---@meta

-- luacheck: no unused args

--- Invokes |vim-function| or |user-function| {func} with arguments {...}.
--- See also |vim.fn|.
--- Equivalent to:
---
--- ```lua
--- vim.fn[func]({...})
--- ```
---
--- @param func string
--- @param ... any
--- @return any
function vim.call(func, ...) end

--- Renamed to `vim.text.diff`, remove at Nvim 1.0
---@deprecated
---@param a string First string to compare
---@param b string Second string to compare
---@param opts? vim.text.diff.Opts
---@return string|integer[][]? # See {opts.result_type}. `nil` if {opts.on_hunk} is given.
function vim.diff(a, b, opts) end
