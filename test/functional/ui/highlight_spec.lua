local t = require('test.functional.testutil')(after_each)
local Screen = require('test.functional.ui.screen')
local os = require('os')
local clear, feed, insert = t.clear, t.feed, t.insert
local command, exec = t.command, t.exec
local eval = t.eval
local feed_command, eq = t.feed_command, t.eq
local fn = t.fn
local api = t.api
local exec_lua = t.exec_lua

describe('colorscheme compatibility', function()
  before_each(function()
    clear()
  end)

  it('&t_Co exists and is set to 256 by default', function()
    eq(1, fn.exists('&t_Co'))
    eq(1, fn.exists('+t_Co'))
    eq('256', eval('&t_Co'))
  end)
end)

describe('highlight: `:syntax manual`', function()
  -- When using manual syntax highlighting, it should be preserved even when
  -- switching buffers... bug did only occur without :set hidden
  -- Ref: vim patch 7.4.1236
  local screen

  before_each(function()
    clear()
    screen = Screen.new(20, 5)
    screen:attach()
    -- syntax highlight for vimscript's "echo"
  end)

  after_each(function()
    os.remove('Xtest-functional-ui-highlight.tmp.vim')
  end)

  it("works with buffer switch and 'hidden'", function()
    command('e tmp1.vim')
    command('e Xtest-functional-ui-highlight.tmp.vim')
    command('filetype on')
    command('syntax manual')
    command('set ft=vim')
    command('set syntax=ON')
    feed('iecho 1<esc>0')

    command('set hidden')
    command('w')
    command('bn')
    feed_command('bp')
    screen:expect([[
      {15:^echo} {26:1}              |
      {1:~                   }|*3
      :bp                 |
    ]])
  end)

  it("works with buffer switch and 'nohidden'", function()
    command('e tmp1.vim')
    command('e Xtest-functional-ui-highlight.tmp.vim')
    command('filetype on')
    command('syntax manual')
    command('set filetype=vim fileformat=unix')
    command('set syntax=ON')
    feed('iecho 1<esc>0')

    command('set nohidden')
    command('w')
    command('silent bn')
    eq('tmp1.vim', eval("fnamemodify(bufname('%'), ':t')"))
    feed_command('silent bp')
    eq('Xtest-functional-ui-highlight.tmp.vim', eval("fnamemodify(bufname('%'), ':t')"))
    screen:expect([[
      {15:^echo} {26:1}              |
      {1:~                   }|*3
      :silent bp          |
    ]])
  end)
end)

describe('highlight defaults', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new()
    screen:add_extra_attr_ids {
      [100] = { foreground = Screen.colors.Red, background = Screen.colors.WebGreen },
      [101] = { italic = true },
    }
    screen:attach()
  end)

  it('window status bar', function()
    feed_command('sp', 'vsp', 'vsp')
    screen:expect([[
      ^                    │                │               |
      {1:~                   }│{1:~               }│{1:~              }|*5
      {3:[No Name]            }{2:[No Name]        [No Name]      }|
                                                           |
      {1:~                                                    }|*4
      {2:[No Name]                                            }|
      :vsp                                                 |
    ]])
    -- navigate to verify that the attributes are properly moved
    feed('<c-w>j')
    screen:expect([[
                          │                │               |
      {1:~                   }│{1:~               }│{1:~              }|*5
      {2:[No Name]            [No Name]        [No Name]      }|
      ^                                                     |
      {1:~                                                    }|*4
      {3:[No Name]                                            }|
      :vsp                                                 |
    ]])
    -- note that when moving to a window with small width nvim will increase
    -- the width of the new active window at the expense of a inactive window
    -- (upstream vim has the same behavior)
    feed('<c-w>k<c-w>l')
    screen:expect([[
                          │^                    │           |
      {1:~                   }│{1:~                   }│{1:~          }|*5
      {2:[No Name]            }{3:[No Name]            }{2:[No Name]  }|
                                                           |
      {1:~                                                    }|*4
      {2:[No Name]                                            }|
      :vsp                                                 |
    ]])
    feed('<c-w>l')
    screen:expect([[
                          │           │^                    |
      {1:~                   }│{1:~          }│{1:~                   }|*5
      {2:[No Name]            [No Name]   }{3:[No Name]           }|
                                                           |
      {1:~                                                    }|*4
      {2:[No Name]                                            }|
      :vsp                                                 |
    ]])
    feed('<c-w>h<c-w>h')
    screen:expect([[
      ^                    │                    │           |
      {1:~                   }│{1:~                   }│{1:~          }|*5
      {3:[No Name]            }{2:[No Name]            [No Name]  }|
                                                           |
      {1:~                                                    }|*4
      {2:[No Name]                                            }|
      :vsp                                                 |
    ]])
  end)

  it('insert mode text', function()
    feed('i')
    screen:try_resize(53, 4)
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*2
      {5:-- INSERT --}                                         |
    ]])
  end)

  it('end of file markers', function()
    screen:try_resize(53, 4)
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*2
                                                           |
    ]])
  end)

  it('"wait return" text', function()
    screen:try_resize(53, 4)
    feed(':ls<cr>')
    screen:expect([[
      {3:                                                     }|
      :ls                                                  |
        1 %a   "[No Name]"                    line 1       |
      {6:Press ENTER or type command to continue}^              |
    ]])
    feed('<cr>') --  skip the "Press ENTER..." state or tests will hang
  end)

  it('can be cleared and linked to other highlight groups', function()
    screen:try_resize(53, 4)
    feed_command('highlight clear ModeMsg')
    feed('i')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*2
      -- INSERT --                                         |
    ]])
    feed('<esc>')
    feed_command('highlight CustomHLGroup guifg=red guibg=green')
    feed_command('highlight link ModeMsg CustomHLGroup')
    feed('i')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*2
      {100:-- INSERT --}                                         |
    ]])
  end)

  it('can be cleared by assigning NONE', function()
    screen:try_resize(53, 4)
    feed_command('syn keyword TmpKeyword neovim')
    feed_command('hi link TmpKeyword ErrorMsg')
    insert('neovim')
    screen:expect([[
      {9:neovi^m}                                               |
      {1:~                                                    }|*2
                                                           |
    ]])
    feed_command(
      'hi ErrorMsg term=NONE cterm=NONE ctermfg=NONE ctermbg=NONE'
        .. ' gui=NONE guifg=NONE guibg=NONE guisp=NONE'
    )
    screen:expect([[
      neovi^m                                               |
      {1:~                                                    }|*2
                                                           |
    ]])
  end)

  it('linking updates window highlight immediately #16552', function()
    screen:try_resize(53, 4)
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*2
                                                           |
    ]])
    feed_command('hi NonTextAlt guifg=Red')
    feed_command('hi! link NonText NonTextAlt')
    screen:expect([[
      ^                                                     |
      {19:~                                                    }|*2
      :hi! link NonText NonTextAlt                         |
    ]])
  end)

  it('Cursor after `:hi clear|syntax reset` #6508', function()
    command('highlight clear|syntax reset')
    eq('guifg=bg guibg=fg', eval([[matchstr(execute('hi Cursor'), '\v(gui|cterm).*$')]]))
  end)

  it('Whitespace highlight', function()
    screen:try_resize(53, 4)
    feed_command('highlight NonText gui=NONE guifg=#FF0000')
    feed_command('set listchars=space:.,tab:>-,trail:*,eol:¬ list')
    insert('   ne \t o\tv  im  ')
    screen:expect([[
      ne{19:.>----.}o{19:>-----}v{19:..}im{19:*^*¬}                             |
      {19:~                                                    }|*2
                                                           |
    ]])
    feed_command('highlight Whitespace gui=NONE guifg=#0000FF')
    screen:expect([[
      ne{18:.>----.}o{18:>-----}v{18:..}im{18:*^*}{19:¬}                             |
      {19:~                                                    }|*2
      :highlight Whitespace gui=NONE guifg=#0000FF         |
    ]])
  end)

  it('are sent to UIs', function()
    screen:try_resize(53, 4)

    screen:expect {
      grid = [[
      ^                                                     |
      {1:~                                                    }|*2
                                                           |
    ]],
      hl_groups = { EndOfBuffer = 1, MsgSeparator = 3 },
    }

    command('highlight EndOfBuffer gui=italic')
    screen:expect {
      grid = [[
      ^                                                     |
      {101:~                                                    }|*2
                                                           |
    ]],
      hl_groups = { EndOfBuffer = 101, MsgSeparator = 3 },
    }

    command('highlight clear EndOfBuffer')
    screen:expect {
      grid = [[
      ^                                                     |
      {1:~                                                    }|*2
                                                           |
    ]],
      hl_groups = { EndOfBuffer = 1, MsgSeparator = 3 },
    }
  end)
end)

