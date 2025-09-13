local lsp = vim.lsp
local api = vim.api
local util = lsp.util
local ms = lsp.protocol.Methods

---@param name string
---@param range lsp.Range
---@param uri string
---@param position_encoding 'utf-8'|'utf-16'|'utf-32'
---@return {name: string, filename: string, cmd: string, kind?: string}
local function mk_tag_item(name, range, uri, position_encoding)
  local bufnr = vim.uri_to_bufnr(uri)
  -- This is get_line_byte_from_position is 0-indexed, call cursor expects a 1-indexed position
  local byte = util._get_line_byte_from_position(bufnr, range.start, position_encoding) + 1
  return {
    name = name,
    filename = vim.uri_to_fname(uri),
    cmd = string.format([[/\%%%dl\%%%dc/]], range.start.line + 1, byte),
  }
end

---@param pattern string
---@return table[]
local function query_definition(pattern)
  local bufnr = api.nvim_get_current_buf()
  local win = api.nvim_get_current_win()
  local results = {}

  --- @param range lsp.Range
  --- @param uri string
  ---@param position_encoding 'utf-8'|'utf-16'|'utf-32'
  local add = function(range, uri, position_encoding)
    table.insert(results, mk_tag_item(pattern, range, uri, position_encoding))
  end

  local request_results, _ = lsp.buf_request_sync(
    bufnr,
    ms.textDocument_definition,
    function(client)
      return util.make_position_params(win, client.offset_encoding)
    end
  )

  for client_id, res in pairs(request_results or {}) do
    local client = assert(lsp.get_client_by_id(client_id))
    local result = res.result ---@type lsp.Location|lsp.Location[]|lsp.LocationLink[]|nil

    if result then
      local encoding = client.offset_encoding
      -- single Location
      if result.range then
        add(result.range, result.uri, encoding)
      else
        for _, location in ipairs(result) do
          if location.range then -- Location
            add(location.range, location.uri, encoding)
          else -- LocationLink
            add(location.targetSelectionRange, location.targetUri, encoding)
          end
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
    local position_encoding = client and client.offset_encoding or 'utf-16'
    local symbols = responses.result --[[@as lsp.SymbolInformation[]|nil]]
    for _, symbol in pairs(symbols or {}) do
      local loc = symbol.location
      local item = mk_tag_item(symbol.name, loc.range, loc.uri, position_encoding)
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
