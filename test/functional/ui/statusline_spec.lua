local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local assert_alive = n.assert_alive
local clear = n.clear
local command = n.command
local feed = n.feed
local eq = t.eq
local fn = n.fn
local api = n.api
local exec = n.exec
local exec_lua = n.exec_lua
local eval = n.eval
local sleep = vim.uv.sleep
local pcall_err = t.pcall_err

local mousemodels = { 'extend', 'popup', 'popup_setpos' }

for _, model in ipairs(mousemodels) do
  describe('statusline clicks with mousemodel=' .. model, function()
    local screen

    before_each(function()
      clear()
      screen = Screen.new(40, 8)
      screen:set_default_attr_ids({
        [0] = { bold = true, foreground = Screen.colors.Blue }, -- NonText
        [1] = { bold = true, reverse = true }, -- StatusLine
      })
      screen:attach()
      command('set laststatus=2 mousemodel=' .. model)
      exec([=[
        function! MyClickFunc(minwid, clicks, button, mods)
          let g:testvar = printf("%d %d %s", a:minwid, a:clicks, a:button)
          if a:mods !=# '    '
            let g:testvar ..= '(' .. a:mods .. ')'
          endif
        endfunction
        let g:testvar = ''
      ]=])
    end)

    it('works', function()
      api.nvim_set_option_value('statusline', 'Not clicky stuff %0@MyClickFunc@Clicky stuff%T', {})
      api.nvim_input_mouse('left', 'press', '', 0, 6, 16)
      eq('', eval('g:testvar'))
      api.nvim_input_mouse('right', 'press', '', 0, 6, 29)
      eq('', eval('g:testvar'))
      api.nvim_input_mouse('left', 'press', '', 0, 6, 17)
      eq('0 1 l', eval('g:testvar'))
      api.nvim_input_mouse('left', 'press', '', 0, 6, 17)
      eq('0 2 l', eval('g:testvar'))
      api.nvim_input_mouse('left', 'press', '', 0, 6, 17)
      eq('0 3 l', eval('g:testvar'))
      api.nvim_input_mouse('left', 'press', '', 0, 6, 17)
      eq('0 4 l', eval('g:testvar'))
      api.nvim_input_mouse('right', 'press', '', 0, 6, 28)
      eq('0 1 r', eval('g:testvar'))
      api.nvim_input_mouse('right', 'press', '', 0, 6, 28)
      eq('0 2 r', eval('g:testvar'))
      api.nvim_input_mouse('right', 'press', '', 0, 6, 28)
      eq('0 3 r', eval('g:testvar'))
      api.nvim_input_mouse('right', 'press', '', 0, 6, 28)
      eq('0 4 r', eval('g:testvar'))
      api.nvim_input_mouse('x1', 'press', '', 0, 6, 17)
      eq('0 1 x1', eval('g:testvar'))
      api.nvim_input_mouse('x1', 'press', '', 0, 6, 17)
      eq('0 2 x1', eval('g:testvar'))
      api.nvim_input_mouse('x1', 'press', '', 0, 6, 17)
      eq('0 3 x1', eval('g:testvar'))
      api.nvim_input_mouse('x1', 'press', '', 0, 6, 17)
      eq('0 4 x1', eval('g:testvar'))
      api.nvim_input_mouse('x2', 'press', '', 0, 6, 28)
      eq('0 1 x2', eval('g:testvar'))
      api.nvim_input_mouse('x2', 'press', '', 0, 6, 28)
      eq('0 2 x2', eval('g:testvar'))
      api.nvim_input_mouse('x2', 'press', '', 0, 6, 28)
      eq('0 3 x2', eval('g:testvar'))
      api.nvim_input_mouse('x2', 'press', '', 0, 6, 28)
      eq('0 4 x2', eval('g:testvar'))
    end)

    it('works with control characters and highlight', function()
      api.nvim_set_option_value('statusline', '\t%#NonText#\1%0@MyClickFunc@\t\1%T\t%##\1', {})
      screen:expect {
        grid = [[
        ^                                        |
        {0:~                                       }|*5
        {1:^I}{0:^A^I^A^I}{1:^A                            }|
                                                |
      ]],
      }
      api.nvim_input_mouse('right', 'press', '', 0, 6, 3)
      eq('', eval('g:testvar'))
      api.nvim_input_mouse('left', 'press', '', 0, 6, 8)
      eq('', eval('g:testvar'))
      api.nvim_input_mouse('right', 'press', '', 0, 6, 4)
      eq('0 1 r', eval('g:testvar'))
      api.nvim_input_mouse('left', 'press', '', 0, 6, 7)
      eq('0 1 l', eval('g:testvar'))
    end)

    it('works for winbar', function()
      api.nvim_set_option_value('winbar', 'Not clicky stuff %0@MyClickFunc@Clicky stuff%T', {})
      api.nvim_input_mouse('left', 'press', '', 0, 0, 17)
      eq('0 1 l', eval('g:testvar'))
      api.nvim_input_mouse('right', 'press', '', 0, 0, 17)
      eq('0 1 r', eval('g:testvar'))
    end)

    it('works for winbar in floating window', function()
      api.nvim_open_win(
        0,
        true,
        { width = 30, height = 4, relative = 'editor', row = 1, col = 5, border = 'single' }
      )
      api.nvim_set_option_value(
        'winbar',
        'Not clicky stuff %0@MyClickFunc@Clicky stuff%T',
        { scope = 'local' }
      )
      api.nvim_input_mouse('left', 'press', '', 0, 2, 23)
      eq('0 1 l', eval('g:testvar'))
    end)

    it('works when there are multiple windows', function()
      command('split')
      api.nvim_set_option_value('statusline', 'Not clicky stuff %0@MyClickFunc@Clicky stuff%T', {})
      api.nvim_set_option_value('winbar', 'Not clicky stuff %0@MyClickFunc@Clicky stuff%T', {})
      api.nvim_input_mouse('left', 'press', '', 0, 0, 17)
      eq('0 1 l', eval('g:testvar'))
      api.nvim_input_mouse('right', 'press', '', 0, 4, 17)
      eq('0 1 r', eval('g:testvar'))
      api.nvim_input_mouse('middle', 'press', '', 0, 3, 17)
      eq('0 1 m', eval('g:testvar'))
      api.nvim_input_mouse('left', 'press', '', 0, 6, 17)
      eq('0 1 l', eval('g:testvar'))
    end)

    it('works with Lua function', function()
      exec_lua([[
      function clicky_func(minwid, clicks, button, mods)
        vim.g.testvar = string.format("%d %d %s", minwid, clicks, button)
      end
      ]])
      api.nvim_set_option_value(
        'statusline',
        'Not clicky stuff %0@v:lua.clicky_func@Clicky stuff%T',
        {}
      )
      api.nvim_input_mouse('left', 'press', '', 0, 6, 17)
      eq('0 1 l', eval('g:testvar'))
    end)

    it('ignores unsupported click items', function()
      command('tabnew | tabprevious')
      api.nvim_set_option_value('statusline', '%2TNot clicky stuff%T', {})
      api.nvim_input_mouse('left', 'press', '', 0, 6, 0)
      eq(1, api.nvim_get_current_tabpage())
      api.nvim_set_option_value('statusline', '%2XNot clicky stuff%X', {})
      api.nvim_input_mouse('left', 'press', '', 0, 6, 0)
      eq(2, #api.nvim_list_tabpages())
    end)

    it("right click works when statusline isn't focused #18994", function()
      api.nvim_set_option_value('statusline', 'Not clicky stuff %0@MyClickFunc@Clicky stuff%T', {})
      api.nvim_input_mouse('right', 'press', '', 0, 6, 17)
      eq('0 1 r', eval('g:testvar'))
      api.nvim_input_mouse('right', 'press', '', 0, 6, 17)
      eq('0 2 r', eval('g:testvar'))
    end)

    it('works with modifiers #18994', function()
      api.nvim_set_option_value('statusline', 'Not clicky stuff %0@MyClickFunc@Clicky stuff%T', {})
      -- Note: alternate between left and right mouse buttons to avoid triggering multiclicks
      api.nvim_input_mouse('left', 'press', 'S', 0, 6, 17)
      eq('0 1 l(s   )', eval('g:testvar'))
      api.nvim_input_mouse('right', 'press', 'S', 0, 6, 17)
      eq('0 1 r(s   )', eval('g:testvar'))
      api.nvim_input_mouse('left', 'press', 'A', 0, 6, 17)
      eq('0 1 l(  a )', eval('g:testvar'))
      api.nvim_input_mouse('right', 'press', 'A', 0, 6, 17)
      eq('0 1 r(  a )', eval('g:testvar'))
      api.nvim_input_mouse('left', 'press', 'AS', 0, 6, 17)
      eq('0 1 l(s a )', eval('g:testvar'))
      api.nvim_input_mouse('right', 'press', 'AS', 0, 6, 17)
      eq('0 1 r(s a )', eval('g:testvar'))
      api.nvim_input_mouse('left', 'press', 'T', 0, 6, 17)
      eq('0 1 l(   m)', eval('g:testvar'))
      api.nvim_input_mouse('right', 'press', 'T', 0, 6, 17)
      eq('0 1 r(   m)', eval('g:testvar'))
      api.nvim_input_mouse('left', 'press', 'TS', 0, 6, 17)
      eq('0 1 l(s  m)', eval('g:testvar'))
      api.nvim_input_mouse('right', 'press', 'TS', 0, 6, 17)
      eq('0 1 r(s  m)', eval('g:testvar'))
      api.nvim_input_mouse('left', 'press', 'C', 0, 6, 17)
      eq('0 1 l( c  )', eval('g:testvar'))
      -- <C-RightMouse> is for tag jump
    end)

    it('works for global statusline with vertical splits #19186', function()
      command('set laststatus=3')
      api.nvim_set_option_value(
        'statusline',
        '%0@MyClickFunc@Clicky stuff%T %= %0@MyClickFunc@Clicky stuff%T',
        {}
      )
      command('vsplit')
      screen:expect {
        grid = [[
        ^                    │                   |
        {0:~                   }│{0:~                  }|*5
        {1:Clicky stuff                Clicky stuff}|
                                                |
      ]],
      }

      -- clickable area on the right
      api.nvim_input_mouse('left', 'press', '', 0, 6, 35)
      eq('0 1 l', eval('g:testvar'))
      api.nvim_input_mouse('right', 'press', '', 0, 6, 35)
      eq('0 1 r', eval('g:testvar'))

      -- clickable area on the left
      api.nvim_input_mouse('left', 'press', '', 0, 6, 5)
      eq('0 1 l', eval('g:testvar'))
      api.nvim_input_mouse('right', 'press', '', 0, 6, 5)
      eq('0 1 r', eval('g:testvar'))
    end)

    it('no memory leak with zero-width click labels', function()
      command([[
      let &stl = '%@Test@%T%@MyClickFunc@%=%T%@Test@'
      ]])
      api.nvim_input_mouse('left', 'press', '', 0, 6, 0)
      eq('0 1 l', eval('g:testvar'))
      api.nvim_input_mouse('right', 'press', '', 0, 6, 39)
      eq('0 1 r', eval('g:testvar'))
    end)

    it('no memory leak with truncated click labels', function()
      command([[
      let &stl = '%@MyClickFunc@foo%X' .. repeat('a', 40) .. '%<t%@Test@bar%X%@Test@baz'
      ]])
      api.nvim_input_mouse('left', 'press', '', 0, 6, 2)
      eq('0 1 l', eval('g:testvar'))
    end)
  end)
end

describe('global statusline', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(60, 16)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = { bold = true, foreground = Screen.colors.Blue },
      [2] = { bold = true, reverse = true },
      [3] = { bold = true },
      [4] = { reverse = true },
      [5] = { bold = true, foreground = Screen.colors.Fuchsia },
    })
    command('set laststatus=3')
    command('set ruler')
  end)

  it('works', function()
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*13
      {2:[No Name]                                 0,0-1          All}|
                                                                  |
    ]])

    feed('i<CR><CR>')
    screen:expect([[
                                                                  |*2
      ^                                                            |
      {1:~                                                           }|*11
      {2:[No Name] [+]                             3,1            All}|
      {3:-- INSERT --}                                                |
    ]])
  end)

  it('works with splits', function()
    command('vsplit | split | vsplit | vsplit | wincmd l | split | 2wincmd l | split')
    screen:expect([[
                          │                │ │^                    |
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|*3
      {1:~                   }├────────────────┤{1:~}│{1:~                   }|
      {1:~                   }│                │{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}├────────────────────|
      {1:~                   }│{1:~               }│{1:~}│                    |
      ────────────────────┴────────────────┴─┤{1:~                   }|
                                             │{1:~                   }|
      {1:~                                      }│{1:~                   }|*3
      {2:[No Name]                                 0,0-1          All}|
                                                                  |
    ]])
  end)

  it('works when switching between values of laststatus', function()
    command('set laststatus=1')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*14
                                                0,0-1         All |
    ]])

    command('set laststatus=3')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*13
      {2:[No Name]                                 0,0-1          All}|
                                                                  |
    ]])

    command('vsplit | split | vsplit | vsplit | wincmd l | split | 2wincmd l | split')
    command('set laststatus=2')
    screen:expect([[
                          │                │ │^                    |
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|*3
      {1:~                   }│{4:< Name] 0,0-1   }│{1:~}│{1:~                   }|
      {1:~                   }│                │{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{2:<No Name] 0,0-1  All}|
      {1:~                   }│{1:~               }│{1:~}│                    |
      {4:<No Name] 0,0-1  All < Name] 0,0-1    <}│{1:~                   }|
                                             │{1:~                   }|
      {1:~                                      }│{1:~                   }|*3
      {4:[No Name]            0,0-1          All <No Name] 0,0-1  All}|
                                                                  |
    ]])

    command('set laststatus=3')
    screen:expect([[
                          │                │ │^                    |
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|*3
      {1:~                   }├────────────────┤{1:~}│{1:~                   }|
      {1:~                   }│                │{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}├────────────────────|
      {1:~                   }│{1:~               }│{1:~}│                    |
      ────────────────────┴────────────────┴─┤{1:~                   }|
                                             │{1:~                   }|
      {1:~                                      }│{1:~                   }|*3
      {2:[No Name]                                 0,0-1          All}|
                                                                  |
    ]])

    command('set laststatus=0')
    screen:expect([[
                          │                │ │^                    |
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|*3
      {1:~                   }│{4:< Name] 0,0-1   }│{1:~}│{1:~                   }|
      {1:~                   }│                │{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{2:<No Name] 0,0-1  All}|
      {1:~                   }│{1:~               }│{1:~}│                    |
      {4:<No Name] 0,0-1  All < Name] 0,0-1    <}│{1:~                   }|
                                             │{1:~                   }|
      {1:~                                      }│{1:~                   }|*4
                                                0,0-1         All |
    ]])

    command('set laststatus=3')
    screen:expect([[
                          │                │ │^                    |
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|*3
      {1:~                   }├────────────────┤{1:~}│{1:~                   }|
      {1:~                   }│                │{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}├────────────────────|
      {1:~                   }│{1:~               }│{1:~}│                    |
      ────────────────────┴────────────────┴─┤{1:~                   }|
                                             │{1:~                   }|
      {1:~                                      }│{1:~                   }|*3
      {2:[No Name]                                 0,0-1          All}|
                                                                  |
    ]])
  end)

  it('win_move_statusline() can reduce cmdheight to 1', function()
    eq(1, api.nvim_get_option_value('cmdheight', {}))
    fn.win_move_statusline(0, -1)
    eq(2, api.nvim_get_option_value('cmdheight', {}))
    fn.win_move_statusline(0, -1)
    eq(3, api.nvim_get_option_value('cmdheight', {}))
    fn.win_move_statusline(0, 1)
    eq(2, api.nvim_get_option_value('cmdheight', {}))
    fn.win_move_statusline(0, 1)
    eq(1, api.nvim_get_option_value('cmdheight', {}))
  end)

  it('mouse dragging can reduce cmdheight to 1', function()
    command('set mouse=a')
    api.nvim_input_mouse('left', 'press', '', 0, 14, 10)
    eq(1, api.nvim_get_option_value('cmdheight', {}))
    api.nvim_input_mouse('left', 'drag', '', 0, 13, 10)
    eq(2, api.nvim_get_option_value('cmdheight', {}))
    api.nvim_input_mouse('left', 'drag', '', 0, 12, 10)
    eq(3, api.nvim_get_option_value('cmdheight', {}))
    api.nvim_input_mouse('left', 'drag', '', 0, 13, 10)
    eq(2, api.nvim_get_option_value('cmdheight', {}))
    api.nvim_input_mouse('left', 'drag', '', 0, 14, 10)
    eq(1, api.nvim_get_option_value('cmdheight', {}))
    api.nvim_input_mouse('left', 'drag', '', 0, 15, 10)
    eq(1, api.nvim_get_option_value('cmdheight', {}))
    api.nvim_input_mouse('left', 'drag', '', 0, 14, 10)
    eq(1, api.nvim_get_option_value('cmdheight', {}))
  end)

  it('cmdline row is correct after setting cmdheight #20514', function()
    command('botright split test/functional/fixtures/bigfile.txt')
    api.nvim_set_option_value('cmdheight', 1, {})
    feed('L')
    screen:expect([[
                                                                  |
      {1:~                                                           }|*5
      ────────────────────────────────────────────────────────────|
      0000;<control>;Cc;0;BN;;;;;N;NULL;;;;                       |
      0001;<control>;Cc;0;BN;;;;;N;START OF HEADING;;;;           |
      0002;<control>;Cc;0;BN;;;;;N;START OF TEXT;;;;              |
      0003;<control>;Cc;0;BN;;;;;N;END OF TEXT;;;;                |
      0004;<control>;Cc;0;BN;;;;;N;END OF TRANSMISSION;;;;        |
      0005;<control>;Cc;0;BN;;;;;N;ENQUIRY;;;;                    |
      ^0006;<control>;Cc;0;BN;;;;;N;ACKNOWLEDGE;;;;                |
      {2:test/functional/fixtures/bigfile.txt      7,1            Top}|
                                                                  |
    ]])
    feed('j')
    screen:expect([[
                                                                  |
      {1:~                                                           }|*5
      ────────────────────────────────────────────────────────────|
      0001;<control>;Cc;0;BN;;;;;N;START OF HEADING;;;;           |
      0002;<control>;Cc;0;BN;;;;;N;START OF TEXT;;;;              |
      0003;<control>;Cc;0;BN;;;;;N;END OF TEXT;;;;                |
      0004;<control>;Cc;0;BN;;;;;N;END OF TRANSMISSION;;;;        |
      0005;<control>;Cc;0;BN;;;;;N;ENQUIRY;;;;                    |
      0006;<control>;Cc;0;BN;;;;;N;ACKNOWLEDGE;;;;                |
      ^0007;<control>;Cc;0;BN;;;;;N;BELL;;;;                       |
      {2:test/functional/fixtures/bigfile.txt      8,1             0%}|
                                                                  |
    ]])
    api.nvim_set_option_value('showtabline', 2, {})
    screen:expect([[
      {3: }{5:2}{3: t/f/f/bigfile.txt }{4:                                       }|
                                                                  |
      {1:~                                                           }|*5
      ────────────────────────────────────────────────────────────|
      0002;<control>;Cc;0;BN;;;;;N;START OF TEXT;;;;              |
      0003;<control>;Cc;0;BN;;;;;N;END OF TEXT;;;;                |
      0004;<control>;Cc;0;BN;;;;;N;END OF TRANSMISSION;;;;        |
      0005;<control>;Cc;0;BN;;;;;N;ENQUIRY;;;;                    |
      0006;<control>;Cc;0;BN;;;;;N;ACKNOWLEDGE;;;;                |
      ^0007;<control>;Cc;0;BN;;;;;N;BELL;;;;                       |
      {2:test/functional/fixtures/bigfile.txt      8,1             0%}|
                                                                  |
    ]])
    api.nvim_set_option_value('cmdheight', 0, {})
    screen:expect([[
      {3: }{5:2}{3: t/f/f/bigfile.txt }{4:                                       }|
                                                                  |
      {1:~                                                           }|*5
      ────────────────────────────────────────────────────────────|
      0001;<control>;Cc;0;BN;;;;;N;START OF HEADING;;;;           |
      0002;<control>;Cc;0;BN;;;;;N;START OF TEXT;;;;              |
      0003;<control>;Cc;0;BN;;;;;N;END OF TEXT;;;;                |
      0004;<control>;Cc;0;BN;;;;;N;END OF TRANSMISSION;;;;        |
      0005;<control>;Cc;0;BN;;;;;N;ENQUIRY;;;;                    |
      0006;<control>;Cc;0;BN;;;;;N;ACKNOWLEDGE;;;;                |
      ^0007;<control>;Cc;0;BN;;;;;N;BELL;;;;                       |
      {2:test/functional/fixtures/bigfile.txt      8,1             0%}|
    ]])
    api.nvim_set_option_value('cmdheight', 1, {})
    screen:expect([[
      {3: }{5:2}{3: t/f/f/bigfile.txt }{4:                                       }|
                                                                  |
      {1:~                                                           }|*5
      ────────────────────────────────────────────────────────────|
      0002;<control>;Cc;0;BN;;;;;N;START OF TEXT;;;;              |
      0003;<control>;Cc;0;BN;;;;;N;END OF TEXT;;;;                |
      0004;<control>;Cc;0;BN;;;;;N;END OF TRANSMISSION;;;;        |
      0005;<control>;Cc;0;BN;;;;;N;ENQUIRY;;;;                    |
      0006;<control>;Cc;0;BN;;;;;N;ACKNOWLEDGE;;;;                |
      ^0007;<control>;Cc;0;BN;;;;;N;BELL;;;;                       |
      {2:test/functional/fixtures/bigfile.txt      8,1             0%}|
                                                                  |
    ]])
  end)

  it('horizontal separators unchanged when failing to split-move window', function()
    exec([[
      botright split
      let &winwidth = &columns
      let &winminwidth = &columns
    ]])
    eq('Vim(wincmd):E36: Not enough room', pcall_err(command, 'wincmd L'))
    command('mode')
    screen:expect([[
                                                                  |
      {1:~                                                           }|*5
      ────────────────────────────────────────────────────────────|
      ^                                                            |
      {1:~                                                           }|*6
      {2:[No Name]                                 0,0-1          All}|
                                                                  |
    ]])
  end)
