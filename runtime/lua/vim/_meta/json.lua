--- @meta

-- luacheck: no unused args

--- @defgroup vim.json
---
--- This module provides encoding and decoding of Lua objects to and
--- from JSON-encoded strings. Supports |vim.NIL| and |vim.empty_dict()|.

--- Decodes (or "unpacks") the JSON-encoded {str} to a Lua object.
---
--- - Decodes JSON "null" as |vim.NIL| (controllable by {opts}, see below).
--- - Decodes empty object as |vim.empty_dict()|.
--- - Decodes empty array as `{}` (empty Lua table).
---
--- Example:
--- <pre>lua
--- :lua vim.print(vim.json.decode('{"bar":[],"foo":{},"zub":null}'))
--- --> { bar = {}, foo = vim.empty_dict(), zub = vim.NIL }
--- </pre>
--- Parameters: ~
---   • {str}    Stringified JSON data.
---   • {opts}   Options map keys:
---              • luanil: { object: bool, array: bool }
---                • `luanil.object=true` converts `null` in JSON objects to
---                  Lua `nil` instead of `vim.NIL`.
---                • `luanil.array=true` converts `null` in JSON arrays to Lua
---                  `nil` instead of `vim.NIL`.
--- @param str string
--- @param opts? table<string, any>
--- @return any
function vim.json.decode(str, opts) end

--- Encodes (or "packs") Lua object {obj} as JSON in a Lua string.
--- @param obj any
--- @return string
function vim.json.encode(obj) end
