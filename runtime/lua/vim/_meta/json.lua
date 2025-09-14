---@meta

---@nodoc
vim.json = {}

-- luacheck: no unused args

---@brief
---
--- This module provides encoding and decoding of Lua objects to and
--- from JSON-encoded strings. Supports |vim.NIL| and |vim.empty_dict()|.

--- Decodes (or "unpacks") stringified JSON to a Lua object.
---
--- - Decodes JSON "null" as |vim.NIL| (controllable by {opts}, see below).
--- - Decodes empty object as |vim.empty_dict()|.
--- - Decodes empty array as `{}` (empty Lua table).
---
--- Example:
---
--- ```lua
--- vim.print(vim.json.decode('{"bar":[],"foo":{},"zub":null}'))
--- -- { bar = {}, foo = vim.empty_dict(), zub = vim.NIL }
--- ```
---
---@param str string Stringified JSON data.
---@param opts? table<string,any> Options table with keys:
---                               - luanil: (table) Table with keys:
---                                 - object: (boolean) When true, converts `null` in JSON objects
---                                   to Lua `nil` instead of |vim.NIL|.
---                                 - array: (boolean) When true, converts `null` in JSON arrays
---                                   to Lua `nil` instead of |vim.NIL|.
---@return any
function vim.json.decode(str, opts) end

--- Encodes (or "packs") a Lua object to stringified JSON.
---
--- Example: use the `indent` flag to implement a basic 'formatexpr' for JSON, so you can use |gq|
--- with a motion to format JSON in a buffer. (The motion must operate on a valid JSON object.)
---
--- ```lua
--- function _G.fmt_json()
---   local indent = vim.bo.expandtab and (' '):rep(vim.o.shiftwidth) or '\t'
---   local lines = vim.api.nvim_buf_get_lines(0, vim.v.lnum - 1, vim.v.lnum + vim.v.count - 1, true)
---   local o = vim.json.decode(table.concat(lines, '\n'))
---   local stringified = vim.json.encode(o, { indent = indent })
---   lines = vim.split(stringified, '\n')
---   vim.api.nvim_buf_set_lines(0, vim.v.lnum - 1, vim.v.count, true, lines)
--- end
--- vim.o.formatexpr = 'v:lua.fmt_json()'
--- ```
---
---@param obj any
---@param opts? table<string,any> Options table with keys:
---                                 - escape_slash: (boolean) (default false) Escape slash
---                                   characters "/" in string values.
---                                 - indent: (string) (default "") String used for indentation at each nesting level.
---                                   If non-empty enables newlines and a space after colons.
---                                 - sort_keys: (boolean) (default false) Sort object
---                                   keys in alphabetical order.
---@return string
function vim.json.encode(obj, opts) end
