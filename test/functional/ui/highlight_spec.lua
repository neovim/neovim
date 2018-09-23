local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local os = require('os')
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local command = helpers.command
local eval, exc_exec = helpers.eval, helpers.exc_exec
local feed_command, eq = helpers.feed_command, helpers.eq
local curbufmeths = helpers.curbufmeths

describe('colorscheme compatibility', function()
  before_each(function()
    clear()
  end)

  it('t_Co is set to 256 by default', function()
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
    screen = Screen.new(20,5)
    screen:attach()
    --syntax highlight for vimcscripts "echo"
    screen:set_default_attr_ids( {
      [0] = {bold=true, foreground=Screen.colors.Blue},
      [1] = {bold=true, foreground=Screen.colors.Brown}
    } )
  end)

  after_each(function()
    screen:detach()
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
      {1:^echo} 1              |
      {0:~                   }|
      {0:~                   }|
      {0:~                   }|
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
    eq("tmp1.vim", eval("fnamemodify(bufname('%'), ':t')"))
    feed_command('silent bp')
    eq("Xtest-functional-ui-highlight.tmp.vim", eval("fnamemodify(bufname('%'), ':t')"))
    screen:expect([[
      {1:^echo} 1              |
      {0:~                   }|
      {0:~                   }|
      {0:~                   }|
      :silent bp          |
    ]])
  end)
end)


