---@meta
-- luacheck: no unused args
error('Cannot require a meta file')

-- This could be documented as a module @brief like tsnode/tstree, but without
-- its own section header documenting it as a class ensures it still gets a helptag.

--- Reference to an object held by the treesitter library that is used as a
--- component of the |vim.treesitter.Query| for language feature support.
--- See |treesitter-query| for more about queries or |vim.treesitter.query.parse()|
--- for an example of how to obtain a query object.
---
---@class TSQuery: userdata
local TSQuery = {} -- luacheck: no unused

--- Get information about the query's patterns and captures.
---@nodoc
---@return TSQueryInfo
function TSQuery:inspect() end

--- Disable a specific capture in this query; once disabled the capture cannot be re-enabled.
--- {capture_name} should not include a leading "@".
---
--- Example: To disable the `@variable.parameter` capture from the vimdoc highlights query:
--- ```lua
--- local query = vim.treesitter.query.get('vimdoc', 'highlights')
--- query.query:disable_capture("variable.parameter")
--- ```
---@param capture_name string
---@param redraw? boolean Restart highlighters using this query (default: true)
function TSQuery:disable_capture(capture_name, redraw) end

--- Disable a specific pattern in this query; once disabled the pattern cannot be re-enabled.
--- The {pattern_index} for a particular match can be obtained with |:Inspect!|, or by reading
--- the source of the query (i.e. from |vim.treesitter.query.get_files()|).
---
--- Example: To disable `|` links in vimdoc but keep other `@markup.link`s highlighted:
--- ```lua
--- local link_pattern = 9 -- from :Inspect!
--- local query = vim.treesitter.query.get('vimdoc', 'highlights')
--- query.query:disable_pattern(link_pattern)
--- ```
---@param pattern_index integer
---@param redraw? boolean Restart highlighters using this query (default: true)
function TSQuery:disable_pattern(pattern_index, redraw) end
