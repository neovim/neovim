local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local command = n.command
local eq = t.eq
local exec = n.exec
local eval = n.eval
local exec_lua = n.exec_lua
local feed = n.feed
local api = n.api
local pcall_err = t.pcall_err
local assert_alive = n.assert_alive

describe('statuscolumn', function()
  local screen
  before_each(function()
    clear('--cmd', 'set number nuw=1 | call setline(1, repeat(["aaaaa"], 16)) | norm GM')
    screen = Screen.new()
    screen:add_extra_attr_ids {
      [100] = { foreground = Screen.colors.Red, background = Screen.colors.LightGray },
      [101] = { background = Screen.colors.Gray90, bold = true },
      [102] = { foreground = Screen.colors.Brown, background = Screen.colors.Grey },
      [103] = { bold = true, background = Screen.colors.Grey, foreground = Screen.colors.Blue1 },
      [104] = { undercurl = true, special = Screen.colors.Red },
      [105] = { foreground = Screen.colors.Red, underline = true },
      [106] = { foreground = Screen.colors.Orange1 },
      [107] = { foreground = Screen.colors.LightBlue },
    }
    exec_lua('ns = vim.api.nvim_create_namespace("")')
  end)

  it("fails with invalid 'statuscolumn'", function()
    command(
      [[set stc=%{v:relnum?v:relnum:(v:lnum==5?'truncate':v:lnum)}%{!v:relnum&&v:lnum==5?invalid:''}\ ]]
    )
    screen:expect([[
      {8:4  }aaaaa                                             |
      {8:3  }aaaaa                                             |
      {8:2  }aaaaa                                             |
      {8:1  }aaaaa                                             |
      {8:8  }^aaaaa                                             |
      {8:1  }aaaaa                                             |
      {8:2  }aaaaa                                             |
      {8:3  }aaaaa                                             |
      {8:4  }aaaaa                                             |
      {8:5  }aaaaa                                             |
      {8:6  }aaaaa                                             |
      {8:7  }aaaaa                                             |
      {8:8  }aaaaa                                             |
                                                           |
    ]])
    command('norm 5G')
    eq('Vim(redraw):E121: Undefined variable: invalid', pcall_err(command, 'redraw!'))
    eq('', eval('&statuscolumn'))
    screen:expect([[
      {8: 4 }aaaaa                                             |
      {8: 5 }^aaaaa                                             |
      {8: 6 }aaaaa                                             |
      {8: 7 }aaaaa                                             |
      {8: 8 }aaaaa                                             |
      {8: 9 }aaaaa                                             |
      {8:10 }aaaaa                                             |
      {8:11 }aaaaa                                             |
      {8:12 }aaaaa                                             |
      {8:13 }aaaaa                                             |
      {8:14 }aaaaa                                             |
      {8:15 }aaaaa                                             |
      {8:16 }aaaaa                                             |
                                                           |
    ]])
  end)

  it("widens with irregular 'statuscolumn' width", function()
    screen:try_resize(screen._width, 4)
    command([=[
      set stc=%{v:relnum?v:relnum:(v:lnum==5?'bbbbb':v:lnum)}
      let ns = nvim_create_namespace('')
      call nvim_buf_set_extmark(0, ns, 3, 0, {'virt_text':[['virt_text']]})
      norm 5G | redraw!
    ]=])
    screen:expect([[
      {8:1    }aaaaa virt_text                                 |
      {8:bbbbb}a^eaaa                                           |
      {8:1    }aaaaa                                           |
                                                           |
    ]])
    -- Doesn't crash when trying to fill click defs that do not fit (#26845)
    command('norm gg')
    command([=[
      set stc=%@Click@%{v:relnum?v:relnum:(v:lnum==5?'bbbbb':v:lnum)}%T
      norm 5Gzt | redraw!
    ]=])
    screen:expect([[
      {8:bbbbb}a^eaaa                                           |
      {8:1    }aaaaa                                           |
      {8:2    }aaaaa                                           |
                                                           |
    ]])
    -- Doesn't crash when clicking inside padded area without click_defs
    command('set numberwidth=10')
    api.nvim_input_mouse('left', 'press', '', 0, 0, 5)
    assert_alive()
  end)

  it("works with 'number' and 'relativenumber'", function()
    screen:expect([[
      {8: 4 }aaaaa                                             |
      {8: 5 }aaaaa                                             |
      {8: 6 }aaaaa                                             |
      {8: 7 }aaaaa                                             |
      {8: 8 }^aaaaa                                             |
      {8: 9 }aaaaa                                             |
      {8:10 }aaaaa                                             |
      {8:11 }aaaaa                                             |
      {8:12 }aaaaa                                             |
      {8:13 }aaaaa                                             |
      {8:14 }aaaaa                                             |
      {8:15 }aaaaa                                             |
      {8:16 }aaaaa                                             |
                                                           |
    ]])
    command([[set stc=%l\ ]])
    screen:expect_unchanged()
    command('set relativenumber')
    screen:expect([[
      {8: 4 }aaaaa                                             |
      {8: 3 }aaaaa                                             |
      {8: 2 }aaaaa                                             |
      {8: 1 }aaaaa                                             |
      {8:8  }^aaaaa                                             |
      {8: 1 }aaaaa                                             |
      {8: 2 }aaaaa                                             |
      {8: 3 }aaaaa                                             |
      {8: 4 }aaaaa                                             |
      {8: 5 }aaaaa                                             |
      {8: 6 }aaaaa                                             |
      {8: 7 }aaaaa                                             |
      {8: 8 }aaaaa                                             |
                                                           |
    ]])
    command('set stc=')
    screen:expect_unchanged()
    command([[set nonu stc=%l\ ]])
    screen:expect([[
      {8: 4 }aaaaa                                             |
      {8: 3 }aaaaa                                             |
      {8: 2 }aaaaa                                             |
      {8: 1 }aaaaa                                             |
      {8: 0 }^aaaaa                                             |
      {8: 1 }aaaaa                                             |
      {8: 2 }aaaaa                                             |
      {8: 3 }aaaaa                                             |
      {8: 4 }aaaaa                                             |
      {8: 5 }aaaaa                                             |
      {8: 6 }aaaaa                                             |
      {8: 7 }aaaaa                                             |
      {8: 8 }aaaaa                                             |
                                                           |
    ]])
    command('set nuw=1 stc=')
    screen:expect_unchanged()
    -- Correct alignment with items before and after number column
    command([[set nu stc=foo\ %l\ bar]])
    screen:expect([[
      {8:foo  4 bar}aaaaa                                      |
      {8:foo  3 bar}aaaaa                                      |
      {8:foo  2 bar}aaaaa                                      |
      {8:foo  1 bar}aaaaa                                      |
      {8:foo 8  bar}^aaaaa                                      |
      {8:foo  1 bar}aaaaa                                      |
      {8:foo  2 bar}aaaaa                                      |
      {8:foo  3 bar}aaaaa                                      |
      {8:foo  4 bar}aaaaa                                      |
      {8:foo  5 bar}aaaaa                                      |
      {8:foo  6 bar}aaaaa                                      |
      {8:foo  7 bar}aaaaa                                      |
      {8:foo  8 bar}aaaaa                                      |
                                                           |
    ]])
  end)

  it("works with highlighted 'statuscolumn'", function()
    command(
      [[set stc=%#NonText#%{&nu?v:lnum:''}]]
        .. [[%=%{&rnu&&(v:lnum%2)?'\ '.v:relnum:''}]]
        .. [[%#LineNr#%{&rnu&&!(v:lnum%2)?'\ '.v:relnum:''}│]]
    )
    screen:expect([[
      {1:4 }{8:│}aaaaa                                             |
      {1:5 }{8:│}aaaaa                                             |
      {1:6 }{8:│}aaaaa                                             |
      {1:7 }{8:│}aaaaa                                             |
      {1:8 }{8:│}^aaaaa                                             |
      {1:9 }{8:│}aaaaa                                             |
      {1:10}{8:│}aaaaa                                             |
      {1:11}{8:│}aaaaa                                             |
      {1:12}{8:│}aaaaa                                             |
      {1:13}{8:│}aaaaa                                             |
      {1:14}{8:│}aaaaa                                             |
      {1:15}{8:│}aaaaa                                             |
      {1:16}{8:│}aaaaa                                             |
                                                           |
    ]])
    command('set relativenumber')
    screen:expect([[
      {1:4  }{8: 4│}aaaaa                                          |
      {1:5   3}{8:│}aaaaa                                          |
      {1:6  }{8: 2│}aaaaa                                          |
      {1:7   1}{8:│}aaaaa                                          |
      {1:8  }{8: 0│}^aaaaa                                          |
      {1:9   1}{8:│}aaaaa                                          |
      {1:10 }{8: 2│}aaaaa                                          |
      {1:11  3}{8:│}aaaaa                                          |
      {1:12 }{8: 4│}aaaaa                                          |
      {1:13  5}{8:│}aaaaa                                          |
      {1:14 }{8: 6│}aaaaa                                          |
      {1:15  7}{8:│}aaaaa                                          |
      {1:16 }{8: 8│}aaaaa                                          |
                                                           |
    ]])
    command('set nonumber')
    screen:expect([[
      {1: }{8:4│}aaaaa                                             |
      {1: 3}{8:│}aaaaa                                             |
      {1: }{8:2│}aaaaa                                             |
      {1: 1}{8:│}aaaaa                                             |
      {1: }{8:0│}^aaaaa                                             |
      {1: 1}{8:│}aaaaa                                             |
      {1: }{8:2│}aaaaa                                             |
      {1: 3}{8:│}aaaaa                                             |
      {1: }{8:4│}aaaaa                                             |
      {1: 5}{8:│}aaaaa                                             |
      {1: }{8:6│}aaaaa                                             |
      {1: 7}{8:│}aaaaa                                             |
      {1: }{8:8│}aaaaa                                             |
                                                           |
    ]])
    -- Last segment and fillchar are highlighted properly
    command("set stc=%#Error#%{v:relnum?'Foo':'FooBar'}")
    screen:expect([[
      {9:Foo   }aaaaa                                          |*4
      {9:FooBar}^aaaaa                                          |
      {9:Foo   }aaaaa                                          |*8
                                                           |
    ]])
  end)

  it('works with wrapped lines, signs and folds', function()
    command([[set cursorline stc=%C%s%=%{v:virtnum?'':v:lnum}│\ ]])
    command("call setline(1,repeat([repeat('aaaaa',10)],16))")
    command('hi! CursorLine gui=bold')
    command('sign define num1 numhl=Special')
    command('sign place 1 line=8 name=num1 buffer=1')
    screen:expect([[
      {8: 4│ }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {8:  │ }a                                                |
      {8: 5│ }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {8:  │ }a                                                |
      {8: 6│ }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {8:  │ }a                                                |
      {8: 7│ }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {8:  │ }a                                                |
      {29: 8│ }{101:^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}|
      {29:  │ }{101:a                                                }|
      {8: 9│ }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {8:  │ }a                                                |
      {8:10│ }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa{1:@@@}|
                                                           |
    ]])
    command([[set stc=%C%s%=%l│\ ]])
    screen:expect_unchanged()
    command('hi! CursorLine guifg=Red guibg=NONE gui=NONE')
    command('set nocursorline signcolumn=auto:2 foldcolumn=auto')
    command('sign define piet1 text=>> texthl=LineNr')
    command('sign define piet2 text=>! texthl=NonText')
    command('sign place 1 line=4 name=piet1 buffer=1')
    command('sign place 2 line=5 name=piet2 buffer=1')
    command('sign place 3 line=6 name=piet1 buffer=1')
    command('sign place 4 line=6 name=piet2 buffer=1')
    screen:expect([[
      {102:>>}{7:  }{8: 4│ }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7:    }{8:  │ }aaaaa                                        |
      {103:>!}{7:  }{8: 5│ }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7:    }{8:  │ }aaaaa                                        |
      {103:>!}{102:>>}{8: 6│ }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7:    }{8:  │ }aaaaa                                        |
      {7:    }{8: 7│ }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7:    }{8:  │ }aaaaa                                        |
      {7:    }{8: 8│ }^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7:    }{8:  │ }aaaaa                                        |
      {7:    }{8: 9│ }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7:    }{8:  │ }aaaaa                                        |
      {7:    }{8:10│ }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa{1:@@@}|
                                                           |
    ]])
    command('norm zf$')
    -- Check that alignment works properly with signs after %=
    command([[set stc=%C%=%{v:virtnum?'':v:lnum}│%s\ ]])
    screen:expect([[
      {7: }{8: 4│}{102:>>}{7:  }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:  │}{7:    }{8: }aaaaaa                                      |
      {7: }{8: 5│}{103:>!}{7:  }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:  │}{7:    }{8: }aaaaaa                                      |
      {7: }{8: 6│}{103:>!}{102:>>}{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:  │}{7:    }{8: }aaaaaa                                      |
      {7: }{8: 7│}{7:    }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:  │}{7:    }{8: }aaaaaa                                      |
      {7:+}{8: 8│}{7:    }{8: }{13:^+--  1 line: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}|
      {7: }{8: 9│}{7:    }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:  │}{7:    }{8: }aaaaaa                                      |
      {7: }{8:10│}{7:    }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:  │}{7:    }{8: }aaaaaa                                      |
                                                           |
    ]])
    command('set cursorline')
    screen:expect([[
      {7: }{8: 4│}{102:>>}{7:  }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:  │}{7:    }{8: }aaaaaa                                      |
      {7: }{8: 5│}{103:>!}{7:  }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:  │}{7:    }{8: }aaaaaa                                      |
      {7: }{8: 6│}{103:>!}{102:>>}{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:  │}{7:    }{8: }aaaaaa                                      |
      {7: }{8: 7│}{7:    }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:  │}{7:    }{8: }aaaaaa                                      |
      {7:+}{15: 8│}{7:    }{15: }{100:^+--  1 line: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}|
      {7: }{8: 9│}{7:    }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:  │}{7:    }{8: }aaaaaa                                      |
      {7: }{8:10│}{7:    }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:  │}{7:    }{8: }aaaaaa                                      |
                                                           |
    ]])
    -- v:lnum is the same value on wrapped lines
    command([[set stc=%C%=%{v:lnum}│%s\ ]])
    screen:expect([[
      {7: }{8: 4│}{102:>>}{7:  }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8: 4│}{7:    }{8: }aaaaaa                                      |
      {7: }{8: 5│}{103:>!}{7:  }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8: 5│}{7:    }{8: }aaaaaa                                      |
      {7: }{8: 6│}{103:>!}{102:>>}{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8: 6│}{7:    }{8: }aaaaaa                                      |
      {7: }{8: 7│}{7:    }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8: 7│}{7:    }{8: }aaaaaa                                      |
      {7:+}{15: 8│}{7:    }{15: }{100:^+--  1 line: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}|
      {7: }{8: 9│}{7:    }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8: 9│}{7:    }{8: }aaaaaa                                      |
      {7: }{8:10│}{7:    }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:10│}{7:    }{8: }aaaaaa                                      |
                                                           |
    ]])
    -- v:relnum is the same value on wrapped lines
    command([[set stc=%C%=\ %{v:relnum}│%s\ ]])
    screen:expect([[
      {7: }{8:  4│}{102:>>}{7:  }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:  4│}{7:    }{8: }aaaaaaa                                    |
      {7: }{8:  3│}{103:>!}{7:  }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:  3│}{7:    }{8: }aaaaaaa                                    |
      {7: }{8:  2│}{103:>!}{102:>>}{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:  2│}{7:    }{8: }aaaaaaa                                    |
      {7: }{8:  1│}{7:    }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:  1│}{7:    }{8: }aaaaaaa                                    |
      {7:+}{15:  0│}{7:    }{15: }{100:^+--  1 line: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}|
      {7: }{8:  1│}{7:    }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:  1│}{7:    }{8: }aaaaaaa                                    |
      {7: }{8:  2│}{7:    }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:  2│}{7:    }{8: }aaaaaaa                                    |
                                                           |
    ]])
    command([[set stc=%C%=\ %{v:virtnum?'':v:relnum}│%s\ ]])
    screen:expect([[
      {7: }{8:  4│}{102:>>}{7:  }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:   │}{7:    }{8: }aaaaaaa                                    |
      {7: }{8:  3│}{103:>!}{7:  }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:   │}{7:    }{8: }aaaaaaa                                    |
      {7: }{8:  2│}{103:>!}{102:>>}{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:   │}{7:    }{8: }aaaaaaa                                    |
      {7: }{8:  1│}{7:    }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:   │}{7:    }{8: }aaaaaaa                                    |
      {7:+}{15:  0│}{7:    }{15: }{100:^+--  1 line: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}|
      {7: }{8:  1│}{7:    }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:   │}{7:    }{8: }aaaaaaa                                    |
      {7: }{8:  2│}{7:    }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:   │}{7:    }{8: }aaaaaaa                                    |
                                                           |
    ]])
    -- Up to 9 signs in a line
    command('set signcolumn=auto:9 foldcolumn=auto')
    command('sign place 5 line=6 name=piet1 buffer=1')
    command('sign place 6 line=6 name=piet2 buffer=1')
    command('sign place 7 line=6 name=piet1 buffer=1')
    command('sign place 8 line=6 name=piet2 buffer=1')
    command('sign place 9 line=6 name=piet1 buffer=1')
    command('sign place 10 line=6 name=piet2 buffer=1')
    command('sign place 11 line=6 name=piet1 buffer=1')
    screen:expect([[
      {7: }{8:  4│}{102:>>}{7:                }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:   │}{7:                  }{8: }aaaaaaaaaaaaaaaaaaaaa        |
      {7: }{8:  3│}{103:>!}{7:                }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:   │}{7:                  }{8: }aaaaaaaaaaaaaaaaaaaaa        |
      {7: }{8:  2│}{102:>>}{103:>!}{102:>>}{103:>!}{102:>>}{103:>!}{102:>>}{103:>!}{102:>>}{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:   │}{7:                  }{8: }aaaaaaaaaaaaaaaaaaaaa        |
      {7: }{8:  1│}{7:                  }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:   │}{7:                  }{8: }aaaaaaaaaaaaaaaaaaaaa        |
      {7:+}{15:  0│}{7:                  }{15: }{100:^+--  1 line: aaaaaaaaaaaaaaaa}|
      {7: }{8:  1│}{7:                  }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:   │}{7:                  }{8: }aaaaaaaaaaaaaaaaaaaaa        |
      {7: }{8:  2│}{7:                  }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7: }{8:   │}{7:                  }{8: }aaaaaaaaaaaaaaaaaaaaa        |
                                                           |
    ]])
    -- Also test fold and sign column when 'cpoptions' includes "n"
    command('set cpoptions+=n')
    feed('Hgjg0')
    screen:expect([[
      {7: }{15:  0│}{102:>>}{7:                }{15: }{19:aaaaaaaaaaaaaaaaaaaaaaaaaaaaa}|
      {7:                   }{19:^aaaaaaaaaaaaaaaaaaaaa             }|
      {7: }{8:  3│}{103:>!}{7:                }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7:                   }aaaaaaaaaaaaaaaaaaaaa             |
      {7: }{8:  2│}{102:>>}{103:>!}{102:>>}{103:>!}{102:>>}{103:>!}{102:>>}{103:>!}{102:>>}{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7:                   }aaaaaaaaaaaaaaaaaaaaa             |
      {7: }{8:  1│}{7:                  }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7:                   }aaaaaaaaaaaaaaaaaaaaa             |
      {7:+}{8:  4│}{7:                  }{8: }{13:+--  1 line: aaaaaaaaaaaaaaaa}|
      {7: }{8:  1│}{7:                  }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7:                   }aaaaaaaaaaaaaaaaaaaaa             |
      {7: }{8:  2│}{7:                  }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7:                   }aaaaaaaaaaaaaaaaaaaaa             |
                                                           |
    ]])
    command('set breakindent')
    command('sign unplace 2')
    feed('J2gjg0')
    screen:expect([[
      {7: }{15:  0│}{102:>>}{7:                }{15: }{19:aaaaaaaaaaaaaaaaaaaaaaaaaaaaa}|
      {7:                   }     {19:aaaaaaaaaaaaaaaaaaaaa aaaaaaa}|
      {7:                   }     {19:aaaaaaaaaaaaaaaaaaaaaaaaaaaaa}|
      {7:                   }     {19:^aaaaaaaaaaaaaa               }|
      {7: }{8:  1│}{102:>>}{103:>!}{102:>>}{103:>!}{102:>>}{103:>!}{102:>>}{103:>!}{102:>>}{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7:                   }     aaaaaaaaaaaaaaaaaaaaa        |
      {7: }{8:  2│}{7:                  }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7:                   }     aaaaaaaaaaaaaaaaaaaaa        |
      {7:+}{8:  3│}{7:                  }{8: }{13:+--  1 line: aaaaaaaaaaaaaaaa}|
      {7: }{8:  4│}{7:                  }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7:                   }     aaaaaaaaaaaaaaaaaaaaa        |
      {7: }{8:  5│}{7:                  }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7:                   }     aaaaaaaaaaaaaaaaaaaaa        |
                                                           |
    ]])
    command('set nobreakindent')
    feed('$g0')
    screen:expect([[
      {7: }{15:  0│}{102:>>}{7:                }{15: }{19:aaaaaaaaaaaaaaaaaaaaaaaaaaaaa}|
      {7:                   }{19:aaaaaaaaaaaaaaaaaaaaa aaaaaaaaaaaa}|
      {7:                   }{19:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}|
      {7:                   }{19:^aaaa                              }|
      {7: }{8:  1│}{102:>>}{103:>!}{102:>>}{103:>!}{102:>>}{103:>!}{102:>>}{103:>!}{102:>>}{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7:                   }aaaaaaaaaaaaaaaaaaaaa             |
      {7: }{8:  2│}{7:                  }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7:                   }aaaaaaaaaaaaaaaaaaaaa             |
      {7:+}{8:  3│}{7:                  }{8: }{13:+--  1 line: aaaaaaaaaaaaaaaa}|
      {7: }{8:  4│}{7:                  }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7:                   }aaaaaaaaaaaaaaaaaaaaa             |
      {7: }{8:  5│}{7:                  }{8: }aaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {7:                   }aaaaaaaaaaaaaaaaaaaaa             |
                                                           |
    ]])
    command('silent undo')
    feed('8gg')
    command('set cpoptions-=n')
    -- Status column is re-evaluated for virt_lines, buffer line, and wrapped line
    exec_lua([[
      vim.api.nvim_buf_set_extmark(0, ns, 5, 0, {
        virt_lines_above = true, virt_lines = {{{"virt_line above", ""}}} })
      vim.api.nvim_buf_set_extmark(0, ns, 4, 0, { virt_lines = {{{"virt_line", ""}}} })
    ]])
    command('set foldcolumn=0 signcolumn=number stc=%l')
    screen:expect([[
      {102:>>}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa |
      {8: 5}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa |
      {8:  }virt_line                                          |
      {8:  }virt_line above                                    |
      {102:>>}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa |
      {8: 7}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa |
      {15: 8}{100:^+--  1 line: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}|
      {8: 9}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa |
      {8:10}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa |
      {8:11}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa |
      {8:12}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa |
      {8:13}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa |
      {8:14}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa |
                                                           |
    ]])
    command(
      [[set stc=%{v:virtnum<0?'virtual':(!v:virtnum?'buffer':'wrapped')}%=%{'\ '.v:virtnum.'\ '.v:lnum}]]
    )
    screen:expect([[
      {8:buffer  0 4}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {8:wrapped 1 4}aaaaaaaa                                  |
      {8:buffer  0 5}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {8:wrapped 1 5}aaaaaaaa                                  |
      {8:virtual-2 5}virt_line                                 |
      {8:virtual-1 5}virt_line above                           |
      {8:buffer  0 6}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {8:wrapped 1 6}aaaaaaaa                                  |
      {8:buffer  0 7}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {8:wrapped 1 7}aaaaaaaa                                  |
      {15:buffer  0 8}{100:^+--  1 line: aaaaaaaaaaaaaaaaaaaaaaaaaaaaa}|
      {8:buffer  0 9}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {8:wrapped 1 9}aaaaaaaa                                  |
                                                           |
    ]])
    -- Also test virt_lines at the end of buffer
    exec_lua([[
      vim.api.nvim_buf_set_extmark(0, ns, 15, 0, { virt_lines = {{{"END", ""}}} })
    ]])
    feed('GkJzz')
    screen:expect([[
      {8:buffer  0 12}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {8:wrapped 1 12}aaaaaaaaa                                |
      {8:buffer  0 13}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {8:wrapped 1 13}aaaaaaaaa                                |
      {8:buffer  0 14}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {8:wrapped 1 14}aaaaaaaaa                                |
      {15:buffer  0 15}{19:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}|
      {15:wrapped 1 15}{19:aaaaaaaaa^ aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}|
      {15:wrapped 2 15}{19:aaaaaaaaaaaaaaaaaaa                      }|
      {8:virtual-1 15}END                                      |
      {1:~                                                    }|*3
                                                           |
    ]])
    -- Also test virt_lines when 'cpoptions' includes "n"
    exec_lua([[
      vim.opt.cpoptions:append("n")
      vim.api.nvim_buf_set_extmark(0, ns, 14, 0, { virt_lines = {{{"virt_line1", ""}}} })
      vim.api.nvim_buf_set_extmark(0, ns, 14, 0, { virt_lines = {{{"virt_line2", ""}}} })
    ]])
    screen:expect([[
      {8:buffer  0 12}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      aaaaaaaaa                                            |
      {8:buffer  0 13}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      aaaaaaaaa                                            |
      {8:buffer  0 14}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      aaaaaaaaa                                            |
      {15:buffer  0 15}{19:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}|
      {19:aaaaaaaaa^ aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa}|
      {19:aaaaaaa                                              }|
      {8:virtual-3 15}virt_line1                               |
      {8:virtual-2 15}virt_line2                               |
      {8:virtual-1 15}END                                      |
      {1:~                                                    }|
                                                           |
    ]])
    -- Also test "col_rows" code path for 'relativenumber' cursor movement
    command([[
      set cpoptions-=n nocursorline relativenumber
      set stc=%{v:virtnum<0?'virtual':(!v:virtnum?'buffer':'wrapped')}%=%{'\ '.v:virtnum.'\ '.v:lnum.'\ '.v:relnum}
    ]])
    screen:expect([[
      {8:buffer  0 12 3}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {8:wrapped 1 12 3}aaaaaaaaaaa                            |
      {8:buffer  0 13 2}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {8:wrapped 1 13 2}aaaaaaaaaaa                            |
      {8:buffer  0 14 1}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {8:wrapped 1 14 1}aaaaaaaaaaa                            |
      {8:buffer  0 15 0}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {8:wrapped 1 15 0}aaaaaaaaaaa^ aaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {8:wrapped 2 15 0}aaaaaaaaaaaaaaaaaaaaaaa                |
      {8:virtual-3 15 0}virt_line1                             |
      {8:virtual-2 15 0}virt_line2                             |
      {8:virtual-1 15 0}END                                    |
      {1:~                                                    }|
                                                           |
    ]])
    feed('kk')
    screen:expect([[
      {8:buffer  0 12 1}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {8:wrapped 1 12 1}aaaaaaaaaaa                            |
      {8:buffer  0 13 0}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {8:wrapped 1 13 0}aaaaaaaaaa^a                            |
      {8:buffer  0 14 1}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {8:wrapped 1 14 1}aaaaaaaaaaa                            |
      {8:buffer  0 15 2}aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {8:wrapped 1 15 2}aaaaaaaaaaa aaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {8:wrapped 2 15 2}aaaaaaaaaaaaaaaaaaaaaaa                |
      {8:virtual-3 15 2}virt_line1                             |
      {8:virtual-2 15 2}virt_line2                             |
      {8:virtual-1 15 2}END                                    |
      {1:~                                                    }|
                                                           |
    ]])
  end)

  it('does not corrupt the screen with minwid sign item', function()
    screen:try_resize(screen._width, 3)
    command([[set stc=%6s\ %l]])
    exec_lua('vim.api.nvim_buf_set_extmark(0, ns, 7, 0, {sign_text = "𒀀"})')
    screen:expect([[
      {8:    }{7:𒀀 }{8:  8}^aaaaa                                       |
      {8:    }{7:  }{8:  9}aaaaa                                       |
                                                           |
    ]])
  end)

  for _, model in ipairs({ 'extend', 'popup', 'popup_setpos' }) do
    describe('with mousemodel=' .. model, function()
      before_each(function()
        command('set mousemodel=' .. model)
        exec([[
          function! MyClickFunc(minwid, clicks, button, mods)
            let g:testvar = printf("%d %d %s %d", a:minwid, a:clicks, a:button, getmousepos().line)
            if a:mods !=# '    '
              let g:testvar ..= '(' .. a:mods .. ')'
            endif
          endfunction
          let g:testvar = ''
        ]])
      end)

      it('clicks work with mousemodel=' .. model, function()
        api.nvim_set_option_value('statuscolumn', '%0@MyClickFunc@%=%l%T', {})
        api.nvim_input_mouse('left', 'press', '', 0, 0, 0)
        eq('0 1 l 4', eval('g:testvar'))
        api.nvim_input_mouse('left', 'press', '', 0, 0, 0)
        eq('0 2 l 4', eval('g:testvar'))
        api.nvim_input_mouse('left', 'press', '', 0, 0, 0)
        eq('0 3 l 4', eval('g:testvar'))
        api.nvim_input_mouse('left', 'press', '', 0, 0, 0)
        eq('0 4 l 4', eval('g:testvar'))
        api.nvim_input_mouse('right', 'press', '', 0, 3, 0)
        eq('0 1 r 7', eval('g:testvar'))
        api.nvim_input_mouse('right', 'press', '', 0, 3, 0)
        eq('0 2 r 7', eval('g:testvar'))
        api.nvim_input_mouse('right', 'press', '', 0, 3, 0)
        eq('0 3 r 7', eval('g:testvar'))
        api.nvim_input_mouse('right', 'press', '', 0, 3, 0)
        eq('0 4 r 7', eval('g:testvar'))

        command('rightbelow vsplit')
        api.nvim_input_mouse('left', 'press', '', 0, 0, 27)
        eq('0 1 l 4', eval('g:testvar'))
        api.nvim_input_mouse('right', 'press', '', 0, 3, 27)
        eq('0 1 r 7', eval('g:testvar'))
        command('setlocal rightleft')
        api.nvim_input_mouse('left', 'press', '', 0, 0, 52)
        eq('0 1 l 4', eval('g:testvar'))
        api.nvim_input_mouse('right', 'press', '', 0, 3, 52)
        eq('0 1 r 7', eval('g:testvar'))
        command('wincmd H')
        api.nvim_input_mouse('left', 'press', '', 0, 0, 25)
        eq('0 1 l 4', eval('g:testvar'))
        api.nvim_input_mouse('right', 'press', '', 0, 3, 25)
        eq('0 1 r 7', eval('g:testvar'))
        command('close')

        command('set laststatus=2 winbar=%f')
        command('let g:testvar = ""')
        -- Check that winbar click doesn't register as statuscolumn click
        api.nvim_input_mouse('right', 'press', '', 0, 0, 0)
        eq('', eval('g:testvar'))
        -- Check that statusline click doesn't register as statuscolumn click
        api.nvim_input_mouse('right', 'press', '', 0, 12, 0)
        eq('', eval('g:testvar'))
        -- Check that rightclick still opens popupmenu if there is no clickdef
        if model == 'popup' then
          api.nvim_set_option_value('statuscolumn', '%0@MyClickFunc@%=%l%TNoClick', {})
          api.nvim_input_mouse('right', 'press', '', 0, 1, 0)
          screen:expect([[
            {5:[No Name]                                            }|
            {8: 4NoClick}^aaaaa                                       |
            {8: 5NoClick}aaaaa                                       |
            {8: 6NoClick}aaaaa                                       |
            {8: 7NoClick}aaaaa                                       |
            {8: 8NoClick}aaaaa                                       |
            {8: 9NoClick}aaaaa                                       |
            {8:10NoClick}aaaaa                                       |
            {8:11NoClick}aaaaa                                       |
            {8:12NoClick}aaaaa                                       |
            {8:13NoClick}aaaaa                                       |
            {8:14NoClick}aaaaa                                       |
            {3:[No Name] [+]                                        }|
                                                                 |
          ]])
          api.nvim_input_mouse('right', 'press', '', 0, 1, 3)
          screen:expect([[
            {5:[No Name]                                            }|
            {8: 4NoClick}^aaaaa                                       |
            {8: 5}{4: Inspect              }                             |
            {8: 6}{4:                      }                             |
            {8: 7}{4: Paste                }                             |
            {8: 8}{4: Select All           }                             |
            {8: 9}{4:                      }                             |
            {8:10}{4: How-to disable mouse }                             |
            {8:11NoClick}aaaaa                                       |
            {8:12NoClick}aaaaa                                       |
            {8:13NoClick}aaaaa                                       |
            {8:14NoClick}aaaaa                                       |
            {3:[No Name] [+]                                        }|
                                                                 |
          ]])
        end
      end)

      it('clicks and highlights work with control characters', function()
        api.nvim_set_option_value('statuscolumn', '\t%#NonText#\1%0@MyClickFunc@\t\1%T\t%##\1', {})
        screen:expect([[
          {8:^I}{1:^A^I^A^I}{8:^A}aaaaa                                    |*4
          {8:^I}{1:^A^I^A^I}{8:^A}^aaaaa                                    |
          {8:^I}{1:^A^I^A^I}{8:^A}aaaaa                                    |*8
                                                               |
        ]])
        api.nvim_input_mouse('right', 'press', '', 0, 4, 3)
        feed('<Esc>') -- Close popupmenu
        eq('', eval('g:testvar'))
        api.nvim_input_mouse('left', 'press', '', 0, 5, 8)
        eq('', eval('g:testvar'))
        api.nvim_input_mouse('right', 'press', '', 0, 6, 4)
        eq('0 1 r 10', eval('g:testvar'))
        api.nvim_input_mouse('left', 'press', '', 0, 7, 7)
        eq('0 1 l 11', eval('g:testvar'))
      end)

      it('popupmenu callback does not drag mouse on close', function()
        screen:try_resize(screen._width, 2)
        api.nvim_set_option_value('statuscolumn', '%0@MyClickFunc@%l%T', {})
        exec([[
          function! MyClickFunc(minwid, clicks, button, mods)
            let g:testvar = printf("%d %d %s %d", a:minwid, a:clicks, a:button, getmousepos().line)
            menu PopupStc.Echo <cmd>echo g:testvar<CR>
            popup PopupStc
          endfunction
        ]])
        -- clicking an item does not drag mouse
        api.nvim_input_mouse('left', 'press', '', 0, 0, 0)
        screen:expect([[
          {8: 8}^aaaaa                                              |
           {4: Echo }                                              |
        ]])
        api.nvim_input_mouse('left', 'press', '', 0, 1, 5)
        api.nvim_input_mouse('left', 'release', '', 0, 1, 5)
        screen:expect([[
          {8: 8}^aaaaa                                              |
          0 1 l 8                                              |
        ]])
        command('echo')
        -- clicking outside to close the menu does not drag mouse
        api.nvim_input_mouse('left', 'press', '', 0, 0, 0)
        screen:expect([[
          {8: 8}^aaaaa                                              |
           {4: Echo }                                              |
        ]])
        api.nvim_input_mouse('left', 'press', '', 0, 0, 10)
        api.nvim_input_mouse('left', 'release', '', 0, 0, 10)
        screen:expect([[
          {8: 8}^aaaaa                                              |
                                                               |
        ]])
      end)

      it('foldcolumn item can be clicked', function()
        api.nvim_set_option_value('statuscolumn', '|%C|', {})
        api.nvim_set_option_value('foldcolumn', '2', {})
        api.nvim_set_option_value('mousetime', 0, {})
        feed('ggzfjzfjzo')
        local s1 = [[
          {8:|}{7:-+}{8:|}{13:^+---  2 lines: aaaaa·····························}|
          {8:|}{7:│ }{8:|}aaaaa                                            |
          {8:|}{7:  }{8:|}aaaaa                                            |*11
                                                               |
        ]]
        screen:expect(s1)
        api.nvim_input_mouse('left', 'press', '', 0, 0, 2)
        screen:expect([[
          {8:|}{7:--}{8:|}^aaaaa                                            |
          {8:|}{7:││}{8:|}aaaaa                                            |
          {8:|}{7:│ }{8:|}aaaaa                                            |
          {8:|}{7:  }{8:|}aaaaa                                            |*10
                                                               |
        ]])
        api.nvim_input_mouse('left', 'press', '', 0, 0, 1)
        screen:expect(s1)
        api.nvim_input_mouse('left', 'press', '', 0, 0, 1)
        screen:expect([[
          {8:|}{7:+ }{8:|}{13:^+--  3 lines: aaaaa······························}|
          {8:|}{7:  }{8:|}aaaaa                                            |*12
                                                               |
        ]])
      end)
    end)
  end

  it('click labels do not leak memory #21878', function()
    exec([[
      set laststatus=2
      setlocal statuscolumn=%0@MyClickFunc@abcd%T
      4vsplit
      setlocal statusline=abcd
      redrawstatus
      setlocal statusline=
      only
      redraw
    ]])
  end)

  it('click labels do not crash when initial width is 0 #24428', function()
    exec([[
      set nonumber
      bwipe!
      setlocal statuscolumn=abcd
      redraw
      setlocal statuscolumn=%0@MyClickFunc@abcd%T
      redraw
    ]])
    assert_alive()
  end)

  it('works with foldcolumn', function()
    -- Fits maximum multibyte foldcolumn #21759
    command([[set stc=%C%=%l\  fdc=9 fillchars=foldsep:𒀀]])
    for _ = 0, 8 do
      command('norm zfjzo')
    end
    -- 'statuscolumn' is not drawn for `virt_lines_leftcol` lines
    exec_lua([[
      vim.api.nvim_buf_set_extmark(0, ns, 6, 0, {
        virt_lines_leftcol = true, virt_lines = {{{"virt", ""}}} })
      vim.api.nvim_buf_set_extmark(0, ns, 7, 0, {
        virt_lines_leftcol = true, virt_lines = {{{"virt", ""}}} })
    ]])
    screen:expect([[
      {7:         }{8: 4 }aaaaa                                    |
      {7:         }{8: 5 }aaaaa                                    |
      {7:         }{8: 6 }aaaaa                                    |
      {7:         }{8: 7 }aaaaa                                    |
      virt                                                 |
      {7:---------}{8: 8 }^aaaaa                                    |
      virt                                                 |
      {7:𒀀𒀀𒀀𒀀𒀀𒀀𒀀𒀀𒀀}{8: 9 }aaaaa                                    |
      {7:         }{8:10 }aaaaa                                    |
      {7:         }{8:11 }aaaaa                                    |
      {7:         }{8:12 }aaaaa                                    |
      {7:         }{8:13 }aaaaa                                    |
      {7:         }{8:14 }aaaaa                                    |
                                                           |
    ]])
    command('set stc=') -- also for the default fold column
    screen:expect_unchanged()
    -- 'statuscolumn' is not too wide with custom (bogus) fold column
    command([[set stc=%{foldlevel(v:lnum)>0?repeat('-',foldlevel(v:lnum)):''}%=%l\ ]])
    feed('Gd10Ggg<C-l>')
    screen:expect([[
      {8:         1 }^aaaaa                                     |
      {8:         2 }aaaaa                                     |
      {8:         3 }aaaaa                                     |
      {8:         4 }aaaaa                                     |
      {8:         5 }aaaaa                                     |
      {8:         6 }aaaaa                                     |
      {8:         7 }aaaaa                                     |
      virt                                                 |
      {8:---------8 }aaaaa                                     |
      virt                                                 |
      {8:---------9 }aaaaa                                     |
      {1:~                                                    }|*2
                                                           |
    ]])
  end)

  it('works with cmdwin', function()
    feed(':set stc=%l<CR>q:k$')
    screen:expect([[
      {8: 7}aaaaa                                              |
      {8: 8}aaaaa                                              |
      {8: 9}aaaaa                                              |
      {8:10}aaaaa                                              |
      {2:[No Name] [+]                                        }|
      {1::}{8:1}set stc=%^l                                         |
      {1::}{8:2}                                                   |
      {1:~                                                    }|*5
      {3:[Command Line]                                       }|
      :                                                    |
    ]])
  end)

  it("has correct width when toggling '(relative)number'", function()
    screen:try_resize(screen._width, 6)
    command('call setline(1, repeat(["aaaaa"], 100))')
    command('set relativenumber')
    command([[set stc=%{!&nu&&!&rnu?'':&rnu?v:relnum?v:relnum:&nu?v:lnum:'0':v:lnum}]])
    screen:expect([[
      {8:1  }aaaaa                                             |
      {8:8  }^aaaaa                                             |
      {8:1  }aaaaa                                             |
      {8:2  }aaaaa                                             |
      {8:3  }aaaaa                                             |
                                                           |
    ]])
    -- width correctly estimated with "w_nrwidth_line_count" when setting 'stc'
    command([[set stc=%{!&nu&&!&rnu?'':&rnu?v:relnum?v:relnum:&nu?v:lnum:'0':v:lnum}]])
    screen:expect_unchanged()
    -- zero width when disabling 'number'
    command('set norelativenumber nonumber')
    screen:expect([[
      aaaaa                                                |
      ^aaaaa                                                |
      aaaaa                                                |*3
                                                           |
    ]])
    -- width correctly estimated with "w_nrwidth_line_count" when setting 'nu'
    command('set number')
    screen:expect([[
      {8:7  }aaaaa                                             |
      {8:8  }^aaaaa                                             |
      {8:9  }aaaaa                                             |
      {8:10 }aaaaa                                             |
      {8:11 }aaaaa                                             |
                                                           |
    ]])
  end)

  it('has correct width with custom sign column when (un)placing signs', function()
    screen:try_resize(screen._width, 3)
    exec_lua([[
      vim.cmd.norm('gg')
      vim.o.signcolumn = 'no'
      vim.fn.sign_define('sign', { text = 'ss' })
      _G.StatusCol = function()
        local s = vim.fn.sign_getplaced(1)[1].signs
        local es = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {type = "sign"})
        local sign = ''
        local signs = #s + #es
        if signs > 0 then
          sign = (vim.v.lnum == 2 and 'ss' or '  '):rep(signs)
        end
        return vim.v.lnum .. '%=' .. sign
      end
      vim.o.number = true
      vim.o.numberwidth = 2
      vim.o.statuscolumn = "%!v:lua.StatusCol()"
    ]])
    command('sign place 1 line=2 name=sign')
    screen:expect([[
      {8:1   }^aaaaa                                            |
      {8:2 ss}aaaaa                                            |
                                                           |
    ]])
    command('sign place 2 line=2 name=sign')
    screen:expect([[
      {8:1     }^aaaaa                                          |
      {8:2 ssss}aaaaa                                          |
                                                           |
    ]])
    command('sign unplace 2')
    screen:expect([[
      {8:1   }^aaaaa                                            |
      {8:2 ss}aaaaa                                            |
                                                           |
    ]])
    command('sign unplace 1')
    screen:expect([[
      {8:1 }^aaaaa                                              |
      {8:2 }aaaaa                                              |
                                                           |
    ]])
    -- Also for extmark signs
    exec_lua('id1 = vim.api.nvim_buf_set_extmark(0, ns, 1, 0, {sign_text = "ss"})')
    screen:expect([[
      {8:1   }^aaaaa                                            |
      {8:2 ss}aaaaa                                            |
                                                           |
    ]])
    exec_lua('id2 = vim.api.nvim_buf_set_extmark(0, ns, 1, 0, {sign_text = "ss"})')
    screen:expect([[
      {8:1     }^aaaaa                                          |
      {8:2 ssss}aaaaa                                          |
                                                           |
    ]])
    exec_lua('vim.api.nvim_buf_del_extmark(0, ns, id1)')
    screen:expect([[
      {8:1   }^aaaaa                                            |
      {8:2 ss}aaaaa                                            |
                                                           |
    ]])
    exec_lua('vim.api.nvim_buf_del_extmark(0, ns, id2)')
    screen:expect([[
      {8:1 }^aaaaa                                              |
      {8:2 }aaaaa                                              |
                                                           |
    ]])
    -- In all windows
    command('wincmd v | set ls=0')
    command('sign place 1 line=2 name=sign')
    screen:expect([[
      {8:1   }^aaaaa                 │{8:1   }aaaaa                 |
      {8:2 ss}aaaaa                 │{8:2 ss}aaaaa                 |
                                                           |
    ]])
  end)

  it('is only evaluated twice, once to estimate and once to draw', function()
    command([[
      let g:stcnr = 0
      func! Stc()
        let g:stcnr += 1
        return '12345'
      endfunc
      set stc=%!Stc()
      norm ggdG
    ]])
    eq(2, eval('g:stcnr'))
  end)

  it('does not wrap multibyte characters at the end of a line', function()
    screen:try_resize(33, 4)
    command([[set spell stc=%l\ ]])
    command('call setline(8, "This is a line that contains ᶏ multibyte character.")')
    screen:expect([[
      {8: 8 }^This is a line that contains {104:ᶏ}|
      {8:   } {104:multibyte} character.         |
      {8: 9 }{104:aaaaa}                         |
                                       |
    ]])
  end)

  it('line increase properly redraws buffer text with relativenumber #27709', function()
    screen:try_resize(33, 4)
    command([[set rnu nuw=3 stc=%{v:lnum}\  ]])
    command('call setline(1, range(1, 99))')
    feed('Gyyp')
    screen:expect([[
      {8:98  }98                           |
      {8:99  }99                           |
      {8:100 }^99                           |
                                       |
    ]])
  end)

  it('forces a rebuild with nvim__redraw', function()
    screen:try_resize(40, 4)
    -- Current window
    command([[
      let g:insert = v:false
      set nonu stc=%{g:insert?'insert':''}
      vsplit
      au InsertEnter * let g:insert = v:true | call nvim__redraw(#{statuscolumn:1, win:0})
      au InsertLeave * let g:insert = v:false | call nvim__redraw(#{statuscolumn:1, win:0})
    ]])
    feed('i')
    screen:expect([[
      {8:insert}^aaaaa         │aaaaa              |
      {8:insert}aaaaa         │aaaaa              |
      {3:[No Name] [+]        }{2:[No Name] [+]      }|
      {5:-- INSERT --}                            |
    ]])
    feed('<esc>')
    screen:expect([[
      ^aaaaa               │aaaaa              |
      aaaaa               │aaaaa              |
      {3:[No Name] [+]        }{2:[No Name] [+]      }|
                                              |
    ]])
    -- All windows
    command([[
      au! InsertEnter * let g:insert = v:true | call nvim__redraw(#{statuscolumn:1})
      au! InsertLeave * let g:insert = v:false | call nvim__redraw(#{statuscolumn:1})
    ]])
    feed('i')
    screen:expect([[
      {8:insert}^aaaaa         │{8:insert}aaaaa        |
      {8:insert}aaaaa         │{8:insert}aaaaa        |
      {3:[No Name] [+]        }{2:[No Name] [+]      }|
      {5:-- INSERT --}                            |
    ]])
    feed('<esc>')
    screen:expect([[
      ^aaaaa               │aaaaa              |
      aaaaa               │aaaaa              |
      {3:[No Name] [+]        }{2:[No Name] [+]      }|
                                              |
    ]])
  end)

  it('applies numhl highlight to virtual lines', function()
    exec_lua([[
      vim.o.statuscolumn = '%=%{%v:virtnum==0?"%l":v:virtnum>0?"↳":"•"%}│'
      vim.o.cursorline = true
      vim.api.nvim_set_hl(0, 'CursorLineNr', { underline = true })

      vim.api.nvim_buf_set_extmark(0, ns, 0, 0, { number_hl_group = 'DiagnosticError' })

      local opts_1 = { number_hl_group = 'DiagnosticWarn', virt_lines = { { { 'Hello' } }, { { 'Hello' } } }, virt_lines_above = true }
      vim.api.nvim_buf_set_extmark(0, ns, 1, 0, opts_1)
      opts_1.virt_lines_above = nil
      vim.api.nvim_buf_set_extmark(0, ns, 1, 0, opts_1)

      local opts_2 = { number_hl_group = 'DiagnosticInfo', virt_lines = { { { 'World' } }, { { 'World' } } }, virt_lines_above = true }
      vim.api.nvim_buf_set_extmark(0, ns, 2, 0, opts_2)
      opts_2.virt_lines_above = nil
      vim.api.nvim_buf_set_extmark(0, ns, 2, 0, opts_2)
      vim.cmd.norm('gg')
    ]])
    screen:expect([[
      {105: 1│}{21:^aaaaa                                             }|
      {106: •│}Hello                                             |*2
      {106: 2│}aaaaa                                             |
      {106: •│}Hello                                             |*2
      {107: •│}World                                             |*2
      {107: 3│}aaaaa                                             |
      {107: •│}World                                             |*2
      {8: 4│}aaaaa                                             |
      {8: 5│}aaaaa                                             |
                                                           |
    ]])
  end)
end)
