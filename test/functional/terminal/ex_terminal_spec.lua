local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local assert_alive = helpers.assert_alive
local clear, poke_eventloop, nvim = helpers.clear, helpers.poke_eventloop, helpers.nvim
local testprg, source, eq = helpers.testprg, helpers.source, helpers.eq
local feed = helpers.feed
local feed_command, eval = helpers.feed_command, helpers.eval
local funcs = helpers.funcs
local retry = helpers.retry
local ok = helpers.ok
local command = helpers.command
local skip = helpers.skip
local is_os = helpers.is_os
local is_ci = helpers.is_ci

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
    feed([[:terminal "]]..testprg('shell-test')..[[" REP 9999 !terminal_output!<cr>]])
    feed([[<C-\><C-N>]])
    poke_eventloop()
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
    skip(is_ci('cirrus') or is_os('win'))
    if is_os('win') then
      feed_command([[terminal powershell -NoProfile -NoLogo -Command Write-Host -NoNewline "\"$([char]27)[6n\""; Start-Sleep -Milliseconds 500 ]])
    else
      feed_command([[terminal printf '\e[6n'; sleep 0.5 ]])
    end
    screen:expect{any='%^%[%[1;1R'}
  end)

  it("in normal-mode :split does not move cursor", function()
    if is_os('win') then
      feed_command([[terminal for /L \\%I in (1,0,2) do ( echo foo & ping -w 100 -n 1 127.0.0.1 > nul )]])
    else
      feed_command([[terminal while true; do echo foo; sleep .1; done]])
    end
    feed([[<C-\><C-N>M]])  -- move cursor away from last line
    poke_eventloop()
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
      poke_eventloop()
      feed('<CR><CR><CR><CR>')
      poke_eventloop()
      feed([[<C-\><C-N>]])
      poke_eventloop()
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

  it('nvim_get_mode() in :terminal', function()
    command('terminal')
    eq({ blocking=false, mode='nt' }, nvim('get_mode'))
    feed('i')
    eq({ blocking=false, mode='t' }, nvim('get_mode'))
    feed([[<C-\><C-N>]])
    eq({ blocking=false, mode='nt' }, nvim('get_mode'))
  end)

  it(':stopinsert RPC request exits terminal-mode #7807', function()
    command('terminal')
    feed('i[tui] insert-mode')
    eq({ blocking=false, mode='t' }, nvim('get_mode'))
    command('stopinsert')
    feed('<Ignore>')  -- Add input to separate two RPC requests
    eq({ blocking=false, mode='nt' }, nvim('get_mode'))
  end)

  it(':stopinsert in normal mode doesn\'t break insert mode #9889', function()
    command('terminal')
    eq({ blocking=false, mode='nt' }, nvim('get_mode'))
    command('stopinsert')
    feed('<Ignore>')  -- Add input to separate two RPC requests
    eq({ blocking=false, mode='nt' }, nvim('get_mode'))
    feed('a')
    eq({ blocking=false, mode='t' }, nvim('get_mode'))
  end)
end)

describe(':terminal (with fake shell)', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(50, 4)
    screen:attach({rgb=false})
    -- shell-test.c is a fake shell that prints its arguments and exits.
    nvim('set_option_value', 'shell', testprg('shell-test'), {})
    nvim('set_option_value', 'shellcmdflag', 'EXE', {})
    nvim('set_option_value', 'shellxquote', '', {})
  end)

  -- Invokes `:terminal {cmd}` using a fake shell (shell-test.c) which prints
  -- the {cmd} and exits immediately.
  -- When no argument is given and the exit code is zero, the terminal buffer
  -- closes automatically.
  local function terminal_with_fake_shell(cmd)
    feed_command("terminal "..(cmd and cmd or ""))
  end

  it('with no argument, acts like termopen()', function()
    skip(is_os('win'))
    -- Use the EXIT subcommand to end the process with a non-zero exit code to
    -- prevent the buffer from closing automatically
    nvim('set_option_value', 'shellcmdflag', 'EXIT', {})
    terminal_with_fake_shell(1)
    retry(nil, 4 * screen.timeout, function()
    screen:expect([[
      ^                                                  |
      [Process exited 1]                                |
                                                        |
      :terminal 1                                       |
    ]])
    end)
  end)

  it("with no argument, and 'shell' is set to empty string", function()
    nvim('set_option_value', 'shell', '', {})
    terminal_with_fake_shell()
    screen:expect([[
      ^                                                  |
      ~                                                 |
      ~                                                 |
      E91: 'shell' option is empty                      |
    ]])
  end)

  it("with no argument, but 'shell' has arguments, acts like termopen()", function()
    skip(is_os('win'))
    nvim('set_option_value', 'shell', testprg('shell-test')..' -t jeff', {})
    terminal_with_fake_shell()
    screen:expect([[
      ^jeff $                                            |
      [Process exited 0]                                |
                                                        |
      :terminal                                         |
    ]])
  end)

  it('executes a given command through the shell', function()
    skip(is_os('win'))
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
    skip(is_os('win'))
    nvim('set_option_value', 'shell', testprg('shell-test')..' -t jeff', {})
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
    skip(is_os('win'))
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
      poke_eventloop()
      -- Race: Though the shell exited (and streams were closed by SIGCHLD
      -- handler), :terminal cleanup is pending on the main-loop.
      -- This write should be ignored (not crash, #5445).
      feed('iiYYYYYYY')
      assert_alive()
  end)

  it('works with findfile()', function()
    feed_command('terminal')
    eq('term://', string.match(eval('bufname("%")'), "^term://"))
    eq('scripts/shadacat.py', eval('findfile("scripts/shadacat.py", ".")'))
  end)

  it('works with :find', function()
    skip(is_os('win'))
    nvim('set_option_value', 'shellcmdflag', 'EXIT', {})
    terminal_with_fake_shell(1)
    screen:expect([[
      ^                                                  |
      [Process exited 1]                                |
                                                        |
      :terminal 1                                       |
    ]])
    eq('term://', string.match(eval('bufname("%")'), "^term://"))
    feed([[<C-\><C-N>]])
    feed_command([[find */shadacat.py]])
    if is_os('win') then
      eq('scripts\\shadacat.py', eval('bufname("%")'))
    else
      eq('scripts/shadacat.py', eval('bufname("%")'))
    end
  end)

  it('works with gf', function()
    skip(is_os('win'))
    command('set shellxquote=')   -- win: avoid extra quotes
    terminal_with_fake_shell([[echo "scripts/shadacat.py"]])
    retry(nil, 4 * screen.timeout, function()
    screen:expect([[
      ^ready $ echo "scripts/shadacat.py"                |
                                                        |
      [Process exited 0]                                |
      :terminal echo "scripts/shadacat.py"              |
    ]])
    end)
    feed([[<C-\><C-N>]])
    eq('term://', string.match(eval('bufname("%")'), "^term://"))
    feed([[ggf"lgf]])
    eq('scripts/shadacat.py', eval('bufname("%")'))
  end)

  it('with bufhidden=delete #3958', function()
    command('set hidden')
    eq(1, eval('&hidden'))
    command('autocmd BufNew * setlocal bufhidden=delete')
    for _ = 1, 5 do
      source([[
      execute 'edit '.reltimestr(reltime())
      terminal]])
    end
  end)
end)
