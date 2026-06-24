local keymap = {}

--- Table of |:map-arguments|.
--- Same as |nvim_set_keymap()| {opts}, except:
--- - {replace_keycodes} defaults to `true` if "expr" is `true`.
--- - {noremap} is not supported; use {remap} instead (see below).
---
--- Also accepts:
--- @class vim.keymap.set.Opts : vim.api.keyset.keymap
--- @inlinedoc
---
--- Creates buffer-local mapping, `0` for current buffer.
--- @field buf? integer
---
--- Make the mapping recursive. Inverse of {noremap}.
--- (Default: `false`)
--- @field remap? boolean

--- Defines a |mapping| of |keycodes| to a function or keycodes. If `lhs` is a list, defines
--- a mapping for each (mode, lhs) pair.
---
--- Examples:
---
--- ```lua
--- -- Map "x" to a Lua function:
--- vim.keymap.set('n', 'x', function() print('real lua function') end)
--- -- Map "<leader>x" to multiple modes for the current buffer:
--- vim.keymap.set({'n', 'v'}, '<leader>x', vim.lsp.buf.references, { buf = 0 })
--- -- Map <Tab> to an expression (|:map-<expr>|):
--- vim.keymap.set('i', '<Tab>', function()
---   return vim.fn.pumvisible() == 1 and '<C-n>' or '<Tab>'
--- end, { expr = true })
--- -- Map "[%%" to a <Plug> mapping:
--- vim.keymap.set('n', '[%%', '<Plug>(MatchitNormalMultiBackward)')
---
--- -- Use `getregionpos(getpos('v'))` to get the "current visual selection":
--- vim.keymap.set('x', 'M', function()
---   local region = vim.fn.getregionpos(vim.fn.getpos('v'), vim.fn.getpos('.'), {
---     type = 'v',
---     exclusive = false,
---     eol = false,
---   })
---   local line1 = region[1][1][2]
---   local line2 = region[#region][1][2]
---   vim.print({ line1, line2 })
--- end)
---
--- vim.keymap.set({ 'n', 'i' }, { 'a', 'b' }, '<cmd>echom localtime()<cr>')
--- -- ... is the same as:
--- vim.keymap.set('n', 'a', '<cmd>echom localtime()<cr>')
--- vim.keymap.set('i', 'a', '<cmd>echom localtime()<cr>')
--- vim.keymap.set('n', 'b', '<cmd>echom localtime()<cr>')
--- vim.keymap.set('i', 'b', '<cmd>echom localtime()<cr>')
--- ```
---
---@param modes string|string[] Mode "short-name" (see |nvim_set_keymap()|), or a list thereof.
---@param lhs string|string[]  Left-hand side |{lhs}| of the mapping, or a list thereof.
---@param rhs string|function  Right-hand side |{rhs}| of the mapping, can be a Lua function.
---@param opts? vim.keymap.set.Opts
---
---@see |nvim_set_keymap()|
---@see |maparg()|
---@see |mapcheck()|
---@see |mapset()|
function keymap.set(modes, lhs, rhs, opts)
  vim.validate('modes', modes, { 'string', 'table' })
  vim.validate('lhs', lhs, { 'string', 'table' })
  vim.validate('rhs', rhs, { 'string', 'function' })
  vim.validate('opts', opts, 'table', true)

  opts = vim.deepcopy(opts or {}, true)

  ---@cast modes string[]
  modes = type(modes) == 'string' and { modes } or modes
  ---@cast lhs string[]
  lhs = type(lhs) == 'string' and { lhs } or lhs

  if opts.expr and opts.replace_keycodes ~= false then
    opts.replace_keycodes = true
  end

  if opts.remap == nil then
    -- default remap value is false
    opts.noremap = true
  else
    -- remaps behavior is opposite of noremap option.
    opts.noremap = not opts.remap
    opts.remap = nil ---@type boolean?
  end

  if type(rhs) == 'function' then
    opts.callback = rhs
    rhs = ''
  end

  local buf = opts.buf
  opts.buf = nil
  --- @cast opts +{buffer?:integer|boolean}
  if opts.buffer ~= nil then
    -- TODO(skewb1k): soft-deprecate `buffer` option in 0.13, remove in 0.15.
    assert(buf == nil, "Conflict: 'buf' not allowed with 'buffer'")
    buf = opts.buffer == true and 0 or opts.buffer --[[@as integer?]]
    opts.buffer = nil
  end

  for _, m in ipairs(modes) do
    for _, l in ipairs(lhs) do
      if buf then
        vim.api.nvim_buf_set_keymap(buf, m, l, rhs, opts)
      else
        vim.api.nvim_set_keymap(m, l, rhs, opts)
      end
    end
  end
end

--- @class vim.keymap.del.Opts
--- @inlinedoc
---
--- Remove a mapping from the given buffer. `0` for current.
--- @field buf? integer

--- Removes a mapping, or removes each (mode, lhs) pair if `lhs` is a list.
--- Examples:
---
--- ```lua
--- vim.keymap.del('n', 'lhs')
--- vim.keymap.del({'n', 'i', 'v'}, '<leader>w', { buf = 5 })
--- ```
---
---@param modes string|string[]
---@param lhs string|string[]
---@param opts? vim.keymap.del.Opts
---@see |vim.keymap.set()|
function keymap.del(modes, lhs, opts)
  vim.validate('mode', modes, { 'string', 'table' })
  vim.validate('lhs', lhs, { 'string', 'table' })
  vim.validate('opts', opts, 'table', true)

  opts = opts or {}

  --- @cast modes string[]
  modes = type(modes) == 'string' and { modes } or modes
  ---@cast lhs string[]
  lhs = type(lhs) == 'string' and { lhs } or lhs

  local buf = opts.buf
  --- @cast opts +{buffer?:integer|boolean}
  if opts.buffer ~= nil then
    -- TODO(skewb1k): soft-deprecate `buffer` option in 0.13, remove in 0.15.
    assert(opts.buf == nil, "Conflict: 'buf' not allowed with 'buffer'")
    buf = opts.buffer == true and 0 or opts.buffer --[[@as integer?]]
  end

  for _, m in ipairs(modes) do
    for _, l in ipairs(lhs) do
      if buf then
        vim.api.nvim_buf_del_keymap(buf, m, l)
      else
        vim.api.nvim_del_keymap(m, l)
      end
    end
  end
end

return keymap