describe('highlight', function()
  before_each(clear)

  it('Visual', function()
    local screen = Screen.new(45, 5)
    screen:attach()
    insert([[
      line1 foo bar
    abcdefghijklmnopqrs
    ABCDEFGHIJKLMNOPQRS
    ]])
    feed('gg')
    command('vsplit')

    -- Non-blinking block cursor: does NOT highlight char-at-cursor.
    command('set guicursor=a:block-blinkon0')
    feed('V')
    screen:expect([[
      {17:  }^l{17:ine1 foo bar}       │{17:  line1 foo bar}       |
      abcdefghijklmnopqrs   │abcdefghijklmnopqrs   |
      ABCDEFGHIJKLMNOPQRS   │ABCDEFGHIJKLMNOPQRS   |
      {3:[No Name] [+]          }{2:[No Name] [+]         }|
      {5:-- VISUAL LINE --}                            |
    ]])

    feed('<Esc>$vhhh')
    screen:expect([[
        line1 foo^ {17:bar}       │  line1 foo{17: bar}       |
      abcdefghijklmnopqrs   │abcdefghijklmnopqrs   |
      ABCDEFGHIJKLMNOPQRS   │ABCDEFGHIJKLMNOPQRS   |
      {3:[No Name] [+]          }{2:[No Name] [+]         }|
      {5:-- VISUAL --}                                 |
    ]])

    -- Vertical cursor: highlights char-at-cursor. #8983
    command('set guicursor=a:block-blinkon175')
    screen:expect([[
        line1 foo{17:^ bar}       │  line1 foo{17: bar}       |
      abcdefghijklmnopqrs   │abcdefghijklmnopqrs   |
      ABCDEFGHIJKLMNOPQRS   │ABCDEFGHIJKLMNOPQRS   |
      {3:[No Name] [+]          }{2:[No Name] [+]         }|
      {5:-- VISUAL --}                                 |
    ]])

    command('set selection=exclusive')
    screen:expect([[
        line1 foo{17:^ ba}r       │  line1 foo{17: ba}r       |
      abcdefghijklmnopqrs   │abcdefghijklmnopqrs   |
      ABCDEFGHIJKLMNOPQRS   │ABCDEFGHIJKLMNOPQRS   |
      {3:[No Name] [+]          }{2:[No Name] [+]         }|
      {5:-- VISUAL --}                                 |
    ]])

    feed('o')
    screen:expect([[
        line1 foo{17: ba}^r       │  line1 foo{17: ba}r       |
      abcdefghijklmnopqrs   │abcdefghijklmnopqrs   |
      ABCDEFGHIJKLMNOPQRS   │ABCDEFGHIJKLMNOPQRS   |
      {3:[No Name] [+]          }{2:[No Name] [+]         }|
      {5:-- VISUAL --}                                 |
    ]])

    feed('V')
    screen:expect([[
      {17:  line1 foo ba^r}       │{17:  line1 foo bar}       |
      abcdefghijklmnopqrs   │abcdefghijklmnopqrs   |
      ABCDEFGHIJKLMNOPQRS   │ABCDEFGHIJKLMNOPQRS   |
      {3:[No Name] [+]          }{2:[No Name] [+]         }|
      {5:-- VISUAL LINE --}                            |
    ]])

    command('set cursorcolumn')
    feed('<C-V>')
    screen:expect([[
        line1 foo{17: ba}^r       │  line1 foo{17: ba}r       |
      abcdefghijklmn{21:o}pqrs   │abcdefghijklmnopqrs   |
      ABCDEFGHIJKLMN{21:O}PQRS   │ABCDEFGHIJKLMNOPQRS   |
      {3:[No Name] [+]          }{2:[No Name] [+]         }|
      {5:-- VISUAL BLOCK --}                           |
    ]])

    command('set selection&')
    screen:expect([[
        line1 foo{17: ba^r}       │  line1 foo{17: bar}       |
      abcdefghijklmn{21:o}pqrs   │abcdefghijklmnopqrs   |
      ABCDEFGHIJKLMN{21:O}PQRS   │ABCDEFGHIJKLMNOPQRS   |
      {3:[No Name] [+]          }{2:[No Name] [+]         }|
      {5:-- VISUAL BLOCK --}                           |
    ]])

    feed('^')
    screen:expect([[
        {17:^line1 foo }bar       │  {17:line1 foo }bar       |
      ab{21:c}defghijklmnopqrs   │abcdefghijklmnopqrs   |
      AB{21:C}DEFGHIJKLMNOPQRS   │ABCDEFGHIJKLMNOPQRS   |
      {3:[No Name] [+]          }{2:[No Name] [+]         }|
      {5:-- VISUAL BLOCK --}                           |
    ]])

    feed('2j')
    screen:expect([[
        {17:line1 foo }bar       │  {17:line1 foo }bar       |
      ab{17:cdefghijkl}mnopqrs   │ab{17:cdefghijkl}mnopqrs   |
      AB{17:^CDEFGHIJKL}MNOPQRS   │AB{17:CDEFGHIJKL}MNOPQRS   |
      {3:[No Name] [+]          }{2:[No Name] [+]         }|
      {5:-- VISUAL BLOCK --}                           |
    ]])

    command('set nocursorcolumn')
    feed('O')
    screen:expect([[
        {17:line1 foo }bar       │  {17:line1 foo }bar       |
      ab{17:cdefghijkl}mnopqrs   │ab{17:cdefghijkl}mnopqrs   |
      AB{17:CDEFGHIJK^L}MNOPQRS   │AB{17:CDEFGHIJKL}MNOPQRS   |
      {3:[No Name] [+]          }{2:[No Name] [+]         }|
      {5:-- VISUAL BLOCK --}                           |
    ]])

    command('set selection=exclusive')
    screen:expect([[
        {17:line1 foo} bar       │  {17:line1 foo} bar       |
      ab{17:cdefghijk}lmnopqrs   │ab{17:cdefghijk}lmnopqrs   |
      AB{17:CDEFGHIJK}^LMNOPQRS   │AB{17:CDEFGHIJK}LMNOPQRS   |
      {3:[No Name] [+]          }{2:[No Name] [+]         }|
      {5:-- VISUAL BLOCK --}                           |
    ]])
  end)

  it('cterm=standout gui=standout', function()
    local screen = Screen.new(20, 5)
    screen:attach()
    screen:add_extra_attr_ids {
      [100] = {
        foreground = Screen.colors.Blue1,
        bold = true,
        background = Screen.colors.Grey90,
        underline = true,
        standout = true,
      },
      [101] = { underline = true, standout = true, background = Screen.colors.Grey90 },
    }
    feed_command('hi CursorLine cterm=standout,underline gui=standout,underline')
    feed_command('set cursorline')
    feed_command('set listchars=space:.,eol:¬,tab:>-,extends:>,precedes:<,trail:* list')
    feed('i\t abcd <cr>\t abcd <cr><esc>k')
    screen:expect([[
    {1:>-------.}abcd{1:*¬}     |
    {100:^>-------.}{101:abcd}{100:*¬}{101:     }|
    {1:¬}                   |
    {1:~                   }|
                        |
    ]])
  end)

  it('strikethrough', function()
    local screen = Screen.new(25, 6)
    screen:attach()
    feed_command('syntax on')
    feed_command('syn keyword TmpKeyword foo')
    feed_command('hi! Awesome cterm=strikethrough gui=strikethrough')
    feed_command('hi link TmpKeyword Awesome')
    insert([[
      foo
      foo bar
      foobarfoobar
      ]])
    screen:expect(
      [[
      {1:foo}                      |
      {1:foo} bar                  |
      foobarfoobar             |
      ^                         |
      {2:~                        }|
                               |
    ]],
      {
        [1] = { strikethrough = true },
        [2] = { bold = true, foreground = Screen.colors.Blue1 },
      }
    )
  end)

  it('nocombine', function()
    local screen = Screen.new(25, 6)
    screen:add_extra_attr_ids {
      [100] = { underline = true, reverse = true, foreground = Screen.colors.SlateBlue },
      [101] = {
        foreground = Screen.colors.SlateBlue,
        reverse = true,
        background = Screen.colors.Yellow,
      },
    }
    screen:attach()
    feed_command('syntax on')
    feed_command('hi! Underlined cterm=underline gui=underline')
    feed_command('syn keyword Underlined foobar')
    feed_command('hi Search cterm=inverse,nocombine gui=inverse,nocombine')
    insert([[
      foobar
      foobar
      ]])
    screen:expect {
      grid = [[
      {28:foobar}                   |*2
      ^                         |
      {1:~                        }|*2
                               |
    ]],
    }

    feed('/foo')
    screen:expect {
      grid = [[
      {100:foo}{28:bar}                   |
      {101:foo}{28:bar}                   |
                               |
      {1:~                        }|*2
      /foo^                     |
    ]],
    }
    feed('<cr>')
    screen:expect {
      grid = [[
      {101:^foo}{28:bar}                   |
      {101:foo}{28:bar}                   |
                               |
      {1:~                        }|*2
      {19:search hit...uing at TOP} |
    ]],
    }
  end)

  it('guisp (special/undercurl)', function()
    local screen = Screen.new(25, 10)
    screen:attach()
    feed_command('syntax on')
    feed_command('syn keyword TmpKeyword neovim')
    feed_command('syn keyword TmpKeyword1 special')
    feed_command('syn keyword TmpKeyword2 specialwithbg')
    feed_command('syn keyword TmpKeyword3 specialwithfg')
    feed_command('hi! Awesome guifg=red guibg=yellow guisp=red')
    feed_command('hi! Awesome1 guisp=red')
    feed_command('hi! Awesome2 guibg=yellow guisp=red')
    feed_command('hi! Awesome3 guifg=red guisp=red')
    feed_command('hi link TmpKeyword Awesome')
    feed_command('hi link TmpKeyword1 Awesome1')
    feed_command('hi link TmpKeyword2 Awesome2')
    feed_command('hi link TmpKeyword3 Awesome3')
    insert([[
      neovim
      awesome neovim
      wordcontainingneovim
      special
      specialwithbg
      specialwithfg
      ]])
    feed('Go<tab>neovim tabbed')
    screen:expect(
      [[
      {1:neovim}                   |
      awesome {1:neovim}           |
      wordcontainingneovim     |
      {2:special}                  |
      {3:specialwithbg}            |
      {4:specialwithfg}            |
                               |
              {1:neovim} tabbed^    |
      {0:~                        }|
      {5:-- INSERT --}             |
    ]],
      {
        [0] = { bold = true, foreground = Screen.colors.Blue },
        [1] = {
          background = Screen.colors.Yellow,
          foreground = Screen.colors.Red,
          special = Screen.colors.Red,
        },
        [2] = { special = Screen.colors.Red },
        [3] = { special = Screen.colors.Red, background = Screen.colors.Yellow },
        [4] = { foreground = Screen.colors.Red, special = Screen.colors.Red },
        [5] = { bold = true },
      }
    )
  end)

  it("'diff', syntax and extmark #23722", function()
    local screen = Screen.new(25, 10)
    screen:attach()
    exec([[
      new
      call setline(1, ['', '01234 6789'])
      windo diffthis
      wincmd w
      syn match WarningMsg "^.*$"
      call nvim_buf_add_highlight(0, -1, 'ErrorMsg', 1, 2, 8)
    ]])
    screen:expect(
      [[
      {1:  }^                       |
      {1:  }{2:01}{3:234 67}{2:89}{5:             }|
      {4:~                        }|*2
      {7:[No Name] [+]            }|
      {1:  }                       |
      {1:  }{6:-----------------------}|
      {4:~                        }|
      {8:[No Name]                }|
                               |
    ]],
      {
        [0] = { Screen.colors.WebGray, foreground = Screen.colors.DarkBlue },
        [1] = { background = Screen.colors.Grey, foreground = Screen.colors.Blue4 },
        [2] = { foreground = Screen.colors.Red, background = Screen.colors.LightBlue },
        [3] = { foreground = Screen.colors.Grey100, background = Screen.colors.LightBlue },
        [4] = { bold = true, foreground = Screen.colors.Blue },
        [5] = { background = Screen.colors.LightBlue },
        [6] = {
          bold = true,
          background = Screen.colors.LightCyan,
          foreground = Screen.colors.Blue1,
        },
        [7] = { reverse = true, bold = true },
        [8] = { reverse = true },
      }
    )
  end)
end)

