---@meta

---@class TSNode
---@field id fun(self: TSNode): integer
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
---@field child fun(self: TSNode, integer): TSNode
---@field named_child fun(self: TSNode, integer): TSNode
---@field descendant_for_range fun(self: TSNode, integer, integer, integer, integer): TSNode
---@field named_descendant_for_range fun(self: TSNode, integer, integer, integer, integer): TSNode
---@field parent fun(self: TSNode): TSNode
---@field next_sibling fun(self: TSNode): TSNode
---@field prev_sibling fun(self: TSNode): TSNode
---@field next_named_sibling fun(self: TSNode): TSNode
---@field prev_named_sibling fun(self: TSNode): TSNode
---@field named_children fun(self: TSNode): TSNode[]
---@field has_changes fun(self: TSNode): boolean
---@field equal fun(self: TSNode, other: TSNode): boolean
---@field iter_children fun(self: TSNode): fun(): TSNode, string
local TSNode = {}

---@param query userdata
---@param captures true
---@param start integer
---@param end_ integer
---@return fun(): integer, TSNode, any
function TSNode:_rawquery(query, captures, start, end_) end

---@param query userdata
---@param captures false
---@param start integer
---@param end_ integer
---@return fun(): string, any
function TSNode:_rawquery(query, captures, start, end_) end

---@class TSParser
---@field parse fun(self: TSParser, tree: TSTree?, source: integer|string, include_bytes: boolean?): TSTree, integer[]
---@field reset fun(self: TSParser)
---@field included_ranges fun(self: TSParser, include_bytes: boolean?): integer[]
---@field set_included_ranges fun(self: TSParser, ranges: Range6[])
---@field set_timeout fun(self: TSParser, timeout: integer)
---@field timeout fun(self: TSParser): integer

---@class TSTree
---@field root fun(self: TSTree): TSNode
---@field edit fun(self: TSTree, _: integer, _: integer, _: integer, _: integer, _: integer, _: integer, _: integer, _: integer, _:integer)
---@field copy fun(self: TSTree): TSTree
---@field included_ranges fun(self: TSTree, include_bytes: boolean?): integer[]

---@return integer
vim._ts_get_language_version = function() end

---@return integer
vim._ts_get_minimum_language_version = function() end

---@param lang string
---@return TSParser
vim._create_ts_parser = function(lang) end
