local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local assert_alive = helpers.assert_alive
local clear = helpers.clear
local command = helpers.command
local feed = helpers.feed
local eq = helpers.eq
local funcs = helpers.funcs
local meths = helpers.meths
local exec = helpers.exec
local exec_lua = helpers.exec_lua
local eval = helpers.eval
local sleep = helpers.sleep

describe('statusline clicks', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(40, 8)
    screen:attach()
    command('set laststatus=2 mousemodel=extend')
    exec([=[
      function! MyClickFunc(minwid, clicks, button, mods)
        let g:testvar = printf("%d %d %s", a:minwid, a:clicks, a:button)
        if a:mods !=# '    '
          let g:testvar ..= '(' .. a:mods .. ')'
        endif
      endfunction
    ]=])
  end)

  it('works', function()
    meths.set_option('statusline', 'Not clicky stuff %0@MyClickFunc@Clicky stuff%T')
    meths.input_mouse('left', 'press', '', 0, 6, 17)
    eq('0 1 l', eval("g:testvar"))
    meths.input_mouse('left', 'press', '', 0, 6, 17)
    eq('0 2 l', eval("g:testvar"))
    meths.input_mouse('left', 'press', '', 0, 6, 17)
    eq('0 3 l', eval("g:testvar"))
    meths.input_mouse('left', 'press', '', 0, 6, 17)
    eq('0 4 l', eval("g:testvar"))
    meths.input_mouse('right', 'press', '', 0, 6, 17)
    eq('0 1 r', eval("g:testvar"))
    meths.input_mouse('right', 'press', '', 0, 6, 17)
    eq('0 2 r', eval("g:testvar"))
    meths.input_mouse('right', 'press', '', 0, 6, 17)
    eq('0 3 r', eval("g:testvar"))
    meths.input_mouse('right', 'press', '', 0, 6, 17)
    eq('0 4 r', eval("g:testvar"))
  end)

  it('works for winbar', function()
    meths.set_option('winbar', 'Not clicky stuff %0@MyClickFunc@Clicky stuff%T')
    meths.input_mouse('left', 'press', '', 0, 0, 17)
    eq('0 1 l', eval("g:testvar"))
    meths.input_mouse('right', 'press', '', 0, 0, 17)
    eq('0 1 r', eval("g:testvar"))
  end)

  it('works for winbar in floating window', function()
    meths.open_win(0, true, { width=30, height=4, relative='editor', row=1, col=5,
                              border = "single" })
    meths.set_option_value('winbar', 'Not clicky stuff %0@MyClickFunc@Clicky stuff%T',
                           { scope = 'local' })
    meths.input_mouse('left', 'press', '', 0, 2, 23)
    eq('0 1 l', eval("g:testvar"))
  end)

  it('works when there are multiple windows', function()
    command('split')
    meths.set_option('statusline', 'Not clicky stuff %0@MyClickFunc@Clicky stuff%T')
    meths.set_option('winbar', 'Not clicky stuff %0@MyClickFunc@Clicky stuff%T')
    meths.input_mouse('left', 'press', '', 0, 0, 17)
    eq('0 1 l', eval("g:testvar"))
    meths.input_mouse('right', 'press', '', 0, 4, 17)
    eq('0 1 r', eval("g:testvar"))
    meths.input_mouse('middle', 'press', '', 0, 3, 17)
    eq('0 1 m', eval("g:testvar"))
    meths.input_mouse('left', 'press', '', 0, 6, 17)
    eq('0 1 l', eval("g:testvar"))
  end)

  it('works with Lua function', function()
    exec_lua([[
      function clicky_func(minwid, clicks, button, mods)
        vim.g.testvar = string.format("%d %d %s", minwid, clicks, button)
      end
    ]])
    meths.set_option('statusline', 'Not clicky stuff %0@v:lua.clicky_func@Clicky stuff%T')
    meths.input_mouse('left', 'press', '', 0, 6, 17)
    eq('0 1 l', eval("g:testvar"))
  end)

  it('ignores unsupported click items', function()
    command('tabnew | tabprevious')
    meths.set_option('statusline', '%2TNot clicky stuff%T')
    meths.input_mouse('left', 'press', '', 0, 6, 0)
    eq(1, meths.get_current_tabpage().id)
    meths.set_option('statusline', '%2XNot clicky stuff%X')
    meths.input_mouse('left', 'press', '', 0, 6, 0)
    eq(2, #meths.list_tabpages())
  end)

  it("right click works when statusline isn't focused #18994", function()
    meths.set_option('statusline', 'Not clicky stuff %0@MyClickFunc@Clicky stuff%T')
    meths.input_mouse('right', 'press', '', 0, 6, 17)
    eq('0 1 r', eval("g:testvar"))
    meths.input_mouse('right', 'press', '', 0, 6, 17)
    eq('0 2 r', eval("g:testvar"))
  end)

  it("works with modifiers #18994", function()
    meths.set_option('statusline', 'Not clicky stuff %0@MyClickFunc@Clicky stuff%T')
    -- Note: alternate between left and right mouse buttons to avoid triggering multiclicks
    meths.input_mouse('left', 'press', 'S', 0, 6, 17)
    eq('0 1 l(s   )', eval("g:testvar"))
    meths.input_mouse('right', 'press', 'S', 0, 6, 17)
    eq('0 1 r(s   )', eval("g:testvar"))
    meths.input_mouse('left', 'press', 'A', 0, 6, 17)
    eq('0 1 l(  a )', eval("g:testvar"))
    meths.input_mouse('right', 'press', 'A', 0, 6, 17)
    eq('0 1 r(  a )', eval("g:testvar"))
    meths.input_mouse('left', 'press', 'AS', 0, 6, 17)
    eq('0 1 l(s a )', eval("g:testvar"))
    meths.input_mouse('right', 'press', 'AS', 0, 6, 17)
    eq('0 1 r(s a )', eval("g:testvar"))
    meths.input_mouse('left', 'press', 'T', 0, 6, 17)
    eq('0 1 l(   m)', eval("g:testvar"))
    meths.input_mouse('right', 'press', 'T', 0, 6, 17)
    eq('0 1 r(   m)', eval("g:testvar"))
    meths.input_mouse('left', 'press', 'TS', 0, 6, 17)
    eq('0 1 l(s  m)', eval("g:testvar"))
    meths.input_mouse('right', 'press', 'TS', 0, 6, 17)
    eq('0 1 r(s  m)', eval("g:testvar"))
    meths.input_mouse('left', 'press', 'C', 0, 6, 17)
    eq('0 1 l( c  )', eval("g:testvar"))
    -- <C-RightMouse> is for tag jump
  end)

  it("works for global statusline with vertical splits #19186", function()
    command('set laststatus=3')
    meths.set_option('statusline', '%0@MyClickFunc@Clicky stuff%T %= %0@MyClickFunc@Clicky stuff%T')
    command('vsplit')
    screen:expect([[
      ^                    │                   |
      ~                   │~                  |
      ~                   │~                  |
      ~                   │~                  |
      ~                   │~                  |
      ~                   │~                  |
      Clicky stuff                Clicky stuff|
                                              |
    ]])

    -- clickable area on the right
    meths.input_mouse('left', 'press', '', 0, 6, 35)
    eq('0 1 l', eval("g:testvar"))
    meths.input_mouse('right', 'press', '', 0, 6, 35)
    eq('0 1 r', eval("g:testvar"))

    -- clickable area on the left
    meths.input_mouse('left', 'press', '', 0, 6, 5)
    eq('0 1 l', eval("g:testvar"))
    meths.input_mouse('right', 'press', '', 0, 6, 5)
    eq('0 1 r', eval("g:testvar"))
  end)

  it('no memory leak with zero-width click labels', function()
    command([[
      let &stl = '%@Test@%T%@MyClickFunc@%=%T%@Test@'
    ]])
    meths.input_mouse('left', 'press', '', 0, 6, 0)
    eq('0 1 l', eval("g:testvar"))
    meths.input_mouse('right', 'press', '', 0, 6, 39)
    eq('0 1 r', eval("g:testvar"))
  end)

  it('no memory leak with truncated click labels', function()
    command([[
      let &stl = '%@MyClickFunc@foo%X' .. repeat('a', 40) .. '%<t%@Test@bar%X%@Test@baz'
    ]])
    meths.input_mouse('left', 'press', '', 0, 6, 2)
    eq('0 1 l', eval("g:testvar"))
  end)
end)

