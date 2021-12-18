local lsp = vim.lsp
local util = vim.lsp.util

---@private
local function mk_tag_item(name, range, uri, offset_encoding)
  local bufnr = vim.uri_to_bufnr(uri)
  -- This is get_line_byte_from_position is 0-indexed, call cursor expects a 1-indexed position
  local byte = util._get_line_byte_from_position(bufnr, range.start, offset_encoding) + 1
  return {
    name = name,
    filename = vim.uri_to_fname(uri),
    cmd = string.format('call cursor(%d, %d)|', range.start.line + 1, byte),
  }
end

---@private
local function query_definition(pattern)
  local params = lsp.util.make_position_params()
  local results_by_client, err = lsp.buf_request_sync(0, 'textDocument/definition', params, 1000)
  if err then
    return {}
  end
  local results = {}
  local add = function(range, uri, offset_encoding)
    table.insert(results, mk_tag_item(pattern, range, uri, offset_encoding))
  end
  for client_id, lsp_results in pairs(results_by_client) do
    local client = lsp.get_client_by_id(client_id)
    local result = lsp_results.result or {}
    if result.range then -- Location
      add(result.range, result.uri)
    else -- Location[] or LocationLink[]
      for _, item in pairs(result) do
        if item.range then -- Location
          add(item.range, item.uri, client.offset_encoding)
        else -- LocationLink
          add(item.targetSelectionRange, item.targetUri, client.offset_encoding)
        end
      end
    end
  end
  return results
end

---@private
local function query_workspace_symbols(pattern)
  local results_by_client, err = lsp.buf_request_sync(0, 'workspace/symbol', { query = pattern }, 1000)
  if err then
    return {}
  end
  local results = {}
  for client_id, symbols in pairs(results_by_client) do
    local client = lsp.get_client_by_id(client_id)
    for _, symbol in pairs(symbols.result or {}) do
      local loc = symbol.location
      local item = mk_tag_item(symbol.name, loc.range, loc.uri, client.offset_encoding)
      item.kind = lsp.protocol.SymbolKind[symbol.kind] or 'Unknown'
      table.insert(results, item)
    end
  end
  return results
end

---@private
local function tagfunc(pattern, flags)
  local matches
  if string.match(flags, 'c') then
    matches = query_definition(pattern)
  else
    matches = query_workspace_symbols(pattern)
  end
  -- fall back to tags if no matches
  return #matches > 0 and matches or vim.NIL
end

return tagfunc
