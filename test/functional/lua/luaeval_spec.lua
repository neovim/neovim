-- Test suite for testing luaeval() function
local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local pcall_err = t.pcall_err
local exc_exec = n.exc_exec
local remove_trace = t.remove_trace
local exec_lua = n.exec_lua
local command = n.command
local api = n.api
local fn = n.fn
local clear = n.clear
local eval = n.eval
local feed = n.feed
local assert_alive = n.assert_alive
local NIL = vim.NIL
local eq = t.eq

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
      local q = {t=true, f=false, --[[n=NIL,]] d={l={'string', 42, 0.42}}}
      eq(q, fn.luaeval("_A", q))
      -- Not tested: nil, funcrefs, returned object identity: behaviour will
      -- most likely change.
    end)
  end)
  describe('lua values', function()
    it('are successfully transformed', function()
      eq({n=1, f=1.5, s='string', l={4, 2}},
         fn.luaeval('{n=1, f=1.5, s="string", l={4, 2}}'))
      -- Not tested: nil inside containers: behaviour will most likely change.
      eq(NIL, fn.luaeval('nil'))
      eq({['']=1}, fn.luaeval('{[""]=1}'))
    end)
  end)
  describe('recursive lua values', function()
    it('are successfully transformed', function()
      command('lua rawset(_G, "d", {})')
      command('lua rawset(d, "d", d)')
      eq('\n{\'d\': {...@0}}', fn.execute('echo luaeval("d")'))

      command('lua rawset(_G, "l", {})')
      command('lua table.insert(l, l)')
      eq('\n[[...@0]]', fn.execute('echo luaeval("l")'))
    end)
  end)
  describe('strings with NULs', function()
    it('are successfully converted to blobs', function()
      command([[let s = luaeval('"\0"')]])
      eq('\000', api.nvim_get_var('s'))
    end)
    it('are successfully converted to special dictionaries in table keys', function()
      command([[let d = luaeval('{["\0"]=1}')]])
      eq({_TYPE={}, _VAL={{'\000', 1}}}, api.nvim_get_var('d'))
      eq(1, fn.eval('d._TYPE is v:msgpack_types.map'))
      eq(eval('v:t_blob'), fn.eval('type(d._VAL[0][0])'))
    end)
    it('are successfully converted to blobs from a list', function()
      command([[let l = luaeval('{"abc", "a\0b", "c\0d", "def"}')]])
      eq({'abc', 'a\000b', 'c\000d', 'def'}, api.nvim_get_var('l'))
    end)
  end)

  -- Not checked: funcrefs converted to NIL. To be altered to something more
  -- meaningful later.

  it('correctly evaluates scalars', function()
    -- Also test method call (->) syntax
    eq(1, fn.luaeval('1'))
    eq(0, eval('"1"->luaeval()->type()'))

    eq(1.5, fn.luaeval('1.5'))
    eq(5, eval('"1.5"->luaeval()->type()'))

    eq("test", fn.luaeval('"test"'))
    eq(1, eval('"\'test\'"->luaeval()->type()'))

    eq('', fn.luaeval('""'))
    eq('\000', fn.luaeval([['\0']]))
    eq('\000\n\000', fn.luaeval([['\0\n\0']]))
    eq(10, eval([[type(luaeval("'\\0\\n\\0'"))]]))

    eq(true, fn.luaeval('true'))
    eq(false, fn.luaeval('false'))
    eq(NIL, fn.luaeval('nil'))
  end)

  it('correctly evaluates containers', function()
    eq({}, fn.luaeval('{}'))
    eq(3, eval('type(luaeval("{}"))'))

    eq({test=1, foo=2}, fn.luaeval('{test=1, foo=2}'))
    eq(4, eval('type(luaeval("{test=1, foo=2}"))'))

    eq({4, 2}, fn.luaeval('{4, 2}'))
    eq(3, eval('type(luaeval("{4, 2}"))'))

    eq({NIL, 20}, fn.luaeval('{[2] = 20}'))
    eq(3, eval('type(luaeval("{[2] = 20}"))'))

    eq({10, NIL, 30}, fn.luaeval('{[1] = 10, [3] = 30}'))
    eq(3, eval('type(luaeval("{[1] = 10, [3] = 30}"))'))

    local level = 30
    eq(nested_by_level[level].o, fn.luaeval(nested_by_level[level].s))

    eq({_TYPE={}, _VAL={{'\000\n\000', '\000\n\000\000'}}},
       fn.luaeval([[{['\0\n\0']='\0\n\0\0'}]]))
    eq(1, eval([[luaeval('{["\0\n\0"]="\0\n\0\0"}')._TYPE is v:msgpack_types.map]]))
    eq(eval("v:t_blob"), eval([[type(luaeval('{["\0\n\0"]="\0\n\0\0"}')._VAL[0][0])]]))
    eq({nested={{_TYPE={}, _VAL={{'\000\n\000', '\000\n\000\000'}}}}},
       fn.luaeval([[{nested={{['\0\n\0']='\0\n\0\0'}}}]]))
  end)

  it('correctly passes scalars as argument', function()
    eq(1, fn.luaeval('_A', 1))
    eq(1.5, fn.luaeval('_A', 1.5))
    eq('', fn.luaeval('_A', ''))
    eq('test', fn.luaeval('_A', 'test'))
    eq(NIL, fn.luaeval('_A', NIL))
    eq(true, fn.luaeval('_A', true))
    eq(false, fn.luaeval('_A', false))
  end)

  it('correctly passes containers as argument', function()
    eq({}, fn.luaeval('_A', {}))
    eq({test=1}, fn.luaeval('_A', {test=1}))
    eq({4, 2}, fn.luaeval('_A', {4, 2}))
    local level = 28
    eq(nested_by_level[level].o, fn.luaeval('_A', nested_by_level[level].o))
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
    return eval((([=[
      [
        extend(g:, {'_ret': luaeval(%s, %s)})._ret,
        type(g:_ret)==type({})&&has_key(g:_ret, '_TYPE')
        ? [
          get(keys(filter(copy(v:msgpack_types), 'v:val is g:_ret._TYPE')), 0,
              g:_ret._TYPE),
          get(g:_ret, '_VAL', g:_ret)
        ]
        : [0, g:_ret]][1]
    ]=]):format(expr or '"_A"', argexpr):gsub('\n', '')))
  end

  it('correctly passes special dictionaries', function()
    eq({0, '\000\n\000'}, luaevalarg(sp('string', '["\\n", "\\n"]')))
    eq({0, true}, luaevalarg(sp('boolean', 1)))
    eq({0, false}, luaevalarg(sp('boolean', 0)))
    eq({0, NIL}, luaevalarg(sp('nil', 0)))
    eq({0, {[""]=""}}, luaevalarg(mapsp(sp('string', '[""]'), '""')))
  end)

  it('issues an error in some cases', function()
    eq("Vim(call):E5100: Cannot convert given Lua table: table should contain either only integer keys or only string keys",
       exc_exec('call luaeval("{1, foo=2}")'))

    startswith("Vim(call):E5107: Error loading lua [string \"luaeval()\"]:",
               exc_exec('call luaeval("1, 2, 3")'))
    startswith("Vim(call):E5108: Error executing lua [string \"luaeval()\"]:",
               exc_exec('call luaeval("(nil)()")'))

  end)

  it('should handle sending lua functions to viml', function()
    eq(true, exec_lua [[
      can_pass_lua_callback_to_vim_from_lua_result = nil

      vim.fn.call(function()
        can_pass_lua_callback_to_vim_from_lua_result = true
      end, {})

      return can_pass_lua_callback_to_vim_from_lua_result
    ]])
  end)

  it('run functions even in timers', function()
    eq(true, exec_lua [[
      can_pass_lua_callback_to_vim_from_lua_result = nil

      vim.fn.timer_start(50, function()
        can_pass_lua_callback_to_vim_from_lua_result = true
      end)

      vim.wait(1000, function()
        return can_pass_lua_callback_to_vim_from_lua_result
      end)

      return can_pass_lua_callback_to_vim_from_lua_result
    ]])
  end)

  it('can run named functions more than once', function()
    eq(5, exec_lua [[
      count_of_vals = 0

      vim.fn.timer_start(5, function()
        count_of_vals = count_of_vals + 1
      end, {['repeat'] = 5})

      vim.fn.wait(1000, function()
        return count_of_vals >= 5
      end)

      return count_of_vals
    ]])
  end)

  it('can handle clashing names', function()
    eq(1, exec_lua [[
      local f_loc = function() return 1 end

      local result = nil
      vim.fn.timer_start(100, function()
        result = f_loc()
      end)

      local f_loc = function() return 2 end
      vim.wait(1000, function() return result ~= nil end)

      return result
    ]])
  end)

  it('can handle functions with errors', function()
    eq(true, exec_lua [[
      vim.fn.timer_start(10, function()
        error("dead function")
      end)

      vim.wait(1000, function() return false end)

      return true
    ]])
  end)

  it('should handle passing functions around', function()
    command [[
      function VimCanCallLuaCallbacks(Concat, Cb)
        let message = a:Concat("Hello Vim", "I'm Lua")
        call a:Cb(message)
      endfunction
    ]]

    eq("Hello Vim I'm Lua", exec_lua [[
      can_pass_lua_callback_to_vim_from_lua_result = ""

      vim.fn.VimCanCallLuaCallbacks(
        function(greeting, message) return greeting .. " " .. message end,
        function(message) can_pass_lua_callback_to_vim_from_lua_result = message end
      )

      return can_pass_lua_callback_to_vim_from_lua_result
    ]])
  end)

  it('should handle funcrefs', function()
    command [[
      function VimCanCallLuaCallbacks(Concat, Cb)
        let message = a:Concat("Hello Vim", "I'm Lua")
        call a:Cb(message)
      endfunction
    ]]

    eq("Hello Vim I'm Lua", exec_lua [[
      can_pass_lua_callback_to_vim_from_lua_result = ""

      vim.funcref('VimCanCallLuaCallbacks')(
        function(greeting, message) return greeting .. " " .. message end,
        function(message) can_pass_lua_callback_to_vim_from_lua_result = message end
      )

      return can_pass_lua_callback_to_vim_from_lua_result
    ]])
  end)

  it('should work with metatables using __call', function()
    eq(1, exec_lua [[
      local this_is_local_variable = false
      local callable_table = setmetatable({x = 1}, {
        __call = function(t, ...)
          this_is_local_variable = t.x
        end
      })

      vim.fn.timer_start(5, callable_table)

      vim.wait(1000, function()
        return this_is_local_variable
      end)

      return this_is_local_variable
    ]])
  end)

  it('should handle being called from a timer once.', function()
    eq(3, exec_lua [[
      local this_is_local_variable = false
      local callable_table = setmetatable({5, 4, 3, 2, 1}, {
        __call = function(t, ...) this_is_local_variable = t[3] end
      })

      vim.fn.timer_start(5, callable_table)
      vim.wait(1000, function()
        return this_is_local_variable
      end)

      return this_is_local_variable
    ]])
  end)

  it('should call functions once with __call metamethod', function()
    eq(true, exec_lua [[
      local this_is_local_variable = false
      local callable_table = setmetatable({a = true, b = false}, {
        __call = function(t, ...) this_is_local_variable = t.a end
      })

      assert(getmetatable(callable_table).__call)
      vim.fn.call(callable_table, {})

      return this_is_local_variable
    ]])
  end)

  it('should work with lists using __call', function()
    eq(3, exec_lua [[
      local this_is_local_variable = false
      local mt = {
        __call = function(t, ...)
          this_is_local_variable = t[3]
        end
      }
      local callable_table = setmetatable({5, 4, 3, 2, 1}, mt)

      -- Call it once...
      vim.fn.timer_start(5, callable_table)
      vim.wait(1000, function()
        return this_is_local_variable
      end)

      assert(this_is_local_variable)
      this_is_local_variable = false

      vim.fn.timer_start(5, callable_table)
      vim.wait(1000, function()
        return this_is_local_variable
      end)

      return this_is_local_variable
    ]])
  end)

  it('should not work with tables not using __call', function()
    eq({false, 'Vim:E921: Invalid callback argument'}, exec_lua [[
      local this_is_local_variable = false
      local callable_table = setmetatable({x = 1}, {})

      return {pcall(function() vim.fn.timer_start(5, callable_table) end)}
    ]])
  end)

  it('correctly converts containers with type_idx', function()
    eq(5, eval('type(luaeval("{[vim.type_idx]=vim.types.float, [vim.val_idx]=0}"))'))
    eq(4, eval([[type(luaeval('{[vim.type_idx]=vim.types.dictionary}'))]]))
    eq(3, eval([[type(luaeval('{[vim.type_idx]=vim.types.array}'))]]))

    eq({}, fn.luaeval('{[vim.type_idx]=vim.types.array}'))

    -- Presence of type_idx makes Vim ignore some keys
    eq({42}, fn.luaeval('{[vim.type_idx]=vim.types.array, [vim.val_idx]=10, [5]=1, foo=2, [1]=42}'))
    eq({foo=2}, fn.luaeval('{[vim.type_idx]=vim.types.dictionary, [vim.val_idx]=10, [5]=1, foo=2, [1]=42}'))
    eq(10, fn.luaeval('{[vim.type_idx]=vim.types.float, [vim.val_idx]=10, [5]=1, foo=2, [1]=42}'))

    -- The following should not crash
    eq({}, fn.luaeval('{[vim.type_idx]=vim.types.dictionary}'))
  end)

  it('correctly converts self-containing containers', function()
    api.nvim_set_var('l', {})
    eval('add(l, l)')
    eq(true, eval('luaeval("_A == _A[1]", l)'))
    eq(true, eval('luaeval("_A[1] == _A[1][1]", [l])'))
    eq(true, eval('luaeval("_A.d == _A.d[1]", {"d": l})'))
    eq(true, eval('luaeval("_A ~= _A[1]", [l])'))

    api.nvim_set_var('d', {foo=42})
    eval('extend(d, {"d": d})')
    eq(true, eval('luaeval("_A == _A.d", d)'))
    eq(true, eval('luaeval("_A[1] == _A[1].d", [d])'))
    eq(true, eval('luaeval("_A.d == _A.d.d", {"d": d})'))
    eq(true, eval('luaeval("_A ~= _A.d", {"d": d})'))
  end)

  it('errors out correctly when doing incorrect things in lua', function()
    -- Conversion errors
    eq('Vim(call):E5108: Error executing lua [string "luaeval()"]:1: attempt to call field \'xxx_nonexistent_key_xxx\' (a nil value)',
       remove_trace(exc_exec([[call luaeval("vim.xxx_nonexistent_key_xxx()")]])))
    eq('Vim(call):E5108: Error executing lua [string "luaeval()"]:1: ERROR',
       remove_trace(exc_exec([[call luaeval("error('ERROR')")]])))
    eq('Vim(call):E5108: Error executing lua [NULL]',
       remove_trace(exc_exec([[call luaeval("error(nil)")]])))
  end)

  it('does not leak memory when called with too long line',
  function()
    local s = ('x'):rep(65536)
    eq('Vim(call):E5107: Error loading lua [string "luaeval()"]:1: unexpected symbol near \')\'',
       exc_exec([[call luaeval("(']] .. s ..[[' + )")]]))
    eq(s, fn.luaeval('"' .. s .. '"'))
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
      function mymod.whatis(value)
        return type(value) .. ": " .. tostring(value)
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
    ]])
  end)

  it('works in expressions', function()
    eq(7, eval('v:lua.foo(3,4,v:null)'))
    eq(true, exec_lua([[return _G.val == vim.NIL]]))
    eq(NIL, eval('v:lua.mymod.noisy("eval")'))
    eq("hey eval", api.nvim_get_current_line())
    eq("string: abc", eval('v:lua.mymod.whatis(0z616263)'))
    eq("string: ", eval('v:lua.mymod.whatis(v:_null_blob)'))

    eq("Vim:E5108: Error executing lua [string \"<nvim>\"]:0: attempt to call global 'nonexistent' (a nil value)",
       pcall_err(eval, 'v:lua.mymod.crashy()'))
  end)

  it('works when called as a method', function()
    eq(123, eval('110->v:lua.foo(13)'))
    eq(true, exec_lua([[return _G.val == nil]]))

    eq(321, eval('300->v:lua.foo(21, "boop")'))
    eq("boop", exec_lua([[return _G.val]]))

    eq(NIL, eval('"there"->v:lua.mymod.noisy()'))
    eq("hey there", api.nvim_get_current_line())
    eq({5, 10, 15, 20}, eval('[[1], [2, 3], [4]]->v:lua.vim.tbl_flatten()->map({_, v -> v * 5})'))

    eq("Vim:E5108: Error executing lua [string \"<nvim>\"]:0: attempt to call global 'nonexistent' (a nil value)",
       pcall_err(eval, '"huh?"->v:lua.mymod.crashy()'))
  end)

  it('works in :call', function()
    command(":call v:lua.mymod.noisy('command')")
    eq("hey command", api.nvim_get_current_line())
    eq("Vim(call):E5108: Error executing lua [string \"<nvim>\"]:0: attempt to call global 'nonexistent' (a nil value)",
       pcall_err(command, 'call v:lua.mymod.crashy()'))
  end)

  it('works in func options', function()
    local screen = Screen.new(60, 8)
    screen:attach()
    api.nvim_set_option_value('omnifunc', 'v:lua.mymod.omni', {})
    feed('isome st<c-x><c-o>')
    screen:expect{grid=[[
      some stuff^                                                  |
      {1:~   }{12: stuff          }{1:                                        }|
      {1:~   }{4: steam          }{1:                                        }|
      {1:~   }{4: strange things }{1:                                        }|
      {1:~                                                           }|*3
      {5:-- Omni completion (^O^N^P) }{6:match 1 of 3}                    |
    ]]}
    api.nvim_set_option_value('operatorfunc', 'v:lua.mymod.noisy', {})
    feed('<Esc>g@g@')
    eq("hey line", api.nvim_get_current_line())
  end)

  it('supports packages', function()
    command('set pp+=test/functional/fixtures')
    eq('\tbadval', eval("v:lua.require'leftpad'('badval')"))
    eq(9003, eval("v:lua.require'bar'.doit()"))
    eq(9004, eval("v:lua.require'baz-quux'.doit()"))
    eq(9003, eval("1 ? v:lua.require'bar'.doit() : v:lua.require'baz-quux'.doit()"))
    eq(9004, eval("0 ? v:lua.require'bar'.doit() : v:lua.require'baz-quux'.doit()"))
  end)

  it('throw errors for invalid use', function()
    eq([[Vim(let):E15: Invalid expression: "v:lua.func"]], pcall_err(command, "let g:Func = v:lua.func"))
    eq([[Vim(let):E15: Invalid expression: "v:lua"]], pcall_err(command, "let g:Func = v:lua"))
    eq([[Vim(let):E15: Invalid expression: "v:['lua']"]], pcall_err(command, "let g:Func = v:['lua']"))

    eq([[Vim:E15: Invalid expression: "v:['lua'].foo()"]], pcall_err(eval, "v:['lua'].foo()"))
    eq("Vim(call):E461: Illegal variable name: v:['lua']", pcall_err(command, "call v:['lua'].baar()"))
    eq("Vim:E1085: Not a callable type: v:lua", pcall_err(eval, "v:lua()"))

    eq("Vim(let):E46: Cannot change read-only variable \"v:['lua']\"", pcall_err(command, "let v:['lua'] = 'xx'"))
    eq("Vim(let):E46: Cannot change read-only variable \"v:lua\"", pcall_err(command, "let v:lua = 'xx'"))

    eq("Vim:E107: Missing parentheses: v:lua.func", pcall_err(eval, "'bad'->v:lua.func"))
    eq("Vim:E274: No white space allowed before parenthesis", pcall_err(eval, "'bad'->v:lua.func ()"))
    eq("Vim:E107: Missing parentheses: v:lua", pcall_err(eval, "'bad'->v:lua"))
    eq("Vim:E1085: Not a callable type: v:lua", pcall_err(eval, "'bad'->v:lua()"))
    eq([[Vim:E15: Invalid expression: "v:lua.()"]], pcall_err(eval, "'bad'->v:lua.()"))

    eq("Vim:E1085: Not a callable type: v:lua", pcall_err(eval, "v:lua()"))
    eq([[Vim:E15: Invalid expression: "v:lua.()"]], pcall_err(eval, "v:lua.()"))
  end)

  describe('invalid use in fold text', function()
    before_each(function()
      feed('ifoo<CR>bar<Esc>')
      command('1,2fold')
    end)

    it('with missing function name when used as simple function', function()
      api.nvim_set_option_value('debug', 'throw', {})
      eq(
        [[Vim(eval):E15: Invalid expression: "v:lua.()"]],
        pcall_err(command, 'set foldtext=v:lua.() | eval foldtextresult(1)')
      )
    end)

    it('with missing function name when used in expression', function()
      api.nvim_set_option_value('debug', 'throw', {})
      eq(
        [[Vim(eval):E15: Invalid expression: "+v:lua.()"]],
        pcall_err(command, 'set foldtext=+v:lua.() | eval foldtextresult(1)')
      )
    end)

    it('with non-existent function when used as simple function', function()
      command('set foldtext=v:lua.NoSuchFunc() | eval foldtextresult(1)')
      assert_alive()
    end)

    it('with non-existent function when used in expression', function()
      command('set foldtext=+v:lua.NoSuchFunc() | eval foldtextresult(1)')
      assert_alive()
    end)
  end)
end)
