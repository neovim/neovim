local helpers = require('test.functional.helpers')
local spawn, set_session, nvim, nvim_prog, nvim_command, nvim_eval =
  helpers.spawn, helpers.set_session, helpers.nvim, helpers.nvim_prog,
  helpers.command, helpers.eval
local write_file = helpers.write_file

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

local exc_exec = function(cmd)
  nvim_command(([[
    try
      execute "%s"
    catch
      let g:__exception = v:exception
    endtry
  ]]):format(cmd:gsub('\n', '\\n'):gsub('[\\"]', '\\%0')))
  local ret = nvim_eval('get(g:, "__exception", 0)')
  nvim_command('unlet! g:__exception')
  return ret
end

local get_shada_rw = function(fname)
  local wshada = function(text)
    write_file(fname, text, true)
  end
  local sdrcmd = function(bang)
    return 'rshada' .. (bang and '!' or '') .. ' ' .. fname
  end
  return wshada, sdrcmd, fname
end

return {
  reset=reset,
  set_additional_cmd=set_additional_cmd,
  clear=clear,
  exc_exec=exc_exec,
  get_shada_rw=get_shada_rw,
}
