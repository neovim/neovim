-- Tests for system() and :! shell.

local t = require('test.functional.testutil')(after_each)

local assert_alive = t.assert_alive
local testprg = t.testprg
local eq, call, clear, eval, feed_command, feed, api =
  t.eq, t.call, t.clear, t.eval, t.feed_command, t.feed, t.api
local command = t.command
local insert = t.insert
local expect = t.expect
local exc_exec = t.exc_exec
local os_kill = t.os_kill
local pcall_err = t.pcall_err
local is_os = t.is_os

local Screen = require('test.functional.ui.screen')

local function create_file_with_nuls(name)
  return function()
    feed('ipart1<C-V>000part2<C-V>000part3<ESC>:w ' .. name .. '<CR>')
    eval('1') -- wait for the file to be created
  end
end

local function delete_file(name)
  return function()
    eval("delete('" .. name .. "')")
  end
end

describe('system()', function()
  before_each(clear)

  describe('command passed as a List', function()
    it('throws error if cmd[0] is not executable', function()
      eq(
        "Vim:E475: Invalid value for argument cmd: 'this-should-not-exist' is not executable",
        pcall_err(call, 'system', { 'this-should-not-exist' })
      )
      eq(-1, eval('v:shell_error'))
    end)

    it('parameter validation does NOT modify v:shell_error', function()
      -- 1. Call system() with invalid parameters.
      -- 2. Assert that v:shell_error was NOT set.
      feed_command('call system({})')
      eq('E475: Invalid argument: expected String or List', eval('v:errmsg'))
      eq(0, eval('v:shell_error'))
      feed_command('call system([])')
      eq('E474: Invalid argument', eval('v:errmsg'))
      eq(0, eval('v:shell_error'))

      -- Provoke a non-zero v:shell_error.
      eq(
        "Vim:E475: Invalid value for argument cmd: 'this-should-not-exist' is not executable",
        pcall_err(call, 'system', { 'this-should-not-exist' })
      )
      local old_val = eval('v:shell_error')
      eq(-1, old_val)

      -- 1. Call system() with invalid parameters.
      -- 2. Assert that v:shell_error was NOT modified.
      feed_command('call system({})')
      eq(old_val, eval('v:shell_error'))
      feed_command('call system([])')
      eq(old_val, eval('v:shell_error'))
    end)

    it('quotes arguments correctly #5280', function()
      local out =
        call('system', { testprg('printargs-test'), [[1]], [[2 "3]], [[4 ' 5]], [[6 ' 7']] })

      eq(0, eval('v:shell_error'))
      eq([[arg1=1;arg2=2 "3;arg3=4 ' 5;arg4=6 ' 7';]], out)

      out = call('system', { testprg('printargs-test'), [['1]], [[2 "3]] })
      eq(0, eval('v:shell_error'))
      eq([[arg1='1;arg2=2 "3;]], out)

      out = call('system', { testprg('printargs-test'), 'A\nB' })
      eq(0, eval('v:shell_error'))
      eq('arg1=A\nB;', out)
    end)

    it('calls executable in $PATH', function()
      if 0 == eval("executable('python3')") then
        pending('missing `python3`')
      end
      eq('foo\n', eval([[system(['python3', '-c', 'print("foo")'])]]))
      eq(0, eval('v:shell_error'))
    end)

    it('does NOT run in shell', function()
      if is_os('win') then
        eq(
          '%PATH%\n',
          eval(
            "system(['powershell', '-NoProfile', '-NoLogo', '-ExecutionPolicy', 'RemoteSigned', '-Command', 'Write-Output', '%PATH%'])"
          )
        )
      else
        eq('* $PATH %PATH%\n', eval("system(['echo', '*', '$PATH', '%PATH%'])"))
      end
    end)
  end)

  it('sets v:shell_error', function()
    if is_os('win') then
      eval([[system("cmd.exe /c exit")]])
      eq(0, eval('v:shell_error'))
      eval([[system("cmd.exe /c exit 1")]])
      eq(1, eval('v:shell_error'))
      eval([[system("cmd.exe /c exit 5")]])
      eq(5, eval('v:shell_error'))
      eval([[system('this-should-not-exist')]])
      eq(1, eval('v:shell_error'))
    else
      eval([[system("sh -c 'exit'")]])
      eq(0, eval('v:shell_error'))
      eval([[system("sh -c 'exit 1'")]])
      eq(1, eval('v:shell_error'))
      eval([[system("sh -c 'exit 5'")]])
      eq(5, eval('v:shell_error'))
      eval([[system('this-should-not-exist')]])
      eq(127, eval('v:shell_error'))
    end
  end)

  describe('executes shell function', function()
    local screen

    before_each(function()
      screen = Screen.new()
      screen:attach()
    end)

    if is_os('win') then
      local function test_more()
        eq('root = true', eval([[get(split(system('"more" ".editorconfig"'), "\n"), 0, '')]]))
      end
      local function test_shell_unquoting()
        eval([[system('"ping" "-n" "1" "127.0.0.1"')]])
        eq(0, eval('v:shell_error'))
        eq('"a b"\n', eval([[system('cmd /s/c "cmd /s/c "cmd /s/c "echo "a b""""')]]))
        eq(
          '"a b"\n',
          eval(
            [[system('powershell -NoProfile -NoLogo -ExecutionPolicy RemoteSigned -Command Write-Output ''\^"a b\^"''')]]
          )
        )
      end

      it('with shell=cmd.exe', function()
        command('set shell=cmd.exe')
        eq('""\n', eval([[system('echo ""')]]))
        eq('"a b"\n', eval([[system('echo "a b"')]]))
        eq('a \nb\n', eval([[system('echo a & echo b')]]))
        eq('a \n', eval([[system('echo a 2>&1')]]))
        test_more()
        eval([[system('cd "C:\Program Files"')]])
        eq(0, eval('v:shell_error'))
        test_shell_unquoting()
      end)

      it('with shell=cmd', function()
        command('set shell=cmd')
        eq('"a b"\n', eval([[system('echo "a b"')]]))
        test_more()
        test_shell_unquoting()
      end)

      it('with shell=$COMSPEC', function()
        local comspecshell = eval("fnamemodify($COMSPEC, ':t')")
        if comspecshell == 'cmd.exe' then
          command('set shell=$COMSPEC')
          eq('"a b"\n', eval([[system('echo "a b"')]]))
          test_more()
          test_shell_unquoting()
        else
          pending('$COMSPEC is not cmd.exe: ' .. comspecshell)
        end
      end)

      it('with powershell', function()
        t.set_shell_powershell()
        eq('a\nb\n', eval([[system('Write-Output a b')]]))
        eq('C:\\\n', eval([[system('cd c:\; (Get-Location).Path')]]))
        eq('a b\n', eval([[system('Write-Output "a b"')]]))
      end)
    end

    it('powershell w/ UTF-8 text #13713', function()
      if not t.has_powershell() then
        pending('powershell not found', function() end)
        return
      end
      t.set_shell_powershell()
      eq('ああ\n', eval([[system('Write-Output "ああ"')]]))
      -- Sanity test w/ default encoding
      -- * on Windows, expected to default to Western European enc
      -- * on Linux, expected to default to UTF8
      command([[let &shellcmdflag = '-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command ']])
      eq(is_os('win') and '??\n' or 'ああ\n', eval([[system('Write-Output "ああ"')]]))
    end)

    it('`echo` and waits for its return', function()
      feed(':call system("echo")<cr>')
      screen:expect([[
        ^                                                     |
        {1:~                                                    }|*12
        :call system("echo")                                 |
      ]])
    end)

    it('prints verbose information', function()
      api.nvim_set_option_value('shell', 'fake_shell', {})
      api.nvim_set_option_value('shellcmdflag', 'cmdflag', {})

      screen:try_resize(72, 14)
      feed(':4verbose echo system("echo hi")<cr>')
      if is_os('win') then
        screen:expect { any = [[Executing command: "'fake_shell' 'cmdflag' '"echo hi"'"]] }
      else
        screen:expect { any = [[Executing command: "'fake_shell' 'cmdflag' 'echo hi'"]] }
      end
      feed('<cr>')
    end)

    it('self and total time recorded separately', function()
      local tempfile = t.tmpname()

      feed(':function! AlmostNoSelfTime()<cr>')
      feed('echo system("echo hi")<cr>')
      feed('endfunction<cr>')

      feed(':profile start ' .. tempfile .. '<cr>')
      feed(':profile func AlmostNoSelfTime<cr>')
      feed(':call AlmostNoSelfTime()<cr>')
      feed(':profile dump<cr>')

      feed(':edit ' .. tempfile .. '<cr>')

      local command_total_time = tonumber(t.fn.split(t.fn.getline(7))[2])
      local command_self_time = tonumber(t.fn.split(t.fn.getline(7))[3])

      t.neq(nil, command_total_time)
      t.neq(nil, command_self_time)
    end)

    it('`yes` interrupted with CTRL-C', function()
      feed(
        ':call system("'
          .. (is_os('win') and 'for /L %I in (1,0,2) do @echo y' or 'yes')
          .. '")<cr>'
      )
      screen:expect([[
                                                             |
        {1:~                                                    }|*12
]] .. (is_os('win') and [[
        :call system("for /L %I in (1,0,2) do @echo y")      |]] or [[
        :call system("yes")                                  |]]))
      feed('foo<c-c>')
      screen:expect([[
        ^                                                     |
        {1:~                                                    }|*12
        Type  :qa  and press <Enter> to exit Nvim            |
      ]])
    end)

    it('`yes` interrupted with mapped CTRL-C', function()
      command('nnoremap <C-C> i')
      feed(
        ':call system("'
          .. (is_os('win') and 'for /L %I in (1,0,2) do @echo y' or 'yes')
          .. '")<cr>'
      )
      screen:expect([[
                                                             |
        {1:~                                                    }|*12
]] .. (is_os('win') and [[
        :call system("for /L %I in (1,0,2) do @echo y")      |]] or [[
        :call system("yes")                                  |]]))
      feed('foo<c-c>')
      screen:expect([[
        ^                                                     |
        {1:~                                                    }|*12
        {5:-- INSERT --}                                         |
      ]])
    end)
  end)

  describe('passing no input', function()
    it('returns the program output', function()
      if is_os('win') then
        eq('echoed\n', eval('system("echo echoed")'))
      else
        eq('echoed', eval('system("printf echoed")'))
      end
    end)
    it('to backgrounded command does not crash', function()
      -- This is indeterminate, just exercise the codepath. May get E5677.
      feed_command(
        'call system(has("win32") ? "start /b /wait cmd /c echo echoed" : "printf echoed &")'
      )
      local v_errnum = string.match(eval('v:errmsg'), '^E%d*:')
      if v_errnum then
        eq('E5677:', v_errnum)
      end
      assert_alive()
    end)
  end)

  describe('passing input', function()
    it('returns the program output', function()
      eq('input', eval('system("cat -", "input")'))
    end)
    it('to backgrounded command does not crash', function()
      -- This is indeterminate, just exercise the codepath. May get E5677.
      feed_command('call system(has("win32") ? "start /b /wait more" : "cat - &", "input")')
      local v_errnum = string.match(eval('v:errmsg'), '^E%d*:')
      if v_errnum then
        eq('E5677:', v_errnum)
      end
      assert_alive()
    end)
    it('works with an empty string', function()
      eq('test\n', eval('system("echo test", "")'))
      assert_alive()
    end)
  end)

  describe('passing a lot of input', function()
    it('returns the program output', function()
      local input = {}
      -- write more than 1mb of data, which should be enough to overcome
      -- the os buffer limit and force multiple event loop iterations to write
      -- everything
      for _ = 1, 0xffff do
        input[#input + 1] = '01234567890ABCDEFabcdef'
      end
      input = table.concat(input, '\n')
      api.nvim_set_var('input', input)
      eq(input, eval('system("cat -", g:input)'))
    end)
  end)

  describe('Number input', function()
    it('is treated as a buffer id', function()
      command("put ='text in buffer 1'")
      eq('\ntext in buffer 1\n', eval('system("cat", 1)'))
      eq('Vim(echo):E86: Buffer 42 does not exist', exc_exec('echo system("cat", 42)'))
    end)
  end)

  describe('with output containing NULs', function()
    local fname = 'Xtest_functional_vimscript_system_nuls'

    before_each(create_file_with_nuls(fname))
    after_each(delete_file(fname))

    it('replaces NULs by SOH characters', function()
      eq('part1\001part2\001part3\n', eval([[system('"cat" "]] .. fname .. [["')]]))
    end)
  end)

  describe('input passed as List', function()
    it('joins List items with linefeed characters', function()
      eq('line1\nline2\nline3', eval("system('cat -', ['line1', 'line2', 'line3'])"))
    end)

    -- Notice that NULs are converted to SOH when the data is read back. This
    -- is inconsistent and is a good reason for the existence of the
    -- `systemlist()` function, where input and output map to the same
    -- characters(see the following tests with `systemlist()` below)
    describe('with linefeed characters inside List items', function()
      it('converts linefeed characters to NULs', function()
        eq(
          'l1\001p2\nline2\001a\001b\nl3',
          eval([[system('cat -', ["l1\np2", "line2\na\nb", 'l3'])]])
        )
      end)
    end)

    describe('with leading/trailing whitespace characters on items', function()
      it('preserves whitespace, replacing linefeeds by NULs', function()
        eq(
          'line \nline2\001\n\001line3',
          eval([[system('cat -', ['line ', "line2\n", "\nline3"])]])
        )
      end)
    end)
  end)

  it("with a program that doesn't close stdout will exit properly after passing input", function()
    local out = eval(string.format("system('%s', 'clip-data')", testprg('streams-test')))
    assert(out:sub(0, 5) == 'pid: ', out)
    os_kill(out:match('%d+'))
  end)
end)

describe('systemlist()', function()
  -- Similar to `system()`, but returns List instead of String.
  before_each(clear)

  it('sets v:shell_error', function()
    if is_os('win') then
      eval([[systemlist("cmd.exe /c exit")]])
      eq(0, eval('v:shell_error'))
      eval([[systemlist("cmd.exe /c exit 1")]])
      eq(1, eval('v:shell_error'))
      eval([[systemlist("cmd.exe /c exit 5")]])
      eq(5, eval('v:shell_error'))
      eval([[systemlist('this-should-not-exist')]])
      eq(1, eval('v:shell_error'))
    else
      eval([[systemlist("sh -c 'exit'")]])
      eq(0, eval('v:shell_error'))
      eval([[systemlist("sh -c 'exit 1'")]])
      eq(1, eval('v:shell_error'))
      eval([[systemlist("sh -c 'exit 5'")]])
      eq(5, eval('v:shell_error'))
      eval([[systemlist('this-should-not-exist')]])
      eq(127, eval('v:shell_error'))
    end
  end)

  describe('executes shell function', function()
    local screen

    before_each(function()
      screen = Screen.new()
      screen:attach()
    end)

    after_each(function()
      screen:detach()
    end)

    it('`echo` and waits for its return', function()
      feed(':call systemlist("echo")<cr>')
      screen:expect([[
        ^                                                     |
        {1:~                                                    }|*12
        :call systemlist("echo")                             |
      ]])
    end)

    it('`yes` interrupted with CTRL-C', function()
      feed(':call systemlist("yes | xargs")<cr>')
      screen:expect([[
                                                             |
        {1:~                                                    }|*12
        :call systemlist("yes | xargs")                      |
      ]])
      feed('<c-c>')
      screen:expect([[
        ^                                                     |
        {1:~                                                    }|*12
        Type  :qa  and press <Enter> to exit Nvim            |
      ]])
    end)
  end)

  describe('passing string with linefeed characters as input', function()
    it('splits the output on linefeed characters', function()
      eq({ 'abc', 'def', 'ghi' }, eval([[systemlist("cat -", "abc\ndef\nghi")]]))
    end)
  end)

  describe('passing a lot of input', function()
    it('returns the program output', function()
      local input = {}
      for _ = 1, 0xffff do
        input[#input + 1] = '01234567890ABCDEFabcdef'
      end
      api.nvim_set_var('input', input)
      eq(input, eval('systemlist("cat -", g:input)'))
    end)
  end)

  describe('with output containing NULs', function()
    local fname = 'Xtest_functional_vimscript_systemlist_nuls'

    before_each(function()
      command('set ff=unix')
      create_file_with_nuls(fname)()
    end)
    after_each(delete_file(fname))

    it('replaces NULs by newline characters', function()
      eq({ 'part1\npart2\npart3' }, eval([[systemlist('"cat" "]] .. fname .. [["')]]))
    end)
  end)

  describe('input passed as List', function()
    it('joins list items with linefeed characters', function()
      eq({ 'line1', 'line2', 'line3' }, eval("systemlist('cat -', ['line1', 'line2', 'line3'])"))
    end)

    -- Unlike `system()` which uses SOH to represent NULs, with `systemlist()`
    -- input and output are the same.
    describe('with linefeed characters inside list items', function()
      it('converts linefeed characters to NULs', function()
        eq(
          { 'l1\np2', 'line2\na\nb', 'l3' },
          eval([[systemlist('cat -', ["l1\np2", "line2\na\nb", 'l3'])]])
        )
      end)
    end)

    describe('with leading/trailing whitespace characters on items', function()
      it('preserves whitespace, replacing linefeeds by NULs', function()
        eq(
          { 'line ', 'line2\n', '\nline3' },
          eval([[systemlist('cat -', ['line ', "line2\n", "\nline3"])]])
        )
      end)
    end)
  end)

  describe('handles empty lines', function()
    it('in the middle', function()
      eq({ 'line one', '', 'line two' }, eval("systemlist('cat',['line one','','line two'])"))
    end)

    it('in the beginning', function()
      eq({ '', 'line one', 'line two' }, eval("systemlist('cat',['','line one','line two'])"))
    end)
  end)

  describe('when keepempty option is', function()
    it('0, ignores trailing newline', function()
      eq({ 'aa', 'bb' }, eval("systemlist('cat',['aa','bb'],0)"))
      eq({ 'aa', 'bb' }, eval("systemlist('cat',['aa','bb',''],0)"))
    end)

    it('1, preserves trailing newline', function()
      eq({ 'aa', 'bb' }, eval("systemlist('cat',['aa','bb'],1)"))
      eq({ 'aa', 'bb', '' }, eval("systemlist('cat',['aa','bb',''],2)"))
    end)
  end)

  it("with a program that doesn't close stdout will exit properly after passing input", function()
    local out = eval(string.format("systemlist('%s', 'clip-data')", testprg('streams-test')))
    assert(out[1]:sub(0, 5) == 'pid: ', out)
    os_kill(out[1]:match('%d+'))
  end)

  it('powershell w/ UTF-8 text #13713', function()
    if not t.has_powershell() then
      pending('powershell not found', function() end)
      return
    end
    t.set_shell_powershell()
    eq({ is_os('win') and 'あ\r' or 'あ' }, eval([[systemlist('Write-Output あ')]]))
    -- Sanity test w/ default encoding
    -- * on Windows, expected to default to Western European enc
    -- * on Linux, expected to default to UTF8
    command([[let &shellcmdflag = '-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command ']])
    eq({ is_os('win') and '?\r' or 'あ' }, eval([[systemlist('Write-Output あ')]]))
  end)
end)

describe('shell :!', function()
  before_each(clear)

  it(':{range}! with powershell filter/redirect #16271 #19250', function()
    local screen = Screen.new(500, 8)
    screen:attach()
    local found = t.set_shell_powershell(true)
    insert([[
      3
      1
      4
      2]])
    if is_os('win') then
      feed(':4verbose %!sort /R<cr>')
      screen:expect {
        any = [[Executing command: .?& { Get%-Content .* | & sort /R } 2>&1 | %%{ "$_" } | Out%-File .*; exit $LastExitCode"]],
      }
    else
      feed(':4verbose %!sort -r<cr>')
      screen:expect {
        any = [[Executing command: .?& { Get%-Content .* | & sort %-r } 2>&1 | %%{ "$_" } | Out%-File .*; exit $LastExitCode"]],
      }
    end
    feed('<CR>')
    if found then
      -- Not using fake powershell, so we can test the result.
      expect([[
        4
        3
        2
        1]])
    end
  end)

  it(':{range}! without redirecting to buffer', function()
    local screen = Screen.new(500, 10)
    screen:attach()
    insert([[
      3
      1
      4
      2]])
    feed(':4verbose %w !sort<cr>')
    if is_os('win') then
      screen:expect {
        any = [[Executing command: .?sort %< .*]],
      }
    else
      screen:expect {
        any = [[Executing command: .?%(sort%) %< .*]],
      }
    end
    feed('<CR>')
    t.set_shell_powershell(true)
    feed(':4verbose %w !sort<cr>')
    screen:expect {
      any = [[Executing command: .?& { Get%-Content .* | & sort }]],
    }
    feed('<CR>')
    t.expect_exit(command, 'qall!')
  end)
end)