describe('highlight defaults', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new()
    screen:attach()
    command("set display-=msgsep")
  end)

  after_each(function()
    screen:detach()
  end)

  it('window status bar', function()
    screen:set_default_attr_ids({
      [0] = {bold=true, foreground=Screen.colors.Blue},
      [1] = {reverse = true, bold = true},  -- StatusLine
      [2] = {reverse = true}                -- StatusLineNC
    })
    feed_command('sp', 'vsp', 'vsp')
    screen:expect([[
      ^                    {2:│}                {2:│}               |
      {0:~                   }{2:│}{0:~               }{2:│}{0:~              }|
      {0:~                   }{2:│}{0:~               }{2:│}{0:~              }|
      {0:~                   }{2:│}{0:~               }{2:│}{0:~              }|
      {0:~                   }{2:│}{0:~               }{2:│}{0:~              }|
      {0:~                   }{2:│}{0:~               }{2:│}{0:~              }|
      {1:[No Name]            }{2:[No Name]        [No Name]      }|
                                                           |
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {2:[No Name]                                            }|
                                                           |
    ]])
    -- navigate to verify that the attributes are properly moved
    feed('<c-w>j')
    screen:expect([[
                          {2:│}                {2:│}               |
      {0:~                   }{2:│}{0:~               }{2:│}{0:~              }|
      {0:~                   }{2:│}{0:~               }{2:│}{0:~              }|
      {0:~                   }{2:│}{0:~               }{2:│}{0:~              }|
      {0:~                   }{2:│}{0:~               }{2:│}{0:~              }|
      {0:~                   }{2:│}{0:~               }{2:│}{0:~              }|
      {2:[No Name]            [No Name]        [No Name]      }|
      ^                                                     |
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {1:[No Name]                                            }|
                                                           |
    ]])
    -- note that when moving to a window with small width nvim will increase
    -- the width of the new active window at the expense of a inactive window
    -- (upstream vim has the same behavior)
    feed('<c-w>k<c-w>l')
    screen:expect([[
                          {2:│}^                    {2:│}           |
      {0:~                   }{2:│}{0:~                   }{2:│}{0:~          }|
      {0:~                   }{2:│}{0:~                   }{2:│}{0:~          }|
      {0:~                   }{2:│}{0:~                   }{2:│}{0:~          }|
      {0:~                   }{2:│}{0:~                   }{2:│}{0:~          }|
      {0:~                   }{2:│}{0:~                   }{2:│}{0:~          }|
      {2:[No Name]            }{1:[No Name]            }{2:[No Name]  }|
                                                           |
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {2:[No Name]                                            }|
                                                           |
    ]])
    feed('<c-w>l')
    screen:expect([[
                          {2:│}           {2:│}^                    |
      {0:~                   }{2:│}{0:~          }{2:│}{0:~                   }|
      {0:~                   }{2:│}{0:~          }{2:│}{0:~                   }|
      {0:~                   }{2:│}{0:~          }{2:│}{0:~                   }|
      {0:~                   }{2:│}{0:~          }{2:│}{0:~                   }|
      {0:~                   }{2:│}{0:~          }{2:│}{0:~                   }|
      {2:[No Name]            [No Name]   }{1:[No Name]           }|
                                                           |
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {2:[No Name]                                            }|
                                                           |
    ]])
    feed('<c-w>h<c-w>h')
    screen:expect([[
      ^                    {2:│}                    {2:│}           |
      {0:~                   }{2:│}{0:~                   }{2:│}{0:~          }|
      {0:~                   }{2:│}{0:~                   }{2:│}{0:~          }|
      {0:~                   }{2:│}{0:~                   }{2:│}{0:~          }|
      {0:~                   }{2:│}{0:~                   }{2:│}{0:~          }|
      {0:~                   }{2:│}{0:~                   }{2:│}{0:~          }|
      {1:[No Name]            }{2:[No Name]            [No Name]  }|
                                                           |
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {2:[No Name]                                            }|
                                                           |
    ]])
  end)

  it('insert mode text', function()
    feed('i')
    screen:try_resize(53, 4)
    screen:expect([[
      ^                                                     |
      {0:~                                                    }|
      {0:~                                                    }|
      {1:-- INSERT --}                                         |
    ]], {[0] = {bold=true, foreground=Screen.colors.Blue},
    [1] = {bold = true}})
  end)

  it('end of file markers', function()
    screen:try_resize(53, 4)
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|
      {1:~                                                    }|
                                                           |
    ]], {[1] = {bold = true, foreground = Screen.colors.Blue}})
  end)

  it('"wait return" text', function()
    screen:try_resize(53, 4)
    feed(':ls<cr>')
    screen:expect([[
      {0:~                                                    }|
      :ls                                                  |
        1 %a   "[No Name]"                    line 1       |
      {1:Press ENTER or type command to continue}^              |
    ]], {[0] = {bold=true, foreground=Screen.colors.Blue},
    [1] = {bold = true, foreground = Screen.colors.SeaGreen}})
    feed('<cr>') --  skip the "Press ENTER..." state or tests will hang
  end)

  it('can be cleared and linked to other highlight groups', function()
    screen:try_resize(53, 4)
    feed_command('highlight clear ModeMsg')
    feed('i')
    screen:expect([[
      ^                                                     |
      {0:~                                                    }|
      {0:~                                                    }|
      -- INSERT --                                         |
    ]], {[0] = {bold=true, foreground=Screen.colors.Blue},
    [1] = {bold=true}})
    feed('<esc>')
    feed_command('highlight CustomHLGroup guifg=red guibg=green')
    feed_command('highlight link ModeMsg CustomHLGroup')
    feed('i')
    screen:expect([[
      ^                                                     |
      {0:~                                                    }|
      {0:~                                                    }|
      {1:-- INSERT --}                                         |
    ]], {[0] = {bold=true, foreground=Screen.colors.Blue},
    [1] = {foreground = Screen.colors.Red, background = Screen.colors.Green}})
  end)

  it('can be cleared by assigning NONE', function()
    screen:try_resize(53, 4)
    feed_command('syn keyword TmpKeyword neovim')
    feed_command('hi link TmpKeyword ErrorMsg')
    insert('neovim')
    screen:expect([[
      {1:neovi^m}                                               |
      {0:~                                                    }|
      {0:~                                                    }|
                                                           |
    ]], {
      [0] = {bold=true, foreground=Screen.colors.Blue},
      [1] = {foreground = Screen.colors.White, background = Screen.colors.Red}
    })
    feed_command("hi ErrorMsg term=NONE cterm=NONE ctermfg=NONE ctermbg=NONE"
            .. " gui=NONE guifg=NONE guibg=NONE guisp=NONE")
    screen:expect([[
      neovi^m                                               |
      {0:~                                                    }|
      {0:~                                                    }|
                                                           |
    ]], {[0] = {bold=true, foreground=Screen.colors.Blue}})
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
      ne{0:.>----.}o{0:>-----}v{0:..}im{0:*^*¬}                             |
      {0:~                                                    }|
      {0:~                                                    }|
                                                           |
    ]], {
      [0] = {foreground=Screen.colors.Red},
      [1] = {foreground=Screen.colors.Blue},
    })
    feed_command('highlight Whitespace gui=NONE guifg=#0000FF')
    screen:expect([[
      ne{1:.>----.}o{1:>-----}v{1:..}im{1:*^*}{0:¬}                             |
      {0:~                                                    }|
      {0:~                                                    }|
      :highlight Whitespace gui=NONE guifg=#0000FF         |
    ]], {
      [0] = {foreground=Screen.colors.Red},
      [1] = {foreground=Screen.colors.Blue},
    })
  end)
