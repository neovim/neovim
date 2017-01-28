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
  end)

  it("does not interrupt Press-ENTER prompt #2748", function()
    -- Ensure that :messages shows Press-ENTER.
    source([[
      echomsg "msg1"
      echomsg "msg2"
    ]])
    -- Invoke a command that emits frequent terminal activity.
    execute([[terminal while true; do echo X; done]])
    helpers.feed([[<C-\><C-N>]])
    screen:expect([[
      X                                                 |
      X                                                 |
      ^X                                                 |
                                                        |
    ]])
    helpers.sleep(10)  -- Let some terminal activity happen.
    execute("messages")
    screen:expect([[
      X                                                 |
      msg1                                              |
      msg2                                              |
      Press ENTER or type command to continue^           |
    ]])
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
    execute("terminal "..(cmd and cmd or ""))
  end

  it('with no argument, acts like termopen()', function()
    terminal_with_fake_shell()
    wait()
    screen:expect([[
      ready $                                           |
      [Process exited 0]                                |
                                                        |
      -- TERMINAL --                                    |
    ]])
  end)

  it('executes a given command through the shell', function()
    terminal_with_fake_shell('echo hi')
    wait()
    screen:expect([[
      ready $ echo hi                                   |
                                                        |
      [Process exited 0]                                |
      -- TERMINAL --                                    |
    ]])
  end)

  it('allows quotes and slashes', function()
    terminal_with_fake_shell([[echo 'hello' \ "world"]])
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
      terminal_with_fake_shell()
      helpers.feed('iiXXXXXXX')
      wait()
      -- Race: Though the shell exited (and streams were closed by SIGCHLD
      -- handler), :terminal cleanup is pending on the main-loop.
      -- This write should be ignored (not crash, #5445).
      helpers.feed('iiYYYYYYY')
      eq(2, eval("1+1"))  -- Still alive?
  end)

  describe('works with', function()
    it('findfile()', function()
      source('terminal')
      eq(1, nvim('eval', 'bufname("%") =~# "^term://"'))
      eq('scripts/shadacat.py', nvim('call_function',
                                     'findfile', {'scripts/shadacat.py', '.'}))
    end)

    it(':find', function()
      terminal_with_fake_shell()
      wait()
      screen:expect([[
        ready $                                           |
        [Process exited 0]                                |
                                                          |
        -- TERMINAL --                                    |
      ]])
      eq(1, nvim('eval', 'bufname("%") =~# "^term://"'))
      helpers.feed([[<C-\><C-N>]])
      wait()
      execute([[find */shadacat.py]])
      wait()
      eq(1, nvim('eval', 'bufname("%") ==# "scripts/shadacat.py"'))
    end)

    it('gf', function()
      terminal_with_fake_shell([[echo "scripts/shadacat.py"]])
      wait()
      screen:expect([[
        ready $ echo "scripts/shadacat.py"                |
                                                          |
        [Process exited 0]                                |
        -- TERMINAL --                                    |
      ]])
      helpers.feed([[<C-\><C-N>]])
      wait()
      eq(1, nvim('eval', 'bufname("%") =~# "^term://"'))
      execute([[normal! ggf"lgf]])
      eq(1, nvim('eval', 'bufname("%") ==# "scripts/shadacat.py"'))
    end)
  end)

end)
