local platform = vim.uv.os_uname()
local deps_install_dir = os.getenv 'DEPS_INSTALL_DIR'
local suffix = (platform and platform.sysname:lower():find'windows') and '.dll' or '.so'
package.path = deps_install_dir.."/share/lua/5.1/?.lua;"..deps_install_dir.."/share/lua/5.1/?/init.lua;"..package.path
package.cpath = deps_install_dir.."/lib/lua/5.1/?"..suffix..";"..package.cpath;

require 'busted.runner'({ standalone = false })
