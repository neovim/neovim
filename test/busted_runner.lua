local platform = vim.uv.os_uname()
local deps_install_dir = os.getenv 'DEPS_INSTALL_DIR'
local suffix = (platform and platform.sysname:lower():find'windows') and '.dll' or '.so'
package.path = deps_install_dir.."/share/lua/5.1/?.lua;"..deps_install_dir.."/share/lua/5.1/?/init.lua;"..package.path
package.cpath = deps_install_dir.."/lib/lua/5.1/?"..suffix..";"..package.cpath;

local uv = vim.uv

local system = {}
package.loaded['system.core'] = system
function system.monotime()
  uv.update_time()
  return uv.now()*1e-3
end
function system.gettime()
  local sec, usec = uv.gettimeofday()
  return sec+usec*1e-6
end
function system.sleep(sec)
  uv.sleep(sec*1e3)
end

local term = {}
package.loaded['term.core'] = term
function term.isatty(_)
  return uv.guess_handle(1) == 'tty'
end

local lfs = {}
package.loaded['lfs'] = lfs

function lfs.attributes(path, attr)
  if attr == 'mode' then
    local stat = uv.fs_stat(path)
    return stat and stat.type or ''
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

require 'busted.runner'({ standalone = false })
