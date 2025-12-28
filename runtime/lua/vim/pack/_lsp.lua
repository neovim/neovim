local M = {}

local capabilities = {
  codeActionProvider = true,
  documentSymbolProvider = true,
  executeCommandProvider = { commands = { 'delete_plugin', 'update_plugin', 'skip_update_plugin' } },
  hoverProvider = true,
}
--- @type table<string,function>
local methods = {}

--- @param callback function
function methods.initialize(_, callback)
  return callback(nil, { capabilities = capabilities })
end

--- @param callback function
function methods.shutdown(_, callback)
  return callback(nil, nil)
end

local get_confirm_bufnr = function(uri)
  return tonumber(uri:match('^nvim%-pack://confirm#(%d+)$'))
end

local group_header_pattern = '^# (%S+)'
local plugin_header_pattern = '^## (.+)$'

--- @return { group: string?, name: string?, from: integer?, to: integer? }
local get_plug_data_at_lnum = function(bufnr, lnum)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  --- @type string, string, integer, integer
  local group, name, from, to
  for i = lnum, 1, -1 do
    group = group or lines[i]:match(group_header_pattern) --[[@as string]]
    -- If group is found earlier than name - `lnum` is for group header line
    -- If later - proper group header line.
    if group then
      break
    end
    name = name or lines[i]:match(plugin_header_pattern) --[[@as string]]
    from = (not from and name) and i or from --[[@as integer]]
  end
  if not (group and name and from) then
    return {}
  end
  --- @cast group string
  --- @cast from integer

  for i = lnum + 1, #lines do
    if lines[i]:match(group_header_pattern) or lines[i]:match(plugin_header_pattern) then
      -- Do not include blank line before next section
      to = i - 2
      break
    end
  end
  to = to or #lines

  if not (from <= lnum and lnum <= to) then
    return {}
  end
  return { group = group, name = name, from = from, to = to }
end

--- @alias vim.pack.lsp.Position { line: integer, character: integer }
--- @alias vim.pack.lsp.Range { start: vim.pack.lsp.Position, end: vim.pack.lsp.Position }

--- @param params { textDocument: { uri: string } }
--- @param callback function
methods['textDocument/documentSymbol'] = function(params, callback)
  local bufnr = get_confirm_bufnr(params.textDocument.uri)
  if bufnr == nil then
    return callback(nil, {})
  end

  --- @alias vim.pack.lsp.Symbol {
  ---   name: string,
  ---   kind: number,
  ---   range: vim.pack.lsp.Range,
  ---   selectionRange: vim.pack.lsp.Range,
  ---   children: vim.pack.lsp.Symbol[]?,
  --- }

  --- @return vim.pack.lsp.Symbol?
  local new_symbol = function(name, start_line, end_line, kind)
    if name == nil then
      return nil
    end
    local range = {
      start = { line = start_line, character = 0 },
      ['end'] = { line = end_line, character = 0 },
    }
    return { name = name, kind = kind, range = range, selectionRange = range }
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  --- @return vim.pack.lsp.Symbol[]
  local parse_headers = function(pattern, start_line, end_line, kind)
    local res, cur_match, cur_start = {}, nil, nil
    for i = start_line, end_line do
      local m = lines[i + 1]:match(pattern)
      if m ~= nil and m ~= cur_match then
        table.insert(res, new_symbol(cur_match, cur_start, i, kind))
        cur_match, cur_start = m, i
      end
    end
    table.insert(res, new_symbol(cur_match, cur_start, end_line, kind))
    return res
  end

  local group_kind = vim.lsp.protocol.SymbolKind.Namespace
  local symbols = parse_headers(group_header_pattern, 0, #lines - 1, group_kind)

  local plug_kind = vim.lsp.protocol.SymbolKind.Module
  for _, group in ipairs(symbols) do
    local start_line, end_line = group.range.start.line, group.range['end'].line
    group.children = parse_headers(plugin_header_pattern, start_line, end_line, plug_kind)
  end

  return callback(nil, symbols)
end

--- @alias vim.pack.lsp.CodeActionContext { diagnostics: table, only: table?, triggerKind: integer? }

--- @param params { textDocument: { uri: string }, range: vim.pack.lsp.Range, context: vim.pack.lsp.CodeActionContext }
--- @param callback function
methods['textDocument/codeAction'] = function(params, callback)
  local bufnr = get_confirm_bufnr(params.textDocument.uri)
  local empty_kind = vim.lsp.protocol.CodeActionKind.Empty
  local only = params.context.only or { empty_kind }
  if not (bufnr and vim.tbl_contains(only, empty_kind)) then
    return callback(nil, {})
  end
  local plug_data = get_plug_data_at_lnum(bufnr, params.range.start.line + 1)
  if not plug_data.name then
    return callback(nil, {})
  end

  local function new_action(title, command)
    return {
      title = ('%s `%s`'):format(title, plug_data.name),
      command = { title = title, command = command, arguments = { bufnr, plug_data } },
    }
  end

  local res = {}
  if plug_data.group == 'Update' then
    vim.list_extend(res, {
      new_action('Update', 'update_plugin'),
      new_action('Skip updating', 'skip_update_plugin'),
    }, 0)
  end
  vim.list_extend(res, { new_action('Delete', 'delete_plugin') })
  callback(nil, res)
end

local commands = {
  update_plugin = function(plug_data)
    vim.pack.update({ plug_data.name }, { force = true, _offline = true })
  end,
  skip_update_plugin = function(_) end,
  delete_plugin = function(plug_data)
    vim.pack.del({ plug_data.name }, { force = true })
  end,
}

-- NOTE: Use `vim.schedule_wrap` to avoid press-enter after choosing code
-- action via built-in `vim.fn.inputlist()`
--- @param params { command: string, arguments: table }
--- @param callback function
methods['workspace/executeCommand'] = vim.schedule_wrap(function(params, callback)
  --- @type integer, table
  local bufnr, plug_data = unpack(params.arguments)
  local ok, err = pcall(commands[params.command], plug_data)
  if not ok then
    return callback({ code = 1, message = err }, {})
  end

  -- Remove plugin lines (including blank line) to not later act on plugin
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, plug_data.from - 2, plug_data.to, false, {})
  vim.bo[bufnr].modifiable, vim.bo[bufnr].modified = false, false
  callback(nil, {})
end)

