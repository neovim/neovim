local M = {}
local lsp = vim.lsp

local function mk_tag_item(name, range, uri)
  local start = range.start
  return {
    name = name,
    filename = vim.uri_to_fname(uri),
    cmd = string.format(
      'call cursor(%d, %d)', start.line + 1, start.character + 1
    )
  }
end

local function query_definition(pattern)
  local params = lsp.util.make_position_params()
  local results_by_client, err = lsp.buf_request_sync(0, 'textDocument/definition', params, 1000)
  assert(not err, vim.inspect(err))
  local results = {}
  local add = function(range, uri) table.insert(results, mk_tag_item(pattern, range, uri)) end
  for _, lsp_results in pairs(results_by_client) do
    local result = lsp_results.result or {}
    if result.range then              -- Location
      add(result.range, result.uri)
    else                              -- Location[] or LocationLink[]
      for _, item in pairs(result) do
        if item.range then            -- Location
          add(item.range, item.uri)
        else                          -- LocationLink
          add(item.targetSelectionRange, item.targetUri)
        end
      end
    end
  end
  return results
end

local function query_workspace_symbols(pattern)
  local results_by_client, err = lsp.buf_request_sync(0, 'workspace/symbol', { query = pattern }, 1000)
  assert(not err, vim.inspect(err))
  local results = {}
  for _, symbols in pairs(results_by_client) do
    for _, symbol in pairs(symbols.result or {}) do
      local loc = symbol.location
      local item = mk_tag_item(symbol.name, loc.range, loc.uri)
      item.kind = lsp.protocol.SymbolKind[symbol.kind] or 'Unknown'
      table.insert(results, item)
    end
  end
  return results
end

function M.tagfunc(pattern, flags)
  local matches
  if flags == 'c' then
    matches = query_definition(pattern)
  elseif flags == '' or flags == 'i' then
    matches = query_workspace_symbols(pattern)
  else
    return vim.NIL
  end
  -- fall back to tags if no matches
  if #matches == 0 then
    return vim.NIL
  end
end


return M
