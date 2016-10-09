local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, wait, nvim = helpers.clear, helpers.wait, helpers.nvim
local nvim_dir, source, eq = helpers.nvim_dir, helpers.source, helpers.eq
local execute, eval = helpers.execute, helpers.eval

if helpers.pending_win32(pending) then return end

describe(':terminal', function()
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
  local function terminal_run_fake_shell_cmd(cmd)
    execute("terminal "..(cmd and cmd or ""))
  end

  it('with no argument, acts like termopen()', function()
    terminal_run_fake_shell_cmd()
    wait()
    screen:expect([[
      ready $                                           |
      [Process exited 0]                                |
                                                        |
      -- TERMINAL --                                    |
    ]])
  end)

  it('executes a given command through the shell', function()
    terminal_run_fake_shell_cmd('echo hi')
    wait()
    screen:expect([[
      ready $ echo hi                                   |
                                                        |
      [Process exited 0]                                |
      -- TERMINAL --                                    |
    ]])
  end)

  it('allows quotes and slashes', function()
    terminal_run_fake_shell_cmd([[echo 'hello' \ "world"]])
    wait()
    screen:expect([[
      ready $ echo 'hello' \ "world"                    |
                                                        |
      [Process exited 0]                                |
      -- TERMINAL --                                    |
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
      terminal_run_fake_shell_cmd()
      helpers.feed('iiXXXXXXX')
      wait()
      -- Race: Though the shell exited (and streams were closed by SIGCHLD
      -- handler), :terminal cleanup is pending on the main-loop.
      -- This write should be ignored (not crash, #5445).
      helpers.feed('iiYYYYYYY')
      wait()
  end)

end)
