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

--- Returns the Levenshtein distance between the two given string arrays
--- @param a string[]
--- @param b string[]
--- @return number
local function levenshtein_distance(a, b)
  local a_len, b_len = #a, #b
  local matrix = {} --- @type integer[][]

  -- Initialize the matrix
  for i = 1, a_len + 1 do
    matrix[i] = { [1] = i }
  end

  for j = 1, b_len + 1 do
    matrix[1][j] = j
  end

  -- Compute the Levenshtein distance
  for i = 1, a_len do
    for j = 1, b_len do
      local cost = (a[i] == b[j]) and 0 or 1
      matrix[i + 1][j + 1] =
        math.min(matrix[i][j + 1] + 1, matrix[i + 1][j] + 1, matrix[i][j] + cost)
    end
  end

  -- Return the Levenshtein distance
  return matrix[a_len + 1][b_len + 1]
end

--- @param path1 string
--- @param path2 string
--- @return number
local function path_similarity_ratio(path1, path2)
  local parts1 = vim.split(path1, '/', { trimempty = true })
  local parts2 = vim.split(path2, '/', { trimempty = true })
  local distance = levenshtein_distance(parts1, parts2)
  return distance * 2 / (#parts1 + #parts2)
end

---@param pattern string
---@return {name: string, filename: string, cmd: string, kind?: string}[]
local function query_definition(pattern)
  local params = util.make_position_params()
  local results_by_client, err = lsp.buf_request_sync(0, ms.textDocument_definition, params, 1000)

  if err then
    return {}
  end

  ---@type {name: string, filename: string, cmd: string, kind?: string}[]
  local results = {}

  local add = function(range, uri, offset_encoding)
    table.insert(results, mk_tag_item(pattern, range, uri, offset_encoding))
  end

  for client_id, lsp_results in pairs(assert(results_by_client)) do
    local client = lsp.get_client_by_id(client_id)
    local offset_encoding = client and client.offset_encoding or 'utf-16'
    local result = lsp_results.result or {}
    if result.range then -- Location
      add(result.range, result.uri)
    else
      --- @cast result lsp.Location[]|lsp.LocationLink[]
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
---@return {name: string, filename: string, cmd: string, kind?: string}[]
local function query_workspace_symbols(pattern)
  local results_by_client, err =
    lsp.buf_request_sync(0, ms.workspace_symbol, { query = pattern }, 1000)
  if err then
    return {}
  end

  local results = {} --- @type {name: string, filename: string, cmd: string, kind?: string}[]

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

  -- Sort paths based on similarity to the bufname so the most relevant match is used.
  local bufname = vim.api.nvim_buf_get_name(0)
  table.sort(matches, function(a, b)
    return path_similarity_ratio(bufname, a.filename) < path_similarity_ratio(bufname, b.filename)
  end)

  -- fall back to tags if no matches
  return #matches > 0 and matches or vim.NIL
end

return tagfunc
