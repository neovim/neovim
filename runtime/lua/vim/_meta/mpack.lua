--- @meta

-- luacheck: no unused args

--- @defgroup vim.mpack
---
--- This module provides encoding and decoding of Lua objects to and
--- from msgpack-encoded strings. Supports |vim.NIL| and |vim.empty_dict()|.

--- Decodes (or "unpacks") the msgpack-encoded {str} to a Lua object.
--- @param str string
function vim.mpack.decode(str) end

--- Encodes (or "packs") Lua object {obj} as msgpack in a Lua string.
function vim.mpack.encode(obj) end
