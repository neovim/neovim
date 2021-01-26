local keymap = {}

-- Have to use a global to handle re-requiring this file and losing all of the keymap.
--  In the future, the C code will handle this.
__VimMapStore = __VimMapStore or {}
keymap._store = __VimMapStore

keymap._create = function(f)
  table.insert(keymap._store, f)
  return #keymap._store
end

keymap._execute = function(id)
  keymap._store[id]()
end

local make_mapper = function(mode, defaults, opts)
  local args, map_args = {}, {}
  for k, v in pairs(opts) do
    if type(k) == 'number' then
      args[k] = v
    else
      map_args[k] = v
    end
  end

  local lhs = opts.lhs or args[1]
  local rhs = opts.rhs or args[2]
  local map_opts = vim.tbl_extend("force", defaults, map_args)

  local mapping
  if type(rhs) == 'string' then
    mapping = rhs
  elseif type(rhs) == 'function' then
    assert(map_opts.noremap, "If `rhs` is a function, `opts.noremap` must be true")

    local func_id = keymap._create(rhs)
    mapping = string.format(
      [[<cmd>lua vim.keymap._execute(%s)<CR>]], func_id
    )
  else
    error("Unexpected type for rhs:" .. tostring(rhs))
  end

  if not map_opts.buffer then
    vim.api.nvim_set_keymap(mode, lhs, mapping, map_opts)
  else
    -- Clear the buffer after saving it
    local buffer = map_opts.buffer
    if buffer == true then
      buffer = 0
    end

    map_opts.buffer = nil

    vim.api.nvim_buf_set_keymap(buffer, mode, lhs, mapping, map_opts)
  end
end

--- Helper function for ':map'.
---
--@see |vim.keymap.nmap|
---
function keymap.map(opts)
  return make_mapper('', { noremap = false }, opts)
end

--- Helper function for ':noremap'
--@see |vim.keymap.nmap|
---
function keymap.noremap(opts)
  return make_mapper('', { noremap = true }, opts)
end

--- Helper function for ':nmap'.
---
--- <pre>
---   vim.keymap.nmap { 'lhs', function() print("real lua function") end, silent = true }
--- </pre>
--@param opts (table): A table with keys:
---     - [1] = left hand side: Must be a string
---     - [2] = right hand side: Can be a string OR a lua function to execute
---     - Other keys can be arguments to |:map|, such as "silent". See |nvim_set_keymap()|
---
function keymap.nmap(opts)
  return make_mapper('n', { noremap = false }, opts)
end

--- Helper function for ':nnoremap'
--- <pre>
---   vim.keymap.nmap { 'lhs', function() print("real lua function") end, silent = true }
--- </pre>
--@param opts (table): A table with keys
---     - [1] = left hand side: Must be a string
---     - [2] = right hand side: Can be a string OR a lua function to execute
---     - Other keys can be arguments to |:map|, such as "silent". See |nvim_set_keymap()|
--- 
---
function keymap.nnoremap(opts)
  return make_mapper('n', { noremap = true }, opts)
end

--- Helper function for ':vmap'.
---
--@see |vim.keymap.nmap|
---
function keymap.vmap(opts)
  return make_mapper('v', { noremap = false }, opts)
end

--- Helper function for ':vnoremap'
--@see |vim.keymap.nmap|
---
function keymap.vnoremap(opts)
  return make_mapper('v', { noremap = true }, opts)
end

--- Helper function for ':xmap'.
---
--@see |vim.keymap.nmap|
---
function keymap.xmap(opts)
  return make_mapper('x', { noremap = false }, opts)
end

--- Helper function for ':xnoremap'
--@see |vim.keymap.nmap|
---
function keymap.xnoremap(opts)
  return make_mapper('x', { noremap = true }, opts)
end

--- Helper function for ':smap'.
---
--@see |vim.keymap.nmap|
---
function keymap.smap(opts)
  return make_mapper('s', { noremap = false }, opts)
end

--- Helper function for ':snoremap'
--@see |vim.keymap.nmap|
---
function keymap.snoremap(opts)
  return make_mapper('s', { noremap = true }, opts)
end

--- Helper function for ':omap'.
---
--@see |vim.keymap.nmap|
---
function keymap.omap(opts)
  return make_mapper('o', { noremap = false }, opts)
end

--- Helper function for ':onoremap'
--@see |vim.keymap.nmap|
---
function keymap.onoremap(opts)
  return make_mapper('o', { noremap = true }, opts)
end

--- Helper function for ':imap'.
---
--@see |vim.keymap.nmap|
---
function keymap.imap(opts)
  return make_mapper('i', { noremap = false }, opts)
end

--- Helper function for ':inoremap'
--@see |vim.keymap.nmap|
---
function keymap.inoremap(opts)
  return make_mapper('i', { noremap = true }, opts)
end

--- Helper function for ':lmap'.
---
--@see |vim.keymap.nmap|
---
function keymap.lmap(opts)
  return make_mapper('l', { noremap = false }, opts)
end

--- Helper function for ':lnoremap'
--@see |vim.keymap.nmap|
---
function keymap.lnoremap(opts)
  return make_mapper('l', { noremap = true }, opts)
end

--- Helper function for ':cmap'.
---
--@see |vim.keymap.nmap|
---
function keymap.cmap(opts)
  return make_mapper('c', { noremap = false }, opts)
end

--- Helper function for ':cnoremap'
--@see |vim.keymap.nmap|
---
function keymap.cnoremap(opts)
  return make_mapper('c', { noremap = true }, opts)
end

--- Helper function for ':tmap'.
---
--@see |vim.keymap.nmap|
---
function keymap.tmap(opts)
  return make_mapper('t', { noremap = false }, opts)
end

--- Helper function for ':tnoremap'
--@see |vim.keymap.nmap|
---
function keymap.tnoremap(opts)
  return make_mapper('t', { noremap = true }, opts)
end

return keymap
