-- Test suite for testing interactions with API bindings
local helpers = require('test.functional.helpers')(after_each)

local funcs = helpers.funcs
local meths = helpers.meths
local clear = helpers.clear
local eq = helpers.eq
local eval = helpers.eval
local feed = helpers.feed
local meth_pcall = helpers.meth_pcall

before_each(clear)

describe('lua function', function()
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

  it("vim.schedule", function()
    meths.execute_lua([[
      test_table = {}
      vim.schedule(function()
        table.insert(test_table, "xx")
      end)
      table.insert(test_table, "yy")
    ]], {})
    eq({"yy","xx"}, meths.execute_lua("return test_table", {}))

    -- type checked args
    eq({false, 'Error executing lua: vim.schedule: expected function'},
       meth_pcall(meths.execute_lua, "vim.schedule('stringly')", {}))

    eq({false, 'Error executing lua: vim.schedule: expected function'},
       meth_pcall(meths.execute_lua, "vim.schedule()", {}))

    meths.execute_lua([[
      vim.schedule(function()
        error("big failure\nvery async")
      end)
    ]], {})

    feed("<cr>")
    eq('Error executing vim.schedule lua callback: [string "<nvim>"]:2: big failure\nvery async', eval("v:errmsg"))
  end)

  it("vim.split", function()
    local split = function(str, sep)
      return meths.execute_lua('return vim.split(...)', {str, sep})
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
      local status, err = pcall(split, t[1], t[2])
      eq(false, status)
      assert(string.match(err, "Infinite loop detected"))
    end
  end)

  it('vim.trim', function()
    local trim = function(s)
      return meths.execute_lua('return vim.trim(...)', { s })
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

    local status, err = pcall(trim, 2)
    eq(false, status)
    assert(string.match(err, "Only strings can be trimmed"))
  end)

  it('vim.inspect', function()
    -- just make sure it basically works, it has its own test suite
    local inspect = function(t, opts)
      return meths.execute_lua('return vim.inspect(...)', { t, opts })
    end

    eq('2', inspect(2))
    eq('{+a = {+b = 1+}+}',
       inspect({ a = { b = 1 } }, { newline = '+', indent = '' }))

    -- special value vim.inspect.KEY works
    eq('{  KEY_a = "x",  KEY_b = "y"}', meths.execute_lua([[
      return vim.inspect({a="x", b="y"}, {newline = '', process = function(item, path)
        if path[#path] == vim.inspect.KEY then
          return 'KEY_'..item
        end
        return item
      end})
    ]], {}))
  end)

  it("vim.deepcopy", function()
    local is_dc = meths.execute_lua([[
      local a = { x = { 1, 2 }, y = 5}
      local b = vim.deepcopy(a)

      local count = 0
      for _ in pairs(b) do count = count + 1 end

      return b.x[1] == 1 and b.x[2] == 2 and b.y == 5 and count == 2
             and tostring(a) ~= tostring(b)
    ]], {})

    assert(is_dc)
  end)
end)
