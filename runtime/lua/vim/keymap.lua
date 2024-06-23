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
--- @field buffer? integer|boolean
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
--- vim.keymap.set('n', 'x', function() print("real lua function") end)
--- -- Map "<leader>x" to multiple modes for the current buffer:
--- vim.keymap.set({'n', 'v'}, '<leader>x', vim.lsp.buf.references, { buffer = true })
--- -- Map <Tab> to an expression (|:map-<expr>|):
--- vim.keymap.set('i', '<Tab>', function()
---   return vim.fn.pumvisible() == 1 and "<C-n>" or "<Tab>"
--- end, { expr = true })
--- -- Map "[%%" to a <Plug> mapping:
--- vim.keymap.set('n', '[%%', '<Plug>(MatchitNormalMultiBackward)')
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
---@overload fun(opts: vim.keymap.get.Return)
function keymap.set(mode, lhs, rhs, opts)
  if type(mode) == 'table' and not lhs then
    ---@type vim.keymap.get.Return
    local keymap_get_opts = mode
    mode = keymap_get_opts.mode
    lhs = keymap_get_opts.lhs
    rhs = keymap_get_opts.rhs
    opts = {
      expr = keymap_get_opts.opts.expr,
      buffer = keymap_get_opts.opts.buffer,
      desc = keymap_get_opts.opts.desc,
    }
  end
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

  if opts.buffer then
    local bufnr = opts.buffer == true and 0 or opts.buffer --[[@as integer]]
    opts.buffer = nil ---@type integer?
    for _, m in ipairs(mode) do
      vim.api.nvim_buf_set_keymap(bufnr, m, lhs, rhs, opts)
    end
  else
    opts.buffer = nil
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
--- @field buffer? integer|boolean

--- Remove an existing mapping.
--- Examples:
---
--- ```lua
--- vim.keymap.del('n', 'lhs')
---
--- vim.keymap.del({'n', 'i', 'v'}, '<leader>w', { buffer = 5 })
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

  local buffer = false ---@type false|integer
  if opts.buffer ~= nil then
    buffer = opts.buffer == true and 0 or opts.buffer --[[@as integer]]
  end

  if buffer == false then
    for _, mode in ipairs(modes) do
      vim.api.nvim_del_keymap(mode, lhs)
    end
  else
    for _, mode in ipairs(modes) do
      vim.api.nvim_buf_del_keymap(buffer, mode, lhs)
    end
  end
end

--- @class vim.keymap.get.Filter
--- @inlinedoc
---
--- Lhs of mapping
--- @field lhs? string
---
--- Patter to match against rhs of mapping
--- @field rhs? string
---
--- Get a mapping for a certain buffer
--- @field buffer? integer|boolean

--- @class vim.keymap.get.Return.Opts
--- @inlinedoc
---
--- If they mapping is an expr mapping
--- @field expr boolean
---
--- If they mapping is a buffer-local mapping
--- @field buffer boolean
---
--- Description of the mapping
--- @field desc? string

--- @class vim.keymap.get.Return
--- @inlinedoc
---
--- Lhs of mapping
--- @field lhs string
---
--- Rhs of mapping (can be callback)
--- @field rhs string|function
--- Mode of the mapping
--- @field mode string
---
--- Get a mapping for a certain buffer
--- @field opts? vim.keymap.get.Return.Opts

--- Gets mappings in a format easily usable for vim.keymap.set
--- Examples:
---
--- ```lua
--- -- Gets all normal mode mappings
--- vim.keymap.get('n')
---
--- -- Gets a mapping which maps to a certain rhs
--- vim.keymap.get('n', { rhs = "<Plug>(MyAmazingFunction)" })
--- ```
---
---@param modes string|string[]
---@param filter? vim.keymap.get.Filter
---@return vim.keymap.get.Return[]
function keymap.get(modes, filter)
  filter = filter or {}

  vim.validate('modes', modes, { 'string', 'table' })
  vim.validate('filter', filter, { 'table' })

  modes = type(modes) == 'string' and { modes } or modes
  --- @cast modes string[]

  local mappings = {}
  for _, mode in ipairs(modes) do
    if filter.buffer then
      table.insert(
        mappings,
        ---@diagnostic disable-next-line: param-type-mismatch
        vim.api.nvim_buf_get_keymap(filter.buffer == true and 0 or filter.buffer, mode)
      )
    else
      table.insert(mappings, vim.api.nvim_get_keymap(mode))
    end
  end

  local function matches(mapping)
    local match = true
    if filter.lhs then
      match = match and vim.keycode(filter.lhs) == vim.keycode(mapping.lhs)
    end
    if filter.rhs then
      match = match and vim.keycode(filter.rhs) == vim.keycode(mapping.rhs)
    end
    return match
  end
  return vim
    .iter(mappings)
    :flatten()
    :filter(function(mapping)
      return matches(mapping)
    end)
    :map(function(mapping)
      ---@type vim.keymap.get.Return
      return {
        lhs = mapping.lhs,
        -- For roundtripping: keymap.set() only accepts "rhs".
        rhs = mapping.callback or mapping.rhs,
        mode = mapping.mode,
        opts = {
          desc = mapping.desc,
          buffer = mapping.buffer == 1,
          expr = mapping.buffer == 1,
        },
      }
    end)
    :totable()
end

return keymap
