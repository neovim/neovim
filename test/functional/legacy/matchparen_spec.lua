local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local exec = n.exec
local feed = n.feed

describe('matchparen', function()
  before_each(clear)

  -- oldtest: Test_visual_block_scroll()
  it('redraws properly after scrolling with scrolloff=1', function()
    local screen = Screen.new(30, 7)
    screen:attach()
    exec([[
      source $VIMRUNTIME/plugin/matchparen.vim
      set scrolloff=1
      call setline(1, ['a', 'b', 'c', 'd', 'e', '', '{', '}', '{', 'f', 'g', '}'])
      call cursor(5, 1)
    ]])

    feed('V<c-d><c-d>')
    screen:expect([[
      {17:{}                             |
      {17:}}                             |
      {17:{}                             |
      {17:f}                             |
      ^g                             |
      }                             |
      {5:-- VISUAL LINE --}             |
    ]])
  end)

  -- oldtest: Test_matchparen_clear_highlight()
  it('matchparen highlight is cleared when switching buffer', function()
    local screen = Screen.new(20, 5)
    screen:set_default_attr_ids({
      [0] = { bold = true, foreground = Screen.colors.Blue },
      [1] = { background = Screen.colors.Cyan },
    })
    screen:attach()

    local screen1 = [[
      {1:^()}                  |
      {0:~                   }|*3
                          |
    ]]
    local screen2 = [[
      ^aa                  |
      {0:~                   }|*3
                          |
    ]]

    exec([[
      source $VIMRUNTIME/plugin/matchparen.vim
      set hidden
      call setline(1, ['()'])
      normal 0

      func OtherBuffer()
         enew
         exe "normal iaa\<Esc>0"
      endfunc
    ]])
    screen:expect(screen1)

    exec('call OtherBuffer()')
    screen:expect(screen2)

    feed('<C-^>')
    screen:expect(screen1)

    feed('<C-^>')
    screen:expect(screen2)
  end)

  -- oldtest: Test_matchparen_win_execute()
  it('matchparen highlight when switching buffer in win_execute()', function()
    local screen = Screen.new(20, 5)
    screen:set_default_attr_ids({
      [1] = { background = Screen.colors.Cyan },
      [2] = { reverse = true, bold = true },
      [3] = { reverse = true },
    })
    screen:attach()

    exec([[
      source $VIMRUNTIME/plugin/matchparen.vim
      let s:win = win_getid()
      call setline(1, '{}')
      split

      func SwitchBuf()
        call win_execute(s:win, 'enew | buffer #')
      endfunc
    ]])
    screen:expect([[
      {1:^{}}                  |
      {2:[No Name] [+]       }|
      {}                  |
      {3:[No Name] [+]       }|
                          |
    ]])

    -- Switching buffer away and back shouldn't change matchparen highlight.
    exec('call SwitchBuf()')
    screen:expect_unchanged()
  end)

  -- oldtest: Test_matchparen_pum_clear()
  it('is cleared when completion popup is shown', function()
    local screen = Screen.new(30, 9)
    screen:attach()

    exec([[
      source $VIMRUNTIME/plugin/matchparen.vim
      set completeopt=menuone
      call setline(1, ['aa', 'aaa', 'aaaa', '(a)'])
      call cursor(4, 3)
    ]])

    feed('i<C-X><C-N><C-N>')
    screen:expect([[
      aa                            |
      aaa                           |
      aaaa                          |
      (aaa^)                         |
      {4: aa             }{1:              }|
      {12: aaa            }{1:              }|
      {4: aaaa           }{1:              }|
      {1:~                             }|
      {5:-- }{6:match 2 of 3}               |
    ]])
  end)

  -- oldtest: Test_matchparen_mbyte()
  it("works with multibyte chars in 'matchpairs'", function()
    local screen = Screen.new(30, 10)
    screen:set_default_attr_ids({
      [0] = { bold = true, foreground = Screen.colors.Blue },
      [1] = { background = Screen.colors.Cyan },
      [2] = { bold = true },
    })
    screen:attach()

    exec([[
      source $VIMRUNTIME/plugin/matchparen.vim
      call setline(1, ['aaaaaaaa（', 'bbbb）cc'])
      set matchpairs+=（:）
    ]])

    screen:expect([[
      ^aaaaaaaa（                    |
      bbbb）cc                      |
      {0:~                             }|*7
                                    |
    ]])
    feed('$')
    screen:expect([[
      aaaaaaaa{1:^（}                    |
      bbbb{1:）}cc                      |
      {0:~                             }|*7
                                    |
    ]])
    feed('j')
    screen:expect([[
      aaaaaaaa（                    |
      bbbb）c^c                      |
      {0:~                             }|*7
                                    |
    ]])
    feed('2h')
    screen:expect([[
      aaaaaaaa{1:（}                    |
      bbbb{1:^）}cc                      |
      {0:~                             }|*7
                                    |
    ]])
    feed('0')
    screen:expect([[
      aaaaaaaa（                    |
      ^bbbb）cc                      |
      {0:~                             }|*7
                                    |
    ]])
    feed('kA')
    screen:expect([[
      aaaaaaaa{1:（}^                    |
      bbbb{1:）}cc                      |
      {0:~                             }|*7
      {2:-- INSERT --}                  |
    ]])
    feed('<Down>')
    screen:expect([[
      aaaaaaaa（                    |
      bbbb）cc^                      |
      {0:~                             }|*7
      {2:-- INSERT --}                  |
    ]])
    feed('<C-W>')
    screen:expect([[
      aaaaaaaa{1:（}                    |
      bbbb{1:）}^                        |
      {0:~                             }|*7
      {2:-- INSERT --}                  |
    ]])
  end)
end)
