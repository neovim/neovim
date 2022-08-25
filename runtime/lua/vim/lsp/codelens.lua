local util = require('vim.lsp.util')
local log = require('vim.lsp.log')
local api = vim.api
local M = {}

--- bufnr -> tick
local last_tick = {}

--- bufnr → true|nil
--- to throttle refreshes to at most one at a time
local active_refreshes = {}

--- bufnr -> client_id -> lenses
local lens_cache_by_buf = setmetatable({}, {
  __index = function(t, b)
    local key = b > 0 and b or api.nvim_get_current_buf()
    return rawget(t, key)
  end,
})

local namespaces = setmetatable({}, {
  __index = function(t, key)
    local value = api.nvim_create_namespace('vim_lsp_codelens:' .. key)
    rawset(t, key, value)
    return value
  end,
})

---@private
M.__namespaces = namespaces

---@private
local function execute_lens(lens, bufnr, client_id)
  local line = lens.range.start.line
  api.nvim_buf_clear_namespace(bufnr, namespaces[client_id], line, line + 1)

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
---@param bufnr number  Buffer number. 0 can be used for the current buffer.
---@return table (`CodeLens[]`)
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
  local options = {}
  local lenses_by_client = lens_cache_by_buf[bufnr] or {}
  for client, lenses in pairs(lenses_by_client) do
    for _, lens in pairs(lenses) do
      if lens.range.start.line == (line - 1) then
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

local function invalid_response(bufnr)
  -- FIXME see https://github.com/neovim/neovim/pull/15723/
  -- if tick has changed our response is outdated!
  local l = last_tick[bufnr]
  return l > 0 and l ~= api.nvim_buf_get_changedtick(bufnr)
end

