--- @meta

-- luacheck: no unused args

---@nodoc
vim.mpack = {}

---@class vim.mpack.Unpacker

---@class vim.mpack.Packer

---@class vim.mpack.Session
---@field receive fun(self: vim.mpack.Session, str: string): any[]
---@field request fun(self: vim.mpack.Session, method: string, ...: any): string
---@field reply fun(self: vim.mpack.Session, id: integer, err: any, result: any): string
---@field notify fun(self: vim.mpack.Session, method: string, ...: any): string

---@class vim.mpack.NIL

--- @brief
---
--- This module provides encoding and decoding of Lua objects to and
--- from msgpack-encoded strings. Supports |vim.NIL| and |vim.empty_dict()|.

--- Decodes (or "unpacks") the msgpack-encoded {str} to a Lua object.
--- @param str string
--- @return any
function vim.mpack.decode(str) end

--- Encodes (or "packs") Lua object {obj} as msgpack in a Lua string.
--- @param obj any
--- @return string
function vim.mpack.encode(obj) end

--- Creates a reusable msgpack decoder object.
--- @return vim.mpack.Unpacker
function vim.mpack.Unpacker() end

--- Creates a reusable msgpack encoder object.
--- @return vim.mpack.Packer
function vim.mpack.Packer() end

--- Creates a msgpack-rpc session helper.
--- @return vim.mpack.Session
function vim.mpack.Session() end

--- Sentinel value representing msgpack nil.
--- @type vim.mpack.NIL
vim.mpack.NIL = ...
