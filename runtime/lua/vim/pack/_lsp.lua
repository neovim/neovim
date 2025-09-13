local M = {}

local capabilities = {
  codeActionProvider = true,
  documentSymbolProvider = true,
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
  return tonumber(uri:match('^nvim%-pack://(%d+)/confirm%-update$'))
end

--- @param params { textDocument: { uri: string } }
--- @param callback function
methods['textDocument/documentSymbol'] = function(params, callback)
  local bufnr = get_confirm_bufnr(params.textDocument.uri)
  if bufnr == nil then
    return callback(nil, {})
  end

  --- @alias vim.pack.lsp.Position { line: integer, character: integer }
  --- @alias vim.pack.lsp.Range { start: vim.pack.lsp.Position, end: vim.pack.lsp.Position }
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
  local symbols = parse_headers('^# (%S+)', 0, #lines - 1, group_kind)

  local plug_kind = vim.lsp.protocol.SymbolKind.Module
  for _, group in ipairs(symbols) do
    local start_line, end_line = group.range.start.line, group.range['end'].line
    group.children = parse_headers('^## (.+)$', start_line, end_line, plug_kind)
  end

  return callback(nil, symbols)
end

--- @param callback function
methods['textDocument/codeAction'] = function(_, callback)
  -- TODO(echasnovski)
  -- Suggested actions for "plugin under cursor":
  -- - Delete plugin from disk.
  -- - Update only this plugin.
  -- - Exclude this plugin from update.
  return callback(_, {})
end

--- @param params { textDocument: { uri: string }, position: { line: integer, character: integer } }
--- @param callback function
methods['textDocument/hover'] = function(params, callback)
  local bufnr = get_confirm_bufnr(params.textDocument.uri)
  if bufnr == nil then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local lnum = params.position.line + 1
  local commit = lines[lnum]:match('^[<>] (%x+) │') or lines[lnum]:match('^State.*:%s+(%x+)')
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
