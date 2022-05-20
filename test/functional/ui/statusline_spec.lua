local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local command = helpers.command
local feed = helpers.feed
local eq = helpers.eq
local funcs = helpers.funcs
local meths = helpers.meths
local exec = helpers.exec
local exec_lua = helpers.exec_lua
local eval = helpers.eval

describe('statusline clicks', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(40, 8)
    screen:attach()
    command('set laststatus=2')
    exec([=[
      function! MyClickFunc(minwid, clicks, button, mods)
        let g:testvar = printf("%d %d %s", a:minwid, a:clicks, a:button)
      endfunction
    ]=])
  end)

  it('works', function()
    meths.set_option('statusline', 'Not clicky stuff %0@MyClickFunc@Clicky stuff%T')
    meths.input_mouse('left', 'press', '', 0, 6, 17)
    eq('0 1 l', eval("g:testvar"))
    meths.input_mouse('right', 'press', '', 0, 6, 17)
    eq('0 1 r', eval("g:testvar"))
  end)

  it('works for winbar', function()
    meths.set_option('winbar', 'Not clicky stuff %0@MyClickFunc@Clicky stuff%T')
    meths.input_mouse('left', 'press', '', 0, 0, 17)
    eq('0 1 l', eval("g:testvar"))
    meths.input_mouse('right', 'press', '', 0, 6, 17)
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
  end)
end)
