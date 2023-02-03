local util = require('vim.lsp.util')
local log = require('vim.lsp.log')
local api = vim.api
local M = {}

---@class lsp.codelens.bufstate
---@field version integer
---@field client_lens table<integer, table<integer, lsp.CodeLens[]>> client_id -> (lnum -> lenses)

---@type table<integer, lsp.codelens.bufstate>
local lens_cache_by_buf = setmetatable({}, {
  __index = function(t, b)
    local key = b > 0 and b or api.nvim_get_current_buf()
    return rawget(t, key)
  end,
})

---@private
local function execute_lens(lens, bufnr, client_id)
  local client = vim.lsp.get_client_by_id(client_id)
  assert(client, 'Client is required to execute lens, client_id=' .. client_id)
  local command = lens.command
  local fn = client.commands[command.command] or vim.lsp.commands[command.command]
  if fn then
    fn(command, { bufnr = bufnr, client_id = client_id })
    return
  end
  -- Need to use the client that returned the lens → must not use buf_request
  local command_provider = client.server_capabilities.executeCommandProvider
  local commands = type(command_provider) == 'table' and command_provider.commands or {}
  if not vim.tbl_contains(commands, command.command) then
    vim.notify(
      string.format(
        'Language server does not support command `%s`. This command may require a client extension.',
        command.command
      ),
      vim.log.levels.WARN
    )
    return
  end
  client.request('workspace/executeCommand', command, function(...)
    local result = vim.lsp.handlers['workspace/executeCommand'](...)
    M.refresh()
    return result
  end, bufnr)
end

--- Return all lenses for the given buffer
---
---@param bufnr integer Buffer number. 0 can be used for the current buffer.
---@return lsp.CodeLens[] (table)
function M.get(bufnr)
  local lenses_by_client = lens_cache_by_buf[bufnr or 0]
  if not lenses_by_client then
    return {}
  end
  local lenses = {}
  for _, client_lenses in pairs(lenses_by_client) do
    for _, line_lenses in pairs(client_lenses) do
      vim.list_extend(lenses, line_lenses)
    end
  end
  return lenses
end

--- Run the code lens in the current line
---
function M.run()
  local lnum = api.nvim_win_get_cursor(0)[1] - 1
  local bufnr = api.nvim_get_current_buf()
  local options = {}
  local lenses_by_client = lens_cache_by_buf[bufnr] or {}
  for client, lenses_by_lnum in pairs(lenses_by_client) do
    local lenses = lenses_by_lnum[lnum] or {}
    for _, lens in pairs(lenses) do
      table.insert(options, { client = client, lens = lens })
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

---@private
local function resolve_bufnr(bufnr)
  return bufnr == 0 and api.nvim_get_current_buf() or bufnr
end

--- Clear the lenses
---
---@param client_id integer|nil filter by client_id. All clients if nil
---@param bufnr integer|nil filter by buffer. All buffers if nil
function M.clear(client_id, bufnr)
  local buffers = bufnr and { resolve_bufnr(bufnr) } or vim.tbl_keys(lens_cache_by_buf)
  for _, iter_bufnr in pairs(buffers) do
    local bufstate = lens_cache_by_buf[iter_bufnr]
    local client_lens = (bufstate or {}).client_lens or {}
    local client_ids = client_id and { client_id } or vim.tbl_keys(client_lens)
    for _, iter_client_id in pairs(client_ids) do
      if bufstate then
        bufstate.client_lens[iter_client_id] = {}
      end
    end
  end
  vim.cmd('redraw!')
end

--- Display the lenses using virtual text
---
---@deprecated
function M.display()
  vim.deprecate('vim.lsp.codelens.display', nil, '0.10.0')
end

