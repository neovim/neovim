local platform = vim.uv.os_uname()
local deps_install_dir = table.remove(_G.arg, 1)
local subcommand = table.remove(_G.arg, 1)
local suffix = (platform and platform.sysname:lower():find 'windows') and '.dll' or '.so'
package.path = (deps_install_dir .. '/?.lua;')
  .. (deps_install_dir .. '/?/init.lua;')
  .. package.path
package.cpath = deps_install_dir .. '/?' .. suffix .. ';' .. package.cpath

local uv = vim.uv

-- we use busted and luacheck and their lua dependencies
-- But installing their binary dependencies with luarocks is very
-- slow, replace them with vim.uv wrappers

local system = {}
package.loaded['system.core'] = system
function system.monotime()
  uv.update_time()
  return uv.now() * 1e-3
end
function system.gettime()
  local sec, usec = uv.gettimeofday()
  return sec + usec * 1e-6
end
function system.sleep(sec)
  uv.sleep(sec * 1e3)
end

local term = {}
package.loaded['term.core'] = term
function term.isatty(_)
  return uv.guess_handle(1) == 'tty'
end

local lfs = { _VERSION = 'fake' }
package.loaded['lfs'] = lfs

function lfs.attributes(path, attr)
  local stat = uv.fs_stat(path)
  if attr == 'mode' then
    return stat and stat.type or ''
  elseif attr == 'modification' then
    if not stat then
      return nil
    end
    local mtime = stat.mtime
    return mtime.sec + mtime.nsec * 1e-9
  else
    error('not implemented')
  end
end

function lfs.currentdir()
  return uv.cwd()
end

function lfs.chdir(dir)
  local status, err = pcall(uv.chdir, dir)
  if status then
    return true
  else
    return nil, err
  end
end

function lfs.dir(path)
  local fs = uv.fs_scandir(path)
  return function()
    if not fs then
      return
    end
    return uv.fs_scandir_next(fs)
  end
end

function lfs.mkdir(dir)
  return uv.fs_mkdir(dir, 493) -- octal 755
end

if subcommand == 'busted' then
  require 'busted.runner'({ standalone = false })
elseif subcommand == 'luacheck' then
  require 'luacheck.main'
else
  error 'unknown subcommand'
end
