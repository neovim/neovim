local keymap = {}

--- Adds a new |mapping|.
--- Examples:
--- <pre>lua
---   -- Map to a Lua function:
---   vim.keymap.set('n', 'lhs', function() print("real lua function") end)
---   -- Map to multiple modes:
---   vim.keymap.set({'n', 'v'}, '<leader>lr', vim.lsp.buf.references, { buffer = true })
---   -- Buffer-local mapping:
---   vim.keymap.set('n', '<leader>w', "<cmd>w<cr>", { silent = true, buffer = 5 })
---   -- Expr mapping:
---   vim.keymap.set('i', '<Tab>', function()
---     return vim.fn.pumvisible() == 1 and "<C-n>" or "<Tab>"
---   end, { expr = true })
---   -- <Plug> mapping:
---   vim.keymap.set('n', '[%%', '<Plug>(MatchitNormalMultiBackward)')
--- </pre>
---
---@param mode string|table    Mode short-name, see |nvim_set_keymap()|.
---                            Can also be list of modes to create mapping on multiple modes.
---@param lhs string           Left-hand side |{lhs}| of the mapping.
---@param rhs string|function  Right-hand side |{rhs}| of the mapping, can be a Lua function.
---
---@param opts table|nil Table of |:map-arguments|.
---                      - Same as |nvim_set_keymap()| {opts}, except:
---                        - "replace_keycodes" defaults to `true` if "expr" is `true`.
---                        - "noremap": inverse of "remap" (see below).
---                      - Also accepts:
---                        - "buffer": (number|boolean) Creates buffer-local mapping, `0` or `true`
---                        for current buffer.
---                        - "remap": (boolean) Make the mapping recursive. Inverse of "noremap".
---                        Defaults to `false`.
---@see |nvim_set_keymap()|
function keymap.set(mode, lhs, rhs, opts)
  vim.validate({
    mode = { mode, { 's', 't' } },
    lhs = { lhs, 's' },
    rhs = { rhs, { 's', 'f' } },
    opts = { opts, 't', true },
  })

  opts = vim.deepcopy(opts) or {}
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
    opts.remap = nil
  end

  if type(rhs) == 'function' then
    opts.callback = rhs
    rhs = ''
  end

  if opts.buffer then
    local bufnr = opts.buffer == true and 0 or opts.buffer
    opts.buffer = nil
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

--- Remove an existing mapping.
--- Examples:
--- <pre>lua
---   vim.keymap.del('n', 'lhs')
---
---   vim.keymap.del({'n', 'i', 'v'}, '<leader>w', { buffer = 5 })
--- </pre>
---@param opts table|nil A table of optional arguments:
---                      - "buffer": (number|boolean) Remove a mapping from the given buffer.
---                        When `0` or `true`, use the current buffer.
---@see |vim.keymap.set()|
---
function keymap.del(modes, lhs, opts)
  vim.validate({
    mode = { modes, { 's', 't' } },
    lhs = { lhs, 's' },
    opts = { opts, 't', true },
  })

  opts = opts or {}
  modes = type(modes) == 'string' and { modes } or modes

  local buffer = false
  if opts.buffer ~= nil then
    buffer = opts.buffer == true and 0 or opts.buffer
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

return keymap
