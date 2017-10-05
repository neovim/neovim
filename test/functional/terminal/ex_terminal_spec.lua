local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, wait, nvim = helpers.clear, helpers.wait, helpers.nvim
local nvim_dir, source, eq = helpers.nvim_dir, helpers.source, helpers.eq
local feed_command, eval = helpers.feed_command, helpers.eval
local retry = helpers.retry
local iswin = helpers.iswin

describe(':terminal', function()
  if helpers.pending_win32(pending) then return end
  local screen

  before_each(function()
    clear()
    screen = Screen.new(50, 4)
    screen:attach({rgb=false})
  end)

  it("does not interrupt Press-ENTER prompt #2748", function()
    -- Ensure that :messages shows Press-ENTER.
    source([[
      echomsg "msg1"
      echomsg "msg2"
      echomsg "msg3"
    ]])
    -- Invoke a command that emits frequent terminal activity.
    feed_command([[terminal while true; do echo X; done]])
    helpers.feed([[<C-\><C-N>]])
    wait()
    screen:sleep(10)  -- Let some terminal activity happen.
    feed_command("messages")
    screen:expect([[
      msg1                                              |
      msg2                                              |
      msg3                                              |
      Press ENTER or type command to continue^           |
    ]])
  end)

  it("in normal-mode :split does not move cursor", function()
    feed_command([[terminal while true; do echo foo; sleep .1; done]])
    helpers.feed([[<C-\><C-N>M]])  -- move cursor away from last line
    wait()
    eq(3, eval("line('$')"))  -- window height
    eq(2, eval("line('.')"))  -- cursor is in the middle
    feed_command('vsplit')
    eq(2, eval("line('.')"))  -- cursor stays where we put it
    feed_command('split')
    eq(2, eval("line('.')"))  -- cursor stays where we put it
  end)

end)

describe(':terminal (with fake shell)', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(50, 4)
    screen:attach({rgb=false})
    -- shell-test.c is a fake shell that prints its arguments and exits.
    nvim('set_option', 'shell', nvim_dir..'/shell-test')
    nvim('set_option', 'shellcmdflag', 'EXE')
  end)

  -- Invokes `:terminal {cmd}` using a fake shell (shell-test.c) which prints
  -- the {cmd} and exits immediately .
  local function terminal_with_fake_shell(cmd)
    feed_command("terminal "..(cmd and cmd or ""))
  end

  it('with no argument, acts like termopen()', function()
    terminal_with_fake_shell()
    retry(3, 4 * screen.timeout, function()
    screen:expect([[
      ^ready $                                           |
      [Process exited 0]                                |
                                                        |
      :terminal                                         |
    ]])
    end)
  end)

  it("with no argument, and 'shell' is set to empty string", function()
    nvim('set_option', 'shell', '')
    terminal_with_fake_shell()
    screen:expect([[
      ^                                                  |
      ~                                                 |
      ~                                                 |
      E91: 'shell' option is empty                      |
    ]])
  end)

  it("with no argument, but 'shell' has arguments, acts like termopen()", function()
    nvim('set_option', 'shell', nvim_dir..'/shell-test -t jeff')
    terminal_with_fake_shell()
    screen:expect([[
      ^jeff $                                            |
      [Process exited 0]                                |
                                                        |
      :terminal                                         |
    ]])
  end)

  it('executes a given command through the shell', function()
    terminal_with_fake_shell('echo hi')
    screen:expect([[
      ^ready $ echo hi                                   |
                                                        |
      [Process exited 0]                                |
      :terminal echo hi                                 |
    ]])
  end)

  it("executes a given command through the shell, when 'shell' has arguments", function()
    nvim('set_option', 'shell', nvim_dir..'/shell-test -t jeff')
    terminal_with_fake_shell('echo hi')
    screen:expect([[
      ^jeff $ echo hi                                    |
                                                        |
      [Process exited 0]                                |
      :terminal echo hi                                 |
    ]])
  end)

  it('allows quotes and slashes', function()
    terminal_with_fake_shell([[echo 'hello' \ "world"]])
    screen:expect([[
      ^ready $ echo 'hello' \ "world"                    |
                                                        |
      [Process exited 0]                                |
      :terminal echo 'hello' \ "world"                  |
    ]])
  end)

  it('ex_terminal() double-free #4554', function()
    source([[
      autocmd BufNew * set shell=foo
      terminal]])
      -- Verify that BufNew actually fired (else the test is invalid).
    eq('foo', eval('&shell'))
  end)

  it('ignores writes if the backing stream closes', function()
      terminal_with_fake_shell()
      helpers.feed('iiXXXXXXX')
      wait()
      -- Race: Though the shell exited (and streams were closed by SIGCHLD
      -- handler), :terminal cleanup is pending on the main-loop.
      -- This write should be ignored (not crash, #5445).
      helpers.feed('iiYYYYYYY')
      eq(2, eval("1+1"))  -- Still alive?
  end)

  it('works with findfile()', function()
    feed_command('terminal')
    eq('term://', string.match(eval('bufname("%")'), "^term://"))
    eq('scripts/shadacat.py', eval('findfile("scripts/shadacat.py", ".")'))
  end)

  it('works with :find', function()
    terminal_with_fake_shell()
    screen:expect([[
      ^ready $                                           |
      [Process exited 0]                                |
                                                        |
      :terminal                                         |
    ]])
    eq('term://', string.match(eval('bufname("%")'), "^term://"))
    helpers.feed([[<C-\><C-N>]])
    feed_command([[find */shadacat.py]])
    if iswin() then
      eq('scripts\\shadacat.py', eval('bufname("%")'))
    else
      eq('scripts/shadacat.py', eval('bufname("%")'))
    end
  end)

  it('works with gf', function()
    terminal_with_fake_shell([[echo "scripts/shadacat.py"]])
    screen:expect([[
      ^ready $ echo "scripts/shadacat.py"                |
                                                        |
      [Process exited 0]                                |
      :terminal echo "scripts/shadacat.py"              |
    ]])
    helpers.feed([[<C-\><C-N>]])
    eq('term://', string.match(eval('bufname("%")'), "^term://"))
    helpers.feed([[ggf"lgf]])
    eq('scripts/shadacat.py', eval('bufname("%")'))
  end)

end)
