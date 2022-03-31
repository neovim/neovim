local helpers = require('test.functional.helpers')(after_each)

local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local poke_eventloop = helpers.poke_eventloop
local exec = helpers.exec
local feed = helpers.feed
local feed_command = helpers.feed_command

describe('display', function()
  before_each(clear)

  it('scroll when modified at topline', function()
    local screen = Screen.new(20, 4)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = {bold = true},
    })

    feed_command([[call setline(1, repeat('a', 21))]])
    poke_eventloop()
    feed('O')
    screen:expect([[
      ^                    |
      aaaaaaaaaaaaaaaaaaaa|
      a                   |
      {1:-- INSERT --}        |
    ]])
  end)

  it('scrolling when modified at topline in Visual mode', function()
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
end)

