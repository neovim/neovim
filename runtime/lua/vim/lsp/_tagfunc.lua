local lsp = vim.lsp
local util = lsp.util
local ms = lsp.protocol.Methods

---@param name string
---@param range lsp.Range
---@param uri string
---@param offset_encoding string
---@return {name: string, filename: string, cmd: string, kind?: string}
local function mk_tag_item(name, range, uri, offset_encoding)
  local bufnr = vim.uri_to_bufnr(uri)
  -- This is get_line_byte_from_position is 0-indexed, call cursor expects a 1-indexed position
  local byte = util._get_line_byte_from_position(bufnr, range.start, offset_encoding) + 1
  return {
    name = name,
    filename = vim.uri_to_fname(uri),
    cmd = string.format([[/\%%%dl\%%%dc/]], range.start.line + 1, byte),
  }
end

---@param pattern string
---@return table[]
local function query_definition(pattern)
  local params = util.make_position_params()
  local results_by_client, err = lsp.buf_request_sync(0, ms.textDocument_definition, params, 1000)
  if err then
    return {}
  end
  local results = {}

  --- @param range lsp.Range
  --- @param uri string
  --- @param offset_encoding string
  local add = function(range, uri, offset_encoding)
    table.insert(results, mk_tag_item(pattern, range, uri, offset_encoding))
  end

  for client_id, lsp_results in pairs(assert(results_by_client)) do
    local client = lsp.get_client_by_id(client_id)
    local offset_encoding = client and client.offset_encoding or 'utf-16'
    local result = lsp_results.result or {}
    if result.range then -- Location
      add(result.range, result.uri, offset_encoding)
    else
      result = result --[[@as (lsp.Location[]|lsp.LocationLink[])]]
      for _, item in pairs(result) do
        if item.range then -- Location
          add(item.range, item.uri, offset_encoding)
        else -- LocationLink
          add(item.targetSelectionRange, item.targetUri, offset_encoding)
        end
      end
    end
  end
  return results
end

---@param pattern string
---@return table[]
local function query_workspace_symbols(pattern)
  local results_by_client, err =
    lsp.buf_request_sync(0, ms.workspace_symbol, { query = pattern }, 1000)
  if err then
    return {}
  end
  local results = {}
  for client_id, responses in pairs(assert(results_by_client)) do
    local client = lsp.get_client_by_id(client_id)
    local offset_encoding = client and client.offset_encoding or 'utf-16'
    local symbols = responses.result --[[@as lsp.SymbolInformation[]|nil]]
    for _, symbol in pairs(symbols or {}) do
      local loc = symbol.location
      local item = mk_tag_item(symbol.name, loc.range, loc.uri, offset_encoding)
      item.kind = lsp.protocol.SymbolKind[symbol.kind] or 'Unknown'
      table.insert(results, item)
    end
  end
  return results
end

local function tagfunc(pattern, flags)
  local matches = string.match(flags, 'c') and query_definition(pattern)
    or query_workspace_symbols(pattern)
  -- fall back to tags if no matches
  return #matches > 0 and matches or vim.NIL
end

return tagfunc