end)

it('statusline does not crash if it has Arabic characters #19447', function()
  clear()
  api.nvim_set_option_value('statusline', 'غً', {})
  api.nvim_set_option_value('laststatus', 2, {})
  command('redraw!')
  assert_alive()
end)

it('statusline is redrawn with :resize from <Cmd> mapping #19629', function()
  clear()
  local screen = Screen.new(40, 8)
  screen:set_default_attr_ids({
    [0] = { bold = true, foreground = Screen.colors.Blue }, -- NonText
    [1] = { bold = true, reverse = true }, -- StatusLine
  })
  screen:attach()
  exec([[
    set laststatus=2
    nnoremap <Up> <cmd>resize -1<CR>
    nnoremap <Down> <cmd>resize +1<CR>
  ]])
  feed('<Up>')
  screen:expect([[
    ^                                        |
    {0:~                                       }|*4
    {1:[No Name]                               }|
                                            |*2
  ]])
  feed('<Down>')
  screen:expect([[
    ^                                        |
    {0:~                                       }|*5
    {1:[No Name]                               }|
                                            |
  ]])
end)

it('showcmdloc=statusline does not show if statusline is too narrow', function()
  clear()
  local screen = Screen.new(40, 8)
  screen:set_default_attr_ids({
    [0] = { bold = true, foreground = Screen.colors.Blue }, -- NonText
    [1] = { bold = true, reverse = true }, -- StatusLine
    [2] = { reverse = true }, -- StatusLineNC
  })
  screen:attach()
  command('set showcmd')
  command('set showcmdloc=statusline')
  command('1vsplit')
  screen:expect([[
    ^ │                                      |
    {0:~}│{0:~                                     }|*5
    {1:< }{2:[No Name]                             }|
                                            |
  ]])
  feed('1234')
  screen:expect_unchanged()
end)

