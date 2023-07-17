---@meta

-- luacheck: no unused args

--- Invokes |vim-function| or |user-function| {func} with arguments {...}.
--- See also |vim.fn|.
--- Equivalent to:
--- <pre>lua
---     vim.fn[func]({...})
--- </pre>
--- @param func fun()
--- @param ... any
function vim.call(func, ...) end
