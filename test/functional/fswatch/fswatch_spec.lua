local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local lfs = require('lfs')
local command = helpers.command
local insert = helpers.insert
local clear = helpers.clear
local feed = helpers.feed
local nvim_async = helpers.nvim_async

describe('Autoread', function()
  local screen

  before_each(function()
    clear('--cmd', 'runtime plugin/fswatch.vim')
    screen = Screen.new(45, 10)
    screen:attach()
    screen:set_default_attr_ids({
      EOB={bold = true, foreground = Screen.colors.Blue1},
      T={foreground=Screen.colors.Red},
      RBP1={background=Screen.colors.Red},
      RBP2={background=Screen.colors.Yellow},
      RBP3={background=Screen.colors.Green},
      RBP4={background=Screen.colors.Blue},
      SEP={bold = true, reverse = true},
      CONFIRM={bold = true, foreground = Screen.colors.SeaGreen4},
    })
  end)

  it('filewatcher generate prompt default settings', function()
    local path = 'Xtest-foo'
    helpers.write_file(path, '')

    command('edit '..path)
    insert([[aa bb]])
    command('write')
    screen:expect{grid=[[
      aa b^b                                        |
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      "Xtest-foo" 1L, 6C written                   |
    ]]}

    local expected_additions = [[
    line 1
    line 2
    line 3
    line 4
    ]]

    helpers.write_file(path, expected_additions)
    screen:expect{grid=[[
      aa bb                                        |
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {SEP:                                             }|
      "Xtest-foo" 1L, 6C written                   |
      {CONFIRM:File changed. Would you like to reload?}      |
      {CONFIRM:[Y]es, (N)o: }^                                |
    ]]}
    feed([[<cr>]])
    command('redraw')
  end)

  it('filewatcher generate prompt backup: on', function()
    local path = 'Xtest-foo'
    helpers.write_file(path, '')

    command('set backup')
    command('edit '..path)
    insert([[aa bb]])
    command('write')
    screen:expect{grid=[[
      aa b^b                                        |
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      "Xtest-foo" 1L, 6C written                   |
    ]]}

    local expected_additions = [[
    line 1
    line 2
    line 3
    line 4
    ]]

    helpers.write_file(path, expected_additions)
    screen:expect{grid=[[
      aa bb                                        |
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {SEP:                                             }|
      "Xtest-foo" 1L, 6C written                   |
      {CONFIRM:File changed. Would you like to reload?}      |
      {CONFIRM:[Y]es, (N)o: }^                                |
    ]]}
    feed([[<cr>]])
    command('redraw')
  end)

  it('filewatcher generate prompt backupcopy: yes', function()
    local path = 'Xtest-foo'
    helpers.write_file(path, '')

    command('set nowritebackup')
    command('edit '..path)
    insert([[aa bb]])
    command('write')
    screen:expect{grid=[[
      aa b^b                                        |
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      "Xtest-foo" 1L, 6C written                   |
    ]]}

    local expected_additions = [[
    line 1
    line 2
    line 3
    line 4
    ]]

    helpers.write_file(path, expected_additions)
    screen:expect{grid=[[
      aa bb                                        |
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {SEP:                                             }|
      "Xtest-foo" 1L, 6C written                   |
      {CONFIRM:File changed. Would you like to reload?}      |
      {CONFIRM:[Y]es, (N)o: }^                                |
    ]]}
    feed([[<cr>]])
    command('redraw')
  end)

  it('filewatcher generate prompt writebackup: off', function()
    local path = 'Xtest-foo'
    helpers.write_file(path, '')

    command('set backupcopy=yes')
    command('edit '..path)
    insert([[aa bb]])
    command('write')
    screen:expect{grid=[[
      aa b^b                                        |
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      "Xtest-foo" 1L, 6C written                   |
    ]]}

    local expected_additions = [[
    line 1
    line 2
    line 3
    line 4
    ]]

    helpers.write_file(path, expected_additions)
    screen:expect{grid=[[
      aa bb                                        |
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {EOB:~                                            }|
      {SEP:                                             }|
      "Xtest-foo" 1L, 6C written                   |
      {CONFIRM:File changed. Would you like to reload?}      |
      {CONFIRM:[Y]es, (N)o: }^                                |
    ]]}
    feed([[<cr>]])
    command('redraw')
  end)
end)