describe('global statusline', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(60, 16)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue};
      [2] = {bold = true, reverse = true};
      [3] = {bold = true};
      [4] = {reverse = true};
      [5] = {bold = true, foreground = Screen.colors.Fuchsia};
    })
    command('set laststatus=3')
    command('set ruler')
  end)

  it('works', function()
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:[No Name]                                 0,0-1          All}|
                                                                  |
    ]])

    feed('i<CR><CR>')
    screen:expect([[
                                                                  |
                                                                  |
      ^                                                            |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:[No Name] [+]                             3,1            All}|
      {3:-- INSERT --}                                                |
    ]])
  end)

  it('works with splits', function()
    command('vsplit | split | vsplit | vsplit | wincmd l | split | 2wincmd l | split')
    screen:expect([[
                          │                │ │^                    |
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|
      {1:~                   }├────────────────┤{1:~}│{1:~                   }|
      {1:~                   }│                │{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}├────────────────────|
      {1:~                   }│{1:~               }│{1:~}│                    |
      ────────────────────┴────────────────┴─┤{1:~                   }|
                                             │{1:~                   }|
      {1:~                                      }│{1:~                   }|
      {1:~                                      }│{1:~                   }|
      {1:~                                      }│{1:~                   }|
      {2:[No Name]                                 0,0-1          All}|
                                                                  |
    ]])
  end)

  it('works when switching between values of laststatus', function()
    command('set laststatus=1')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
                                                0,0-1         All |
    ]])

    command('set laststatus=3')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:[No Name]                                 0,0-1          All}|
                                                                  |
    ]])

    command('vsplit | split | vsplit | vsplit | wincmd l | split | 2wincmd l | split')
    command('set laststatus=2')
    screen:expect([[
                          │                │ │^                    |
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|
      {1:~                   }│{4:< Name] 0,0-1   }│{1:~}│{1:~                   }|
      {1:~                   }│                │{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{2:<No Name] 0,0-1  All}|
      {1:~                   }│{1:~               }│{1:~}│                    |
      {4:<No Name] 0,0-1  All < Name] 0,0-1    <}│{1:~                   }|
                                             │{1:~                   }|
      {1:~                                      }│{1:~                   }|
      {1:~                                      }│{1:~                   }|
      {1:~                                      }│{1:~                   }|
      {4:[No Name]            0,0-1          All <No Name] 0,0-1  All}|
                                                                  |
    ]])

    command('set laststatus=3')
    screen:expect([[
                          │                │ │^                    |
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|
      {1:~                   }├────────────────┤{1:~}│{1:~                   }|
      {1:~                   }│                │{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}├────────────────────|
      {1:~                   }│{1:~               }│{1:~}│                    |
      ────────────────────┴────────────────┴─┤{1:~                   }|
                                             │{1:~                   }|
      {1:~                                      }│{1:~                   }|
      {1:~                                      }│{1:~                   }|
      {1:~                                      }│{1:~                   }|
      {2:[No Name]                                 0,0-1          All}|
                                                                  |
    ]])

    command('set laststatus=0')
    screen:expect([[
                          │                │ │^                    |
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|
      {1:~                   }│{4:< Name] 0,0-1   }│{1:~}│{1:~                   }|
      {1:~                   }│                │{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{2:<No Name] 0,0-1  All}|
      {1:~                   }│{1:~               }│{1:~}│                    |
      {4:<No Name] 0,0-1  All < Name] 0,0-1    <}│{1:~                   }|
                                             │{1:~                   }|
      {1:~                                      }│{1:~                   }|
      {1:~                                      }│{1:~                   }|
      {1:~                                      }│{1:~                   }|
      {1:~                                      }│{1:~                   }|
                                                0,0-1         All |
    ]])

    command('set laststatus=3')
    screen:expect([[
                          │                │ │^                    |
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|
      {1:~                   }├────────────────┤{1:~}│{1:~                   }|
      {1:~                   }│                │{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}│{1:~                   }|
      {1:~                   }│{1:~               }│{1:~}├────────────────────|
      {1:~                   }│{1:~               }│{1:~}│                    |
      ────────────────────┴────────────────┴─┤{1:~                   }|
                                             │{1:~                   }|
      {1:~                                      }│{1:~                   }|
      {1:~                                      }│{1:~                   }|
      {1:~                                      }│{1:~                   }|
      {2:[No Name]                                 0,0-1          All}|
                                                                  |
    ]])
  end)

  it('win_move_statusline() can reduce cmdheight to 1', function()
    eq(1, meths.get_option('cmdheight'))
    funcs.win_move_statusline(0, -1)
    eq(2, meths.get_option('cmdheight'))
    funcs.win_move_statusline(0, -1)
    eq(3, meths.get_option('cmdheight'))
    funcs.win_move_statusline(0, 1)
    eq(2, meths.get_option('cmdheight'))
    funcs.win_move_statusline(0, 1)
    eq(1, meths.get_option('cmdheight'))
  end)

  it('mouse dragging can reduce cmdheight to 1', function()
    command('set mouse=a')
    meths.input_mouse('left', 'press', '', 0, 14, 10)
    eq(1, meths.get_option('cmdheight'))
    meths.input_mouse('left', 'drag', '', 0, 13, 10)
    eq(2, meths.get_option('cmdheight'))
    meths.input_mouse('left', 'drag', '', 0, 12, 10)
    eq(3, meths.get_option('cmdheight'))
    meths.input_mouse('left', 'drag', '', 0, 13, 10)
    eq(2, meths.get_option('cmdheight'))
    meths.input_mouse('left', 'drag', '', 0, 14, 10)
    eq(1, meths.get_option('cmdheight'))
    meths.input_mouse('left', 'drag', '', 0, 15, 10)
    eq(1, meths.get_option('cmdheight'))
    meths.input_mouse('left', 'drag', '', 0, 14, 10)
    eq(1, meths.get_option('cmdheight'))
  end)

  it('cmdline row is correct after setting cmdheight #20514', function()
    command('botright split test/functional/fixtures/bigfile.txt')
    meths.set_option('cmdheight', 1)
    feed('L')
    screen:expect([[
                                                                  |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
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
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
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
    meths.set_option('showtabline', 2)
    screen:expect([[
      {3: }{5:2}{3: t/f/f/bigfile.txt }{4:                                       }|
                                                                  |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
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
    meths.set_option('cmdheight', 0)
    screen:expect([[
      {3: }{5:2}{3: t/f/f/bigfile.txt }{4:                                       }|
                                                                  |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
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
    meths.set_option('cmdheight', 1)
    screen:expect([[
      {3: }{5:2}{3: t/f/f/bigfile.txt }{4:                                       }|
                                                                  |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
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
end)

it('statusline does not crash if it has Arabic characters #19447', function()
  clear()
  meths.set_option('statusline', 'غً')
  meths.set_option('laststatus', 2)
  command('redraw!')
  assert_alive()
end)

it('statusline is redrawn with :resize from <Cmd> mapping #19629', function()
  clear()
  local screen = Screen.new(40, 8)
  screen:set_default_attr_ids({
    [0] = {bold = true, foreground = Screen.colors.Blue},  -- NonText
    [1] = {bold = true, reverse = true},  -- StatusLine
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
    {0:~                                       }|
    {0:~                                       }|
    {0:~                                       }|
    {0:~                                       }|
    {1:[No Name]                               }|
                                            |
                                            |
  ]])
  feed('<Down>')
  screen:expect([[
    ^                                        |
    {0:~                                       }|
    {0:~                                       }|
    {0:~                                       }|
    {0:~                                       }|
    {0:~                                       }|
    {1:[No Name]                               }|
                                            |
  ]])
end)

it('showcmdloc=statusline does not show if statusline is too narrow', function()
  clear()
  local screen = Screen.new(40, 8)
  screen:set_default_attr_ids({
    [0] = {bold = true, foreground = Screen.colors.Blue},  -- NonText
    [1] = {bold = true, reverse = true},  -- StatusLine
    [2] = {reverse = true},  -- StatusLineNC
  })
  screen:attach()
  command('set showcmd')
  command('set showcmdloc=statusline')
  command('1vsplit')
  screen:expect([[
    ^ │                                      |
    {0:~}│{0:~                                     }|
    {0:~}│{0:~                                     }|
    {0:~}│{0:~                                     }|
    {0:~}│{0:~                                     }|
    {0:~}│{0:~                                     }|
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
