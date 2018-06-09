local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, wait, nvim = helpers.clear, helpers.wait, helpers.nvim
local nvim_dir, source, eq = helpers.nvim_dir, helpers.source, helpers.eq
local feed = helpers.feed
local feed_command, eval = helpers.feed_command, helpers.eval
local funcs = helpers.funcs
local retry = helpers.retry
local ok = helpers.ok
local iswin = helpers.iswin
local command = helpers.command

describe(':terminal', function()
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
    if iswin() then
      feed_command([[terminal for /L \%I in (1,0,2) do echo \%I]])
    else
      feed_command([[terminal while true; do echo X; done]])
    end
    feed([[<C-\><C-N>]])
    wait()
    -- Wait for some terminal activity.
    retry(nil, 4000, function()
      ok(funcs.line('$') > 6)
    end)
    feed_command("messages")
    screen:expect([[
      msg1                                              |
      msg2                                              |
      msg3                                              |
      Press ENTER or type command to continue^           |
    ]])
  end)

  it("reads output buffer on terminal reporting #4151", function()
    if helpers.pending_win32(pending) then return end
    if iswin() then
      feed_command([[terminal powershell -NoProfile -NoLogo -Command Write-Host -NoNewline "\"$([char]27)[6n\""; Start-Sleep -Milliseconds 500 ]])
    else
      feed_command([[terminal printf '\e[6n'; sleep 0.5 ]])
    end
    screen:expect('%^%[%[1;1R', nil, nil, nil, true)
  end)

  it("in normal-mode :split does not move cursor", function()
    if iswin() then
      feed_command([[terminal for /L \\%I in (1,0,2) do ( echo foo & ping -w 100 -n 1 127.0.0.1 > nul )]])
    else
      feed_command([[terminal while true; do echo foo; sleep .1; done]])
    end
    feed([[<C-\><C-N>M]])  -- move cursor away from last line
    wait()
    eq(3, eval("line('$')"))  -- window height
    eq(2, eval("line('.')"))  -- cursor is in the middle
    feed_command('vsplit')
    eq(2, eval("line('.')"))  -- cursor stays where we put it
    feed_command('split')
    eq(2, eval("line('.')"))  -- cursor stays where we put it
  end)

  it('Enter/Leave does not increment jumplist #3723', function()
    feed_command('terminal')
    local function enter_and_leave()
      local lines_before = funcs.line('$')
      -- Create a new line (in the shell). For a normal buffer this
      -- increments the jumplist; for a terminal-buffer it should not. #3723
      feed('i')
      wait()
      feed('<CR><CR><CR><CR>')
      wait()
      feed([[<C-\><C-N>]])
      wait()
      -- Wait for >=1 lines to be created.
      retry(nil, 4000, function()
        ok(funcs.line('$') > lines_before)
      end)
    end
    enter_and_leave()
    enter_and_leave()
    enter_and_leave()
    ok(funcs.line('$') > 6)   -- Verify assumption.
    local jumps = funcs.split(funcs.execute('jumps'), '\n')
    eq(' jump line  col file/text', jumps[1])
    eq(3, #jumps)
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
    command('set shellxquote=')   -- win: avoid extra quotes
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
    command('set shellxquote=')   -- win: avoid extra quotes
    terminal_with_fake_shell('echo hi')
    screen:expect([[
      ^jeff $ echo hi                                    |
                                                        |
      [Process exited 0]                                |
      :terminal echo hi                                 |
    ]])
  end)

  it('allows quotes and slashes', function()
    command('set shellxquote=')   -- win: avoid extra quotes
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
      feed('iiXXXXXXX')
      wait()
      -- Race: Though the shell exited (and streams were closed by SIGCHLD
      -- handler), :terminal cleanup is pending on the main-loop.
      -- This write should be ignored (not crash, #5445).
      feed('iiYYYYYYY')
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
    feed([[<C-\><C-N>]])
    feed_command([[find */shadacat.py]])
    if iswin() then
      eq('scripts\\shadacat.py', eval('bufname("%")'))
    else
      eq('scripts/shadacat.py', eval('bufname("%")'))
    end
  end)

  it('works with gf', function()
    command('set shellxquote=')   -- win: avoid extra quotes
    terminal_with_fake_shell([[echo "scripts/shadacat.py"]])
    screen:expect([[
      ^ready $ echo "scripts/shadacat.py"                |
                                                        |
      [Process exited 0]                                |
      :terminal echo "scripts/shadacat.py"              |
    ]])
    feed([[<C-\><C-N>]])
    eq('term://', string.match(eval('bufname("%")'), "^term://"))
    feed([[ggf"lgf]])
    eq('scripts/shadacat.py', eval('bufname("%")'))
  end)

end)
