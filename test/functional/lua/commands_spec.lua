-- Test suite for checking :lua* commands
local t = require('test.functional.testutil')()
local Screen = require('test.functional.ui.screen')

local eq = t.eq
local NIL = vim.NIL
local eval = t.eval
local feed = t.feed
local clear = t.clear
local matches = t.matches
local api = t.api
local exec_lua = t.exec_lua
local exec_capture = t.exec_capture
local fn = t.fn
local source = t.source
local dedent = t.dedent
local command = t.command
local exc_exec = t.exc_exec
local pcall_err = t.pcall_err
local write_file = t.write_file
local remove_trace = t.remove_trace

before_each(clear)

describe(':lua', function()
  it('works', function()
    eq('', exec_capture('lua vim.api.nvim_buf_set_lines(1, 1, 2, false, {"TEST"})'))
    eq({ '', 'TEST' }, api.nvim_buf_get_lines(0, 0, 100, false))
    source([[
      lua << EOF
        vim.api.nvim_buf_set_lines(1, 1, 2, false, {"TSET"})
      EOF]])
    eq({ '', 'TSET' }, api.nvim_buf_get_lines(0, 0, 100, false))
    source([[
      lua << EOF
        vim.api.nvim_buf_set_lines(1, 1, 2, false, {"SETT"})]])
    eq({ '', 'SETT' }, api.nvim_buf_get_lines(0, 0, 100, false))
    source([[
      lua << EOF
        vim.api.nvim_buf_set_lines(1, 1, 2, false, {"ETTS"})
        vim.api.nvim_buf_set_lines(1, 2, 3, false, {"TTSE"})
        vim.api.nvim_buf_set_lines(1, 3, 4, false, {"STTE"})
      EOF]])
    eq({ '', 'ETTS', 'TTSE', 'STTE' }, api.nvim_buf_get_lines(0, 0, 100, false))
    matches(
      '.*Vim%(lua%):E15: Invalid expression: .*',
      pcall_err(
        source,
        [[
      lua << eval EOF
        {}
      EOF
    ]]
      )
    )
  end)

  it('throws catchable errors', function()
    eq('Vim(lua):E471: Argument required', pcall_err(command, 'lua'))
    eq(
      [[Vim(lua):E5107: Error loading lua [string ":lua"]:0: unexpected symbol near ')']],
      pcall_err(command, 'lua ()')
    )
    eq(
      [[Vim(lua):E5108: Error executing lua [string ":lua"]:1: TEST]],
      remove_trace(exc_exec('lua error("TEST")'))
    )
    eq(
      [[Vim(lua):E5108: Error executing lua [string ":lua"]:1: Invalid buffer id: -10]],
      remove_trace(exc_exec('lua vim.api.nvim_buf_set_lines(-10, 1, 1, false, {"TEST"})'))
    )
    eq({ '' }, api.nvim_buf_get_lines(0, 0, 100, false))
  end)

  it('works with NULL errors', function()
    eq([=[Vim(lua):E5108: Error executing lua [NULL]]=], exc_exec('lua error(nil)'))
  end)

  it('accepts embedded NLs without heredoc', function()
    -- Such code is usually used for `:execute 'lua' {generated_string}`:
    -- heredocs do not work in this case.
    command([[
      lua
        vim.api.nvim_buf_set_lines(1, 1, 2, false, {"ETTS"})
        vim.api.nvim_buf_set_lines(1, 2, 3, false, {"TTSE"})
        vim.api.nvim_buf_set_lines(1, 3, 4, false, {"STTE"})
    ]])
    eq({ '', 'ETTS', 'TTSE', 'STTE' }, api.nvim_buf_get_lines(0, 0, 100, false))
  end)

  it('preserves global and not preserves local variables', function()
    eq('', exec_capture('lua gvar = 42'))
    eq('', exec_capture('lua local lvar = 100500'))
    eq(NIL, fn.luaeval('lvar'))
    eq(42, fn.luaeval('gvar'))
  end)

  it('works with long strings', function()
    local s = ('x'):rep(100500)

    eq(
      'Vim(lua):E5107: Error loading lua [string ":lua"]:0: unfinished string near \'<eof>\'',
      pcall_err(command, ('lua vim.api.nvim_buf_set_lines(1, 1, 2, false, {"%s})'):format(s))
    )
    eq({ '' }, api.nvim_buf_get_lines(0, 0, -1, false))

    eq('', exec_capture(('lua vim.api.nvim_buf_set_lines(1, 1, 2, false, {"%s"})'):format(s)))
    eq({ '', s }, api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('can show multiline error messages', function()
    local screen = Screen.new(40, 10)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = { bold = true, foreground = Screen.colors.Blue1 },
      [2] = { bold = true, reverse = true },
      [3] = { foreground = Screen.colors.Grey100, background = Screen.colors.Red },
      [4] = { bold = true, foreground = Screen.colors.SeaGreen4 },
    })

    feed(':lua error("fail\\nmuch error\\nsuch details")<cr>')
    screen:expect {
      grid = [[
      {2:                                        }|
      {3:E5108: Error executing lua [string ":lua}|
      {3:"]:1: fail}                              |
      {3:much error}                              |
      {3:such details}                            |
      {3:stack traceback:}                        |
      {3:        [C]: in function 'error'}        |
      {3:        [string ":lua"]:1: in main chunk}|
                                              |
      {4:Press ENTER or type command to continue}^ |
    ]],
    }
    feed('<cr>')
    screen:expect {
      grid = [[
      ^                                        |
      {1:~                                       }|*8
                                              |
    ]],
    }
    eq(
      'E5108: Error executing lua [string ":lua"]:1: fail\nmuch error\nsuch details',
      remove_trace(eval('v:errmsg'))
    )

    local status, err = pcall(command, 'lua error("some error\\nin a\\nAPI command")')
    local expected =
      'Vim(lua):E5108: Error executing lua [string ":lua"]:1: some error\nin a\nAPI command'
    eq(false, status)
    eq(expected, string.sub(remove_trace(err), -string.len(expected)))

    feed(':messages<cr>')
    screen:expect {
      grid = [[
      {2:                                        }|
      {3:E5108: Error executing lua [string ":lua}|
      {3:"]:1: fail}                              |
      {3:much error}                              |
      {3:such details}                            |
      {3:stack traceback:}                        |
      {3:        [C]: in function 'error'}        |
      {3:        [string ":lua"]:1: in main chunk}|
                                              |
      {4:Press ENTER or type command to continue}^ |
    ]],
    }
  end)

  it('prints result of =expr', function()
    exec_lua('x = 5')
    eq('5', exec_capture(':lua =x'))
    eq('5', exec_capture('=x'))
    exec_lua("function x() return 'hello' end")
    eq('hello', exec_capture(':lua = x()'))
    exec_lua('x = {a = 1, b = 2}')
    eq('{\n  a = 1,\n  b = 2\n}', exec_capture(':lua  =x'))
    exec_lua([[function x(success)
      if success then
        return true, "Return value"
      else
        return false, nil, "Error message"
      end
    end]])
    eq(
      dedent [[
      true
      Return value]],
      exec_capture(':lua  =x(true)')
    )
    eq(
      dedent [[
      false
      nil
      Error message]],
      exec_capture('=x(false)')
    )
  end)

  it('with range', function()
    local screen = Screen.new(40, 10)
    screen:attach()
    api.nvim_buf_set_lines(0, 0, 0, 0, { 'nonsense', 'function x() print "hello" end', 'x()' })

    -- ":{range}lua" fails on invalid Lua code.
    eq(
      [[:{range}lua: Vim(lua):E5107: Error loading lua [string ":{range}lua"]:0: '=' expected near '<eof>']],
      pcall_err(command, '1lua')
    )

    -- ":{range}lua" executes valid Lua code.
    feed(':2,3lua<CR>')
    screen:expect {
      grid = [[
        nonsense                                |
        function x() print "hello" end          |
        x()                                     |
        ^                                        |
        {1:~                                       }|*5
        hello                                   |
      ]],
      attr_ids = {
        [1] = { foreground = Screen.colors.Blue, bold = true },
      },
    }

    -- ":{range}lua {code}" executes {code}, ignoring {range}
    eq('', exec_capture('1lua gvar = 42'))
    eq(42, fn.luaeval('gvar'))
  end)
end)

describe(':luado command', function()
  it('works', function()
    api.nvim_buf_set_lines(0, 0, 1, false, { 'ABC', 'def', 'gHi' })
    eq('', exec_capture('luado lines = (lines or {}) lines[#lines + 1] = {linenr, line}'))
    eq({ 'ABC', 'def', 'gHi' }, api.nvim_buf_get_lines(0, 0, -1, false))
    eq({ { 1, 'ABC' }, { 2, 'def' }, { 3, 'gHi' } }, fn.luaeval('lines'))

    -- Automatic transformation of numbers
    eq('', exec_capture('luado return linenr'))
    eq({ '1', '2', '3' }, api.nvim_buf_get_lines(0, 0, -1, false))

    eq('', exec_capture('luado return ("<%02x>"):format(line:byte())'))
    eq({ '<31>', '<32>', '<33>' }, api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('stops processing lines when suddenly out of lines', function()
    api.nvim_buf_set_lines(0, 0, 1, false, { 'ABC', 'def', 'gHi' })
    eq('', exec_capture('2,$luado runs = ((runs or 0) + 1) vim.api.nvim_command("%d")'))
    eq({ '' }, api.nvim_buf_get_lines(0, 0, -1, false))
    eq(1, fn.luaeval('runs'))

    api.nvim_buf_set_lines(0, 0, -1, false, { 'one', 'two', 'three' })
    eq('', exec_capture('luado vim.api.nvim_command("%d")'))
    eq({ '' }, api.nvim_buf_get_lines(0, 0, -1, false))

    api.nvim_buf_set_lines(0, 0, -1, false, { 'one', 'two', 'three' })
    eq('', exec_capture('luado vim.api.nvim_command("1,2d")'))
    eq({ 'three' }, api.nvim_buf_get_lines(0, 0, -1, false))

    api.nvim_buf_set_lines(0, 0, -1, false, { 'one', 'two', 'three' })
    eq('', exec_capture('luado vim.api.nvim_command("2,3d"); return "REPLACED"'))
    eq({ 'REPLACED' }, api.nvim_buf_get_lines(0, 0, -1, false))

    api.nvim_buf_set_lines(0, 0, -1, false, { 'one', 'two', 'three' })
    eq('', exec_capture('2,3luado vim.api.nvim_command("1,2d"); return "REPLACED"'))
    eq({ 'three' }, api.nvim_buf_get_lines(0, 0, -1, false))
  end)

  it('fails on errors', function()
    eq(
      [[Vim(luado):E5109: Error loading lua: [string ":luado"]:0: unexpected symbol near ')']],
      pcall_err(command, 'luado ()')
    )
    eq(
      [[Vim(luado):E5111: Error calling lua: [string ":luado"]:0: attempt to perform arithmetic on global 'liness' (a nil value)]],
      pcall_err(command, 'luado return liness + 1')
    )
  end)

  it('works with NULL errors', function()
    eq([=[Vim(luado):E5111: Error calling lua: [NULL]]=], exc_exec('luado error(nil)'))
  end)

  it('fails in sandbox when needed', function()
    api.nvim_buf_set_lines(0, 0, 1, false, { 'ABC', 'def', 'gHi' })
    eq(
      'Vim(luado):E48: Not allowed in sandbox: sandbox luado runs = (runs or 0) + 1',
      pcall_err(command, 'sandbox luado runs = (runs or 0) + 1')
    )
    eq(NIL, fn.luaeval('runs'))
  end)

  it('works with long strings', function()
    local s = ('x'):rep(100500)

    eq(
      'Vim(luado):E5109: Error loading lua: [string ":luado"]:0: unfinished string near \'<eof>\'',
      pcall_err(command, ('luado return "%s'):format(s))
    )
    eq({ '' }, api.nvim_buf_get_lines(0, 0, -1, false))

    eq('', exec_capture(('luado return "%s"'):format(s)))
    eq({ s }, api.nvim_buf_get_lines(0, 0, -1, false))
  end)
end)

describe(':luafile', function()
  local fname = 'Xtest-functional-lua-commands-luafile'

  after_each(function()
    os.remove(fname)
  end)

  it('works', function()
    write_file(
      fname,
      [[
        vim.api.nvim_buf_set_lines(1, 1, 2, false, {"ETTS"})
        vim.api.nvim_buf_set_lines(1, 2, 3, false, {"TTSE"})
        vim.api.nvim_buf_set_lines(1, 3, 4, false, {"STTE"})
    ]]
    )
    eq('', exec_capture('luafile ' .. fname))
    eq({ '', 'ETTS', 'TTSE', 'STTE' }, api.nvim_buf_get_lines(0, 0, 100, false))
  end)

  it('correctly errors out', function()
    write_file(fname, '()')
    eq(
      ("Vim(luafile):E5112: Error while creating lua chunk: %s:1: unexpected symbol near ')'"):format(
        fname
      ),
      exc_exec('luafile ' .. fname)
    )
    write_file(fname, 'vimm.api.nvim_buf_set_lines(1, 1, 2, false, {"ETTS"})')
    eq(
      ("Vim(luafile):E5113: Error while calling lua chunk: %s:1: attempt to index global 'vimm' (a nil value)"):format(
        fname
      ),
      remove_trace(exc_exec('luafile ' .. fname))
    )
  end)

  it('works with NULL errors', function()
    write_file(fname, 'error(nil)')
    eq(
      [=[Vim(luafile):E5113: Error while calling lua chunk: [NULL]]=],
      exc_exec('luafile ' .. fname)
    )
  end)
end)
