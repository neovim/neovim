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
--- @param func fun()
--- @param ... any
function vim.call(func, ...) end
