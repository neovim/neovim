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

local make_mapper = function(mode, defaults)
  return function(opts)
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

    local mapping
    if type(rhs) == 'string' then
      mapping = rhs
    elseif type(rhs) == 'function' then
      local func_id = keymap._create(rhs)

      mapping = string.format(
        [[:lua vim.keymap._execute(%s)<CR>]], func_id
      )
    end

    local map_opts = vim.tbl_extend("force", defaults, map_args)

    if not map_opts.buffer then
      vim.api.nvim_set_keymap(mode, lhs, mapping, map_opts)
    else
      -- Clear the buffer after saving it
      local buffer = map_opts.buffer
      map_opts.buffer = nil

      vim.api.nvim_buf_set_keymap(buffer, mode, lhs, mapping, map_opts)
    end
  end
end

-- Use this code to generate all the things
function keymap._generate_keymap_codes()
  local map_prefix = {
    '',
    'n',
    'v',
    'x',
    's',
    'o',
    'i',
    'l',
    'c',
    't',
  }

  local result = {
    "-- BEGIN GENERATED",
    "",
  }

  for _, prefix in ipairs(map_prefix) do

    local usage_example
    if prefix == 'n' then
      usage_example = [[
--- <pre>
---   vim.keymap.nmap { 'lhs', function() print("real lua function") end, silent = true }
--- </pre>
--@param opts (table): A table with keys:
---     - [1] = left hand side: Must be a string
---     - [2] = right hand side: Can be a string OR a lua function to execute
---     - Other keys can be arguments to |:map|, such as "silent". See |nvim_set_keymap()|
--- ]]
    else
      usage_example = [[--@see |vim.keymap.nmap|]]
    end

    table.insert(result, (string.format([[
--- Helper function for ':%smap'.
---
%s
---
function keymap.%smap(opts)
  return make_mapper('%s', { noremap = false })(opts)
end

--- Helper function for ':%snoremap'
%s
---
function keymap.%snoremap(opts)
  return make_mapper('%s', { noremap = true })(opts)
end
]], prefix, usage_example, prefix, prefix, prefix, usage_example, prefix, prefix)))
  end

  table.insert(result, "")
  table.insert(result, "-- END GENERATED")
  table.insert(result, "")
  table.insert(result, "return keymap")

  return vim.split(table.concat(result, "\n"), "\n")
end

local generating = false
if generating then
  vim.api.nvim_buf_set_lines(0, -1, -1, false, keymap._generate_keymap_codes())
end
-- BEGIN GENERATED

--- Helper function for ':map'.
---
--@see |vim.keymap.nmap|
---
function keymap.map(opts)
  return make_mapper('', { noremap = false })(opts)
end

--- Helper function for ':noremap'
--@see |vim.keymap.nmap|
---
function keymap.noremap(opts)
  return make_mapper('', { noremap = true })(opts)
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
---
function keymap.nmap(opts)
  return make_mapper('n', { noremap = false })(opts)
end

--- Helper function for ':nnoremap'
--- <pre>
---   vim.keymap.nmap { 'lhs', function() print("real lua function") end, silent = true }
--- </pre>
--@param opts (table): A table with keys:
---     - [1] = left hand side: Must be a string
---     - [2] = right hand side: Can be a string OR a lua function to execute
---     - Other keys can be arguments to |:map|, such as "silent". See |nvim_set_keymap()|
--- 
---
function keymap.nnoremap(opts)
  return make_mapper('n', { noremap = true })(opts)
end

--- Helper function for ':vmap'.
---
--@see |vim.keymap.nmap|
---
function keymap.vmap(opts)
  return make_mapper('v', { noremap = false })(opts)
end

--- Helper function for ':vnoremap'
--@see |vim.keymap.nmap|
---
function keymap.vnoremap(opts)
  return make_mapper('v', { noremap = true })(opts)
end

--- Helper function for ':xmap'.
---
--@see |vim.keymap.nmap|
---
function keymap.xmap(opts)
  return make_mapper('x', { noremap = false })(opts)
end

--- Helper function for ':xnoremap'
--@see |vim.keymap.nmap|
---
function keymap.xnoremap(opts)
  return make_mapper('x', { noremap = true })(opts)
end

--- Helper function for ':smap'.
---
--@see |vim.keymap.nmap|
---
function keymap.smap(opts)
  return make_mapper('s', { noremap = false })(opts)
end

--- Helper function for ':snoremap'
--@see |vim.keymap.nmap|
---
function keymap.snoremap(opts)
  return make_mapper('s', { noremap = true })(opts)
end

--- Helper function for ':omap'.
---
--@see |vim.keymap.nmap|
---
function keymap.omap(opts)
  return make_mapper('o', { noremap = false })(opts)
end

--- Helper function for ':onoremap'
--@see |vim.keymap.nmap|
---
function keymap.onoremap(opts)
  return make_mapper('o', { noremap = true })(opts)
end

--- Helper function for ':imap'.
---
--@see |vim.keymap.nmap|
---
function keymap.imap(opts)
  return make_mapper('i', { noremap = false })(opts)
end

--- Helper function for ':inoremap'
--@see |vim.keymap.nmap|
---
function keymap.inoremap(opts)
  return make_mapper('i', { noremap = true })(opts)
end

--- Helper function for ':lmap'.
---
--@see |vim.keymap.nmap|
---
function keymap.lmap(opts)
  return make_mapper('l', { noremap = false })(opts)
end

--- Helper function for ':lnoremap'
--@see |vim.keymap.nmap|
---
function keymap.lnoremap(opts)
  return make_mapper('l', { noremap = true })(opts)
end

--- Helper function for ':cmap'.
---
--@see |vim.keymap.nmap|
---
function keymap.cmap(opts)
  return make_mapper('c', { noremap = false })(opts)
end

--- Helper function for ':cnoremap'
--@see |vim.keymap.nmap|
---
function keymap.cnoremap(opts)
  return make_mapper('c', { noremap = true })(opts)
end

--- Helper function for ':tmap'.
---
--@see |vim.keymap.nmap|
---
function keymap.tmap(opts)
  return make_mapper('t', { noremap = false })(opts)
end

--- Helper function for ':tnoremap'
--@see |vim.keymap.nmap|
---
function keymap.tnoremap(opts)
  return make_mapper('t', { noremap = true })(opts)
end


-- END GENERATED

return keymap