end)

describe('highlight', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(25,10)
    screen:attach()
  end)

  it('cterm=standout gui=standout', function()
    screen:detach()
    screen = Screen.new(20,5)
    screen:attach()
    screen:set_default_attr_ids({
        [1] = {bold = true, foreground = Screen.colors.Blue1},
        [2] = {standout = true, bold = true, underline = true,
        background = Screen.colors.Gray90, foreground = Screen.colors.Blue1},
        [3] = {standout = true, underline = true,
        background = Screen.colors.Gray90}
    })
    feed_command('hi CursorLine cterm=standout,underline gui=standout,underline')
    feed_command('set cursorline')
    feed_command('set listchars=space:.,eol:¬,tab:>-,extends:>,precedes:<,trail:* list')
    feed('i\t abcd <cr>\t abcd <cr><esc>k')
    screen:expect([[
    {1:>-------.}abcd{1:*¬}     |
    {2:^>-------.}{3:abcd}{2:*¬}{3:     }|
    {1:¬}                   |
    {1:~                   }|
                        |
    ]])
  end)

  it('guisp (special/undercurl)', function()
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
    screen:expect([[
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
    ]],{
      [0] = {bold=true, foreground=Screen.colors.Blue},
      [1] = {background = Screen.colors.Yellow, foreground = Screen.colors.Red,
             special = Screen.colors.Red},
      [2] = {special = Screen.colors.Red},
      [3] = {special = Screen.colors.Red, background = Screen.colors.Yellow},
      [4] = {foreground = Screen.colors.Red, special = Screen.colors.Red},
      [5] = {bold=true},
    })

  end)
end)

