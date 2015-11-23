-- Specs for
-- - `system()`
-- - `systemlist()`

local helpers = require('test.functional.helpers')
local eq, clear, eval, feed, nvim =
  helpers.eq, helpers.clear, helpers.eval, helpers.feed, helpers.nvim

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

  it('sets the v:shell_error variable', function()
    eval([[system("sh -c 'exit'")]])
    eq(0, eval('v:shell_error'))
    eval([[system("sh -c 'exit 1'")]])
    eq(1, eval('v:shell_error'))
    eval([[system("sh -c 'exit 5'")]])
    eq(5, eval('v:shell_error'))
    eval([[system('this-should-not-exist')]])
    eq(127, eval('v:shell_error'))
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
      feed(':call system("yes")<cr>')
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
        :call system("yes")                                  |
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

  describe('passing no input', function()
    it('returns the program output', function()
      eq("echoed", eval('system("echo -n echoed")'))
    end)
  end)

  describe('passing input', function()
    it('returns the program output', function()
      eq("input", eval('system("cat -", "input")'))
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

  describe('passing number as input', function()
    it('stringifies the input', function()
      eq('1', eval('system("cat", 1)'))
    end)
  end)

  describe('with output containing NULs', function()
    local fname = 'Xtest'

    setup(create_file_with_nuls(fname))
    teardown(delete_file(fname))

    it('replaces NULs by SOH characters', function()
      eq('part1\001part2\001part3\n', eval('system("cat '..fname..'")'))
    end)
  end)

  describe('passing list as input', function()
    it('joins list items with linefeed characters', function()
      eq('line1\nline2\nline3',
        eval("system('cat -', ['line1', 'line2', 'line3'])"))
    end)

    -- Notice that NULs are converted to SOH when the data is read back. This
    -- is inconsistent and is a good reason for the existence of the
    -- `systemlist()` function, where input and output map to the same
    -- characters(see the following tests with `systemlist()` below)
    describe('with linefeed characters inside list items', function()
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
      pending('skipped (missing xclip)', function() end)
    else
      it('will exit properly after passing input', function()
        eq('', eval([[system('xclip -i -selection clipboard', 'clip-data')]]))
        eq('clip-data', eval([[system('xclip -o -selection clipboard')]]))
      end)
    end
  end)

  describe('command passed as a list', function()
    it('does not execute &shell', function()
      eq('* $NOTHING ~/file',
         eval("system(['echo', '-n', '*', '$NOTHING', '~/file'])"))
    end)
  end)
end)

describe('systemlist()', function()
  -- behavior is similar to `system()` but it returns a list instead of a
  -- string.
  before_each(clear)

  it('sets the v:shell_error variable', function()
    eval([[systemlist("sh -c 'exit'")]])
    eq(0, eval('v:shell_error'))
    eval([[systemlist("sh -c 'exit 1'")]])
    eq(1, eval('v:shell_error'))
    eval([[systemlist("sh -c 'exit 5'")]])
    eq(5, eval('v:shell_error'))
    eval([[systemlist('this-should-not-exist')]])
    eq(127, eval('v:shell_error'))
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

    setup(create_file_with_nuls(fname))
    teardown(delete_file(fname))

    it('replaces NULs by newline characters', function()
      eq({'part1\npart2\npart3'}, eval('systemlist("cat '..fname..'")'))
    end)
  end)

  describe('passing list as input', function()
    it('joins list items with linefeed characters', function()
      eq({'line1', 'line2', 'line3'},
        eval("systemlist('cat -', ['line1', 'line2', 'line3'])"))
    end)

    -- Unlike `system()` which uses SOH to represent NULs, with `systemlist()`
    -- input and ouput are the same
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
      pending('skipped (missing xclip)', function() end)
    else
      it('will exit properly after passing input', function()
        eq({}, eval(
          "systemlist('xclip -i -selection clipboard', ['clip', 'data'])"))
        eq({'clip', 'data'}, eval(
          "systemlist('xclip -o -selection clipboard')"))
      end)
    end
  end)
end)
