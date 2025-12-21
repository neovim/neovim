local util = require('vim.lsp.util')
local log = require('vim.lsp.log')
local api = vim.api
local M = {}

---@class vim.lsp.codelens.display.Opts
---@field virt_lines? boolean Display the lenses as virtual lines instead of virtual text
---Lens handler replacing the default handler. Will be called even if the amount of chunks to
---display is zero.
---Takes the following args:
---- buf: Buffer number of the lens
---- ns: Extmark namespace id for the LSP client's lenses.
---NOTE: Previous extmarks must be cleared manually
---- lnum: The zero-indexed line number the lenses will be displayed on
---- chunks: The lenses converted to a list of `[text, hl_group]` pairs
---
--- Example:
---
--- ```lua
--- vim.api.nvim_buf_clear_namespace(buf, ns, lnum, lnum + 1)
--- if #chunks == 0 then
---   return
--- end
---
--- local indent = vim.api.nvim_buf_call(buf, function()
---   return vim.fn.indent(lnum + 1)
--- end)
---
--- if indent > 0 then
---   local indent_str = string.rep(' ', indent)
---   table.insert(chunks, 1, { indent_str, '' })
--- end
---
--- vim.api.nvim_buf_set_extmark(buf, ns, lnum, 0, {
---   virt_lines = { chunks },
---   virt_lines_above = true,
---   hl_mode = 'replace', -- Default: 'combine'
--- })
--- ```
---@field on_display? fun(buf: integer, ns: integer, lnum: integer, chunks: [string, integer|string?][])

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
    local value = api.nvim_create_namespace('nvim.lsp.codelens:' .. key)
    rawset(t, key, value)
    return value
  end,
})

---@private
M.__namespaces = namespaces

local augroup = api.nvim_create_augroup('nvim.lsp.codelens', {})

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
    vim.lsp.handlers['workspace/executeCommand'](...)
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

--- Run the code lens available in the current line.
function M.run()
  local line = api.nvim_win_get_cursor(0)[1] - 1
  local bufnr = api.nvim_get_current_buf()
  local options = {} --- @type {client: integer, lens: lsp.CodeLens}[]
  local lenses_by_client = lens_cache_by_buf[bufnr] or {}
  for client, lenses in pairs(lenses_by_client) do
    for _, lens in pairs(lenses) do
      if
        lens.command
        and lens.command.command ~= ''
        and lens.range.start.line <= line
        and lens.range['end'].line >= line
      then
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

--- Clear the lenses
---
---@param client_id integer|nil filter by client_id. All clients if nil
---@param bufnr integer|nil filter by buffer. All buffers if nil, 0 for current buffer
function M.clear(client_id, bufnr)
  bufnr = bufnr and vim._resolve_bufnr(bufnr)
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

---@param lenses lsp.CodeLens[]
---@return table<integer, lsp.CodeLens[]>
local function group_lenses_by_start_line(lenses)
  local lenses_by_lnum = {} ---@type table<integer, lsp.CodeLens[]>
  for _, lens in pairs(lenses) do
    local line_lenses = lenses_by_lnum[lens.range.start.line]
    if not line_lenses then
      line_lenses = {}
      lenses_by_lnum[lens.range.start.line] = line_lenses
    end
    table.insert(line_lenses, lens)
  end
  return lenses_by_lnum
end