it('K_EVENT does not trigger a statusline redraw unnecessarily', function()
  clear()
  local screen = Screen.new(40, 8)
  screen:attach()
  -- does not redraw on vim.schedule (#17937)
  command([[
    set laststatus=2
    let g:counter = 0
    func Status()
      let g:counter += 1
      lua vim.schedule(function() end)
      return g:counter
    endfunc
    set statusline=%!Status()
  ]])
  sleep(50)
  eq(1, eval('g:counter < 50'), 'g:counter=' .. eval('g:counter'))
  -- also in insert mode
  feed('i')
  sleep(50)
  eq(1, eval('g:counter < 50'), 'g:counter=' .. eval('g:counter'))
  -- does not redraw on timer call (#14303)
  command([[
    let g:counter = 0
    func Timer(timer)
    endfunc
    call timer_start(1, 'Timer', {'repeat': 100})
  ]])
  sleep(50)
  eq(1, eval('g:counter < 50'), 'g:counter=' .. eval('g:counter'))
end)

it('statusline is redrawn on various state changes', function()
  clear()
  local screen = Screen.new(40, 4)
  screen:attach()

  -- recording state change #22683
  command('set ls=2 stl=%{repeat(reg_recording(),5)}')
  screen:expect([[
    ^                                        |
    {1:~                                       }|
    {3:                                        }|
                                            |
  ]])
  feed('qQ')
  screen:expect([[
    ^                                        |
    {1:~                                       }|
    {3:QQQQQ                                   }|
    {5:recording @Q}                            |
  ]])
  feed('q')
  screen:expect([[
    ^                                        |
    {1:~                                       }|
    {3:                                        }|
                                            |
  ]])

  -- Visual mode change #23932
  command('set ls=2 stl=%{mode(1)}')
  screen:expect([[
    ^                                        |
    {1:~                                       }|
    {3:n                                       }|
                                            |
  ]])
  feed('v')
  screen:expect([[
    ^                                        |
    {1:~                                       }|
    {3:v                                       }|
    {5:-- VISUAL --}                            |
  ]])
  feed('V')
  screen:expect([[
    ^                                        |
    {1:~                                       }|
    {3:V                                       }|
    {5:-- VISUAL LINE --}                       |
  ]])
  feed('<C-V>')
  screen:expect([[
    ^                                        |
    {1:~                                       }|
    {3:^V                                      }|
    {5:-- VISUAL BLOCK --}                      |
  ]])
  feed('<Esc>')
  screen:expect([[
    ^                                        |
    {1:~                                       }|
    {3:n                                       }|
                                            |
  ]])
end)

it('ruler is redrawn in cmdline with redrawstatus #22804', function()
  clear()
  local screen = Screen.new(40, 2)
  screen:attach()
  command([[
    let g:n = 'initial value'
    set ls=1 ru ruf=%{g:n}
    redraw
    let g:n = 'other value'
    redrawstatus
  ]])
  screen:expect([[
    ^                                        |
                          other value       |
  ]])
end)

it('shows correct ruler in cmdline with no statusline', function()
  clear()
  local screen = Screen.new(30, 8)
  screen:set_default_attr_ids {
    [1] = { bold = true, foreground = Screen.colors.Blue }, -- NonText
    [2] = { bold = true, reverse = true }, -- StatusLine
    [3] = { reverse = true }, -- StatusLineNC
  }
  screen:attach()
  -- Use long ruler to check 'ruler' with 'rulerformat' set has correct width.
  command [[
    set ruler rulerformat=%{winnr()}longlonglong ls=0 winwidth=10
    split
    wincmd b
    vsplit
    wincmd t
    wincmd |
    mode
  ]]
  -- Window 1 is current. It has a statusline, so cmdline should show the
  -- last window's ruler, which has no statusline.
  command '1wincmd w'
  screen:expect [[
    ^                              |
    {1:~                             }|*2
    {2:[No Name]      1longlonglong  }|
                   │              |
    {1:~              }│{1:~             }|*2
                   3longlonglong  |
  ]]
  -- Window 2 is current. It has no statusline, so cmdline should show its
  -- ruler instead.
  command '2wincmd w'
  screen:expect [[
                                  |
    {1:~                             }|*2
    {3:[No Name]      1longlonglong  }|
    ^               │              |
    {1:~              }│{1:~             }|*2
                   2longlonglong  |
  ]]
  -- Window 3 is current. Cmdline should again show its ruler.
  command '3wincmd w'
  screen:expect [[
                                  |
    {1:~                             }|*2
    {3:[No Name]      1longlonglong  }|
                   │^              |
    {1:~              }│{1:~             }|*2
                   3longlonglong  |
  ]]
end)

it('uses "stl" and "stlnc" fillchars even if they are the same #19803', function()
  clear()
  local screen = Screen.new(53, 4)
  screen:attach()
  screen:set_default_attr_ids({
    [1] = { bold = true, foreground = Screen.colors.Blue }, -- NonText
  })
  command('hi clear StatusLine')
  command('hi clear StatusLineNC')
  command('vsplit')
  screen:expect {
    grid = [[
    ^                          │                          |
    {1:~                         }│{1:~                         }|
    [No Name]                  [No Name]                 |
                                                         |
  ]],
  }
end)

it('showcmdloc=statusline works with vertical splits', function()
  clear()
  local screen = Screen.new(53, 4)
  screen:set_default_attr_ids {
    [1] = { bold = true, foreground = Screen.colors.Blue }, -- NonText
    [2] = { bold = true, reverse = true }, -- StatusLine
    [3] = { reverse = true }, -- StatusLineNC
  }
  screen:attach()
  command('rightbelow vsplit')
  command('set showcmd showcmdloc=statusline')
  feed('1234')
  screen:expect([[
                              │^                          |
    {1:~                         }│{1:~                         }|
    {3:[No Name]                  }{2:[No Name]      1234       }|
                                                         |
  ]])
  feed('<Esc>')
  command('set laststatus=3')
  feed('1234')
  screen:expect([[
                              │^                          |
    {1:~                         }│{1:~                         }|
    {2:[No Name]                                 1234       }|
                                                         |
  ]])
end)

it('keymap is shown with vertical splits #27269', function()
  clear()
  local screen = Screen.new(53, 4)
  screen:set_default_attr_ids {
    [1] = { bold = true, foreground = Screen.colors.Blue }, -- NonText
    [2] = { bold = true, reverse = true }, -- StatusLine
    [3] = { reverse = true }, -- StatusLineNC
  }
  screen:attach()
  command('setlocal keymap=dvorak')
  command('rightbelow vsplit')
  screen:expect([[
                              │^                          |
    {1:~                         }│{1:~                         }|
    {3:[No Name]         <en-dv>  }{2:[No Name]         <en-dv> }|
                                                         |
  ]])
  command('set laststatus=3')
  screen:expect([[
                              │^                          |
    {1:~                         }│{1:~                         }|
    {2:[No Name]                                    <en-dv> }|
                                                         |
  ]])
end)
