local util = require('vim.lsp.util')
local log = require('vim.lsp.log')
local ms = require('vim.lsp.protocol').Methods
local api = vim.api
local M = {}

--- bufnr → true|nil
--- to throttle refreshes to at most one at a time
local active_refreshes = {} --- @type table<integer,true>

---@type table<integer, table<integer, lsp.CodeLens[]>>
--- bufnr -> client_id -> lenses
local lens_cache_by_buf = setmetatable({}, {
  __index = function(t, b)
    local key = b > 0 and b or api.nvim_get_current_buf()
    return rawget(t, key)
  end,
})

---@type table<integer, integer>
---client_id -> namespace
local namespaces = setmetatable({}, {
  __index = function(t, key)
    local value = api.nvim_create_namespace('vim_lsp_codelens:' .. key)
    rawset(t, key, value)
    return value
  end,
})

---@private
M.__namespaces = namespaces

local augroup = api.nvim_create_augroup('vim_lsp_codelens', {})

api.nvim_create_autocmd('LspDetach', {
  group = augroup,
  callback = function(ev)
    M.clear(ev.data.client_id, ev.buf)
  end,
})

---@param lens lsp.CodeLens
---@param bufnr integer
---@param client_id integer
local function execute_lens(lens, bufnr, client_id)
  local line = lens.range.start.line
  api.nvim_buf_clear_namespace(bufnr, namespaces[client_id], line, line + 1)

  local client = vim.lsp.get_client_by_id(client_id)
  assert(client, 'Client is required to execute lens, client_id=' .. client_id)
  client:exec_cmd(lens.command, { bufnr = bufnr }, function(...)
    vim.lsp.handlers[ms.workspace_executeCommand](...)
    M.refresh()
  end)
end

--- Return all lenses for the given buffer
---
---@param bufnr integer  Buffer number. 0 can be used for the current buffer.
---@return lsp.CodeLens[]
function M.get(bufnr)
  local lenses_by_client = lens_cache_by_buf[bufnr or 0]
  if not lenses_by_client then
    return {}
  end
  local lenses = {}
  for _, client_lenses in pairs(lenses_by_client) do
    vim.list_extend(lenses, client_lenses)
  end
  return lenses
end

--- Run the code lens in the current line
---
function M.run()
  local line = api.nvim_win_get_cursor(0)[1]
  local bufnr = api.nvim_get_current_buf()
  local options = {} --- @type {client: integer, lens: lsp.CodeLens}[]
  local lenses_by_client = lens_cache_by_buf[bufnr] or {}
  for client, lenses in pairs(lenses_by_client) do
    for _, lens in pairs(lenses) do
      if lens.range.start.line == (line - 1) and lens.command and lens.command.command ~= '' then
        table.insert(options, { client = client, lens = lens })
      end
    end
  end
  if #options == 0 then
    vim.notify('No executable codelens found at current line')
  elseif #options == 1 then
    local option = options[1]
    execute_lens(option.lens, bufnr, option.client)
  else
    vim.ui.select(options, {
      prompt = 'Code lenses:',
      kind = 'codelens',
      format_item = function(option)
        return option.lens.command.title
      end,
    }, function(option)
      if option then
        execute_lens(option.lens, bufnr, option.client)
      end
    end)
  end
end

local function resolve_bufnr(bufnr)
  return bufnr == 0 and api.nvim_get_current_buf() or bufnr
end

--- Clear the lenses
---
---@param client_id integer|nil filter by client_id. All clients if nil
---@param bufnr integer|nil filter by buffer. All buffers if nil, 0 for current buffer
function M.clear(client_id, bufnr)
  bufnr = bufnr and resolve_bufnr(bufnr)
  local buffers = bufnr and { bufnr }
    or vim.tbl_filter(api.nvim_buf_is_loaded, api.nvim_list_bufs())
  for _, iter_bufnr in pairs(buffers) do
    local client_ids = client_id and { client_id } or vim.tbl_keys(namespaces)
    for _, iter_client_id in pairs(client_ids) do
      local ns = namespaces[iter_client_id]
      -- there can be display()ed lenses, which are not stored in cache
      if lens_cache_by_buf[iter_bufnr] then
        lens_cache_by_buf[iter_bufnr][iter_client_id] = {}
      end
      api.nvim_buf_clear_namespace(iter_bufnr, ns, 0, -1)
    end
  end
end

--- Display the lenses using virtual text
---
---@param lenses? lsp.CodeLens[] lenses to display
---@param bufnr integer
---@param client_id integer
function M.display(lenses, bufnr, client_id)
  if not api.nvim_buf_is_loaded(bufnr) then
    return
  end

  local ns = namespaces[client_id]
  if not lenses or not next(lenses) then
    api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    return
  end

  local lenses_by_lnum = {} ---@type table<integer, lsp.CodeLens[]>
  for _, lens in pairs(lenses) do
    local line_lenses = lenses_by_lnum[lens.range.start.line]
    if not line_lenses then
      line_lenses = {}
      lenses_by_lnum[lens.range.start.line] = line_lenses
    end
    table.insert(line_lenses, lens)
  end
  local num_lines = api.nvim_buf_line_count(bufnr)
  for i = 0, num_lines do
    local line_lenses = lenses_by_lnum[i] or {}
    api.nvim_buf_clear_namespace(bufnr, ns, i, i + 1)
    local chunks = {}
    local num_line_lenses = #line_lenses
    table.sort(line_lenses, function(a, b)
      return a.range.start.character < b.range.start.character
    end)
    for j, lens in ipairs(line_lenses) do
      local text = (lens.command and lens.command.title or 'Unresolved lens ...'):gsub('%s+', ' ')
      table.insert(chunks, { text, 'LspCodeLens' })
      if j < num_line_lenses then
        table.insert(chunks, { ' | ', 'LspCodeLensSeparator' })
      end
    end
    if #chunks > 0 then
      api.nvim_buf_set_extmark(bufnr, ns, i, 0, {
        virt_text = chunks,
        hl_mode = 'combine',
      })
    end
  end
