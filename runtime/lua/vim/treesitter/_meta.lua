---@meta
error('Cannot require a meta file')

---@class TSNode: userdata
---@field id fun(self: TSNode): string
---@field tree fun(self: TSNode): TSTree
---@field range fun(self: TSNode, include_bytes: false?): integer, integer, integer, integer
---@field range fun(self: TSNode, include_bytes: true): integer, integer, integer, integer, integer, integer
---@field start fun(self: TSNode): integer, integer, integer
---@field end_ fun(self: TSNode): integer, integer, integer
---@field type fun(self: TSNode): string
---@field symbol fun(self: TSNode): integer
---@field named fun(self: TSNode): boolean
---@field missing fun(self: TSNode): boolean
---@field extra fun(self: TSNode): boolean
---@field child_count fun(self: TSNode): integer
---@field named_child_count fun(self: TSNode): integer
---@field child fun(self: TSNode, index: integer): TSNode?
---@field named_child fun(self: TSNode, index: integer): TSNode?
---@field descendant_for_range fun(self: TSNode, start_row: integer, start_col: integer, end_row: integer, end_col: integer): TSNode?
---@field named_descendant_for_range fun(self: TSNode, start_row: integer, start_col: integer, end_row: integer, end_col: integer): TSNode?
---@field parent fun(self: TSNode): TSNode?
---@field next_sibling fun(self: TSNode): TSNode?
---@field prev_sibling fun(self: TSNode): TSNode?
---@field next_named_sibling fun(self: TSNode): TSNode?
---@field prev_named_sibling fun(self: TSNode): TSNode?
---@field named_children fun(self: TSNode): TSNode[]
---@field has_changes fun(self: TSNode): boolean
---@field has_error fun(self: TSNode): boolean
---@field sexpr fun(self: TSNode): string
---@field equal fun(self: TSNode, other: TSNode): boolean
---@field iter_children fun(self: TSNode): fun(): TSNode, string
---@field field fun(self: TSNode, name: string): TSNode[]
---@field byte_length fun(self: TSNode): integer
local TSNode = {}

---Execute {query} on the node, and enumerates over the node captures. See |Query:iter_captures()|
---A capture is represented by capture_id (index in the query), matched TSNode, and an optional
---table (TSMatch) which is set *only* when a predicate exists in the pattern. For multiple
---captures within the same match, the identical TSMatch object will be returned.
---@param query TSQuery
---@param captures true (see query_next_capture() in treesitter.c)
---@param start? integer
---@param end_? integer
---@param opts? table
---@return fun(): integer, TSNode, vim.treesitter.query.TSMatch iterator of (capture_id, node, match).
function TSNode:_rawquery(query, captures, start, end_, opts) end

---Execute {query} on the node, and enumerates the matches by pattern. See |Query:iter_matches()|.
---@param query TSQuery
---@param captures false (see query_next_match() in treesitter.c)
---@param start? integer
---@param end_? integer
---@param opts? table
---@return fun(): integer, vim.treesitter.query.TSMatch iterator of (pattern_index, match).
---  match is a mapping from capture index to matched node (see #24738)
function TSNode:_rawquery(query, captures, start, end_, opts) end

--- Internal data structure for query match. Key is capture_id, value is matched nodes.
---
--- For captures, this table additionally includes the following field to process predicates, see
--- TSNode:_rawquery() and Query:iter_captures():
---     - active?  (boolean) denotes whether the match will be included, according to predicates.
---     - pattern? (integer) id of the pattern associated with this match.
--- TODO: consider removing `match.pattern` to make the data structure consistent
---       between iter_captures() and iter_matches().
---@class TSMatch
---@field pattern? integer
---@field active? boolean
---@field [integer] TSNode[]

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

---@class TSTree: userdata
---@field root fun(self: TSTree): TSNode
---@field edit fun(self: TSTree, _: integer, _: integer, _: integer, _: integer, _: integer, _: integer, _: integer, _: integer, _:integer)
---@field copy fun(self: TSTree): TSTree
---@field included_ranges fun(self: TSTree, include_bytes: true): Range6[]
---@field included_ranges fun(self: TSTree, include_bytes: false): Range4[]

---@class TSQuery: userdata
---@field inspect fun(self: TSQuery): TSQueryInfo

---@class (exact) TSQueryInfo
---@field captures string[]
---@field patterns table<integer, (integer|string)[][]>

---@return integer
vim._ts_get_language_version = function() end

---@return integer
vim._ts_get_minimum_language_version = function() end

---@param lang string Language to use for the query
---@param query string Query string in s-expr syntax
---@return TSQuery
vim._ts_parse_query = function(lang, query) end

---@param lang string
---@return TSParser
vim._create_ts_parser = function(lang) end
