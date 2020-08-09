local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local lfs = require('lfs')
local command = helpers.command
local clear = helpers.clear
local feed = helpers.feed
local thelpers = require('test.functional.terminal.helpers')
local nvim_prog = helpers.nvim_prog
local feed_command = helpers.feed_command
local feed_data = thelpers.feed_data

describe('fcnotify watcher', function()
  local screen

  before_each(function()
    clear('--cmd', 'runtime plugin/fcnotify.vim')
    screen = Screen.new(50, 10)
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

  it('autoread unmodified buffer', function()
    local path = 'Xtest-foo'
    helpers.write_file(path, 'aa bb')
    lfs.touch(path, os.time() - 10)
    command('set fcnotify=autoread,watcher')

    command('edit '..path)
    screen:expect{grid=[[
      ^aa bb                                             |
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      Xtest-foo not exists                              |
    ]]}

    local expected_additions = [[
    line 1
    line 2
    line 3
    line 4
    ]]

    helpers.write_file(path, expected_additions)
    screen:expect{grid=[[
      ^line 1                                            |
      line 2                                            |
      line 3                                            |
      line 4                                            |
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      "Xtest-foo" 4L, 28C                               |
    ]]}
  end)

  it('autoread modified buffer', function()
    local path = 'Xtest-foo'
    helpers.write_file(path, 'aa bb')
    lfs.touch(path, os.time() - 10)
    command('set fcnotify=autoread,watcher')

    command('edit '..path)
    feed([[o]])
    feed([[<esc>]])
    screen:expect{grid=[[
      aa bb                                             |
      ^                                                  |
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
                                                        |
    ]]}


    local expected_additions = [[
    line 1
    line 2
    line 3
    line 4
    ]]

    helpers.write_file(path, expected_additions)
    screen:expect{grid=[[
      aa bb                                             |
                                                        |
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {SEP:                                                  }|
                                                        |
      {CONFIRM:W12: Warning: File "Xtest-foo" has changed and the}|
      {CONFIRM: buffer was changed in Vim as well}                |
      {CONFIRM:See ":help W12" for more info.}                    |
      {CONFIRM:[O]K, (S)how diff, (L)oad File: }^                  |
    ]]}
  end)

  it('without autoread', function()
    local path = 'Xtest-foo'
    helpers.write_file(path, 'aa bb')
    lfs.touch(path, os.time() - 10)
    command('set fcnotify=watcher')

    command('edit '..path)
    screen:expect{grid=[[
      ^aa bb                                             |
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      Xtest-foo not exists                              |
    ]]}

    local expected_additions = [[
    line 1
    line 2
    line 3
    line 4
    ]]

    helpers.write_file(path, expected_additions)
    screen:expect{grid=[[
      aa bb                                             |
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {EOB:~                                                 }|
      {SEP:                                                  }|
      Xtest-foo not exists                              |
      {CONFIRM:W11: Warning: File "Xtest-foo" has changed since e}|
      {CONFIRM:diting started}                                    |
      {CONFIRM:See ":help W11" for more info.}                    |
      {CONFIRM:[O]K, (S)how diff, (L)oad File: }^                  |
    ]]}

  end)
end)

if helpers.pending_win32(pending) then return end

describe('fcnotify onfocus', function()
  local screen

  before_each(function()
    clear()
    screen = thelpers.screen_setup(0, '["'..nvim_prog
      ..'", "-u", "NONE", "-i", "NONE", "--cmd", "set noswapfile noshowcmd noruler"]')
  end)

  it('autoread with unmodified buffer', function()
    local path = 'xtest-foo'
    local expected_addition = [[
    line 1
    line 2
    line 3
    line 4
    ]]

    helpers.write_file(path, '')
    lfs.touch(path, os.time() - 10)
    feed_command('edit '..path)
    feed_data('\027[O')

    screen:expect{grid=[[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:xtest-foo                                         }|
      :edit xtest-foo                                   |
      {3:-- TERMINAL --}                                    |
    ]]}

    helpers.write_file(path, expected_addition)

    feed_data('\027[I')

    screen:expect{grid=[[
      {1:l}ine 1                                            |
      line 2                                            |
      line 3                                            |
      line 4                                            |
      {5:xtest-foo                                         }|
      "xtest-foo" 4L, 28C                               |
      {3:-- TERMINAL --}                                    |
    ]]}
  end)

  it('autoread with modified buffer', function()
    local path = 'xtest-foo'
    local expected_addition = [[
    line 1
    line 2
    line 3
    line 4
    ]]

    helpers.write_file(path, '')
    lfs.touch(path, os.time() - 10)
    feed_command('edit '..path)
    feed_data([[o]])
    feed_data('\027[O')
    screen:expect{grid=[[
                                                        |
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {5:xtest-foo [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]]}

    helpers.write_file(path, expected_addition)

    feed_data('\027[I')
    screen:expect{grid=[[
      {5:                                                  }|
      {3:-- INSERT --}                                      |
      {10:W12: Warning: File "xtest-foo" has changed and the}|
      {10: buffer was changed in Vim as well}                |
      {10:See ":help W12" for more info.}                    |
      {10:[O]K, (S)how diff, (L)oad File: }{1: }                 |
      {3:-- TERMINAL --}                                    |
    ]]}
  end)

  it('without autoread', function()
    local path = 'xtest-foo'
    local expected_addition = [[
    line 1
    line 2
    line 3
    line 4
    ]]

    helpers.write_file(path, '')
    lfs.touch(path, os.time() - 10)
    feed_command('edit '..path)
    feed_data('\027[O')
    screen:expect{grid=[[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:xtest-foo                                         }|
      :edit xtest-foo                                   |
      {3:-- TERMINAL --}                                    |
    ]]}

    helpers.write_file(path, expected_addition)

    feed_data('\027[I')
    screen:expect{grid=[[
      {1:l}ine 1                                            |
      line 2                                            |
      line 3                                            |
      line 4                                            |
      {5:xtest-foo                                         }|
      "xtest-foo" 4L, 28C                               |
      {3:-- TERMINAL --}                                    |
    ]]}
  end)
end)
