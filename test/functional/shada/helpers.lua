local helpers = require('test.functional.helpers')(nil)
local spawn, set_session, meths, nvim_prog =
  helpers.spawn, helpers.set_session, helpers.meths, helpers.nvim_prog
local write_file, merge_args = helpers.write_file, helpers.merge_args

local mpack = require('mpack')

local tmpname = os.tmpname()
local additional_cmd = ''

local function nvim_argv()
  local argv = {nvim_prog, '-u', 'NONE', '-i', tmpname, '-N',
                '--cmd', 'set shortmess+=I background=light noswapfile',
                '--cmd', additional_cmd,
                '--embed'}
  if helpers.prepend_argv then
    return merge_args(helpers.prepend_argv, argv)
  else
    return argv
  end
end

local reset = function()
  set_session(spawn(nvim_argv()))
  meths.set_var('tmpname', tmpname)
end

local set_additional_cmd = function(s)
  additional_cmd = s
end

local clear = function()
  os.remove(tmpname)
  set_additional_cmd('')
end

local get_shada_rw = function(fname)
  local wshada = function(text)
    write_file(fname, text, true)
  end
  local sdrcmd = function(bang)
    return 'rshada' .. (bang and '!' or '') .. ' ' .. fname
  end
  local clean = function()
    os.remove(fname)
    local i = ('a'):byte()
    while i <= ('z'):byte() do
      if not os.remove(fname .. ('.tmp.%c'):format(i)) then
        break
      end
      i = i + 1
    end
  end
  return wshada, sdrcmd, fname, clean
end

local mpack_keys = {'type', 'timestamp', 'length', 'value'}

local read_shada_file = function(fname)
  local fd = io.open(fname, 'r')
  local mstring = fd:read('*a')
  fd:close()
  local unpack = mpack.Unpacker()
  local ret = {}
  local cur, val
  local i = 0
  local off = 1
  while off <= #mstring do
    val, off = unpack(mstring, off)
    if i % 4 == 0 then
      cur = {}
      ret[#ret + 1] = cur
    end
    cur[mpack_keys[(i % 4) + 1]] = val
    i = i + 1
  end
  return ret
end

return {
  reset=reset,
  set_additional_cmd=set_additional_cmd,
  clear=clear,
  get_shada_rw=get_shada_rw,
  read_shada_file=read_shada_file,
}