describe("'listchars' highlight", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(20,5)
    screen:attach()
  end)

  after_each(function()
    screen:detach()
  end)

  it("'cursorline' and 'cursorcolumn'", function()
    screen:set_default_attr_ids({
      [0] = {bold=true, foreground=Screen.colors.Blue},
      [1] = {background=Screen.colors.Grey90}
    })
    feed_command('highlight clear ModeMsg')
    feed_command('set cursorline')
    feed('i')
    screen:expect([[
      {1:^                    }|
      {0:~                   }|
      {0:~                   }|
      {0:~                   }|
      -- INSERT --        |
    ]])
    feed('abcdefg<cr>kkasdf')
    screen:expect([[
      abcdefg             |
      {1:kkasdf^              }|
      {0:~                   }|
      {0:~                   }|
      -- INSERT --        |
    ]])
    feed('<esc>')
    screen:expect([[
      abcdefg             |
      {1:kkasd^f              }|
      {0:~                   }|
      {0:~                   }|
                          |
    ]])
    feed_command('set nocursorline')
    screen:expect([[
      abcdefg             |
      kkasd^f              |
      {0:~                   }|
      {0:~                   }|
      :set nocursorline   |
    ]])
    feed('k')
    screen:expect([[
      abcde^fg             |
      kkasdf              |
      {0:~                   }|
      {0:~                   }|
      :set nocursorline   |
    ]])
    feed('jjji<cr><cr><cr><esc>')
    screen:expect([[
      kkasd               |
                          |
                          |
      ^f                   |
                          |
    ]])
    feed_command('set cursorline')
    feed_command('set cursorcolumn')
    feed('kkiabcdefghijk<esc>hh')
    screen:expect([[
      kkasd   {1: }           |
      {1:abcdefgh^ijk         }|
              {1: }           |
      f       {1: }           |
                          |
    ]])
    feed('khh')
    screen:expect([[
      {1:kk^asd               }|
      ab{1:c}defghijk         |
        {1: }                 |
      f {1: }                 |
                          |
    ]])
  end)

  it("'cursorline' and with 'listchar' option: space, eol, tab, and trail", function()
    screen:set_default_attr_ids({
      [1] = {background=Screen.colors.Grey90},
      [2] = {
        foreground=Screen.colors.Red,
        background=Screen.colors.Grey90,
      },
      [3] = {
        background=Screen.colors.Grey90,
        foreground=Screen.colors.Blue,
        bold=true,
      },
      [4] = {
        foreground=Screen.colors.Blue,
        bold=true,
      },
      [5] = {
        foreground=Screen.colors.Red,
      },
    })
    feed_command('highlight clear ModeMsg')
    feed_command('highlight Whitespace guifg=#FF0000')
    feed_command('set cursorline')
    feed_command('set tabstop=8')
    feed_command('set listchars=space:.,eol:¬,tab:>-,extends:>,precedes:<,trail:* list')
    feed('i\t abcd <cr>\t abcd <cr><esc>k')
    screen:expect([[
      {5:>-------.}abcd{5:*}{4:¬}     |
      {2:^>-------.}{1:abcd}{2:*}{3:¬}{1:     }|
      {4:¬}                   |
      {4:~                   }|
                          |
    ]])
    feed('k')
    screen:expect([[
      {2:^>-------.}{1:abcd}{2:*}{3:¬}{1:     }|
      {5:>-------.}abcd{5:*}{4:¬}     |
      {4:¬}                   |
      {4:~                   }|
                          |
    ]])
    feed_command('set nocursorline')
    screen:expect([[
      {5:^>-------.}abcd{5:*}{4:¬}     |
      {5:>-------.}abcd{5:*}{4:¬}     |
      {4:¬}                   |
      {4:~                   }|
      :set nocursorline   |
    ]])
    feed_command('set nowrap')
    feed('ALorem ipsum dolor sit amet<ESC>0')
    screen:expect([[
      {5:^>-------.}abcd{5:.}Lorem{4:>}|
      {5:>-------.}abcd{5:*}{4:¬}     |
      {4:¬}                   |
      {4:~                   }|
                          |
    ]])
    feed_command('set cursorline')
    screen:expect([[
      {2:^>-------.}{1:abcd}{2:.}{1:Lorem}{3:>}|
      {5:>-------.}abcd{5:*}{4:¬}     |
      {4:¬}                   |
      {4:~                   }|
      :set cursorline     |
    ]])
    feed('$')
    screen:expect([[
      {3:<}{1:r}{2:.}{1:sit}{2:.}{1:ame^t}{3:¬}{1:        }|
      {4:<}                   |
      {4:<}                   |
      {4:~                   }|
      :set cursorline     |
    ]])
    feed('G')
    screen:expect([[
      {5:>-------.}abcd{5:.}Lorem{4:>}|
      {5:>-------.}abcd{5:*}{4:¬}     |
      {3:^¬}{1:                   }|
      {4:~                   }|
      :set cursorline     |
    ]])
  end)

  it("'listchar' in visual mode", function()
    screen:set_default_attr_ids({
      [1] = {background=Screen.colors.Grey90},
      [2] = {
        foreground=Screen.colors.Red,
        background=Screen.colors.Grey90,
      },
      [3] = {
        background=Screen.colors.Grey90,
        foreground=Screen.colors.Blue,
        bold=true,
      },
      [4] = {
        foreground=Screen.colors.Blue,
        bold=true,
      },
      [5] = {
        foreground=Screen.colors.Red,
      },
      [6] = {
        background=Screen.colors.LightGrey,
      },
      [7] = {
        background=Screen.colors.LightGrey,
        foreground=Screen.colors.Red,
      },
      [8] = {
        background=Screen.colors.LightGrey,
        foreground=Screen.colors.Blue,
        bold=true,
      },
    })
    feed_command('highlight clear ModeMsg')
    feed_command('highlight Whitespace guifg=#FF0000')
    feed_command('set cursorline')
    feed_command('set tabstop=8')
    feed_command('set nowrap')
    feed_command('set listchars=space:.,eol:¬,tab:>-,extends:>,precedes:<,trail:* list')
    feed('i\t abcd <cr>\t abcd Lorem ipsum dolor sit amet<cr><esc>kkk0')
    screen:expect([[
      {2:^>-------.}{1:abcd}{2:*}{3:¬}{1:     }|
      {5:>-------.}abcd{5:.}Lorem{4:>}|
      {4:¬}                   |
      {4:~                   }|
                          |
    ]])
    feed('lllvj')
    screen:expect([[
      {5:>-------.}a{6:bcd}{7:*}{8:¬}     |
      {7:>-------.}{6:a}^bcd{5:.}Lorem{4:>}|
      {4:¬}                   |
      {4:~                   }|
      -- VISUAL --        |
    ]])
    feed('<esc>V')
    screen:expect([[
      {5:>-------.}abcd{5:*}{4:¬}     |
      {7:>-------.}{6:a}^b{6:cd}{7:.}{6:Lorem}{4:>}|
      {4:¬}                   |
      {4:~                   }|
      -- VISUAL LINE --   |
    ]])
    feed('<esc>$')
    screen:expect([[
      {4:<}                   |
      {3:<}{1:r}{2:.}{1:sit}{2:.}{1:ame^t}{3:¬}{1:        }|
      {4:<}                   |
      {4:~                   }|
                          |
    ]])
  end)

  it("'cursorline' with :match", function()
    screen:set_default_attr_ids({
      [0] = {bold=true, foreground=Screen.colors.Blue},
      [1] = {background=Screen.colors.Grey90},
      [2] = {foreground=Screen.colors.Red},
      [3] = {foreground=Screen.colors.Green1},
    })
    feed_command('highlight clear ModeMsg')
    feed_command('highlight Whitespace guifg=#FF0000')
    feed_command('highlight Error guifg=#00FF00')
    feed_command('set nowrap')
    feed('ia \t bc \t  <esc>')
    screen:expect([[
      a        bc      ^   |
      {0:~                   }|
      {0:~                   }|
      {0:~                   }|
                          |
    ]])
    feed_command('set listchars=space:.,eol:¬,tab:>-,extends:>,precedes:<,trail:* list')
    screen:expect([[
      a{2:.>-----.}bc{2:*>---*^*}{0:¬} |
      {0:~                   }|
      {0:~                   }|
      {0:~                   }|
                          |
    ]])
    feed_command('match Error /\\s\\+$/')
    screen:expect([[
      a{2:.>-----.}bc{3:*>---*^*}{0:¬} |
      {0:~                   }|
      {0:~                   }|
      {0:~                   }|
                          |
    ]])
  end)
