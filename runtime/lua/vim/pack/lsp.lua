local M = {}

local capabilities = {
  codeActionProvider = true,
  documentSymbolProvider = true,
  hoverProvider = true,
}
--- @type table<string,function>
local methods = {}

function methods.initialize(_)
  return { capabilities = capabilities }
end

function methods.shutdown(_)
  return nil
end

methods['textDocument/documentSymbol'] = function(params)
  local bufnr = tonumber(params.textDocument.uri:match('^nvimpack://(%d+)/confirm%-update$'))
  if bufnr == nil then
    return {}
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

  return symbols
end

methods['textDocument/codeAction'] = function(_)
  -- TODO(echasnovski)
  -- Suggested actions for "plugin under cursor":
  -- - Delete plugin from disk.
  -- - Update only this plugin.
  -- - Exclude this plugin from update.
  return {}
end

methods['textDocument/hover'] = function(_)
  -- TODO(echasnovski)
  -- Suggested usages:
  -- - Show diff when on pending commit.
  -- - Show description and/or changelog when on newer tag.
  return {}
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
      callback(nil, method_impl(params))
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

  function res.is_closed()
    return closing
  end

  function res.terminate()
    closing = true
  end

  return res
end

M.client_id = vim.lsp.start(
  { cmd = cmd, name = 'vim.pack', root_dir = vim.uv.cwd() },
  { attach = false }
)

local progress_token_count = 0

--- @return fun(kind: 'begin'|'report'|'end', msg: string?, percent: integer?): nil
function M.new_progress_report(title)
  progress_token_count = progress_token_count + 1

  return vim.schedule_wrap(function(kind, msg, percent)
    local value = { kind = kind, message = msg, percentage = percent }
    if kind == 'begin' then
      value.title = title
    elseif kind == 'end' then
      value.percentage = nil
    end
    dispatchers.notification('$/progress', { token = progress_token_count, value = value })
  end)
end

return M
