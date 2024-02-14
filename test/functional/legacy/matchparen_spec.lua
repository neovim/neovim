local helpers = require('test.functional.helpers')(after_each)

local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local exec = helpers.exec
local feed = helpers.feed

describe('matchparen', function()
  before_each(clear)

  -- oldtest: Test_visual_block_scroll()
  it('redraws properly after scrolling with scrolloff=1', function()
    local screen = Screen.new(30, 7)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = { bold = true },
      [2] = { background = Screen.colors.LightGrey, foreground = Screen.colors.Black },
    })

    exec([[
      source $VIMRUNTIME/plugin/matchparen.vim
      set scrolloff=1
      call setline(1, ['a', 'b', 'c', 'd', 'e', '', '{', '}', '{', 'f', 'g', '}'])
      call cursor(5, 1)
    ]])

    feed('V<c-d><c-d>')
    screen:expect([[
      {2:{}                             |
      {2:}}                             |
      {2:{}                             |
      {2:f}                             |
      ^g                             |
      }                             |
      {1:-- VISUAL LINE --}             |
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
    ]])
    screen:expect(screen1)

    exec([[
      enew
      exe "normal iaa\<Esc>0"
    ]])
    screen:expect(screen2)

    feed('<C-^>')
    screen:expect(screen1)

    feed('<C-^>')
    screen:expect(screen2)
  end)

  -- oldtest: Test_matchparen_pum_clear()
  it('is cleared when completion popup is shown', function()
    local screen = Screen.new(30, 9)
    screen:attach()
    screen:set_default_attr_ids({
      [0] = { bold = true, foreground = Screen.colors.Blue },
      [1] = { background = Screen.colors.Plum1 },
      [2] = { background = Screen.colors.Grey },
      [3] = { bold = true },
      [4] = { bold = true, foreground = Screen.colors.SeaGreen },
    })

    exec([[
      source $VIMRUNTIME/plugin/matchparen.vim
      set completeopt=menuone
      call setline(1, ['aa', 'aaa', 'aaaa', '(a)'])
      call cursor(4, 3)
    ]])

    feed('i<C-X><C-N><C-N>')
    screen:expect {
      grid = [[
      aa                            |
      aaa                           |
      aaaa                          |
      (aaa^)                         |
      {1: aa             }{0:              }|
      {2: aaa            }{0:              }|
      {1: aaaa           }{0:              }|
      {0:~                             }|
      {3:-- }{4:match 2 of 3}               |
    ]],
    }
  end)
end)