describe("'listchars' highlight", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(20, 5)
    screen:attach()
  end)

  it("'cursorline' and 'cursorcolumn'", function()
    feed_command('highlight clear ModeMsg')
    feed_command('set cursorline')
    feed('i')
    screen:expect([[
      {21:^                    }|
      {1:~                   }|*3
      -- INSERT --        |
    ]])
    feed('abcdefg<cr>kkasdf')
    screen:expect([[
      abcdefg             |
      {21:kkasdf^              }|
      {1:~                   }|*2
      -- INSERT --        |
    ]])
    feed('<esc>')
    screen:expect([[
      abcdefg             |
      {21:kkasd^f              }|
      {1:~                   }|*2
                          |
    ]])
    feed_command('set nocursorline')
    screen:expect([[
      abcdefg             |
      kkasd^f              |
      {1:~                   }|*2
      :set nocursorline   |
    ]])
    feed('k')
    screen:expect([[
      abcde^fg             |
      kkasdf              |
      {1:~                   }|*2
      :set nocursorline   |
    ]])
    feed('jjji<cr><cr><cr><esc>')
    screen:expect([[
      kkasd               |
                          |*2
      ^f                   |
                          |
    ]])
    feed_command('set cursorline')
    feed_command('set cursorcolumn')
    feed('kkiabcdefghijk<esc>hh')
    screen:expect([[
      kkasd   {21: }           |
      {21:abcdefgh^ijk         }|
              {21: }           |
      f       {21: }           |
                          |
    ]])
    feed('khh')
    screen:expect([[
      {21:kk^asd               }|
      ab{21:c}defghijk         |
        {21: }                 |
      f {21: }                 |
                          |
    ]])
  end)

  it("'cursorline' and with 'listchars' option", function()
    screen:add_extra_attr_ids {
      [100] = { foreground = Screen.colors.Red, background = Screen.colors.Grey90 },
      [101] = { foreground = Screen.colors.Blue1, bold = true, background = Screen.colors.Grey90 },
    }
    feed_command('highlight clear ModeMsg')
    feed_command('highlight Whitespace guifg=#FF0000')
    feed_command('set cursorline')
    feed_command('set tabstop=8')
    feed_command('set listchars=space:.,eol:¬,tab:>-,extends:>,precedes:<,trail:* list')
    feed('i\t abcd <cr>\t abcd <cr><esc>k')
    screen:expect([[
      {19:>-------.}abcd{19:*}{1:¬}     |
      {100:^>-------.}{21:abcd}{100:*}{101:¬}{21:     }|
      {1:¬}                   |
      {1:~                   }|
                          |
    ]])
    feed('k')
    screen:expect([[
      {100:^>-------.}{21:abcd}{100:*}{101:¬}{21:     }|
      {19:>-------.}abcd{19:*}{1:¬}     |
      {1:¬}                   |
      {1:~                   }|
                          |
    ]])
    feed_command('set nocursorline')
    screen:expect([[
      {19:^>-------.}abcd{19:*}{1:¬}     |
      {19:>-------.}abcd{19:*}{1:¬}     |
      {1:¬}                   |
      {1:~                   }|
      :set nocursorline   |
    ]])
    feed_command('set nowrap')
    feed('ALorem ipsum dolor sit amet<ESC>0')
    screen:expect([[
      {19:^>-------.}abcd{19:.}Lorem{1:>}|
      {19:>-------.}abcd{19:*}{1:¬}     |
      {1:¬}                   |
      {1:~                   }|
                          |
    ]])
    feed_command('set cursorline')
    screen:expect([[
      {100:^>-------.}{21:abcd}{100:.}{21:Lorem}{101:>}|
      {19:>-------.}abcd{19:*}{1:¬}     |
      {1:¬}                   |
      {1:~                   }|
      :set cursorline     |
    ]])
    feed('$')
    screen:expect([[
      {101:<}{21:r}{100:.}{21:sit}{100:.}{21:ame^t}{101:¬}{21:        }|
      {1:<}                   |*2
      {1:~                   }|
      :set cursorline     |
    ]])
    feed('G')
    screen:expect([[
      {19:>-------.}abcd{19:.}Lorem{1:>}|
      {19:>-------.}abcd{19:*}{1:¬}     |
      {101:^¬}{21:                   }|
      {1:~                   }|
      :set cursorline     |
    ]])
  end)

  it("'listchar' with wrap", function()
    feed_command('set wrap')
    feed_command('set listchars=eol:¬,precedes:< list')
    feed('90ia<esc>')
    screen:expect([[
      {1:<}aaaaaaaaaaaaaaaaaaa|
      aaaaaaaaaaaaaaaaaaaa|*2
      aaaaaaaaa^a{1:¬}         |
                          |
    ]])
    feed('0')
    screen:expect([[
      ^aaaaaaaaaaaaaaaaaaaa|
      aaaaaaaaaaaaaaaaaaaa|*3
                          |
    ]])
  end)

  it("'listchar' in visual mode", function()
    screen:add_extra_attr_ids {
      [100] = {
        foreground = Screen.colors.Blue1,
        bold = true,
        background = Screen.colors.LightGray,
      },
      [101] = { foreground = Screen.colors.Red, background = Screen.colors.Grey90 },
      [102] = { foreground = Screen.colors.Blue1, bold = true, background = Screen.colors.Grey90 },
      [103] = { foreground = Screen.colors.Red, background = Screen.colors.LightGray },
    }
    command('highlight clear ModeMsg')
    command('highlight Whitespace guifg=#FF0000')
    command('set cursorline')
    command('set tabstop=8')
    command('set nowrap')
    command('set listchars=space:.,eol:¬,tab:>-,extends:>,precedes:<,trail:* list')
    feed('i\t abcd <cr>\t abcd Lorem ipsum dolor sit amet<cr><esc>kkk0')
    screen:expect([[
      {101:^>-------.}{21:abcd}{101:*}{102:¬}{21:     }|
      {19:>-------.}abcd{19:.}Lorem{1:>}|
      {1:¬}                   |
      {1:~                   }|
                          |
    ]])
    feed('lllvj')
    screen:expect([[
      {19:>-------.}a{17:bcd}{103:*}{100:¬}     |
      {103:>-------.}{17:a}^bcd{19:.}Lorem{1:>}|
      {1:¬}                   |
      {1:~                   }|
      -- VISUAL --        |
    ]])
    feed('<esc>V')
    screen:expect([[
      {19:>-------.}abcd{19:*}{1:¬}     |
      {103:>-------.}{17:a}^b{17:cd}{103:.}{17:Lorem}{1:>}|
      {1:¬}                   |
      {1:~                   }|
      -- VISUAL LINE --   |
    ]])
    feed('<esc>$')
    screen:expect([[
      {1:<}                   |
      {102:<}{21:r}{101:.}{21:sit}{101:.}{21:ame^t}{102:¬}{21:        }|
      {1:<}                   |
      {1:~                   }|
                          |
    ]])
  end)

  it("'cursorline' with :match", function()
    screen:add_extra_attr_ids {
      [100] = { foreground = Screen.colors.Lime, background = Screen.colors.Red },
    }
    feed_command('highlight clear ModeMsg')
    feed_command('highlight Whitespace guifg=#FF0000')
    feed_command('highlight Error guifg=#00FF00')
    feed_command('set nowrap')
    feed('ia \t bc \t  <esc>')
    screen:expect([[
      a        bc      ^   |
      {1:~                   }|*3
                          |
    ]])
    feed_command('set listchars=space:.,eol:¬,tab:>-,extends:>,precedes:<,trail:* list')
    screen:expect([[
      a{19:.>-----.}bc{19:*>---*^*}{1:¬} |
      {1:~                   }|*3
                          |
    ]])
    feed_command('match Error /\\s\\+$/')
    screen:expect([[
      a{19:.>-----.}bc{100:*>---*^*}{1:¬} |
      {1:~                   }|*3
                          |
    ]])
  end)
end)