---@param buf integer
---@param ns integer
---@param lnum integer
---@param lenses lsp.CodeLens[] Lenses that start at `line`
---@param opts vim.lsp.codelens.display.Opts
local function display_line_lenses(buf, ns, lnum, lenses, opts)
  local chunks = {} ---@type [string, integer|string?][]
  table.sort(lenses, function(a, b)
    return a.range.start.character < b.range.start.character
  end)

  for i, lens in ipairs(lenses) do
    if lens.command then
      local text = lens.command.title:gsub('%s+', ' ') ---@type string
      chunks[#chunks + 1] = { text, 'LspCodeLens' }
      if i < #lenses then
        chunks[#chunks + 1] = { ' | ', 'LspCodeLensSeparator' }
      end
    else
      -- If some lenses are unresolved, don't update the line's virtual text. Due to this, user
      -- may see outdated lenses or not see already resolved lenses. However, showing outdated
      -- lenses for short period of time is better than spamming user with virtual text updates.
      return
    end
  end

  if opts.on_display then
    opts.on_display(buf, ns, lnum, chunks)
    return
  end

  api.nvim_buf_clear_namespace(buf, ns, lnum, lnum + 1)
  if #chunks == 0 then
    return
  end

  local extmark_opts = { hl_mode = 'combine' } ---@type vim.api.keyset.set_extmark
  if opts.virt_lines then
    ---@type integer
    local indent = api.nvim_buf_call(buf, function()
      return vim.fn.indent(lnum + 1)
    end)

    if indent > 0 then
      local indent_str = string.rep(' ', indent) ---@type string
      table.insert(chunks, 1, { indent_str, '' })
    end

    extmark_opts.virt_lines = { chunks }
    extmark_opts.virt_lines_above = true
  else
    extmark_opts.virt_text = chunks
  end

  api.nvim_buf_set_extmark(buf, ns, lnum, 0, extmark_opts)
end

--- Display the lenses using virtual text
---
---@param lenses? lsp.CodeLens[] lenses to display
---@param bufnr integer
---@param client_id integer
---@param opts? vim.lsp.codelens.display.Opts
function M.display(lenses, bufnr, client_id, opts)
  opts = opts or {}
  vim.validate('opts', opts, 'table')
  vim.validate('opts.virt_lines', opts.virt_lines, 'boolean', true)
  vim.validate('opts.on_display', opts.on_display, 'callable', true)

  if not api.nvim_buf_is_loaded(bufnr) then
    return
  end

  local ns = namespaces[client_id]
  if (not lenses) or #lenses < 1 then
    api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    return
  end

  local lenses_by_lnum = group_lenses_by_start_line(lenses)
  local num_lines = api.nvim_buf_line_count(bufnr)
  for i = 0, num_lines - 1 do
    display_line_lenses(bufnr, ns, i, lenses_by_lnum[i] or {}, opts)
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
---@param opts vim.lsp.codelens.display.Opts
local function resolve_lenses(lenses, bufnr, client_id, callback, opts)
  lenses = lenses or {}
  local num_lens = vim.tbl_count(lenses)
  if num_lens == 0 then
    callback()
    return
  end

  ---@param n integer
  local function countdown(n)
    num_lens = num_lens - n
    if num_lens == 0 then
      callback()
    end
  end

  local ns = namespaces[client_id]
  local client = vim.lsp.get_client_by_id(client_id)

  -- Resolve all lenses in a line, then display them.
  local lenses_by_lnum = group_lenses_by_start_line(lenses)
  for line, line_lenses in pairs(lenses_by_lnum) do
    local num_resolved_line_lenses = 0
    local function display_line_countdown()
      num_resolved_line_lenses = num_resolved_line_lenses + 1
      if num_resolved_line_lenses == #line_lenses then
        if api.nvim_buf_is_valid(bufnr) and line <= api.nvim_buf_line_count(bufnr) then
          display_line_lenses(bufnr, ns, line, line_lenses, opts)
        end
        countdown(#line_lenses)
      end
    end

    for _, lens in pairs(line_lenses) do
      if lens.command then
        display_line_countdown()
      else
        assert(client)
        client:request('codeLens/resolve', lens, function(_, result)
          if api.nvim_buf_is_loaded(bufnr) and result and result.command then
            lens.command = result.command
          end
          display_line_countdown()
        end, bufnr)
      end
    end
  end
end

--- |lsp-handler| for the method `textDocument/codeLens`
---
---@param err lsp.ResponseError?
---@param result lsp.CodeLens[]
---@param ctx lsp.HandlerContext
---@param opts? { display: vim.lsp.codelens.display.Opts }
function M.on_codelens(err, result, ctx, opts)
  opts = opts or {}
  vim.validate('opts', opts, 'table')
  -- This value could go from here to local resolve_lenses to local display_line_lenses, so
  -- clean and validate now
  opts.display = opts.display or {}
  vim.validate('opts.display', opts.display, 'table')
  vim.validate('opts.display.virt_lines', opts.display.virt_lines, 'boolean', true)
  vim.validate('opts.display.on_display', opts.display.on_display, 'callable', true)

  local bufnr = assert(ctx.bufnr)

  if err then
    active_refreshes[bufnr] = nil
    log.error('codelens', err)
    return
  end

  M.save(result, bufnr, ctx.client_id)

  -- Eager display for any resolved lenses and refresh them once resolved.
  M.display(result, bufnr, ctx.client_id, opts.display)
  resolve_lenses(result, bufnr, ctx.client_id, function()
    active_refreshes[bufnr] = nil
  end, opts.display)
end

--- @class vim.lsp.codelens.refresh.Opts
--- @inlinedoc
--- @field bufnr integer? filter by buffer. All buffers if nil, 0 for current buffer
--- @field display vim.lsp.codelens.display.Opts? See |vim.lsp.codelens.display.Opts|

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
  vim.validate('opts', opts, 'table')
  opts.display = opts.display or {}
  vim.validate('opts.display', opts.display, 'table')
  vim.validate('opts.display.virt_lines', opts.display.virt_lines, 'boolean', true)
  vim.validate('opts.display.on_display', opts.display.on_display, 'callable', true)

  local bufnr = opts.bufnr and vim._resolve_bufnr(opts.bufnr)
  local buffers = bufnr and { bufnr }
    or vim.tbl_filter(api.nvim_buf_is_loaded, api.nvim_list_bufs())

  for _, buf in ipairs(buffers) do
    if not active_refreshes[buf] then
      local params = {
        textDocument = util.make_text_document_params(buf),
      }
      active_refreshes[buf] = true

      ---@type table<integer, integer>
      local request_ids = vim.lsp.buf_request(
        buf,
        'textDocument/codeLens',
        params,
        function(err, result, ctx)
          M.on_codelens(err, result, ctx, { display = opts.display })
        end,
        function() end
      )

      if vim.tbl_isempty(request_ids) then
        active_refreshes[buf] = nil
      end
    end
  end
end

return M
