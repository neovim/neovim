local pathtrails = {}
vim._so_trails = {}
for s in (package.cpath .. ';'):gmatch('[^;]*;') do
  s = s:sub(1, -2) -- Strip trailing semicolon
  -- Find out path patterns. pathtrail should contain something like
  -- /?.so, \?.dll. This allows not to bother determining what correct
  -- suffixes are.
  local pathtrail = s:match('[/\\][^/\\]*%?.*$')
  if pathtrail and not pathtrails[pathtrail] then
    pathtrails[pathtrail] = true
    table.insert(vim._so_trails, pathtrail)
  end
end

--- @param name string
function vim._load_package(name)
  local basename = name:gsub('%.', '/')
  local paths = { 'lua/' .. basename .. '.lua', 'lua/' .. basename .. '/init.lua' }
  local found = vim.api.nvim__get_runtime(paths, false, { is_lua = true })
  if #found > 0 then
    local f, err = loadfile(found[1])
    return f or error(err)
  end

  local so_paths = {}
  for _, trail in ipairs(vim._so_trails) do
    local path = 'lua' .. trail:gsub('?', basename) -- so_trails contains a leading slash
    table.insert(so_paths, path)
  end

  found = vim.api.nvim__get_runtime(so_paths, false, { is_lua = true })
  if #found > 0 then
    -- Making function name in Lua 5.1 (see src/loadlib.c:mkfuncname) is
    -- a) strip prefix up to and including the first dash, if any
    -- b) replace all dots by underscores
    -- c) prepend "luaopen_"
    -- So "foo-bar.baz" should result in "luaopen_bar_baz"
    local dash = name:find('-', 1, true)
    local modname = dash and name:sub(dash + 1) or name
    local f, err = package.loadlib(found[1], 'luaopen_' .. modname:gsub('%.', '_'))
    return f or error(err)
  end
  return nil
end

-- TODO(bfredl): dedicated state for this?
if vim.api then
  -- Insert vim._load_package after the preloader at position 2
  table.insert(package.loaders, 2, vim._load_package)
end

-- builtin functions which always should be available
require('vim.shared')

vim._submodules = {
  inspect = true,
  version = true,
  fs = true,
  glob = true,
  iter = true,
  re = true,
  text = true,
  provider = true,
}

-- These are for loading runtime modules in the vim namespace lazily.
setmetatable(vim, {
  __index = function(t, key)
    if vim._submodules[key] then
      t[key] = require('vim.' .. key)
      return t[key]
    elseif key == 'inspect_pos' or key == 'show_pos' then
      require('vim._inspector')
      return t[key]
    elseif vim.startswith(key, 'uri_') then
      local val = require('vim.uri')[key]
      if val ~= nil then
        -- Expose all `vim.uri` functions on the `vim` module.
        t[key] = val
        return t[key]
      end
    end
  end,
})

--- <Docs described in |vim.empty_dict()| >
---@private
--- TODO: should be in vim.shared when vim.shared always uses nvim-lua
function vim.empty_dict()
  return setmetatable({}, vim._empty_dict_mt)
end

-- only on main thread: functions for interacting with editor state
if vim.api and not vim.is_thread() then
  require('vim._editor')
end