describe('CursorLine and CursorLineNr highlights', function()
  before_each(clear)

  it('overridden by Error, ColorColumn if fg not set', function()
    local screen = Screen.new(50, 5)
    screen:add_extra_attr_ids {
      [100] = { background = Screen.colors.LightRed },
      [101] = { foreground = Screen.colors.SlateBlue, background = Screen.colors.Grey90 },
    }
    screen:attach()

    command('filetype on')
    command('syntax on')
    command('set cursorline ft=json')
    feed('i{<cr>"a" : abc // 10;<cr>}<cr><esc>')
    screen:expect([[
      {16:{}                                                 |
      "{15:a}" : {9:abc} {9:// 10;}                                  |
      {16:}}                                                 |
      {21:^                                                  }|
                                                        |
    ]])

    command('set colorcolumn=3')
    feed('i  <esc>')
    screen:expect([[
      {16:{} {100: }                                               |
      "{15:a}{100:"} : {9:abc} {9:// 10;}                                  |
      {16:}} {100: }                                               |
      {21: ^ }{100: }{21:                                               }|
                                                        |
    ]])
  end)

  it("overridden by NonText in 'showbreak' characters", function()
    local screen = Screen.new(20, 5)
    screen:add_extra_attr_ids {
      [100] = { foreground = Screen.colors.Yellow1 },
      [101] = { foreground = Screen.colors.Yellow1, background = Screen.colors.Blue },
      [102] = { foreground = Screen.colors.Grey0, background = Screen.colors.Grey100 },
      [103] = { foreground = Screen.colors.Yellow1, background = Screen.colors.Grey100 },
    }
    screen:attach()

    feed_command('set wrap cursorline')
    feed_command('set showbreak=>>>')
    feed_command('highlight clear NonText')
    feed_command('highlight clear CursorLine')
    feed_command('highlight NonText guifg=Yellow guibg=Blue gui=NONE')
    feed_command('highlight CursorLine guifg=Black guibg=White gui=NONE')

    feed('30iø<esc>o<esc>30ia<esc>')
    screen:expect([[
      øøøøøøøøøøøøøøøøøøøø|
      {101:>>>}øøøøøøøøøø       |
      {102:aaaaaaaaaaaaaaaaaaaa}|
      {101:>>>}{102:aaaaaaaaa^a       }|
                          |
    ]])
    feed('k')
    screen:expect([[
      {102:øøøøøøøøøøøøøøøøøøøø}|
      {101:>>>}{102:øøøøøøøøø^ø       }|
      aaaaaaaaaaaaaaaaaaaa|
      {101:>>>}aaaaaaaaaa       |
                          |
    ]])
    feed_command('highlight NonText guibg=NONE')
    screen:expect([[
      {102:øøøøøøøøøøøøøøøøøøøø}|
      {103:>>>}{102:øøøøøøøøø^ø       }|
      aaaaaaaaaaaaaaaaaaaa|
      {100:>>>}aaaaaaaaaa       |
                          |
    ]])
    feed_command('set nocursorline')
    screen:expect([[
      øøøøøøøøøøøøøøøøøøøø|
      {100:>>>}øøøøøøøøø^ø       |
      aaaaaaaaaaaaaaaaaaaa|
      {100:>>>}aaaaaaaaaa       |
      :set nocursorline   |
    ]])
  end)

  it("'cursorlineopt' screenline", function()
    local screen = Screen.new(20, 5)
    screen:add_extra_attr_ids {
      [100] = { foreground = Screen.colors.Yellow },
      [101] = { foreground = Screen.colors.Red, background = Screen.colors.WebGreen },
      [102] = { foreground = Screen.colors.Black, background = Screen.colors.Grey100 },
      [103] = { foreground = Screen.colors.WebGreen, background = Screen.colors.Red },
    }
    screen:attach()

    command('set wrap cursorline cursorlineopt=screenline')
    command('set showbreak=>>>')
    command('highlight clear NonText')
    command('highlight clear CursorLine')
    command('highlight NonText guifg=Yellow gui=NONE')
    command('highlight LineNr guifg=Red guibg=Green gui=NONE')
    command('highlight CursorLine guifg=Black guibg=White gui=NONE')
    command('highlight CursorLineNr guifg=Green guibg=Red gui=NONE')

    feed('30iø<esc>o<esc>30ia<esc>')

    -- CursorLine should not apply to 'showbreak' when 'cursorlineopt' contains "screenline"
    screen:expect([[
      øøøøøøøøøøøøøøøøøøøø|
      {100:>>>}øøøøøøøøøø       |
      aaaaaaaaaaaaaaaaaaaa|
      {100:>>>}{102:aaaaaaaaa^a       }|
                          |
    ]])
    feed('gk')
    screen:expect([[
      øøøøøøøøøøøøøøøøøøøø|
      {100:>>>}øøøøøøøøøø       |
      {102:aaaaaaaaaaaa^aaaaaaaa}|
      {100:>>>}aaaaaaaaaa       |
                          |
    ]])
    feed('k')
    screen:expect([[
      {102:øøøøøøøøøøøø^øøøøøøøø}|
      {100:>>>}øøøøøøøøøø       |
      aaaaaaaaaaaaaaaaaaaa|
      {100:>>>}aaaaaaaaaa       |
                          |
    ]])

    -- CursorLineNr should not apply to line number when 'cursorlineopt' does not contain "number"
    command('set relativenumber numberwidth=2')
    screen:expect([[
      {101:0 }{102:øøøøøøøøøøøø^øøøøøø}|
      {101:  }{100:>>>}øøøøøøøøøøøø   |
      {101:1 }aaaaaaaaaaaaaaaaaa|
      {101:  }{100:>>>}aaaaaaaaaaaa   |
                          |
    ]])

    -- CursorLineNr should apply to line number when 'cursorlineopt' contains "number"
    command('set cursorlineopt+=number')
    screen:expect([[
      {103:0 }{102:øøøøøøøøøøøø^øøøøøø}|
      {101:  }{100:>>>}øøøøøøøøøøøø   |
      {101:1 }aaaaaaaaaaaaaaaaaa|
      {101:  }{100:>>>}aaaaaaaaaaaa   |
                          |
    ]])
    feed('gj')
    screen:expect([[
      {103:0 }øøøøøøøøøøøøøøøøøø|
      {101:  }{100:>>>}{102:øøøøøøøøø^øøø   }|
      {101:1 }aaaaaaaaaaaaaaaaaa|
      {101:  }{100:>>>}aaaaaaaaaaaa   |
                          |
    ]])
    feed('gj')
    screen:expect([[
      {101:1 }øøøøøøøøøøøøøøøøøø|
      {101:  }{100:>>>}øøøøøøøøøøøø   |
      {103:0 }{102:aaaaaaaaaaaa^aaaaaa}|
      {101:  }{100:>>>}aaaaaaaaaaaa   |
                          |
    ]])
    feed('gj')
    screen:expect([[
      {101:1 }øøøøøøøøøøøøøøøøøø|
      {101:  }{100:>>>}øøøøøøøøøøøø   |
      {103:0 }aaaaaaaaaaaaaaaaaa|
      {101:  }{100:>>>}{102:aaaaaaaaa^aaa   }|
                          |
    ]])

    -- updated in Insert mode
    feed('I')
    screen:expect([[
      {101:1 }øøøøøøøøøøøøøøøøøø|
      {101:  }{100:>>>}øøøøøøøøøøøø   |
      {103:0 }{102:^aaaaaaaaaaaaaaaaaa}|
      {101:  }{100:>>>}aaaaaaaaaaaa   |
      {5:-- INSERT --}        |
    ]])

    feed('<Esc>gg')
    screen:expect([[
      {103:0 }{102:^øøøøøøøøøøøøøøøøøø}|
      {101:  }{100:>>>}øøøøøøøøøøøø   |
      {101:1 }aaaaaaaaaaaaaaaaaa|
      {101:  }{100:>>>}aaaaaaaaaaaa   |
                          |
    ]])

    command('inoremap <F2> <Cmd>call cursor(1, 1)<CR>')
    feed('A')
    screen:expect([[
      {103:0 }øøøøøøøøøøøøøøøøøø|
      {101:  }{100:>>>}{102:øøøøøøøøøøøø^   }|
      {101:1 }aaaaaaaaaaaaaaaaaa|
      {101:  }{100:>>>}aaaaaaaaaaaa   |
      {5:-- INSERT --}        |
    ]])

    feed('<F2>')
    screen:expect([[
      {103:0 }{102:^øøøøøøøøøøøøøøøøøø}|
      {101:  }{100:>>>}øøøøøøøøøøøø   |
      {101:1 }aaaaaaaaaaaaaaaaaa|
      {101:  }{100:>>>}aaaaaaaaaaaa   |
      {5:-- INSERT --}        |
    ]])
  end)

  -- oldtest: Test_cursorline_after_yank()
  it('always updated. vim-patch:8.1.0849', function()
    local screen = Screen.new(50, 5)
    screen:add_extra_attr_ids {
      [100] = { background = Screen.colors.LightRed },
      [101] = { foreground = Screen.colors.SlateBlue, background = Screen.colors.Grey90 },
    }
    screen:attach()
    command('set cursorline relativenumber')
    command('call setline(1, ["","1","2","3",""])')
    feed('Gy3k')
    screen:expect([[
      {15:  0 }{21:^1                                             }|
      {8:  1 }2                                             |
      {8:  2 }3                                             |
      {8:  3 }                                              |
      4 lines yanked                                    |
    ]])
    feed('jj')
    screen:expect([[
      {8:  2 }1                                             |
      {8:  1 }2                                             |
      {15:  0 }{21:^3                                             }|
      {8:  1 }                                              |
      4 lines yanked                                    |
    ]])
  end)

  -- oldtest: Test_cursorline_with_visualmode()
  it('with visual area. vim-patch:8.1.1001', function()
    local screen = Screen.new(50, 5)
    screen:add_extra_attr_ids {
      [100] = { foreground = Screen.colors.SlateBlue, background = Screen.colors.Grey90 },
      [101] = { background = Screen.colors.LightRed },
    }
    screen:attach()
    command('set cursorline')
    command('call setline(1, repeat(["abc"], 50))')
    feed('V<C-f>zbkkjk')
    screen:expect([[
      {17:abc}                                               |
      ^a{17:bc}                                               |
      abc                                               |*2
      {5:-- VISUAL LINE --}                                 |
    ]])
  end)

  -- oldtest: Test_cursorline_callback()
  it('is updated if cursor is moved up from timer vim-patch:8.2.4591', function()
    local screen = Screen.new(50, 8)
    screen:attach()
    exec([[
      call setline(1, ['aaaaa', 'bbbbb', 'ccccc', 'ddddd'])
      set cursorline
      call cursor(4, 1)

      func Func(timer)
        call cursor(2, 1)
      endfunc

      call timer_start(300, 'Func')
    ]])
    screen:expect({
      grid = [[
      aaaaa                                             |
      bbbbb                                             |
      ccccc                                             |
      {21:^ddddd                                             }|
      {1:~                                                 }|*3
                                                        |
    ]],
      timeout = 100,
    })
    screen:expect({
      grid = [[
      aaaaa                                             |
      {21:^bbbbb                                             }|
      ccccc                                             |
      ddddd                                             |
      {1:~                                                 }|*3
                                                        |
    ]],
    })
  end)

  it('with split windows in diff mode', function()
    local screen = Screen.new(50, 12)
    screen:add_extra_attr_ids {
      [100] = { background = Screen.colors.Plum1, underline = true },
      [101] = { background = Screen.colors.Red1, bold = true, underline = true },
    }
    screen:attach()

    command('hi CursorLine ctermbg=red ctermfg=white guibg=red guifg=white')
    command('set cursorline')
    feed('iline 1 some text<cr>line 2 more text<cr>extra line!<cr>extra line!<cr>last line ...<cr>')
    feed('<esc>gg')
    command('vsplit')
    command('enew')
    feed(
      'iline 1 some text<cr>line 2 moRe text!<cr>extra line!<cr>extra line!<cr>extra line!<cr>last line ...<cr>'
    )
    feed('<esc>gg')
    command('windo diffthis')
    screen:expect([[
      {7:  }{9:line 1 some text       }│{7:  }{9:^line 1 some text      }|
      {7:  }{4:line 2 mo}{27:Re text!}{4:      }│{7:  }{4:line 2 mo}{27:re text}{4:      }|
      {7:  }{22:extra line!            }│{7:  }{23:----------------------}|
      {7:  }extra line!            │{7:  }extra line!           |*2
      {7:  }last line ...          │{7:  }last line ...         |
      {7:  }                       │{7:  }                      |
      {1:~                        }│{1:~                       }|*3
      {2:[No Name] [+]             }{3:[No Name] [+]           }|
                                                        |
    ]])
    feed('jjjjj')
    screen:expect([[
      {7:  }line 1 some text       │{7:  }line 1 some text      |
      {7:  }{4:line 2 mo}{27:Re text!}{4:      }│{7:  }{4:line 2 mo}{27:re text}{4:      }|
      {7:  }{22:extra line!            }│{7:  }{23:----------------------}|
      {7:  }extra line!            │{7:  }extra line!           |*2
      {7:  }last line ...          │{7:  }last line ...         |
      {7:  }{9:                       }│{7:  }{9:^                      }|
      {1:~                        }│{1:~                       }|*3
      {2:[No Name] [+]             }{3:[No Name] [+]           }|
                                                        |
    ]])

    -- CursorLine with fg=NONE is "low-priority".
    -- Rendered as underline in a diff-line. #9028
    command('hi CursorLine ctermbg=red ctermfg=NONE guibg=red guifg=NONE')
    feed('kkkk')
    screen:expect([[
      {7:  }line 1 some text       │{7:  }line 1 some text      |
      {7:  }{100:line 2 mo}{101:Re text!}{100:      }│{7:  }{100:^line 2 mo}{101:re text}{100:      }|
      {7:  }{22:extra line!            }│{7:  }{23:----------------------}|
      {7:  }extra line!            │{7:  }extra line!           |*2
      {7:  }last line ...          │{7:  }last line ...         |
      {7:  }                       │{7:  }                      |
      {1:~                        }│{1:~                       }|*3
      {2:[No Name] [+]             }{3:[No Name] [+]           }|
                                                        |
    ]])
  end)

  -- oldtest: Test_diff_with_cursorline_number()
  it('CursorLineNr shows correctly just below filler lines', function()
    local screen = Screen.new(50, 12)
    screen:add_extra_attr_ids {
      [100] = { foreground = Screen.colors.Black, bold = true, background = Screen.colors.Grey100 },
    }
    screen:attach()

    command('hi CursorLine guibg=red guifg=white')
    command('hi CursorLineNr guibg=white guifg=black gui=bold')
    command('set cursorline number')
    command('call setline(1, ["baz", "foo", "foo", "bar"])')
    feed('2gg0')
    command('vnew')
    command('call setline(1, ["foo", "foo", "bar"])')
    command('windo diffthis')
    command('1wincmd w')
    screen:expect([[
      {7:  }{8:    }{23:-------------------}│{7:  }{8:  1 }{22:baz               }|
      {7:  }{100:  1 }{9:^foo                }│{7:  }{100:  2 }{9:foo               }|
      {7:  }{8:  2 }foo                │{7:  }{8:  3 }foo               |
      {7:  }{8:  3 }bar                │{7:  }{8:  4 }bar               |
      {1:~                        }│{1:~                       }|*6
      {3:[No Name] [+]             }{2:[No Name] [+]           }|
                                                        |
    ]])
    command('set cursorlineopt=number')
    screen:expect([[
      {7:  }{8:    }{23:-------------------}│{7:  }{8:  1 }{22:baz               }|
      {7:  }{100:  1 }^foo                │{7:  }{100:  2 }{9:foo               }|
      {7:  }{8:  2 }foo                │{7:  }{8:  3 }foo               |
      {7:  }{8:  3 }bar                │{7:  }{8:  4 }bar               |
      {1:~                        }│{1:~                       }|*6
      {3:[No Name] [+]             }{2:[No Name] [+]           }|
                                                        |
    ]])
  end)
end)

describe('CursorColumn highlight', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(50, 8)
    screen:add_extra_attr_ids {
      [100] = { background = Screen.colors.Blue1 },
    }
    screen:attach()
  end)

  it('is updated when pressing "i" on a TAB character', function()
    exec([[
      call setline(1, ['123456789', "a\tb"])
      set cursorcolumn
      call cursor(2, 2)
    ]])
    screen:expect([[
      1234567{21:8}9                                         |
      a      ^ b                                         |
      {1:~                                                 }|*5
                                                        |
    ]])
    feed('i')
    screen:expect([[
      1{21:2}3456789                                         |
      a^       b                                         |
      {1:~                                                 }|*5
      {5:-- INSERT --}                                      |
    ]])
    feed('<C-O>')
    screen:expect([[
      1234567{21:8}9                                         |
      a      ^ b                                         |
      {1:~                                                 }|*5
      {5:-- (insert) --}                                    |
    ]])
    feed('i')
    screen:expect([[
      1{21:2}3456789                                         |
      a^       b                                         |
      {1:~                                                 }|*5
      {5:-- INSERT --}                                      |
    ]])
  end)

  -- oldtest: Test_cursorcolumn_callback()
  it('is updated if cursor is moved from timer', function()
    exec([[
      call setline(1, ['aaaaa', 'bbbbb', 'ccccc', 'ddddd'])
      set cursorcolumn
      call cursor(4, 5)

      func Func(timer)
        call cursor(1, 1)
      endfunc

      call timer_start(300, 'Func')
    ]])
    screen:expect({
      grid = [[
      aaaa{21:a}                                             |
      bbbb{21:b}                                             |
      cccc{21:c}                                             |
      dddd^d                                             |
      {1:~                                                 }|*3
                                                        |
    ]],
      timeout = 100,
    })
    screen:expect({
      grid = [[
      ^aaaaa                                             |
      {21:b}bbbb                                             |
      {21:c}cccc                                             |
      {21:d}dddd                                             |
      {1:~                                                 }|*3
                                                        |
    ]],
    })
  end)

  it('is not shown on current line with virtualedit', function()
    exec([[
      hi! CursorColumn guibg=Red
      hi! CursorLine guibg=Blue
      set virtualedit=all cursorline cursorcolumn
    ]])
    insert('line 1\nline 2\nline 3')
    feed('k')
    screen:expect([[
      line {30:1}                                            |
      {100:line ^2                                            }|
      line {30:3}                                            |
      {1:~                                                 }|*4
                                                        |
    ]])
    feed('l')
    screen:expect([[
      line 1{30: }                                           |
      {100:line 2^                                            }|
      line 3{30: }                                           |
      {1:~                                                 }|*4
                                                        |
    ]])
    feed('l')
    screen:expect([[
      line 1 {30: }                                          |
      {100:line 2 ^                                           }|
      line 3 {30: }                                          |
      {1:~                                                 }|*4
                                                        |
    ]])
    feed('l')
    screen:expect([[
      line 1  {30: }                                         |
      {100:line 2  ^                                          }|
      line 3  {30: }                                         |
      {1:~                                                 }|*4
                                                        |
    ]])
  end)
end)

