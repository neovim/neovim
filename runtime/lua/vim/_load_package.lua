-- prevents luacheck from making lints for setting things on vim
local vim = assert(vim)

local pathtrails = {}
vim._so_trails = {}
for s in  (package.cpath..';'):gmatch('[^;]*;') do
    s = s:sub(1, -2)  -- Strip trailing semicolon
  -- Find out path patterns. pathtrail should contain something like
  -- /?.so, \?.dll. This allows not to bother determining what correct
  -- suffixes are.
  local pathtrail = s:match('[/\\][^/\\]*%?.*$')
  if pathtrail and not pathtrails[pathtrail] then
    pathtrails[pathtrail] = true
    table.insert(vim._so_trails, pathtrail)
  end
end

function vim._load_package(name)
  local basename = name:gsub('%.', '/')
  local paths = {"lua/"..basename..".lua", "lua/"..basename.."/init.lua"}
  local found = vim.api.nvim__get_runtime(paths, false, {is_lua=true})
  if #found > 0 then
    local f, err = loadfile(found[1])
    return f or error(err)
  end

  local so_paths = {}
  for _,trail in ipairs(vim._so_trails) do
    local path = "lua"..trail:gsub('?', basename) -- so_trails contains a leading slash
    table.insert(so_paths, path)
  end

  found = vim.api.nvim__get_runtime(so_paths, false, {is_lua=true})
  if #found > 0 then
    -- Making function name in Lua 5.1 (see src/loadlib.c:mkfuncname) is
    -- a) strip prefix up to and including the first dash, if any
    -- b) replace all dots by underscores
    -- c) prepend "luaopen_"
    -- So "foo-bar.baz" should result in "luaopen_bar_baz"
    local dash = name:find("-", 1, true)
    local modname = dash and name:sub(dash + 1) or name
    local f, err = package.loadlib(found[1], "luaopen_"..modname:gsub("%.", "_"))
    return f or error(err)
  end
  return nil
end

-- Insert vim._load_package after the preloader at position 2
table.insert(package.loaders, 2, vim._load_package)

-- should always be available
vim.inspect = require'vim.inspect'