--- Store lenses for a specific buffer and client
--- Resolves unresolved lenses
---
---@param lenses lsp.CodeLens[]|nil (table) of lenses to store
---@param bufnr integer
---@param client_id integer
---@param version integer
function M.save(lenses, bufnr, client_id, version)
  if not lenses then
    return
  end
  local bufstate = lens_cache_by_buf[bufnr]
  if not bufstate then
    bufstate = {
      client_lens = vim.defaulttable(),
      version = version,
    }
    lens_cache_by_buf[bufnr] = bufstate
    api.nvim_buf_attach(bufnr, false, {
      on_detach = function(_, b)
        lens_cache_by_buf[b] = nil
      end,
      on_reload = function(_, b)
        lens_cache_by_buf[b] = nil
      end,
    })
  end
  local lenses_by_client = bufstate.client_lens
  local lenses_by_lnum = lenses_by_client[client_id]
  local client = vim.lsp.get_client_by_id(client_id)

  -- To reduce flicker, preserve old resolved lenses until new ones are resolved.

  local new_lenses_by_lnum = vim.defaulttable()
  local num_unprocessed = #lenses
  if num_unprocessed == 0 then
    lenses_by_client[client_id] = {}
    bufstate.version = version
    return
  end

  for _, lens in ipairs(lenses) do
    local lnum = lens.range.start.line
    table.insert(new_lenses_by_lnum[lnum], lens)
  end

  for lnum, _ in pairs(lenses_by_lnum) do
    if not next(new_lenses_by_lnum[lnum]) then
      lenses_by_lnum[lnum] = nil
    end
  end

  local countdown = function()
    num_unprocessed = num_unprocessed - 1
    if num_unprocessed == 0 then
      bufstate.version = version
      vim.cmd('redraw!')
    end
  end

  local redraw = false
  for lnum, new_line_lenses in pairs(new_lenses_by_lnum) do
    local num_unresolved = 0
    for _, lens in pairs(new_line_lenses) do
      if not lens.command then
        num_unresolved = num_unresolved + 1
      end
    end
    local current_line_lenses = lenses_by_lnum[lnum]
    if not next(current_line_lenses or {}) then
      lenses_by_lnum[lnum] = new_line_lenses
      redraw = true
    end
    for _, lens in pairs(new_line_lenses) do
      if lens.command then
        countdown()
      else
        client.request('codeLens/resolve', lens, function(_, result)
          if result and result.command then
            lens.command = result.command
          end
          num_unresolved = num_unresolved - 1
          if num_unresolved == 0 and current_line_lenses then
            lenses_by_lnum[lnum] = new_line_lenses
          end
          countdown()
        end)
      end
    end
  end
  if redraw then
    vim.cmd('redraw!')
  end
end

--- |lsp-handler| for the method `textDocument/codeLens`
---
function M.on_codelens(err, result, ctx, _)
  if err then
    local _ = log.error() and log.error('codelens', err)
    return
  end
  M.save(result, ctx.bufnr, ctx.client_id, ctx.version)
end

--- Refresh the codelens for the current buffer
---
--- It is recommended to trigger this using an autocmd or via keymap.
---
--- Example:
--- <pre>vim
---   autocmd BufEnter,CursorHold,InsertLeave <buffer> lua vim.lsp.codelens.refresh()
--- </pre>
---
function M.refresh()
  local params = {
    textDocument = util.make_text_document_params(),
  }
  vim.lsp.buf_request(0, 'textDocument/codeLens', params)
end

local namespace = api.nvim_create_namespace('vim_lsp_codelens')

api.nvim_set_decoration_provider(namespace, {
  on_win = function(_, _, bufnr, topline, botline)
    local bufstate = lens_cache_by_buf[bufnr]
    if not bufstate then
      return
    end

    if bufstate.version ~= vim.lsp.util.buf_versions[bufnr] then
      return
    end
    local lenses_by_client = bufstate.client_lens
    api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)

    for i = topline, botline do
      local chunks = {}
      for _, lenses_by_lnum in pairs(lenses_by_client) do
        local line_lenses = lenses_by_lnum[i] or {}
        table.sort(line_lenses, function(a, b)
          return a.range.start.character < b.range.start.character
        end)
        for _, lens in ipairs(line_lenses) do
          local text = lens.command and lens.command.title or 'Unresolved lens ...'
          table.insert(chunks, { text, 'LspCodeLens' })
          table.insert(chunks, { ' | ', 'LspCodeLensSeparator' })
        end
      end
      if #chunks > 0 then
        table.remove(chunks)
        api.nvim_buf_set_extmark(bufnr, namespace, i, 0, {
          ephemeral = false,
          virt_text = chunks,
          hl_mode = 'combine',
        })
      end
    end
  end,
})

return M
