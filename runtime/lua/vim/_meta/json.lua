---@meta

---@nodoc
vim.json = {}

-- luacheck: no unused args

--- @class vim.json.decode.Opts
--- @inlinedoc
---
--- Convert `null` in JSON objects and/or arrays to Lua `nil` instead of |vim.NIL|.
--- (default: `nil`)
--- @field luanil? { object?: boolean, array?: boolean }

--- @class vim.json.encode.Opts
--- @inlinedoc
---
---  Escape slash characters "/" in string values.
--- (default: `false`)
--- @field escape_slash? boolean
---
---
--- If non-empty, the returned JSON is formatted with newlines and whitespace, where `indent`
--- defines the whitespace at each nesting level.
--- (default: `""`)
--- @field indent? string
---
--- Sort object keys in alphabetical order.
--- (default: `false`)
--- @field sort_keys? boolean

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
---@param opts? vim.json.decode.Opts
---@return any
function vim.json.decode(str, opts) end

--- Encodes (or "packs") a Lua object to stringified JSON.
---
--- Example: Implement a basic 'formatexpr' for JSON, so |gq| with a motion formats JSON in
--- a buffer. (The motion must operate on a valid JSON object.)
---
--- ```lua
--- function _G.fmt_json()
---   local indent = vim.bo.expandtab and (' '):rep(vim.o.shiftwidth) or '\t'
---   local lines = vim.api.nvim_buf_get_lines(0, vim.v.lnum - 1, vim.v.lnum + vim.v.count - 1, true)
---   local o = vim.json.decode(table.concat(lines, '\n'))
---   local stringified = vim.json.encode(o, { indent = indent, sort_keys = true })
---   lines = vim.split(stringified, '\n')
---   vim.api.nvim_buf_set_lines(0, vim.v.lnum - 1, vim.v.count, true, lines)
--- end
--- vim.o.formatexpr = 'v:lua.fmt_json()'
--- ```
---
---@param obj any
---@param opts? vim.json.encode.Opts
---@return string
function vim.json.encode(obj, opts) end
