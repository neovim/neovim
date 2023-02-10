local platform = vim.loop.os_uname()
if platform and platform.sysname:lower():find'windows' then
  local deps_prefix = os.getenv 'DEPS_PREFIX'
  if deps_prefix ~= nil and deps_prefix ~= "" then
    package.path = deps_prefix.."/share/lua/5.1/?.lua;"..deps_prefix.."/share/lua/5.1/?/init.lua;"..package.path
    package.path = deps_prefix.."/bin/lua/?.lua;"..deps_prefix.."/bin/lua/?/init.lua;"..package.path
    package.cpath = deps_prefix.."/lib/lua/5.1/?.dll;"..package.cpath;
    package.cpath = deps_prefix.."/bin/?.dll;"..deps_prefix.."/bin/loadall.dll;"..package.cpath;
  end
end

require 'busted.runner'({ standalone = false })