describe('ColorColumn highlight', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(40, 15)
    screen:add_extra_attr_ids {
      [100] = { foreground = Screen.colors.Red, background = Screen.colors.Grey90 },
      [101] = { background = Screen.colors.LightRed },
      [102] = { foreground = Screen.colors.Blue1, bold = true, background = Screen.colors.LightRed },
    }
    screen:attach()
  end)

  -- oldtest: Test_colorcolumn()
  it('when entering a buffer vim-patch:8.1.2073', function()
    exec([[
      set nohidden
      split
      edit X
      call setline(1, ["1111111111","22222222222","3333333333"])
      set nomodified
      set colorcolumn=3,9
      set number cursorline cursorlineopt=number
      wincmd w
      buf X
    ]])
    screen:expect([[
      {15:  1 }11{101:1}11111{101:1}1                          |
      {8:  2 }22{101:2}22222{101:2}22                         |
      {8:  3 }33{101:3}33333{101:3}3                          |
      {1:~                                       }|*3
      {2:X                                       }|
      {15:  1 }^11{101:1}11111{101:1}1                          |
      {8:  2 }22{101:2}22222{101:2}22                         |
      {8:  3 }33{101:3}33333{101:3}3                          |
      {1:~                                       }|*3
      {3:X                                       }|
                                              |
    ]])
  end)

  -- oldtest: Test_colorcolumn_bri()
  it("in 'breakindent' vim-patch:8.2.1689", function()
    exec([[
      call setline(1, 'The quick brown fox jumped over the lazy dogs')
      set co=40 linebreak bri briopt=shift:2 cc=40,41,43
    ]])
    screen:expect([[
      ^The quick brown fox jumped over the    {101: }|
      {101: } {101:l}azy dogs                             |
      {1:~                                       }|*12
                                              |
    ]])
  end)

  -- oldtest: Test_colorcolumn_sbr()
  it("in 'showbreak' vim-patch:8.2.1689", function()
    exec([[
      call setline(1, 'The quick brown fox jumped over the lazy dogs')
      set co=40 showbreak=+++>\\  cc=40,41,43
    ]])
    screen:expect([[
      ^The quick brown fox jumped over the laz{101:y}|
      {102:+}{1:+}{102:+}{1:>\} dogs                              |
      {1:~                                       }|*12
                                              |
    ]])
  end)

  it('is combined with low-priority CursorLine highlight #23016', function()
    screen:try_resize(40, 2)
    command('set colorcolumn=30 cursorline')
    screen:expect([[
      {21:^                             }{101: }{21:          }|
                                              |
    ]])
    command('hi clear ColorColumn')
    screen:expect([[
      {21:^                                        }|
                                              |
    ]])
    command('hi ColorColumn guifg=Red')
    screen:expect([[
      {21:^                             }{100: }{21:          }|
                                              |
    ]])
  end)
end)

