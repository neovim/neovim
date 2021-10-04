-- Test suite for testing interactions with API bindings
local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local funcs = helpers.funcs
local meths = helpers.meths
local dedent = helpers.dedent
local command = helpers.command
local insert = helpers.insert
local clear = helpers.clear
local eq = helpers.eq
local ok = helpers.ok
local eval = helpers.eval
local feed = helpers.feed
local pcall_err = helpers.pcall_err
local exec_lua = helpers.exec_lua
local matches = helpers.matches
local source = helpers.source
local NIL = helpers.NIL
local retry = helpers.retry
local next_msg = helpers.next_msg

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

  -- for brevity, match only the error header (not the traceback)
  local function pcall_header(...)
    return string.gsub(string.gsub(pcall_err(exec_lua, ...), '[\r\n].*', ''), '^Error executing lua: ', '')
  end

  it('vim.startswith', function()
    eq(true, funcs.luaeval('vim.startswith("123", "1")'))
    eq(true, funcs.luaeval('vim.startswith("123", "")'))
    eq(true, funcs.luaeval('vim.startswith("123", "123")'))
    eq(true, funcs.luaeval('vim.startswith("", "")'))

    eq(false, funcs.luaeval('vim.startswith("123", " ")'))
    eq(false, funcs.luaeval('vim.startswith("123", "2")'))
    eq(false, funcs.luaeval('vim.startswith("123", "1234")'))

    eq("vim/shared.lua:0: prefix: expected string, got nil", pcall_header 'return vim.startswith("123", nil)')
    eq("vim/shared.lua:0: s: expected string, got nil", pcall_header 'return vim.startswith(nil, "123")')
  end)

  it('vim.endswith', function()
    eq(true, funcs.luaeval('vim.endswith("123", "3")'))
    eq(true, funcs.luaeval('vim.endswith("123", "")'))
    eq(true, funcs.luaeval('vim.endswith("123", "123")'))
    eq(true, funcs.luaeval('vim.endswith("", "")'))

    eq(false, funcs.luaeval('vim.endswith("123", " ")'))
    eq(false, funcs.luaeval('vim.endswith("123", "2")'))
    eq(false, funcs.luaeval('vim.endswith("123", "1234")'))

    eq("vim/shared.lua:0: suffix: expected string, got nil", pcall_header 'return vim.endswith("123", nil)')
    eq("vim/shared.lua:0: s: expected string, got nil", pcall_header 'return vim.endswith(nil, "123")')
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
    local split = function(str, sep, kwargs)
      return exec_lua('return vim.split(...)', str, sep, kwargs)
    end

    local tests = {
      { "a,b", ",", false, false, { 'a', 'b' } },
      { ":aa::bb:", ":", false, false, { '', 'aa', '', 'bb', '' } },
      { ":aa::bb:", ":", false, true, { 'aa', '', 'bb' } },
      { "::ee::ff:", ":", false, false, { '', '', 'ee', '', 'ff', '' } },
      { "::ee::ff:", ":", false, true, { 'ee', '', 'ff' } },
      { "ab", ".", false, false, { '', '', '' } },
      { "a1b2c", "[0-9]", false, false, { 'a', 'b', 'c' } },
      { "xy", "", false, false, { 'x', 'y' } },
      { "here be dragons", " ", false, false, { "here", "be", "dragons"} },
      { "axaby", "ab?", false, false, { '', 'x', 'y' } },
      { "f v2v v3v w2w ", "([vw])2%1", false, false, { 'f ', ' v3v ', ' ' } },
      { "", "", false, false, {} },
      { "", "a", false, false, { '' } },
      { "x*yz*oo*l", "*", true, false, { 'x', 'yz', 'oo', 'l' } },
    }

    for _, t in ipairs(tests) do
      eq(t[5], split(t[1], t[2], {plain=t[3], trimempty=t[4]}))
    end

    -- Test old signature
    eq({'x', 'yz', 'oo', 'l'}, split("x*yz*oo*l", "*", true))

    local loops = {
      { "abc", ".-" },
    }

    for _, t in ipairs(loops) do
      eq("Error executing lua: vim/shared.lua:0: Infinite loop detected", pcall_err(split, t[1], t[2]))
    end

    -- Validates args.
    eq(true, pcall(split, 'string', 'string'))
    eq(dedent([[
        Error executing lua: vim/shared.lua:0: s: expected string, got number
        stack traceback:
            vim/shared.lua:0: in function 'gsplit'
            vim/shared.lua:0: in function <vim/shared.lua:0>]]),
      pcall_err(split, 1, 'string'))
    eq(dedent([[
        Error executing lua: vim/shared.lua:0: sep: expected string, got number
        stack traceback:
            vim/shared.lua:0: in function 'gsplit'
            vim/shared.lua:0: in function <vim/shared.lua:0>]]),
      pcall_err(split, 'string', 1))
    eq(dedent([[
        Error executing lua: vim/shared.lua:0: kwargs: expected table, got number
        stack traceback:
            vim/shared.lua:0: in function <vim/shared.lua:0>]]),
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
    eq(dedent([[
        Error executing lua: vim/shared.lua:0: s: expected string, got number
        stack traceback:
            vim/shared.lua:0: in function <vim/shared.lua:0>]]),
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
    ok(exec_lua([[
      local a = { x = { 1, 2 }, y = 5}
      local b = vim.deepcopy(a)

      return b.x[1] == 1 and b.x[2] == 2 and b.y == 5 and vim.tbl_count(b) == 2
             and tostring(a) ~= tostring(b)
    ]]))

    ok(exec_lua([[
      local a = {}
      local b = vim.deepcopy(a)

      return vim.tbl_islist(b) and vim.tbl_count(b) == 0 and tostring(a) ~= tostring(b)
    ]]))

    ok(exec_lua([[
      local a = vim.empty_dict()
      local b = vim.deepcopy(a)

      return not vim.tbl_islist(b) and vim.tbl_count(b) == 0
    ]]))

    ok(exec_lua([[
      local a = {x = vim.empty_dict(), y = {}}
      local b = vim.deepcopy(a)

      return not vim.tbl_islist(b.x) and vim.tbl_islist(b.y)
        and vim.tbl_count(b) == 2
        and tostring(a) ~= tostring(b)
    ]]))

    ok(exec_lua([[
      local f1 = function() return 1 end
      local f2 = function() return 2 end
      local t1 = {f = f1}
      local t2 = vim.deepcopy(t1)
      t1.f = f2
      return t1.f() ~= t2.f()
    ]]))

    eq('Error executing lua: vim/shared.lua:0: Cannot deepcopy object of type thread',
      pcall_err(exec_lua, [[
        local thread = coroutine.create(function () return 0 end)
        local t = {thr = thread}
        vim.deepcopy(t)
      ]]))
  end)

  it('vim.pesc', function()
    eq('foo%-bar', exec_lua([[return vim.pesc('foo-bar')]]))
    eq('foo%%%-bar', exec_lua([[return vim.pesc(vim.pesc('foo-bar'))]]))

    -- Validates args.
    eq(dedent([[
        Error executing lua: vim/shared.lua:0: s: expected string, got number
        stack traceback:
            vim/shared.lua:0: in function <vim/shared.lua:0>]]),
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

  it('vim.tbl_map', function()
    eq({}, exec_lua([[
      return vim.tbl_map(function(v) return v * 2 end, {})
    ]]))
    eq({2, 4, 6}, exec_lua([[
      return vim.tbl_map(function(v) return v * 2 end, {1, 2, 3})
    ]]))
    eq({{i=2}, {i=4}, {i=6}}, exec_lua([[
      return vim.tbl_map(function(v) return { i = v.i * 2 } end, {{i=1}, {i=2}, {i=3}})
    ]]))
  end)

  it('vim.tbl_filter', function()
    eq({}, exec_lua([[
      return vim.tbl_filter(function(v) return (v % 2) == 0 end, {})
    ]]))
    eq({2}, exec_lua([[
      return vim.tbl_filter(function(v) return (v % 2) == 0 end, {1, 2, 3})
    ]]))
    eq({{i=2}}, exec_lua([[
      return vim.tbl_filter(function(v) return (v.i % 2) == 0 end, {{i=1}, {i=2}, {i=3}})
    ]]))
  end)

  it('vim.tbl_islist', function()
    eq(true, exec_lua("return vim.tbl_islist({})"))
    eq(false, exec_lua("return vim.tbl_islist(vim.empty_dict())"))
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

  it('vim.tbl_extend', function()
    ok(exec_lua([[
      local a = {x = 1}
      local b = {y = 2}
      local c = vim.tbl_extend("keep", a, b)

      return c.x == 1 and b.y == 2 and vim.tbl_count(c) == 2
    ]]))

    ok(exec_lua([[
      local a = {x = 1}
      local b = {y = 2}
      local c = {z = 3}
      local d = vim.tbl_extend("keep", a, b, c)

      return d.x == 1 and d.y == 2 and d.z == 3 and vim.tbl_count(d) == 3
    ]]))

    ok(exec_lua([[
      local a = {x = 1}
      local b = {x = 3}
      local c = vim.tbl_extend("keep", a, b)

      return c.x == 1 and vim.tbl_count(c) == 1
    ]]))

    ok(exec_lua([[
      local a = {x = 1}
      local b = {x = 3}
      local c = vim.tbl_extend("force", a, b)

      return c.x == 3 and vim.tbl_count(c) == 1
    ]]))

    ok(exec_lua([[
      local a = vim.empty_dict()
      local b = {}
      local c = vim.tbl_extend("keep", a, b)

      return not vim.tbl_islist(c) and vim.tbl_count(c) == 0
    ]]))

    ok(exec_lua([[
      local a = {}
      local b = vim.empty_dict()
      local c = vim.tbl_extend("keep", a, b)

      return vim.tbl_islist(c) and vim.tbl_count(c) == 0
    ]]))

    ok(exec_lua([[
      local a = {x = {a = 1, b = 2}}
      local b = {x = {a = 2, c = {y = 3}}}
      local c = vim.tbl_extend("keep", a, b)

      local count = 0
      for _ in pairs(c) do count = count + 1 end

      return c.x.a == 1 and c.x.b == 2 and c.x.c == nil and count == 1
    ]]))

    eq('Error executing lua: vim/shared.lua:0: invalid "behavior": nil',
      pcall_err(exec_lua, [[
        return vim.tbl_extend()
      ]])
    )

    eq('Error executing lua: vim/shared.lua:0: wrong number of arguments (given 1, expected at least 3)',
      pcall_err(exec_lua, [[
        return vim.tbl_extend("keep")
      ]])
    )

    eq('Error executing lua: vim/shared.lua:0: wrong number of arguments (given 2, expected at least 3)',
      pcall_err(exec_lua, [[
        return vim.tbl_extend("keep", {})
      ]])
    )
  end)

  it('vim.tbl_deep_extend', function()
    ok(exec_lua([[
      local a = {x = {a = 1, b = 2}}
      local b = {x = {a = 2, c = {y = 3}}}
      local c = vim.tbl_deep_extend("keep", a, b)

      local count = 0
      for _ in pairs(c) do count = count + 1 end

      return c.x.a == 1 and c.x.b == 2 and c.x.c.y == 3 and count == 1
    ]]))

    ok(exec_lua([[
      local a = {x = {a = 1, b = 2}}
      local b = {x = {a = 2, c = {y = 3}}}
      local c = vim.tbl_deep_extend("force", a, b)

      local count = 0
      for _ in pairs(c) do count = count + 1 end

      return c.x.a == 2 and c.x.b == 2 and c.x.c.y == 3 and count == 1
    ]]))

    ok(exec_lua([[
      local a = {x = {a = 1, b = 2}}
      local b = {x = {a = 2, c = {y = 3}}}
      local c = {x = {c = 4, d = {y = 4}}}
      local d = vim.tbl_deep_extend("keep", a, b, c)

      local count = 0
      for _ in pairs(c) do count = count + 1 end

      return d.x.a == 1 and d.x.b == 2 and d.x.c.y == 3 and d.x.d.y == 4 and count == 1
    ]]))

    ok(exec_lua([[
      local a = {x = {a = 1, b = 2}}
      local b = {x = {a = 2, c = {y = 3}}}
      local c = {x = {c = 4, d = {y = 4}}}
      local d = vim.tbl_deep_extend("force", a, b, c)

      local count = 0
      for _ in pairs(c) do count = count + 1 end

      return d.x.a == 2 and d.x.b == 2 and d.x.c == 4 and d.x.d.y == 4 and count == 1
    ]]))

    ok(exec_lua([[
      local a = vim.empty_dict()
      local b = {}
      local c = vim.tbl_deep_extend("keep", a, b)

      local count = 0
      for _ in pairs(c) do count = count + 1 end

      return not vim.tbl_islist(c) and count == 0
    ]]))

    ok(exec_lua([[
      local a = {}
      local b = vim.empty_dict()
      local c = vim.tbl_deep_extend("keep", a, b)

      local count = 0
      for _ in pairs(c) do count = count + 1 end

      return vim.tbl_islist(c) and count == 0
    ]]))

    eq(exec_lua([[
      local a = { a = { b = 1 } }
      local b = { a = {} }
      return vim.tbl_deep_extend("force", a, b)
    ]]), {a = {b = 1}})

    eq(exec_lua([[
      local a = { a = 123 }
      local b = { a = { b = 1} }
      return vim.tbl_deep_extend("force", a, b)
    ]]), {a = {b = 1}})

    ok(exec_lua([[
      local a = { a = {[2] = 3} }
      local b = { a = {[3] = 3} }
      local c = vim.tbl_deep_extend("force", a, b)
      return vim.deep_equal(c, {a = {[3] = 3}})
    ]]))

    eq(exec_lua([[
      local a = { a = { b = 1} }
      local b = { a = 123 }
      return vim.tbl_deep_extend("force", a, b)
    ]]), {a = 123 })

    eq('Error executing lua: vim/shared.lua:0: invalid "behavior": nil',
      pcall_err(exec_lua, [[
        return vim.tbl_deep_extend()
      ]])
    )

    eq('Error executing lua: vim/shared.lua:0: wrong number of arguments (given 1, expected at least 3)',
      pcall_err(exec_lua, [[
        return vim.tbl_deep_extend("keep")
      ]])
    )

    eq('Error executing lua: vim/shared.lua:0: wrong number of arguments (given 2, expected at least 3)',
      pcall_err(exec_lua, [[
        return vim.tbl_deep_extend("keep", {})
      ]])
    )
  end)

  it('vim.tbl_count', function()
    eq(0, exec_lua [[ return vim.tbl_count({}) ]])
    eq(0, exec_lua [[ return vim.tbl_count(vim.empty_dict()) ]])
    eq(0, exec_lua [[ return vim.tbl_count({nil}) ]])
    eq(0, exec_lua [[ return vim.tbl_count({a=nil}) ]])
    eq(1, exec_lua [[ return vim.tbl_count({1}) ]])
    eq(2, exec_lua [[ return vim.tbl_count({1, 2}) ]])
    eq(2, exec_lua [[ return vim.tbl_count({1, nil, 3}) ]])
    eq(1, exec_lua [[ return vim.tbl_count({a=1}) ]])
    eq(2, exec_lua [[ return vim.tbl_count({a=1, b=2}) ]])
    eq(2, exec_lua [[ return vim.tbl_count({a=1, b=nil, c=3}) ]])
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
    eq(dedent([[
        Error executing lua: vim/shared.lua:0: src: expected table, got nil
        stack traceback:
            vim/shared.lua:0: in function <vim/shared.lua:0>]]),
      pcall_err(exec_lua, [[ return vim.list_extend({1}, nil) ]]))
    eq({1,2}, exec_lua [[ return vim.list_extend({1}, {2;a=1}) ]])
    eq(true, exec_lua [[ local a = {1} return vim.list_extend(a, {2;a=1}) == a ]])
    eq({2}, exec_lua [[ return vim.list_extend({}, {2;a=1}, 1) ]])
    eq({}, exec_lua [[ return vim.list_extend({}, {2;a=1}, 2) ]])
    eq({}, exec_lua [[ return vim.list_extend({}, {2;a=1}, 1, -1) ]])
    eq({2}, exec_lua [[ return vim.list_extend({}, {2;a=1}, -1, 2) ]])
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
    matches('^Error executing lua: vim/shared%.lua:0: The reverse lookup found an existing value for "[1A]" while processing key "[1A]"$',
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
    eq({false, 'Vim:E897: List or Blob required'}, exec_lua([[return {pcall(vim.fn.add, "aa", "bb")}]]))
  end)

  it('vim.fn should error when calling API function', function()
      eq('Error executing lua: vim.lua:0: Tried to call API function with vim.fn: use vim.api.nvim_get_current_line instead',
          pcall_err(exec_lua, "vim.fn.nvim_get_current_line()"))
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

    eq({{}, {}, false, true}, exec_lua([[
      vim.rpcrequest(chan, 'nvim_exec', 'let xx = {}\nlet yy = []', false)
      local dict = vim.rpcrequest(chan, 'nvim_eval', 'xx')
      local list = vim.rpcrequest(chan, 'nvim_eval', 'yy')
      return {dict, list, vim.tbl_islist(dict), vim.tbl_islist(list)}
     ]]))

     exec_lua([[
       vim.rpcrequest(chan, 'nvim_set_var', 'aa', {})
       vim.rpcrequest(chan, 'nvim_set_var', 'bb', vim.empty_dict())
     ]])
     eq({1, 1}, eval('[type(g:aa) == type([]), type(g:bb) == type({})]'))

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
      timer = vim.loop.new_timer()
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

    exec_lua([[timer:close()]])
  end)

  it('vim.empty_dict()', function()
    eq({true, false, true, true}, exec_lua([[
      vim.api.nvim_set_var('listy', {})
      vim.api.nvim_set_var('dicty', vim.empty_dict())
      local listy = vim.fn.eval("listy")
      local dicty = vim.fn.eval("dicty")
      return {vim.tbl_islist(listy), vim.tbl_islist(dicty), next(listy) == nil, next(dicty) == nil}
    ]]))

    -- vim.empty_dict() gives new value each time
    -- equality is not overriden (still by ref)
    -- non-empty table uses the usual heuristics (ignores the tag)
    eq({false, {"foo"}, {namey="bar"}}, exec_lua([[
      local aa = vim.empty_dict()
      local bb = vim.empty_dict()
      local equally = (aa == bb)
      aa[1] = "foo"
      bb["namey"] = "bar"
      return {equally, aa, bb}
    ]]))

    eq("{ {}, vim.empty_dict() }", exec_lua("return vim.inspect({{}, vim.empty_dict()})"))
    eq('{}', exec_lua([[ return vim.fn.json_encode(vim.empty_dict()) ]]))
    eq('{"a": {}, "b": []}', exec_lua([[ return vim.fn.json_encode({a=vim.empty_dict(), b={}}) ]]))
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

    eq(dedent([[
        Error executing lua: [string "<nvim>"]:0: opt[1]: expected table, got number
        stack traceback:
            [string "<nvim>"]:0: in main chunk]]),
      pcall_err(exec_lua, "vim.validate{ 1, 'x' }"))
    eq(dedent([[
        Error executing lua: [string "<nvim>"]:0: invalid type name: x
        stack traceback:
            [string "<nvim>"]:0: in main chunk]]),
      pcall_err(exec_lua, "vim.validate{ arg1={ 1, 'x' }}"))
    eq(dedent([[
        Error executing lua: [string "<nvim>"]:0: invalid type name: 1
        stack traceback:
            [string "<nvim>"]:0: in main chunk]]),
      pcall_err(exec_lua, "vim.validate{ arg1={ 1, 1 }}"))
    eq(dedent([[
        Error executing lua: [string "<nvim>"]:0: invalid type name: nil
        stack traceback:
            [string "<nvim>"]:0: in main chunk]]),
      pcall_err(exec_lua, "vim.validate{ arg1={ 1 }}"))

    -- Validated parameters are required by default.
    eq(dedent([[
        Error executing lua: [string "<nvim>"]:0: arg1: expected string, got nil
        stack traceback:
            [string "<nvim>"]:0: in main chunk]]),
      pcall_err(exec_lua, "vim.validate{ arg1={ nil, 's' }}"))
    -- Explicitly required.
    eq(dedent([[
        Error executing lua: [string "<nvim>"]:0: arg1: expected string, got nil
        stack traceback:
            [string "<nvim>"]:0: in main chunk]]),
      pcall_err(exec_lua, "vim.validate{ arg1={ nil, 's', false }}"))

    eq(dedent([[
        Error executing lua: [string "<nvim>"]:0: arg1: expected table, got number
        stack traceback:
            [string "<nvim>"]:0: in main chunk]]),
      pcall_err(exec_lua, "vim.validate{arg1={1, 't'}}"))
    eq(dedent([[
        Error executing lua: [string "<nvim>"]:0: arg2: expected string, got number
        stack traceback:
            [string "<nvim>"]:0: in main chunk]]),
      pcall_err(exec_lua, "vim.validate{arg1={{}, 't'}, arg2={1, 's'}}"))
    eq(dedent([[
        Error executing lua: [string "<nvim>"]:0: arg2: expected string, got nil
        stack traceback:
            [string "<nvim>"]:0: in main chunk]]),
      pcall_err(exec_lua, "vim.validate{arg1={{}, 't'}, arg2={nil, 's'}}"))
    eq(dedent([[
        Error executing lua: [string "<nvim>"]:0: arg2: expected string, got nil
        stack traceback:
            [string "<nvim>"]:0: in main chunk]]),
      pcall_err(exec_lua, "vim.validate{arg1={{}, 't'}, arg2={nil, 's'}}"))
    eq(dedent([[
        Error executing lua: [string "<nvim>"]:0: arg1: expected even number, got 3
        stack traceback:
            [string "<nvim>"]:0: in main chunk]]),
      pcall_err(exec_lua, "vim.validate{arg1={3, function(a) return a == 1 end, 'even number'}}"))
    eq(dedent([[
        Error executing lua: [string "<nvim>"]:0: arg1: expected ?, got 3
        stack traceback:
            [string "<nvim>"]:0: in main chunk]]),
      pcall_err(exec_lua, "vim.validate{arg1={3, function(a) return a == 1 end}}"))

    -- Pass an additional message back.
    eq(dedent([[
        Error executing lua: [string "<nvim>"]:0: arg1: expected ?, got 3. Info: TEST_MSG
        stack traceback:
            [string "<nvim>"]:0: in main chunk]]),
      pcall_err(exec_lua, "vim.validate{arg1={3, function(a) return a == 1, 'TEST_MSG' end}}"))
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

  it('vim.g', function()
    exec_lua [[
    vim.api.nvim_set_var("testing", "hi")
    vim.api.nvim_set_var("other", 123)
    vim.api.nvim_set_var("floaty", 5120.1)
    vim.api.nvim_set_var("nullvar", vim.NIL)
    vim.api.nvim_set_var("to_delete", {hello="world"})
    ]]

    eq('hi', funcs.luaeval "vim.g.testing")
    eq(123, funcs.luaeval "vim.g.other")
    eq(5120.1, funcs.luaeval "vim.g.floaty")
    eq(NIL, funcs.luaeval "vim.g.nonexistant")
    eq(NIL, funcs.luaeval "vim.g.nullvar")
    -- lost over RPC, so test locally:
    eq({false, true}, exec_lua [[
      return {vim.g.nonexistant == vim.NIL, vim.g.nullvar == vim.NIL}
    ]])

    eq({hello="world"}, funcs.luaeval "vim.g.to_delete")
    exec_lua [[
    vim.g.to_delete = nil
    ]]
    eq(NIL, funcs.luaeval "vim.g.to_delete")
  end)

  it('vim.b', function()
    exec_lua [[
    vim.api.nvim_buf_set_var(0, "testing", "hi")
    vim.api.nvim_buf_set_var(0, "other", 123)
    vim.api.nvim_buf_set_var(0, "floaty", 5120.1)
    vim.api.nvim_buf_set_var(0, "nullvar", vim.NIL)
    vim.api.nvim_buf_set_var(0, "to_delete", {hello="world"})
    ]]

    eq('hi', funcs.luaeval "vim.b.testing")
    eq(123, funcs.luaeval "vim.b.other")
    eq(5120.1, funcs.luaeval "vim.b.floaty")
    eq(NIL, funcs.luaeval "vim.b.nonexistant")
    eq(NIL, funcs.luaeval "vim.b.nullvar")
    -- lost over RPC, so test locally:
    eq({false, true}, exec_lua [[
      return {vim.b.nonexistant == vim.NIL, vim.b.nullvar == vim.NIL}
    ]])

    eq({hello="world"}, funcs.luaeval "vim.b.to_delete")
    exec_lua [[
    vim.b.to_delete = nil
    ]]
    eq(NIL, funcs.luaeval "vim.b.to_delete")

    exec_lua [[
    vim.cmd "vnew"
    ]]

    eq(NIL, funcs.luaeval "vim.b.testing")
    eq(NIL, funcs.luaeval "vim.b.other")
    eq(NIL, funcs.luaeval "vim.b.nonexistant")
  end)

  it('vim.w', function()
    exec_lua [[
    vim.api.nvim_win_set_var(0, "testing", "hi")
    vim.api.nvim_win_set_var(0, "other", 123)
    vim.api.nvim_win_set_var(0, "to_delete", {hello="world"})
    ]]

    eq('hi', funcs.luaeval "vim.w.testing")
    eq(123, funcs.luaeval "vim.w.other")
    eq(NIL, funcs.luaeval "vim.w.nonexistant")

    eq({hello="world"}, funcs.luaeval "vim.w.to_delete")
    exec_lua [[
    vim.w.to_delete = nil
    ]]
    eq(NIL, funcs.luaeval "vim.w.to_delete")

    exec_lua [[
    vim.cmd "vnew"
    ]]

    eq(NIL, funcs.luaeval "vim.w.testing")
    eq(NIL, funcs.luaeval "vim.w.other")
    eq(NIL, funcs.luaeval "vim.w.nonexistant")
  end)

  it('vim.t', function()
    exec_lua [[
    vim.api.nvim_tabpage_set_var(0, "testing", "hi")
    vim.api.nvim_tabpage_set_var(0, "other", 123)
    vim.api.nvim_tabpage_set_var(0, "to_delete", {hello="world"})
    ]]

    eq('hi', funcs.luaeval "vim.t.testing")
    eq(123, funcs.luaeval "vim.t.other")
    eq(NIL, funcs.luaeval "vim.t.nonexistant")

    eq({hello="world"}, funcs.luaeval "vim.t.to_delete")
    exec_lua [[
    vim.t.to_delete = nil
    ]]
    eq(NIL, funcs.luaeval "vim.t.to_delete")

    exec_lua [[
    vim.cmd "tabnew"
    ]]

    eq(NIL, funcs.luaeval "vim.t.testing")
    eq(NIL, funcs.luaeval "vim.t.other")
    eq(NIL, funcs.luaeval "vim.t.nonexistant")
  end)

  it('vim.env', function()
    exec_lua [[
    vim.fn.setenv("A", 123)
    ]]
    eq('123', funcs.luaeval "vim.env.A")
    eq(true, funcs.luaeval "vim.env.B == nil")
  end)

  it('vim.v', function()
    eq(funcs.luaeval "vim.api.nvim_get_vvar('progpath')", funcs.luaeval "vim.v.progpath")
    eq(false, funcs.luaeval "vim.v['false']")
    eq(NIL, funcs.luaeval "vim.v.null")
  end)

  it('vim.bo', function()
    eq('', funcs.luaeval "vim.bo.filetype")
    exec_lua [[
    vim.api.nvim_buf_set_option(0, "filetype", "markdown")
    BUF = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(BUF, "modifiable", false)
    ]]
    eq(false, funcs.luaeval "vim.bo.modified")
    eq('markdown', funcs.luaeval "vim.bo.filetype")
    eq(false, funcs.luaeval "vim.bo[BUF].modifiable")
    exec_lua [[
    vim.bo.filetype = ''
    vim.bo[BUF].modifiable = true
    ]]
    eq('', funcs.luaeval "vim.bo.filetype")
    eq(true, funcs.luaeval "vim.bo[BUF].modifiable")
    matches("^Error executing lua: .*: Invalid option name: 'nosuchopt'$",
       pcall_err(exec_lua, 'return vim.bo.nosuchopt'))
    matches("^Error executing lua: .*: Expected lua string$",
       pcall_err(exec_lua, 'return vim.bo[0][0].autoread'))
  end)

  it('vim.wo', function()
    exec_lua [[
    vim.api.nvim_win_set_option(0, "cole", 2)
    vim.cmd "split"
    vim.api.nvim_win_set_option(0, "cole", 2)
    ]]
    eq(2, funcs.luaeval "vim.wo.cole")
    exec_lua [[
    vim.wo.conceallevel = 0
    ]]
    eq(0, funcs.luaeval "vim.wo.cole")
    eq(0, funcs.luaeval "vim.wo[0].cole")
    eq(0, funcs.luaeval "vim.wo[1001].cole")
    matches("^Error executing lua: .*: Invalid option name: 'notanopt'$",
       pcall_err(exec_lua, 'return vim.wo.notanopt'))
    matches("^Error executing lua: .*: Expected lua string$",
       pcall_err(exec_lua, 'return vim.wo[0][0].list'))
    eq(2, funcs.luaeval "vim.wo[1000].cole")
    exec_lua [[
    vim.wo[1000].cole = 0
    ]]
    eq(0, funcs.luaeval "vim.wo[1000].cole")
  end)

  describe('vim.opt', function()
    -- TODO: We still need to write some tests for optlocal, opt and then getting the options
    --  Probably could also do some stuff with getting things from viml side as well to confirm behavior is the same.

    it('should allow setting number values', function()
      local scrolloff = exec_lua [[
        vim.opt.scrolloff = 10
        return vim.o.scrolloff
      ]]
      eq(scrolloff, 10)
    end)

    pending('should handle STUPID window things', function()
      local result = exec_lua [[
        local result = {}

        table.insert(result, vim.api.nvim_get_option('scrolloff'))
        table.insert(result, vim.api.nvim_win_get_option(0, 'scrolloff'))

        return result
      ]]

      eq({}, result)
    end)

    it('should allow setting tables', function()
      local wildignore = exec_lua [[
        vim.opt.wildignore = { 'hello', 'world' }
        return vim.o.wildignore
      ]]
      eq(wildignore, "hello,world")
    end)

    it('should allow setting tables with shortnames', function()
      local wildignore = exec_lua [[
        vim.opt.wig = { 'hello', 'world' }
        return vim.o.wildignore
      ]]
      eq(wildignore, "hello,world")
    end)

    it('should error when you attempt to set string values to numeric options', function()
      local result = exec_lua [[
        return {
          pcall(function() vim.opt.textwidth = 'hello world' end)
        }
      ]]

      eq(false, result[1])
    end)

    it('should error when you attempt to setlocal a global value', function()
      local result = exec_lua [[
        return pcall(function() vim.opt_local.clipboard = "hello" end)
      ]]

      eq(false, result)
    end)

    it('should allow you to set boolean values', function()
      eq({true, false, true}, exec_lua [[
        local results = {}

        vim.opt.autoindent = true
        table.insert(results, vim.bo.autoindent)

        vim.opt.autoindent = false
        table.insert(results, vim.bo.autoindent)

        vim.opt.autoindent = not vim.opt.autoindent:get()
        table.insert(results, vim.bo.autoindent)

        return results
      ]])
    end)

    it('should change current buffer values and defaults for global local values', function()
      local result = exec_lua [[
        local result = {}

        vim.opt.makeprg = "global-local"
        table.insert(result, vim.api.nvim_get_option('makeprg'))
        table.insert(result, (pcall(vim.api.nvim_buf_get_option, 0, 'makeprg')))

        vim.opt_local.mp = "only-local"
        table.insert(result, vim.api.nvim_get_option('makeprg'))
        table.insert(result, vim.api.nvim_buf_get_option(0, 'makeprg'))

        vim.opt_global.makeprg = "only-global"
        table.insert(result, vim.api.nvim_get_option('makeprg'))
        table.insert(result, vim.api.nvim_buf_get_option(0, 'makeprg'))

        vim.opt.makeprg = "global-local"
        table.insert(result, vim.api.nvim_get_option('makeprg'))
        table.insert(result, vim.api.nvim_buf_get_option(0, 'makeprg'))
        return result
      ]]

      -- Set -> global & local
      eq("global-local", result[1])
      eq(false, result[2])

      -- Setlocal -> only local
      eq("global-local", result[3])
      eq("only-local", result[4])

      -- Setglobal -> only global
      eq("only-global", result[5])
      eq("only-local", result[6])

      -- set -> doesn't override previously set value
      eq("global-local", result[7])
      eq("only-local", result[8])
    end)

    it('should allow you to retrieve window opts even if they have not been set', function()
      local result = exec_lua [[
        local result = {}
        table.insert(result, vim.opt.number:get())
        table.insert(result, vim.opt_local.number:get())

        vim.opt_local.number = true
        table.insert(result, vim.opt.number:get())
        table.insert(result, vim.opt_local.number:get())

        return result
      ]]
      eq({false, false, true, true}, result)
    end)

    it('should allow all sorts of string manipulation', function()
      eq({'hello', 'hello world', 'start hello world'}, exec_lua [[
        local results = {}

        vim.opt.makeprg = "hello"
        table.insert(results, vim.o.makeprg)

        vim.opt.makeprg = vim.opt.makeprg + " world"
        table.insert(results, vim.o.makeprg)

        vim.opt.makeprg = vim.opt.makeprg ^ "start "
        table.insert(results, vim.o.makeprg)

        return results
      ]])
    end)

    describe('option:get()', function()
      it('should work for boolean values', function()
        eq(false, exec_lua [[
          vim.opt.number = false
          return vim.opt.number:get()
        ]])
      end)

      it('should work for number values', function()
        local tabstop = exec_lua[[
          vim.opt.tabstop = 10
          return vim.opt.tabstop:get()
        ]]

        eq(10, tabstop)
      end)

      it('should work for string values', function()
        eq("hello world", exec_lua [[
          vim.opt.makeprg = "hello world"
          return vim.opt.makeprg:get()
        ]])
      end)

      it('should work for set type flaglists', function()
        local formatoptions = exec_lua [[
          vim.opt.formatoptions = 'tcro'
          return vim.opt.formatoptions:get()
        ]]

        eq(true, formatoptions.t)
        eq(true, not formatoptions.q)
      end)

      it('should work for set type flaglists', function()
        local formatoptions = exec_lua [[
          vim.opt.formatoptions = { t = true, c = true, r = true, o = true }
          return vim.opt.formatoptions:get()
        ]]

        eq(true, formatoptions.t)
        eq(true, not formatoptions.q)
      end)

      it('should work for array list type options', function()
        local wildignore = exec_lua [[
          vim.opt.wildignore = "*.c,*.o,__pycache__"
          return vim.opt.wildignore:get()
        ]]

        eq(3, #wildignore)
        eq("*.c", wildignore[1])
      end)

      it('should work for options that are both commalist and flaglist', function()
        local result = exec_lua [[
          vim.opt.whichwrap = "b,s"
          return vim.opt.whichwrap:get()
        ]]

        eq({b = true, s = true}, result)

        result = exec_lua [[
          vim.opt.whichwrap = { b = true, s = false, h = true }
          return vim.opt.whichwrap:get()
        ]]

        eq({b = true, h = true}, result)
      end)

      it('should work for key-value pair options', function()
        local listchars = exec_lua [[
          vim.opt.listchars = "tab:> ,space:_"
          return vim.opt.listchars:get()
        ]]

        eq({
          tab = "> ",
          space = "_",
        }, listchars)
      end)

      it('should allow you to add numeric options', function()
        eq(16, exec_lua [[
          vim.opt.tabstop = 12
          vim.opt.tabstop = vim.opt.tabstop + 4
          return vim.bo.tabstop
        ]])
      end)

      it('should allow you to subtract numeric options', function()
        eq(2, exec_lua [[
          vim.opt.tabstop = 4
          vim.opt.tabstop = vim.opt.tabstop - 2
          return vim.bo.tabstop
        ]])
      end)
    end)

    describe('key:value style options', function()
      it('should handle dictionary style', function()
        local listchars = exec_lua [[
          vim.opt.listchars = {
            eol = "~",
            space = ".",
          }

          return vim.o.listchars
        ]]
        eq("eol:~,space:.", listchars)
      end)

      it('should allow adding dictionary style', function()
        local listchars = exec_lua [[
          vim.opt.listchars = {
            eol = "~",
            space = ".",
          }

          vim.opt.listchars = vim.opt.listchars + { space = "-" }

          return vim.o.listchars
        ]]

        eq("eol:~,space:-", listchars)
      end)

      it('should allow adding dictionary style', function()
        local listchars = exec_lua [[
          vim.opt.listchars = {
            eol = "~",
            space = ".",
          }
          vim.opt.listchars = vim.opt.listchars + { space = "-" } + { space = "_" }

          return vim.o.listchars
        ]]

        eq("eol:~,space:_", listchars)
      end)

      it('should allow completely new keys', function()
        local listchars = exec_lua [[
          vim.opt.listchars = {
            eol = "~",
            space = ".",
          }
          vim.opt.listchars = vim.opt.listchars + { tab = ">>>" }

          return vim.o.listchars
        ]]

        eq("eol:~,space:.,tab:>>>", listchars)
      end)

      it('should allow subtracting dictionary style', function()
        local listchars = exec_lua [[
          vim.opt.listchars = {
            eol = "~",
            space = ".",
          }
          vim.opt.listchars = vim.opt.listchars - "space"

          return vim.o.listchars
        ]]

        eq("eol:~", listchars)
      end)

      it('should allow subtracting dictionary style', function()
        local listchars = exec_lua [[
          vim.opt.listchars = {
            eol = "~",
            space = ".",
          }
          vim.opt.listchars = vim.opt.listchars - "space" - "eol"

          return vim.o.listchars
        ]]

        eq("", listchars)
      end)

      it('should allow subtracting dictionary style multiple times', function()
        local listchars = exec_lua [[
          vim.opt.listchars = {
            eol = "~",
            space = ".",
          }
          vim.opt.listchars = vim.opt.listchars - "space" - "space"

          return vim.o.listchars
        ]]

        eq("eol:~", listchars)
      end)

      it('should allow adding a key:value string to a listchars', function()
        local listchars = exec_lua [[
          vim.opt.listchars = {
            eol = "~",
            space = ".",
          }
          vim.opt.listchars = vim.opt.listchars + "tab:>~"

          return vim.o.listchars
        ]]

        eq("eol:~,space:.,tab:>~", listchars)
      end)

      it('should allow prepending a key:value string to a listchars', function()
        local listchars = exec_lua [[
          vim.opt.listchars = {
            eol = "~",
            space = ".",
          }
          vim.opt.listchars = vim.opt.listchars ^ "tab:>~"

          return vim.o.listchars
        ]]

        eq("eol:~,space:.,tab:>~", listchars)
      end)
    end)

    it('should automatically set when calling remove', function()
      eq("foo,baz", exec_lua [[
        vim.opt.wildignore = "foo,bar,baz"
        vim.opt.wildignore:remove("bar")

        return vim.o.wildignore
      ]])
    end)

    it('should automatically set when calling remove with a table', function()
      eq("foo", exec_lua [[
        vim.opt.wildignore = "foo,bar,baz"
        vim.opt.wildignore:remove { "bar", "baz" }

        return vim.o.wildignore
      ]])
    end)

    it('should automatically set when calling append', function()
      eq("foo,bar,baz,bing", exec_lua [[
        vim.opt.wildignore = "foo,bar,baz"
        vim.opt.wildignore:append("bing")

        return vim.o.wildignore
      ]])
    end)

    it('should automatically set when calling append with a table', function()
      eq("foo,bar,baz,bing,zap", exec_lua [[
        vim.opt.wildignore = "foo,bar,baz"
        vim.opt.wildignore:append { "bing", "zap" }

        return vim.o.wildignore
      ]])
    end)

    it('should allow adding tables', function()
      local wildignore = exec_lua [[
        vim.opt.wildignore = 'foo'
        return vim.o.wildignore
      ]]
      eq(wildignore, 'foo')

      wildignore = exec_lua [[
        vim.opt.wildignore = vim.opt.wildignore + { 'bar', 'baz' }
        return vim.o.wildignore
      ]]
      eq(wildignore, 'foo,bar,baz')
    end)

    it('should handle adding duplicates', function()
      local wildignore = exec_lua [[
        vim.opt.wildignore = 'foo'
        return vim.o.wildignore
      ]]
      eq(wildignore, 'foo')

      wildignore = exec_lua [[
        vim.opt.wildignore = vim.opt.wildignore + { 'bar', 'baz' }
        return vim.o.wildignore
      ]]
      eq(wildignore, 'foo,bar,baz')

      wildignore = exec_lua [[
        vim.opt.wildignore = vim.opt.wildignore + { 'bar', 'baz' }
        return vim.o.wildignore
      ]]
      eq(wildignore, 'foo,bar,baz')
    end)

    it('should allow adding multiple times', function()
      local wildignore = exec_lua [[
        vim.opt.wildignore = 'foo'
        vim.opt.wildignore = vim.opt.wildignore + 'bar' + 'baz'
        return vim.o.wildignore
      ]]
      eq(wildignore, 'foo,bar,baz')
    end)

    it('should remove values when you use minus', function()
      local wildignore = exec_lua [[
        vim.opt.wildignore = 'foo'
        return vim.o.wildignore
      ]]
      eq(wildignore, 'foo')

      wildignore = exec_lua [[
        vim.opt.wildignore = vim.opt.wildignore + { 'bar', 'baz' }
        return vim.o.wildignore
      ]]
      eq(wildignore, 'foo,bar,baz')

      wildignore = exec_lua [[
        vim.opt.wildignore = vim.opt.wildignore - 'bar'
        return vim.o.wildignore
      ]]
      eq(wildignore, 'foo,baz')
    end)

    it('should prepend values when using ^', function()
      local wildignore = exec_lua [[
        vim.opt.wildignore = 'foo'
        vim.opt.wildignore = vim.opt.wildignore ^ 'first'
        return vim.o.wildignore
      ]]
      eq('first,foo', wildignore)

      wildignore = exec_lua [[
        vim.opt.wildignore = vim.opt.wildignore ^ 'super_first'
        return vim.o.wildignore
      ]]
      eq(wildignore, 'super_first,first,foo')
    end)

    it('should not remove duplicates from wildmode: #14708', function()
      local wildmode = exec_lua [[
        vim.opt.wildmode = {"full", "list", "full"}
        return vim.o.wildmode
      ]]

      eq(wildmode, 'full,list,full')
    end)

    describe('option types', function()
      it('should allow to set option with numeric value', function()
        eq(4, exec_lua [[
          vim.opt.tabstop = 4
          return vim.bo.tabstop
        ]])

        matches("Invalid option type 'string' for 'tabstop'", pcall_err(exec_lua, [[
          vim.opt.tabstop = '4'
        ]]))
        matches("Invalid option type 'boolean' for 'tabstop'", pcall_err(exec_lua, [[
          vim.opt.tabstop = true
        ]]))
        matches("Invalid option type 'table' for 'tabstop'", pcall_err(exec_lua, [[
          vim.opt.tabstop = {4, 2}
        ]]))
        matches("Invalid option type 'function' for 'tabstop'", pcall_err(exec_lua, [[
          vim.opt.tabstop = function()
            return 4
          end
        ]]))
      end)

      it('should allow to set option with boolean value', function()
        eq(true, exec_lua [[
          vim.opt.undofile = true
          return vim.bo.undofile
        ]])

        matches("Invalid option type 'number' for 'undofile'", pcall_err(exec_lua, [[
          vim.opt.undofile = 0
        ]]))
        matches("Invalid option type 'table' for 'undofile'", pcall_err(exec_lua, [[
          vim.opt.undofile = {true}
        ]]))
        matches("Invalid option type 'string' for 'undofile'", pcall_err(exec_lua, [[
          vim.opt.undofile = 'true'
        ]]))
        matches("Invalid option type 'function' for 'undofile'", pcall_err(exec_lua, [[
          vim.opt.undofile = function()
            return true
          end
        ]]))
      end)

      it('should allow to set option with array or string value', function()
        eq('indent,eol,start', exec_lua [[
          vim.opt.backspace = {'indent','eol','start'}
          return vim.go.backspace
        ]])
        eq('indent,eol,start', exec_lua [[
          vim.opt.backspace = 'indent,eol,start'
          return vim.go.backspace
        ]])

        matches("Invalid option type 'boolean' for 'backspace'", pcall_err(exec_lua, [[
          vim.opt.backspace = true
        ]]))
        matches("Invalid option type 'number' for 'backspace'", pcall_err(exec_lua, [[
          vim.opt.backspace = 2
        ]]))
        matches("Invalid option type 'function' for 'backspace'", pcall_err(exec_lua, [[
          vim.opt.backspace = function()
            return 'indent,eol,start'
          end
        ]]))
      end)

      it('should allow set option with map or string value', function()
        eq("eol:~,space:.", exec_lua [[
          vim.opt.listchars = {
            eol = "~",
            space = ".",
          }
          return vim.o.listchars
        ]])
        eq("eol:~,space:.,tab:>~", exec_lua [[
          vim.opt.listchars = "eol:~,space:.,tab:>~"
          return vim.o.listchars
        ]])

        matches("Invalid option type 'boolean' for 'listchars'", pcall_err(exec_lua, [[
          vim.opt.listchars = true
        ]]))
        matches("Invalid option type 'number' for 'listchars'", pcall_err(exec_lua, [[
          vim.opt.listchars = 2
        ]]))
        matches("Invalid option type 'function' for 'listchars'", pcall_err(exec_lua, [[
          vim.opt.listchars = function()
            return "eol:~,space:.,tab:>~"
          end
        ]]))
      end)

      it('should allow set option with set or string value', function()
        local ww = exec_lua [[
          vim.opt.whichwrap = {
            b = true,
            s = 1,
          }
          return vim.go.whichwrap
        ]]

        eq(ww, "b,s")
        eq("b,s,<,>,[,]", exec_lua [[
          vim.opt.whichwrap = "b,s,<,>,[,]"
          return vim.go.whichwrap
        ]])

        matches("Invalid option type 'boolean' for 'whichwrap'", pcall_err(exec_lua, [[
          vim.opt.whichwrap = true
        ]]))
        matches("Invalid option type 'number' for 'whichwrap'", pcall_err(exec_lua, [[
          vim.opt.whichwrap = 2
        ]]))
        matches("Invalid option type 'function' for 'whichwrap'", pcall_err(exec_lua, [[
          vim.opt.whichwrap = function()
            return "b,s,<,>,[,]"
          end
        ]]))
      end)
    end)

    -- isfname=a,b,c,,,d,e,f
    it('can handle isfname ,,,', function()
      local result = exec_lua [[
        vim.opt.isfname = "a,b,,,c"
        return { vim.opt.isfname:get(), vim.api.nvim_get_option('isfname') }
      ]]

      eq({{",", "a", "b", "c"}, "a,b,,,c"}, result)
    end)

    -- isfname=a,b,c,^,,def
    it('can handle isfname ,^,,', function()
      local result = exec_lua [[
        vim.opt.isfname = "a,b,^,,c"
        return { vim.opt.isfname:get(), vim.api.nvim_get_option('isfname') }
      ]]

      eq({{"^,", "a", "b", "c"}, "a,b,^,,c"}, result)
    end)



    describe('https://github.com/neovim/neovim/issues/14828', function()
      it('gives empty list when item is empty:array', function()
        eq({}, exec_lua [[
          vim.cmd("set wildignore=")
          return vim.opt.wildignore:get()
        ]])

        eq({}, exec_lua [[
          vim.opt.wildignore = {}
          return vim.opt.wildignore:get()
        ]])
      end)

      it('gives empty list when item is empty:set', function()
        eq({}, exec_lua [[
          vim.cmd("set formatoptions=")
          return vim.opt.formatoptions:get()
        ]])

        eq({}, exec_lua [[
          vim.opt.formatoptions = {}
          return vim.opt.formatoptions:get()
        ]])
      end)

      it('does not append to empty item', function()
        eq({"*.foo", "*.bar"},  exec_lua [[
          vim.opt.wildignore = {}
          vim.opt.wildignore:append { "*.foo", "*.bar" }

          return vim.opt.wildignore:get()
        ]])
      end)

      it('does not prepend to empty item', function()
        eq({"*.foo", "*.bar"},  exec_lua [[
          vim.opt.wildignore = {}
          vim.opt.wildignore:prepend { "*.foo", "*.bar" }

          return vim.opt.wildignore:get()
        ]])
      end)

      it('append to empty set', function()
        eq({ t = true },  exec_lua [[
          vim.opt.formatoptions = {}
          vim.opt.formatoptions:append("t")

          return vim.opt.formatoptions:get()
        ]])
      end)

      it('prepend to empty set', function()
        eq({ t = true },  exec_lua [[
          vim.opt.formatoptions = {}
          vim.opt.formatoptions:prepend("t")

          return vim.opt.formatoptions:get()
        ]])
      end)
    end)
  end) -- vim.opt

  it('vim.cmd', function()
    exec_lua [[
    vim.cmd "autocmd BufNew * ++once lua BUF = vim.fn.expand('<abuf>')"
    vim.cmd "new"
    ]]
    eq('2', funcs.luaeval "BUF")
    eq(2, funcs.luaeval "#vim.api.nvim_list_bufs()")
  end)

  it('vim.regex', function()
    exec_lua [[
      re1 = vim.regex"ab\\+c"
      vim.cmd "set nomagic ignorecase"
      re2 = vim.regex"xYz"
    ]]
    eq({}, exec_lua[[return {re1:match_str("x ac")}]])
    eq({3,7}, exec_lua[[return {re1:match_str("ac abbc")}]])

    meths.buf_set_lines(0, 0, -1, true, {"yy", "abc abbc"})
    eq({}, exec_lua[[return {re1:match_line(0, 0)}]])
    eq({0,3}, exec_lua[[return {re1:match_line(0, 1)}]])
    eq({3,7}, exec_lua[[return {re1:match_line(0, 1, 1)}]])
    eq({3,7}, exec_lua[[return {re1:match_line(0, 1, 1, 8)}]])
    eq({}, exec_lua[[return {re1:match_line(0, 1, 1, 7)}]])
    eq({0,3}, exec_lua[[return {re1:match_line(0, 1, 0, 7)}]])
  end)

  it('vim.defer_fn', function()
    eq(false, exec_lua [[
      vim.g.test = false
      vim.defer_fn(function() vim.g.test = true end, 150)
      return vim.g.test
    ]])
    exec_lua [[vim.wait(1000, function() return vim.g.test end)]]
    eq(true, exec_lua[[return vim.g.test]])
  end)

  it('vim.region', function()
    insert(helpers.dedent( [[
    text tααt tααt text
    text tαxt txtα tex
    text tαxt tαxt
    ]]))
    eq({5,15}, exec_lua[[ return vim.region(0,{1,5},{1,14},'v',true)[1] ]])
  end)

  describe('vim.on_key', function()
    it('tracks keystrokes', function()
      insert([[hello world ]])

      exec_lua [[
        keys = {}

        vim.on_key(function(buf)
          if buf:byte() == 27 then
            buf = "<ESC>"
          end

          table.insert(keys, buf)
        end)
      ]]

      insert([[next 🤦 lines å ]])

      -- It has escape in the keys pressed
      eq('inext 🤦 lines å <ESC>', exec_lua [[return table.concat(keys, '')]])
    end)

    it('allows removing on_key listeners', function()
      insert([[hello world]])

      exec_lua [[
        keys = {}

        return vim.on_key(function(buf)
          if buf:byte() == 27 then
            buf = "<ESC>"
          end

          table.insert(keys, buf)
        end, vim.api.nvim_create_namespace("logger"))
      ]]

      insert([[next lines]])

      eq(1, exec_lua('return vim.on_key()'))
      exec_lua("vim.on_key(nil, vim.api.nvim_create_namespace('logger'))")
      eq(0, exec_lua('return vim.on_key()'))

      insert([[more lines]])

      -- It has escape in the keys pressed
      eq('inext lines<ESC>', exec_lua [[return table.concat(keys, '')]])
    end)

    it('skips any function that caused an error', function()
      insert([[hello world]])

      exec_lua [[
        keys = {}

        return vim.on_key(function(buf)
          if buf:byte() == 27 then
            buf = "<ESC>"
          end

          table.insert(keys, buf)

          if buf == 'l' then
            error("Dumb Error")
          end
        end)
      ]]

      insert([[next lines]])
      insert([[more lines]])

      -- Only the first letter gets added. After that we remove the callback
      eq('inext l', exec_lua [[ return table.concat(keys, '') ]])
    end)

    it('processes mapped keys, not unmapped keys', function()
      exec_lua [[
        keys = {}

        vim.cmd("inoremap hello world")

        vim.on_key(function(buf)
          if buf:byte() == 27 then
            buf = "<ESC>"
          end

          table.insert(keys, buf)
        end)
      ]]
      insert("hello")

      eq('iworld<ESC>', exec_lua[[return table.concat(keys, '')]])
    end)
  end)

  describe('vim.wait', function()
    before_each(function()
      exec_lua[[
        -- high precision timer
        get_time = function()
          return vim.fn.reltimefloat(vim.fn.reltime())
        end
      ]]
    end)

    it('should run from lua', function()
      exec_lua[[vim.wait(100, function() return true end)]]
    end)

    it('should wait the expected time if false', function()
      eq({time = true, wait_result = {false, -1}}, exec_lua[[
        start_time = get_time()
        wait_succeed, wait_fail_val = vim.wait(200, function() return false end)

        return {
          -- 150ms waiting or more results in true. Flaky tests are bad.
          time = (start_time + 0.15) < get_time(),
          wait_result = {wait_succeed, wait_fail_val}
        }
      ]])
    end)


    it('should not block other events', function()
      eq({time = true, wait_result = true}, exec_lua[[
        start_time = get_time()

        vim.g.timer_result = false
        timer = vim.loop.new_timer()
        timer:start(100, 0, vim.schedule_wrap(function()
          vim.g.timer_result = true
        end))

        -- Would wait ten seconds if results blocked.
        wait_result = vim.wait(10000, function() return vim.g.timer_result end)

        return {
          time = (start_time + 5) > get_time(),
          wait_result = wait_result,
        }
      ]])
    end)

    it('should not process non-fast events when commanded', function()
      eq({wait_result = false}, exec_lua[[
        start_time = get_time()

        vim.g.timer_result = false
        timer = vim.loop.new_timer()
        timer:start(100, 0, vim.schedule_wrap(function()
          vim.g.timer_result = true
        end))

        wait_result = vim.wait(300, function() return vim.g.timer_result end, nil, true)

        return {
          wait_result = wait_result,
        }
      ]])
    end)
    it('should work with vim.defer_fn', function()
      eq({time = true, wait_result = true}, exec_lua[[
        start_time = get_time()

        vim.defer_fn(function() vim.g.timer_result = true end, 100)
        wait_result = vim.wait(10000, function() return vim.g.timer_result end)

        return {
          time = (start_time + 5) > get_time(),
          wait_result = wait_result,
        }
      ]])
    end)

    it('should not crash when callback errors', function()
      eq({false, '[string "<nvim>"]:1: As Expected'}, exec_lua [[
        return {pcall(function() vim.wait(1000, function() error("As Expected") end) end)}
      ]])
    end)

    it('if callback is passed, it must be a function', function()
      eq({false, 'vim.wait: if passed, condition must be a function'}, exec_lua [[
        return {pcall(function() vim.wait(1000, 13) end)}
      ]])
    end)

    it('should allow waiting with no callback, explicit', function()
      eq(true, exec_lua [[
        local start_time = vim.loop.hrtime()
        vim.wait(50, nil)
        return vim.loop.hrtime() - start_time > 25000
      ]])
    end)

    it('should allow waiting with no callback, implicit', function()
      eq(true, exec_lua [[
        local start_time = vim.loop.hrtime()
        vim.wait(50)
        return vim.loop.hrtime() - start_time > 25000
      ]])
    end)

    it('should call callbacks exactly once if they return true immediately', function()
      eq(true, exec_lua [[
        vim.g.wait_count = 0
        vim.wait(1000, function()
          vim.g.wait_count = vim.g.wait_count + 1
          return true
        end, 20)
        return vim.g.wait_count == 1
      ]])
    end)

    it('should call callbacks few times with large `interval`', function()
      eq(true, exec_lua [[
        vim.g.wait_count = 0
        vim.wait(50, function() vim.g.wait_count = vim.g.wait_count + 1 end, 200)
        return vim.g.wait_count < 5
      ]])
    end)

    it('should play nice with `not` when fails', function()
      eq(true, exec_lua [[
        if not vim.wait(50, function() end) then
          return true
        end

        return false
      ]])
    end)

    it('should play nice with `if` when success', function()
      eq(true, exec_lua [[
        if vim.wait(50, function() return true end) then
          return true
        end

        return false
      ]])
    end)

    it('should return immediately with false if timeout is 0', function()
      eq({false, -1}, exec_lua [[
        return {
          vim.wait(0, function() return false end)
        }
      ]])
    end)

    it('should work with tables with __call', function()
      eq(true, exec_lua [[
        local t = setmetatable({}, {__call = function(...) return true end})
        return vim.wait(100, t, 10)
      ]])
    end)

    it('should work with tables with __call that change', function()
      eq(true, exec_lua [[
        local t = {count = 0}
        setmetatable(t, {
          __call = function()
            t.count = t.count + 1
            return t.count > 3
          end
        })

        return vim.wait(1000, t, 10)
      ]])
    end)

    it('should not work with negative intervals', function()
      local pcall_result = exec_lua [[
        return pcall(function() vim.wait(1000, function() return false end, -1) end)
      ]]

      eq(false, pcall_result)
    end)

    it('should not work with weird intervals', function()
      local pcall_result = exec_lua [[
        return pcall(function() vim.wait(1000, function() return false end, 'a string value') end)
      ]]

      eq(false, pcall_result)
    end)
  end)

  describe('vim.schedule_wrap', function()
    it('preserves argument lists', function()
      exec_lua [[
        local fun = vim.schedule_wrap(function(kling, klang, klonk)
          vim.rpcnotify(1, 'mayday_mayday', {a=kling, b=klang, c=klonk})
        end)
        fun("BOB", nil, "MIKE")
      ]]
      eq({'notification', 'mayday_mayday', {{a='BOB', c='MIKE'}}}, next_msg())

      -- let's gooooo
      exec_lua [[
        vim.schedule_wrap(function(...) vim.rpcnotify(1, 'boogalo', select('#', ...)) end)(nil,nil,nil,nil)
      ]]
      eq({'notification', 'boogalo', {4}}, next_msg())
    end)
  end)

  describe('vim.api.nvim_buf_call', function()
    it('can access buf options', function()
      local buf1 = meths.get_current_buf()
      local buf2 = exec_lua [[
        buf2 = vim.api.nvim_create_buf(false, true)
        return buf2
      ]]

      eq(false, meths.buf_get_option(buf1, 'autoindent'))
      eq(false, meths.buf_get_option(buf2, 'autoindent'))

      local val = exec_lua [[
        return vim.api.nvim_buf_call(buf2, function()
          vim.cmd "set autoindent"
          return vim.api.nvim_get_current_buf()
        end)
      ]]

      eq(false, meths.buf_get_option(buf1, 'autoindent'))
      eq(true, meths.buf_get_option(buf2, 'autoindent'))
      eq(buf1, meths.get_current_buf())
      eq(buf2, val)
    end)
  end)

  describe('vim.api.nvim_win_call', function()
    it('can access window options', function()
      command('vsplit')
      local win1 = meths.get_current_win()
      command('wincmd w')
      local win2 = exec_lua [[
        win2 = vim.api.nvim_get_current_win()
        return win2
      ]]
      command('wincmd p')

      eq('', meths.win_get_option(win1, 'winhighlight'))
      eq('', meths.win_get_option(win2, 'winhighlight'))

      local val = exec_lua [[
        return vim.api.nvim_win_call(win2, function()
          vim.cmd "setlocal winhighlight=Normal:Normal"
          return vim.api.nvim_get_current_win()
        end)
      ]]

      eq('', meths.win_get_option(win1, 'winhighlight'))
      eq('Normal:Normal', meths.win_get_option(win2, 'winhighlight'))
      eq(win1, meths.get_current_win())
      eq(win2, val)
    end)
  end)
end)

describe('lua: require("mod") from packages', function()
  before_each(function()
    command('set rtp+=test/functional/fixtures')
  end)

  it('propagates syntax error', function()
    local syntax_error_msg = exec_lua [[
      local _, err = pcall(require, "syntax_error")
      return err
    ]]

    matches("unexpected symbol", syntax_error_msg)
  end)
end)
