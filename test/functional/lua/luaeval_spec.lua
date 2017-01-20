-- Test suite for testing luaeval() function
local helpers = require('test.functional.helpers')(after_each)

local command = helpers.command
local meths = helpers.meths
local funcs = helpers.funcs
local clear = helpers.clear
local NIL = helpers.NIL
local eq = helpers.eq

before_each(clear)

describe('luaeval()', function()
  describe('second argument', function()
    it('is successfully received', function()
      local t = {t=true, f=false, --[[n=NIL,]] d={l={'string', 42, 0.42}}}
      eq(t, funcs.luaeval("_A", t))
      -- Not tested: nil, funcrefs, returned object identity: behaviour will 
      -- most likely change.
    end)
  end)
  describe('lua values', function()
    it('are successfully transformed', function()
      eq({n=1, f=1.5, s='string', l={4, 2}},
         funcs.luaeval('{n=1, f=1.5, s="string", l={4, 2}}'))
      -- Not tested: nil inside containers: behaviour will most likely change.
      eq(NIL, funcs.luaeval('nil'))
    end)
  end)
  describe('recursive lua values', function()
    it('are successfully transformed', function()
      funcs.luaeval('rawset(_G, "d", {})')
      funcs.luaeval('rawset(d, "d", d)')
      eq('\n{\'d\': {...@0}}', funcs.execute('echo luaeval("d")'))

      funcs.luaeval('rawset(_G, "l", {})')
      funcs.luaeval('table.insert(l, l)')
      eq('\n[[...@0]]', funcs.execute('echo luaeval("l")'))
    end)
  end)
  describe('strings', function()
    it('are successfully converted to special dictionaries', function()
      command([[let s = luaeval('"\0"')]])
      eq({_TYPE={}, _VAL={'\n'}}, meths.get_var('s'))
      eq(1, funcs.eval('s._TYPE is v:msgpack_types.binary'))
    end)
    it('are successfully converted to special dictionaries in table keys',
    function()
      command([[let d = luaeval('{["\0"]=1}')]])
      eq({_TYPE={}, _VAL={{{_TYPE={}, _VAL={'\n'}}, 1}}}, meths.get_var('d'))
      eq(1, funcs.eval('d._TYPE is v:msgpack_types.map'))
      eq(1, funcs.eval('d._VAL[0][0]._TYPE is v:msgpack_types.string'))
    end)
    it('are successfully converted to special dictionaries from a list',
    function()
      command([[let l = luaeval('{"abc", "a\0b", "c\0d", "def"}')]])
      eq({'abc', {_TYPE={}, _VAL={'a\nb'}}, {_TYPE={}, _VAL={'c\nd'}}, 'def'},
         meths.get_var('l'))
      eq(1, funcs.eval('l[1]._TYPE is v:msgpack_types.binary'))
      eq(1, funcs.eval('l[2]._TYPE is v:msgpack_types.binary'))
    end)
  end)
end)
