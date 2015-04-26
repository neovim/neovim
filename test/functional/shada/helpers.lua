local helpers = require('test.functional.helpers')
local spawn, set_session, nvim, nvim_prog =
  helpers.spawn, helpers.set_session, helpers.nvim, helpers.nvim_prog

local tmpname = os.tmpname()
local additional_cmd = ''

local function nvim_argv()
  local ret
  local nvim_argv = {nvim_prog, '-u', 'NONE', '-i', tmpname, '-N',
                     '--cmd', 'set shortmess+=I background=light noswapfile',
                     '--cmd', additional_cmd,
                     '--embed'}
  if helpers.prepend_argv then
    ret = {}
    for i, v in ipairs(helpers.prepend_argv) do
      ret[i] = v
    end
    local shift = #ret
    for i, v in ipairs(nvim_argv) do
      ret[i + shift] = v
    end
  else
    ret = nvim_argv
  end
  return ret
end

local session = nil

local reset = function()
  if session then
    session:exit(0)
  end
  session = spawn(nvim_argv())
  set_session(session)
  nvim('set_var', 'tmpname', tmpname)
end

local set_additional_cmd = function(s)
  additional_cmd = s
end

local clear = function()
  os.remove(tmpname)
  set_additional_cmd('')
end

return {
  reset=reset,
  set_additional_cmd=set_additional_cmd,
  clear=clear,
}
