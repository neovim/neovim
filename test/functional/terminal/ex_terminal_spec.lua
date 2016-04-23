local helpers = require('test.functional.helpers')
local Screen = require('test.functional.ui.screen')
local clear, wait, nvim = helpers.clear, helpers.wait, helpers.nvim
local nvim_dir = helpers.nvim_dir
local execute = helpers.execute

describe(':terminal', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(50, 7)
    screen:attach(false)
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
                                                        |
                                                        |
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
                                                        |
                                                        |
                                                        |
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
                                                        |
                                                        |
                                                        |
      -- TERMINAL --                                    |
    ]])
  end)
end)
