local api = vim.api
local query = vim.treesitter.query

---@class (private) vim.treesitter.highlighter.Query
---@field private _query vim.treesitter.Query?
---@field private lang string
---@field private hl_cache table<integer,integer>
local TSHighlighterQuery = {}
TSHighlighterQuery.__index = TSHighlighterQuery

---@param lang string
---@param query_string string?
---@return vim.treesitter.highlighter.Query
function TSHighlighterQuery.new(lang, query_string)
  local self = setmetatable({}, TSHighlighterQuery)
  self.lang = lang
  self.hl_cache = {}

  if query_string then
    self._query = query.parse(lang, query_string)
  else
    self._query = query.get(lang, 'highlights')
  end

  return self
end

---@package
---@param capture integer
---@return integer?
function TSHighlighterQuery:get_hl_from_capture(capture)
  if not self.hl_cache[capture] then
    local name = self._query.captures[capture]
    local id = 0
    if not vim.startswith(name, '_') then
      id = api.nvim_get_hl_id_by_name('@' .. name .. '.' .. self.lang)
    end
    self.hl_cache[capture] = id
  end

  return self.hl_cache[capture]
end

---@package
--- @return vim.treesitter.Query
function TSHighlighterQuery:query()
  return self._query
end

return TSHighlighterQuery
