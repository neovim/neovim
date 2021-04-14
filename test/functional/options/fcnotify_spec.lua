local helpers = require('test.functional.helpers')(after_each)
local lfs = require('lfs')
local clear = helpers.clear
local thelpers = require('test.functional.terminal.helpers')
local nvim_prog = helpers.nvim_prog
local feed_command = helpers.feed_command
local feed = helpers.feed
local feed_data = thelpers.feed_data
local Screen = require('test.functional.ui.screen')

local attr_ids = {
  [1] = {reverse = true};
  [2] = {background = tonumber('0x00000b')};
  [3] = {bold = true};
  [4] = {foreground = tonumber('0x00000c')};
  [5] = {reverse = true, bold = true};
  [7] = {foreground = tonumber('0x000082')};
  [8] = {background = tonumber('0x000001'), foreground = tonumber('0x00000f')};
  [9] = {foreground = tonumber('0x000004')};
  [10] = {foreground = tonumber('0x000079')};
  [11] = {foreground = tonumber('0x00000b')};
  [12] = {reverse = true, foreground = tonumber('0x000079')};
  [13] = {foreground = tonumber('0x0000e1')};
  [14] = {foreground = Screen.colors.Magenta, bold = true};
  [15] = {foreground = Screen.colors.SeaGreen4, bold = true};
  [16] = {foreground = Screen.colors.Blue, bold = true};
}

describe('fcnotify watcher', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(40, 10);
    screen:attach()
    screen:set_default_attr_ids(attr_ids)
    feed_command('runtime plugin/fcnotify.vim')
  end)

  it('off autocommands', function()
    feed_command('set fcnotify=off')

    feed_command('autocmd fcnotify')
    screen:expect{grid=[[
                                              |
      {5:                                        }|
      :autocmd fcnotify                       |
      {14:--- Autocommands ---}                    |
      {14:fcnotify}  {14:OptionSet}                     |
          filechangenotify                    |
                    call v:lua.vim.fcnotify.ha|
      ndle_option_set(v:option_type, v:option_|
      new)                                    |
      {15:Press ENTER or type command to continue}^ |
    ]]}
  end)

  it('on autocommands', function()
    feed_command('set fcnotify=autoread,onfocus')

    feed_command('autocmd fcnotify')
    screen:expect{grid=[[
      andle_focus_gained()                    |
      {14:fcnotify}  {14:FocusLost}                     |
          *         call v:lua.vim.fcnotify.ha|
      ndle_focus_lost()                       |
      {14:fcnotify}  {14:OptionSet}                     |
          filechangenotify                    |
                    call v:lua.vim.fcnotify.ha|
      ndle_option_set(v:option_type, v:option_|
      new)                                    |
      {15:Press ENTER or type command to continue}^ |
    ]]}
  end)
end)

-- Do not perform tests on windows/appveyor since terminal tests
-- aren't working
if helpers.pending_win32(pending) then return end

describe('fcnotify watcher', function()
  local screen
  local path = 'Xtest-fcnotify'
  local expected_addition = [[
  line 1
  line 2
  line 3
  line 4
  ]]

  before_each(function()
    clear()
    screen = Screen.new(40,10)
    screen:attach()
    screen:set_default_attr_ids(attr_ids)
    helpers.write_file(path, 'aa bb')
    lfs.touch(path, os.time() - 10)
    feed_command('runtime plugin/fcnotify.vim')
  end)

  after_each(function()
    os.remove(path)
  end)

  it('autoread unmodified buffer', function()
    feed_command('set fcnotify=autoread,watcher')

    feed_command('edit '..path)
    screen:expect{grid=[[
      ^aa bb                                   |
      {16:~                                       }|
      {16:~                                       }|
      {16:~                                       }|
      {16:~                                       }|
      {16:~                                       }|
      {16:~                                       }|
      {16:~                                       }|
      {16:~                                       }|
      :edit Xtest-fcnotify                    |
    ]]}

    helpers.write_file(path, expected_addition)
    screen:expect{grid=[[
      ^line 1                                  |
      line 2                                  |
      line 3                                  |
      line 4                                  |
      {16:~                                       }|
      {16:~                                       }|
      {16:~                                       }|
      {16:~                                       }|
      {16:~                                       }|
      "Xtest-fcnotify" 4L, 28C                |
    ]]}
  end)

  it('autoread with modified buffer', function()
    feed_command('edit '..path)
    feed_command('set fcnotify=autoread,watcher')
    feed([[o]])
    screen:expect{grid=[[
      aa bb                                   |
      ^                                        |
      {16:~                                       }|
      {16:~                                       }|
      {16:~                                       }|
      {16:~                                       }|
      {16:~                                       }|
      {16:~                                       }|
      {16:~                                       }|
      {3:-- INSERT --}                            |
    ]]}

    helpers.write_file(path, expected_addition)
    screen:expect{grid=[[
      aa bb                                   |
                                              |
      {16:~                                       }|
      {5:                                        }|
      {3:-- INSERT --}                            |
      {15:W12: Warning: File "Xtest-fcnotify" has }|
      {15:changed and the buffer was changed in Vi}|
      {15:m as well}                               |
      {15:See ":help W12" for more info.}          |
      {15:[O]K, (S)how diff, (L)oad File: }^        |
    ]]}
  end)

  it('without autoread', function()
    feed_command('set fcnotify=watcher')

    feed_command('edit '..path)
    screen:expect{grid=[[
      ^aa bb                                   |
      {16:~                                       }|
      {16:~                                       }|
      {16:~                                       }|
      {16:~                                       }|
      {16:~                                       }|
      {16:~                                       }|
      {16:~                                       }|
      {16:~                                       }|
      :edit Xtest-fcnotify                    |
    ]]}

    helpers.write_file(path, expected_addition)
    screen:expect{grid=[[
      aa bb                                   |
      {16:~                                       }|
      {16:~                                       }|
      {16:~                                       }|
      {5:                                        }|
      :edit Xtest-fcnotify                    |
      {15:W11: Warning: File "Xtest-fcnotify" has }|
      {15:changed since editing started}           |
      {15:See ":help W11" for more info.}          |
      {15:[O]K, (S)how diff, (L)oad File: }^        |
    ]]}
  end)
end)

