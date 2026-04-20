--- @meta
-- This file is NOT generated, edit it directly.
error('Cannot require a meta file')

--- @alias elem_or_list<T> T|T[]

---@type uv
vim.uv = ...

--- LuaLS fallback surface for the richer iterator annotations in `vim.iter`.
--- EmmyLua reads the precise generics from `runtime/lua/vim/iter.lua`; LuaLS uses
--- these broader shapes for downstream type-checking.
--- @class vim.Iter
--- @field filter fun(self: vim.Iter, f: fun(...): boolean): vim.Iter
--- @field unique fun(self: vim.Iter, key?: fun(...): any): vim.Iter
--- @field flatten fun(self: vim.Iter, depth?: integer): vim.IterArray
--- @field map fun(self: vim.Iter, f: fun(...): ...): vim.Iter
--- @field each fun(self: vim.Iter, f: fun(...)): nil
--- @field totable fun(self: vim.Iter): table
--- @field join fun(self: vim.Iter, delim: string): string
--- @field fold fun(self: vim.Iter, init: any, f: fun(acc: any, ...): any): any
--- @field next fun(self: vim.Iter): any
--- @field rev fun(self: vim.Iter): vim.IterArray
--- @field peek fun(self: vim.Iter): any
--- @field find fun(self: vim.Iter, f: any): any
--- @field rfind fun(self: vim.Iter, f: any): any
--- @field take fun(self: vim.Iter, n: integer|fun(...): boolean): vim.Iter
--- @field pop fun(self: vim.Iter): any
--- @field rpeek fun(self: vim.Iter): any
--- @field skip fun(self: vim.Iter, n: integer|fun(...): boolean): vim.Iter
--- @field rskip fun(self: vim.Iter, n: integer): vim.IterArray
--- @field nth fun(self: vim.Iter, n: integer): any
--- @field slice fun(self: vim.Iter, first: integer, last: integer): vim.IterArray
--- @field any fun(self: vim.Iter, pred: fun(...): boolean): boolean
--- @field all fun(self: vim.Iter, pred: fun(...): boolean): boolean
--- @field last fun(self: vim.Iter): any
--- @field enumerate fun(self: vim.Iter): vim.Iter

--- @class vim.IterArray : vim.Iter
--- @field filter fun(self: vim.IterArray, f: fun(...): boolean): vim.IterArray
--- @field unique fun(self: vim.IterArray, key?: fun(...): any): vim.IterArray
--- @field flatten fun(self: vim.IterArray, depth?: integer): vim.IterArray
--- @field map fun(self: vim.IterArray, f: fun(...): ...): vim.IterArray
--- @field totable fun(self: vim.IterArray): table
--- @field fold fun(self: vim.IterArray, init: any, f: fun(acc: any, ...): any): any
--- @field next fun(self: vim.IterArray): any
--- @field rev fun(self: vim.IterArray): vim.IterArray
--- @field peek fun(self: vim.IterArray): any
--- @field find fun(self: vim.IterArray, f: any): any
--- @field rfind fun(self: vim.IterArray, f: any): any
--- @field take fun(self: vim.IterArray, n: integer|fun(...): boolean): vim.IterArray
--- @field pop fun(self: vim.IterArray): any
--- @field rpeek fun(self: vim.IterArray): any
--- @field skip fun(self: vim.IterArray, n: integer|fun(...): boolean): vim.IterArray
--- @field rskip fun(self: vim.IterArray, n: integer): vim.IterArray
--- @field slice fun(self: vim.IterArray, first: integer, last: integer): vim.IterArray
--- @field last fun(self: vim.IterArray): any
--- @field enumerate fun(self: vim.IterArray): vim.IterArray

--- @class vim.IterModule
--- @operator call: fun(src: any, ...): vim.Iter

--- The following modules are loaded specially in _init_packages.lua

vim.F = require('vim.F')
vim._watch = require('vim._watch')
vim.diagnostic = require('vim.diagnostic')
vim.filetype = require('vim.filetype')
vim.fs = require('vim.fs')
vim.func = require('vim.func')
vim.glob = require('vim.glob')
vim.health = require('vim.health')
vim.hl = require('vim.hl')
local iter = require('vim.iter')
-- `require('vim.iter')` carries the richer EmmyLua generic surface. Force
-- LuaLS onto the fallback module shape above so `make luals` stays clean.
---@cast iter vim.IterModule
vim.iter = iter
vim.keymap = require('vim.keymap')
vim.loader = require('vim.loader')
vim.lsp = require('vim.lsp')
vim.net = require('vim.net')
vim.pack = require('vim.pack')
vim.pos = require('vim.pos')
vim.range = require('vim.range')
vim.re = require('vim.re')
vim.secure = require('vim.secure')
vim.snippet = require('vim.snippet')
vim.text = require('vim.text')
vim.treesitter = require('vim.treesitter')
vim.tty = require('vim.tty')
vim.ui = require('vim.ui')
vim.version = require('vim.version')

local uri = require('vim.uri')

vim.uri_from_fname = uri.uri_from_fname
vim.uri_from_bufnr = uri.uri_from_bufnr
vim.uri_to_fname = uri.uri_to_fname
vim.uri_to_bufnr = uri.uri_to_bufnr

vim.provider = require('vim.provider')
