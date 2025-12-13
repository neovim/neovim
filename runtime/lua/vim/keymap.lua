local keymap = {}

--- Table of |:map-arguments|.
--- Same as |nvim_set_keymap()| {opts}, except:
--- - {replace_keycodes} defaults to `true` if "expr" is `true`.
---
--- Also accepts:
--- @class vim.keymap.set.Opts : vim.api.keyset.keymap
--- @inlinedoc
---
--- Creates buffer-local mapping, `0` or `true` for current buffer.
--- @field buf? integer|boolean
--- @field buffer? integer|boolean Deprecated: use `buf`
---
--- Make the mapping recursive. Inverse of {noremap}.
--- (Default: `false`)
--- @field remap? boolean

--- Defines a |mapping| of |keycodes| to a function or keycodes.
---
--- Examples:
---
--- ```lua
--- -- Map "x" to a Lua function:
--- vim.keymap.set('n', 'x', function() print('real lua function') end)
--- -- Map "<leader>x" to multiple modes for the current buffer:
--- vim.keymap.set({'n', 'v'}, '<leader>x', vim.lsp.buf.references, { buf = true })
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
--- ```
---
---@param mode string|string[] Mode "short-name" (see |nvim_set_keymap()|), or a list thereof.
---@param lhs string           Left-hand side |{lhs}| of the mapping.
---@param rhs string|function  Right-hand side |{rhs}| of the mapping, can be a Lua function.
---@param opts? vim.keymap.set.Opts
---
---@see |nvim_set_keymap()|
---@see |maparg()|
---@see |mapcheck()|
---@see |mapset()|
function keymap.set(mode, lhs, rhs, opts)
  vim.validate('mode', mode, { 'string', 'table' })
  vim.validate('lhs', lhs, 'string')
  vim.validate('rhs', rhs, { 'string', 'function' })
  vim.validate('opts', opts, 'table', true)

  opts = vim.deepcopy(opts or {}, true)

  ---@cast mode string[]
  mode = type(mode) == 'string' and { mode } or mode

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

  -- Handle buf/buffer option
  -- TODO(deprecate): emit warning for opts.buffer in 0.15, remove in 0.16
  if opts.buf and opts.buffer then
    error('cannot use both "buf" and "buffer" options')
  end
  if opts.buffer then
    opts.buf = opts.buffer
  end
  opts.buffer = nil ---@diagnostic disable-line: inject-field

  if opts.buf then
    local bufnr = opts.buf == true and 0 or opts.buf --[[@as integer]]
    opts.buf = nil ---@type integer?
    for _, m in ipairs(mode) do
      vim.api.nvim_buf_set_keymap(bufnr, m, lhs, rhs, opts)
    end
  else
    opts.buf = nil
    for _, m in ipairs(mode) do
      vim.api.nvim_set_keymap(m, lhs, rhs, opts)
    end
  end
end

--- @class vim.keymap.del.Opts
--- @inlinedoc
---
--- Remove a mapping from the given buffer.
--- When `0` or `true`, use the current buffer.
--- @field buf? integer|boolean
--- @field buffer? integer|boolean Deprecated: use `buf`

--- Remove an existing mapping.
--- Examples:
---
--- ```lua
--- vim.keymap.del('n', 'lhs')
---
--- vim.keymap.del({'n', 'i', 'v'}, '<leader>w', { buf = 5 })
--- ```
---
---@param modes string|string[]
---@param lhs string
---@param opts? vim.keymap.del.Opts
---@see |vim.keymap.set()|
function keymap.del(modes, lhs, opts)
  vim.validate('mode', modes, { 'string', 'table' })
  vim.validate('lhs', lhs, 'string')
  vim.validate('opts', opts, 'table', true)

  opts = opts or {}
  modes = type(modes) == 'string' and { modes } or modes
  --- @cast modes string[]

  -- Handle buf/buffer option
  -- TODO(deprecate): emit warning for opts.buffer in 0.15, remove in 0.16
  if opts.buf and opts.buffer then
    error('cannot use both "buf" and "buffer" options')
  end
  if opts.buffer then
    opts.buf = opts.buffer
  end

  local bufnr = false ---@type false|integer
  if opts.buf ~= nil then
    bufnr = opts.buf == true and 0 or opts.buf --[[@as integer]]
  end

  if bufnr == false then
    for _, mode in ipairs(modes) do
      vim.api.nvim_del_keymap(mode, lhs)
    end
  else
    for _, mode in ipairs(modes) do
      vim.api.nvim_buf_del_keymap(bufnr, mode, lhs)
    end
  end
end

return keymap