describe('fcnotify onfocus', function()
  local screen
  local path = 'Xtest-fcnotify'
  local expected_addition = [[
  line 1
  line 2
  line 3
  line 4
  ]]

  before_each(function()
    clear()
    screen = thelpers.screen_setup(0, '["'..nvim_prog
    ..'", "-u", "NONE", "-i", "NONE", "--cmd", "set noswapfile noshowcmd noruler"]')
    screen:set_default_attr_ids(attr_ids)
    os.remove(path)
  end)

  after_each(function()
    os.remove(path)
  end)

  it('autoread with unmodified buffer', function()
    helpers.write_file(path, '')
    lfs.touch(path, os.time() - 10)
    feed_command('set fcnotify=autoread,onfocus')
    feed_command('edit '..path)
    feed_data('\027[O')
    screen:expect{grid=[[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:Xtest-fcnotify                                    }|
      :edit Xtest-fcnotify                              |
      {3:-- TERMINAL --}                                    |
    ]]}

    helpers.write_file(path, expected_addition)

    feed_data('\027[I')
    screen:expect{grid=[[
      {1:l}ine 1                                            |
      line 2                                            |
      line 3                                            |
      line 4                                            |
      {5:Xtest-fcnotify                                    }|
      "Xtest-fcnotify" 4L, 28C                          |
      {3:-- TERMINAL --}                                    |
    ]]}
  end)

  it('autoread with modified buffer', function()
    helpers.write_file(path, '')
    lfs.touch(path, os.time() - 10)
    feed_command('set fcnotify=autoread,onfocus')
    feed_command('edit '..path)
    feed_data([[o]])
    feed_data('\027[O')
    screen:expect{grid=[[
                                                        |
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {5:Xtest-fcnotify [+]                                }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]]}

    helpers.write_file(path, expected_addition)

    feed_data('\027[I')
    screen:expect{grid=[[
      {5:                                                  }|
      {3:-- INSERT --}                                      |
      {10:W12: Warning: File "Xtest-fcnotify" has changed an}|
      {10:d the buffer was changed in Vim as well}           |
      {10:See ":help W12" for more info.}                    |
      {10:[O]K, (S)how diff, (L)oad File: }{1: }                 |
      {3:-- TERMINAL --}                                    |
    ]]}
  end)

  it('without autoread', function()
    helpers.write_file(path, '')
    lfs.touch(path, os.time() - 10)
    feed_command('edit '..path)
    feed_command('set fcnotify=onfocus')
    feed_data('\027[O')
    screen:expect{grid=[[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:Xtest-fcnotify                                    }|
      :set fcnotify=onfocus                             |
      {3:-- TERMINAL --}                                    |
    ]]}

    helpers.write_file(path, expected_addition)
    feed_data('\027[I')
    screen:expect{grid=[[
      {5:                                                  }|
      :set fcnotify=onfocus                             |
      {10:W11: Warning: File "Xtest-fcnotify" has changed si}|
      {10:nce editing started}                               |
      {10:See ":help W11" for more info.}                    |
      {10:[O]K, (S)how diff, (L)oad File: }{1: }                 |
      {3:-- TERMINAL --}                                    |
    ]]}
  end)
end)