---@param line_lenses table | nil lenses to display (`CodeLens[] | null`)
---@param bufnr integer
---@param ns integer
---@param lnum integer
local function display_line(line_lenses, bufnr, ns, lnum)
  if not line_lenses or not next(line_lenses) or invalid_response(bufnr) then
    return
  end

  table.sort(line_lenses, function(a, b)
    return a.range.start.character < b.range.start.character
  end)

  local chunks = {}
  local num_line_lenses = #line_lenses
  for j, lens in ipairs(line_lenses) do
    local text = lens.command and lens.command.title or 'Unresolved lens ...'
    chunks[#chunks + 1] = { text, 'LspCodeLens' }
    if j < num_line_lenses then
      chunks[#chunks + 1] = { ' | ', 'LspCodeLensSeparator' }
    end
  end

  if #chunks > 0 then
    local opts = {
      virt_text = chunks,
      hl_mode = 'combine',
    }

    api.nvim_buf_clear_namespace(bufnr, ns, lnum, lnum + 1)
    api.nvim_buf_set_extmark(bufnr, ns, lnum, 0, opts)
  end
end

--- Clear invalid lenses and display lenses for the given lines using virtual text
---
---@param lines table<integer, true | nil> whether to show lenses for that line
---@param lenses_by_lnum table<integer, table> lenses to display (`CodeLens[] | null`)
---@param bufnr number
---@param client_id number
function M.display(lines, lenses_by_lnum, bufnr, client_id)
  local ns = namespaces[client_id]
  local num_lines = api.nvim_buf_line_count(bufnr)
  for i = 0, num_lines do
    local line_lenses = lenses_by_lnum[i]
    if not line_lenses then
      api.nvim_buf_clear_namespace(bufnr, ns, i, i + 1)
    elseif lines[i] then
      display_line(line_lenses, bufnr, ns, i)
    end
  end
end

--- Store lenses for a specific buffer and client
---
---@param lenses table | nil lenses to store (`CodeLens[] | null`)
---@param bufnr number
---@param client_id number
function M.save(lenses, bufnr, client_id)
  local lenses_by_client = lens_cache_by_buf[bufnr]
  if not lenses_by_client then
    lenses_by_client = {}
    lens_cache_by_buf[bufnr] = lenses_by_client
    api.nvim_buf_attach(bufnr, false, {
      on_detach = function(_, b)
        api.nvim_buf_clear_namespace(b, namespaces[client_id], 0, -1)
        lens_cache_by_buf[b] = nil
      end,
    })
  end
  lenses_by_client[client_id] = lenses
end

---@private
---@param lenses table | nil lenses to display (`CodeLens[] | null`)
---@param new table<integer, true | nil> lines without an extmark/lens
---@param bufnr number
---@param lenses_by_lnum table<integer, table | nil> mapping lnum -> lens
---@param client_id number
---@param callback function
local function resolve_lenses(lenses, new, lenses_by_lnum, bufnr, client_id, callback)
  lenses = lenses or {}
  local num_lens = vim.tbl_count(lenses)
  if num_lens == 0 then
    callback()
    return
  end

  ---@private
  local function countdown()
    num_lens = num_lens - 1
    if num_lens == 0 then
      callback()
    end
  end

  local num_lens_line = {}
  for _, lens in pairs(lenses) do
    local line = lens.range.start.line
    local c = num_lens_line[line] or 0
    num_lens_line[line] = c + 1
  end

  -- We may update intermediate states on a new lens. Otherwise, refresh when all lenses for that
  -- line have been resolved.
  local ns = namespaces[client_id]
  local function countdown_line(line)
    num_lens_line[line] = num_lens_line[line] - 1
    if new[line] or num_lens_line[line] == 0 then
      local line_lenses = lenses_by_lnum[line]
      display_line(line_lenses, bufnr, ns, line)
    end
  end

  local client = vim.lsp.get_client_by_id(client_id)
  for _, lens in pairs(lenses or {}) do
    if lens.command then
      countdown()
    else
      client.request('codeLens/resolve', lens, function(_, result)
        if result and result.command then
          lens.command = result.command
        end
        -- Incremental display
        countdown_line(lens.range.start.line)
        countdown()
      end, bufnr)
    end
  end
end

local function current_extmarks(bufnr, ns)
  local extmarks = {}
  for _, extmark in pairs(api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, {})) do
    local id, lnum = extmark[1], extmark[2]
    extmarks[lnum] = id
  end
  return extmarks
end

local function is_resolved(lens)
  local command = lens.command
  return command and command.command and command.title
end

--- |lsp-handler| for the method `textDocument/codeLens`
---
function M.on_codelens(err, result, ctx, _)
  if err then
    active_refreshes[ctx.bufnr] = nil
    local _ = log.error() and log.error('codelens', err)
    return
  end

  if invalid_response(ctx.bufnr) then
    active_refreshes[ctx.bufnr] = nil
    return
  end

  M.save(result, ctx.bufnr, ctx.client_id)

  -- Enables incremental feedback by displaying intermediate states:
  -- { Unresolved | Unresolved } -> { a | Unresolved } or { Unresolved | b } -> { a | b }).
  local extmarks = current_extmarks(ctx.bufnr, namespaces[ctx.client_id])
  local new, new_or_resolved, unresolved, lenses_by_lnum = {}, {}, {}, {}
  for _, lens in pairs(result) do
    local line = lens.range.start.line

    local resolved = is_resolved(lens)
    if not resolved then
      unresolved[#unresolved + 1] = lens
    end

    if not extmarks[line] then
      new[line] = true
      new_or_resolved[line] = true
    elseif resolved then
      new_or_resolved[line] = true
    end

    local line_lenses = lenses_by_lnum[line]
    if not line_lenses then
      line_lenses = {}
      lenses_by_lnum[line] = line_lenses
    end
    line_lenses[#line_lenses + 1] = lens
  end

  -- Display resolved (and new unresolved) lenses. Otherwise, refresh once resolved.
  M.display(new_or_resolved, lenses_by_lnum, ctx.bufnr, ctx.client_id)

  resolve_lenses(unresolved, new, lenses_by_lnum, ctx.bufnr, ctx.client_id, function()
    active_refreshes[ctx.bufnr] = nil
  end)
end

--- Refresh the codelens for the current buffer
---
--- It is recommended to trigger this using an autocmd or via keymap.
---
--- <pre>
---   autocmd BufEnter,CursorHold,InsertLeave <buffer> lua vim.lsp.codelens.refresh()
--- </pre>
---
function M.refresh()
  local params = {
    textDocument = util.make_text_document_params(),
  }
  local bufnr = api.nvim_get_current_buf()
  if active_refreshes[bufnr] then
    return
  end
  active_refreshes[bufnr] = true
  last_tick[bufnr] = api.nvim_buf_get_changedtick(bufnr)

  vim.lsp.buf_request(bufnr, 'textDocument/codeLens', params, M.on_codelens)
end

return M
