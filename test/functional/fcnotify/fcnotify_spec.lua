local helpers = require('test.functional.helpers')(after_each)
local lfs = require('lfs')
local clear = helpers.clear
local thelpers = require('test.functional.terminal.helpers')
local nvim_prog = helpers.nvim_prog
local feed_command = helpers.feed_command
local feed_data = thelpers.feed_data

if helpers.pending_win32(pending) then return end

describe('fcnotify watcher', function()
  local screen

  before_each(function()
    clear()
    screen = thelpers.screen_setup(5, '["'..nvim_prog
      ..'", "-u", "NONE", "-i", "NONE", "--cmd", "set noswapfile noshowcmd noruler", "--cmd", "runtime plugin/fcnotify.vim"]')
    feed_data('\027[I')
  end)

  it('autoread unmodified buffer', function()
    local path = 'Xtest-foo'
    helpers.write_file(path, 'aa bb')
    lfs.touch(path, os.time() - 10)
    feed_command('set fcnotify=autoread,watcher')

    feed_command('edit '..path)
    screen:expect{grid=[[
      {1:a}a bb                                             |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:Xtest-foo                                         }|
      :edit Xtest-foo                                   |
      {3:-- TERMINAL --}                                    |
    ]]}

    local expected_additions = [[
    line 1
    line 2
    line 3
    line 4
    ]]

    helpers.write_file(path, expected_additions)
    screen:expect{grid=[[
      {1:l}ine 1                                            |
      line 2                                            |
      line 3                                            |
      line 4                                            |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:Xtest-foo                                         }|
      "Xtest-foo" 4L, 28C                               |
      {3:-- TERMINAL --}                                    |
    ]]}
  end)

  it('autoread with modified buffer', function()
    local path = 'Xtest-foo'
    local expected_addition = [[
    line 1
    line 2
    line 3
    line 4
    ]]

    helpers.write_file(path, '')
    lfs.touch(path, os.time() - 10)
    feed_command('edit '..path)
    feed_command('set fcnotify=autoread,watcher')
    feed_data([[o]])
    screen:expect{grid=[[
                                                        |
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:Xtest-foo [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]]}

    helpers.write_file(path, expected_addition)
    screen:expect{grid=[[
                                                        |
                                                        |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:                                                  }|
      {3:-- INSERT --}                                      |
      {10:W12: Warning: File "Xtest-foo" has changed and the}|
      {10: buffer was changed in Vim as well}                |
      {10:See ":help W12" for more info.}                    |
      {10:[O]K, (S)how diff, (L)oad File: }{1: }                 |
      {3:-- TERMINAL --}                                    |
    ]]}
  end)

  it('watcher', function()
    local path = 'Xtest-foo'
    helpers.write_file(path, 'aa bb')
    lfs.touch(path, os.time() - 10)
    feed_command('set fcnotify=watcher')

    feed_command('edit '..path)
    feed_command('set fcnotify=watcher')
    screen:expect{grid=[[
      {1:a}a bb                                             |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:Xtest-foo                                         }|
      :set fcnotify=watcher                             |
      {3:-- TERMINAL --}                                    |
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
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:                                                  }|
      :set fcnotify=watcher                             |
      {10:W11: Warning: File "Xtest-foo" has changed since e}|
      {10:diting started}                                    |
      {10:See ":help W11" for more info.}                    |
      {10:[O]K, (S)how diff, (L)oad File: }{1: }                 |
      {3:-- TERMINAL --}                                    |
    ]]}
  end)
end)

describe('fcnotify onfocus', function()
  local screen

  before_each(function()
    clear()
    screen = thelpers.screen_setup(0, '["'..nvim_prog
      ..'", "-u", "NONE", "-i", "NONE", "--cmd", "set noswapfile noshowcmd noruler"]')
  end)

  it('autoread with unmodified buffer', function()
    local path = 'Xtest-foo'
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
      {5:Xtest-foo                                         }|
      :edit Xtest-foo                                   |
      {3:-- TERMINAL --}                                    |
    ]]}

    helpers.write_file(path, expected_addition)

    feed_data('\027[I')

    screen:expect{grid=[[
      {1:l}ine 1                                            |
      line 2                                            |
      line 3                                            |
      line 4                                            |
      {5:Xtest-foo                                         }|
      "Xtest-foo" 4L, 28C                               |
      {3:-- TERMINAL --}                                    |
    ]]}
  end)

  it('autoread with modified buffer', function()
    local path = 'Xtest-foo'
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
      {5:Xtest-foo [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]]}

    helpers.write_file(path, expected_addition)

    feed_data('\027[I')
    screen:expect{grid=[[
      {5:                                                  }|
      {3:-- INSERT --}                                      |
      {10:W12: Warning: File "Xtest-foo" has changed and the}|
      {10: buffer was changed in Vim as well}                |
      {10:See ":help W12" for more info.}                    |
      {10:[O]K, (S)how diff, (L)oad File: }{1: }                 |
      {3:-- TERMINAL --}                                    |
    ]]}
  end)

  it('without autoread', function()
    local path = 'Xtest-foo'
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
      {5:Xtest-foo                                         }|
      :edit Xtest-foo                                   |
      {3:-- TERMINAL --}                                    |
    ]]}

    helpers.write_file(path, expected_addition)

    feed_data('\027[I')
    screen:expect{grid=[[
      {1:l}ine 1                                            |
      line 2                                            |
      line 3                                            |
      line 4                                            |
      {5:Xtest-foo                                         }|
      "Xtest-foo" 4L, 28C                               |
      {3:-- TERMINAL --}                                    |
    ]]}
  end)
end)