end

--- Store lenses for a specific buffer and client
---
---@param lenses? lsp.CodeLens[] lenses to store
---@param bufnr integer
---@param client_id integer
function M.save(lenses, bufnr, client_id)
  if not api.nvim_buf_is_loaded(bufnr) then
    return
  end

  local lenses_by_client = lens_cache_by_buf[bufnr]
  if not lenses_by_client then
    lenses_by_client = {}
    lens_cache_by_buf[bufnr] = lenses_by_client
    local ns = namespaces[client_id]
    api.nvim_buf_attach(bufnr, false, {
      on_detach = function(_, b)
        lens_cache_by_buf[b] = nil
      end,
      on_lines = function(_, b, _, first_lnum, last_lnum)
        api.nvim_buf_clear_namespace(b, ns, first_lnum, last_lnum)
      end,
    })
  end
  lenses_by_client[client_id] = lenses
end

---@param lenses? lsp.CodeLens[]
---@param bufnr integer
---@param client_id integer
---@param callback fun()
local function resolve_lenses(lenses, bufnr, client_id, callback)
  lenses = lenses or {}
  local num_lens = vim.tbl_count(lenses)
  if num_lens == 0 then
    callback()
    return
  end

  local function countdown()
    num_lens = num_lens - 1
    if num_lens == 0 then
      callback()
    end
  end
  local ns = namespaces[client_id]
  local client = vim.lsp.get_client_by_id(client_id)
  for _, lens in pairs(lenses or {}) do
    if lens.command then
      countdown()
    else
      assert(client)
      client.request(ms.codeLens_resolve, lens, function(_, result)
        if api.nvim_buf_is_loaded(bufnr) and result and result.command then
          lens.command = result.command
          -- Eager display to have some sort of incremental feedback
          -- Once all lenses got resolved there will be a full redraw for all lenses
          -- So that multiple lens per line are properly displayed

          local num_lines = api.nvim_buf_line_count(bufnr)
          if lens.range.start.line <= num_lines then
            api.nvim_buf_set_extmark(
              bufnr,
              ns,
              lens.range.start.line,
              0,
              { virt_text = { { lens.command.title, 'LspCodeLens' } }, hl_mode = 'combine' }
            )
          end
        end

        countdown()
      end, bufnr)
    end
  end
end

--- |lsp-handler| for the method `textDocument/codeLens`
---
---@param err lsp.ResponseError?
---@param result lsp.CodeLens[]
---@param ctx lsp.HandlerContext
function M.on_codelens(err, result, ctx)
  if err then
    active_refreshes[assert(ctx.bufnr)] = nil
    log.error('codelens', err)
    return
  end

  M.save(result, ctx.bufnr, ctx.client_id)

  -- Eager display for any resolved (and unresolved) lenses and refresh them
  -- once resolved.
  M.display(result, ctx.bufnr, ctx.client_id)
  resolve_lenses(result, ctx.bufnr, ctx.client_id, function()
    active_refreshes[assert(ctx.bufnr)] = nil
    M.display(result, ctx.bufnr, ctx.client_id)
  end)
end

--- @class vim.lsp.codelens.refresh.Opts
--- @inlinedoc
--- @field bufnr integer? filter by buffer. All buffers if nil, 0 for current buffer

--- Refresh the lenses.
---
--- It is recommended to trigger this using an autocmd or via keymap.
---
--- Example:
---
--- ```vim
--- autocmd BufEnter,CursorHold,InsertLeave <buffer> lua vim.lsp.codelens.refresh({ bufnr = 0 })
--- ```
---
--- @param opts? vim.lsp.codelens.refresh.Opts Optional fields
function M.refresh(opts)
  opts = opts or {}
  local bufnr = opts.bufnr and resolve_bufnr(opts.bufnr)
  local buffers = bufnr and { bufnr }
    or vim.tbl_filter(api.nvim_buf_is_loaded, api.nvim_list_bufs())

  for _, buf in ipairs(buffers) do
    if not active_refreshes[buf] then
      local params = {
        textDocument = util.make_text_document_params(buf),
      }
      active_refreshes[buf] = true

      local request_ids = vim.lsp.buf_request(
        buf,
        ms.textDocument_codeLens,
        params,
        M.on_codelens,
        function() end
      )
      if vim.tbl_isempty(request_ids) then
        active_refreshes[buf] = nil
      end
    end
  end
end

return M
