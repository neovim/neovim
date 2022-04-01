local keymap = {}

--- Add a new |mapping|.
--- Examples:
--- <pre>
---   -- Can add mapping to Lua functions
---   vim.keymap.set('n', 'lhs', function() print("real lua function") end)
---
---   -- Can use it to map multiple modes
---   vim.keymap.set({'n', 'v'}, '<leader>lr', vim.lsp.buf.references, { buffer=true })
---
---   -- Can add mapping for specific buffer
---   vim.keymap.set('n', '<leader>w', "<cmd>w<cr>", { silent = true, buffer = 5 })
---
---   -- Expr mappings
---   vim.keymap.set('i', '<Tab>', function()
---     return vim.fn.pumvisible() == 1 and "<C-n>" or "<Tab>"
---   end, { expr = true })
---   -- <Plug> mappings
---   vim.keymap.set('n', '[%%', '<Plug>(MatchitNormalMultiBackward)')
--- </pre>
---
--- Note that in a mapping like:
--- <pre>
---    vim.keymap.set('n', 'asdf', require('jkl').my_fun)
--- </pre>
---
--- the ``require('jkl')`` gets evaluated during this call in order to access the function.
--- If you want to avoid this cost at startup you can wrap it in a function, for example:
--- <pre>
---    vim.keymap.set('n', 'asdf', function() return require('jkl').my_fun() end)
--- </pre>
---
---@param mode string|table   Same mode short names as |nvim_set_keymap()|.
---                            Can also be list of modes to create mapping on multiple modes.
---@param lhs string          Left-hand side |{lhs}| of the mapping.
---@param rhs string|function  Right-hand side |{rhs}| of the mapping. Can also be a Lua function.
---                            If a Lua function and `opts.expr == true`, returning `nil` is
---                            equivalent to an empty string.
--
---@param opts table A table of |:map-arguments| such as "silent". In addition to the options
---                  listed in |nvim_set_keymap()|, this table also accepts the following keys:
---                  - replace_keycodes: (boolean, default true) When both this and expr is "true",
---                  |nvim_replace_termcodes()| is applied to the result of Lua expr maps.
---                  - remap: (boolean) Make the mapping recursive. This is the
---                  inverse of the "noremap" option from |nvim_set_keymap()|.
---                  Default `false`.
---@see |nvim_set_keymap()|
function keymap.set(mode, lhs, rhs, opts)
  vim.validate {
    mode = {mode, {'s', 't'}},
    lhs = {lhs, 's'},
    rhs = {rhs, {'s', 'f'}},
    opts = {opts, 't', true}
  }

  opts = vim.deepcopy(opts) or {}
  local is_rhs_luaref = type(rhs) == "function"
  mode = type(mode) == 'string' and {mode} or mode

  if is_rhs_luaref and opts.expr then
    local user_rhs = rhs
    rhs = function ()
      local res = user_rhs()
      if res == nil then
        -- TODO(lewis6991): Handle this in C?
        return ''
      elseif opts.replace_keycodes ~= false then
        return vim.api.nvim_replace_termcodes(res, true, true, true)
      else
        return res
      end
    end
  end
  -- clear replace_keycodes from opts table
  opts.replace_keycodes = nil

  if opts.remap == nil then
    -- default remap value is false
    opts.noremap = true
  else
    -- remaps behavior is opposite of noremap option.
    opts.noremap = not opts.remap
    opts.remap = nil
  end

  if is_rhs_luaref then
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
--- <pre>
---   vim.keymap.del('n', 'lhs')
---
---   vim.keymap.del({'n', 'i', 'v'}, '<leader>w', { buffer = 5 })
--- </pre>
---@param opts table A table of optional arguments:
---                  - buffer: (number or boolean) Remove a mapping from the given buffer.
---                  When "true" or 0, use the current buffer.
---@see |vim.keymap.set()|
---
function keymap.del(modes, lhs, opts)
  vim.validate {
    mode = {modes, {'s', 't'}},
    lhs = {lhs, 's'},
    opts = {opts, 't', true}
  }

  opts = opts or {}
  modes = type(modes) == 'string' and {modes} or modes

  local buffer = false
  if opts.buffer ~= nil then
    buffer = opts.buffer == true and 0 or opts.buffer
    opts.buffer = nil
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
