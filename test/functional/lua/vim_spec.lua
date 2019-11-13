-- Test suite for testing interactions with API bindings
local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local funcs = helpers.funcs
local meths = helpers.meths
local command = helpers.command
local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local feed = helpers.feed
local pcall_err = helpers.pcall_err
local exec_lua = helpers.exec_lua
local matches = helpers.matches
local source = helpers.source
local NIL = helpers.NIL
local retry = helpers.retry

before_each(clear)

describe('lua stdlib', function()
  -- İ: `tolower("İ")` is `i` which has length 1 while `İ` itself has
  --    length 2 (in bytes).
  -- Ⱥ: `tolower("Ⱥ")` is `ⱥ` which has length 2 while `Ⱥ` itself has
  --    length 3 (in bytes).
  --
  -- Note: 'i' !=? 'İ' and 'ⱥ' !=? 'Ⱥ' on some systems.
  -- Note: Built-in Nvim comparison (on systems lacking `strcasecmp`) works
  --       only on ASCII characters.
  it('vim.stricmp', function()
    eq(0, funcs.luaeval('vim.stricmp("a", "A")'))
    eq(0, funcs.luaeval('vim.stricmp("A", "a")'))
    eq(0, funcs.luaeval('vim.stricmp("a", "a")'))
    eq(0, funcs.luaeval('vim.stricmp("A", "A")'))

    eq(0, funcs.luaeval('vim.stricmp("", "")'))
    eq(0, funcs.luaeval('vim.stricmp("\\0", "\\0")'))
    eq(0, funcs.luaeval('vim.stricmp("\\0\\0", "\\0\\0")'))
    eq(0, funcs.luaeval('vim.stricmp("\\0\\0\\0", "\\0\\0\\0")'))
    eq(0, funcs.luaeval('vim.stricmp("\\0\\0\\0A", "\\0\\0\\0a")'))
    eq(0, funcs.luaeval('vim.stricmp("\\0\\0\\0a", "\\0\\0\\0A")'))
    eq(0, funcs.luaeval('vim.stricmp("\\0\\0\\0a", "\\0\\0\\0a")'))

    eq(0, funcs.luaeval('vim.stricmp("a\\0", "A\\0")'))
    eq(0, funcs.luaeval('vim.stricmp("A\\0", "a\\0")'))
    eq(0, funcs.luaeval('vim.stricmp("a\\0", "a\\0")'))
    eq(0, funcs.luaeval('vim.stricmp("A\\0", "A\\0")'))

    eq(0, funcs.luaeval('vim.stricmp("\\0a", "\\0A")'))
    eq(0, funcs.luaeval('vim.stricmp("\\0A", "\\0a")'))
    eq(0, funcs.luaeval('vim.stricmp("\\0a", "\\0a")'))
    eq(0, funcs.luaeval('vim.stricmp("\\0A", "\\0A")'))

    eq(0, funcs.luaeval('vim.stricmp("\\0a\\0", "\\0A\\0")'))
    eq(0, funcs.luaeval('vim.stricmp("\\0A\\0", "\\0a\\0")'))
    eq(0, funcs.luaeval('vim.stricmp("\\0a\\0", "\\0a\\0")'))
    eq(0, funcs.luaeval('vim.stricmp("\\0A\\0", "\\0A\\0")'))

    eq(-1, funcs.luaeval('vim.stricmp("a", "B")'))
    eq(-1, funcs.luaeval('vim.stricmp("A", "b")'))
    eq(-1, funcs.luaeval('vim.stricmp("a", "b")'))
    eq(-1, funcs.luaeval('vim.stricmp("A", "B")'))

    eq(-1, funcs.luaeval('vim.stricmp("", "\\0")'))
    eq(-1, funcs.luaeval('vim.stricmp("\\0", "\\0\\0")'))
    eq(-1, funcs.luaeval('vim.stricmp("\\0\\0", "\\0\\0\\0")'))
    eq(-1, funcs.luaeval('vim.stricmp("\\0\\0\\0A", "\\0\\0\\0b")'))
    eq(-1, funcs.luaeval('vim.stricmp("\\0\\0\\0a", "\\0\\0\\0B")'))
    eq(-1, funcs.luaeval('vim.stricmp("\\0\\0\\0a", "\\0\\0\\0b")'))

    eq(-1, funcs.luaeval('vim.stricmp("a\\0", "B\\0")'))
    eq(-1, funcs.luaeval('vim.stricmp("A\\0", "b\\0")'))
    eq(-1, funcs.luaeval('vim.stricmp("a\\0", "b\\0")'))
    eq(-1, funcs.luaeval('vim.stricmp("A\\0", "B\\0")'))

    eq(-1, funcs.luaeval('vim.stricmp("\\0a", "\\0B")'))
    eq(-1, funcs.luaeval('vim.stricmp("\\0A", "\\0b")'))
    eq(-1, funcs.luaeval('vim.stricmp("\\0a", "\\0b")'))
    eq(-1, funcs.luaeval('vim.stricmp("\\0A", "\\0B")'))

    eq(-1, funcs.luaeval('vim.stricmp("\\0a\\0", "\\0B\\0")'))
    eq(-1, funcs.luaeval('vim.stricmp("\\0A\\0", "\\0b\\0")'))
    eq(-1, funcs.luaeval('vim.stricmp("\\0a\\0", "\\0b\\0")'))
    eq(-1, funcs.luaeval('vim.stricmp("\\0A\\0", "\\0B\\0")'))

    eq(1, funcs.luaeval('vim.stricmp("c", "B")'))
    eq(1, funcs.luaeval('vim.stricmp("C", "b")'))
    eq(1, funcs.luaeval('vim.stricmp("c", "b")'))
    eq(1, funcs.luaeval('vim.stricmp("C", "B")'))

    eq(1, funcs.luaeval('vim.stricmp("\\0", "")'))
    eq(1, funcs.luaeval('vim.stricmp("\\0\\0", "\\0")'))
    eq(1, funcs.luaeval('vim.stricmp("\\0\\0\\0", "\\0\\0")'))
    eq(1, funcs.luaeval('vim.stricmp("\\0\\0\\0\\0", "\\0\\0\\0")'))
    eq(1, funcs.luaeval('vim.stricmp("\\0\\0\\0C", "\\0\\0\\0b")'))
    eq(1, funcs.luaeval('vim.stricmp("\\0\\0\\0c", "\\0\\0\\0B")'))
    eq(1, funcs.luaeval('vim.stricmp("\\0\\0\\0c", "\\0\\0\\0b")'))

    eq(1, funcs.luaeval('vim.stricmp("c\\0", "B\\0")'))
    eq(1, funcs.luaeval('vim.stricmp("C\\0", "b\\0")'))
    eq(1, funcs.luaeval('vim.stricmp("c\\0", "b\\0")'))
    eq(1, funcs.luaeval('vim.stricmp("C\\0", "B\\0")'))

    eq(1, funcs.luaeval('vim.stricmp("c\\0", "B")'))
    eq(1, funcs.luaeval('vim.stricmp("C\\0", "b")'))
    eq(1, funcs.luaeval('vim.stricmp("c\\0", "b")'))
    eq(1, funcs.luaeval('vim.stricmp("C\\0", "B")'))

    eq(1, funcs.luaeval('vim.stricmp("\\0c", "\\0B")'))
    eq(1, funcs.luaeval('vim.stricmp("\\0C", "\\0b")'))
    eq(1, funcs.luaeval('vim.stricmp("\\0c", "\\0b")'))
    eq(1, funcs.luaeval('vim.stricmp("\\0C", "\\0B")'))

    eq(1, funcs.luaeval('vim.stricmp("\\0c\\0", "\\0B\\0")'))
    eq(1, funcs.luaeval('vim.stricmp("\\0C\\0", "\\0b\\0")'))
    eq(1, funcs.luaeval('vim.stricmp("\\0c\\0", "\\0b\\0")'))
    eq(1, funcs.luaeval('vim.stricmp("\\0C\\0", "\\0B\\0")'))
  end)

  it("vim.str_utfindex/str_byteindex", function()
    exec_lua([[_G.test_text = "xy åäö ɧ 汉语 ↥ 🤦x🦄 å بِيَّ"]])
    local indicies32 = {[0]=0,1,2,3,5,7,9,10,12,13,16,19,20,23,24,28,29,33,34,35,37,38,40,42,44,46,48}
    local indicies16 = {[0]=0,1,2,3,5,7,9,10,12,13,16,19,20,23,24,28,28,29,33,33,34,35,37,38,40,42,44,46,48}
    for i,k in pairs(indicies32) do
      eq(k, exec_lua("return vim.str_byteindex(_G.test_text, ...)", i), i)
    end
    for i,k in pairs(indicies16) do
      eq(k, exec_lua("return vim.str_byteindex(_G.test_text, ..., true)", i), i)
    end
    local i32, i16 = 0, 0
    for k = 0,48 do
      if indicies32[i32] < k then
        i32 = i32 + 1
      end
      if indicies16[i16] < k then
        i16 = i16 + 1
        if indicies16[i16+1] == indicies16[i16] then
          i16 = i16 + 1
        end
      end
      eq({i32, i16}, exec_lua("return {vim.str_utfindex(_G.test_text, ...)}", k), k)
    end
  end)

  it("vim.schedule", function()
    exec_lua([[
      test_table = {}
      vim.schedule(function()
        table.insert(test_table, "xx")
      end)
      table.insert(test_table, "yy")
    ]])
    eq({"yy","xx"}, exec_lua("return test_table"))

    -- Validates args.
    eq('Error executing lua: vim.schedule: expected function',
      pcall_err(exec_lua, "vim.schedule('stringly')"))
    eq('Error executing lua: vim.schedule: expected function',
      pcall_err(exec_lua, "vim.schedule()"))

    exec_lua([[
      vim.schedule(function()
        error("big failure\nvery async")
      end)
    ]])

    feed("<cr>")
    eq('Error executing vim.schedule lua callback: [string "<nvim>"]:2: big failure\nvery async', eval("v:errmsg"))

    local screen = Screen.new(60,5)
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue1},
      [2] = {bold = true, reverse = true},
      [3] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
      [4] = {bold = true, foreground = Screen.colors.SeaGreen4},
    })
    screen:attach()
    screen:expect{grid=[[
      ^                                                            |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
                                                                  |
    ]]}

    -- nvim_command causes a vimL exception, check that it is properly caught
    -- and propagated as an error message in async contexts.. #10809
    exec_lua([[
      vim.schedule(function()
        vim.api.nvim_command(":echo 'err")
      end)
    ]])
    screen:expect{grid=[[
                                                                  |
      {2:                                                            }|
      {3:Error executing vim.schedule lua callback: [string "<nvim>"]}|
      {3::2: Vim(echo):E115: Missing quote: 'err}                     |
      {4:Press ENTER or type command to continue}^                     |
    ]]}
  end)

  it("vim.split", function()
    local split = function(str, sep, plain)
      return exec_lua('return vim.split(...)', str, sep, plain)
    end

    local tests = {
      { "a,b", ",", false, { 'a', 'b' } },
      { ":aa::bb:", ":", false, { '', 'aa', '', 'bb', '' } },
      { "::ee::ff:", ":", false, { '', '', 'ee', '', 'ff', '' } },
      { "ab", ".", false, { '', '', '' } },
      { "a1b2c", "[0-9]", false, { 'a', 'b', 'c' } },
      { "xy", "", false, { 'x', 'y' } },
      { "here be dragons", " ", false, { "here", "be", "dragons"} },
      { "axaby", "ab?", false, { '', 'x', 'y' } },
      { "f v2v v3v w2w ", "([vw])2%1", false, { 'f ', ' v3v ', ' ' } },
      { "x*yz*oo*l", "*", true, { 'x', 'yz', 'oo', 'l' } },
    }

    for _, t in ipairs(tests) do
      eq(t[4], split(t[1], t[2], t[3]))
    end

    local loops = {
      { "abc", ".-" },
    }

    for _, t in ipairs(loops) do
      matches(".*Infinite loop detected", pcall_err(split, t[1], t[2]))
    end

    -- Validates args.
    eq(true, pcall(split, 'string', 'string'))
    eq('Error executing lua: .../shared.lua: s: expected string, got number',
      pcall_err(split, 1, 'string'))
    eq('Error executing lua: .../shared.lua: sep: expected string, got number',
      pcall_err(split, 'string', 1))
    eq('Error executing lua: .../shared.lua: plain: expected boolean, got number',
      pcall_err(split, 'string', 'string', 1))
  end)

  it('vim.trim', function()
    local trim = function(s)
      return exec_lua('return vim.trim(...)', s)
    end

    local trims = {
      { "   a", "a" },
      { " b  ", "b" },
      { "\tc" , "c" },
      { "r\n", "r" },
    }

    for _, t in ipairs(trims) do
      assert(t[2], trim(t[1]))
    end

    -- Validates args.
    eq('Error executing lua: .../shared.lua: s: expected string, got number',
      pcall_err(trim, 2))
  end)

  it('vim.inspect', function()
    -- just make sure it basically works, it has its own test suite
    local inspect = function(t, opts)
      return exec_lua('return vim.inspect(...)', t, opts)
    end

    eq('2', inspect(2))
    eq('{+a = {+b = 1+}+}',
       inspect({ a = { b = 1 } }, { newline = '+', indent = '' }))

    -- special value vim.inspect.KEY works
    eq('{  KEY_a = "x",  KEY_b = "y"}', exec_lua([[
      return vim.inspect({a="x", b="y"}, {newline = '', process = function(item, path)
        if path[#path] == vim.inspect.KEY then
          return 'KEY_'..item
        end
        return item
      end})
    ]]))
  end)

  it("vim.deepcopy", function()
    local is_dc = exec_lua([[
      local a = { x = { 1, 2 }, y = 5}
      local b = vim.deepcopy(a)

      local count = 0
      for _ in pairs(b) do count = count + 1 end

      return b.x[1] == 1 and b.x[2] == 2 and b.y == 5 and count == 2
             and tostring(a) ~= tostring(b)
    ]])

    assert(is_dc)
  end)

  it('vim.pesc', function()
    eq('foo%-bar', exec_lua([[return vim.pesc('foo-bar')]]))
    eq('foo%%%-bar', exec_lua([[return vim.pesc(vim.pesc('foo-bar'))]]))

    -- Validates args.
    eq('Error executing lua: .../shared.lua: s: expected string, got number',
      pcall_err(exec_lua, [[return vim.pesc(2)]]))
  end)

  it('vim.tbl_keys', function()
    eq({}, exec_lua("return vim.tbl_keys({})"))
    for _, v in pairs(exec_lua("return vim.tbl_keys({'a', 'b', 'c'})")) do
      eq(true, exec_lua("return vim.tbl_contains({ 1, 2, 3 }, ...)", v))
    end
    for _, v in pairs(exec_lua("return vim.tbl_keys({a=1, b=2, c=3})")) do
      eq(true, exec_lua("return vim.tbl_contains({ 'a', 'b', 'c' }, ...)", v))
    end
  end)

  it('vim.tbl_values', function()
    eq({}, exec_lua("return vim.tbl_values({})"))
    for _, v in pairs(exec_lua("return vim.tbl_values({'a', 'b', 'c'})")) do
      eq(true, exec_lua("return vim.tbl_contains({ 'a', 'b', 'c' }, ...)", v))
    end
    for _, v in pairs(exec_lua("return vim.tbl_values({a=1, b=2, c=3})")) do
      eq(true, exec_lua("return vim.tbl_contains({ 1, 2, 3 }, ...)", v))
    end
  end)

  it('vim.tbl_islist', function()
    eq(NIL, exec_lua("return vim.tbl_islist({})"))
    eq(true, exec_lua("return vim.tbl_islist({'a', 'b', 'c'})"))
    eq(false, exec_lua("return vim.tbl_islist({'a', '32', a='hello', b='baz'})"))
    eq(false, exec_lua("return vim.tbl_islist({1, a='hello', b='baz'})"))
    eq(false, exec_lua("return vim.tbl_islist({a='hello', b='baz', 1})"))
    eq(false, exec_lua("return vim.tbl_islist({1, 2, nil, a='hello'})"))
  end)

  it('vim.tbl_isempty', function()
    eq(true, exec_lua("return vim.tbl_isempty({})"))
    eq(false, exec_lua("return vim.tbl_isempty({ 1, 2, 3 })"))
    eq(false, exec_lua("return vim.tbl_isempty({a=1, b=2, c=3})"))
  end)

  it('vim.deep_equal', function()
    eq(true, exec_lua [[ return vim.deep_equal({a=1}, {a=1}) ]])
    eq(true, exec_lua [[ return vim.deep_equal({a={b=1}}, {a={b=1}}) ]])
    eq(true, exec_lua [[ return vim.deep_equal({a={b={nil}}}, {a={b={}}}) ]])
    eq(true, exec_lua [[ return vim.deep_equal({a=1, [5]=5}, {nil,nil,nil,nil,5,a=1}) ]])
    eq(false, exec_lua [[ return vim.deep_equal(1, {nil,nil,nil,nil,5,a=1}) ]])
    eq(false, exec_lua [[ return vim.deep_equal(1, 3) ]])
    eq(false, exec_lua [[ return vim.deep_equal(nil, 3) ]])
    eq(false, exec_lua [[ return vim.deep_equal({a=1}, {a=2}) ]])
  end)

  it('vim.list_extend', function()
    eq({1,2,3}, exec_lua [[ return vim.list_extend({1}, {2,3}) ]])
    eq('Error executing lua: .../shared.lua: src must be a table',
      pcall_err(exec_lua, [[ return vim.list_extend({1}, nil) ]]))
    eq({1,2}, exec_lua [[ return vim.list_extend({1}, {2;a=1}) ]])
    eq(true, exec_lua [[ local a = {1} return vim.list_extend(a, {2;a=1}) == a ]])
  end)

  it('vim.tbl_add_reverse_lookup', function()
    eq(true, exec_lua [[
    local a = { A = 1 }
    vim.tbl_add_reverse_lookup(a)
    return vim.deep_equal(a, { A = 1; [1] = 'A'; })
    ]])
    -- Throw an error for trying to do it twice (run into an existing key)
    local code = [[
    local res = {}
    local a = { A = 1 }
    vim.tbl_add_reverse_lookup(a)
    assert(vim.deep_equal(a, { A = 1; [1] = 'A'; }))
    vim.tbl_add_reverse_lookup(a)
    ]]
    matches('Error executing lua: .../shared.lua: The reverse lookup found an existing value for "[1A]" while processing key "[1A]"',
      pcall_err(exec_lua, code))
  end)

  it('vim.call, vim.fn', function()
    eq(true, exec_lua([[return vim.call('sin', 0.0) == 0.0 ]]))
    eq(true, exec_lua([[return vim.fn.sin(0.0) == 0.0 ]]))
    -- compat: nvim_call_function uses "special" value for vimL float
    eq(false, exec_lua([[return vim.api.nvim_call_function('sin', {0.0}) == 0.0 ]]))

    source([[
      func! FooFunc(test)
        let g:test = a:test
        return {}
      endfunc
      func! VarArg(...)
        return a:000
      endfunc
      func! Nilly()
        return [v:null, v:null]
      endfunc
    ]])
    eq(true, exec_lua([[return next(vim.fn.FooFunc(3)) == nil ]]))
    eq(3, eval("g:test"))
    -- compat: nvim_call_function uses "special" value for empty dict
    eq(true, exec_lua([[return next(vim.api.nvim_call_function("FooFunc", {5})) == true ]]))
    eq(5, eval("g:test"))

    eq({2, "foo", true}, exec_lua([[return vim.fn.VarArg(2, "foo", true)]]))

    eq(true, exec_lua([[
      local x = vim.fn.Nilly()
      return #x == 2 and x[1] == vim.NIL and x[2] == vim.NIL
    ]]))
    eq({NIL, NIL}, exec_lua([[return vim.fn.Nilly()]]))

    -- error handling
    eq({false, 'Vim:E714: List required'}, exec_lua([[return {pcall(vim.fn.add, "aa", "bb")}]]))
  end)

  it('vim.rpcrequest and vim.rpcnotify', function()
    exec_lua([[
      chan = vim.fn.jobstart({'cat'}, {rpc=true})
      vim.rpcrequest(chan, 'nvim_set_current_line', 'meow')
    ]])
    eq('meow', meths.get_current_line())
    command("let x = [3, 'aa', v:true, v:null]")
    eq(true, exec_lua([[
      ret = vim.rpcrequest(chan, 'nvim_get_var', 'x')
      return #ret == 4 and ret[1] == 3 and ret[2] == 'aa' and ret[3] == true and ret[4] == vim.NIL
    ]]))
    eq({3, 'aa', true, NIL}, exec_lua([[return ret]]))

    -- error handling
    eq({false, 'Invalid channel: 23'},
       exec_lua([[return {pcall(vim.rpcrequest, 23, 'foo')}]]))
    eq({false, 'Invalid channel: 23'},
       exec_lua([[return {pcall(vim.rpcnotify, 23, 'foo')}]]))

    eq({false, 'Vim:E121: Undefined variable: foobar'},
       exec_lua([[return {pcall(vim.rpcrequest, chan, 'nvim_eval', "foobar")}]]))


    -- rpcnotify doesn't wait on request
    eq('meow', exec_lua([[
      vim.rpcnotify(chan, 'nvim_set_current_line', 'foo')
      return vim.api.nvim_get_current_line()
    ]]))
    retry(10, nil, function()
      eq('foo', meths.get_current_line())
    end)

    local screen = Screen.new(50,7)
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue1},
      [2] = {bold = true, reverse = true},
      [3] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
      [4] = {bold = true, foreground = Screen.colors.SeaGreen4},
    })
    screen:attach()
    exec_lua([[
      local timer = vim.loop.new_timer()
      timer:start(20, 0, function ()
        -- notify ok (executed later when safe)
        vim.rpcnotify(chan, 'nvim_set_var', 'yy', {3, vim.NIL})
        -- rpcrequest an error
        vim.rpcrequest(chan, 'nvim_set_current_line', 'bork')
      end)
    ]])
    screen:expect{grid=[[
      foo                                               |
      {1:~                                                 }|
      {2:                                                  }|
      {3:Error executing luv callback:}                     |
      {3:[string "<nvim>"]:6: E5560: rpcrequest must not be}|
      {3: called in a lua loop callback}                    |
      {4:Press ENTER or type command to continue}^           |
    ]]}
    feed('<cr>')
    eq({3, NIL}, meths.get_var('yy'))
  end)

  it('vim.validate', function()
    exec_lua("vim.validate{arg1={{}, 'table' }}")
    exec_lua("vim.validate{arg1={{}, 't' }}")
    exec_lua("vim.validate{arg1={nil, 't', true }}")
    exec_lua("vim.validate{arg1={{ foo='foo' }, 't' }}")
    exec_lua("vim.validate{arg1={{ 'foo' }, 't' }}")
    exec_lua("vim.validate{arg1={'foo', 'string' }}")
    exec_lua("vim.validate{arg1={'foo', 's' }}")
    exec_lua("vim.validate{arg1={'', 's' }}")
    exec_lua("vim.validate{arg1={nil, 's', true }}")
    exec_lua("vim.validate{arg1={1, 'number' }}")
    exec_lua("vim.validate{arg1={1, 'n' }}")
    exec_lua("vim.validate{arg1={0, 'n' }}")
    exec_lua("vim.validate{arg1={0.1, 'n' }}")
    exec_lua("vim.validate{arg1={nil, 'n', true }}")
    exec_lua("vim.validate{arg1={true, 'boolean' }}")
    exec_lua("vim.validate{arg1={true, 'b' }}")
    exec_lua("vim.validate{arg1={false, 'b' }}")
    exec_lua("vim.validate{arg1={nil, 'b', true }}")
    exec_lua("vim.validate{arg1={function()end, 'function' }}")
    exec_lua("vim.validate{arg1={function()end, 'f' }}")
    exec_lua("vim.validate{arg1={nil, 'f', true }}")
    exec_lua("vim.validate{arg1={nil, 'nil' }}")
    exec_lua("vim.validate{arg1={nil, 'nil', true }}")
    exec_lua("vim.validate{arg1={coroutine.create(function()end), 'thread' }}")
    exec_lua("vim.validate{arg1={nil, 'thread', true }}")
    exec_lua("vim.validate{arg1={{}, 't' }, arg2={ 'foo', 's' }}")
    exec_lua("vim.validate{arg1={2, function(a) return (a % 2) == 0  end, 'even number' }}")

    eq("Error executing lua: .../shared.lua: 1: expected table, got number",
      pcall_err(exec_lua, "vim.validate{ 1, 'x' }"))
    eq("Error executing lua: .../shared.lua: invalid type name: x",
      pcall_err(exec_lua, "vim.validate{ arg1={ 1, 'x' }}"))
    eq("Error executing lua: .../shared.lua: invalid type name: 1",
      pcall_err(exec_lua, "vim.validate{ arg1={ 1, 1 }}"))
    eq("Error executing lua: .../shared.lua: invalid type name: nil",
      pcall_err(exec_lua, "vim.validate{ arg1={ 1 }}"))

    -- Validated parameters are required by default.
    eq("Error executing lua: .../shared.lua: arg1: expected string, got nil",
      pcall_err(exec_lua, "vim.validate{ arg1={ nil, 's' }}"))
    -- Explicitly required.
    eq("Error executing lua: .../shared.lua: arg1: expected string, got nil",
      pcall_err(exec_lua, "vim.validate{ arg1={ nil, 's', false }}"))

    eq("Error executing lua: .../shared.lua: arg1: expected table, got number",
      pcall_err(exec_lua, "vim.validate{arg1={1, 't'}}"))
    eq("Error executing lua: .../shared.lua: arg2: expected string, got number",
      pcall_err(exec_lua, "vim.validate{arg1={{}, 't'}, arg2={1, 's'}}"))
    eq("Error executing lua: .../shared.lua: arg2: expected string, got nil",
      pcall_err(exec_lua, "vim.validate{arg1={{}, 't'}, arg2={nil, 's'}}"))
    eq("Error executing lua: .../shared.lua: arg2: expected string, got nil",
      pcall_err(exec_lua, "vim.validate{arg1={{}, 't'}, arg2={nil, 's'}}"))
    eq("Error executing lua: .../shared.lua: arg1: expected even number, got 3",
      pcall_err(exec_lua, "vim.validate{arg1={3, function(a) return a == 1 end, 'even number'}}"))
    eq("Error executing lua: .../shared.lua: arg1: expected ?, got 3",
      pcall_err(exec_lua, "vim.validate{arg1={3, function(a) return a == 1 end}}"))
  end)

  it('vim.is_callable', function()
    eq(true, exec_lua("return vim.is_callable(function()end)"))
    eq(true, exec_lua([[
      local meta = { __call = function()end }
      local function new_callable()
        return setmetatable({}, meta)
      end
      local callable = new_callable()
      return vim.is_callable(callable)
    ]]))

    eq(false, exec_lua("return vim.is_callable(1)"))
    eq(false, exec_lua("return vim.is_callable('foo')"))
    eq(false, exec_lua("return vim.is_callable({})"))
  end)
end)
