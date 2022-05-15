local helpers = require('test.functional.helpers')(after_each)

local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local exec = helpers.exec
local feed = helpers.feed
local command = helpers.command

describe('display', function()
  before_each(clear)

  it('scroll when modified at topline vim-patch:8.2.1488', function()
    local screen = Screen.new(20, 4)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = {bold = true},
    })

    command([[call setline(1, repeat('a', 21))]])
    feed('O')
    screen:expect([[
      ^                    |
      aaaaaaaaaaaaaaaaaaaa|
      a                   |
      {1:-- INSERT --}        |
    ]])
  end)

  it('scrolling when modified at topline in Visual mode vim-patch:8.2.4626', function()
    local screen = Screen.new(60, 8)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = {bold = true},  -- ModeMsg
      [2] = {background = Screen.colors.LightGrey},  -- Visual
      [3] = {background = Screen.colors.Grey, foreground = Screen.colors.DarkBlue},  -- SignColumn
    })

    exec([[
      set scrolloff=0
      call setline(1, repeat(['foo'], 10))
      call sign_define('foo', { 'text': '>' })
      call sign_place(1, 'bar', 'foo', bufnr(), { 'lnum': 2 })
      call sign_place(2, 'bar', 'foo', bufnr(), { 'lnum': 1 })
      autocmd CursorMoved * if getcurpos()[1] == 2 | call sign_unplace('bar', { 'id': 1 }) | endif
    ]])
    feed('VG7kk')
    screen:expect([[
      {3:  }^f{2:oo}                                                       |
      {3:  }foo                                                       |
      {3:  }foo                                                       |
      {3:  }foo                                                       |
      {3:  }foo                                                       |
      {3:  }foo                                                       |
      {3:  }foo                                                       |
      {1:-- VISUAL LINE --}                                           |
    ]])
  end)

  it('@@@ in the last line shows correctly in a narrow window vim-patch:8.2.4718', function()
    local screen = Screen.new(60, 10)
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue},  -- NonText
      [2] = {bold = true, reverse = true},  -- StatusLine
      [3] = {reverse = true},  -- VertSplit, StatusLineNC
    })
    screen:attach()
    exec([[
      call setline(1, ['aaa', 'b'->repeat(100)])
      set display=truncate
      vsplit
      100wincmd <
    ]])
    screen:expect([[
      ^a│aaa                                                       |
      a│bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb|
      a│bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb                |
      b│{1:~                                                         }|
      b│{1:~                                                         }|
      b│{1:~                                                         }|
      b│{1:~                                                         }|
      {1:@}│{1:~                                                         }|
      {2:< }{3:[No Name] [+]                                             }|
                                                                  |
    ]])
    command('set display=lastline')
    screen:expect_unchanged()
    command('100wincmd >')
    screen:expect([[
      ^aaa                                                       │a|
      bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb│a|
      bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb                │a|
      {1:~                                                         }│b|
      {1:~                                                         }│b|
      {1:~                                                         }│b|
      {1:~                                                         }│b|
      {1:~                                                         }│{1:@}|
      {2:[No Name] [+]                                              }{3:<}|
                                                                  |
    ]])
    command('set display=truncate')
    screen:expect_unchanged()
  end)
end)
