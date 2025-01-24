---@meta
-- luacheck: no unused args
error('Cannot require a meta file')

---@alias TSLoggerCallback fun(logtype: 'parse'|'lex', msg: string)

---@class TSParser: userdata
---@field parse fun(self: TSParser, tree: TSTree?, source: integer|string, include_bytes: boolean): TSTree, (Range4|Range6)[]
---@field reset fun(self: TSParser)
---@field included_ranges fun(self: TSParser, include_bytes: boolean?): integer[]
---@field set_included_ranges fun(self: TSParser, ranges: (Range6|TSNode)[])
---@field set_timeout fun(self: TSParser, timeout: integer)
---@field timeout fun(self: TSParser): integer
---@field _set_logger fun(self: TSParser, lex: boolean, parse: boolean, cb: TSLoggerCallback)
---@field _logger fun(self: TSParser): TSLoggerCallback

---@class TSQuery: userdata
---@field inspect fun(self: TSQuery): TSQueryInfo

---@class (exact) TSQueryInfo
---@field captures string[]
---@field patterns table<integer, (integer|string)[][]>
---
---@class TSLangInfo
---@field fields string[]
---@field symbols table<string,boolean>
---@field _wasm boolean
---@field _abi_version integer

--- @param lang string
--- @return TSLangInfo
vim._ts_inspect_language = function(lang) end

---@return integer
vim._ts_get_language_version = function() end

--- @param path string
--- @param lang string
--- @param symbol_name? string
vim._ts_add_language_from_object = function(path, lang, symbol_name) end

--- @param path string
--- @param lang string
vim._ts_add_language_from_wasm = function(path, lang) end

---@return integer
vim._ts_get_minimum_language_version = function() end

---@param lang string Language to use for the query
---@param query string Query string in s-expr syntax
---@return TSQuery
vim._ts_parse_query = function(lang, query) end

---@param lang string
---@return TSParser
vim._create_ts_parser = function(lang) end

--- @class TSQueryMatch: userdata
--- @field captures fun(self: TSQueryMatch): table<integer,TSNode[]>
local TSQueryMatch = {} -- luacheck: no unused

--- @return integer match_id
--- @return integer pattern_index
function TSQueryMatch:info() end

--- @class TSQueryCursor: userdata
--- @field remove_match fun(self: TSQueryCursor, id: integer)
local TSQueryCursor = {} -- luacheck: no unused

--- @return integer capture
--- @return TSNode captured_node
--- @return TSQueryMatch match
function TSQueryCursor:next_capture() end

--- @return TSQueryMatch match
function TSQueryCursor:next_match() end

--- @param node TSNode
--- @param query TSQuery
--- @param start integer?
--- @param stop integer?
--- @param opts? { max_start_depth?: integer, match_limit?: integer}
--- @return TSQueryCursor
function vim._create_ts_querycursor(node, query, start, stop, opts) end
