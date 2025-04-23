-- Test suite for testing interactions with API bindings
local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local nvim_prog = n.nvim_prog
local fn = n.fn
local api = n.api
local command = n.command
local dedent = t.dedent
local insert = n.insert
local clear = n.clear
local eq = t.eq
local ok = t.ok
local pesc = vim.pesc
local eval = n.eval
local feed = n.feed
local pcall_err = t.pcall_err
local exec_lua = n.exec_lua
local matches = t.matches
local exec = n.exec
local NIL = vim.NIL
local retry = t.retry
local next_msg = n.next_msg
local remove_trace = t.remove_trace
local mkdir_p = n.mkdir_p
local rmdir = n.rmdir
local write_file = t.write_file
local poke_eventloop = n.poke_eventloop
local assert_alive = n.assert_alive
local expect = n.expect

describe('lua stdlib', function()
  before_each(clear)
  -- İ: `tolower("İ")` is `i` which has length 1 while `İ` itself has
  --    length 2 (in bytes).
  -- Ⱥ: `tolower("Ⱥ")` is `ⱥ` which has length 2 while `Ⱥ` itself has
  --    length 3 (in bytes).
  --
  -- Note: 'i' !=? 'İ' and 'ⱥ' !=? 'Ⱥ' on some systems.
  -- Note: Built-in Nvim comparison (on systems lacking `strcasecmp`) works
  --       only on ASCII characters.
  it('vim.stricmp', function()
    eq(0, fn.luaeval('vim.stricmp("a", "A")'))
    eq(0, fn.luaeval('vim.stricmp("A", "a")'))
    eq(0, fn.luaeval('vim.stricmp("a", "a")'))
    eq(0, fn.luaeval('vim.stricmp("A", "A")'))

    eq(0, fn.luaeval('vim.stricmp("", "")'))
    eq(0, fn.luaeval('vim.stricmp("\\0", "\\0")'))
    eq(0, fn.luaeval('vim.stricmp("\\0\\0", "\\0\\0")'))
    eq(0, fn.luaeval('vim.stricmp("\\0\\0\\0", "\\0\\0\\0")'))
    eq(0, fn.luaeval('vim.stricmp("\\0\\0\\0A", "\\0\\0\\0a")'))
    eq(0, fn.luaeval('vim.stricmp("\\0\\0\\0a", "\\0\\0\\0A")'))
    eq(0, fn.luaeval('vim.stricmp("\\0\\0\\0a", "\\0\\0\\0a")'))

    eq(0, fn.luaeval('vim.stricmp("a\\0", "A\\0")'))
    eq(0, fn.luaeval('vim.stricmp("A\\0", "a\\0")'))
    eq(0, fn.luaeval('vim.stricmp("a\\0", "a\\0")'))
    eq(0, fn.luaeval('vim.stricmp("A\\0", "A\\0")'))

    eq(0, fn.luaeval('vim.stricmp("\\0a", "\\0A")'))
    eq(0, fn.luaeval('vim.stricmp("\\0A", "\\0a")'))
    eq(0, fn.luaeval('vim.stricmp("\\0a", "\\0a")'))
    eq(0, fn.luaeval('vim.stricmp("\\0A", "\\0A")'))

    eq(0, fn.luaeval('vim.stricmp("\\0a\\0", "\\0A\\0")'))
    eq(0, fn.luaeval('vim.stricmp("\\0A\\0", "\\0a\\0")'))
    eq(0, fn.luaeval('vim.stricmp("\\0a\\0", "\\0a\\0")'))
    eq(0, fn.luaeval('vim.stricmp("\\0A\\0", "\\0A\\0")'))

    eq(-1, fn.luaeval('vim.stricmp("a", "B")'))
    eq(-1, fn.luaeval('vim.stricmp("A", "b")'))
    eq(-1, fn.luaeval('vim.stricmp("a", "b")'))
    eq(-1, fn.luaeval('vim.stricmp("A", "B")'))

    eq(-1, fn.luaeval('vim.stricmp("", "\\0")'))
    eq(-1, fn.luaeval('vim.stricmp("\\0", "\\0\\0")'))
    eq(-1, fn.luaeval('vim.stricmp("\\0\\0", "\\0\\0\\0")'))
    eq(-1, fn.luaeval('vim.stricmp("\\0\\0\\0A", "\\0\\0\\0b")'))
    eq(-1, fn.luaeval('vim.stricmp("\\0\\0\\0a", "\\0\\0\\0B")'))
    eq(-1, fn.luaeval('vim.stricmp("\\0\\0\\0a", "\\0\\0\\0b")'))

    eq(-1, fn.luaeval('vim.stricmp("a\\0", "B\\0")'))
    eq(-1, fn.luaeval('vim.stricmp("A\\0", "b\\0")'))
    eq(-1, fn.luaeval('vim.stricmp("a\\0", "b\\0")'))
    eq(-1, fn.luaeval('vim.stricmp("A\\0", "B\\0")'))

    eq(-1, fn.luaeval('vim.stricmp("\\0a", "\\0B")'))
    eq(-1, fn.luaeval('vim.stricmp("\\0A", "\\0b")'))
    eq(-1, fn.luaeval('vim.stricmp("\\0a", "\\0b")'))
    eq(-1, fn.luaeval('vim.stricmp("\\0A", "\\0B")'))

    eq(-1, fn.luaeval('vim.stricmp("\\0a\\0", "\\0B\\0")'))
    eq(-1, fn.luaeval('vim.stricmp("\\0A\\0", "\\0b\\0")'))
    eq(-1, fn.luaeval('vim.stricmp("\\0a\\0", "\\0b\\0")'))
    eq(-1, fn.luaeval('vim.stricmp("\\0A\\0", "\\0B\\0")'))

    eq(1, fn.luaeval('vim.stricmp("c", "B")'))
    eq(1, fn.luaeval('vim.stricmp("C", "b")'))
    eq(1, fn.luaeval('vim.stricmp("c", "b")'))
    eq(1, fn.luaeval('vim.stricmp("C", "B")'))

    eq(1, fn.luaeval('vim.stricmp("\\0", "")'))
    eq(1, fn.luaeval('vim.stricmp("\\0\\0", "\\0")'))
    eq(1, fn.luaeval('vim.stricmp("\\0\\0\\0", "\\0\\0")'))
    eq(1, fn.luaeval('vim.stricmp("\\0\\0\\0\\0", "\\0\\0\\0")'))
    eq(1, fn.luaeval('vim.stricmp("\\0\\0\\0C", "\\0\\0\\0b")'))
    eq(1, fn.luaeval('vim.stricmp("\\0\\0\\0c", "\\0\\0\\0B")'))
    eq(1, fn.luaeval('vim.stricmp("\\0\\0\\0c", "\\0\\0\\0b")'))

    eq(1, fn.luaeval('vim.stricmp("c\\0", "B\\0")'))
    eq(1, fn.luaeval('vim.stricmp("C\\0", "b\\0")'))
    eq(1, fn.luaeval('vim.stricmp("c\\0", "b\\0")'))
    eq(1, fn.luaeval('vim.stricmp("C\\0", "B\\0")'))

    eq(1, fn.luaeval('vim.stricmp("c\\0", "B")'))
    eq(1, fn.luaeval('vim.stricmp("C\\0", "b")'))
    eq(1, fn.luaeval('vim.stricmp("c\\0", "b")'))
    eq(1, fn.luaeval('vim.stricmp("C\\0", "B")'))

    eq(1, fn.luaeval('vim.stricmp("\\0c", "\\0B")'))
    eq(1, fn.luaeval('vim.stricmp("\\0C", "\\0b")'))
    eq(1, fn.luaeval('vim.stricmp("\\0c", "\\0b")'))
    eq(1, fn.luaeval('vim.stricmp("\\0C", "\\0B")'))

    eq(1, fn.luaeval('vim.stricmp("\\0c\\0", "\\0B\\0")'))
    eq(1, fn.luaeval('vim.stricmp("\\0C\\0", "\\0b\\0")'))
    eq(1, fn.luaeval('vim.stricmp("\\0c\\0", "\\0b\\0")'))
    eq(1, fn.luaeval('vim.stricmp("\\0C\\0", "\\0B\\0")'))
  end)

  --- @param prerel string | nil
  local function test_vim_deprecate(prerel)
    -- vim.deprecate(name, alternative, version, plugin, backtrace)
    -- See MAINTAIN.md for the soft/hard deprecation policy

    describe(('vim.deprecate prerel=%s,'):format(prerel or 'nil'), function()
      local curver --- @type {major:number, minor:number}

      before_each(function()
        curver = exec_lua('return vim.version()')
      end)

      it('plugin=nil, same message skipped', function()
        -- "0.10" or "0.10-dev+xxx"
        local curstr = ('%s.%s%s'):format(curver.major, curver.minor, prerel or '')
        eq(
          ([[foo.bar() is deprecated. Run ":checkhealth vim.deprecated" for more information]]):format(
            curstr
          ),
          exec_lua('return vim.deprecate(...)', 'foo.bar()', 'zub.wooo{ok=yay}', curstr)
        )
        -- Same message as above; skipped this time.
        eq(vim.NIL, exec_lua('return vim.deprecate(...)', 'foo.bar()', 'zub.wooo{ok=yay}', curstr))
      end)

      it('plugin=nil, no error if soft-deprecated', function()
        eq(vim.NIL, exec_lua [[return vim.deprecate('old1', 'new1', '0.99.0')]])
        -- Major version > current Nvim major is always "soft-deprecated".
        -- XXX: This is also a reminder to update the hardcoded `nvim_major`, when Nvim reaches 1.0.
        eq(vim.NIL, exec_lua [[return vim.deprecate('old2', 'new2', '1.0.0')]])
      end)

      it('plugin=nil, show error if hard-deprecated', function()
        -- "0.10" or "0.11"
        local nextver = ('%s.%s'):format(curver.major, curver.minor + (prerel and 0 or 1))

        local was_removed = prerel and 'was removed' or 'will be removed'
        eq(
          dedent(
            [[
            foo.hard_dep() is deprecated. Run ":checkhealth vim.deprecated" for more information]]
          ):format(was_removed, nextver),
          exec_lua('return vim.deprecate(...)', 'foo.hard_dep()', 'vim.new_api()', nextver)
        )
      end)

      it('plugin specified', function()
        -- When `plugin` is specified, don't show ":help deprecated". #22235
        eq(
          dedent [[
            foo.bar() is deprecated, use zub.wooo{ok=yay} instead.
            Feature will be removed in my-plugin.nvim 0.3.0]],
          exec_lua(
            'return vim.deprecate(...)',
            'foo.bar()',
            'zub.wooo{ok=yay}',
            '0.3.0',
            'my-plugin.nvim',
            false
          )
        )

        -- plugins: no soft deprecation period
        eq(
          dedent [[
            foo.bar() is deprecated, use zub.wooo{ok=yay} instead.
            Feature will be removed in my-plugin.nvim 0.11.0]],
          exec_lua(
            'return vim.deprecate(...)',
            'foo.bar()',
            'zub.wooo{ok=yay}',
            '0.11.0',
            'my-plugin.nvim',
            false
          )
        )
      end)
    end)
  end

  test_vim_deprecate()
  test_vim_deprecate('-dev+g0000000')

  it('vim.startswith', function()
    eq(true, fn.luaeval('vim.startswith("123", "1")'))
    eq(true, fn.luaeval('vim.startswith("123", "")'))
    eq(true, fn.luaeval('vim.startswith("123", "123")'))
    eq(true, fn.luaeval('vim.startswith("", "")'))

    eq(false, fn.luaeval('vim.startswith("123", " ")'))
    eq(false, fn.luaeval('vim.startswith("123", "2")'))
    eq(false, fn.luaeval('vim.startswith("123", "1234")'))

    matches(
      'prefix: expected string, got nil',
      pcall_err(exec_lua, 'return vim.startswith("123", nil)')
    )
    matches('s: expected string, got nil', pcall_err(exec_lua, 'return vim.startswith(nil, "123")'))
  end)

  it('vim.endswith', function()
    eq(true, fn.luaeval('vim.endswith("123", "3")'))
    eq(true, fn.luaeval('vim.endswith("123", "")'))
    eq(true, fn.luaeval('vim.endswith("123", "123")'))
    eq(true, fn.luaeval('vim.endswith("", "")'))

    eq(false, fn.luaeval('vim.endswith("123", " ")'))
    eq(false, fn.luaeval('vim.endswith("123", "2")'))
    eq(false, fn.luaeval('vim.endswith("123", "1234")'))

    matches(
      'suffix: expected string, got nil',
      pcall_err(exec_lua, 'return vim.endswith("123", nil)')
    )
    matches('s: expected string, got nil', pcall_err(exec_lua, 'return vim.endswith(nil, "123")'))
  end)

  it('vim.str_utfindex/str_byteindex', function()
    exec_lua([[_G.test_text = "xy åäö ɧ 汉语 ↥ 🤦x🦄 å بِيَّ\000ъ"]])
    local indices32 = {
      [0] = 0,
      1,
      2,
      3,
      5,
      7,
      9,
      10,
      12,
      13,
      16,
      19,
      20,
      23,
      24,
      28,
      29,
      33,
      34,
      35,
      37,
      38,
      40,
      42,
      44,
      46,
      48,
      49,
      51,
    }
    local indices16 = {
      [0] = 0,
      1,
      2,
      3,
      5,
      7,
      9,
      10,
      12,
      13,
      16,
      19,
      20,
      23,
      24,
      28,
      28,
      29,
      33,
      33,
      34,
      35,
      37,
      38,
      40,
      42,
      44,
      46,
      48,
      49,
      51,
    }
    local indices8 = {
      [0] = 0,
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
      23,
      24,
      25,
      26,
      27,
      28,
      29,
      30,
      31,
      32,
      33,
      34,
      35,
      36,
      37,
      38,
      39,
      40,
      41,
      42,
      43,
      44,
      45,
      46,
      47,
      48,
      49,
      50,
      51,
    }
    for i, k in pairs(indices32) do
      eq(k, exec_lua('return vim.str_byteindex(_G.test_text, ...)', i), i)
      eq(k, exec_lua('return vim.str_byteindex(_G.test_text, ..., false)', i), i)
      eq(k, exec_lua('return vim.str_byteindex(_G.test_text, "utf-32", ...)', i), i)
    end
    for i, k in pairs(indices16) do
      eq(k, exec_lua('return vim.str_byteindex(_G.test_text, ..., true)', i), i)
      eq(k, exec_lua('return vim.str_byteindex(_G.test_text, "utf-16", ...)', i), i)
    end
    for i, k in pairs(indices8) do
      eq(k, exec_lua('return vim.str_byteindex(_G.test_text, "utf-8", ...)', i), i)
    end
    matches(
      'index out of range',
      pcall_err(exec_lua, 'return vim.str_byteindex(_G.test_text, ...)', #indices32 + 1)
    )
    matches(
      'index out of range',
      pcall_err(exec_lua, 'return vim.str_byteindex(_G.test_text, ..., true)', #indices16 + 1)
    )
    matches(
      'index out of range',
      pcall_err(exec_lua, 'return vim.str_byteindex(_G.test_text, "utf-16", ...)', #indices16 + 1)
    )
    matches(
      'index out of range',
      pcall_err(exec_lua, 'return vim.str_byteindex(_G.test_text, "utf-32", ...)', #indices32 + 1)
    )
    matches(
      'invalid encoding',
      pcall_err(exec_lua, 'return vim.str_byteindex("hello", "madeupencoding", 1)')
    )
    eq(
      indices32[#indices32],
      exec_lua('return vim.str_byteindex(_G.test_text, "utf-32", 99999, false)')
    )
    eq(
      indices16[#indices16],
      exec_lua('return vim.str_byteindex(_G.test_text, "utf-16", 99999, false)')
    )
    eq(
      indices8[#indices8],
      exec_lua('return vim.str_byteindex(_G.test_text, "utf-8", 99999, false)')
    )
    eq(2, exec_lua('return vim.str_byteindex("é", "utf-16", 2, false)'))
    local i32, i16, i8 = 0, 0, 0
    local len = 51
    for k = 0, len do
      if indices32[i32] < k then
        i32 = i32 + 1
      end
      if indices16[i16] < k then
        i16 = i16 + 1
        if indices16[i16 + 1] == indices16[i16] then
          i16 = i16 + 1
        end
      end
      if indices8[i8] < k then
        i8 = i8 + 1
      end
      eq({ i32, i16 }, exec_lua('return {vim.str_utfindex(_G.test_text, ...)}', k), k)
      eq({ i32 }, exec_lua('return {vim.str_utfindex(_G.test_text, "utf-32", ...)}', k), k)
      eq({ i16 }, exec_lua('return {vim.str_utfindex(_G.test_text, "utf-16", ...)}', k), k)
      eq({ i8 }, exec_lua('return {vim.str_utfindex(_G.test_text, "utf-8", ...)}', k), k)
    end

    eq({ #indices32, #indices16 }, exec_lua('return {vim.str_utfindex(_G.test_text)}'))

    eq(#indices32, exec_lua('return vim.str_utfindex(_G.test_text, "utf-32", math.huge, false)'))
    eq(#indices16, exec_lua('return vim.str_utfindex(_G.test_text, "utf-16", math.huge, false)'))
    eq(#indices8, exec_lua('return vim.str_utfindex(_G.test_text, "utf-8", math.huge, false)'))

    eq(#indices32, exec_lua('return vim.str_utfindex(_G.test_text, "utf-32")'))
    eq(#indices16, exec_lua('return vim.str_utfindex(_G.test_text, "utf-16")'))
    eq(#indices8, exec_lua('return vim.str_utfindex(_G.test_text, "utf-8")'))
    matches(
      'invalid encoding',
      pcall_err(exec_lua, 'return vim.str_utfindex(_G.test_text, "madeupencoding", ...)', 1)
    )
    matches(
      'index out of range',
      pcall_err(exec_lua, 'return vim.str_utfindex(_G.test_text, ...)', len + 1)
    )
  end)

  it('vim.str_utf_start', function()
    exec_lua([[_G.test_text = "xy åäö ɧ 汉语 ↥ 🤦x🦄 å بِيَّ"]])
    local expected_positions = {
      0,
      0,
      0,
      0,
      -1,
      0,
      -1,
      0,
      -1,
      0,
      0,
      -1,
      0,
      0,
      -1,
      -2,
      0,
      -1,
      -2,
      0,
      0,
      -1,
      -2,
      0,
      0,
      -1,
      -2,
      -3,
      0,
      0,
      -1,
      -2,
      -3,
      0,
      0,
      0,
      -1,
      0,
      0,
      -1,
      0,
      -1,
      0,
      -1,
      0,
      -1,
      0,
      -1,
    }
    eq(
      expected_positions,
      exec_lua([[
      local start_codepoint_positions = {}
      for idx = 1, #_G.test_text do
        table.insert(start_codepoint_positions, vim.str_utf_start(_G.test_text, idx))
      end
      return start_codepoint_positions
    ]])
    )
  end)

  it('vim.str_utf_end', function()
    exec_lua([[_G.test_text = "xy åäö ɧ 汉语 ↥ 🤦x🦄 å بِيَّ"]])
    local expected_positions = {
      0,
      0,
      0,
      1,
      0,
      1,
      0,
      1,
      0,
      0,
      1,
      0,
      0,
      2,
      1,
      0,
      2,
      1,
      0,
      0,
      2,
      1,
      0,
      0,
      3,
      2,
      1,
      0,
      0,
      3,
      2,
      1,
      0,
      0,
      0,
      1,
      0,
      0,
      1,
      0,
      1,
      0,
      1,
      0,
      1,
      0,
      1,
      0,
    }
    eq(
      expected_positions,
      exec_lua([[
      local end_codepoint_positions = {}
      for idx = 1, #_G.test_text do
        table.insert(end_codepoint_positions, vim.str_utf_end(_G.test_text, idx))
      end
      return end_codepoint_positions
    ]])
    )
  end)

  it('vim.str_utf_pos', function()
    exec_lua([[_G.test_text = "xy åäö ɧ 汉语 ↥ 🤦x🦄 å بِيَّ"]])
    local expected_positions = {
      1,
      2,
      3,
      4,
      6,
      8,
      10,
      11,
      13,
      14,
      17,
      20,
      21,
      24,
      25,
      29,
      30,
      34,
      35,
      36,
      38,
      39,
      41,
      43,
      45,
      47,
    }
    eq(expected_positions, exec_lua('return vim.str_utf_pos(_G.test_text)'))
  end)

  it('vim.schedule', function()
    exec_lua([[
      test_table = {}
      vim.schedule(function()
        table.insert(test_table, "xx")
      end)
      table.insert(test_table, "yy")
    ]])
    eq({ 'yy', 'xx' }, exec_lua('return test_table'))

    -- Validates args.
    matches('vim.schedule: expected function', pcall_err(exec_lua, "vim.schedule('stringly')"))
    matches('vim.schedule: expected function', pcall_err(exec_lua, 'vim.schedule()'))

    exec_lua([[
      vim.schedule(function()
        error("big failure\nvery async")
      end)
    ]])

    feed('<cr>')
    matches('big failure\nvery async', remove_trace(eval('v:errmsg')))

    local screen = Screen.new(60, 5)
    screen:expect {
      grid = [[
      ^                                                            |
      {1:~                                                           }|*3
                                                                  |
    ]],
    }

    -- nvim_command causes a Vimscript exception, check that it is properly caught
    -- and propagated as an error message in async contexts.. #10809
    exec_lua([[
      vim.schedule(function()
        vim.api.nvim_command(":echo 'err")
      end)
    ]])
    screen:expect {
      grid = [[
      {9:stack traceback:}                                            |
      {9:        [C]: in function 'nvim_command'}                     |
      {9:        [string "<nvim>"]:2: in function <[string "<nvim>"]:}|
      {9:1>}                                                          |
      {6:Press ENTER or type command to continue}^                     |
    ]],
    }
  end)

  it('vim.gsplit, vim.split', function()
    local tests = {
      --                            plain  trimempty
      { 'a,b', ',', false, false, { 'a', 'b' } },
      { ':aa::::bb:', ':', false, false, { '', 'aa', '', '', '', 'bb', '' } },
      { ':aa::::bb:', ':', false, true, { 'aa', '', '', '', 'bb' } },
      { 'aa::::bb:', ':', false, true, { 'aa', '', '', '', 'bb' } },
      { ':aa::bb:', ':', false, true, { 'aa', '', 'bb' } },
      { '/a/b:/b/\n', '[:\n]', false, true, { '/a/b', '/b/' } },
      { '::ee::ff:', ':', false, false, { '', '', 'ee', '', 'ff', '' } },
      { '::ee::ff::', ':', false, true, { 'ee', '', 'ff' } },
      { 'ab', '.', false, false, { '', '', '' } },
      { 'a1b2c', '[0-9]', false, false, { 'a', 'b', 'c' } },
      { 'xy', '', false, false, { 'x', 'y' } },
      { 'here be dragons', ' ', false, false, { 'here', 'be', 'dragons' } },
      { 'axaby', 'ab?', false, false, { '', 'x', 'y' } },
      { 'f v2v v3v w2w ', '([vw])2%1', false, false, { 'f ', ' v3v ', ' ' } },
      { '', '', false, false, {} },
      { '', '', false, true, {} },
      { '\n', '[:\n]', false, true, {} },
      { '', 'a', false, false, { '' } },
      { 'x*yz*oo*l', '*', true, false, { 'x', 'yz', 'oo', 'l' } },
    }

    for _, q in ipairs(tests) do
      eq(q[5], vim.split(q[1], q[2], { plain = q[3], trimempty = q[4] }), q[1])
    end

    -- Test old signature
    eq({ 'x', 'yz', 'oo', 'l' }, vim.split('x*yz*oo*l', '*', true))

    local loops = {
      { 'abc', '.-' },
    }

    for _, q in ipairs(loops) do
      matches('Infinite loop detected', pcall_err(vim.split, q[1], q[2]))
    end

    -- Validates args.
    eq(true, pcall(vim.split, 'string', 'string'))
    matches('s: expected string, got number', pcall_err(vim.split, 1, 'string'))
    matches('sep: expected string, got number', pcall_err(vim.split, 'string', 1))
    matches('opts: expected table, got number', pcall_err(vim.split, 'string', 'string', 1))
  end)

  it('vim.trim', function()
    local trim = function(s)
      return exec_lua('return vim.trim(...)', s)
    end

    local trims = {
      { '   a', 'a' },
      { ' b  ', 'b' },
      { '\tc', 'c' },
      { 'r\n', 'r' },
    }

    for _, q in ipairs(trims) do
      assert(q[2], trim(q[1]))
    end

    -- Validates args.
    matches('s: expected string, got number', pcall_err(trim, 2))
  end)

  it('vim.inspect', function()
    -- just make sure it basically works, it has its own test suite
    local inspect = function(q, opts)
      return exec_lua('return vim.inspect(...)', q, opts)
    end

    eq('2', inspect(2))
    eq('{+a = {+b = 1+}+}', inspect({ a = { b = 1 } }, { newline = '+', indent = '' }))

    -- special value vim.inspect.KEY works
    eq(
      '{  KEY_a = "x",  KEY_b = "y"}',
      exec_lua([[
      return vim.inspect({a="x", b="y"}, {newline = '', process = function(item, path)
        if path[#path] == vim.inspect.KEY then
          return 'KEY_'..item
        end
        return item
      end})
    ]])
    )
  end)

  it('vim.deepcopy', function()
    ok(exec_lua([[
      local a = { x = { 1, 2 }, y = 5}
      local b = vim.deepcopy(a)

      return b.x[1] == 1 and b.x[2] == 2 and b.y == 5 and vim.tbl_count(b) == 2
             and tostring(a) ~= tostring(b)
    ]]))

    ok(exec_lua([[
      local a = {}
      local b = vim.deepcopy(a)

      return vim.islist(b) and vim.tbl_count(b) == 0 and tostring(a) ~= tostring(b)
    ]]))

    ok(exec_lua([[
      local a = vim.empty_dict()
      local b = vim.deepcopy(a)

      return not vim.islist(b) and vim.tbl_count(b) == 0
    ]]))

    ok(exec_lua([[
      local a = {x = vim.empty_dict(), y = {}}
      local b = vim.deepcopy(a)

      return not vim.islist(b.x) and vim.islist(b.y)
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

    ok(exec_lua([[
      local t1 = {a = 5}
      t1.self = t1
      local t2 = vim.deepcopy(t1)
      return t2.self == t2 and t2.self ~= t1
    ]]))

    ok(exec_lua([[
      local mt = {mt=true}
      local t1 = setmetatable({a = 5}, mt)
      local t2 = vim.deepcopy(t1)
      return getmetatable(t2) == mt
    ]]))

    ok(exec_lua([[
      local t1 = {a = vim.NIL}
      local t2 = vim.deepcopy(t1)
      return t2.a == vim.NIL
    ]]))

    matches(
      'Cannot deepcopy object of type thread',
      pcall_err(
        exec_lua,
        [[
        local thread = coroutine.create(function () return 0 end)
        local t = {thr = thread}
        vim.deepcopy(t)
      ]]
      )
    )
  end)

  it('vim.pesc', function()
    eq('foo%-bar', exec_lua([[return vim.pesc('foo-bar')]]))
    eq('foo%%%-bar', exec_lua([[return vim.pesc(vim.pesc('foo-bar'))]]))
    -- pesc() returns one result. #20751
    eq({ 'x' }, exec_lua([[return {vim.pesc('x')}]]))

    -- Validates args.
    matches('s: expected string, got number', pcall_err(exec_lua, [[return vim.pesc(2)]]))
  end)

  it('vim.list_contains', function()
    eq(true, exec_lua("return vim.list_contains({'a','b','c'}, 'c')"))
    eq(false, exec_lua("return vim.list_contains({'a','b','c'}, 'd')"))
  end)

  it('vim.tbl_contains', function()
    eq(true, exec_lua("return vim.tbl_contains({'a','b','c'}, 'c')"))
    eq(false, exec_lua("return vim.tbl_contains({'a','b','c'}, 'd')"))
    eq(true, exec_lua("return vim.tbl_contains({[2]='a',foo='b',[5] = 'c'}, 'c')"))
    eq(
      true,
      exec_lua([[
        return vim.tbl_contains({ 'a', { 'b', 'c' } }, function(v)
          return vim.deep_equal(v, { 'b', 'c' })
        end, { predicate = true })
    ]])
    )
  end)

  it('vim.tbl_keys', function()
    eq({}, exec_lua('return vim.tbl_keys({})'))
    for _, v in pairs(exec_lua("return vim.tbl_keys({'a', 'b', 'c'})")) do
      eq(true, exec_lua('return vim.tbl_contains({ 1, 2, 3 }, ...)', v))
    end
    for _, v in pairs(exec_lua('return vim.tbl_keys({a=1, b=2, c=3})')) do
      eq(true, exec_lua("return vim.tbl_contains({ 'a', 'b', 'c' }, ...)", v))
    end
  end)

  it('vim.tbl_values', function()
    eq({}, exec_lua('return vim.tbl_values({})'))
    for _, v in pairs(exec_lua("return vim.tbl_values({'a', 'b', 'c'})")) do
      eq(true, exec_lua("return vim.tbl_contains({ 'a', 'b', 'c' }, ...)", v))
    end
    for _, v in pairs(exec_lua('return vim.tbl_values({a=1, b=2, c=3})')) do
      eq(true, exec_lua('return vim.tbl_contains({ 1, 2, 3 }, ...)', v))
    end
  end)

  it('vim.tbl_map', function()
    eq(
      {},
      exec_lua([[
      return vim.tbl_map(function(v) return v * 2 end, {})
    ]])
    )
    eq(
      { 2, 4, 6 },
      exec_lua([[
      return vim.tbl_map(function(v) return v * 2 end, {1, 2, 3})
    ]])
    )
    eq(
      { { i = 2 }, { i = 4 }, { i = 6 } },
      exec_lua([[
      return vim.tbl_map(function(v) return { i = v.i * 2 } end, {{i=1}, {i=2}, {i=3}})
    ]])
    )
  end)

  it('vim.tbl_filter', function()
    eq(
      {},
      exec_lua([[
      return vim.tbl_filter(function(v) return (v % 2) == 0 end, {})
    ]])
    )
    eq(
      { 2 },
      exec_lua([[
      return vim.tbl_filter(function(v) return (v % 2) == 0 end, {1, 2, 3})
    ]])
    )
    eq(
      { { i = 2 } },
      exec_lua([[
      return vim.tbl_filter(function(v) return (v.i % 2) == 0 end, {{i=1}, {i=2}, {i=3}})
    ]])
    )
  end)

  it('vim.isarray', function()
    eq(true, exec_lua('return vim.isarray({})'))
    eq(false, exec_lua('return vim.isarray(vim.empty_dict())'))
    eq(true, exec_lua("return vim.isarray({'a', 'b', 'c'})"))
    eq(false, exec_lua("return vim.isarray({'a', '32', a='hello', b='baz'})"))
    eq(false, exec_lua("return vim.isarray({1, a='hello', b='baz'})"))
    eq(false, exec_lua("return vim.isarray({a='hello', b='baz', 1})"))
    eq(false, exec_lua("return vim.isarray({1, 2, nil, a='hello'})"))
    eq(true, exec_lua('return vim.isarray({1, 2, nil, 4})'))
    eq(true, exec_lua('return vim.isarray({nil, 2, 3, 4})'))
    eq(false, exec_lua('return vim.isarray({1, [1.5]=2, [3]=3})'))
  end)

  it('vim.islist', function()
    eq(true, exec_lua('return vim.islist({})'))
    eq(false, exec_lua('return vim.islist(vim.empty_dict())'))
    eq(true, exec_lua("return vim.islist({'a', 'b', 'c'})"))
    eq(false, exec_lua("return vim.islist({'a', '32', a='hello', b='baz'})"))
    eq(false, exec_lua("return vim.islist({1, a='hello', b='baz'})"))
    eq(false, exec_lua("return vim.islist({a='hello', b='baz', 1})"))
    eq(false, exec_lua("return vim.islist({1, 2, nil, a='hello'})"))
    eq(false, exec_lua('return vim.islist({1, 2, nil, 4})'))
    eq(false, exec_lua('return vim.islist({nil, 2, 3, 4})'))
    eq(false, exec_lua('return vim.islist({1, [1.5]=2, [3]=3})'))
  end)

  it('vim.tbl_isempty', function()
    eq(true, exec_lua('return vim.tbl_isempty({})'))
    eq(false, exec_lua('return vim.tbl_isempty({ 1, 2, 3 })'))
    eq(false, exec_lua('return vim.tbl_isempty({a=1, b=2, c=3})'))
  end)

  it('vim.tbl_get', function()
    eq(
      true,
      exec_lua("return vim.tbl_get({ test = { nested_test = true }}, 'test', 'nested_test')")
    )
    eq(NIL, exec_lua("return vim.tbl_get({ unindexable = true }, 'unindexable', 'missing_key')"))
    eq(NIL, exec_lua("return vim.tbl_get({ unindexable = 1 }, 'unindexable', 'missing_key')"))
    eq(
      NIL,
      exec_lua(
        "return vim.tbl_get({ unindexable = coroutine.create(function () end) }, 'unindexable', 'missing_key')"
      )
    )
    eq(
      NIL,
      exec_lua(
        "return vim.tbl_get({ unindexable = function () end }, 'unindexable', 'missing_key')"
      )
    )
    eq(NIL, exec_lua("return vim.tbl_get({}, 'missing_key')"))
    eq(NIL, exec_lua('return vim.tbl_get({})'))
    eq(NIL, exec_lua("return vim.tbl_get({}, nil, 'key')"))
    eq(1, exec_lua("return select('#', vim.tbl_get({}))"))
    eq(1, exec_lua("return select('#', vim.tbl_get({ nested = {} }, 'nested', 'missing_key'))"))
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

      return not vim.islist(c) and vim.tbl_count(c) == 0
    ]]))

    ok(exec_lua([[
      local a = {}
      local b = vim.empty_dict()
      local c = vim.tbl_extend("keep", a, b)

      return vim.islist(c) and vim.tbl_count(c) == 0
    ]]))

    ok(exec_lua([[
      local a = {x = {a = 1, b = 2}}
      local b = {x = {a = 2, c = {y = 3}}}
      local c = vim.tbl_extend("keep", a, b)

      local count = 0
      for _ in pairs(c) do count = count + 1 end

      return c.x.a == 1 and c.x.b == 2 and c.x.c == nil and count == 1
    ]]))

    ok(exec_lua([[
      local a = { a = 1, b = 2, c = 1 }
      local b = { a = -1, b = 5, c = 3, d = 4 }
      -- Return the maximum value for each key.
      local c = vim.tbl_extend(function(k, prev_v, v)
        if prev_v then
          return v > prev_v and v or prev_v
        else
          return v
        end
      end, a, b)
      return vim.deep_equal(c, { a = 1, b = 5, c = 3, d = 4 })
    ]]))

    matches(
      'invalid "behavior": nil',
      pcall_err(
        exec_lua,
        [[
        return vim.tbl_extend()
      ]]
      )
    )

    matches(
      'wrong number of arguments %(given 1, expected at least 3%)',
      pcall_err(
        exec_lua,
        [[
        return vim.tbl_extend("keep")
      ]]
      )
    )

    matches(
      'wrong number of arguments %(given 2, expected at least 3%)',
      pcall_err(
        exec_lua,
        [[
        return vim.tbl_extend("keep", {})
      ]]
      )
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

      return not vim.islist(c) and count == 0
    ]]))

    ok(exec_lua([[
      local a = {}
      local b = vim.empty_dict()
      local c = vim.tbl_deep_extend("keep", a, b)

      local count = 0
      for _ in pairs(c) do count = count + 1 end

      return vim.islist(c) and count == 0
    ]]))

    eq(
      { a = { b = 1 } },
      exec_lua([[
      local a = { a = { b = 1 } }
      local b = { a = {} }
      return vim.tbl_deep_extend("force", a, b)
    ]])
    )

    eq(
      { a = { b = 1 } },
      exec_lua([[
      local a = { a = 123 }
      local b = { a = { b = 1} }
      return vim.tbl_deep_extend("force", a, b)
    ]])
    )

    ok(exec_lua([[
      local a = { a = {[2] = 3} }
      local b = { a = {[3] = 3} }
      local c = vim.tbl_deep_extend("force", a, b)
      return vim.deep_equal(c, {a = {[2] = 3, [3] = 3}})
    ]]))

    eq(
      { a = 123 },
      exec_lua([[
      local a = { a = { b = 1} }
      local b = { a = 123 }
      return vim.tbl_deep_extend("force", a, b)
    ]])
    )

    ok(exec_lua([[
      local a = { sub = { 'a', 'b' } }
      local b = { sub = { 'b', 'c' } }
      local c = vim.tbl_deep_extend('force', a, b)
      return vim.deep_equal(c, { sub = { 'b', 'c' } })
    ]]))

    ok(exec_lua([[
      local a = { a = 1, b = 2, c = { d = 1, e = -2} }
      local b = { a = -1, b = 5, c = { d = 6 } }
      -- Return the maximum value for each key.
      local c = vim.tbl_deep_extend(function(k, prev_v, v)
        if prev_v then
          return v > prev_v and v or prev_v
        else
          return v
        end
      end, a, b)
      return vim.deep_equal(c, { a = 1, b = 5, c = { d = 6, e = -2 } })
    ]]))

    matches('invalid "behavior": nil', pcall_err(exec_lua, [[return vim.tbl_deep_extend()]]))

    matches(
      'wrong number of arguments %(given 1, expected at least 3%)',
      pcall_err(exec_lua, [[return vim.tbl_deep_extend("keep")]])
    )

    matches(
      'wrong number of arguments %(given 2, expected at least 3%)',
      pcall_err(exec_lua, [[return vim.tbl_deep_extend("keep", {})]])
    )

    matches(
      'after the second argument%: expected table, got number',
      pcall_err(exec_lua, [[return vim.tbl_deep_extend("keep", {}, 42)]])
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
    eq({ 1, 2, 3 }, exec_lua [[ return vim.list_extend({1}, {2,3}) ]])
    matches(
      'src: expected table, got nil',
      pcall_err(exec_lua, [[ return vim.list_extend({1}, nil) ]])
    )
    eq({ 1, 2 }, exec_lua [[ return vim.list_extend({1}, {2;a=1}) ]])
    eq(true, exec_lua [[ local a = {1} return vim.list_extend(a, {2;a=1}) == a ]])
    eq({ 2 }, exec_lua [[ return vim.list_extend({}, {2;a=1}, 1) ]])
    eq({}, exec_lua [[ return vim.list_extend({}, {2;a=1}, 2) ]])
    eq({}, exec_lua [[ return vim.list_extend({}, {2;a=1}, 1, -1) ]])
    eq({ 2 }, exec_lua [[ return vim.list_extend({}, {2;a=1}, -1, 2) ]])
  end)

  it('vim.tbl_add_reverse_lookup', function()
    eq(
      true,
      exec_lua [[
    local a = { A = 1 }
    vim.tbl_add_reverse_lookup(a)
    return vim.deep_equal(a, { A = 1; [1] = 'A'; })
    ]]
    )
    -- Throw an error for trying to do it twice (run into an existing key)
    local code = [[
    local res = {}
    local a = { A = 1 }
    vim.tbl_add_reverse_lookup(a)
    assert(vim.deep_equal(a, { A = 1; [1] = 'A'; }))
    vim.tbl_add_reverse_lookup(a)
    ]]
    matches(
      'The reverse lookup found an existing value for "[1A]" while processing key "[1A]"$',
      pcall_err(exec_lua, code)
    )
  end)

  it('vim.spairs', function()
    local res = ''
    local table = {
      ccc = 1,
      bbb = 2,
      ddd = 3,
      aaa = 4,
    }
    for key, _ in vim.spairs(table) do
      res = res .. key
    end
    matches('aaabbbcccddd', res)
  end)

  it('vim.call, vim.fn', function()
    eq(true, exec_lua([[return vim.call('sin', 0.0) == 0.0 ]]))
    eq(true, exec_lua([[return vim.fn.sin(0.0) == 0.0 ]]))
    -- compat: nvim_call_function uses "special" value for Vimscript float
    eq(false, exec_lua([[return vim.api.nvim_call_function('sin', {0.0}) == 0.0 ]]))

    exec([[
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
    eq(3, eval('g:test'))
    eq(true, exec_lua([[return vim.tbl_isempty(vim.api.nvim_call_function("FooFunc", {5}))]]))
    eq(5, eval('g:test'))

    eq({ 2, 'foo', true }, exec_lua([[return vim.fn.VarArg(2, "foo", true)]]))

    eq(
      true,
      exec_lua([[
      local x = vim.fn.Nilly()
      return #x == 2 and x[1] == vim.NIL and x[2] == vim.NIL
    ]])
    )
    eq({ NIL, NIL }, exec_lua([[return vim.fn.Nilly()]]))

    -- error handling
    eq(
      { false, 'Vim:E897: List or Blob required' },
      exec_lua([[return {pcall(vim.fn.add, "aa", "bb")}]])
    )

    -- conversion between LuaRef and Vim Funcref
    eq(
      true,
      exec_lua([[
      local x = vim.fn.VarArg(function() return 'foo' end, function() return 'bar' end)
      return #x == 2 and x[1]() == 'foo' and x[2]() == 'bar'
    ]])
    )

    -- Test for #20211
    eq(
      'a (b) c',
      exec_lua([[
      return vim.fn.substitute('a b c', 'b', function(m) return '(' .. m[1] .. ')' end, 'g')
    ]])
    )
  end)

  it('vim.fn errors when calling API function', function()
    matches(
      'Tried to call API function with vim.fn: use vim.api.nvim_get_current_line instead',
      pcall_err(exec_lua, 'vim.fn.nvim_get_current_line()')
    )
  end)

  it('vim.fn is allowed in "fast" context by some functions #18306', function()
    exec_lua([[
      local timer = vim.uv.new_timer()
      timer:start(0, 0, function()
        timer:close()
        assert(vim.in_fast_event())
        vim.g.fnres = vim.fn.iconv('hello', 'utf-8', 'utf-8')
      end)
    ]])

    poke_eventloop()
    eq('hello', exec_lua [[return vim.g.fnres]])
  end)

  it('vim.rpcrequest and vim.rpcnotify', function()
    exec_lua([[
      chan = vim.fn.jobstart({'cat'}, {rpc=true})
      vim.rpcrequest(chan, 'nvim_set_current_line', 'meow')
    ]])
    eq('meow', api.nvim_get_current_line())
    command("let x = [3, 'aa', v:true, v:null]")
    eq(
      true,
      exec_lua([[
      ret = vim.rpcrequest(chan, 'nvim_get_var', 'x')
      return #ret == 4 and ret[1] == 3 and ret[2] == 'aa' and ret[3] == true and ret[4] == vim.NIL
    ]])
    )
    eq({ 3, 'aa', true, NIL }, exec_lua([[return ret]]))

    eq(
      { {}, {}, false, true },
      exec_lua([[
      vim.rpcrequest(chan, 'nvim_exec', 'let xx = {}\nlet yy = []', false)
      local dict = vim.rpcrequest(chan, 'nvim_eval', 'xx')
      local list = vim.rpcrequest(chan, 'nvim_eval', 'yy')
      return {dict, list, vim.islist(dict), vim.islist(list)}
     ]])
    )

    exec_lua([[
       vim.rpcrequest(chan, 'nvim_set_var', 'aa', {})
       vim.rpcrequest(chan, 'nvim_set_var', 'bb', vim.empty_dict())
     ]])
    eq({ 1, 1 }, eval('[type(g:aa) == type([]), type(g:bb) == type({})]'))

    -- error handling
    eq({ false, 'Invalid channel: 23' }, exec_lua([[return {pcall(vim.rpcrequest, 23, 'foo')}]]))
    eq({ false, 'Invalid channel: 23' }, exec_lua([[return {pcall(vim.rpcnotify, 23, 'foo')}]]))

    eq(
      { false, 'Vim:E121: Undefined variable: foobar' },
      exec_lua([[return {pcall(vim.rpcrequest, chan, 'nvim_eval', "foobar")}]])
    )

    -- rpcnotify doesn't wait on request
    eq(
      'meow',
      exec_lua([[
      vim.rpcnotify(chan, 'nvim_set_current_line', 'foo')
      return vim.api.nvim_get_current_line()
    ]])
    )
    retry(10, nil, function()
      eq('foo', api.nvim_get_current_line())
    end)

    local screen = Screen.new(50, 7)
    exec_lua([[
      timer = vim.uv.new_timer()
      timer:start(20, 0, function ()
        -- notify ok (executed later when safe)
        vim.rpcnotify(chan, 'nvim_set_var', 'yy', {3, vim.NIL})
        -- rpcrequest an error
        vim.rpcrequest(chan, 'nvim_set_current_line', 'bork')
      end)
    ]])
    screen:expect {
      grid = [[
      {9:[string "<nvim>"]:6: E5560: rpcrequest must not be}|
      {9: called in a fast event context}                   |
      {9:stack traceback:}                                  |
      {9:        [C]: in function 'rpcrequest'}             |
      {9:        [string "<nvim>"]:6: in function <[string }|
      {9:"<nvim>"]:2>}                                      |
      {6:Press ENTER or type command to continue}^           |
    ]],
    }
    feed('<cr>')
    retry(10, nil, function()
      eq({ 3, NIL }, api.nvim_get_var('yy'))
    end)

    exec_lua([[timer:close()]])
  end)

  it('vim.empty_dict()', function()
    eq(
      { true, false, true, true },
      exec_lua([[
      vim.api.nvim_set_var('listy', {})
      vim.api.nvim_set_var('dicty', vim.empty_dict())
      local listy = vim.fn.eval("listy")
      local dicty = vim.fn.eval("dicty")
      return {vim.islist(listy), vim.islist(dicty), next(listy) == nil, next(dicty) == nil}
    ]])
    )

    -- vim.empty_dict() gives new value each time
    -- equality is not overridden (still by ref)
    -- non-empty table uses the usual heuristics (ignores the tag)
    eq(
      { false, { 'foo' }, { namey = 'bar' } },
      exec_lua([[
      local aa = vim.empty_dict()
      local bb = vim.empty_dict()
      local equally = (aa == bb)
      aa[1] = "foo"
      bb["namey"] = "bar"
      return {equally, aa, bb}
    ]])
    )

    eq('{ {}, vim.empty_dict() }', exec_lua('return vim.inspect({{}, vim.empty_dict()})'))
    eq('{}', exec_lua([[ return vim.fn.json_encode(vim.empty_dict()) ]]))
    eq('{"a": {}, "b": []}', exec_lua([[ return vim.fn.json_encode({a=vim.empty_dict(), b={}}) ]]))
  end)

  it('vim.validate (fast form)', function()
    exec_lua("vim.validate('arg1', {}, 'table')")
    exec_lua("vim.validate('arg1', nil, 'table', true)")
    exec_lua("vim.validate('arg1', { foo='foo' }, 'table')")
    exec_lua("vim.validate('arg1', { 'foo' }, 'table')")
    exec_lua("vim.validate('arg1', 'foo', 'string')")
    exec_lua("vim.validate('arg1', nil, 'string', true)")
    exec_lua("vim.validate('arg1', 1, 'number')")
    exec_lua("vim.validate('arg1', 0, 'number')")
    exec_lua("vim.validate('arg1', 0.1, 'number')")
    exec_lua("vim.validate('arg1', nil, 'number', true)")
    exec_lua("vim.validate('arg1', true, 'boolean')")
    exec_lua("vim.validate('arg1', false, 'boolean')")
    exec_lua("vim.validate('arg1', nil, 'boolean', true)")
    exec_lua("vim.validate('arg1', function()end, 'function')")
    exec_lua("vim.validate('arg1', nil, 'function', true)")
    exec_lua("vim.validate('arg1', nil, 'nil')")
    exec_lua("vim.validate('arg1', nil, 'nil', true)")
    exec_lua("vim.validate('arg1', coroutine.create(function()end), 'thread')")
    exec_lua("vim.validate('arg1', nil, 'thread', true)")
    exec_lua("vim.validate('arg1', 2, function(a) return (a % 2) == 0  end, 'even number')")
    exec_lua("vim.validate('arg1', 5, {'number', 'string'})")
    exec_lua("vim.validate('arg2', 'foo', {'number', 'string'})")

    matches('arg1: expected number, got nil', pcall_err(vim.validate, 'arg1', nil, 'number'))
    matches('arg1: expected string, got nil', pcall_err(vim.validate, 'arg1', nil, 'string'))
    matches('arg1: expected table, got nil', pcall_err(vim.validate, 'arg1', nil, 'table'))
    matches('arg1: expected function, got nil', pcall_err(vim.validate, 'arg1', nil, 'function'))
    matches('arg1: expected string, got number', pcall_err(vim.validate, 'arg1', 5, 'string'))
    matches('arg1: expected table, got number', pcall_err(vim.validate, 'arg1', 5, 'table'))
    matches('arg1: expected function, got number', pcall_err(vim.validate, 'arg1', 5, 'function'))
    matches('arg1: expected number, got string', pcall_err(vim.validate, 'arg1', '5', 'number'))
    matches('arg1: expected x, got number', pcall_err(exec_lua, "vim.validate('arg1', 1, 'x')"))
    matches('invalid validator: 1', pcall_err(exec_lua, "vim.validate('arg1', 1, 1)"))
    matches('invalid arguments', pcall_err(exec_lua, "vim.validate('arg1', { 1 })"))

    -- Validated parameters are required by default.
    matches(
      'arg1: expected string, got nil',
      pcall_err(exec_lua, "vim.validate('arg1',  nil, 'string')")
    )
    -- Explicitly required.
    matches(
      'arg1: expected string, got nil',
      pcall_err(exec_lua, "vim.validate('arg1', nil, 'string', false)")
    )

    matches(
      'arg1: expected table, got number',
      pcall_err(exec_lua, "vim.validate('arg1', 1, 'table')")
    )

    matches(
      'arg1: expected even number, got 3',
      pcall_err(exec_lua, "vim.validate('arg1', 3, function(a) return a == 1 end, 'even number')")
    )
    matches(
      'arg1: expected %?, got 3',
      pcall_err(exec_lua, "vim.validate('arg1', 3, function(a) return a == 1 end)")
    )
    matches(
      'arg1: expected number|string, got nil',
      pcall_err(exec_lua, "vim.validate('arg1', nil, {'number', 'string'})")
    )

    -- Validator func can return an extra "Info" message.
    matches(
      'arg1: expected %?, got 3. Info: TEST_MSG',
      pcall_err(exec_lua, "vim.validate('arg1', 3, function(a) return a == 1, 'TEST_MSG' end)")
    )
    -- Caller can override the "expected" message.
    eq(
      'arg1: expected TEST_MSG, got nil',
      pcall_err(exec_lua, "vim.validate('arg1', nil, 'table', 'TEST_MSG')")
    )
  end)

  it('vim.validate (spec form)', function()
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
    exec_lua("vim.validate{arg1={5, {'n', 's'} }, arg2={ 'foo', {'n', 's'} }}")

    matches('expected table, got number', pcall_err(exec_lua, "vim.validate{ 1, 'x' }"))
    matches('arg1: expected x, got number', pcall_err(exec_lua, "vim.validate{ arg1={ 1, 'x' }}"))
    matches('invalid validator: 1', pcall_err(exec_lua, 'vim.validate{ arg1={ 1, 1 }}'))
    matches('invalid validator: nil', pcall_err(exec_lua, 'vim.validate{ arg1={ 1 }}'))

    -- Validated parameters are required by default.
    matches(
      'arg1: expected string, got nil',
      pcall_err(exec_lua, "vim.validate{ arg1={ nil, 's' }}")
    )
    -- Explicitly required.
    matches(
      'arg1: expected string, got nil',
      pcall_err(exec_lua, "vim.validate{ arg1={ nil, 's', false }}")
    )

    matches('arg1: expected table, got number', pcall_err(exec_lua, "vim.validate{arg1={1, 't'}}"))
    matches(
      'arg2: expected string, got number',
      pcall_err(exec_lua, "vim.validate{arg1={{}, 't'}, arg2={1, 's'}}")
    )
    matches(
      'arg2: expected string, got nil',
      pcall_err(exec_lua, "vim.validate{arg1={{}, 't'}, arg2={nil, 's'}}")
    )
    matches(
      'arg2: expected string, got nil',
      pcall_err(exec_lua, "vim.validate{arg1={{}, 't'}, arg2={nil, 's'}}")
    )
    matches(
      'arg1: expected even number, got 3',
      pcall_err(exec_lua, "vim.validate{arg1={3, function(a) return a == 1 end, 'even number'}}")
    )
    matches(
      'arg1: expected %?, got 3',
      pcall_err(exec_lua, 'vim.validate{arg1={3, function(a) return a == 1 end}}')
    )
    matches(
      'arg1: expected number|string, got nil',
      pcall_err(exec_lua, "vim.validate{ arg1={ nil, {'n', 's'} }}")
    )

    -- Pass an additional message back.
    matches(
      'arg1: expected %?, got 3. Info: TEST_MSG',
      pcall_err(exec_lua, "vim.validate{arg1={3, function(a) return a == 1, 'TEST_MSG' end}}")
    )
  end)

  it('vim.is_callable', function()
    eq(true, exec_lua('return vim.is_callable(function()end)'))
    eq(
      true,
      exec_lua([[
      local meta = { __call = function()end }
      local function new_callable()
        return setmetatable({}, meta)
      end
      local callable = new_callable()
      return vim.is_callable(callable)
    ]])
    )

    eq(
      { false, false },
      exec_lua([[
      local meta = { __call = {} }
      assert(meta.__call)
      local function new()
        return setmetatable({}, meta)
      end
      local not_callable = new()
      return { pcall(function() not_callable() end), vim.is_callable(not_callable) }
    ]])
    )
    eq(
      { false, false },
      exec_lua([[
      local function new()
        return { __call = function()end }
      end
      local not_callable = new()
      assert(not_callable.__call)
      return { pcall(function() not_callable() end), vim.is_callable(not_callable) }
    ]])
    )
    eq(
      { false, false },
      exec_lua([[
      local meta = setmetatable(
        { __index = { __call = function() end } },
        { __index = { __call = function() end } }
      )
      assert(meta.__call)
      local not_callable = setmetatable({}, meta)
      assert(not_callable.__call)
      return { pcall(function() not_callable() end), vim.is_callable(not_callable) }
    ]])
    )
    eq(
      { false, false },
      exec_lua([[
      local meta = setmetatable({
        __index = function()
          return function() end
        end,
      }, {
        __index = function()
          return function() end
        end,
      })
      assert(meta.__call)
      local not_callable = setmetatable({}, meta)
      assert(not_callable.__call)
      return { pcall(function() not_callable() end), vim.is_callable(not_callable) }
    ]])
    )
    eq(false, exec_lua('return vim.is_callable(1)'))
    eq(false, exec_lua("return vim.is_callable('foo')"))
    eq(false, exec_lua('return vim.is_callable({})'))
  end)

  it('vim.g', function()
    exec_lua [[
    vim.api.nvim_set_var("testing", "hi")
    vim.api.nvim_set_var("other", 123)
    vim.api.nvim_set_var("floaty", 5120.1)
    vim.api.nvim_set_var("nullvar", vim.NIL)
    vim.api.nvim_set_var("to_delete", {hello="world"})
    ]]

    eq('hi', fn.luaeval 'vim.g.testing')
    eq(123, fn.luaeval 'vim.g.other')
    eq(5120.1, fn.luaeval 'vim.g.floaty')
    eq(NIL, fn.luaeval 'vim.g.nonexistent')
    eq(NIL, fn.luaeval 'vim.g.nullvar')
    -- lost over RPC, so test locally:
    eq(
      { false, true },
      exec_lua [[
      return {vim.g.nonexistent == vim.NIL, vim.g.nullvar == vim.NIL}
    ]]
    )

    eq({ hello = 'world' }, fn.luaeval 'vim.g.to_delete')
    exec_lua [[
    vim.g.to_delete = nil
    ]]
    eq(NIL, fn.luaeval 'vim.g.to_delete')

    matches([[attempt to index .* nil value]], pcall_err(exec_lua, 'return vim.g[0].testing'))

    exec_lua [[
      local counter = 0
      local function add_counter() counter = counter + 1 end
      local function get_counter() return counter end
      vim.g.AddCounter = add_counter
      vim.g.GetCounter = get_counter
      vim.g.fn = {add = add_counter, get = get_counter}
      vim.g.AddParens = function(s) return '(' .. s .. ')' end
    ]]

    eq(0, eval('g:GetCounter()'))
    eval('g:AddCounter()')
    eq(1, eval('g:GetCounter()'))
    eval('g:AddCounter()')
    eq(2, eval('g:GetCounter()'))
    exec_lua([[vim.g.AddCounter()]])
    eq(3, exec_lua([[return vim.g.GetCounter()]]))
    exec_lua([[vim.api.nvim_get_var('AddCounter')()]])
    eq(4, exec_lua([[return vim.api.nvim_get_var('GetCounter')()]]))
    exec_lua([[vim.g.fn.add()]])
    eq(5, exec_lua([[return vim.g.fn.get()]]))
    exec_lua([[vim.api.nvim_get_var('fn').add()]])
    eq(6, exec_lua([[return vim.api.nvim_get_var('fn').get()]]))
    eq('((foo))', eval([['foo'->AddParens()->AddParens()]]))

    exec_lua [[
      local counter = 0
      local function add_counter() counter = counter + 1 end
      local function get_counter() return counter end
      vim.api.nvim_set_var('AddCounter', add_counter)
      vim.api.nvim_set_var('GetCounter', get_counter)
      vim.api.nvim_set_var('fn', {add = add_counter, get = get_counter})
      vim.api.nvim_set_var('AddParens', function(s) return '(' .. s .. ')' end)
    ]]

    eq(0, eval('g:GetCounter()'))
    eval('g:AddCounter()')
    eq(1, eval('g:GetCounter()'))
    eval('g:AddCounter()')
    eq(2, eval('g:GetCounter()'))
    exec_lua([[vim.g.AddCounter()]])
    eq(3, exec_lua([[return vim.g.GetCounter()]]))
    exec_lua([[vim.api.nvim_get_var('AddCounter')()]])
    eq(4, exec_lua([[return vim.api.nvim_get_var('GetCounter')()]]))
    exec_lua([[vim.g.fn.add()]])
    eq(5, exec_lua([[return vim.g.fn.get()]]))
    exec_lua([[vim.api.nvim_get_var('fn').add()]])
    eq(6, exec_lua([[return vim.api.nvim_get_var('fn').get()]]))
    eq('((foo))', eval([['foo'->AddParens()->AddParens()]]))

    exec([[
      function Test()
      endfunction
      function s:Test()
      endfunction
      let g:Unknown_func = function('Test')
      let g:Unknown_script_func = function('s:Test')
    ]])
    eq(NIL, exec_lua([[return vim.g.Unknown_func]]))
    eq(NIL, exec_lua([[return vim.g.Unknown_script_func]]))

    -- Check if autoload works properly
    local pathsep = n.get_pathsep()
    local xconfig = 'Xhome' .. pathsep .. 'Xconfig'
    local xdata = 'Xhome' .. pathsep .. 'Xdata'
    local autoload_folder = table.concat({ xconfig, 'nvim', 'autoload' }, pathsep)
    local autoload_file = table.concat({ autoload_folder, 'testload.vim' }, pathsep)
    mkdir_p(autoload_folder)
    write_file(autoload_file, [[let testload#value = 2]])

    clear { args_rm = { '-u' }, env = { XDG_CONFIG_HOME = xconfig, XDG_DATA_HOME = xdata } }

    eq(2, exec_lua("return vim.g['testload#value']"))
    rmdir('Xhome')
  end)

  it('vim.b', function()
    exec_lua [[
    vim.api.nvim_buf_set_var(0, "testing", "hi")
    vim.api.nvim_buf_set_var(0, "other", 123)
    vim.api.nvim_buf_set_var(0, "floaty", 5120.1)
    vim.api.nvim_buf_set_var(0, "nullvar", vim.NIL)
    vim.api.nvim_buf_set_var(0, "to_delete", {hello="world"})
    BUF = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_var(BUF, "testing", "bye")
    ]]

    eq('hi', fn.luaeval 'vim.b.testing')
    eq('bye', fn.luaeval 'vim.b[BUF].testing')
    eq(123, fn.luaeval 'vim.b.other')
    eq(5120.1, fn.luaeval 'vim.b.floaty')
    eq(NIL, fn.luaeval 'vim.b.nonexistent')
    eq(NIL, fn.luaeval 'vim.b[BUF].nonexistent')
    eq(NIL, fn.luaeval 'vim.b.nullvar')
    -- lost over RPC, so test locally:
    eq(
      { false, true },
      exec_lua [[
      return {vim.b.nonexistent == vim.NIL, vim.b.nullvar == vim.NIL}
    ]]
    )

    matches([[attempt to index .* nil value]], pcall_err(exec_lua, 'return vim.b[BUF][0].testing'))

    eq({ hello = 'world' }, fn.luaeval 'vim.b.to_delete')
    exec_lua [[
    vim.b.to_delete = nil
    ]]
    eq(NIL, fn.luaeval 'vim.b.to_delete')

    exec_lua [[
      local counter = 0
      local function add_counter() counter = counter + 1 end
      local function get_counter() return counter end
      vim.b.AddCounter = add_counter
      vim.b.GetCounter = get_counter
      vim.b.fn = {add = add_counter, get = get_counter}
      vim.b.AddParens = function(s) return '(' .. s .. ')' end
    ]]

    eq(0, eval('b:GetCounter()'))
    eval('b:AddCounter()')
    eq(1, eval('b:GetCounter()'))
    eval('b:AddCounter()')
    eq(2, eval('b:GetCounter()'))
    exec_lua([[vim.b.AddCounter()]])
    eq(3, exec_lua([[return vim.b.GetCounter()]]))
    exec_lua([[vim.api.nvim_buf_get_var(0, 'AddCounter')()]])
    eq(4, exec_lua([[return vim.api.nvim_buf_get_var(0, 'GetCounter')()]]))
    exec_lua([[vim.b.fn.add()]])
    eq(5, exec_lua([[return vim.b.fn.get()]]))
    exec_lua([[vim.api.nvim_buf_get_var(0, 'fn').add()]])
    eq(6, exec_lua([[return vim.api.nvim_buf_get_var(0, 'fn').get()]]))
    eq('((foo))', eval([['foo'->b:AddParens()->b:AddParens()]]))

    exec_lua [[
      local counter = 0
      local function add_counter() counter = counter + 1 end
      local function get_counter() return counter end
      vim.api.nvim_buf_set_var(0, 'AddCounter', add_counter)
      vim.api.nvim_buf_set_var(0, 'GetCounter', get_counter)
      vim.api.nvim_buf_set_var(0, 'fn', {add = add_counter, get = get_counter})
      vim.api.nvim_buf_set_var(0, 'AddParens', function(s) return '(' .. s .. ')' end)
    ]]

    eq(0, eval('b:GetCounter()'))
    eval('b:AddCounter()')
    eq(1, eval('b:GetCounter()'))
    eval('b:AddCounter()')
    eq(2, eval('b:GetCounter()'))
    exec_lua([[vim.b.AddCounter()]])
    eq(3, exec_lua([[return vim.b.GetCounter()]]))
    exec_lua([[vim.api.nvim_buf_get_var(0, 'AddCounter')()]])
    eq(4, exec_lua([[return vim.api.nvim_buf_get_var(0, 'GetCounter')()]]))
    exec_lua([[vim.b.fn.add()]])
    eq(5, exec_lua([[return vim.b.fn.get()]]))
    exec_lua([[vim.api.nvim_buf_get_var(0, 'fn').add()]])
    eq(6, exec_lua([[return vim.api.nvim_buf_get_var(0, 'fn').get()]]))
    eq('((foo))', eval([['foo'->b:AddParens()->b:AddParens()]]))

    exec([[
      function Test()
      endfunction
      function s:Test()
      endfunction
      let b:Unknown_func = function('Test')
      let b:Unknown_script_func = function('s:Test')
    ]])
    eq(NIL, exec_lua([[return vim.b.Unknown_func]]))
    eq(NIL, exec_lua([[return vim.b.Unknown_script_func]]))

    exec_lua [[
    vim.cmd "vnew"
    ]]

    eq(NIL, fn.luaeval 'vim.b.testing')
    eq(NIL, fn.luaeval 'vim.b.other')
    eq(NIL, fn.luaeval 'vim.b.nonexistent')
  end)

  it('vim.w', function()
    exec_lua [[
    vim.api.nvim_win_set_var(0, "testing", "hi")
    vim.api.nvim_win_set_var(0, "other", 123)
    vim.api.nvim_win_set_var(0, "to_delete", {hello="world"})
    BUF = vim.api.nvim_create_buf(false, true)
    WIN = vim.api.nvim_open_win(BUF, false, {
      width=10, height=10,
      relative='win', row=0, col=0
    })
    vim.api.nvim_win_set_var(WIN, "testing", "bye")
    ]]

    eq('hi', fn.luaeval 'vim.w.testing')
    eq('bye', fn.luaeval 'vim.w[WIN].testing')
    eq(123, fn.luaeval 'vim.w.other')
    eq(NIL, fn.luaeval 'vim.w.nonexistent')
    eq(NIL, fn.luaeval 'vim.w[WIN].nonexistent')

    matches([[attempt to index .* nil value]], pcall_err(exec_lua, 'return vim.w[WIN][0].testing'))

    eq({ hello = 'world' }, fn.luaeval 'vim.w.to_delete')
    exec_lua [[
    vim.w.to_delete = nil
    ]]
    eq(NIL, fn.luaeval 'vim.w.to_delete')

    exec_lua [[
      local counter = 0
      local function add_counter() counter = counter + 1 end
      local function get_counter() return counter end
      vim.w.AddCounter = add_counter
      vim.w.GetCounter = get_counter
      vim.w.fn = {add = add_counter, get = get_counter}
      vim.w.AddParens = function(s) return '(' .. s .. ')' end
    ]]

    eq(0, eval('w:GetCounter()'))
    eval('w:AddCounter()')
    eq(1, eval('w:GetCounter()'))
    eval('w:AddCounter()')
    eq(2, eval('w:GetCounter()'))
    exec_lua([[vim.w.AddCounter()]])
    eq(3, exec_lua([[return vim.w.GetCounter()]]))
    exec_lua([[vim.api.nvim_win_get_var(0, 'AddCounter')()]])
    eq(4, exec_lua([[return vim.api.nvim_win_get_var(0, 'GetCounter')()]]))
    exec_lua([[vim.w.fn.add()]])
    eq(5, exec_lua([[return vim.w.fn.get()]]))
    exec_lua([[vim.api.nvim_win_get_var(0, 'fn').add()]])
    eq(6, exec_lua([[return vim.api.nvim_win_get_var(0, 'fn').get()]]))
    eq('((foo))', eval([['foo'->w:AddParens()->w:AddParens()]]))

    exec_lua [[
      local counter = 0
      local function add_counter() counter = counter + 1 end
      local function get_counter() return counter end
      vim.api.nvim_win_set_var(0, 'AddCounter', add_counter)
      vim.api.nvim_win_set_var(0, 'GetCounter', get_counter)
      vim.api.nvim_win_set_var(0, 'fn', {add = add_counter, get = get_counter})
      vim.api.nvim_win_set_var(0, 'AddParens', function(s) return '(' .. s .. ')' end)
    ]]

    eq(0, eval('w:GetCounter()'))
    eval('w:AddCounter()')
    eq(1, eval('w:GetCounter()'))
    eval('w:AddCounter()')
    eq(2, eval('w:GetCounter()'))
    exec_lua([[vim.w.AddCounter()]])
    eq(3, exec_lua([[return vim.w.GetCounter()]]))
    exec_lua([[vim.api.nvim_win_get_var(0, 'AddCounter')()]])
    eq(4, exec_lua([[return vim.api.nvim_win_get_var(0, 'GetCounter')()]]))
    exec_lua([[vim.w.fn.add()]])
    eq(5, exec_lua([[return vim.w.fn.get()]]))
    exec_lua([[vim.api.nvim_win_get_var(0, 'fn').add()]])
    eq(6, exec_lua([[return vim.api.nvim_win_get_var(0, 'fn').get()]]))
    eq('((foo))', eval([['foo'->w:AddParens()->w:AddParens()]]))

    exec([[
      function Test()
      endfunction
      function s:Test()
      endfunction
      let w:Unknown_func = function('Test')
      let w:Unknown_script_func = function('s:Test')
    ]])
    eq(NIL, exec_lua([[return vim.w.Unknown_func]]))
    eq(NIL, exec_lua([[return vim.w.Unknown_script_func]]))

    exec_lua [[
    vim.cmd "vnew"
    ]]

    eq(NIL, fn.luaeval 'vim.w.testing')
    eq(NIL, fn.luaeval 'vim.w.other')
    eq(NIL, fn.luaeval 'vim.w.nonexistent')
  end)

  it('vim.t', function()
    exec_lua [[
    vim.api.nvim_tabpage_set_var(0, "testing", "hi")
    vim.api.nvim_tabpage_set_var(0, "other", 123)
    vim.api.nvim_tabpage_set_var(0, "to_delete", {hello="world"})
    ]]

    eq('hi', fn.luaeval 'vim.t.testing')
    eq(123, fn.luaeval 'vim.t.other')
    eq(NIL, fn.luaeval 'vim.t.nonexistent')
    eq('hi', fn.luaeval 'vim.t[0].testing')
    eq(123, fn.luaeval 'vim.t[0].other')
    eq(NIL, fn.luaeval 'vim.t[0].nonexistent')

    matches([[attempt to index .* nil value]], pcall_err(exec_lua, 'return vim.t[0][0].testing'))

    eq({ hello = 'world' }, fn.luaeval 'vim.t.to_delete')
    exec_lua [[
    vim.t.to_delete = nil
    ]]
    eq(NIL, fn.luaeval 'vim.t.to_delete')

    exec_lua [[
      local counter = 0
      local function add_counter() counter = counter + 1 end
      local function get_counter() return counter end
      vim.t.AddCounter = add_counter
      vim.t.GetCounter = get_counter
      vim.t.fn = {add = add_counter, get = get_counter}
      vim.t.AddParens = function(s) return '(' .. s .. ')' end
    ]]

    eq(0, eval('t:GetCounter()'))
    eval('t:AddCounter()')
    eq(1, eval('t:GetCounter()'))
    eval('t:AddCounter()')
    eq(2, eval('t:GetCounter()'))
    exec_lua([[vim.t.AddCounter()]])
    eq(3, exec_lua([[return vim.t.GetCounter()]]))
    exec_lua([[vim.api.nvim_tabpage_get_var(0, 'AddCounter')()]])
    eq(4, exec_lua([[return vim.api.nvim_tabpage_get_var(0, 'GetCounter')()]]))
    exec_lua([[vim.t.fn.add()]])
    eq(5, exec_lua([[return vim.t.fn.get()]]))
    exec_lua([[vim.api.nvim_tabpage_get_var(0, 'fn').add()]])
    eq(6, exec_lua([[return vim.api.nvim_tabpage_get_var(0, 'fn').get()]]))
    eq('((foo))', eval([['foo'->t:AddParens()->t:AddParens()]]))

    exec_lua [[
      local counter = 0
      local function add_counter() counter = counter + 1 end
      local function get_counter() return counter end
      vim.api.nvim_tabpage_set_var(0, 'AddCounter', add_counter)
      vim.api.nvim_tabpage_set_var(0, 'GetCounter', get_counter)
      vim.api.nvim_tabpage_set_var(0, 'fn', {add = add_counter, get = get_counter})
      vim.api.nvim_tabpage_set_var(0, 'AddParens', function(s) return '(' .. s .. ')' end)
    ]]

    eq(0, eval('t:GetCounter()'))
    eval('t:AddCounter()')
    eq(1, eval('t:GetCounter()'))
    eval('t:AddCounter()')
    eq(2, eval('t:GetCounter()'))
    exec_lua([[vim.t.AddCounter()]])
    eq(3, exec_lua([[return vim.t.GetCounter()]]))
    exec_lua([[vim.api.nvim_tabpage_get_var(0, 'AddCounter')()]])
    eq(4, exec_lua([[return vim.api.nvim_tabpage_get_var(0, 'GetCounter')()]]))
    exec_lua([[vim.t.fn.add()]])
    eq(5, exec_lua([[return vim.t.fn.get()]]))
    exec_lua([[vim.api.nvim_tabpage_get_var(0, 'fn').add()]])
    eq(6, exec_lua([[return vim.api.nvim_tabpage_get_var(0, 'fn').get()]]))
    eq('((foo))', eval([['foo'->t:AddParens()->t:AddParens()]]))

    exec_lua [[
    vim.cmd "tabnew"
    ]]

    eq(NIL, fn.luaeval 'vim.t.testing')
    eq(NIL, fn.luaeval 'vim.t.other')
    eq(NIL, fn.luaeval 'vim.t.nonexistent')
  end)

  it('vim.env', function()
    exec_lua([[vim.fn.setenv('A', 123)]])
    eq('123', fn.luaeval('vim.env.A'))
    exec_lua([[vim.env.A = 456]])
    eq('456', fn.luaeval('vim.env.A'))
    exec_lua([[vim.env.A = nil]])
    eq(NIL, fn.luaeval('vim.env.A'))

    eq(true, fn.luaeval('vim.env.B == nil'))

    command([[let $HOME = 'foo']])
    eq('foo', fn.expand('~'))
    eq('foo', fn.luaeval('vim.env.HOME'))
    exec_lua([[vim.env.HOME = nil]])
    eq('foo', fn.expand('~'))
    exec_lua([[vim.env.HOME = 'bar']])
    eq('bar', fn.expand('~'))
    eq('bar', fn.luaeval('vim.env.HOME'))
  end)

  it('vim.v', function()
    eq(fn.luaeval "vim.api.nvim_get_vvar('progpath')", fn.luaeval 'vim.v.progpath')
    eq(false, fn.luaeval "vim.v['false']")
    eq(NIL, fn.luaeval 'vim.v.null')
    matches([[attempt to index .* nil value]], pcall_err(exec_lua, 'return vim.v[0].progpath'))
    matches('Key is read%-only: count$', pcall_err(exec_lua, [[vim.v.count = 42]]))
    matches('Dict is locked$', pcall_err(exec_lua, [[vim.v.nosuchvar = 42]]))
    matches('Key is fixed: errmsg$', pcall_err(exec_lua, [[vim.v.errmsg = nil]]))
    exec_lua([[vim.v.errmsg = 'set by Lua']])
    eq('set by Lua', eval('v:errmsg'))
    exec_lua([[vim.v.errmsg = 42]])
    eq('42', eval('v:errmsg'))
    exec_lua([[vim.v.oldfiles = { 'one', 'two' }]])
    eq({ 'one', 'two' }, eval('v:oldfiles'))
    exec_lua([[vim.v.oldfiles = {}]])
    eq({}, eval('v:oldfiles'))
    matches(
      'Setting v:oldfiles to value with wrong type$',
      pcall_err(exec_lua, [[vim.v.oldfiles = 'a']])
    )
    eq({}, eval('v:oldfiles'))

    feed('i foo foo foo<Esc>0/foo<CR>')
    eq({ 1, 1 }, api.nvim_win_get_cursor(0))
    eq(1, eval('v:searchforward'))
    feed('n')
    eq({ 1, 5 }, api.nvim_win_get_cursor(0))
    exec_lua([[vim.v.searchforward = 0]])
    eq(0, eval('v:searchforward'))
    feed('n')
    eq({ 1, 1 }, api.nvim_win_get_cursor(0))
    exec_lua([[vim.v.searchforward = 1]])
    eq(1, eval('v:searchforward'))
    feed('n')
    eq({ 1, 5 }, api.nvim_win_get_cursor(0))

    local screen = Screen.new(60, 3)
    eq(1, eval('v:hlsearch'))
    screen:expect {
      grid = [[
       {10:foo} {10:^foo} {10:foo}                                                |
      {1:~                                                           }|
                                                                  |
    ]],
    }
    exec_lua([[vim.v.hlsearch = 0]])
    eq(0, eval('v:hlsearch'))
    screen:expect {
      grid = [[
       foo ^foo foo                                                |
      {1:~                                                           }|
                                                                  |
    ]],
    }
    exec_lua([[vim.v.hlsearch = 1]])
    eq(1, eval('v:hlsearch'))
    screen:expect {
      grid = [[
       {10:foo} {10:^foo} {10:foo}                                                |
      {1:~                                                           }|
                                                                  |
    ]],
    }
  end)

  it('vim.bo', function()
    eq('', fn.luaeval 'vim.bo.filetype')
    exec_lua [[
    vim.api.nvim_set_option_value("filetype", "markdown", {})
    BUF = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("modifiable", false, {buf = BUF})
    ]]
    eq(false, fn.luaeval 'vim.bo.modified')
    eq('markdown', fn.luaeval 'vim.bo.filetype')
    eq(false, fn.luaeval 'vim.bo[BUF].modifiable')
    exec_lua [[
    vim.bo.filetype = ''
    vim.bo[BUF].modifiable = true
    ]]
    eq('', fn.luaeval 'vim.bo.filetype')
    eq(true, fn.luaeval 'vim.bo[BUF].modifiable')
    matches("Unknown option 'nosuchopt'$", pcall_err(exec_lua, 'return vim.bo.nosuchopt'))
    matches('Expected Lua string$', pcall_err(exec_lua, 'return vim.bo[0][0].autoread'))
    matches('Invalid buffer id: %-1$', pcall_err(exec_lua, 'return vim.bo[-1].filetype'))
  end)

  it('vim.wo', function()
    exec_lua [[
    vim.api.nvim_set_option_value("cole", 2, {})
    vim.cmd "split"
    vim.api.nvim_set_option_value("cole", 2, {})
    ]]
    eq(2, fn.luaeval 'vim.wo.cole')
    exec_lua [[
    vim.wo.conceallevel = 0
    ]]
    eq(0, fn.luaeval 'vim.wo.cole')
    eq(0, fn.luaeval 'vim.wo[0].cole')
    eq(0, fn.luaeval 'vim.wo[1001].cole')
    matches("Unknown option 'notanopt'$", pcall_err(exec_lua, 'return vim.wo.notanopt'))
    matches('Invalid window id: %-1$', pcall_err(exec_lua, 'return vim.wo[-1].list'))
    eq(2, fn.luaeval 'vim.wo[1000].cole')
    exec_lua [[
    vim.wo[1000].cole = 0
    ]]
    eq(0, fn.luaeval 'vim.wo[1000].cole')

    -- Can handle global-local values
    exec_lua [[vim.o.scrolloff = 100]]
    exec_lua [[vim.wo.scrolloff = 200]]
    eq(200, fn.luaeval 'vim.wo.scrolloff')
    exec_lua [[vim.wo.scrolloff = -1]]
    eq(100, fn.luaeval 'vim.wo.scrolloff')
    exec_lua [[
    vim.wo[0][0].scrolloff = 200
    vim.cmd "enew"
    ]]
    eq(100, fn.luaeval 'vim.wo.scrolloff')

    matches('only bufnr=0 is supported', pcall_err(exec_lua, 'vim.wo[0][10].signcolumn = "no"'))

    matches('only bufnr=0 is supported', pcall_err(exec_lua, 'local a = vim.wo[0][10].signcolumn'))
  end)

  describe('vim.opt', function()
    -- TODO: We still need to write some tests for optlocal, opt and then getting the options
    --  Probably could also do some stuff with getting things from viml side as well to confirm behavior is the same.

    it('allows setting number values', function()
      local scrolloff = exec_lua [[
        vim.opt.scrolloff = 10
        return vim.o.scrolloff
      ]]
      eq(10, scrolloff)
    end)

    pending('handles STUPID window things', function()
      local result = exec_lua [[
        local result = {}

        table.insert(result, vim.api.nvim_get_option_value('scrolloff', {scope='global'}))
        table.insert(result, vim.api.nvim_get_option_value('scrolloff', {win=0}))

        return result
      ]]

      eq({}, result)
    end)

    it('allows setting tables', function()
      local wildignore = exec_lua [[
        vim.opt.wildignore = { 'hello', 'world' }
        return vim.o.wildignore
      ]]
      eq('hello,world', wildignore)
    end)

    it('allows setting tables with shortnames', function()
      local wildignore = exec_lua [[
        vim.opt.wig = { 'hello', 'world' }
        return vim.o.wildignore
      ]]
      eq('hello,world', wildignore)
    end)

    it('errors when you attempt to set string values to numeric options', function()
      local result = exec_lua [[
        return {
          pcall(function() vim.opt.textwidth = 'hello world' end)
        }
      ]]

      eq(false, result[1])
    end)

    it('errors when you attempt to setlocal a global value', function()
      local result = exec_lua [[
        return pcall(function() vim.opt_local.clipboard = "hello" end)
      ]]

      eq(false, result)
    end)

    it('allows you to set boolean values', function()
      eq(
        { true, false, true },
        exec_lua [[
        local results = {}

        vim.opt.autoindent = true
        table.insert(results, vim.bo.autoindent)

        vim.opt.autoindent = false
        table.insert(results, vim.bo.autoindent)

        vim.opt.autoindent = not vim.opt.autoindent:get()
        table.insert(results, vim.bo.autoindent)

        return results
      ]]
      )
    end)

    it('changes current buffer values and defaults for global local values', function()
      local result = exec_lua [[
        local result = {}

        vim.opt.makeprg = "global-local"
        table.insert(result, vim.go.makeprg)
        table.insert(result, vim.api.nvim_get_option_value('makeprg', {buf=0}))

        vim.opt_local.mp = "only-local"
        table.insert(result, vim.go.makeprg)
        table.insert(result, vim.api.nvim_get_option_value('makeprg', {buf=0}))

        vim.opt_global.makeprg = "only-global"
        table.insert(result, vim.go.makeprg)
        table.insert(result, vim.api.nvim_get_option_value('makeprg', {buf=0}))

        vim.opt.makeprg = "global-local"
        table.insert(result, vim.go.makeprg)
        table.insert(result, vim.api.nvim_get_option_value('makeprg', {buf=0}))
        return result
      ]]

      -- Set -> global & local
      eq('global-local', result[1])
      eq('', result[2])

      -- Setlocal -> only local
      eq('global-local', result[3])
      eq('only-local', result[4])

      -- Setglobal -> only global
      eq('only-global', result[5])
      eq('only-local', result[6])

      -- Set -> sets global value and resets local value
      eq('global-local', result[7])
      eq('', result[8])
    end)

    it('allows you to retrieve window opts even if they have not been set', function()
      local result = exec_lua [[
        local result = {}
        table.insert(result, vim.opt.number:get())
        table.insert(result, vim.opt_local.number:get())

        vim.opt_local.number = true
        table.insert(result, vim.opt.number:get())
        table.insert(result, vim.opt_local.number:get())

        return result
      ]]
      eq({ false, false, true, true }, result)
    end)

    it('allows all sorts of string manipulation', function()
      eq(
        { 'hello', 'hello world', 'start hello world' },
        exec_lua [[
        local results = {}

        vim.opt.makeprg = "hello"
        table.insert(results, vim.o.makeprg)

        vim.opt.makeprg = vim.opt.makeprg + " world"
        table.insert(results, vim.o.makeprg)

        vim.opt.makeprg = vim.opt.makeprg ^ "start "
        table.insert(results, vim.o.makeprg)

        return results
      ]]
      )
    end)

    describe('option:get()', function()
      it('works for boolean values', function()
        eq(
          false,
          exec_lua [[
          vim.opt.number = false
          return vim.opt.number:get()
        ]]
        )
      end)

      it('works for number values', function()
        local tabstop = exec_lua [[
          vim.opt.tabstop = 10
          return vim.opt.tabstop:get()
        ]]

        eq(10, tabstop)
      end)

      it('works for string values', function()
        eq(
          'hello world',
          exec_lua [[
          vim.opt.makeprg = "hello world"
          return vim.opt.makeprg:get()
        ]]
        )
      end)

      it('works for set type flaglists', function()
        local formatoptions = exec_lua [[
          vim.opt.formatoptions = 'tcro'
          return vim.opt.formatoptions:get()
        ]]

        eq(true, formatoptions.t)
        eq(true, not formatoptions.q)
      end)

      it('works for set type flaglists', function()
        local formatoptions = exec_lua [[
          vim.opt.formatoptions = { t = true, c = true, r = true, o = true }
          return vim.opt.formatoptions:get()
        ]]

        eq(true, formatoptions.t)
        eq(true, not formatoptions.q)
      end)

      it('works for array list type options', function()
        local wildignore = exec_lua [[
          vim.opt.wildignore = "*.c,*.o,__pycache__"
          return vim.opt.wildignore:get()
        ]]

        eq(3, #wildignore)
        eq('*.c', wildignore[1])
      end)

      it('works for options that are both commalist and flaglist', function()
        local result = exec_lua [[
          vim.opt.whichwrap = "b,s"
          return vim.opt.whichwrap:get()
        ]]

        eq({ b = true, s = true }, result)

        result = exec_lua [[
          vim.opt.whichwrap = { b = true, s = false, h = true }
          return vim.opt.whichwrap:get()
        ]]

        eq({ b = true, h = true }, result)
      end)

      it('works for key-value pair options', function()
        local listchars = exec_lua [[
          vim.opt.listchars = "tab:> ,space:_"
          return vim.opt.listchars:get()
        ]]

        eq({
          tab = '> ',
          space = '_',
        }, listchars)
      end)

      it('allows you to add numeric options', function()
        eq(
          16,
          exec_lua [[
          vim.opt.tabstop = 12
          vim.opt.tabstop = vim.opt.tabstop + 4
          return vim.bo.tabstop
        ]]
        )
      end)

      it('allows you to subtract numeric options', function()
        eq(
          2,
          exec_lua [[
          vim.opt.tabstop = 4
          vim.opt.tabstop = vim.opt.tabstop - 2
          return vim.bo.tabstop
        ]]
        )
      end)
    end)

    describe('key:value style options', function()
      it('handles dict style', function()
        local listchars = exec_lua [[
          vim.opt.listchars = {
            eol = "~",
            space = ".",
          }

          return vim.o.listchars
        ]]
        eq('eol:~,space:.', listchars)
      end)

      it('allows adding dict style', function()
        local listchars = exec_lua [[
          vim.opt.listchars = {
            eol = "~",
            space = ".",
          }

          vim.opt.listchars = vim.opt.listchars + { space = "-" }

          return vim.o.listchars
        ]]

        eq('eol:~,space:-', listchars)
      end)

      it('allows adding dict style', function()
        local listchars = exec_lua [[
          vim.opt.listchars = {
            eol = "~",
            space = ".",
          }
          vim.opt.listchars = vim.opt.listchars + { space = "-" } + { space = "_" }

          return vim.o.listchars
        ]]

        eq('eol:~,space:_', listchars)
      end)

      it('allows completely new keys', function()
        local listchars = exec_lua [[
          vim.opt.listchars = {
            eol = "~",
            space = ".",
          }
          vim.opt.listchars = vim.opt.listchars + { tab = ">>>" }

          return vim.o.listchars
        ]]

        eq('eol:~,space:.,tab:>>>', listchars)
      end)

      it('allows subtracting dict style', function()
        local listchars = exec_lua [[
          vim.opt.listchars = {
            eol = "~",
            space = ".",
          }
          vim.opt.listchars = vim.opt.listchars - "space"

          return vim.o.listchars
        ]]

        eq('eol:~', listchars)
      end)

      it('allows subtracting dict style', function()
        local listchars = exec_lua [[
          vim.opt.listchars = {
            eol = "~",
            space = ".",
          }
          vim.opt.listchars = vim.opt.listchars - "space" - "eol"

          return vim.o.listchars
        ]]

        eq('', listchars)
      end)

      it('allows subtracting dict style multiple times', function()
        local listchars = exec_lua [[
          vim.opt.listchars = {
            eol = "~",
            space = ".",
          }
          vim.opt.listchars = vim.opt.listchars - "space" - "space"

          return vim.o.listchars
        ]]

        eq('eol:~', listchars)
      end)

      it('allows adding a key:value string to a listchars', function()
        local listchars = exec_lua [[
          vim.opt.listchars = {
            eol = "~",
            space = ".",
          }
          vim.opt.listchars = vim.opt.listchars + "tab:>~"

          return vim.o.listchars
        ]]

        eq('eol:~,space:.,tab:>~', listchars)
      end)

      it('allows prepending a key:value string to a listchars', function()
        local listchars = exec_lua [[
          vim.opt.listchars = {
            eol = "~",
            space = ".",
          }
          vim.opt.listchars = vim.opt.listchars ^ "tab:>~"

          return vim.o.listchars
        ]]

        eq('eol:~,space:.,tab:>~', listchars)
      end)
    end)

    it('automatically sets when calling remove', function()
      eq(
        'foo,baz',
        exec_lua [[
        vim.opt.wildignore = "foo,bar,baz"
        vim.opt.wildignore:remove("bar")

        return vim.o.wildignore
      ]]
      )
    end)

    it('automatically sets when calling remove with a table', function()
      eq(
        'foo',
        exec_lua [[
        vim.opt.wildignore = "foo,bar,baz"
        vim.opt.wildignore:remove { "bar", "baz" }

        return vim.o.wildignore
      ]]
      )
    end)

    it('automatically sets when calling append', function()
      eq(
        'foo,bar,baz,bing',
        exec_lua [[
        vim.opt.wildignore = "foo,bar,baz"
        vim.opt.wildignore:append("bing")

        return vim.o.wildignore
      ]]
      )
    end)

    it('automatically sets when calling append with a table', function()
      eq(
        'foo,bar,baz,bing,zap',
        exec_lua [[
        vim.opt.wildignore = "foo,bar,baz"
        vim.opt.wildignore:append { "bing", "zap" }

        return vim.o.wildignore
      ]]
      )
    end)

    it('allows adding tables', function()
      local wildignore = exec_lua [[
        vim.opt.wildignore = 'foo'
        return vim.o.wildignore
      ]]
      eq('foo', wildignore)

      wildignore = exec_lua [[
        vim.opt.wildignore = vim.opt.wildignore + { 'bar', 'baz' }
        return vim.o.wildignore
      ]]
      eq('foo,bar,baz', wildignore)
    end)

    it('handles adding duplicates', function()
      local wildignore = exec_lua [[
        vim.opt.wildignore = 'foo'
        return vim.o.wildignore
      ]]
      eq('foo', wildignore)

      wildignore = exec_lua [[
        vim.opt.wildignore = vim.opt.wildignore + { 'bar', 'baz' }
        return vim.o.wildignore
      ]]
      eq('foo,bar,baz', wildignore)

      wildignore = exec_lua [[
        vim.opt.wildignore = vim.opt.wildignore + { 'bar', 'baz' }
        return vim.o.wildignore
      ]]
      eq('foo,bar,baz', wildignore)
    end)

    it('allows adding multiple times', function()
      local wildignore = exec_lua [[
        vim.opt.wildignore = 'foo'
        vim.opt.wildignore = vim.opt.wildignore + 'bar' + 'baz'
        return vim.o.wildignore
      ]]
      eq('foo,bar,baz', wildignore)
    end)

    it('removes values when you use minus', function()
      local wildignore = exec_lua [[
        vim.opt.wildignore = 'foo'
        return vim.o.wildignore
      ]]
      eq('foo', wildignore)

      wildignore = exec_lua [[
        vim.opt.wildignore = vim.opt.wildignore + { 'bar', 'baz' }
        return vim.o.wildignore
      ]]
      eq('foo,bar,baz', wildignore)

      wildignore = exec_lua [[
        vim.opt.wildignore = vim.opt.wildignore - 'bar'
        return vim.o.wildignore
      ]]
      eq('foo,baz', wildignore)
    end)

    it('prepends values when using ^', function()
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
      eq('super_first,first,foo', wildignore)
    end)

    it('does not remove duplicates from wildmode: #14708', function()
      local wildmode = exec_lua [[
        vim.opt.wildmode = {"full", "list", "full"}
        return vim.o.wildmode
      ]]

      eq('full,list,full', wildmode)
    end)

    describe('option types', function()
      it('allows to set option with numeric value', function()
        eq(
          4,
          exec_lua [[
          vim.opt.tabstop = 4
          return vim.bo.tabstop
        ]]
        )

        matches(
          "Invalid option type 'string' for 'tabstop'",
          pcall_err(
            exec_lua,
            [[
          vim.opt.tabstop = '4'
        ]]
          )
        )
        matches(
          "Invalid option type 'boolean' for 'tabstop'",
          pcall_err(
            exec_lua,
            [[
          vim.opt.tabstop = true
        ]]
          )
        )
        matches(
          "Invalid option type 'table' for 'tabstop'",
          pcall_err(
            exec_lua,
            [[
          vim.opt.tabstop = {4, 2}
        ]]
          )
        )
        matches(
          "Invalid option type 'function' for 'tabstop'",
          pcall_err(
            exec_lua,
            [[
          vim.opt.tabstop = function()
            return 4
          end
        ]]
          )
        )
      end)

      it('allows to set option with boolean value', function()
        eq(
          true,
          exec_lua [[
          vim.opt.undofile = true
          return vim.bo.undofile
        ]]
        )

        matches(
          "Invalid option type 'number' for 'undofile'",
          pcall_err(
            exec_lua,
            [[
          vim.opt.undofile = 0
        ]]
          )
        )
        matches(
          "Invalid option type 'table' for 'undofile'",
          pcall_err(
            exec_lua,
            [[
          vim.opt.undofile = {true}
        ]]
          )
        )
        matches(
          "Invalid option type 'string' for 'undofile'",
          pcall_err(
            exec_lua,
            [[
          vim.opt.undofile = 'true'
        ]]
          )
        )
        matches(
          "Invalid option type 'function' for 'undofile'",
          pcall_err(
            exec_lua,
            [[
          vim.opt.undofile = function()
            return true
          end
        ]]
          )
        )
      end)

      it('allows to set option with array or string value', function()
        eq(
          'indent,eol,start',
          exec_lua [[
          vim.opt.backspace = {'indent','eol','start'}
          return vim.go.backspace
        ]]
        )
        eq(
          'indent,eol,start',
          exec_lua [[
          vim.opt.backspace = 'indent,eol,start'
          return vim.go.backspace
        ]]
        )

        matches(
          "Invalid option type 'boolean' for 'backspace'",
          pcall_err(
            exec_lua,
            [[
          vim.opt.backspace = true
        ]]
          )
        )
        matches(
          "Invalid option type 'number' for 'backspace'",
          pcall_err(
            exec_lua,
            [[
          vim.opt.backspace = 2
        ]]
          )
        )
        matches(
          "Invalid option type 'function' for 'backspace'",
          pcall_err(
            exec_lua,
            [[
          vim.opt.backspace = function()
            return 'indent,eol,start'
          end
        ]]
          )
        )
      end)

      it('allows set option with map or string value', function()
        eq(
          'eol:~,space:.',
          exec_lua [[
          vim.opt.listchars = {
            eol = "~",
            space = ".",
          }
          return vim.o.listchars
        ]]
        )
        eq(
          'eol:~,space:.,tab:>~',
          exec_lua [[
          vim.opt.listchars = "eol:~,space:.,tab:>~"
          return vim.o.listchars
        ]]
        )

        matches(
          "Invalid option type 'boolean' for 'listchars'",
          pcall_err(
            exec_lua,
            [[
          vim.opt.listchars = true
        ]]
          )
        )
        matches(
          "Invalid option type 'number' for 'listchars'",
          pcall_err(
            exec_lua,
            [[
          vim.opt.listchars = 2
        ]]
          )
        )
        matches(
          "Invalid option type 'function' for 'listchars'",
          pcall_err(
            exec_lua,
            [[
          vim.opt.listchars = function()
            return "eol:~,space:.,tab:>~"
          end
        ]]
          )
        )
      end)

      it('allows set option with set or string value', function()
        local ww = exec_lua [[
          vim.opt.whichwrap = {
            b = true,
            s = 1,
          }
          return vim.go.whichwrap
        ]]

        eq('b,s', ww)
        eq(
          'b,s,<,>,[,]',
          exec_lua [[
          vim.opt.whichwrap = "b,s,<,>,[,]"
          return vim.go.whichwrap
        ]]
        )

        matches(
          "Invalid option type 'boolean' for 'whichwrap'",
          pcall_err(
            exec_lua,
            [[
          vim.opt.whichwrap = true
        ]]
          )
        )
        matches(
          "Invalid option type 'number' for 'whichwrap'",
          pcall_err(
            exec_lua,
            [[
          vim.opt.whichwrap = 2
        ]]
          )
        )
        matches(
          "Invalid option type 'function' for 'whichwrap'",
          pcall_err(
            exec_lua,
            [[
          vim.opt.whichwrap = function()
            return "b,s,<,>,[,]"
          end
        ]]
          )
        )
      end)
    end)

    -- isfname=a,b,c,,,d,e,f
    it('can handle isfname ,,,', function()
      local result = exec_lua [[
        vim.opt.isfname = "a,b,,,c"
        return { vim.opt.isfname:get(), vim.go.isfname }
      ]]

      eq({ { ',', 'a', 'b', 'c' }, 'a,b,,,c' }, result)
    end)

    -- isfname=a,b,c,^,,def
    it('can handle isfname ,^,,', function()
      local result = exec_lua [[
        vim.opt.isfname = "a,b,^,,c"
        return { vim.opt.isfname:get(), vim.go.isfname }
      ]]

      eq({ { '^,', 'a', 'b', 'c' }, 'a,b,^,,c' }, result)
    end)

    describe('https://github.com/neovim/neovim/issues/14828', function()
      it('gives empty list when item is empty:array', function()
        eq(
          {},
          exec_lua [[
          vim.cmd("set wildignore=")
          return vim.opt.wildignore:get()
        ]]
        )

        eq(
          {},
          exec_lua [[
          vim.opt.wildignore = {}
          return vim.opt.wildignore:get()
        ]]
        )
      end)

      it('gives empty list when item is empty:set', function()
        eq(
          {},
          exec_lua [[
          vim.cmd("set formatoptions=")
          return vim.opt.formatoptions:get()
        ]]
        )

        eq(
          {},
          exec_lua [[
          vim.opt.formatoptions = {}
          return vim.opt.formatoptions:get()
        ]]
        )
      end)

      it('does not append to empty item', function()
        eq(
          { '*.foo', '*.bar' },
          exec_lua [[
          vim.opt.wildignore = {}
          vim.opt.wildignore:append { "*.foo", "*.bar" }

          return vim.opt.wildignore:get()
        ]]
        )
      end)

      it('does not prepend to empty item', function()
        eq(
          { '*.foo', '*.bar' },
          exec_lua [[
          vim.opt.wildignore = {}
          vim.opt.wildignore:prepend { "*.foo", "*.bar" }

          return vim.opt.wildignore:get()
        ]]
        )
      end)

      it('append to empty set', function()
        eq(
          { t = true },
          exec_lua [[
          vim.opt.formatoptions = {}
          vim.opt.formatoptions:append("t")

          return vim.opt.formatoptions:get()
        ]]
        )
      end)

      it('prepend to empty set', function()
        eq(
          { t = true },
          exec_lua [[
          vim.opt.formatoptions = {}
          vim.opt.formatoptions:prepend("t")

          return vim.opt.formatoptions:get()
        ]]
        )
      end)
    end)
  end) -- vim.opt

  describe('vim.opt_local', function()
    it('appends into global value when changing local option value', function()
      eq(
        { 'foo,bar,baz,qux' },
        exec_lua [[
        local result = {}

        vim.opt.tags = "foo,bar"
        vim.opt_local.tags:append("baz")
        vim.opt_local.tags:append("qux")

        table.insert(result, vim.bo.tags)

        return result
      ]]
      )
    end)
  end)

  describe('vim.opt_global', function()
    it('gets current global option value', function()
      eq(
        { 'yes' },
        exec_lua [[
        local result = {}

        vim.cmd "setglobal signcolumn=yes"
        table.insert(result, vim.opt_global.signcolumn:get())

        return result
      ]]
      )
    end)
  end)

  it('vim.cmd', function()
    exec_lua [[
    vim.cmd "autocmd BufNew * ++once lua BUF = vim.fn.expand('<abuf>')"
    vim.cmd "new"
    ]]
    eq('2', fn.luaeval 'BUF')
    eq(2, fn.luaeval '#vim.api.nvim_list_bufs()')

    -- vim.cmd can be indexed with a command name
    exec_lua [[
      vim.cmd.let 'g:var = 2'
    ]]

    eq(2, fn.luaeval 'vim.g.var')
  end)

  it('vim.regex', function()
    exec_lua [[
      re1 = vim.regex"ab\\+c"
      vim.cmd "set nomagic ignorecase"
      re2 = vim.regex"xYz"
    ]]
    eq({}, exec_lua [[return {re1:match_str("x ac")}]])
    eq({ 3, 7 }, exec_lua [[return {re1:match_str("ac abbc")}]])

    api.nvim_buf_set_lines(0, 0, -1, true, { 'yy', 'abc abbc' })
    eq({}, exec_lua [[return {re1:match_line(0, 0)}]])
    eq({ 0, 3 }, exec_lua [[return {re1:match_line(0, 1)}]])
    eq({ 3, 7 }, exec_lua [[return {re1:match_line(0, 1, 1)}]])
    eq({ 3, 7 }, exec_lua [[return {re1:match_line(0, 1, 1, 8)}]])
    eq({}, exec_lua [[return {re1:match_line(0, 1, 1, 7)}]])
    eq({ 0, 3 }, exec_lua [[return {re1:match_line(0, 1, 0, 7)}]])

    -- vim.regex() error inside :silent! should not crash. #20546
    command([[silent! lua vim.regex('\\z')]])
    assert_alive()
  end)

  it('vim.defer_fn', function()
    eq(
      false,
      exec_lua [[
      vim.g.test = false
      vim.defer_fn(function() vim.g.test = true end, 150)
      return vim.g.test
    ]]
    )
    exec_lua [[vim.wait(1000, function() return vim.g.test end)]]
    eq(true, exec_lua [[return vim.g.test]])
  end)

  describe('vim.region', function()
    it('charwise', function()
      insert(dedent([[
      text tααt tααt text
      text tαxt txtα tex
      text tαxt tαxt
      ]]))
      eq({ 5, 13 }, exec_lua [[ return vim.region(0,{0,5},{0,13},'v',false)[0] ]])
      eq({ 5, 15 }, exec_lua [[ return vim.region(0,{0,5},{0,13},'v',true)[0] ]])
      eq({ 5, 15 }, exec_lua [[ return vim.region(0,{0,5},{0,14},'v',true)[0] ]])
      eq({ 5, 15 }, exec_lua [[ return vim.region(0,{0,5},{0,15},'v',false)[0] ]])
      eq({ 5, 17 }, exec_lua [[ return vim.region(0,{0,5},{0,15},'v',true)[0] ]])
      eq({ 5, 17 }, exec_lua [[ return vim.region(0,{0,5},{0,16},'v',true)[0] ]])
      eq({ 5, 17 }, exec_lua [[ return vim.region(0,{0,5},{0,17},'v',false)[0] ]])
      eq({ 5, 18 }, exec_lua [[ return vim.region(0,{0,5},{0,17},'v',true)[0] ]])
    end)
    it('blockwise', function()
      insert([[αα]])
      eq({ 0, 5 }, exec_lua [[ return vim.region(0,{0,0},{0,4},'3',true)[0] ]])
    end)
    it('linewise', function()
      insert(dedent([[
      text tααt tααt text
      text tαxt txtα tex
      text tαxt tαxt
      ]]))
      eq({ 0, -1 }, exec_lua [[ return vim.region(0,{1,5},{1,14},'V',true)[1] ]])
    end)
    it('getpos() input', function()
      insert('getpos')
      eq({ 0, 6 }, exec_lua [[ return vim.region(0,{0,0},'.','v',true)[0] ]])
    end)
  end)

  describe('vim.on_key', function()
    it('tracks Unicode input', function()
      insert([[hello world ]])

      exec_lua [[
        keys = {}
        typed = {}

        vim.on_key(function(buf, typed_buf)
          if buf:byte() == 27 then
            buf = "<ESC>"
          end
          if typed_buf:byte() == 27 then
            typed_buf = "<ESC>"
          end

          table.insert(keys, buf)
          table.insert(typed, typed_buf)
        end)
      ]]

      insert([[next 🤦 lines å …]])

      -- It has escape in the keys pressed
      eq('inext 🤦 lines å …<ESC>', exec_lua [[return table.concat(keys, '')]])
      eq('inext 🤦 lines å …<ESC>', exec_lua [[return table.concat(typed, '')]])
    end)

    it('tracks input with modifiers', function()
      exec_lua [[
        keys = {}
        typed = {}

        vim.on_key(function(buf, typed_buf)
          table.insert(keys, vim.fn.keytrans(buf))
          table.insert(typed, vim.fn.keytrans(typed_buf))
        end)
      ]]

      feed([[i<C-V><C-;><C-V><C-…><Esc>]])

      eq('i<C-V><C-;><C-V><C-…><Esc>', exec_lua [[return table.concat(keys, '')]])
      eq('i<C-V><C-;><C-V><C-…><Esc>', exec_lua [[return table.concat(typed, '')]])
    end)

    it('works with character find and Select mode', function()
      insert('12345')

      exec_lua [[
        typed = {}

        vim.cmd('snoremap # @')

        vim.on_key(function(buf, typed_buf)
          table.insert(typed, vim.fn.keytrans(typed_buf))
        end)
      ]]

      feed('F3gHβγδεζ<Esc>gH…<Esc>gH#$%^')
      eq('F3gHβγδεζ<Esc>gH…<Esc>gH#$%^', exec_lua [[return table.concat(typed, '')]])
    end)

    it('allows removing on_key listeners', function()
      -- Create some unused namespaces
      api.nvim_create_namespace('unused1')
      api.nvim_create_namespace('unused2')
      api.nvim_create_namespace('unused3')
      api.nvim_create_namespace('unused4')

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

    it('skips any function that caused an error and shows stacktrace', function()
      insert([[hello world]])

      exec_lua [[
        local function ErrF2()
          error("Dumb Error")
        end
        local function ErrF1()
          ErrF2()
        end

        keys = {}

        return vim.on_key(function(buf)
          if buf:byte() == 27 then
            buf = "<ESC>"
          end

          table.insert(keys, buf)

          if buf == 'l' then
            ErrF1()
          end
        end)
      ]]

      insert([[next lines]])
      insert([[more lines]])

      -- Only the first letter gets added. After that we remove the callback
      eq('inext l', exec_lua [[ return table.concat(keys, '') ]])

      local errmsg = api.nvim_get_vvar('errmsg')
      matches(
        [[
^vim%.on%_key%(%) callbacks:.*
With ns%_id %d+: .*: Dumb Error
stack traceback:
.*: in function 'error'
.*: in function 'ErrF2'
.*: in function 'ErrF1'
.*]],
        errmsg
      )
    end)

    it('argument 1 is keys after mapping, argument 2 is typed keys', function()
      exec_lua [[
        keys = {}
        typed = {}

        vim.cmd("inoremap hello world")

        vim.on_key(function(buf, typed_buf)
          if buf:byte() == 27 then
            buf = "<ESC>"
          end
          if typed_buf:byte() == 27 then
            typed_buf = "<ESC>"
          end

          table.insert(keys, buf)
          table.insert(typed, typed_buf)
        end)
      ]]
      insert('hello')

      eq('iworld<ESC>', exec_lua [[return table.concat(keys, '')]])
      eq('ihello<ESC>', exec_lua [[return table.concat(typed, '')]])
    end)

    it('can call vim.fn functions on Ctrl-C #17273', function()
      exec_lua([[
        _G.ctrl_c_cmdtype = ''

        vim.on_key(function(c)
          if c == '\3' then
            _G.ctrl_c_cmdtype = vim.fn.getcmdtype()
          end
        end)
      ]])
      feed('/')
      poke_eventloop() -- This is needed because Ctrl-C flushes input
      feed('<C-C>')
      eq('/', exec_lua([[return _G.ctrl_c_cmdtype]]))
    end)

    it('callback is not invoked recursively #30752', function()
      local screen = Screen.new(60, 10)
      exec_lua([[
        vim.on_key(function(key, typed)
          vim.api.nvim_echo({
            { 'key_cb\n' },
            { ("KEYCB: key '%s', typed '%s'\n"):format(key, typed) },
          }, false, {})
        end)
      ]])
      feed('^')
      screen:expect([[
                                                                    |
        {1:~                                                           }|*5
        {3:                                                            }|
        key_cb                                                      |
        KEYCB: key '^', typed '^'                                   |
        {6:Press ENTER or type command to continue}^                     |
      ]])
      feed('<C-C>')
      screen:expect([[
                                                                    |
        {1:~                                                           }|*3
        {3:                                                            }|
        key_cb                                                      |
        KEYCB: key '^', typed '^'                                   |
        key_cb                                                      |
        KEYCB: key '{18:^C}', typed '{18:^C}'                                 |
        {6:Press ENTER or type command to continue}^                     |
      ]])
      feed('<C-C>')
      screen:expect([[
        ^                                                            |
        {1:~                                                           }|*8
                                                                    |
      ]])
    end)

    it('can discard input', function()
      -- discard every other normal 'x' command
      exec_lua [[
        n_key = 0

        vim.on_key(function(buf, typed_buf)
          if typed_buf == 'x' then
            n_key = n_key + 1
          end
          return (n_key % 2 == 0) and "" or nil
        end)
      ]]

      api.nvim_buf_set_lines(0, 0, -1, true, { '54321' })

      feed('x')
      expect('4321')
      feed('x')
      expect('4321')
      feed('x')
      expect('321')
      feed('x')
      expect('321')
    end)

    it('callback invalid return', function()
      -- second key produces an error which removes the callback
      exec_lua [[
        n_call = 0

        vim.on_key(function(buf, typed_buf)
          if typed_buf == 'x' then
            n_call = n_call + 1
          end
          return n_call >= 2 and '!' or nil
        end)
      ]]

      api.nvim_buf_set_lines(0, 0, -1, true, { '54321' })

      feed('x')
      eq(1, exec_lua [[ return n_call ]])
      eq(1, exec_lua [[ return vim.on_key(nil, nil) ]])
      eq('', eval('v:errmsg'))
      feed('x')
      eq(2, exec_lua [[ return n_call ]])
      matches('return string must be empty', eval('v:errmsg'))
      command('let v:errmsg = ""')

      eq(0, exec_lua [[ return vim.on_key(nil, nil) ]])

      feed('x')
      eq(2, exec_lua [[ return n_call ]])
      expect('21')
      eq('', eval('v:errmsg'))
    end)
  end)

  describe('vim.wait', function()
    before_each(function()
      exec_lua [[
        -- high precision timer
        get_time = function()
          return vim.fn.reltimefloat(vim.fn.reltime())
        end
      ]]
    end)

    it('runs from lua', function()
      exec_lua [[vim.wait(100, function() return true end)]]
    end)

    it('waits the expected time if false', function()
      eq(
        { time = true, wait_result = { false, -1 } },
        exec_lua [[
        start_time = get_time()
        wait_succeed, wait_fail_val = vim.wait(200, function() return false end)

        return {
          -- 150ms waiting or more results in true. Flaky tests are bad.
          time = (start_time + 0.15) < get_time(),
          wait_result = {wait_succeed, wait_fail_val}
        }
      ]]
      )
    end)

    it('does not block other events', function()
      eq(
        { time = true, wait_result = true },
        exec_lua [[
        start_time = get_time()

        vim.g.timer_result = false
        timer = vim.uv.new_timer()
        timer:start(100, 0, vim.schedule_wrap(function()
          vim.g.timer_result = true
        end))

        -- Would wait ten seconds if results blocked.
        wait_result = vim.wait(10000, function() return vim.g.timer_result end)

        timer:close()

        return {
          time = (start_time + 5) > get_time(),
          wait_result = wait_result,
        }
      ]]
      )
    end)

    it('does not process non-fast events when commanded', function()
      eq(
        { wait_result = false },
        exec_lua [[
        start_time = get_time()

        vim.g.timer_result = false
        timer = vim.uv.new_timer()
        timer:start(100, 0, vim.schedule_wrap(function()
          vim.g.timer_result = true
        end))

        wait_result = vim.wait(300, function() return vim.g.timer_result end, nil, true)

        timer:close()

        return {
          wait_result = wait_result,
        }
      ]]
      )
    end)

    it('works with vim.defer_fn', function()
      eq(
        { time = true, wait_result = true },
        exec_lua [[
        start_time = get_time()

        vim.defer_fn(function() vim.g.timer_result = true end, 100)
        wait_result = vim.wait(10000, function() return vim.g.timer_result end)

        return {
          time = (start_time + 5) > get_time(),
          wait_result = wait_result,
        }
      ]]
      )
    end)

    it('does not crash when callback errors', function()
      local result = exec_lua [[
        return {pcall(function() vim.wait(1000, function() error("As Expected") end) end)}
      ]]
      eq({ false, '[string "<nvim>"]:1: As Expected' }, { result[1], remove_trace(result[2]) })
    end)

    it('if callback is passed, it must be a function', function()
      eq(
        { false, 'vim.wait: if passed, condition must be a function' },
        exec_lua [[
        return {pcall(function() vim.wait(1000, 13) end)}
      ]]
      )
    end)

    it('allows waiting with no callback, explicit', function()
      eq(
        true,
        exec_lua [[
        local start_time = vim.uv.hrtime()
        vim.wait(50, nil)
        return vim.uv.hrtime() - start_time > 25000
      ]]
      )
    end)

    it('allows waiting with no callback, implicit', function()
      eq(
        true,
        exec_lua [[
        local start_time = vim.uv.hrtime()
        vim.wait(50)
        return vim.uv.hrtime() - start_time > 25000
      ]]
      )
    end)

    it('calls callbacks exactly once if they return true immediately', function()
      eq(
        true,
        exec_lua [[
        vim.g.wait_count = 0
        vim.wait(1000, function()
          vim.g.wait_count = vim.g.wait_count + 1
          return true
        end, 20)
        return vim.g.wait_count == 1
      ]]
      )
    end)

    it('calls callbacks few times with large `interval`', function()
      eq(
        true,
        exec_lua [[
        vim.g.wait_count = 0
        vim.wait(50, function() vim.g.wait_count = vim.g.wait_count + 1 end, 200)
        return vim.g.wait_count < 5
      ]]
      )
    end)

    it('plays nice with `not` when fails', function()
      eq(
        true,
        exec_lua [[
        if not vim.wait(50, function() end) then
          return true
        end

        return false
      ]]
      )
    end)

    it('plays nice with `if` when success', function()
      eq(
        true,
        exec_lua [[
        if vim.wait(50, function() return true end) then
          return true
        end

        return false
      ]]
      )
    end)

    it('returns immediately with false if timeout is 0', function()
      eq(
        { false, -1 },
        exec_lua [[
        return {
          vim.wait(0, function() return false end)
        }
      ]]
      )
    end)

    it('works with tables with __call', function()
      eq(
        true,
        exec_lua [[
        local t = setmetatable({}, {__call = function(...) return true end})
        return vim.wait(100, t, 10)
      ]]
      )
    end)

    it('works with tables with __call that change', function()
      eq(
        true,
        exec_lua [[
        local t = {count = 0}
        setmetatable(t, {
          __call = function()
            t.count = t.count + 1
            return t.count > 3
          end
        })

        return vim.wait(1000, t, 10)
      ]]
      )
    end)

    it('fails with negative intervals', function()
      local pcall_result = exec_lua [[
        return pcall(function() vim.wait(1000, function() return false end, -1) end)
      ]]

      eq(false, pcall_result)
    end)

    it('fails with weird intervals', function()
      local pcall_result = exec_lua [[
        return pcall(function() vim.wait(1000, function() return false end, 'a string value') end)
      ]]

      eq(false, pcall_result)
    end)

    describe('returns -2 when interrupted', function()
      before_each(function()
        local channel = api.nvim_get_chan_info(0).id
        api.nvim_set_var('channel', channel)
      end)

      it('without callback', function()
        exec_lua([[
          function _G.Wait()
            vim.rpcnotify(vim.g.channel, 'ready')
            local _, interrupted = vim.wait(4000)
            vim.rpcnotify(vim.g.channel, 'wait', interrupted)
          end
        ]])
        feed(':lua _G.Wait()<CR>')
        eq({ 'notification', 'ready', {} }, next_msg(500))
        feed('<C-C>')
        eq({ 'notification', 'wait', { -2 } }, next_msg(500))
      end)

      it('with callback', function()
        exec_lua([[
          function _G.Wait()
            vim.rpcnotify(vim.g.channel, 'ready')
            local _, interrupted = vim.wait(4000, function() end)
            vim.rpcnotify(vim.g.channel, 'wait', interrupted)
          end
        ]])
        feed(':lua _G.Wait()<CR>')
        eq({ 'notification', 'ready', {} }, next_msg(500))
        feed('<C-C>')
        eq({ 'notification', 'wait', { -2 } }, next_msg(500))
      end)
    end)

    it('fails in fast callbacks #26122', function()
      local screen = Screen.new(80, 10)
      exec_lua([[
        local timer = vim.uv.new_timer()
        timer:start(0, 0, function()
          timer:close()
          vim.wait(100, function() end)
        end)
      ]])
      screen:expect({
        any = pesc('E5560: vim.wait must not be called in a fast event context'),
      })
      feed('<CR>')
      assert_alive()
    end)
  end)

  it('vim.notify_once', function()
    local screen = Screen.new(60, 5)
    screen:expect {
      grid = [[
      ^                                                            |
      {1:~                                                           }|*3
                                                                  |
    ]],
    }
    exec_lua [[vim.notify_once("I'll only tell you this once...", vim.log.levels.WARN)]]
    screen:expect {
      grid = [[
      ^                                                            |
      {1:~                                                           }|*3
      {19:I'll only tell you this once...}                             |
    ]],
    }
    feed('<C-l>')
    screen:expect {
      grid = [[
      ^                                                            |
      {1:~                                                           }|*3
                                                                  |
    ]],
    }
    exec_lua [[vim.notify_once("I'll only tell you this once...")]]
    screen:expect_unchanged()
  end)

  describe('vim.schedule_wrap', function()
    it('preserves argument lists', function()
      exec_lua [[
        local fun = vim.schedule_wrap(function(kling, klang, klonk)
          vim.rpcnotify(1, 'mayday_mayday', {a=kling, b=klang, c=klonk})
        end)
        fun("BOB", nil, "MIKE")
      ]]
      eq({ 'notification', 'mayday_mayday', { { a = 'BOB', c = 'MIKE' } } }, next_msg())

      -- let's gooooo
      exec_lua [[
        vim.schedule_wrap(function(...) vim.rpcnotify(1, 'boogalo', select('#', ...)) end)(nil,nil,nil,nil)
      ]]
      eq({ 'notification', 'boogalo', { 4 } }, next_msg())
    end)
  end)

  describe('vim.api.nvim_buf_call', function()
    it('can access buf options', function()
      local buf1 = api.nvim_get_current_buf()
      local buf2 = exec_lua [[
        buf2 = vim.api.nvim_create_buf(false, true)
        return buf2
      ]]

      eq(false, api.nvim_get_option_value('autoindent', { buf = buf1 }))
      eq(false, api.nvim_get_option_value('autoindent', { buf = buf2 }))

      local val = exec_lua [[
        return vim.api.nvim_buf_call(buf2, function()
          vim.cmd "set autoindent"
          return vim.api.nvim_get_current_buf()
        end)
      ]]

      eq(false, api.nvim_get_option_value('autoindent', { buf = buf1 }))
      eq(true, api.nvim_get_option_value('autoindent', { buf = buf2 }))
      eq(buf1, api.nvim_get_current_buf())
      eq(buf2, val)
    end)

    it('does not cause ml_get errors with invalid visual selection', function()
      -- Should be fixed by vim-patch:8.2.4028.
      exec_lua [[
        local api = vim.api
        local t = function(s) return api.nvim_replace_termcodes(s, true, true, true) end
        api.nvim_buf_set_lines(0, 0, -1, true, {"a", "b", "c"})
        api.nvim_feedkeys(t "G<C-V>", "txn", false)
        api.nvim_buf_call(api.nvim_create_buf(false, true), function() vim.cmd "redraw" end)
      ]]
    end)

    it('can be nested crazily with hidden buffers', function()
      eq(
        true,
        exec_lua([[
        local function scratch_buf_call(fn)
          local buf = vim.api.nvim_create_buf(false, true)
          vim.api.nvim_set_option_value('cindent', true, {buf = buf})
          return vim.api.nvim_buf_call(buf, function()
            return vim.api.nvim_get_current_buf() == buf
              and vim.api.nvim_get_option_value('cindent', {buf = buf})
              and fn()
          end) and vim.api.nvim_buf_delete(buf, {}) == nil
        end

        return scratch_buf_call(function()
          return scratch_buf_call(function()
            return scratch_buf_call(function()
              return scratch_buf_call(function()
                return scratch_buf_call(function()
                  return scratch_buf_call(function()
                    return scratch_buf_call(function()
                      return scratch_buf_call(function()
                        return scratch_buf_call(function()
                          return scratch_buf_call(function()
                            return scratch_buf_call(function()
                              return scratch_buf_call(function()
                                return true
                              end)
                            end)
                          end)
                        end)
                      end)
                    end)
                  end)
                end)
              end)
            end)
          end)
        end)
      ]])
      )
    end)

    it('can return values by reference', function()
      eq(
        { 4, 7 },
        exec_lua [[
        local val = {4, 10}
        local ref = vim.api.nvim_buf_call(0, function() return val end)
        ref[2] = 7
        return val
      ]]
      )
    end)
  end)

  describe('vim.api.nvim_win_call', function()
    it('can access window options', function()
      command('vsplit')
      local win1 = api.nvim_get_current_win()
      command('wincmd w')
      local win2 = exec_lua [[
        win2 = vim.api.nvim_get_current_win()
        return win2
      ]]
      command('wincmd p')

      eq('', api.nvim_get_option_value('winhighlight', { win = win1 }))
      eq('', api.nvim_get_option_value('winhighlight', { win = win2 }))

      local val = exec_lua [[
        return vim.api.nvim_win_call(win2, function()
          vim.cmd "setlocal winhighlight=Normal:Normal"
          return vim.api.nvim_get_current_win()
        end)
      ]]

      eq('', api.nvim_get_option_value('winhighlight', { win = win1 }))
      eq('Normal:Normal', api.nvim_get_option_value('winhighlight', { win = win2 }))
      eq(win1, api.nvim_get_current_win())
      eq(win2, val)
    end)

    it('failure modes', function()
      matches(
        'nvim_exec2%(%), line 1: Vim:E492: Not an editor command: fooooo',
        pcall_err(exec_lua, [[vim.api.nvim_win_call(0, function() vim.cmd 'fooooo' end)]])
      )
      eq(
        'Lua: [string "<nvim>"]:0: fooooo',
        pcall_err(exec_lua, [[vim.api.nvim_win_call(0, function() error('fooooo') end)]])
      )
    end)

    it('does not cause ml_get errors with invalid visual selection', function()
      -- Add lines to the current buffer and make another window looking into an empty buffer.
      exec_lua [[
        _G.api = vim.api
        _G.t = function(s) return api.nvim_replace_termcodes(s, true, true, true) end
        _G.win_lines = api.nvim_get_current_win()
        vim.cmd "new"
        _G.win_empty = api.nvim_get_current_win()
        api.nvim_set_current_win(win_lines)
        api.nvim_buf_set_lines(0, 0, -1, true, {"a", "b", "c"})
      ]]

      -- Start Visual in current window, redraw in other window with fewer lines.
      -- Should be fixed by vim-patch:8.2.4018.
      exec_lua [[
        api.nvim_feedkeys(t "G<C-V>", "txn", false)
        api.nvim_win_call(win_empty, function() vim.cmd "redraw" end)
      ]]

      -- Start Visual in current window, extend it in other window with more lines.
      -- Fixed for win_execute by vim-patch:8.2.4026, but nvim_win_call should also not be affected.
      exec_lua [[
        api.nvim_feedkeys(t "<Esc>gg", "txn", false)
        api.nvim_set_current_win(win_empty)
        api.nvim_feedkeys(t "gg<C-V>", "txn", false)
        api.nvim_win_call(win_lines, function() api.nvim_feedkeys(t "G<C-V>", "txn", false) end)
        vim.cmd "redraw"
      ]]
    end)

    it('updates ruler if cursor moved', function()
      -- Fixed for win_execute in vim-patch:8.1.2124, but should've applied to nvim_win_call too!
      local screen = Screen.new(30, 5)
      exec_lua [[
        _G.api = vim.api
        vim.opt.ruler = true
        local lines = {}
        for i = 0, 499 do lines[#lines + 1] = tostring(i) end
        api.nvim_buf_set_lines(0, 0, -1, true, lines)
        api.nvim_win_set_cursor(0, {20, 0})
        vim.cmd "split"
        _G.win = api.nvim_get_current_win()
        vim.cmd "wincmd w | redraw"
      ]]
      screen:expect [[
        19                            |
        {2:< Name] [+] 20,1            3%}|
        ^19                            |
        {3:< Name] [+] 20,1            3%}|
                                      |
      ]]
      exec_lua [[
        api.nvim_win_call(win, function() api.nvim_win_set_cursor(0, {100, 0}) end)
        vim.cmd "redraw"
      ]]
      screen:expect [[
        99                            |
        {2:< Name] [+] 100,1          19%}|
        ^19                            |
        {3:< Name] [+] 20,1            3%}|
                                      |
      ]]
    end)

    it('can return values by reference', function()
      eq(
        { 7, 10 },
        exec_lua [[
        local val = {4, 10}
        local ref = vim.api.nvim_win_call(0, function() return val end)
        ref[1] = 7
        return val
      ]]
      )
    end)

    it('layout in current tabpage does not affect windows in others', function()
      command('tab split')
      local t2_move_win = api.nvim_get_current_win()
      command('vsplit')
      local t2_other_win = api.nvim_get_current_win()
      command('tabprevious')
      matches('E36: Not enough room$', pcall_err(command, 'execute "split|"->repeat(&lines)'))
      command('vsplit')

      -- Without vim-patch:8.2.3862, this gives E36, despite just the 1st tabpage being full.
      exec_lua('vim.api.nvim_win_call(..., function() vim.cmd.wincmd "J" end)', t2_move_win)
      eq({ 'col', { { 'leaf', t2_other_win }, { 'leaf', t2_move_win } } }, fn.winlayout(2))
    end)
  end)

  describe('vim.iconv', function()
    it('can convert strings', function()
      eq(
        'hello',
        exec_lua [[
        return vim.iconv('hello', 'latin1', 'utf-8')
      ]]
      )
    end)

    it('can validate arguments', function()
      eq(
        { false, 'Expected at least 3 arguments' },
        exec_lua [[
        return {pcall(vim.iconv, 'hello')}
      ]]
      )

      eq(
        { false, "bad argument #3 to '?' (expected string)" },
        exec_lua [[
        return {pcall(vim.iconv, 'hello', 'utf-8', true)}
      ]]
      )
    end)

    it('can handle bad encodings', function()
      eq(
        NIL,
        exec_lua [[
        return vim.iconv('hello', 'foo', 'bar')
      ]]
      )
    end)

    it('can handle strings with NUL bytes', function()
      eq(
        7,
        exec_lua [[
        local a = string.char(97, 98, 99, 0, 100, 101, 102) -- abc\0def
        return string.len(vim.iconv(a, 'latin1', 'utf-8'))
      ]]
      )
    end)
  end)

  describe('vim.defaulttable', function()
    it('creates nested table by default', function()
      eq(
        { b = { c = 1 } },
        exec_lua [[
        local a = vim.defaulttable()
        a.b.c = 1
        return a
      ]]
      )
    end)

    it('allows to create default objects', function()
      eq(
        { b = 1 },
        exec_lua [[
        local a = vim.defaulttable(function() return 0 end)
        a.b = a.b + 1
        return a
      ]]
      )
    end)

    it('accepts the key name', function()
      eq(
        { b = 'b', c = 'c' },
        exec_lua [[
        local a = vim.defaulttable(function(k) return k end)
        local _ = a.b
        local _ = a.c
        return a
      ]]
      )
    end)
  end)

  it('vim.lua_omnifunc', function()
    local screen = Screen.new(60, 5)
    command [[ set omnifunc=v:lua.vim.lua_omnifunc ]]

    -- Note: the implementation is shared with lua command line completion.
    -- More tests for completion in lua/command_line_completion_spec.lua
    feed [[ivim.insp<c-x><c-o>]]
    screen:expect {
      grid = [[
      vim.inspect^                                                 |
      {1:~  }{12: inspect        }{1:                                         }|
      {1:~  }{4: inspect_pos    }{1:                                         }|
      {1:~                                                           }|
      {5:-- Omni completion (^O^N^P) }{6:match 1 of 2}                    |
    ]],
    }
  end)

  it('vim.print', function()
    -- vim.print() returns its args.
    eq(
      { 42, 'abc', { a = { b = 77 } } },
      exec_lua [[return {vim.print(42, 'abc', { a = { b = 77 }})}]]
    )

    -- vim.print() pretty-prints the args.
    eq(
      dedent [[

      42
      abc
      {
        a = {
          b = 77
        }
      }]],
      eval [[execute('lua vim.print(42, "abc", { a = { b = 77 }})')]]
    )
  end)

  it('vim.F.if_nil', function()
    local function if_nil(...)
      return exec_lua(
        [[
        local args = {...}
        local nargs = select('#', ...)
        for i = 1, nargs do
          if args[i] == vim.NIL then
            args[i] = nil
          end
        end
        return vim.F.if_nil(unpack(args, 1, nargs))
      ]],
        ...
      )
    end

    local a = NIL
    local b = NIL
    local c = 42
    local d = false
    eq(42, if_nil(a, c))
    eq(false, if_nil(d, b))
    eq(42, if_nil(a, b, c, d))
    eq(false, if_nil(d))
    eq(false, if_nil(d, c))
    eq(NIL, if_nil(a))
  end)

  it('lpeg', function()
    eq(
      5,
      exec_lua [[
      local m = vim.lpeg
      return m.match(m.R'09'^1, '4504ab')
    ]]
    )

    eq(4, exec_lua [[ return vim.re.match("abcde", '[a-c]+') ]])
  end)

  it('vim.ringbuf', function()
    local results = exec_lua([[
      local ringbuf = vim.ringbuf(3)
      ringbuf:push("a") -- idx: 0
      local peeka1 = ringbuf:peek()
      local peeka2 = ringbuf:peek()
      local popa = ringbuf:pop()
      local popnil = ringbuf:pop()
      ringbuf:push("a") -- idx: 1
      ringbuf:push("b") -- idx: 2

      -- doesn't read last added item, but uses separate read index
      local pop_after_add_b = ringbuf:pop()

      ringbuf:push("c") -- idx: 3 wraps around, overrides idx: 0 "a"
      ringbuf:push("d") -- idx: 4 wraps around, overrides idx: 1 "a"
      return {
        peeka1 = peeka1,
        peeka2 = peeka2,
        pop1 = popa,
        pop2 = popnil,
        pop3 = ringbuf:pop(),
        pop4 = ringbuf:pop(),
        pop5 = ringbuf:pop(),
        pop_after_add_b = pop_after_add_b,
      }
    ]])
    local expected = {
      peeka1 = 'a',
      peeka2 = 'a',
      pop1 = 'a',
      pop2 = nil,
      pop3 = 'b',
      pop4 = 'c',
      pop5 = 'd',
      pop_after_add_b = 'a',
    }
    eq(expected, results)
  end)
end)

describe('lua: builtin modules', function()
  local function do_tests()
    eq(2, exec_lua [[return vim.tbl_count {x=1,y=2}]])
    eq('{ 10, "spam" }', exec_lua [[return vim.inspect {10, 'spam'}]])
  end

  it('works', function()
    clear()
    do_tests()
  end)

  it('works when disabled', function()
    clear('--luamod-dev')
    do_tests()
  end)

  it('works without runtime', function()
    clear { env = { VIMRUNTIME = 'fixtures/a' } }
    do_tests()
  end)

  it('fails when disabled without runtime', function()
    clear()
    command("let $VIMRUNTIME='fixtures/a'")
    -- Use system([nvim,…]) instead of clear() to avoid stderr noise. #21844
    local out = fn.system({
      nvim_prog,
      '--clean',
      '--luamod-dev',
      [[+call nvim_exec_lua('return vim.tbl_count {x=1,y=2}')]],
      '+qa!',
    }):gsub('\r\n', '\n')
    eq(1, eval('v:shell_error'))
    matches("'vim%.shared' not found", out)
  end)
end)

describe('lua: require("mod") from packages', function()
  before_each(function()
    clear('--cmd', 'set rtp+=test/functional/fixtures pp+=test/functional/fixtures')
  end)

  it('propagates syntax error', function()
    local syntax_error_msg = exec_lua [[
      local _, err = pcall(require, "syntax_error")
      return err
    ]]

    matches('unexpected symbol', syntax_error_msg)
  end)

  it('uses the right order of mod.lua vs mod/init.lua', function()
    -- lua/fancy_x.lua takes precedence over lua/fancy_x/init.lua
    eq('I am fancy_x.lua', exec_lua [[ return require'fancy_x' ]])
    -- but lua/fancy_y/init.lua takes precedence over after/lua/fancy_y.lua
    eq('I am init.lua of fancy_y!', exec_lua [[ return require'fancy_y' ]])
    -- safety check: after/lua/fancy_z.lua is still loaded
    eq('I am fancy_z.lua', exec_lua [[ return require'fancy_z' ]])
  end)
end)

describe('vim.keymap', function()
  before_each(clear)

  it('validates', function()
    matches(
      'mode: expected string|table, got number',
      pcall_err(exec_lua, [[vim.keymap.set(42, 'x', print)]])
    )

    matches(
      'rhs: expected string|function, got nil',
      pcall_err(exec_lua, [[vim.keymap.set('n', 'x')]])
    )

    matches(
      'lhs: expected string, got table',
      pcall_err(exec_lua, [[vim.keymap.set('n', {}, print)]])
    )

    matches(
      'rhs: expected string|function, got number',
      pcall_err(exec_lua, [[vim.keymap.set({}, 'x', 42, function() end)]])
    )

    matches(
      'opts: expected table, got function',
      pcall_err(exec_lua, [[vim.keymap.set({}, 'x', 'x', function() end)]])
    )

    matches(
      'rhs: expected string|function, got number',
      pcall_err(exec_lua, [[vim.keymap.set('z', 'x', 42)]])
    )

    matches('Invalid mode shortname: "z"', pcall_err(exec_lua, [[vim.keymap.set('z', 'x', 'y')]]))
  end)

  it('mapping', function()
    eq(
      0,
      exec_lua [[
      GlobalCount = 0
      vim.keymap.set('n', 'asdf', function() GlobalCount = GlobalCount + 1 end)
      return GlobalCount
    ]]
    )

    feed('asdf\n')

    eq(1, exec_lua [[return GlobalCount]])
  end)

  it('expr mapping', function()
    exec_lua [[
      vim.keymap.set('n', 'aa', function() return '<Insert>π<C-V><M-π>foo<lt><Esc>' end, {expr = true})
    ]]

    feed('aa')

    eq({ 'π<M-π>foo<' }, api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('overwrite a mapping', function()
    eq(
      0,
      exec_lua [[
      GlobalCount = 0
      vim.keymap.set('n', 'asdf', function() GlobalCount = GlobalCount + 1 end)
      return GlobalCount
    ]]
    )

    feed('asdf\n')

    eq(1, exec_lua [[return GlobalCount]])

    exec_lua [[
      vim.keymap.set('n', 'asdf', function() GlobalCount = GlobalCount - 1 end)
    ]]

    feed('asdf\n')

    eq(0, exec_lua [[return GlobalCount]])
  end)

  it('unmap', function()
    eq(
      0,
      exec_lua [[
      GlobalCount = 0
      vim.keymap.set('n', 'asdf', function() GlobalCount = GlobalCount + 1 end)
      return GlobalCount
    ]]
    )

    feed('asdf\n')

    eq(1, exec_lua [[return GlobalCount]])

    exec_lua [[
      vim.keymap.del('n', 'asdf')
    ]]

    feed('asdf\n')

    eq(1, exec_lua [[return GlobalCount]])
    eq('\nNo mapping found', n.exec_capture('nmap asdf'))
  end)

  it('buffer-local mappings', function()
    eq(
      0,
      exec_lua [[
      GlobalCount = 0
      vim.keymap.set('n', 'asdf', function() GlobalCount = GlobalCount + 1 end, {buffer=true})
      return GlobalCount
    ]]
    )

    feed('asdf\n')

    eq(1, exec_lua [[return GlobalCount]])

    exec_lua [[
      vim.keymap.del('n', 'asdf', {buffer=true})
    ]]

    feed('asdf\n')

    eq(1, exec_lua [[return GlobalCount]])
    eq('\nNo mapping found', n.exec_capture('nmap asdf'))
  end)

  it('does not mutate the opts parameter', function()
    eq(
      true,
      exec_lua [[
      opts = {buffer=true}
      vim.keymap.set('n', 'asdf', function() end, opts)
      return opts.buffer
    ]]
    )
    eq(
      true,
      exec_lua [[
      vim.keymap.del('n', 'asdf', opts)
      return opts.buffer
    ]]
    )
  end)

  it('<Plug> mappings', function()
    eq(
      0,
      exec_lua [[
      GlobalCount = 0
      vim.keymap.set('n', '<plug>(asdf)', function() GlobalCount = GlobalCount + 1 end)
      vim.keymap.set('n', 'ww', '<plug>(asdf)')
      return GlobalCount
    ]]
    )

    feed('ww\n')

    eq(1, exec_lua [[return GlobalCount]])
  end)
end)

describe('Vimscript function exists()', function()
  it('can check a lua function', function()
    eq(
      1,
      exec_lua [[
      _G.test = function() print("hello") end
      return vim.fn.exists('*v:lua.test')
    ]]
    )

    eq(1, fn.exists('*v:lua.require("mpack").decode'))
    eq(1, fn.exists("*v:lua.require('mpack').decode"))
    eq(1, fn.exists('*v:lua.require"mpack".decode'))
    eq(1, fn.exists("*v:lua.require'mpack'.decode"))
    eq(1, fn.exists("*v:lua.require('vim.lsp').start"))
    eq(1, fn.exists('*v:lua.require"vim.lsp".start'))
    eq(1, fn.exists("*v:lua.require'vim.lsp'.start"))
    eq(0, fn.exists("*v:lua.require'vim.lsp'.unknown"))
    eq(0, fn.exists('*v:lua.?'))
  end)
end)
