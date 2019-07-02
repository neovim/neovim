-- Nvim-Lua stdlib: the `vim` module (:help lua-stdlib)
--
-- Lua code lives in one of three places:
--    1. runtime/lua/vim/ (the runtime): For "nice to have" features, e.g. the
--       `inspect` and `lpeg` modules.
--    2. runtime/lua/vim/shared.lua: Code shared between Nvim and tests.
--    3. src/nvim/lua/: Compiled-into Nvim itself.
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

--- Return a human-readable representation of the given object.
---
--@see https://github.com/kikito/inspect.lua
local function inspect(object, options)  -- luacheck: no unused
  error(object, options)  -- Stub for gen_vimdoc.py
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

--- Defers the wrapped callback until when the nvim API is safe to call.
---
--- See |vim-loop-callbacks|
local function schedule_wrap(cb)
  return (function (...)
    local args = {...}
    vim.schedule(function() cb(unpack(args)) end)
  end)
end

local module = {
  _update_package_paths = _update_package_paths,
  _os_proc_children = _os_proc_children,
  _os_proc_info = _os_proc_info,
  _system = _system,
  schedule_wrap = schedule_wrap,
}

setmetatable(module, {
  __index = __index
})

return module
