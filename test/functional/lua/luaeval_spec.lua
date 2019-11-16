-- Test suite for testing luaeval() function
local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local redir_exec = helpers.redir_exec
local pcall_err = helpers.pcall_err
local exc_exec = helpers.exc_exec
local exec_lua = helpers.exec_lua
local command = helpers.command
local meths = helpers.meths
local funcs = helpers.funcs
local clear = helpers.clear
local eval = helpers.eval
local feed = helpers.feed
local NIL = helpers.NIL
local eq = helpers.eq

before_each(clear)

local function startswith(expected, actual)
  eq(expected, actual:sub(1, #expected))
end

describe('luaeval()', function()
  local nested_by_level = {}
  local nested = {}
  local nested_s = '{}'
  for i=1,100 do
    if i % 2 == 0 then
      nested = {nested}
      nested_s = '{' .. nested_s .. '}'
    else
      nested = {nested=nested}
      nested_s = '{nested=' .. nested_s .. '}'
    end
    nested_by_level[i] = {o=nested, s=nested_s}
  end

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
      eq({['']=1}, funcs.luaeval('{[""]=1}'))
    end)
  end)
  describe('recursive lua values', function()
    it('are successfully transformed', function()
      command('lua rawset(_G, "d", {})')
      command('lua rawset(d, "d", d)')
      eq('\n{\'d\': {...@0}}', funcs.execute('echo luaeval("d")'))

      command('lua rawset(_G, "l", {})')
      command('lua table.insert(l, l)')
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

  -- Not checked: funcrefs converted to NIL. To be altered to something more
  -- meaningful later.

  it('correctly evaluates scalars', function()
    eq(1, funcs.luaeval('1'))
    eq(0, eval('type(luaeval("1"))'))

    eq(1.5, funcs.luaeval('1.5'))
    eq(5, eval('type(luaeval("1.5"))'))

    eq("test", funcs.luaeval('"test"'))
    eq(1, eval('type(luaeval("\'test\'"))'))

    eq('', funcs.luaeval('""'))
    eq({_TYPE={}, _VAL={'\n'}}, funcs.luaeval([['\0']]))
    eq({_TYPE={}, _VAL={'\n', '\n'}}, funcs.luaeval([['\0\n\0']]))
    eq(1, eval([[luaeval('"\0\n\0"')._TYPE is v:msgpack_types.binary]]))

    eq(true, funcs.luaeval('true'))
    eq(false, funcs.luaeval('false'))
    eq(NIL, funcs.luaeval('nil'))
  end)

  it('correctly evaluates containers', function()
    eq({}, funcs.luaeval('{}'))
    eq(3, eval('type(luaeval("{}"))'))

    eq({test=1, foo=2}, funcs.luaeval('{test=1, foo=2}'))
    eq(4, eval('type(luaeval("{test=1, foo=2}"))'))

    eq({4, 2}, funcs.luaeval('{4, 2}'))
    eq(3, eval('type(luaeval("{4, 2}"))'))

    local level = 30
    eq(nested_by_level[level].o, funcs.luaeval(nested_by_level[level].s))

    eq({_TYPE={}, _VAL={{{_TYPE={}, _VAL={'\n', '\n'}}, {_TYPE={}, _VAL={'\n', '\n\n'}}}}},
       funcs.luaeval([[{['\0\n\0']='\0\n\0\0'}]]))
    eq(1, eval([[luaeval('{["\0\n\0"]="\0\n\0\0"}')._TYPE is v:msgpack_types.map]]))
    eq(1, eval([[luaeval('{["\0\n\0"]="\0\n\0\0"}')._VAL[0][0]._TYPE is v:msgpack_types.string]]))
    eq(1, eval([[luaeval('{["\0\n\0"]="\0\n\0\0"}')._VAL[0][1]._TYPE is v:msgpack_types.binary]]))
    eq({nested={{_TYPE={}, _VAL={{{_TYPE={}, _VAL={'\n', '\n'}}, {_TYPE={}, _VAL={'\n', '\n\n'}}}}}}},
       funcs.luaeval([[{nested={{['\0\n\0']='\0\n\0\0'}}}]]))
  end)

  it('correctly passes scalars as argument', function()
    eq(1, funcs.luaeval('_A', 1))
    eq(1.5, funcs.luaeval('_A', 1.5))
    eq('', funcs.luaeval('_A', ''))
    eq('test', funcs.luaeval('_A', 'test'))
    eq(NIL, funcs.luaeval('_A', NIL))
    eq(true, funcs.luaeval('_A', true))
    eq(false, funcs.luaeval('_A', false))
  end)

  it('correctly passes containers as argument', function()
    eq({}, funcs.luaeval('_A', {}))
    eq({test=1}, funcs.luaeval('_A', {test=1}))
    eq({4, 2}, funcs.luaeval('_A', {4, 2}))
    local level = 28
    eq(nested_by_level[level].o, funcs.luaeval('_A', nested_by_level[level].o))
  end)

  local function sp(typ, val)
    return ('{"_TYPE": v:msgpack_types.%s, "_VAL": %s}'):format(typ, val)
  end
  local function mapsp(...)
    local val = ''
    for i=1,(select('#', ...)/2) do
      val = ('%s[%s,%s],'):format(val, select(i * 2 - 1, ...),
                                  select(i * 2, ...))
    end
    return sp('map', '[' .. val .. ']')
  end
  local function luaevalarg(argexpr, expr)
    return eval(([=[
      [
        extend(g:, {'_ret': luaeval(%s, %s)})._ret,
        type(g:_ret)==type({})&&has_key(g:_ret, '_TYPE')
        ? [
          get(keys(filter(copy(v:msgpack_types), 'v:val is g:_ret._TYPE')), 0,
              g:_ret._TYPE),
          get(g:_ret, '_VAL', g:_ret)
        ]
        : [0, g:_ret]][1]
    ]=]):format(expr or '"_A"', argexpr):gsub('\n', ''))
  end

  it('correctly passes special dictionaries', function()
    eq({'binary', {'\n', '\n'}}, luaevalarg(sp('binary', '["\\n", "\\n"]')))
    eq({'binary', {'\n', '\n'}}, luaevalarg(sp('string', '["\\n", "\\n"]')))
    eq({0, true}, luaevalarg(sp('boolean', 1)))
    eq({0, false}, luaevalarg(sp('boolean', 0)))
    eq({0, NIL}, luaevalarg(sp('nil', 0)))
    eq({0, {[""]=""}}, luaevalarg(mapsp(sp('binary', '[""]'), '""')))
    eq({0, {[""]=""}}, luaevalarg(mapsp(sp('string', '[""]'), '""')))
  end)

  it('issues an error in some cases', function()
    eq("Vim(call):E5100: Cannot convert given lua table: table should either have a sequence of positive integer keys or contain only string keys",
       exc_exec('call luaeval("{1, foo=2}")'))
    eq("Vim(call):E5101: Cannot convert given lua type",
       exc_exec('call luaeval("vim.api.nvim_buf_get_lines")'))
    startswith("Vim(call):E5107: Error loading lua [string \"luaeval()\"]:",
               exc_exec('call luaeval("1, 2, 3")'))
    startswith("Vim(call):E5108: Error executing lua [string \"luaeval()\"]:",
               exc_exec('call luaeval("(nil)()")'))
    eq("Vim(call):E5101: Cannot convert given lua type",
       exc_exec('call luaeval("{42, vim.api}")'))
    eq("Vim(call):E5101: Cannot convert given lua type",
       exc_exec('call luaeval("{foo=42, baz=vim.api}")'))

    -- The following should not crash: conversion error happens inside
    eq("Vim(call):E5101: Cannot convert given lua type",
       exc_exec('call luaeval("vim.api")'))
    -- The following should not show internal error
    eq("\nE5101: Cannot convert given lua type\n0",
       redir_exec('echo luaeval("vim.api")'))
  end)

  it('correctly converts containers with type_idx', function()
    eq(5, eval('type(luaeval("{[vim.type_idx]=vim.types.float, [vim.val_idx]=0}"))'))
    eq(4, eval([[type(luaeval('{[vim.type_idx]=vim.types.dictionary}'))]]))
    eq(3, eval([[type(luaeval('{[vim.type_idx]=vim.types.array}'))]]))

    eq({}, funcs.luaeval('{[vim.type_idx]=vim.types.array}'))

    -- Presence of type_idx makes Vim ignore some keys
    eq({42}, funcs.luaeval('{[vim.type_idx]=vim.types.array, [vim.val_idx]=10, [5]=1, foo=2, [1]=42}'))
    eq({foo=2}, funcs.luaeval('{[vim.type_idx]=vim.types.dictionary, [vim.val_idx]=10, [5]=1, foo=2, [1]=42}'))
    eq(10, funcs.luaeval('{[vim.type_idx]=vim.types.float, [vim.val_idx]=10, [5]=1, foo=2, [1]=42}'))

    -- The following should not crash
    eq({}, funcs.luaeval('{[vim.type_idx]=vim.types.dictionary}'))
  end)

  it('correctly converts self-containing containers', function()
    meths.set_var('l', {})
    eval('add(l, l)')
    eq(true, eval('luaeval("_A == _A[1]", l)'))
    eq(true, eval('luaeval("_A[1] == _A[1][1]", [l])'))
    eq(true, eval('luaeval("_A.d == _A.d[1]", {"d": l})'))
    eq(true, eval('luaeval("_A ~= _A[1]", [l])'))

    meths.set_var('d', {foo=42})
    eval('extend(d, {"d": d})')
    eq(true, eval('luaeval("_A == _A.d", d)'))
    eq(true, eval('luaeval("_A[1] == _A[1].d", [d])'))
    eq(true, eval('luaeval("_A.d == _A.d.d", {"d": d})'))
    eq(true, eval('luaeval("_A ~= _A.d", {"d": d})'))
  end)

  it('errors out correctly when doing incorrect things in lua', function()
    -- Conversion errors
    eq('Vim(call):E5108: Error executing lua [string "luaeval()"]:1: attempt to call field \'xxx_nonexistent_key_xxx\' (a nil value)',
       exc_exec([[call luaeval("vim.xxx_nonexistent_key_xxx()")]]))
    eq('Vim(call):E5108: Error executing lua [string "luaeval()"]:1: ERROR',
       exc_exec([[call luaeval("error('ERROR')")]]))
    eq('Vim(call):E5108: Error executing lua [NULL]',
       exc_exec([[call luaeval("error(nil)")]]))
  end)

  it('does not leak memory when called with too long line',
  function()
    local s = ('x'):rep(65536)
    eq('Vim(call):E5107: Error loading lua [string "luaeval()"]:1: unexpected symbol near \')\'',
       exc_exec([[call luaeval("(']] .. s ..[[' + )")]]))
    eq(s, funcs.luaeval('"' .. s .. '"'))
  end)
end)

describe('v:lua', function()
  before_each(function()
    exec_lua([[
      function _G.foo(a,b,n)
        _G.val = n
        return a+b
      end
      mymod = {}
      function mymod.noisy(name)
        vim.api.nvim_set_current_line("hey "..name)
      end
      function mymod.crashy()
        nonexistent()
      end
      function mymod.omni(findstart, base)
        if findstart == 1 then
          return 5
        else
          if base == 'st' then
            return {'stuff', 'steam', 'strange things'}
          end
        end
      end
      vim.api.nvim_buf_set_option(0, 'omnifunc', 'v:lua.mymod.omni')
    ]])
  end)

  it('works in expressions', function()
    eq(7, eval('v:lua.foo(3,4,v:null)'))
    eq(true, exec_lua([[return _G.val == vim.NIL]]))
    eq(NIL, eval('v:lua.mymod.noisy("eval")'))
    eq("hey eval", meths.get_current_line())

    eq("Vim:E5108: Error executing lua [string \"<nvim>\"]:10: attempt to call global 'nonexistent' (a nil value)",
       pcall_err(eval, 'v:lua.mymod.crashy()'))
  end)

  it('works in :call', function()
    command(":call v:lua.mymod.noisy('command')")
    eq("hey command", meths.get_current_line())
    eq("Vim(call):E5108: Error executing lua [string \"<nvim>\"]:10: attempt to call global 'nonexistent' (a nil value)",
       pcall_err(command, 'call v:lua.mymod.crashy()'))
  end)

  it('works in func options', function()
    local screen = Screen.new(60, 8)
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue1},
      [2] = {background = Screen.colors.WebGray},
      [3] = {background = Screen.colors.LightMagenta},
      [4] = {bold = true},
      [5] = {bold = true, foreground = Screen.colors.SeaGreen4},
    })
    screen:attach()
    feed('isome st<c-x><c-o>')
    screen:expect{grid=[[
      some stuff^                                                  |
      {1:~   }{2: stuff          }{1:                                        }|
      {1:~   }{3: steam          }{1:                                        }|
      {1:~   }{3: strange things }{1:                                        }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {4:-- Omni completion (^O^N^P) }{5:match 1 of 3}                    |
    ]]}
  end)

  it('throw errors for invalid use', function()
    eq('Vim(let):E15: Invalid expression: v:lua.func', pcall_err(command, "let g:Func = v:lua.func"))
    eq('Vim(let):E15: Invalid expression: v:lua', pcall_err(command, "let g:Func = v:lua"))
    eq("Vim(let):E15: Invalid expression: v:['lua']", pcall_err(command, "let g:Func = v:['lua']"))

    eq("Vim:E15: Invalid expression: v:['lua'].foo()", pcall_err(eval, "v:['lua'].foo()"))
    eq("Vim(call):E461: Illegal variable name: v:['lua']", pcall_err(command, "call v:['lua'].baar()"))

    eq("Vim(let):E46: Cannot change read-only variable \"v:['lua']\"", pcall_err(command, "let v:['lua'] = 'xx'"))
    eq("Vim(let):E46: Cannot change read-only variable \"v:lua\"", pcall_err(command, "let v:lua = 'xx'"))
  end)
end)
