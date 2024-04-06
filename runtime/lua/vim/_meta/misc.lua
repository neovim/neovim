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

--- @class vim.context.mods
--- @field sandbox? boolean
--- @field noautocmd? boolean
--- @field hide? boolean
--- @field horizontal? boolean
--- @field keepalt? boolean
--- @field keepjumps? boolean
--- @field keepmarks? boolean
--- @field keeppatterns? boolean
--- @field lockmarks? boolean
---
--- @field buf? integer
--- @field win? integer

--- @generic R1, R2, R3, R4
--- @param mods vim.context.mods
--- @param f fun(): R1, R2, R3, R4
--- @return R1, R2, R3, R4
function vim._context(mods, f) end
