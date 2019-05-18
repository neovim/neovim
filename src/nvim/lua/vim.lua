-- Nvim-Lua stdlib: the `vim` module (:help lua-stdlib)
--
-- Lua code lives in one of three places:
--    1. The runtime (`runtime/lua/vim/`). For "nice to have" features, e.g.
--       the `inspect` and `lpeg` modules.
--    2. The `vim.shared` module: code shared between Nvim and its test-suite.
--    3. Compiled-into Nvim itself (`src/nvim/lua/`).
--
-- Guideline: "If in doubt, put it in the runtime".
--
-- Most functions should live directly on `vim.`, not sub-modules. The only
-- "forbidden" names are those claimed by legacy `if_lua`:
--    $ vim
--    :lua for k,v in pairs(vim) do print(k) end
--    buffer
--    open
--    window
--    lastline
--    firstline
--    type
--    line
--    eval
--    dict
--    beep
--    list
--    command
--
-- Reference (#6580):
--    - https://github.com/luafun/luafun
--    - https://github.com/rxi/lume
--    - http://leafo.net/lapis/reference/utilities.html
--    - https://github.com/torch/paths
--    - https://github.com/bakpakin/Fennel (pretty print, repl)
--    - https://github.com/howl-editor/howl/tree/master/lib/howl/util


-- Internal-only until comments in #8107 are addressed.
-- Returns:
--    {errcode}, {output}
local function _system(cmd)
  local out = vim.api.nvim_call_function('system', { cmd })
  local err = vim.api.nvim_get_vvar('shell_error')
  return err, out
end

-- Gets process info from the `ps` command.
-- Used by nvim_get_proc() as a fallback.
local function _os_proc_info(pid)
  if pid == nil or pid <= 0 or type(pid) ~= 'number' then
    error('invalid pid')
  end
  local cmd = { 'ps', '-p', pid, '-o', 'comm=', }
  local err, name = _system(cmd)
  if 1 == err and string.gsub(name, '%s*', '') == '' then
    return {}  -- Process not found.
  elseif 0 ~= err then
    local args_str = vim.api.nvim_call_function('string', { cmd })
    error('command failed: '..args_str)
  end
  local _, ppid = _system({ 'ps', '-p', pid, '-o', 'ppid=', })
  -- Remove trailing whitespace.
  name = string.gsub(string.gsub(name, '%s+$', ''), '^.*/', '')
  ppid = string.gsub(ppid, '%s+$', '')
  ppid = tonumber(ppid) == nil and -1 or tonumber(ppid)
  return {
    name = name,
    pid = pid,
    ppid = ppid,
  }
end

-- Gets process children from the `pgrep` command.
-- Used by nvim_get_proc_children() as a fallback.
local function _os_proc_children(ppid)
  if ppid == nil or ppid <= 0 or type(ppid) ~= 'number' then
    error('invalid ppid')
  end
  local cmd = { 'pgrep', '-P', ppid, }
  local err, rv = _system(cmd)
  if 1 == err and string.gsub(rv, '%s*', '') == '' then
    return {}  -- Process not found.
  elseif 0 ~= err then
    local args_str = vim.api.nvim_call_function('string', { cmd })
    error('command failed: '..args_str)
  end
  local children = {}
  for s in string.gmatch(rv, '%S+') do
    local i = tonumber(s)
    if i ~= nil then
      table.insert(children, i)
    end
  end
  return children
end

-- TODO(ZyX-I): Create compatibility layer.
--{{{1 package.path updater function
-- Last inserted paths. Used to clear out items from package.[c]path when they
-- are no longer in &runtimepath.
local last_nvim_paths = {}
local function _update_package_paths()
  local cur_nvim_paths = {}
  local rtps = vim.api.nvim_list_runtime_paths()
  local sep = package.config:sub(1, 1)
  for _, key in ipairs({'path', 'cpath'}) do
    local orig_str = package[key] .. ';'
    local pathtrails_ordered = {}
    local orig = {}
    -- Note: ignores trailing item without trailing `;`. Not using something
    -- simpler in order to preserve empty items (stand for default path).
    for s in orig_str:gmatch('[^;]*;') do
      s = s:sub(1, -2)  -- Strip trailing semicolon
      orig[#orig + 1] = s
    end
    if key == 'path' then
      -- /?.lua and /?/init.lua
      pathtrails_ordered = {sep .. '?.lua', sep .. '?' .. sep .. 'init.lua'}
    else
      local pathtrails = {}
      for _, s in ipairs(orig) do
        -- Find out path patterns. pathtrail should contain something like
        -- /?.so, \?.dll. This allows not to bother determining what correct
        -- suffixes are.
        local pathtrail = s:match('[/\\][^/\\]*%?.*$')
        if pathtrail and not pathtrails[pathtrail] then
          pathtrails[pathtrail] = true
          pathtrails_ordered[#pathtrails_ordered + 1] = pathtrail
        end
      end
    end
    local new = {}
    for _, rtp in ipairs(rtps) do
      if not rtp:match(';') then
        for _, pathtrail in pairs(pathtrails_ordered) do
          local new_path = rtp .. sep .. 'lua' .. pathtrail
          -- Always keep paths from &runtimepath at the start:
          -- append them here disregarding orig possibly containing one of them.
          new[#new + 1] = new_path
          cur_nvim_paths[new_path] = true
        end
      end
    end
    for _, orig_path in ipairs(orig) do
      -- Handle removing obsolete paths originating from &runtimepath: such
      -- paths either belong to cur_nvim_paths and were already added above or
      -- to last_nvim_paths and should not be added at all if corresponding
      -- entry was removed from &runtimepath list.
      if not (cur_nvim_paths[orig_path] or last_nvim_paths[orig_path]) then
        new[#new + 1] = orig_path
      end
    end
    package[key] = table.concat(new, ';')
  end
  last_nvim_paths = cur_nvim_paths
end

---Split a string by a given separator. The separator can be a lua pattern, see [1].
---Used by |vim.split()|, see there for some examples. See [2]
---for usage of the plain parameter.
---
--- [1] https://www.lua.org/pil/20.2.html.
---
--- [2] http://lua-users.org/wiki/StringLibraryTutorial
--@param s String The string to split
--@param sep String The separator to use
--@param plain Boolean If `true`, use the separator literally
---(passed as an argument to String.find)
--@returns An iterator over the split components
local function gsplit(s, sep, plain)
  assert(type(s) == "string")
  assert(type(sep) == "string")
  assert(type(plain) == "boolean" or type(plain) == "nil")

  local start = 1
  local done = false

  local function _pass(i, j, ...)
    if i then
      assert(j+1 > start, "Infinite loop detected")
      local seg = s:sub(start, i - 1)
      start = j + 1
      return seg, ...
    else
      done = true
      return s:sub(start)
    end
  end

  return function()
    if done then
      return
    end
    if sep == '' then
      if start == #s then
        done = true
      end
      return _pass(start+1, start)
    end
    return _pass(s:find(sep, start, plain))
  end
end

--- Split a string by a given separator.
---
--- Examples:
--- <pre>
---  split(":aa::b:", ":")     --> {'','aa','','bb',''}
---  split("axaby", "ab?")     --> {'','x','y'}
---  split(x*yz*o, "*", true)  --> {'x','yz','o'}
--- </pre>
---
--@param s String The string to split
--@param sep String The separator to use (see |vim.gsplit()|)
--@param plain Boolean If `true`, use the separator literally
---(see |vim.gsplit()|)
--@returns An array containing the components of the split.
local function split(s,sep,plain)
  local t={} for c in gsplit(s, sep, plain) do table.insert(t,c) end
  return t
end

--- Trim the whitespaces from a string.  A whitespace is everything that
--- matches the lua pattern '%%s', see
---
--- https://www.lua.org/pil/20.2.html
--@param s String The string to trim
--@returns The string with all whitespaces trimmed from its beginning and end
local function trim(s)
  assert(type(s) == "string", "Only strings can be trimmed")
  local result = s:gsub("^%s+", ""):gsub("%s+$", "")
  return result
end

--- Performs a deep copy of the given object, and returns that copy.
--- For a non-table object, that just means a usual copy of the object,
--- while for a table all subtables are copied recursively.
--@param orig Table The table to copy
--@returns A new table where the keys and values are deepcopies of the keys
--- and values from the original table.
local function deepcopy(orig)
  error()
end

local function _id(v)
  return v
end

local deepcopy_funcs = {
  table = function(orig)
    local copy = {}
    for k, v in pairs(orig) do
      copy[deepcopy(k)] = deepcopy(v)
    end
    return copy
  end,
  number = _id,
  string = _id,
  ['nil'] = _id,
  boolean = _id,
}

deepcopy = function(orig)
  return deepcopy_funcs[type(orig)](orig)
end

local function __index(t, key)
  if key == 'inspect' then
    t.inspect = require('vim.inspect')
    return t.inspect
  elseif require('vim.shared')[key] ~= nil then
    -- Expose all `vim.shared` functions on the `vim` module.
    t[key] = require('vim.shared')[key]
    return t[key]
  end
end

local module = {
  _update_package_paths = _update_package_paths,
  _os_proc_children = _os_proc_children,
  _os_proc_info = _os_proc_info,
  _system = _system,
  trim = trim,
  split = split,
  gsplit = gsplit,
  deepcopy = deepcopy,
}

setmetatable(module, {
  __index = __index
})

return module
