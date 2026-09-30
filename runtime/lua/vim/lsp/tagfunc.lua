local lsp = vim.lsp
local api = vim.api
local util = lsp.util

---@param name string
---@param range lsp.Range
---@param uri string
---@param position_encoding 'utf-8'|'utf-16'|'utf-32'
---@return {name: string, filename: string, cmd: string, kind?: string}
local function mk_tag_item(name, range, uri, position_encoding)
  local bufnr = vim.uri_to_bufnr(uri)
  -- This is get_line_byte_from_position is 0-indexed, call cursor expects a 1-indexed position
  local pos = vim.pos.lsp(bufnr, range.start, position_encoding)
  local byte = pos.col + 1
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

  local request_results, _ = lsp.buf_request_sync(bufnr, 'textDocument/definition', function(client)
    return util.make_position_params(win, client.offset_encoding)
  end)

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
    lsp.buf_request_sync(0, 'workspace/symbol', { query = pattern }, 1000)
  if err then
    return {}
  end
  local results = {}
  for client_id, responses in pairs(assert(results_by_client)) do
    local client = lsp.get_client_by_id(client_id)
    local position_encoding = client and client.offset_encoding or 'utf-16'
    local symbols = responses.result --[[@as lsp.SymbolInformation[]?]]
    if symbols then
      for _, symbol in pairs(symbols) do
        local loc = symbol.location
        local item = mk_tag_item(symbol.name, loc.range, loc.uri, position_encoding)
        item.kind = lsp.protocol.SymbolKind[symbol.kind] or 'Unknown'
        table.insert(results, item)
      end
    end
  end
  return results
end

--- Provides an interface between the built-in client and 'tagfunc'.
---
--- When used with normal mode commands (e.g. |CTRL-]|) this will invoke
--- the "textDocument/definition" LSP method to find the tag under the cursor.
--- Otherwise, uses "workspace/symbol". If no results are returned from
--- any LSP servers, falls back to using built-in tags.
---
---@param pattern string Pattern used to find a workspace symbol
---@param flags string See |tag-function|
---
---@return table[]|vim.NIL tags A list of matching tags, or `vim.NIL` to use the built-in tags.
local function tagfunc(pattern, flags)
  -- avoid definition/symbol queries for insert completion
  if string.match(flags, 'i') then
    return vim.NIL
  end
  local matches = string.match(flags, 'c') and query_definition(pattern)
    or query_workspace_symbols(pattern)
  -- fall back to tags if no matches
  return #matches > 0 and matches or vim.NIL
end

return tagfunc
