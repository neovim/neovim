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

--- Adds a new |mapping|.
--- Examples:
---
--- ```lua
--- -- Map to a Lua function:
--- vim.keymap.set('n', 'lhs', function() print("real lua function") end)
--- -- Map to multiple modes:
--- vim.keymap.set({'n', 'v'}, '<leader>lr', vim.lsp.buf.references, { buffer = true })
--- -- Buffer-local mapping:
--- vim.keymap.set('n', '<leader>w', "<cmd>w<cr>", { silent = true, buffer = 5 })
--- -- Expr mapping:
--- vim.keymap.set('i', '<Tab>', function()
---   return vim.fn.pumvisible() == 1 and "<C-n>" or "<Tab>"
--- end, { expr = true })
--- -- <Plug> mapping:
--- vim.keymap.set('n', '[%%', '<Plug>(MatchitNormalMultiBackward)')
--- ```
---
---@param mode string|string[] Mode short-name, see |nvim_set_keymap()|.
---                            Can also be list of modes to create mapping on multiple modes.
---@param lhs string           Left-hand side |{lhs}| of the mapping.
---@param rhs string|function  Right-hand side |{rhs}| of the mapping, can be a Lua function.
---
---@param opts? vim.keymap.set.Opts
---@see |nvim_set_keymap()|
---@see |maparg()|
---@see |mapcheck()|
---@see |mapset()|
function keymap.set(mode, lhs, rhs, opts)
  vim.validate({
    mode = { mode, { 's', 't' } },
    lhs = { lhs, 's' },
    rhs = { rhs, { 's', 'f' } },
    opts = { opts, 't', true },
  })

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
  vim.validate({
    mode = { modes, { 's', 't' } },
    lhs = { lhs, 's' },
    opts = { opts, 't', true },
  })

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

--- @class vim.keymap.get.Opts
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
---
--- Get a mapping for a certain buffer
--- @field opts? integer|boolean

--- Gets mappings in a format easily usable for vim.keymap.set
--- Examples:
---
--- ```lua
--- -- Gets all normal mode keymaps
--- vim.keymap.get('n')
---
--- -- Gets a mapping which maps to a certain rhs
--- vim.keymap.get('n', { rhs = "<Plug>(MyAmazingFunction)" })
--- ```
---
---@param modes string|string[]
---@param opts? vim.keymap.get.Opts
---@return vim.keymap.get.Return[]
function keymap.get(modes, opts)
  vim.validate({
    mode = { modes, { 's', 't' } },
    opts = { opts, 't', true },
  })

  opts = opts or {}
  modes = type(modes) == 'string' and { modes } or modes
  --- @cast modes string[]

  local keymaps = {}
  for _, mode in ipairs(modes) do
    if opts.buffer then
      table.insert(
        keymaps,
        ---@diagnostic disable-next-line: param-type-mismatch
        vim.api.nvim_buf_get_keymap(opts.buffer == true and 0 or opts.buffer, mode)
      )
    else
      table.insert(keymaps, vim.api.nvim_get_keymap(mode))
    end
  end

  local function matches(mapping)
    local match = true
    if opts.lhs then
      opts.lhs = opts.lhs:gsub('<leader>', vim.g.mapleader or '')
      opts.lhs = opts.lhs:gsub('<localleader>', vim.g.maplocaleader or '')
      match = match and opts.lhs == mapping.lhs
    end
    if opts.rhs then
      opts.rhs = opts.rhs:gsub('<leader>', vim.g.mapleader or '')
      opts.rhs = opts.rhs:gsub('<localleader>', vim.g.maplocaleader or '')
      match = match and string.match(mapping.rhs, opts.rhs)
    end
    return match
  end
  return vim
    .iter(keymaps)
    :flatten()
    :filter(function(mapping)
      return matches(mapping)
    end)
    :map(function(mapping)
      return {
        lhs = mapping.lhs,
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
