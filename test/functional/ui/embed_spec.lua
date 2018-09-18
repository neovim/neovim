local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local feed = helpers.feed
local spawn, set_session = helpers.spawn, helpers.set_session
local nvim_prog, nvim_set = helpers.nvim_prog, helpers.nvim_set
local merge_args, prepend_argv = helpers.merge_args, helpers.prepend_argv

describe('--embed UI on startup', function()
  local session, screen
  local function startup(...)
    local nvim_argv = {nvim_prog, '-u', 'NONE', '-i', 'NONE',
                       '--cmd', nvim_set, '--embed'}
    nvim_argv = merge_args(prepend_argv, nvim_argv, {...})
    session = spawn(nvim_argv)
    set_session(session)

    -- attach immediately after startup, for early UI
    screen = Screen.new(60, 8)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
      [2] = {bold = true, foreground = Screen.colors.SeaGreen4},
      [3] = {bold = true, foreground = Screen.colors.Blue1},
    })
  end

  after_each(function()
    session:close()
  end)

  it('can display errors', function()
    startup('--cmd', 'echoerr invalid+')
    screen:expect([[
                                                                  |
                                                                  |
                                                                  |
                                                                  |
      Error detected while processing pre-vimrc command line:     |
      E121: Undefined variable: invalid                           |
      E15: Invalid expression: invalid+                           |
      Press ENTER or type command to continue^                     |
    ]])

    feed('<cr>')
    screen:expect([[
      ^                                                            |
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
                                                                  |
    ]])
  end)

  it("doesn't erase output when setting colors", function()
    startup('--cmd', 'echoerr "foo"', '--cmd', 'color default', '--cmd', 'echoerr "bar"')
    screen:expect([[
                                                                  |
                                                                  |
                                                                  |
                                                                  |
      Error detected while processing pre-vimrc command line:     |
      foo                                                         |
      {1:bar}                                                         |
      {2:Press ENTER or type command to continue}^                     |
    ]])
  end)
end)
