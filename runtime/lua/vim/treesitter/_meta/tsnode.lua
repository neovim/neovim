---@meta
-- luacheck: no unused args
error('Cannot require a meta file')

--- @brief A "treesitter node" represents one specific element of the parsed contents of a buffer,
--- which can be captured by a |Query| for, e.g., highlighting. It is a |userdata| reference to an
--- object held by the treesitter library.
---
--- An instance `TSNode` of a treesitter node supports the following methods.

---@nodoc
---@class TSNode: userdata
local TSNode = {} -- luacheck: no unused

--- Get the node's immediate parent.
--- Prefer |TSNode:child_with_descendant()|
--- for iterating over the node's ancestors.
--- @return TSNode?
function TSNode:parent() end

--- Get the node's next sibling.
--- @return TSNode?
function TSNode:next_sibling() end

--- Get the node's previous sibling.
--- @return TSNode?
function TSNode:prev_sibling() end

--- Get the node's next named sibling.
--- @return TSNode?
function TSNode:next_named_sibling() end

--- Get the node's previous named sibling.
--- @return TSNode?
function TSNode:prev_named_sibling() end

--- Iterates over all the direct children of {TSNode}, regardless of whether
--- they are named or not.
--- Returns the child node plus the eventual field name corresponding to this
--- child node.
--- @return fun(): TSNode, string
function TSNode:iter_children() end

--- Returns a list of all the node's children that have the given field name.
--- @param name string
--- @return TSNode[]
function TSNode:field(name) end

--- Get the node's number of children.
--- @return integer
function TSNode:child_count() end

--- Get the node's child at the given {index}, where zero represents the first
--- child.
--- @param index integer
--- @return TSNode?
function TSNode:child(index) end

--- Get the node's number of named children.
--- @return integer
function TSNode:named_child_count() end

--- Returns a list of the node's named children.
--- @return TSNode[]
function TSNode:named_children() end

--- Check if the node has any of the given node types as its ancestor.
--- @param node_types string[]
--- @return boolean
function TSNode:__has_ancestor(node_types) end

--- Get the node's named child at the given {index}, where zero represents the
--- first named child.
--- @param index integer
--- @return TSNode?
function TSNode:named_child(index) end

--- Get the node's child that contains {descendant} (includes {descendant}).
---
--- For example, with the following node hierarchy:
---
--- ```
--- a -> b -> c
---
--- a:child_with_descendant(c) == b
--- a:child_with_descendant(b) == b
--- a:child_with_descendant(a) == nil
--- ```
--- @param descendant TSNode
--- @return TSNode?
function TSNode:child_with_descendant(descendant) end

--- Get the node's start position. Return three values: the row, column and
--- total byte count (all zero-based).
--- @return integer, integer, integer
function TSNode:start() end

--- Get the node's end position. Return three values: the row, column and
--- total byte count (all zero-based).
--- @return integer, integer, integer
function TSNode:end_() end

--- Get the range of the node.
---
--- Return four or six values:
---
--- - start row
--- - start column
--- - start byte (if {include_bytes} is `true`)
--- - end row
--- - end column
--- - end byte (if {include_bytes} is `true`)
--- @param include_bytes false?
--- @return integer, integer, integer, integer
--- @overload fun(self: TSNode, include_bytes: true): integer, integer, integer, integer, integer, integer
function TSNode:range(include_bytes) end

--- Get the node's type as a string.
--- @return string
function TSNode:type() end

--- Get the node's type as a numerical id.
--- @return integer
function TSNode:symbol() end

--- Check if the node is named. Named nodes correspond to named rules in the
--- grammar, whereas anonymous nodes correspond to string literals in the
--- grammar.
--- @return boolean
function TSNode:named() end

--- Check if the node is missing. Missing nodes are inserted by the parser in
--- order to recover from certain kinds of syntax errors.
--- @return boolean
function TSNode:missing() end

--- Check if the node is extra. Extra nodes represent things like comments,
--- which are not required by the grammar but can appear anywhere.
--- @return boolean
function TSNode:extra() end

--- Check if a syntax node has been edited.
--- @return boolean
function TSNode:has_changes() end

--- Check if the node is a syntax error or contains any syntax errors.
--- @return boolean
function TSNode:has_error() end

--- Get an S-expression representing the node as a string.
--- @return string
function TSNode:sexpr() end

--- Get a unique identifier for the node inside its own tree.
---
--- No guarantees are made about this identifier's internal representation,
--- except for being a primitive Lua type with value equality (so not a
--- table). Presently it is a (non-printable) string.
---
--- Note: The `id` is not guaranteed to be unique for nodes from different
--- trees.
--- @return string
function TSNode:id() end

--- Get the |TSTree| of the node.
--- @return TSTree
function TSNode:tree() end

--- Get the smallest node within this node that spans the given range of (row,
--- column) positions
--- @param start_row integer
--- @param start_col integer
--- @param end_row integer
--- @param end_col integer
--- @return TSNode?
function TSNode:descendant_for_range(start_row, start_col, end_row, end_col) end

--- Get the smallest named node within this node that spans the given range of
--- (row, column) positions
--- @param start_row integer
--- @param start_col integer
--- @param end_row integer
--- @param end_col integer
--- @return TSNode?
function TSNode:named_descendant_for_range(start_row, start_col, end_row, end_col) end

--- Check if {node} refers to the same node within the same tree.
--- @param node TSNode
--- @return boolean
function TSNode:equal(node) end

--- Return the number of bytes spanned by this node.
--- @return integer
function TSNode:byte_length() end
