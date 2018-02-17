local helpers = require('test.functional.helpers')(after_each)

local nvim_dir = helpers.nvim_dir
local eq, call, clear, eval, feed_command, feed, nvim =
  helpers.eq, helpers.call, helpers.clear, helpers.eval, helpers.feed_command,
  helpers.feed, helpers.nvim
local command = helpers.command
local exc_exec = helpers.exc_exec
local iswin = helpers.iswin

local Screen = require('test.functional.ui.screen')

local function create_file_with_nuls(name)
  return function()
    feed('ipart1<C-V>000part2<C-V>000part3<ESC>:w '..name..'<CR>')
    eval('1')  -- wait for the file to be created
  end
end

local function delete_file(name)
  return function()
    eval("delete('"..name.."')")
  end
end

-- Some tests require the xclip program and a x server.
local xclip = nil
do
  if os.getenv('DISPLAY') then
    xclip = (os.execute('command -v xclip > /dev/null 2>&1') == 0)
  end
end

describe('system()', function()
  before_each(clear)

  describe('command passed as a List', function()
    local function printargs_path()
      return nvim_dir..'/printargs-test' .. (iswin() and '.exe' or '')
    end

    it('sets v:shell_error if cmd[0] is not executable', function()
      call('system', { 'this-should-not-exist' })
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
      call('system', { 'this-should-not-exist' })
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
      local out = call('system',
        { printargs_path(), [[1]], [[2 "3]], [[4 ' 5]], [[6 ' 7']] })

      eq(0, eval('v:shell_error'))
      eq([[arg1=1;arg2=2 "3;arg3=4 ' 5;arg4=6 ' 7';]], out)

      out = call('system', { printargs_path(), [['1]], [[2 "3]] })
      eq(0, eval('v:shell_error'))
      eq([[arg1='1;arg2=2 "3;]], out)

      out = call('system', { printargs_path(), "A\nB" })
      eq(0, eval('v:shell_error'))
      eq("arg1=A\nB;", out)
    end)

    it('calls executable in $PATH', function()
      if 0 == eval("executable('python')") then pending("missing `python`") end
      eq("foo\n", eval([[system(['python', '-c', 'print("foo")'])]]))
      eq(0, eval('v:shell_error'))
    end)

    it('does NOT run in shell', function()
      if iswin() then
        eq("%PATH%\n", eval("system(['powershell', '-NoProfile', '-NoLogo', '-ExecutionPolicy', 'RemoteSigned', '-Command', 'echo', '%PATH%'])"))
      else
        eq("* $PATH %PATH%\n", eval("system(['echo', '*', '$PATH', '%PATH%'])"))
      end
    end)
  end)

  it('sets v:shell_error', function()
    if iswin() then
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

  describe('executes shell function if passed a string', function()
    local screen

    before_each(function()
        clear()
        screen = Screen.new()
        screen:attach()
    end)

    after_each(function()
        screen:detach()
    end)

    if iswin() then
      it('with shell=cmd.exe', function()
        command('set shell=cmd.exe')
        eq('""\n', eval([[system('echo ""')]]))
        eq('"a b"\n', eval([[system('echo "a b"')]]))
        eq('a \nb\n', eval([[system('echo a & echo b')]]))
        eq('a \n', eval([[system('echo a 2>&1')]]))
        eval([[system('cd "C:\Program Files"')]])
        eq(0, eval('v:shell_error'))
      end)

      it('with shell=cmd', function()
        command('set shell=cmd')
        eq('"a b"\n', eval([[system('echo "a b"')]]))
      end)

      it('with shell=$COMSPEC', function()
        local comspecshell = eval("fnamemodify($COMSPEC, ':t')")
        if comspecshell == 'cmd.exe' then
          command('set shell=$COMSPEC')
          eq('"a b"\n', eval([[system('echo "a b"')]]))
        else
          pending('$COMSPEC is not cmd.exe: ' .. comspecshell)
        end
      end)

      it('works with powershell', function()
        helpers.set_shell_powershell()
        eq('a\nb\n', eval([[system('echo a b')]]))
        eq('C:\\\n', eval([[system('cd c:\; (Get-Location).Path')]]))
        eq('a b\n', eval([[system('echo "a b"')]]))
      end)
    end

    it('`echo` and waits for its return', function()
      feed(':call system("echo")<cr>')
      screen:expect([[
        ^                                                     |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        :call system("echo")                                 |
      ]])
    end)

    it('`yes` and is interrupted with CTRL-C', function()
      feed(':call system("' .. (iswin()
        and 'for /L %I in (1,0,2) do @echo y'
        or  'yes') .. '")<cr>')
      screen:expect([[
                                                             |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
]] .. (iswin()
        and [[
        :call system("for /L %I in (1,0,2) do @echo y")      |]]
        or  [[
        :call system("yes")                                  |]]))
      feed('<c-c>')
      screen:expect([[
        ^                                                     |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        Type  :quit<Enter>  to exit Nvim                     |
      ]])
    end)
  end)

  describe('passing no input', function()
    it('returns the program output', function()
      if iswin() then
        eq("echoed\n", eval('system("echo echoed")'))
      else
        eq("echoed", eval('system("echo -n echoed")'))
      end
    end)
    it('to backgrounded command does not crash', function()
      -- This is indeterminate, just exercise the codepath. May get E5677.
      feed_command('call system("echo -n echoed &")')
      local v_errnum = string.match(eval("v:errmsg"), "^E%d*:")
      if v_errnum then
        eq("E5677:", v_errnum)
      end
      eq(2, eval("1+1"))  -- Still alive?
    end)
  end)

  describe('passing input', function()
    it('returns the program output', function()
      eq("input", eval('system("cat -", "input")'))
    end)
    it('to backgrounded command does not crash', function()
      -- This is indeterminate, just exercise the codepath. May get E5677.
      feed_command('call system("cat - &", "input")')
      local v_errnum = string.match(eval("v:errmsg"), "^E%d*:")
      if v_errnum then
        eq("E5677:", v_errnum)
      end
      eq(2, eval("1+1"))  -- Still alive?
    end)
    it('works with an empty string', function()
      eq("test\n", eval('system("echo test", "")'))
      eq(2, eval("1+1"))  -- Still alive?
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
      nvim('set_var', 'input', input)
      eq(input, eval('system("cat -", g:input)'))
    end)
  end)

  describe('Number input', function()
    it('is treated as a buffer id', function()
      command("put ='text in buffer 1'")
      eq('\ntext in buffer 1\n', eval('system("cat", 1)'))
      eq('Vim(echo):E86: Buffer 42 does not exist',
         exc_exec('echo system("cat", 42)'))
    end)
  end)

  describe('with output containing NULs', function()
    local fname = 'Xtest'

    before_each(create_file_with_nuls(fname))
    after_each(delete_file(fname))

    it('replaces NULs by SOH characters', function()
      eq('part1\001part2\001part3\n', eval('system("cat '..fname..'")'))
    end)
  end)

  describe('input passed as List', function()
    it('joins List items with linefeed characters', function()
      eq('line1\nline2\nline3',
        eval("system('cat -', ['line1', 'line2', 'line3'])"))
    end)

    -- Notice that NULs are converted to SOH when the data is read back. This
    -- is inconsistent and is a good reason for the existence of the
    -- `systemlist()` function, where input and output map to the same
    -- characters(see the following tests with `systemlist()` below)
    describe('with linefeed characters inside List items', function()
      it('converts linefeed characters to NULs', function()
        eq('l1\001p2\nline2\001a\001b\nl3',
          eval([[system('cat -', ["l1\np2", "line2\na\nb", 'l3'])]]))
      end)
    end)

    describe('with leading/trailing whitespace characters on items', function()
      it('preserves whitespace, replacing linefeeds by NULs', function()
        eq('line \nline2\001\n\001line3',
          eval([[system('cat -', ['line ', "line2\n", "\nline3"])]]))
      end)
    end)
  end)

  describe("with a program that doesn't close stdout", function()
    if not xclip then
      pending('missing `xclip`', function() end)
    else
      it('will exit properly after passing input', function()
        eq('', eval([[system('xclip -i -loops 1 -selection clipboard', 'clip-data')]]))
        eq('clip-data', eval([[system('xclip -o -selection clipboard')]]))
      end)
    end
  end)
end)

describe('systemlist()', function()
  -- Similar to `system()`, but returns List instead of String.
  before_each(clear)

  it('sets v:shell_error', function()
    if iswin() then
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

  describe('exectues shell function', function()
    local screen

    before_each(function()
        clear()
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
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        :call systemlist("echo")                             |
      ]])
    end)

    it('`yes` and is interrupted with CTRL-C', function()
      feed(':call systemlist("yes | xargs")<cr>')
      screen:expect([[
                                                             |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        :call systemlist("yes | xargs")                      |
      ]])
      feed('<c-c>')
      screen:expect([[
        ^                                                     |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        Type  :quit<Enter>  to exit Nvim                     |
      ]])
    end)
  end)

  describe('passing string with linefeed characters as input', function()
    it('splits the output on linefeed characters', function()
      eq({'abc', 'def', 'ghi'}, eval([[systemlist("cat -", "abc\ndef\nghi")]]))
    end)
  end)

  describe('passing a lot of input', function()
    it('returns the program output', function()
      local input = {}
      for _ = 1, 0xffff do
        input[#input + 1] = '01234567890ABCDEFabcdef'
      end
      nvim('set_var', 'input', input)
      eq(input, eval('systemlist("cat -", g:input)'))
    end)
  end)

  describe('with output containing NULs', function()
    local fname = 'Xtest'

    before_each(function()
      command('set ff=unix')
      create_file_with_nuls(fname)()
    end)
    after_each(delete_file(fname))

    it('replaces NULs by newline characters', function()
      eq({'part1\npart2\npart3'}, eval('systemlist("cat '..fname..'")'))
    end)
  end)

  describe('input passed as List', function()
    it('joins list items with linefeed characters', function()
      eq({'line1', 'line2', 'line3'},
        eval("systemlist('cat -', ['line1', 'line2', 'line3'])"))
    end)

    -- Unlike `system()` which uses SOH to represent NULs, with `systemlist()`
    -- input and ouput are the same.
    describe('with linefeed characters inside list items', function()
      it('converts linefeed characters to NULs', function()
        eq({'l1\np2', 'line2\na\nb', 'l3'},
          eval([[systemlist('cat -', ["l1\np2", "line2\na\nb", 'l3'])]]))
      end)
    end)

    describe('with leading/trailing whitespace characters on items', function()
      it('preserves whitespace, replacing linefeeds by NULs', function()
        eq({'line ', 'line2\n', '\nline3'},
          eval([[systemlist('cat -', ['line ', "line2\n", "\nline3"])]]))
      end)
    end)
  end)

  describe('handles empty lines', function()
    it('in the middle', function()
      eq({'line one','','line two'}, eval("systemlist('cat',['line one','','line two'])"))
    end)

    it('in the beginning', function()
      eq({'','line one','line two'}, eval("systemlist('cat',['','line one','line two'])"))
    end)
  end)

  describe('when keepempty option is', function()
    it('0, ignores trailing newline', function()
      eq({'aa','bb'}, eval("systemlist('cat',['aa','bb'],0)"))
      eq({'aa','bb'}, eval("systemlist('cat',['aa','bb',''],0)"))
    end)

    it('1, preserves trailing newline', function()
      eq({'aa','bb'}, eval("systemlist('cat',['aa','bb'],1)"))
      eq({'aa','bb',''}, eval("systemlist('cat',['aa','bb',''],2)"))
    end)
  end)

  describe("with a program that doesn't close stdout", function()
    if not xclip then
      pending('missing `xclip`', function() end)
    else
      it('will exit properly after passing input', function()
        eq({}, eval(
          "systemlist('xclip -i -loops 1 -selection clipboard', ['clip', 'data'])"))
        eq({'clip', 'data'}, eval(
          "systemlist('xclip -o -selection clipboard')"))
      end)
    end
  end)
end)