describe('MsgSeparator highlight and msgsep fillchar', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(50, 5)
    screen:set_default_attr_ids({
      [1] = { bold = true, foreground = Screen.colors.Blue },
      [2] = { bold = true, reverse = true },
      [3] = { bold = true, foreground = Screen.colors.SeaGreen4 },
      [4] = { background = Screen.colors.Cyan, bold = true, reverse = true },
      [5] = { bold = true, background = Screen.colors.Magenta },
      [6] = { background = Screen.colors.WebGray },
      [7] = {
        background = Screen.colors.WebGray,
        bold = true,
        foreground = Screen.colors.SeaGreen4,
      },
      [8] = { foreground = Screen.colors.Grey0, background = Screen.colors.Gray60 },
      [9] = { foreground = Screen.colors.Grey40, background = Screen.colors.Gray60 },
      [10] = { foreground = tonumber('0x000019'), background = Screen.colors.Gray60 },
      [11] = { background = Screen.colors.Gray60, bold = true, foreground = tonumber('0x666699') },
      [12] = { background = Screen.colors.Gray60, bold = true, foreground = tonumber('0x297d4e') },
      [13] = { background = tonumber('0xff4cff'), bold = true, foreground = tonumber('0xb200ff') },
    })
    screen:attach()
  end)

  it('works', function()
    -- defaults
    feed_command('ls')
    screen:expect([[
                                                        |
      {2:                                                  }|
      :ls                                               |
        1 %a   "[No Name]"                    line 1    |
      {3:Press ENTER or type command to continue}^           |
    ]])
    feed('<cr>')

    feed_command('set fillchars+=msgsep:-')
    feed_command('ls')
    screen:expect([[
                                                        |
      {2:--------------------------------------------------}|
      :ls                                               |
        1 %a   "[No Name]"                    line 1    |
      {3:Press ENTER or type command to continue}^           |
    ]])

    -- linked to StatusLine per default
    feed_command('hi StatusLine guibg=Cyan')
    feed_command('ls')
    screen:expect([[
                                                        |
      {4:--------------------------------------------------}|
      :ls                                               |
        1 %a   "[No Name]"                    line 1    |
      {3:Press ENTER or type command to continue}^           |
    ]])

    -- but can be unlinked
    feed_command('hi clear MsgSeparator')
    feed_command('hi MsgSeparator guibg=Magenta gui=bold')
    feed_command('ls')
    screen:expect([[
                                                        |
      {5:--------------------------------------------------}|
      :ls                                               |
        1 %a   "[No Name]"                    line 1    |
      {3:Press ENTER or type command to continue}^           |
    ]])
  end)

  it('and MsgArea', function()
    feed_command('hi MsgArea guibg=Gray')
    screen:expect {
      grid = [[
      ^                                                  |
      {1:~                                                 }|*3
      {6:                                                  }|
    ]],
    }
    feed(':ls')
    screen:expect {
      grid = [[
                                                        |
      {1:~                                                 }|*3
      {6::ls^                                               }|
    ]],
    }
    feed(':<cr>')
    screen:expect {
      grid = [[
                                                        |
      {2:                                                  }|
      {6::ls:                                              }|
      {6:  1 %a   "[No Name]"                    line 1    }|
      {7:Press ENTER or type command to continue}{6:^           }|
    ]],
    }

    -- support madness^Wblending of message "overlay"
    feed_command('hi MsgArea blend=20')
    feed_command('hi clear MsgSeparator')
    feed_command('hi MsgSeparator blend=30 guibg=Magenta')
    screen:expect {
      grid = [[
      ^                                                  |
      {1:~                                                 }|*3
      {8::hi}{9: }{8:MsgSeparator}{9: }{8:blend=30}{9: }{8:guibg=Magenta}{9:           }|
    ]],
    }
    feed(':ls')
    screen:expect {
      grid = [[
                                                        |
      {1:~                                                 }|*3
      {8::ls}{9:^                                               }|
    ]],
    }
    feed('<cr>')
    screen:expect {
      grid = [[
                                                        |
      {13:~                                                 }|
      {10::ls}{11:                                               }|
      {11:~ }{10:1}{11: }{10:%a}{11:   }{10:"[No}{11: }{10:Name]"}{11:                    }{10:line}{11: }{10:1}{11:    }|
      {12:Press}{9: }{12:ENTER}{9: }{12:or}{9: }{12:type}{9: }{12:command}{9: }{12:to}{9: }{12:continue}{9:^           }|
    ]],
    }
  end)
end)

