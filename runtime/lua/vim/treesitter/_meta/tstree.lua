---@meta
-- luacheck: no unused args
error('Cannot require a meta file')

--- @brief A "treesitter tree" represents the parsed contents of a buffer, which can be
--- used to perform further analysis. It is a |userdata| reference to an object
--- held by the treesitter library.
---
--- An instance `TSTree` of a treesitter tree supports the following methods.

---@nodoc
---@class TSTree: userdata
local TSTree = {} -- luacheck: no unused

--- Return the root node of this tree.
---@return TSNode
function TSTree:root() end

-- stylua: ignore
---@param start_byte integer
---@param end_byte_old integer
---@param end_byte_new integer
---@param start_row integer
---@param start_col integer
---@param end_row_old integer
---@param end_col_old integer
---@param end_row_new integer
---@param end_col_new integer
---@return TSTree
---@nodoc
function TSTree:edit(start_byte, end_byte_old, end_byte_new, start_row, start_col, end_row_old, end_col_old, end_row_new, end_col_new) end

--- Returns a copy of the `TSTree`.
---@return TSTree
function TSTree:copy() end

---@param include_bytes true
---@return Range6[]
---@nodoc
function TSTree:included_ranges(include_bytes) end

---@param include_bytes false
---@return Range4[]
---@nodoc
function TSTree:included_ranges(include_bytes) end
