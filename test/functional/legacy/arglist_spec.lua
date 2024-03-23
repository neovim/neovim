-- Test argument list commands

local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, command, eq = helpers.clear, helpers.command, helpers.eq
local expect_exit = helpers.expect_exit
local feed = helpers.feed
local pcall_err = helpers.pcall_err

describe('argument list commands', function()
  before_each(clear)

  it('quitting Vim with unedited files in the argument list throws E173', function()
    command('set nomore')
    command('args a b c')
    eq('Vim(quit):E173: 2 more files to edit', pcall_err(command, 'quit'))
  end)

  it(':confirm quit with unedited files in arglist', function()
    local screen = Screen.new(60, 6)
    screen:attach()
    command('set nomore')
    command('args a b c')
    feed(':confirm quit\n')
    screen:expect([[
                                                                  |
      {1:~                                                           }|
      {3:                                                            }|
      :confirm quit                                               |
      {6:2 more files to edit.  Quit anyway?}                         |
      {6:[Y]es, (N)o: }^                                               |
    ]])
    feed('N')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*4
                                                                  |
    ]])
    feed(':confirm quit\n')
    screen:expect([[
                                                                  |
      {1:~                                                           }|
      {3:                                                            }|
      :confirm quit                                               |
      {6:2 more files to edit.  Quit anyway?}                         |
      {6:[Y]es, (N)o: }^                                               |
    ]])
    expect_exit(1000, feed, 'Y')
  end)
end)
