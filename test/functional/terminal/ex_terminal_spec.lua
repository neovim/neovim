local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, wait, nvim = helpers.clear, helpers.wait, helpers.nvim
local nvim_dir, source, eq = helpers.nvim_dir, helpers.source, helpers.eq
local execute, eval = helpers.execute, helpers.eval
local funcs = helpers.funcs

if helpers.pending_win32(pending) then return end

describe(':terminal', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(50, 4)
    screen:attach({rgb=false})
    nvim('set_option', 'shell', nvim_dir..'/shell-test')
    nvim('set_option', 'shellcmdflag', 'EXE')

  end)

  it('with no argument, acts like termopen()', function()
    execute('terminal')
    wait()
    screen:expect([[
      ready $                                           |
      [Process exited 0]                                |
                                                        |
      -- TERMINAL --                                    |
    ]])
  end)

  it('executes a given command through the shell', function()
    execute('terminal echo hi')
    wait()
    screen:expect([[
      ready $ echo hi                                   |
                                                        |
      [Process exited 0]                                |
      -- TERMINAL --                                    |
    ]])
  end)

  it('allows quotes and slashes', function()
    execute([[terminal echo 'hello' \ "world"]])
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

  it('re-edit terminal buffer', function()
      execute('terminal')
      execute('argadd')
      local a=funcs.bufname('%')
      execute('argu 1')
      local b=funcs.bufname('%')
      eq(a,b)
  end)

end)
