local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local api = n.api
local write_file = t.write_file
local concat_tables = t.concat_tables

local tmpname = t.tmpname()

--   o={
--     args=…,
--     args_rm=…,
--     shadafile=…,
--   }
local function reset(o)
  assert(o == nil or type(o) == 'table' or type(o) == 'string')
  o = o and o or {}
  local args_rm = o.args_rm or {}
  table.insert(args_rm, '-i')
  local args = {
    '-i',
    o.shadafile or tmpname,
  }
  if type(o) == 'string' then
    args = concat_tables(args, { '--cmd', o })
  elseif o.args then
    args = concat_tables(args, o.args)
  end
  n.clear {
    args_rm = args_rm,
    args = args,
  }
  api.nvim_set_var('tmpname', tmpname)
end

local clear = function()
  n.expect_exit(n.command, 'qall!')
  os.remove(tmpname)
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

local mpack_keys = { 'type', 'timestamp', 'length', 'value' }

local read_shada_file = function(fname)
  local fd = io.open(fname, 'r')
  local mstring = fd:read('*a')
  fd:close()
  local unpack = vim.mpack.Unpacker()
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
  reset = reset,
  clear = clear,
  get_shada_rw = get_shada_rw,
  read_shada_file = read_shada_file,
}