--- @param params { textDocument: { uri: string }, position: vim.pack.lsp.Position }
--- @param callback function
methods['textDocument/hover'] = function(params, callback)
  local bufnr = get_confirm_bufnr(params.textDocument.uri)
  if bufnr == nil then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local lnum = params.position.line + 1
  local commit = lines[lnum]:match('^[<>] (%x+) │') or lines[lnum]:match('^Revision.*:%s+(%x+)')
  local tag = lines[lnum]:match('^• (.+)$')
  if commit == nil and tag == nil then
    return
  end

  local path, path_lnum = nil, lnum - 1
  while path == nil and path_lnum >= 1 do
    path = lines[path_lnum]:match('^Path:%s+(.+)$')
    path_lnum = path_lnum - 1
  end
  if path == nil then
    return
  end

  local cmd = { 'git', 'show', '--no-color', commit or tag }
  --- @param sys_out vim.SystemCompleted
  local on_exit = function(sys_out)
    local markdown = '```diff\n' .. sys_out.stdout .. '\n```'
    local res = { contents = { kind = vim.lsp.protocol.MarkupKind.Markdown, value = markdown } }
    callback(nil, res)
  end
  vim.system(cmd, { cwd = path }, vim.schedule_wrap(on_exit))
end

local dispatchers = {}

-- TODO: Simplify after `vim.lsp.server` is a thing
-- https://github.com/neovim/neovim/pull/24338
local cmd = function(disp)
  -- Store dispatchers to use for showing progress notifications
  dispatchers = disp
  local res, closing, request_id = {}, false, 0

  function res.request(method, params, callback)
    local method_impl = methods[method]
    if method_impl ~= nil then
      method_impl(params, callback)
    end
    request_id = request_id + 1
    return true, request_id
  end

  function res.notify(method, _)
    if method == 'exit' then
      dispatchers.on_exit(0, 15)
    end
    return false
  end

  function res.is_closing()
    return closing
  end

  function res.terminate()
    closing = true
  end

  return res
end

M.client_id = assert(
  vim.lsp.start({ cmd = cmd, name = 'vim.pack', root_dir = vim.uv.cwd() }, { attach = false })
)

return M
