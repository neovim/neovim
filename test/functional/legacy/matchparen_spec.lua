local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local exec = n.exec
local feed = n.feed
local poke_eventloop = n.poke_eventloop

describe('matchparen', function()
  before_each(clear)

  -- oldtest: Test_visual_block_scroll()
  it('redraws properly after scrolling with scrolloff=1', function()
    local screen = Screen.new(30, 7)
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
    screen:add_extra_attr_ids {
      [100] = { background = Screen.colors.Cyan1 },
    }

    local screen1 = [[
      {100:^()}                  |
      {1:~                   }|*3
                          |
    ]]
    local screen2 = [[
      ^aa                  |
      {1:~                   }|*3
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
    screen:add_extra_attr_ids {
      [100] = { background = Screen.colors.Cyan1 },
    }

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
      {100:^{}}                  |
      {3:[No Name] [+]       }|
      {}                  |
      {2:[No Name] [+]       }|
                          |
    ]])

    -- Switching buffer away and back shouldn't change matchparen highlight.
    exec('call SwitchBuf()')
    screen:expect_unchanged()
  end)

  -- oldtest: Test_matchparen_pum_clear()
  it('is cleared when completion popup is shown', function()
    local screen = Screen.new(30, 9)

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
    screen:add_extra_attr_ids {
      [100] = { background = Screen.colors.Cyan1 },
    }

    exec([[
      source $VIMRUNTIME/plugin/matchparen.vim
      call setline(1, ['aaaaaaaa（', 'bbbb）cc'])
      set matchpairs+=（:）
    ]])

    screen:expect([[
      ^aaaaaaaa（                    |
      bbbb）cc                      |
      {1:~                             }|*7
                                    |
    ]])
    feed('$')
    screen:expect([[
      aaaaaaaa{100:^（}                    |
      bbbb{100:）}cc                      |
      {1:~                             }|*7
                                    |
    ]])
    feed('j')
    screen:expect([[
      aaaaaaaa（                    |
      bbbb）c^c                      |
      {1:~                             }|*7
                                    |
    ]])
    feed('2h')
    screen:expect([[
      aaaaaaaa{100:（}                    |
      bbbb{100:^）}cc                      |
      {1:~                             }|*7
                                    |
    ]])
    feed('0')
    screen:expect([[
      aaaaaaaa（                    |
      ^bbbb）cc                      |
      {1:~                             }|*7
                                    |
    ]])
    feed('kA')
    screen:expect([[
      aaaaaaaa{100:（}^                    |
      bbbb{100:）}cc                      |
      {1:~                             }|*7
      {5:-- INSERT --}                  |
    ]])
    feed('<Down>')
    screen:expect([[
      aaaaaaaa（                    |
      bbbb）cc^                      |
      {1:~                             }|*7
      {5:-- INSERT --}                  |
    ]])
    feed('<C-W>')
    screen:expect([[
      aaaaaaaa{100:（}                    |
      bbbb{100:）}^                        |
      {1:~                             }|*7
      {5:-- INSERT --}                  |
    ]])
  end)

  -- oldtest: Test_matchparen_ignore_sh_case()
  it('ignores shell case statements', function()
    local screen = Screen.new(40, 15)
    exec([[
      syntax on
      source $VIMRUNTIME/plugin/matchparen.vim
      set ft=sh
      call setline(1, [
            \ '#!/bin/sh',
            \ 'SUSUWU_PRINT() (',
            \ '  case "${LEVEL}" in',
            \ '    "$SUSUWU_SH_NOTICE")',
            \ '    ${SUSUWU_S} && return 1',
            \ '  ;;',
            \ '    "$SUSUWU_SH_DEBUG")',
            \ '    (! ${SUSUWU_VERBOSE}) && return 1',
            \ '  ;;',
            \ '  esac',
            \ '  # snip',
            \ ')'
            \ ])
      call cursor(4, 26)
    ]])
    screen:add_extra_attr_ids({
      [100] = { foreground = tonumber('0x6a0dad') },
    })
    screen:expect([[
      {18:#!/bin/sh}                               |
      {25:SUSUWU_PRINT() (}                        |
        {15:case} {15:"}{100:${LEVEL}}{15:"} {15:in}                    |
          {15:"}{100:$SUSUWU_SH_NOTICE}{15:"^)}                |
          {100:${SUSUWU_S}} {15:&&} {15:return} {26:1}             |
        {15:;;}                                    |
          {15:"}{100:$SUSUWU_SH_DEBUG}{15:")}                 |
          {100:(}{15:!} {100:${SUSUWU_VERBOSE})} {15:&&} {15:return} {26:1}   |
        {15:;;}                                    |
        {15:esac}                                  |
        {18:# snip}                                |
      {25:)}                                       |
      {1:~                                       }|*2
                                              |
    ]])
    -- Send keys one by one so that CursorMoved is triggered.
    for _, c in ipairs({ 'A', ' ', 'f', 'o', 'o', 'b', 'a', 'r' }) do
      feed(c)
      poke_eventloop()
    end
    screen:expect([[
      {18:#!/bin/sh}                               |
      {25:SUSUWU_PRINT() (}                        |
        {15:case} {15:"}{100:${LEVEL}}{15:"} {15:in}                    |
          {15:"}{100:$SUSUWU_SH_NOTICE}{15:")} foobar^         |
          {100:${SUSUWU_S}} {15:&&} {15:return} {26:1}             |
        {15:;;}                                    |
          {15:"}{100:$SUSUWU_SH_DEBUG}{15:")}                 |
          {100:(}{15:!} {100:${SUSUWU_VERBOSE})} {15:&&} {15:return} {26:1}   |
        {15:;;}                                    |
        {15:esac}                                  |
        {18:# snip}                                |
      {25:)}                                       |
      {1:~                                       }|*2
      {5:-- INSERT --}                            |
    ]])
  end)

  -- oldtest: Test_scroll_winscrolled()
  it('with scrolling', function()
    local screen = Screen.new(30, 7)
    exec([[
      source $VIMRUNTIME/plugin/matchparen.vim
      set scrolloff=1
      call setline(1, ['foobar {', '', '', '', '}'])
      call cursor(5, 1)
    ]])
    screen:add_extra_attr_ids({
      [100] = { background = Screen.colors.Aqua },
    })
    local s1 = [[
      foobar {100:{}                      |
                                    |*3
      {100:^}}                             |
      {1:~                             }|
                                    |
    ]]
    screen:expect(s1)
    feed('<C-E>')
    screen:expect([[
                                    |*3
      ^}                             |
      {1:~                             }|*2
                                    |
    ]])
    feed('<C-Y>')
    screen:expect(s1)
  end)
end)