describe("'winhighlight' highlight", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(20, 8)
    screen:attach()
    screen:set_default_attr_ids {
      [0] = { bold = true, foreground = Screen.colors.Blue },
      [1] = { background = Screen.colors.DarkBlue },
      [2] = { background = Screen.colors.DarkBlue, bold = true, foreground = Screen.colors.Blue1 },
      [3] = { bold = true, reverse = true },
      [4] = { reverse = true },
      [5] = { background = Screen.colors.DarkGreen },
      [6] = { background = Screen.colors.DarkGreen, bold = true, foreground = Screen.colors.Blue1 },
      [7] = { background = Screen.colors.DarkMagenta },
      [8] = {
        background = Screen.colors.DarkMagenta,
        bold = true,
        foreground = Screen.colors.Blue1,
      },
      [9] = { foreground = Screen.colors.Brown },
      [10] = { foreground = Screen.colors.Brown, background = Screen.colors.DarkBlue },
      [11] = { background = Screen.colors.DarkBlue, bold = true, reverse = true },
      [12] = { background = Screen.colors.DarkGreen, reverse = true },
      [13] = { background = Screen.colors.Magenta4, reverse = true },
      [14] = { background = Screen.colors.DarkBlue, reverse = true },
      [15] = { foreground = Screen.colors.Grey100, background = Screen.colors.Red },
      [16] = { foreground = Screen.colors.Blue1 },
      [17] = { background = Screen.colors.LightRed },
      [18] = { background = Screen.colors.Gray90 },
      [19] = { foreground = Screen.colors.LightGrey, background = Screen.colors.DarkGray },
      [20] = { background = Screen.colors.LightGrey, underline = true },
      [21] = { bold = true },
      [22] = { bold = true, foreground = Screen.colors.SeaGreen4 },
      [23] = { background = Screen.colors.LightMagenta },
      [24] = { background = Screen.colors.WebGray },
      [25] = { bold = true, foreground = Screen.colors.Green1 },
      [26] = { background = Screen.colors.Red },
      [27] = { background = Screen.colors.DarkBlue, bold = true, foreground = Screen.colors.Green1 },
      [28] = { bold = true, foreground = Screen.colors.Brown },
      [29] = { foreground = Screen.colors.Blue1, background = Screen.colors.Red, bold = true },
      [30] = { background = tonumber('0xff8800') },
      [31] = { background = tonumber('0xff8800'), bold = true, foreground = Screen.colors.Blue },
    }
    command('hi Background1 guibg=DarkBlue')
    command('hi Background2 guibg=DarkGreen')
  end)

  it('works for background color', function()
    insert('aa')
    command('split')
    command('set winhl=Normal:Background1')
    screen:expect([[
      {1:a^a                  }|
      {2:~                   }|*2
      {3:[No Name] [+]       }|
      aa                  |
      {0:~                   }|
      {4:[No Name] [+]       }|
                          |
    ]])

    command('enew')
    screen:expect([[
      {1:^                    }|
      {2:~                   }|*2
      {3:[No Name]           }|
      aa                  |
      {0:~                   }|
      {4:[No Name] [+]       }|
                          |
    ]])
  end)

  it('works for background color in rightleft window #22640', function()
    -- Use a wide screen to also check that this doesn't overflow linebuf_attr.
    screen:try_resize(80, 6)
    insert('aa')
    command('setlocal rightleft')
    command('setlocal winhl=Normal:Background1')
    screen:expect([[
      {1:                                                                              ^aa}|
      {2:                                                                               ~}|*4
                                                                                      |
    ]])
    command('botright vsplit')
    screen:expect([[
      {1:                                     aa│                                      ^aa}|
      {2:                                      ~}{1:│}{2:                                       ~}|*3
      {4:[No Name] [+]                           }{3:[No Name] [+]                           }|
                                                                                      |
    ]])
  end)

  it('handles undefined groups', function()
    command('set winhl=Normal:Background1')
    screen:expect([[
      {1:^                    }|
      {2:~                   }|*6
                          |
    ]])

    command('set winhl=xxx:yyy')
    eq('xxx:yyy', eval('&winhl'))
    screen:expect {
      grid = [[
      ^                    |
      {0:~                   }|*6
                          |
    ]],
    }
  end)

  it('can be changed to define different groups', function()
    command('set winhl=EndOfBuffer:Background1')
    screen:expect {
      grid = [[
      ^                    |
      {1:~                   }|*6
                          |
    ]],
    }

    command('set winhl=Normal:ErrorMsg')
    screen:expect {
      grid = [[
      {15:^                    }|
      {29:~                   }|*6
                          |
    ]],
    }
  end)

  it('works local to the window', function()
    insert('aa')
    command('split')
    command('setlocal winhl=Normal:Background1')
    screen:expect([[
      {1:a^a                  }|
      {2:~                   }|*2
      {3:[No Name] [+]       }|
      aa                  |
      {0:~                   }|
      {4:[No Name] [+]       }|
                          |
    ]])

    command('enew')
    screen:expect([[
      ^                    |
      {0:~                   }|*2
      {3:[No Name]           }|
      aa                  |
      {0:~                   }|
      {4:[No Name] [+]       }|
                          |
    ]])

    command('bnext')
    screen:expect([[
      {1:^aa                  }|
      {2:~                   }|*2
      {3:[No Name] [+]       }|
      aa                  |
      {0:~                   }|
      {4:[No Name] [+]       }|
                          |
    ]])
  end)

  it('for inactive window background works', function()
    command('set winhl=Normal:Background1,NormalNC:Background2')
    -- tests global value is copied across split
    command('split')
    screen:expect([[
      {1:^                    }|
      {2:~                   }|*2
      {3:[No Name]           }|
      {5:                    }|
      {6:~                   }|
      {4:[No Name]           }|
                          |
    ]])

    feed('<c-w><c-w>')
    screen:expect([[
      {5:                    }|
      {6:~                   }|*2
      {4:[No Name]           }|
      {1:^                    }|
      {2:~                   }|
      {3:[No Name]           }|
                          |
    ]])

    feed('<c-w><c-w>')
    screen:expect([[
      {1:^                    }|
      {2:~                   }|*2
      {3:[No Name]           }|
      {5:                    }|
      {6:~                   }|
      {4:[No Name]           }|
                          |
    ]])
  end)

  it('works with NormalNC', function()
    command('hi NormalNC guibg=DarkMagenta')
    -- tests global value is copied across split
    command('split')
    screen:expect([[
      ^                    |
      {0:~                   }|*2
      {3:[No Name]           }|
      {7:                    }|
      {8:~                   }|
      {4:[No Name]           }|
                          |
    ]])

    command('wincmd w')
    screen:expect([[
      {7:                    }|
      {8:~                   }|*2
      {4:[No Name]           }|
      ^                    |
      {0:~                   }|
      {3:[No Name]           }|
                          |
    ]])

    -- winbg=Normal:... overrides global NormalNC
    command('set winhl=Normal:Background1')
    screen:expect([[
      {7:                    }|
      {8:~                   }|*2
      {4:[No Name]           }|
      {1:^                    }|
      {2:~                   }|
      {3:[No Name]           }|
                          |
    ]])

    command('wincmd w')
    screen:expect([[
      ^                    |
      {0:~                   }|*2
      {3:[No Name]           }|
      {1:                    }|
      {2:~                   }|
      {4:[No Name]           }|
                          |
    ]])

    command('wincmd w')
    command('set winhl=Normal:Background1,NormalNC:Background2')
    screen:expect([[
      {7:                    }|
      {8:~                   }|*2
      {4:[No Name]           }|
      {1:^                    }|
      {2:~                   }|
      {3:[No Name]           }|
                          |
    ]])

    command('wincmd w')
    screen:expect([[
      ^                    |
      {0:~                   }|*2
      {3:[No Name]           }|
      {5:                    }|
      {6:~                   }|
      {4:[No Name]           }|
                          |
    ]])
  end)

  it('updates background to changed linked group', function()
    command('split')
    command('setlocal winhl=Normal:FancyGroup') -- does not yet exist
    screen:expect {
      grid = [[
      ^                    |
      {0:~                   }|*2
      {3:[No Name]           }|
                          |
      {0:~                   }|
      {4:[No Name]           }|
                          |
    ]],
    }

    command('hi FancyGroup guibg=#FF8800') -- nice orange
    screen:expect {
      grid = [[
      {30:^                    }|
      {31:~                   }|*2
      {3:[No Name]           }|
                          |
      {0:~                   }|
      {4:[No Name]           }|
                          |
    ]],
    }
  end)

  it('background applies also to non-text', function()
    command('set sidescroll=0')
    insert('Lorem ipsum dolor sit amet ')
    command('set shiftwidth=2')
    feed('>>')
    command('set number')
    command('set breakindent')
    command('set briopt=shift:5,min:0')
    command('set list')
    command('set showbreak=↪')
    screen:expect([[
      {9:  1 }  ^Lorem ipsum do|
      {9:    }       {0:↪}lor sit |
      {9:    }       {0:↪}amet{0:-}   |
      {0:~                   }|*4
                          |
    ]])

    command('set winhl=Normal:Background1')
    screen:expect([[
      {10:  1 }{1:  ^Lorem ipsum do}|
      {10:    }{1:       }{2:↪}{1:lor sit }|
      {10:    }{1:       }{2:↪}{1:amet}{2:-}{1:   }|
      {2:~                   }|*4
                          |
    ]])

    command('set nowrap')
    command('set listchars+=extends:❯,precedes:❮')
    feed('3w')
    screen:expect([[
      {10:  1 }{2:❮}{1: dolor ^sit ame}{2:❯}|
      {2:~                   }|*6
                          |
    ]])
  end)

  it("background doesn't override syntax background", function()
    command('syntax on')
    command('syntax keyword Foobar foobar')
    command('syntax keyword Article the')
    command('hi Foobar guibg=#FF0000')
    command('hi Article guifg=#00FF00 gui=bold')
    insert('the foobar was foobar')
    screen:expect([[
      {25:the} {26:foobar} was {26:fooba}|
      {26:^r}                   |
      {0:~                   }|*5
                          |
    ]])

    -- winhl=Normal:Group with background doesn't override syntax background,
    -- but does combine with syntax foreground.
    command('set winhl=Normal:Background1')
    screen:expect([[
      {27:the}{1: }{26:foobar}{1: was }{26:fooba}|
      {26:^r}{1:                   }|
      {2:~                   }|*5
                          |
    ]])
  end)

  it('can override NonText, Conceal and EndOfBuffer', function()
    api.nvim_buf_set_lines(0, 0, -1, true, { 'raa\000' })
    command('call matchaddpos("Conceal", [[1,2]], 0, -1, {"conceal": "#"})')
    command('set cole=2 cocu=nvic')
    command('split')
    command('call matchaddpos("Conceal", [[1,2]], 0, -1, {"conceal": "#"})')
    command('set winhl=SpecialKey:ErrorMsg,EndOfBuffer:Background1,' .. 'Conceal:Background2')

    screen:expect([[
      ^r{5:#}a{15:^@}               |
      {1:~                   }|*2
      {3:[No Name] [+]       }|
      r{19:#}a{16:^@}               |
      {0:~                   }|
      {4:[No Name] [+]       }|
                          |
    ]])
  end)

  it('can override LineNr, CursorColumn and ColorColumn', function()
    insert('very text\nmore text')
    command('set number')
    command('set colorcolumn=2')
    command('set cursorcolumn')
    feed('k')

    command('split')
    command('set winhl=LineNr:Background1,CursorColumn:Background2,' .. 'ColorColumn:ErrorMsg')
    screen:expect([[
      {1:  1 }v{15:e}ry tex^t       |
      {1:  2 }m{15:o}re tex{5:t}       |
      {0:~                   }|
      {3:[No Name] [+]       }|
      {9:  1 }v{17:e}ry text       |
      {9:  2 }m{17:o}re tex{18:t}       |
      {4:[No Name] [+]       }|
                          |
    ]])
  end)

  it('can override Tabline', function()
    command('tabnew')
    command('set winhl=TabLine:Background1,TabLineSel:ErrorMsg')

    screen:expect([[
      {20: No Name] }{15: No Name]}{20:X}|
      ^                    |
      {0:~                   }|*5
                          |
    ]])
    command('tabnext')
    screen:expect([[
      {21: No Name] }{1: No Name]}{20:X}|
      ^                    |
      {0:~                   }|*5
                          |
    ]])
  end)

  it('can override popupmenu', function()
    insert('word wording wordy')
    command('split')
    command(
      'set winhl=Pmenu:Background1,PmenuSel:Background2,' .. 'PmenuSbar:ErrorMsg,PmenuThumb:Normal'
    )
    screen:expect([[
      word wording word^y  |
      {0:~                   }|*2
      {3:[No Name] [+]       }|
      word wording wordy  |
      {0:~                   }|
      {4:[No Name] [+]       }|
                          |
    ]])

    feed('oword<c-x><c-p>')
    screen:expect([[
      word wording wordy  |
      wordy^               |
      {1:word           }{0:     }|
      {1:wording        }{3:     }|
      {5:wordy          }rdy  |
      wordy               |
      {4:[No Name] [+]       }|
      {21:-- }{22:match 1 of 3}     |
    ]])

    feed('<esc>u<c-w><c-w>oword<c-x><c-p>')
    screen:expect([[
      word wording wordy  |
      wordy               |
      {23:word           }{0:     }|
      {23:wording        }{4:     }|
      {24:wordy          }rdy  |
      wordy^               |
      {3:[No Name] [+]       }|
      {21:-- }{22:match 1 of 3}     |
    ]])
  end)

  it('can override CursorLine and CursorLineNr', function()
    -- CursorLine used to be parsed as CursorLineNr, because strncmp
    command('set cursorline number')
    command('split')
    command('set winhl=CursorLine:Background1')
    screen:expect {
      grid = [[
      {28:  1 }{1:^                }|
      {0:~                   }|*2
      {3:[No Name]           }|
      {28:  1 }{18:                }|
      {0:~                   }|
      {4:[No Name]           }|
                          |
    ]],
    }

    command('set winhl=CursorLineNr:Background2,CursorLine:Background1')
    screen:expect {
      grid = [[
      {5:  1 }{1:^                }|
      {0:~                   }|*2
      {3:[No Name]           }|
      {28:  1 }{18:                }|
      {0:~                   }|
      {4:[No Name]           }|
                          |
    ]],
    }

    feed('<c-w>w')
    screen:expect {
      grid = [[
      {5:  1 }{1:                }|
      {0:~                   }|*2
      {4:[No Name]           }|
      {28:  1 }{18:^                }|
      {0:~                   }|
      {3:[No Name]           }|
                          |
    ]],
    }
  end)

  it('can override StatusLine and StatusLineNC', function()
    command('set winhighlight=StatusLine:Background1,StatusLineNC:Background2')
    command('split')
    screen:expect([[
      ^                    |
      {0:~                   }|*2
      {1:[No Name]           }|
                          |
      {0:~                   }|
      {5:[No Name]           }|
                          |
    ]])
  end)

  it('can override WinBar and WinBarNC #19345', function()
    command('setlocal winbar=foobar')
    command('set winhighlight=WinBar:Background1,WinBarNC:Background2')
    command('split')
    screen:expect([[
      {1:foobar              }|
      ^                    |
      {0:~                   }|
      {3:[No Name]           }|
      {5:foobar              }|
                          |
      {4:[No Name]           }|
                          |
    ]])
  end)

  it('can override syntax groups', function()
    command('syntax on')
    command('syntax keyword Foobar foobar')
    command('syntax keyword Article the')
    command('hi Foobar guibg=#FF0000')
    command('hi Article guifg=#00FF00 gui=bold')
    insert('the foobar was foobar')
    screen:expect([[
      {25:the} {26:foobar} was {26:fooba}|
      {26:^r}                   |
      {0:~                   }|*5
                          |
    ]])

    command('split')
    command('set winhl=Foobar:Background1,Article:ErrorMsg')
    screen:expect {
      grid = [[
      {15:the} {1:foobar} was {1:fooba}|
      {1:^r}                   |
      {0:~                   }|
      {3:[No Name] [+]       }|
      {25:the} {26:foobar} was {26:fooba}|
      {26:r}                   |
      {4:[No Name] [+]       }|
                          |
    ]],
    }
  end)

  it('can be disabled in newly opened window #19823', function()
    command('split | set winhl=Normal:ErrorMsg | set winhl=')
    screen:expect {
      grid = [[
      ^                    |
      {0:~                   }|*2
      {3:[No Name]           }|
                          |
      {0:~                   }|
      {4:[No Name]           }|
                          |
    ]],
    }

    t.assert_alive()
  end)

  it('can redraw statusline on cursor movement', function()
    screen:try_resize(40, 8)
    exec [[
      set statusline=%f%=%#Background1#%l,%c%V\ %P
      split
    ]]
    insert [[
      some text
      more text]]
    screen:expect {
      grid = [[
      some text                               |
      more tex^t                               |
      {0:~                                       }|
      {3:[No Name]                        }{1:2,9 All}|
      some text                               |
      more text                               |
      {4:[No Name]                        }{1:1,1 All}|
                                              |
    ]],
    }

    command 'set winhl=Background1:Background2'
    screen:expect {
      grid = [[
      some text                               |
      more tex^t                               |
      {0:~                                       }|
      {3:[No Name]                        }{5:2,9 All}|
      some text                               |
      more text                               |
      {4:[No Name]                        }{1:1,1 All}|
                                              |
    ]],
    }

    feed 'k'
    screen:expect {
      grid = [[
      some tex^t                               |
      more text                               |
      {0:~                                       }|
      {3:[No Name]                        }{5:1,9 All}|
      some text                               |
      more text                               |
      {4:[No Name]                        }{1:1,1 All}|
                                              |
    ]],
    }
  end)

  it('can link to empty highlight group', function()
    command 'hi NormalNC guibg=Red' -- czerwone time
    command 'set winhl=NormalNC:Normal'
    command 'split'

    screen:expect {
      grid = [[
      ^                    |
      {0:~                   }|*2
      {3:[No Name]           }|
                          |
      {0:~                   }|
      {4:[No Name]           }|
                          |
    ]],
    }
  end)