end)

describe('CursorLine highlight', function()
  before_each(clear)
  it('overridden by Error, ColorColumn if fg not set', function()
    local screen = Screen.new(50,5)
    screen:set_default_attr_ids({
      [1] = {foreground = Screen.colors.SlateBlue},
      [2] = {bold = true, foreground = Screen.colors.Brown},
      [3] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
      [4] = {foreground = Screen.colors.SlateBlue, background = Screen.colors.Gray90},
      [5] = {background = Screen.colors.Gray90},
      [6] = {bold = true, foreground = Screen.colors.Blue1},
      [7] = {background = Screen.colors.LightRed},
    })
    screen:attach()

    feed_command('filetype on')
    feed_command('syntax on')
    feed_command('set cursorline ft=json')
    feed('i{<cr>"a" : abc // 10;<cr>}<cr><esc>')
    screen:expect([[
      {1:{}                                                 |
      "{2:a}" : {3:abc} {3:// 10;}                                  |
      {1:}}                                                 |
      {5:^                                                  }|
                                                        |
    ]])

    feed_command('set colorcolumn=3')
    feed('i  <esc>')
    screen:expect([[
      {1:{} {7: }                                               |
      "{2:a}{7:"} : {3:abc} {3:// 10;}                                  |
      {1:}} {7: }                                               |
      {5: ^ }{7: }{5:                                               }|
                                                        |
    ]])
  end)
end)


describe("MsgSeparator highlight and msgsep fillchar", function()
  before_each(clear)
  it("works", function()
    local screen = Screen.new(50,5)
    screen:set_default_attr_ids({
      [1] = {bold=true, foreground=Screen.colors.Blue},
      [2] = {bold=true, reverse=true},
      [3] = {bold = true, foreground = Screen.colors.SeaGreen4},
      [4] = {background = Screen.colors.Cyan, bold = true, reverse = true},
      [5] = {bold = true, background = Screen.colors.Magenta}
    })
    screen:attach()

    -- defaults
    feed_command("ls")
    screen:expect([[
                                                        |
      {2:                                                  }|
      :ls                                               |
        1 %a   "[No Name]"                    line 1    |
      {3:Press ENTER or type command to continue}^           |
    ]])
    feed('<cr>')

    feed_command("set fillchars+=msgsep:-")
    feed_command("ls")
    screen:expect([[
                                                        |
      {2:--------------------------------------------------}|
      :ls                                               |
        1 %a   "[No Name]"                    line 1    |
      {3:Press ENTER or type command to continue}^           |
    ]])

    -- linked to StatusLine per default
    feed_command("hi StatusLine guibg=Cyan")
    feed_command("ls")
    screen:expect([[
                                                        |
      {4:--------------------------------------------------}|
      :ls                                               |
        1 %a   "[No Name]"                    line 1    |
      {3:Press ENTER or type command to continue}^           |
    ]])

    -- but can be unlinked
    feed_command("hi clear MsgSeparator")
    feed_command("hi MsgSeparator guibg=Magenta gui=bold")
    feed_command("ls")
    screen:expect([[
                                                        |
      {5:--------------------------------------------------}|
      :ls                                               |
        1 %a   "[No Name]"                    line 1    |
      {3:Press ENTER or type command to continue}^           |
    ]])

    -- when display doesn't contain msgsep, these options have no effect
    feed_command("set display-=msgsep")
    feed_command("ls")
    screen:expect([[
      {1:~                                                 }|
      {1:~                                                 }|
      :ls                                               |
        1 %a   "[No Name]"                    line 1    |
      {3:Press ENTER or type command to continue}^           |
    ]])
  end)
end)

describe("'winhighlight' highlight", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(20,8)
    screen:attach()
    screen:set_default_attr_ids({
      [0] = {bold=true, foreground=Screen.colors.Blue},
      [1] = {background = Screen.colors.DarkBlue},
      [2] = {background = Screen.colors.DarkBlue, bold = true, foreground = Screen.colors.Blue1},
      [3] = {bold = true, reverse = true},
      [4] = {reverse = true},
      [5] = {background = Screen.colors.DarkGreen},
      [6] = {background = Screen.colors.DarkGreen, bold = true, foreground = Screen.colors.Blue1},
      [7] = {background = Screen.colors.DarkMagenta},
      [8] = {background = Screen.colors.DarkMagenta, bold = true, foreground = Screen.colors.Blue1},
      [9] = {foreground = Screen.colors.Brown},
      [10] = {foreground = Screen.colors.Brown, background = Screen.colors.DarkBlue},
      [11] = {background = Screen.colors.DarkBlue, bold = true, reverse = true},
      [12] = {background = Screen.colors.DarkGreen, reverse = true},
      [13] = {background = Screen.colors.Magenta4, reverse = true},
      [14] = {background = Screen.colors.DarkBlue, reverse = true},
      [15] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
      [16] = {foreground = Screen.colors.Blue1},
      [17] = {background = Screen.colors.LightRed},
      [18] = {background = Screen.colors.Gray90},
      [19] = {foreground = Screen.colors.LightGrey, background = Screen.colors.DarkGray},
      [20] = {background = Screen.colors.LightGrey, underline = true},
      [21] = {bold = true},
      [22] = {bold = true, foreground = Screen.colors.SeaGreen4},
      [23] = {background = Screen.colors.LightMagenta},
      [24] = {background = Screen.colors.WebGray},
      [25] = {bold = true, foreground = Screen.colors.Green1},
      [26] = {background = Screen.colors.Red},
      [27] = {background = Screen.colors.DarkBlue, bold = true, foreground = Screen.colors.Green1},
    })
    command("hi Background1 guibg=DarkBlue")
    command("hi Background2 guibg=DarkGreen")
  end)

  it('works for background color', function()
    insert("aa")
    command("split")
    command("set winhl=Normal:Background1")
    screen:expect([[
      {1:a^a                  }|
      {2:~                   }|
      {2:~                   }|
      {3:[No Name] [+]       }|
      aa                  |
      {0:~                   }|
      {4:[No Name] [+]       }|
                          |
    ]])

    command("enew")
    screen:expect([[
      {1:^                    }|
      {2:~                   }|
      {2:~                   }|
      {3:[No Name]           }|
      aa                  |
      {0:~                   }|
      {4:[No Name] [+]       }|
                          |
    ]])
  end)

  it('handles invalid values', function()
    command("set winhl=Normal:Background1")
    screen:expect([[
      {1:^                    }|
      {2:~                   }|
      {2:~                   }|
      {2:~                   }|
      {2:~                   }|
      {2:~                   }|
      {2:~                   }|
                          |
    ]])

    eq('Vim(set):E474: Invalid argument: winhl=xxx:yyy',
       exc_exec("set winhl=xxx:yyy"))
    eq('Normal:Background1', eval('&winhl'))
    screen:expect([[
      {1:^                    }|
      {2:~                   }|
      {2:~                   }|
      {2:~                   }|
      {2:~                   }|
      {2:~                   }|
      {2:~                   }|
                          |
    ]])
  end)


  it('works local to the buffer', function()
    insert("aa")
    command("split")
    command("setlocal winhl=Normal:Background1")
    screen:expect([[
      {1:a^a                  }|
      {2:~                   }|
      {2:~                   }|
      {3:[No Name] [+]       }|
      aa                  |
      {0:~                   }|
      {4:[No Name] [+]       }|
                          |
    ]])

    command("enew")
    screen:expect([[
      ^                    |
      {0:~                   }|
      {0:~                   }|
      {3:[No Name]           }|
      aa                  |
      {0:~                   }|
      {4:[No Name] [+]       }|
                          |
    ]])

    command("bnext")
    screen:expect([[
      {1:^aa                  }|
      {2:~                   }|
      {2:~                   }|
      {3:[No Name] [+]       }|
      aa                  |
      {0:~                   }|
      {4:[No Name] [+]       }|
                          |
    ]])
  end)

  it('for inactive window background works', function()
    command("set winhl=Normal:Background1,NormalNC:Background2")
    -- tests global value is copied across split
    command("split")
    screen:expect([[
      {1:^                    }|
      {2:~                   }|
      {2:~                   }|
      {3:[No Name]           }|
      {5:                    }|
      {6:~                   }|
      {4:[No Name]           }|
                          |
    ]])

    feed("<c-w><c-w>")
    screen:expect([[
      {5:                    }|
      {6:~                   }|
      {6:~                   }|
      {4:[No Name]           }|
      {1:^                    }|
      {2:~                   }|
      {3:[No Name]           }|
                          |
    ]])

    feed("<c-w><c-w>")
    screen:expect([[
      {1:^                    }|
      {2:~                   }|
      {2:~                   }|
      {3:[No Name]           }|
      {5:                    }|
      {6:~                   }|
      {4:[No Name]           }|
                          |
    ]])
  end)

  it('works with NormalNC', function()
    command("hi NormalNC guibg=DarkMagenta")
    -- tests global value is copied across split
    command("split")
    screen:expect([[
      ^                    |
      {0:~                   }|
      {0:~                   }|
      {3:[No Name]           }|
      {7:                    }|
      {8:~                   }|
      {4:[No Name]           }|
                          |
    ]])

    command("wincmd w")
    screen:expect([[
      {7:                    }|
      {8:~                   }|
      {8:~                   }|
      {4:[No Name]           }|
      ^                    |
      {0:~                   }|
      {3:[No Name]           }|
                          |
    ]])


    -- winbg=Normal:... overrides global NormalNC
    command("set winhl=Normal:Background1")
    screen:expect([[
      {7:                    }|
      {8:~                   }|
      {8:~                   }|
      {4:[No Name]           }|
      {1:^                    }|
      {2:~                   }|
      {3:[No Name]           }|
                          |
    ]])

    command("wincmd w")
    screen:expect([[
      ^                    |
      {0:~                   }|
      {0:~                   }|
      {3:[No Name]           }|
      {1:                    }|
      {2:~                   }|
      {4:[No Name]           }|
                          |
    ]])

    command("wincmd w")
    command("set winhl=Normal:Background1,NormalNC:Background2")
    screen:expect([[
      {7:                    }|
      {8:~                   }|
      {8:~                   }|
      {4:[No Name]           }|
      {1:^                    }|
      {2:~                   }|
      {3:[No Name]           }|
                          |
    ]])

    command("wincmd w")
    screen:expect([[
      ^                    |
      {0:~                   }|
      {0:~                   }|
      {3:[No Name]           }|
      {5:                    }|
      {6:~                   }|
      {4:[No Name]           }|
                          |
    ]])
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
      {0:~                   }|
      {0:~                   }|
      {0:~                   }|
      {0:~                   }|
                          |
    ]])

    command('set winhl=Normal:Background1')
    screen:expect([[
      {10:  1 }{1:  ^Lorem ipsum do}|
      {10:    }{1:       }{2:↪}{1:lor sit }|
      {10:    }{1:       }{2:↪}{1:amet}{2:-}{1:   }|
      {2:~                   }|
      {2:~                   }|
      {2:~                   }|
      {2:~                   }|
                          |
    ]])

    command('set nowrap')
    command('set listchars+=extends:❯,precedes:❮')
    feed('3w')
    screen:expect([[
      {10:  1 }{2:❮}{1: dolor ^sit ame}{2:❯}|
      {2:~                   }|
      {2:~                   }|
      {2:~                   }|
      {2:~                   }|
      {2:~                   }|
      {2:~                   }|
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
      {0:~                   }|
      {0:~                   }|
      {0:~                   }|
      {0:~                   }|
      {0:~                   }|
                          |
    ]])

    -- winhl=Normal:Group with background doesn't override syntax background,
    -- but does combine with syntax foreground.
    command('set winhl=Normal:Background1')
    screen:expect([[
      {27:the}{1: }{26:foobar}{1: was }{26:fooba}|
      {26:^r}{1:                   }|
      {2:~                   }|
      {2:~                   }|
      {2:~                   }|
      {2:~                   }|
      {2:~                   }|
                          |
    ]])
  end)

  it('can override NonText, Conceal and EndOfBuffer', function()
    curbufmeths.set_lines(0,-1,true, {"raa\000"})
    command('call matchaddpos("Conceal", [[1,2]], 0, -1, {"conceal": "#"})')
    command('set cole=2 cocu=nvic')
    command('split')
    command('call matchaddpos("Conceal", [[1,2]], 0, -1, {"conceal": "#"})')
    command('set winhl=SpecialKey:ErrorMsg,EndOfBuffer:Background1,'
            ..'Conceal:Background2')

    screen:expect([[
      ^r{5:#}a{15:^@}               |
      {1:~                   }|
      {1:~                   }|
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

    command('split')
    command('set winhl=LineNr:Background1,CursorColumn:Background2,'
            ..'ColorColumn:ErrorMsg')
    screen:expect([[
      {1:  1 }v{15:e}ry tex{5:t}       |
      {1:  2 }m{15:o}re tex^t       |
      {0:~                   }|
      {3:[No Name] [+]       }|
      {9:  1 }v{17:e}ry tex{18:t}       |
      {9:  2 }m{17:o}re text       |
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
      {0:~                   }|
      {0:~                   }|
      {0:~                   }|
      {0:~                   }|
      {0:~                   }|
                          |
    ]])
    command("tabnext")
    screen:expect([[
      {21: No Name] }{1: No Name]}{20:X}|
      ^                    |
      {0:~                   }|
      {0:~                   }|
      {0:~                   }|
      {0:~                   }|
      {0:~                   }|
                          |
    ]])
  end)

  it('can override popupmenu', function()
    insert('word wording wordy')
    command('split')
    command('set winhl=Pmenu:Background1,PmenuSel:Background2,'
            ..'PmenuSbar:ErrorMsg,PmenuThumb:Normal')
    screen:expect([[
      word wording word^y  |
      {0:~                   }|
      {0:~                   }|
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
end)