end)

describe('highlight namespaces', function()
  local screen
  local ns1, ns2

  before_each(function()
    clear()
    screen = Screen.new(25, 10)
    screen:attach()
    screen:set_default_attr_ids {
      [1] = { foreground = Screen.colors.Blue, bold = true },
      [2] = { background = Screen.colors.DarkGrey },
      [3] = {
        italic = true,
        foreground = Screen.colors.DarkCyan,
        background = Screen.colors.DarkOrange4,
      },
      [4] = { background = Screen.colors.Magenta4 },
      [5] = { background = Screen.colors.Magenta4, foreground = Screen.colors.Crimson },
      [6] = { bold = true, reverse = true },
      [7] = { reverse = true },
      [8] = { foreground = Screen.colors.Gray20 },
      [9] = { foreground = Screen.colors.Blue },
      [10] = { bold = true, foreground = Screen.colors.SeaGreen },
    }

    ns1 = api.nvim_create_namespace 'grungy'
    ns2 = api.nvim_create_namespace 'ultrared'

    api.nvim_set_hl(ns1, 'Normal', { bg = 'DarkGrey' })
    api.nvim_set_hl(ns1, 'NonText', { bg = 'DarkOrange4', fg = 'DarkCyan', italic = true })
    api.nvim_set_hl(ns2, 'Normal', { bg = 'DarkMagenta' })
    api.nvim_set_hl(ns2, 'NonText', { fg = 'Crimson' })
  end)

  it('can be used globally', function()
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*8
                               |
    ]],
    }

    api.nvim_set_hl_ns(ns1)
    screen:expect {
      grid = [[
      {2:^                         }|
      {3:~                        }|*8
                               |
    ]],
    }

    api.nvim_set_hl_ns(ns2)
    screen:expect {
      grid = [[
      {4:^                         }|
      {5:~                        }|*8
                               |
    ]],
    }

    api.nvim_set_hl_ns(0)
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*8
                               |
    ]],
    }
  end)

  it('can be used per window', function()
    local win1 = api.nvim_get_current_win()
    command 'split'
    local win2 = api.nvim_get_current_win()
    command 'split'

    api.nvim_win_set_hl_ns(win1, ns1)
    api.nvim_win_set_hl_ns(win2, ns2)

    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|
      {6:[No Name]                }|
      {4:                         }|
      {5:~                        }|
      {7:[No Name]                }|
      {2:                         }|
      {3:~                        }|
      {7:[No Name]                }|
                               |
    ]],
    }
  end)

  it('redraws correctly when ns=0', function()
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*8
                               |
    ]],
    }

    api.nvim_set_hl(0, 'EndOfBuffer', { fg = '#333333' })
    screen:expect {
      grid = [[
      ^                         |
      {8:~                        }|*8
                               |
    ]],
    }
  end)

  it('winhl does not accept invalid value #24586', function()
    local res = exec_lua([[
      local curwin = vim.api.nvim_get_current_win()
      vim.api.nvim_command("set winhl=Normal:Visual")
      local _, msg = pcall(vim.api.nvim_command,"set winhl='Normal:Wrong'")
      return { msg, vim.wo[curwin].winhl }
    ]])
    eq({
      'Vim(set):E5248: Invalid character in group name',
      'Normal:Visual',
    }, res)
  end)

  it('Normal in set_hl #25474', function()
    command('highlight Ignore guifg=bg ctermfg=White')
    api.nvim_set_hl(0, 'Normal', { bg = '#333333' })
    command('highlight Ignore')
    screen:expect {
      grid = [[
                               |
      {1:~                        }|*2
      {6:                         }|
                               |
      Ignore         {8:xxx} {9:ctermf}|
      {9:g=}15               {9:guifg=}|
      bg                       |
      {10:Press ENTER or type comma}|
      {10:nd to continue}^           |
    ]],
    }
  end)
end)

describe('synIDattr()', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(50, 7)
    command('highlight Normal ctermfg=252 guifg=#ff0000 guibg=Black')
    -- Salmon #fa8072 Maroon #800000
    command(
      'highlight Keyword ctermfg=79 guifg=Salmon guisp=Maroon cterm=strikethrough gui=strikethrough'
    )
  end)

  it('returns cterm-color if RGB-capable UI is _not_ attached', function()
    eq('252', eval('synIDattr(hlID("Normal"),  "fg")'))
    eq('252', eval('synIDattr(hlID("Normal"),  "fg#")'))
    eq('', eval('synIDattr(hlID("Normal"),  "bg")'))
    eq('', eval('synIDattr(hlID("Normal"),  "bg#")'))
    eq('79', eval('synIDattr(hlID("Keyword"), "fg")'))
    eq('79', eval('synIDattr(hlID("Keyword"), "fg#")'))
    eq('', eval('synIDattr(hlID("Keyword"), "sp")'))
    eq('', eval('synIDattr(hlID("Keyword"), "sp#")'))
  end)

  it('returns gui-color if "gui" arg is passed', function()
    eq('Black', eval('synIDattr(hlID("Normal"),  "bg", "gui")'))
    eq('Maroon', eval('synIDattr(hlID("Keyword"), "sp", "gui")'))
  end)

  it('returns gui-color if RGB-capable UI is attached', function()
    screen:attach({ rgb = true })
    eq('#ff0000', eval('synIDattr(hlID("Normal"),  "fg")'))
    eq('Black', eval('synIDattr(hlID("Normal"),  "bg")'))
    eq('Salmon', eval('synIDattr(hlID("Keyword"), "fg")'))
    eq('Maroon', eval('synIDattr(hlID("Keyword"), "sp")'))
  end)

  it('returns #RRGGBB value for fg#/bg#/sp#', function()
    screen:attach({ rgb = true })
    eq('#ff0000', eval('synIDattr(hlID("Normal"),  "fg#")'))
    eq('#000000', eval('synIDattr(hlID("Normal"),  "bg#")'))
    eq('#fa8072', eval('synIDattr(hlID("Keyword"), "fg#")'))
    eq('#800000', eval('synIDattr(hlID("Keyword"), "sp#")'))
  end)

  it('returns color number if non-GUI', function()
    screen:attach({ rgb = false })
    eq('252', eval('synIDattr(hlID("Normal"), "fg")'))
    eq('79', eval('synIDattr(hlID("Keyword"), "fg")'))
  end)

  it('returns "1" if group has given highlight attribute', function()
    local hl_attrs = {
      'underline',
      'undercurl',
      'underdouble',
      'underdotted',
      'underdashed',
      'strikethrough',
    }
    for _, hl_attr in ipairs(hl_attrs) do
      local context = 'using ' .. hl_attr .. ' attr'
      command('highlight Keyword cterm=' .. hl_attr .. ' gui=' .. hl_attr)
      eq('', eval('synIDattr(hlID("Normal"), "' .. hl_attr .. '")'), context)
      eq('1', eval('synIDattr(hlID("Keyword"), "' .. hl_attr .. '")'), context)
      eq('1', eval('synIDattr(hlID("Keyword"), "' .. hl_attr .. '", "gui")'), context)
    end
  end)
end)

describe('fg/bg special colors', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(50, 7)
    command('highlight Normal ctermfg=145 ctermbg=16 guifg=#ff0000 guibg=Black')
    command('highlight Visual ctermfg=bg ctermbg=fg guifg=bg guibg=fg guisp=bg')
  end)

  it('resolve to "Normal" values', function()
    eq(eval('synIDattr(hlID("Normal"), "bg")'), eval('synIDattr(hlID("Visual"), "fg")'))
    eq(eval('synIDattr(hlID("Normal"), "bg#")'), eval('synIDattr(hlID("Visual"), "fg#")'))
    eq(eval('synIDattr(hlID("Normal"), "fg")'), eval('synIDattr(hlID("Visual"), "bg")'))
    eq(eval('synIDattr(hlID("Normal"), "fg#")'), eval('synIDattr(hlID("Visual"), "bg#")'))
    eq('bg', eval('synIDattr(hlID("Visual"), "fg", "gui")'))
    eq('bg', eval('synIDattr(hlID("Visual"), "fg#", "gui")'))
    eq('fg', eval('synIDattr(hlID("Visual"), "bg", "gui")'))
    eq('fg', eval('synIDattr(hlID("Visual"), "bg#", "gui")'))
    eq('bg', eval('synIDattr(hlID("Visual"), "sp", "gui")'))
    eq('bg', eval('synIDattr(hlID("Visual"), "sp#", "gui")'))
  end)

  it('resolve to "Normal" values in RGB-capable UI', function()
    screen:attach({ rgb = true })
    eq('bg', eval('synIDattr(hlID("Visual"), "fg")'))
    eq(eval('synIDattr(hlID("Normal"), "bg#")'), eval('synIDattr(hlID("Visual"), "fg#")'))
    eq('fg', eval('synIDattr(hlID("Visual"), "bg")'))
    eq(eval('synIDattr(hlID("Normal"), "fg#")'), eval('synIDattr(hlID("Visual"), "bg#")'))
    eq('bg', eval('synIDattr(hlID("Visual"), "sp")'))
    eq(eval('synIDattr(hlID("Normal"), "bg#")'), eval('synIDattr(hlID("Visual"), "sp#")'))
  end)

  it('resolve after the "Normal" group is modified', function()
    screen:attach({ rgb = true })
    local new_guibg = '#282c34'
    local new_guifg = '#abb2bf'
    command('highlight Normal guifg=' .. new_guifg .. ' guibg=' .. new_guibg)
    eq(new_guibg, eval('synIDattr(hlID("Visual"), "fg#")'))
    eq(new_guifg, eval('synIDattr(hlID("Visual"), "bg#")'))
    eq(new_guibg, eval('synIDattr(hlID("Visual"), "sp#")'))
  end)
end)
