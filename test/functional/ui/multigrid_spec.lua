local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local feed, command, insert = n.feed, n.command, n.insert
local eq = t.eq
local fn = n.fn
local api = n.api
local curwin = n.api.nvim_get_current_win
local poke_eventloop = n.poke_eventloop


describe('ext_multigrid', function()
  local screen

  before_each(function()
    clear{args_rm={'--headless'}, args={'--cmd', 'set laststatus=2'}}
    screen = Screen.new(53,14, {ext_multigrid=true})
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue1},
      [2] = {foreground = Screen.colors.Magenta},
      [3] = {foreground = Screen.colors.Brown, bold = true},
      [4] = {foreground = Screen.colors.SlateBlue},
      [5] = {bold = true, foreground = Screen.colors.SlateBlue},
      [6] = {foreground = Screen.colors.Cyan4},
      [7] = {bold = true},
      [8] = {underline = true, bold = true, foreground = Screen.colors.SlateBlue},
      [9] = {foreground = Screen.colors.SlateBlue, underline = true},
      [10] = {foreground = Screen.colors.Red},
      [11] = {bold = true, reverse = true},
      [12] = {reverse = true},
      [13] = {foreground = Screen.colors.DarkBlue, background = Screen.colors.LightGrey},
      [14] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
      [15] = {bold = true, foreground = Screen.colors.SeaGreen4},
      [16] = {background = Screen.colors.LightGrey, underline = true},
      [17] = {background = Screen.colors.LightGrey, underline = true, bold = true, foreground = Screen.colors.Magenta},
      [18] = {bold = true, foreground = Screen.colors.Magenta},
      [19] = {foreground = Screen.colors.Brown},
      [20] = {background = Screen.colors.LightGrey, foreground = Screen.colors.Black},
      [21] = {background = Screen.colors.LightMagenta},
      [22] = {background = Screen.colors.LightMagenta, bold = true, foreground = Screen.colors.Blue},
      [23] = {background = Screen.colors.Grey90},
      [24] = {background = Screen.colors.Grey},
    })
  end)

  it('default initial screen', function()
    screen:expect{grid=[[
    ## grid 1
      [2:-----------------------------------------------------]|*12
      {11:[No Name]                                            }|
      [3:-----------------------------------------------------]|
    ## grid 2
      ^                                                     |
      {1:~                                                    }|*11
    ## grid 3
                                                           |
    ]]}
  end)

  it('positions windows correctly', function()
    command('vsplit')
    screen:expect{grid=[[
    ## grid 1
      [4:--------------------------]│[2:--------------------------]|*12
      {11:[No Name]                  }{12:[No Name]                 }|
      [3:-----------------------------------------------------]|
    ## grid 2
                                |
      {1:~                         }|*11
    ## grid 3
                                                           |
    ## grid 4
      ^                          |
      {1:~                         }|*11
    ]], condition=function()
      eq({
        [2] = { win = 1000, startrow = 0, startcol = 27, width = 26, height = 12 },
        [4] = { win = 1001, startrow = 0, startcol =  0, width = 26, height = 12 }
      }, screen.win_position)
    end}
    command('wincmd l')
    command('split')
    screen:expect{grid=[[
    ## grid 1
      [4:--------------------------]│[5:--------------------------]|*6
      [4:--------------------------]│{11:[No Name]                 }|
      [4:--------------------------]│[2:--------------------------]|*5
      {12:[No Name]                  [No Name]                 }|
      [3:-----------------------------------------------------]|
    ## grid 2
                                |
      {1:~                         }|*4
    ## grid 3
                                                           |
    ## grid 4
                                |
      {1:~                         }|*11
    ## grid 5
      ^                          |
      {1:~                         }|*5
    ]], condition=function()
      eq({
        [2] = { win = 1000, startrow = 7, startcol = 27, width = 26, height =  5 },
        [4] = { win = 1001, startrow = 0, startcol =  0, width = 26, height = 12 },
        [5] = { win = 1002, startrow = 0, startcol = 27, width = 26, height =  6 }
      }, screen.win_position)
    end}
    command('wincmd h')
    command('q')
    screen:expect{grid=[[
    ## grid 1
      [5:-----------------------------------------------------]|*6
      {11:[No Name]                                            }|
      [2:-----------------------------------------------------]|*5
      {12:[No Name]                                            }|
      [3:-----------------------------------------------------]|
    ## grid 2
                                                           |
      {1:~                                                    }|*4
    ## grid 3
                                                           |
    ## grid 5
      ^                                                     |
      {1:~                                                    }|*5
    ]], condition=function()
      eq({
        [2] = { win = 1000, startrow = 7, startcol = 0, width = 53, height =  5 },
        [5] = { win = 1002, startrow = 0, startcol = 0, width = 53, height =  6 }
      }, screen.win_position)
    end}
  end)

  describe('split', function ()
    describe('horizontally', function ()
      it('allocates grids', function ()
        command('sp')
        screen:expect([[
        ## grid 1
          [4:-----------------------------------------------------]|*6
          {11:[No Name]                                            }|
          [2:-----------------------------------------------------]|*5
          {12:[No Name]                                            }|
          [3:-----------------------------------------------------]|
        ## grid 2
                                                               |
          {1:~                                                    }|*4
        ## grid 3
                                                               |
        ## grid 4
          ^                                                     |
          {1:~                                                    }|*5
        ]])
      end)

      it('resizes grids', function ()
        command('sp')
        command('resize 8')
        screen:expect([[
        ## grid 1
          [4:-----------------------------------------------------]|*8
          {11:[No Name]                                            }|
          [2:-----------------------------------------------------]|*3
          {12:[No Name]                                            }|
          [3:-----------------------------------------------------]|
        ## grid 2
                                                               |
          {1:~                                                    }|*2
        ## grid 3
                                                               |
        ## grid 4
          ^                                                     |
          {1:~                                                    }|*7
        ]])
      end)

      it('splits vertically', function()
        command('sp')
        command('vsp')
        command('vsp')
        screen:expect{grid=[[
        ## grid 1
          [6:--------------------]│[5:----------------]│[4:---------------]|*6
          {11:[No Name]            }{12:[No Name]        [No Name]      }|
          [2:-----------------------------------------------------]|*5
          {12:[No Name]                                            }|
          [3:-----------------------------------------------------]|
        ## grid 2
                                                               |
          {1:~                                                    }|*4
        ## grid 3
                                                               |
        ## grid 4
                         |
          {1:~              }|*5
        ## grid 5
                          |
          {1:~               }|*5
        ## grid 6
          ^                    |
          {1:~                   }|*5
        ]]}
        insert('hello')
        screen:expect{grid=[[
        ## grid 1
          [6:--------------------]│[5:----------------]│[4:---------------]|*6
          {11:[No Name] [+]        }{12:[No Name] [+]    [No Name] [+]  }|
          [2:-----------------------------------------------------]|*5
          {12:[No Name] [+]                                        }|
          [3:-----------------------------------------------------]|
        ## grid 2
          hello                                                |
          {1:~                                                    }|*4
        ## grid 3
                                                               |
        ## grid 4
          hello          |
          {1:~              }|*5
        ## grid 5
          hello           |
          {1:~               }|*5
        ## grid 6
          hell^o               |
          {1:~                   }|*5
        ]]}
      end)
      it('closes splits', function ()
        command('sp')
        screen:expect{grid=[[
        ## grid 1
          [4:-----------------------------------------------------]|*6
          {11:[No Name]                                            }|
          [2:-----------------------------------------------------]|*5
          {12:[No Name]                                            }|
          [3:-----------------------------------------------------]|
        ## grid 2
                                                               |
          {1:~                                                    }|*4
        ## grid 3
                                                               |
        ## grid 4
          ^                                                     |
          {1:~                                                    }|*5
        ]]}
        command('q')
        screen:expect{grid=[[
        ## grid 1
          [2:-----------------------------------------------------]|*12
          {11:[No Name]                                            }|
          [3:-----------------------------------------------------]|
        ## grid 2
          ^                                                     |
          {1:~                                                    }|*11
        ## grid 3
                                                               |
        ]]}
      end)
    end)

    describe('vertically', function ()
      it('allocates grids', function ()
        command('vsp')
        screen:expect{grid=[[
        ## grid 1
          [4:--------------------------]│[2:--------------------------]|*12
          {11:[No Name]                  }{12:[No Name]                 }|
          [3:-----------------------------------------------------]|
        ## grid 2
                                    |
          {1:~                         }|*11
        ## grid 3
                                                               |
        ## grid 4
          ^                          |
          {1:~                         }|*11
        ]]}
      end)
      it('resizes grids', function ()
        command('vsp')
        command('vertical resize 10')
        screen:expect{grid=[[
        ## grid 1
          [4:----------]│[2:------------------------------------------]|*12
          {11:[No Name]  }{12:[No Name]                                 }|
          [3:-----------------------------------------------------]|
        ## grid 2
                                                    |
          {1:~                                         }|*11
        ## grid 3
                                                               |
        ## grid 4
          ^          |
          {1:~         }|*11
        ]]}
      end)
      it('splits horizontally', function ()
        command('vsp')
        command('sp')
        screen:expect{grid=[[
        ## grid 1
          [5:--------------------------]│[2:--------------------------]|*6
          {11:[No Name]                 }│[2:--------------------------]|
          [4:--------------------------]│[2:--------------------------]|*5
          {12:[No Name]                  [No Name]                 }|
          [3:-----------------------------------------------------]|
        ## grid 2
                                    |
          {1:~                         }|*11
        ## grid 3
                                                               |
        ## grid 4
                                    |
          {1:~                         }|*4
        ## grid 5
          ^                          |
          {1:~                         }|*5
        ]]}
        insert('hello')
        screen:expect{grid=[[
        ## grid 1
          [5:--------------------------]│[2:--------------------------]|*6
          {11:[No Name] [+]             }│[2:--------------------------]|
          [4:--------------------------]│[2:--------------------------]|*5
          {12:[No Name] [+]              [No Name] [+]             }|
          [3:-----------------------------------------------------]|
        ## grid 2
          hello                     |
          {1:~                         }|*11
        ## grid 3
                                                               |
        ## grid 4
          hello                     |
          {1:~                         }|*4
        ## grid 5
          hell^o                     |
          {1:~                         }|*5
        ]]}
      end)
      it('closes splits', function ()
        command('vsp')
        screen:expect{grid=[[
        ## grid 1
          [4:--------------------------]│[2:--------------------------]|*12
          {11:[No Name]                  }{12:[No Name]                 }|
          [3:-----------------------------------------------------]|
        ## grid 2
                                    |
          {1:~                         }|*11
        ## grid 3
                                                               |
        ## grid 4
          ^                          |
          {1:~                         }|*11
        ]]}
        command('q')
        screen:expect{grid=[[
        ## grid 1
          [2:-----------------------------------------------------]|*12
          {11:[No Name]                                            }|
          [3:-----------------------------------------------------]|
        ## grid 2
          ^                                                     |
          {1:~                                                    }|*11
        ## grid 3
                                                               |
        ]]}
      end)
    end)
  end)

  describe('on resize', function ()
    it('rebuilds all grids', function ()
      screen:try_resize(25, 6)
      screen:expect{grid=[[
      ## grid 1
        [2:-------------------------]|*4
        {11:[No Name]                }|
        [3:-------------------------]|
      ## grid 2
        ^                         |
        {1:~                        }|*3
      ## grid 3
                                 |
      ]]}
    end)

    it('has minimum width/height values', function()
      screen:try_resize(1, 1)
      screen:expect{grid=[[
      ## grid 1
        [2:------------]|
        {11:[No Name]   }|
        [3:------------]|
      ## grid 2
        ^            |
      ## grid 3
                    |
      ]]}

      feed('<esc>:ls')
      screen:expect{grid=[[
      ## grid 1
        [2:------------]|
        {11:[No Name]   }|
        [3:------------]|
      ## grid 2
                    |
      ## grid 3
        :ls^         |
      ]]}
    end)
  end)

  describe('grid of smaller inner size', function()
    before_each(function()
      screen:try_resize_grid(2, 20, 5)
    end)

    it('is rendered correctly', function()
      screen:expect{grid=[[
      ## grid 1
        [2:-----------------------------------------------------]|*12
        {11:[No Name]                                            }|
        [3:-----------------------------------------------------]|
      ## grid 2
        ^                    |
        {1:~                   }|*4
      ## grid 3
                                                             |
      ]]}
      screen:try_resize_grid(2, 8, 5)
      screen:expect{grid=[[
      ## grid 1
        [2:-----------------------------------------------------]|*12
        {11:[No Name]                                            }|
        [3:-----------------------------------------------------]|
      ## grid 2
        ^        |
        {1:~       }|*4
      ## grid 3
                                                             |
      ]]}
    end)

    it("cursor draws correctly with double-width char and 'showbreak'", function()
      insert(('a'):rep(19) .. '哦bbbb')
      command('setlocal showbreak=++')
      screen:expect{grid=[[
      ## grid 1
        [2:-----------------------------------------------------]|*12
        {11:[No Name] [+]                                        }|
        [3:-----------------------------------------------------]|
      ## grid 2
        aaaaaaaaaaaaaaaaaaa{1:>}|
        {1:++}哦bbb^b            |
        {1:~                   }|*3
      ## grid 3
                                                             |
      ]]}
    end)
  end)

  describe('grid of bigger inner size', function()
    before_each(function()
      screen:try_resize_grid(2, 60, 20)
    end)

    it('is rendered correctly', function()
      screen:expect{grid=[[
      ## grid 1
        [2:-----------------------------------------------------]|*12
        {11:[No Name]                                            }|
        [3:-----------------------------------------------------]|
      ## grid 2
        ^                                                            |
        {1:~                                                           }|*19
      ## grid 3
                                                             |
      ]]}
      screen:try_resize_grid(2, 80, 20)
      screen:expect{grid=[[
      ## grid 1
        [2:-----------------------------------------------------]|*12
        {11:[No Name]                                            }|
        [3:-----------------------------------------------------]|
      ## grid 2
        ^                                                                                |
        {1:~                                                                               }|*19
      ## grid 3
                                                             |
      ]]}
    end)

    it('winwidth() winheight() getwininfo() return inner width and height #19743', function()
      eq(60, fn.winwidth(0))
      eq(20, fn.winheight(0))
      local win_info = fn.getwininfo(curwin())[1]
      eq(60, win_info.width)
      eq(20, win_info.height)
    end)

    it("'scroll' option works properly", function()
      eq(10, api.nvim_get_option_value('scroll', { win = 0 }))
      api.nvim_set_option_value('scroll', 15, { win = 0 })
      eq(15, api.nvim_get_option_value('scroll', { win = 0 }))
    end)

    it('gets written till grid width', function()
      insert(('a'):rep(60).."\n")
      screen:expect{grid=[[
      ## grid 1
        [2:-----------------------------------------------------]|*12
        {11:[No Name] [+]                                        }|
        [3:-----------------------------------------------------]|
      ## grid 2
        aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
        ^                                                            |
        {1:~                                                           }|*18
      ## grid 3
                                                             |
      ]]}
    end)

    it('g$ works correctly with double-width chars and no wrapping', function()
      command('set nowrap')
      insert(('a'):rep(58) .. ('哦'):rep(3))
      feed('0')
      screen:expect{grid=[[
      ## grid 1
        [2:-----------------------------------------------------]|*12
        {11:[No Name] [+]                                        }|
        [3:-----------------------------------------------------]|
      ## grid 2
        ^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa哦|
        {1:~                                                           }|*19
      ## grid 3
                                                             |
      ]]}
      feed('g$')
      screen:expect{grid=[[
      ## grid 1
        [2:-----------------------------------------------------]|*12
        {11:[No Name] [+]                                        }|
        [3:-----------------------------------------------------]|
      ## grid 2
        aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa^哦|
        {1:~                                                           }|*19
      ## grid 3
                                                             |
      ]]}
    end)

    it('wraps with grid width', function()
      insert(('b'):rep(160).."\n")
      screen:expect{grid=[[
      ## grid 1
        [2:-----------------------------------------------------]|*12
        {11:[No Name] [+]                                        }|
        [3:-----------------------------------------------------]|
      ## grid 2
        bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb|*2
        bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb                    |
        ^                                                            |
        {1:~                                                           }|*16
      ## grid 3
                                                             |
      ]]}
      feed('2gk')
      command('setlocal cursorline cursorlineopt=screenline')
      screen:expect{grid=[[
      ## grid 1
        [2:-----------------------------------------------------]|*12
        {11:[No Name] [+]                                        }|
        [3:-----------------------------------------------------]|
      ## grid 2
        bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb|
        {23:^bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb}|
        bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb                    |
                                                                    |
        {1:~                                                           }|*16
      ## grid 3
                                                             |
      ]]}
      command('setlocal breakindent breakindentopt=shift:8')
      feed('g$')
      screen:expect{grid=[[
      ## grid 1
        [2:-----------------------------------------------------]|*12
        {11:[No Name] [+]                                        }|
        [3:-----------------------------------------------------]|
      ## grid 2
        bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb|
                {23:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb^b}|
                bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb    |
                                                                    |
        {1:~                                                           }|*16
      ## grid 3
                                                             |
      ]]}
    end)

    it('displays messages with default grid width', function()
      command('echomsg "this is a very very very very very very very very'..
        ' long message"')
      screen:expect{grid=[[
      ## grid 1
        [2:-----------------------------------------------------]|*12
        {11:[No Name]                                            }|
        [3:-----------------------------------------------------]|
      ## grid 2
        ^                                                            |
        {1:~                                                           }|*19
      ## grid 3
        this is a very very very...ry very very long message |
      ]]}
    end)

    it('creates folds with grid width', function()
      insert('this is a fold\nthis is inside fold\nthis is outside fold')
      feed('kzfgg')
      screen:expect{grid=[[
      ## grid 1
        [2:-----------------------------------------------------]|*12
        {11:[No Name] [+]                                        }|
        [3:-----------------------------------------------------]|
      ## grid 2
        {13:^+--  2 lines: this is a fold································}|
        this is outside fold                                        |
        {1:~                                                           }|*18
      ## grid 3
                                                             |
      ]]}
    end)

    it('anchored float window "bufpos"', function()
      insert(('c'):rep(1111))
      screen:expect{grid=[[
      ## grid 1
        [2:-----------------------------------------------------]|*12
        {11:[No Name] [+]                                        }|
        [3:-----------------------------------------------------]|
      ## grid 2
        cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc|*18
        cccccccccccccccccccccccccccccc^c                             |
        {1:~                                                           }|
      ## grid 3
                                                             |
      ]]}
      local float_buf = api.nvim_create_buf(false, false)
      api.nvim_open_win(float_buf, false, {
        relative = 'win',
        win = curwin(),
        bufpos = {0, 1018},
        anchor = 'SE',
        width = 5,
        height = 5,
      })
      screen:expect{grid=[[
      ## grid 1
        [2:-----------------------------------------------------]|*12
        {11:[No Name] [+]                                        }|
        [3:-----------------------------------------------------]|
      ## grid 2
        cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc|*18
        cccccccccccccccccccccccccccccc^c                             |
        {1:~                                                           }|
      ## grid 3
                                                             |
      ## grid 4
        {21:     }|
        {22:~    }|*4
      ]], float_pos={
        [4] = {1001, "SE", 2, 16, 58, true, 50, 1, 8, 48};
      }}
    end)

    it('completion popup position', function()
      insert(('\n'):rep(14) .. ('foo bar '):rep(7))
      feed('A<C-X><C-N>')
      screen:expect{grid=[[
      ## grid 1
        [2:-----------------------------------------------------]|*12
        {11:[No Name] [+]                                        }|
        [3:-----------------------------------------------------]|
      ## grid 2
                                                                    |*14
        foo bar foo bar foo bar foo bar foo bar foo bar foo bar foo^ |
        {1:~                                                           }|*5
      ## grid 3
        {7:-- Keyword Local completion (^N^P) }{15:match 1 of 2}      |
      ## grid 4
        {24: foo}|
        {21: bar}|
      ]], float_pos={
        [4] = {-1, "NW", 2, 15, 55, false, 100, 1, 15, 55};
      }}
      feed('<C-E><Esc>')

      command('setlocal rightleft')
      feed('o<C-X><C-N>')
      screen:expect{grid=[[
      ## grid 1
        [2:-----------------------------------------------------]|*12
        {11:[No Name] [+]                                        }|
        [3:-----------------------------------------------------]|
      ## grid 2
                                                                    |*14
             rab oof rab oof rab oof rab oof rab oof rab oof rab oof|
                                                                ^ oof|
        {1:                                                           ~}|*4
      ## grid 3
        {7:-- Keyword Local completion (^N^P) }{15:match 1 of 2}      |
      ## grid 4
        {24:            oof}|
        {21:            rab}|
      ]], float_pos={
        [4] = {-1, "NW", 2, 16, 45, false, 100, 1, 16, 45};
      }}
      feed('<C-E><Esc>')

      command('set wildoptions+=pum')
      feed(':sign un<Tab>')
      screen:expect{grid=[[
      ## grid 1
        [2:-----------------------------------------------------]|*12
        {11:[No Name] [+]                                        }|
        [3:-----------------------------------------------------]|
      ## grid 2
                                                                    |*14
             rab oof rab oof rab oof rab oof rab oof rab oof rab oof|
                                                                    |
        {1:                                                           ~}|*4
      ## grid 3
        :sign undefine^                                       |
      ## grid 4
        {24: undefine       }|
        {21: unplace        }|
      ]], float_pos={
        [4] = {-1, "SW", 1, 13, 5, false, 250, 2, 11, 5};
      }}
    end)

    it('half-page scrolling stops at end of buffer', function()
      command('set number')
      insert(('foobar\n'):rep(100))
      feed('7<C-Y>')
      screen:expect({
        grid = [[
        ## grid 1
          [2:-----------------------------------------------------]|*12
          {11:[No Name] [+]                                        }|
          [3:-----------------------------------------------------]|
        ## grid 2
          {19: 75 }foobar                                                  |
          {19: 76 }foobar                                                  |
          {19: 77 }foobar                                                  |
          {19: 78 }foobar                                                  |
          {19: 79 }foobar                                                  |
          {19: 80 }foobar                                                  |
          {19: 81 }foobar                                                  |
          {19: 82 }foobar                                                  |
          {19: 83 }foobar                                                  |
          {19: 84 }foobar                                                  |
          {19: 85 }foobar                                                  |
          {19: 86 }foobar                                                  |
          {19: 87 }foobar                                                  |
          {19: 88 }foobar                                                  |
          {19: 89 }foobar                                                  |
          {19: 90 }foobar                                                  |
          {19: 91 }foobar                                                  |
          {19: 92 }foobar                                                  |
          {19: 93 }foobar                                                  |
          {19: 94 }^foobar                                                  |
        ## grid 3
                                                               |
        ]],
      })
      feed('<C-D>')
      screen:expect({
        grid = [[
        ## grid 1
          [2:-----------------------------------------------------]|*12
          {11:[No Name] [+]                                        }|
          [3:-----------------------------------------------------]|
        ## grid 2
          {19: 82 }foobar                                                  |
          {19: 83 }foobar                                                  |
          {19: 84 }foobar                                                  |
          {19: 85 }foobar                                                  |
          {19: 86 }foobar                                                  |
          {19: 87 }foobar                                                  |
          {19: 88 }foobar                                                  |
          {19: 89 }foobar                                                  |
          {19: 90 }foobar                                                  |
          {19: 91 }foobar                                                  |
          {19: 92 }foobar                                                  |
          {19: 93 }foobar                                                  |
          {19: 94 }foobar                                                  |
          {19: 95 }foobar                                                  |
          {19: 96 }foobar                                                  |
          {19: 97 }foobar                                                  |
          {19: 98 }foobar                                                  |
          {19: 99 }foobar                                                  |
          {19:100 }foobar                                                  |
          {19:101 }^                                                        |
        ## grid 3
                                                               |
        ]],
      })
    end)
  end)

  it('multiline messages scroll over windows', function()
    command('sp')
    command('vsp')
    screen:expect{grid=[[
    ## grid 1
      [5:--------------------------]│[4:--------------------------]|*6
      {11:[No Name]                  }{12:[No Name]                 }|
      [2:-----------------------------------------------------]|*5
      {12:[No Name]                                            }|
      [3:-----------------------------------------------------]|
    ## grid 2
                                                           |
      {1:~                                                    }|*4
    ## grid 3
                                                           |
    ## grid 4
                                |
      {1:~                         }|*5
    ## grid 5
      ^                          |
      {1:~                         }|*5
    ]]}

    feed(":echoerr 'very' | echoerr 'much' | echoerr 'fail'<cr>")
    screen:expect{grid=[[
    ## grid 1
      [5:--------------------------]│[4:--------------------------]|*6
      {11:[No Name]                  }{12:[No Name]                 }|
      [2:-----------------------------------------------------]|*3
      [3:-----------------------------------------------------]|*4
    ## grid 2
                                                           |
      {1:~                                                    }|*4
    ## grid 3
      {14:very}                                                 |
      {14:much}                                                 |
      {14:fail}                                                 |
      {15:Press ENTER or type command to continue}^              |
    ## grid 4
                                |
      {1:~                         }|*5
    ## grid 5
                                |
      {1:~                         }|*5
    ]]}

    feed('<cr>')
    screen:expect{grid=[[
    ## grid 1
      [5:--------------------------]│[4:--------------------------]|*6
      {11:[No Name]                  }{12:[No Name]                 }|
      [2:-----------------------------------------------------]|*5
      {12:[No Name]                                            }|
      [3:-----------------------------------------------------]|
    ## grid 2
                                                           |
      {1:~                                                    }|*4
    ## grid 3
                                                           |
    ## grid 4
                                |
      {1:~                         }|*5
    ## grid 5
      ^                          |
      {1:~                         }|*5
    ]]}

    command([[
      func! ErrMsg()
        for i in range(11)
          echoerr "error ".i
        endfor
      endfunc]])
    feed(":call ErrMsg()<cr>")
    screen:expect{grid=[[
    ## grid 1
      [3:-----------------------------------------------------]|*14
    ## grid 2
                                                           |
      {1:~                                                    }|*4
    ## grid 3
      {14:Error detected while processing function ErrMsg:}     |
      {19:line    2:}                                           |
      {14:error 0}                                              |
      {14:error 1}                                              |
      {14:error 2}                                              |
      {14:error 3}                                              |
      {14:error 4}                                              |
      {14:error 5}                                              |
      {14:error 6}                                              |
      {14:error 7}                                              |
      {14:error 8}                                              |
      {14:error 9}                                              |
      {14:error 10}                                             |
      {15:Press ENTER or type command to continue}^              |
    ## grid 4
                                |
      {1:~                         }|*5
    ## grid 5
                                |
      {1:~                         }|*5
    ]]}

    feed("<c-c>")
    screen:expect{grid=[[
    ## grid 1
      [5:--------------------------]│[4:--------------------------]|*6
      {11:[No Name]                  }{12:[No Name]                 }|
      [2:-----------------------------------------------------]|*5
      {12:[No Name]                                            }|
      [3:-----------------------------------------------------]|
    ## grid 2
                                                           |
      {1:~                                                    }|*4
    ## grid 3
                                                           |
    ## grid 4
                                |
      {1:~                         }|*5
    ## grid 5
      ^                          |
      {1:~                         }|*5
    ]]}
  end)

  it('handles switch tabs', function()
    command('vsp')
    screen:expect{grid=[[
    ## grid 1
      [4:--------------------------]│[2:--------------------------]|*12
      {11:[No Name]                  }{12:[No Name]                 }|
      [3:-----------------------------------------------------]|
    ## grid 2
                                |
      {1:~                         }|*11
    ## grid 3
                                                           |
    ## grid 4
      ^                          |
      {1:~                         }|*11
    ]]}


    command('tabnew')
    -- note the old grids aren't resized yet
    screen:expect{grid=[[
    ## grid 1
      {16: }{17:2}{16: [No Name] }{7: [No Name] }{12:                            }{16:X}|
      [5:-----------------------------------------------------]|*11
      {11:[No Name]                                            }|
      [3:-----------------------------------------------------]|
    ## grid 2 (hidden)
                                |
      {1:~                         }|*11
    ## grid 3
                                                           |
    ## grid 4 (hidden)
                                |
      {1:~                         }|*11
    ## grid 5
      ^                                                     |
      {1:~                                                    }|*10
    ]]}

    command('sp')
    screen:expect{grid=[[
    ## grid 1
      {16: }{17:2}{16: [No Name] }{7: }{18:2}{7: [No Name] }{12:                          }{16:X}|
      [6:-----------------------------------------------------]|*5
      {11:[No Name]                                            }|
      [5:-----------------------------------------------------]|*5
      {12:[No Name]                                            }|
      [3:-----------------------------------------------------]|
    ## grid 2 (hidden)
                                |
      {1:~                         }|*11
    ## grid 3
                                                           |
    ## grid 4 (hidden)
                                |
      {1:~                         }|*11
    ## grid 5
                                                           |
      {1:~                                                    }|*4
    ## grid 6
      ^                                                     |
      {1:~                                                    }|*4
    ]]}

    command('tabnext')
    screen:expect{grid=[[
    ## grid 1
      {7: }{18:2}{7: [No Name] }{16: }{17:2}{16: [No Name] }{12:                          }{16:X}|
      [4:--------------------------]│[2:--------------------------]|*11
      {11:[No Name]                  }{12:[No Name]                 }|
      [3:-----------------------------------------------------]|
    ## grid 2
                                |
      {1:~                         }|*10
    ## grid 3
                                                           |
    ## grid 4
      ^                          |
      {1:~                         }|*10
    ## grid 5 (hidden)
                                                           |
      {1:~                                                    }|*4
    ## grid 6 (hidden)
                                                           |
      {1:~                                                    }|*4
    ]]}

    command('tabnext')
    screen:expect{grid=[[
    ## grid 1
      {16: }{17:2}{16: [No Name] }{7: }{18:2}{7: [No Name] }{12:                          }{16:X}|
      [6:-----------------------------------------------------]|*5
      {11:[No Name]                                            }|
      [5:-----------------------------------------------------]|*5
      {12:[No Name]                                            }|
      [3:-----------------------------------------------------]|
    ## grid 2 (hidden)
                                |
      {1:~                         }|*10
    ## grid 3
                                                           |
    ## grid 4 (hidden)
                                |
      {1:~                         }|*10
    ## grid 5
                                                           |
      {1:~                                                    }|*4
    ## grid 6
      ^                                                     |
      {1:~                                                    }|*4
    ]]}

    command('tabnext')
    command('$tabnew')
    screen:expect{grid=[[
    ## grid 1
      {16: }{17:2}{16: [No Name]  }{17:2}{16: [No Name] }{7: [No Name] }{12:               }{16:X}|
      [7:-----------------------------------------------------]|*11
      {11:[No Name]                                            }|
      [3:-----------------------------------------------------]|
    ## grid 2 (hidden)
                                |
      {1:~                         }|*10
    ## grid 3
                                                           |
    ## grid 4 (hidden)
                                |
      {1:~                         }|*10
    ## grid 5 (hidden)
                                                           |
      {1:~                                                    }|*4
    ## grid 6 (hidden)
                                                           |
      {1:~                                                    }|*4
    ## grid 7
      ^                                                     |
      {1:~                                                    }|*10
    ]]}

    command('tabclose')
    command('tabclose')
    screen:expect{grid=[[
    ## grid 1
      [4:--------------------------]│[2:--------------------------]|*12
      {11:[No Name]                  }{12:[No Name]                 }|
      [3:-----------------------------------------------------]|
    ## grid 2
                                |
      {1:~                         }|*11
    ## grid 3
                                                           |
    ## grid 4
      ^                          |
      {1:~                         }|*11
    ]]}
  end)

  it('supports mouse', function()
    command('autocmd! nvim.popupmenu') -- Delete the default MenuPopup event handler.
    insert('some text\nto be clicked')
    screen:expect{grid=[[
    ## grid 1
      [2:-----------------------------------------------------]|*12
      {11:[No Name] [+]                                        }|
      [3:-----------------------------------------------------]|
    ## grid 2
      some text                                            |
      to be clicke^d                                        |
      {1:~                                                    }|*10
    ## grid 3
                                                           |
    ]]}

    api.nvim_input_mouse('left', 'press', '', 2, 0, 5)
    screen:expect{grid=[[
    ## grid 1
      [2:-----------------------------------------------------]|*12
      {11:[No Name] [+]                                        }|
      [3:-----------------------------------------------------]|
    ## grid 2
      some ^text                                            |
      to be clicked                                        |
      {1:~                                                    }|*10
    ## grid 3
                                                           |
    ]]}

    feed(':new<cr>')
    insert('Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmo')

    screen:expect{grid=[[
    ## grid 1
      [4:-----------------------------------------------------]|*6
      {11:[No Name] [+]                                        }|
      [2:-----------------------------------------------------]|*5
      {12:[No Name] [+]                                        }|
      [3:-----------------------------------------------------]|
    ## grid 2
      some text                                            |
      to be clicked                                        |
      {1:~                                                    }|*3
    ## grid 3
                                                           |
    ## grid 4
      Lorem ipsum dolor sit amet, consectetur adipiscing el|
      it, sed do eiusm^o                                    |
      {1:~                                                    }|*4
    ]]}

    api.nvim_input_mouse('left', 'press', '', 2, 1, 6)
    screen:expect{grid=[[
    ## grid 1
      [4:-----------------------------------------------------]|*6
      {12:[No Name] [+]                                        }|
      [2:-----------------------------------------------------]|*5
      {11:[No Name] [+]                                        }|
      [3:-----------------------------------------------------]|
    ## grid 2
      some text                                            |
      to be ^clicked                                        |
      {1:~                                                    }|*3
    ## grid 3
                                                           |
    ## grid 4
      Lorem ipsum dolor sit amet, consectetur adipiscing el|
      it, sed do eiusmo                                    |
      {1:~                                                    }|*4
    ]]}

    api.nvim_input_mouse('left', 'press', '', 4, 1, 4)
    screen:expect{grid=[[
    ## grid 1
      [4:-----------------------------------------------------]|*6
      {11:[No Name] [+]                                        }|
      [2:-----------------------------------------------------]|*5
      {12:[No Name] [+]                                        }|
      [3:-----------------------------------------------------]|
    ## grid 2
      some text                                            |
      to be clicked                                        |
      {1:~                                                    }|*3
    ## grid 3
                                                           |
    ## grid 4
      Lorem ipsum dolor sit amet, consectetur adipiscing el|
      it, ^sed do eiusmo                                    |
      {1:~                                                    }|*4
    ]]}

    screen:try_resize_grid(4, 80, 2)
    screen:expect{grid=[[
    ## grid 1
      [4:-----------------------------------------------------]|*6
      {11:[No Name] [+]                                        }|
      [2:-----------------------------------------------------]|*5
      {12:[No Name] [+]                                        }|
      [3:-----------------------------------------------------]|
    ## grid 2
      some text                                            |
      to be clicked                                        |
      {1:~                                                    }|*3
    ## grid 3
                                                           |
    ## grid 4
      Lorem ipsum dolor sit amet, consectetur adipiscing elit, ^sed do eiusmo          |
      {1:~                                                                               }|
    ]]}

    api.nvim_input_mouse('left', 'press', '', 4, 0, 64)
    screen:expect{grid=[[
    ## grid 1
      [4:-----------------------------------------------------]|*6
      {11:[No Name] [+]                                        }|
      [2:-----------------------------------------------------]|*5
      {12:[No Name] [+]                                        }|
      [3:-----------------------------------------------------]|
    ## grid 2
      some text                                            |
      to be clicked                                        |
      {1:~                                                    }|*3
    ## grid 3
                                                           |
    ## grid 4
      Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do ^eiusmo          |
      {1:~                                                                               }|
    ]]}

    -- XXX: mouse_check_grid() doesn't work properly when clicking on grid 1
    api.nvim_input_mouse('left', 'press', '', 1, 6, 20)
    -- TODO(bfredl): "batching" input_mouse is formally not supported yet.
    -- Normally it should work fine in async context when nvim is not blocked,
    -- but add a poke_eventloop be sure.
    poke_eventloop()
    api.nvim_input_mouse('left', 'drag', '', 1, 4, 20)
    screen:expect{grid=[[
    ## grid 1
      [4:-----------------------------------------------------]|*4
      {11:[No Name] [+]                                        }|
      [2:-----------------------------------------------------]|*7
      {12:[No Name] [+]                                        }|
      [3:-----------------------------------------------------]|
    ## grid 2
      some text                                            |
      to be clicked                                        |
      {1:~                                                    }|*5
    ## grid 3
                                                           |
    ## grid 4
      Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do ^eiusmo          |
      {1:~                                                                               }|
    ]]}

    feed('<c-w><c-w><c-w>v')
    screen:expect{grid=[[
    ## grid 1
      [4:-----------------------------------------------------]|*4
      {12:[No Name] [+]                                        }|
      [5:--------------------------]│[2:--------------------------]|*7
      {11:[No Name] [+]              }{12:[No Name] [+]             }|
      [3:-----------------------------------------------------]|
    ## grid 2
      some text                 |
      to be clicked             |
      {1:~                         }|*5
    ## grid 3
                                                           |
    ## grid 4
      Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmo          |
      {1:~                                                                               }|
    ## grid 5
      some text                 |
      to be ^clicked             |
      {1:~                         }|*5
    ]]}

    api.nvim_input_mouse('left', 'press', '', 1, 8, 26)
    poke_eventloop()
    api.nvim_input_mouse('left', 'drag', '', 1, 6, 30)
    screen:expect{grid=[[
    ## grid 1
      [4:-----------------------------------------------------]|*4
      {12:[No Name] [+]                                        }|
      [5:------------------------------]│[2:----------------------]|*7
      {11:[No Name] [+]                  }{12:[No Name] [+]         }|
      [3:-----------------------------------------------------]|
    ## grid 2
      some text             |
      to be clicked         |
      {1:~                     }|*5
    ## grid 3
                                                           |
    ## grid 4
      Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmo          |
      {1:~                                                                               }|
    ## grid 5
      some text                     |
      to be ^clicked                 |
      {1:~                             }|*5
    ]]}

    command('aunmenu PopUp | vmenu PopUp.Copy y')

    fn.setreg('"', '')
    api.nvim_input_mouse('left', 'press', '2', 2, 1, 6)
    screen:expect{grid=[[
    ## grid 1
      [4:-----------------------------------------------------]|*4
      {12:[No Name] [+]                                        }|
      [5:------------------------------]│[2:----------------------]|*7
      {12:[No Name] [+]                  }{11:[No Name] [+]         }|
      [3:-----------------------------------------------------]|
    ## grid 2
      some text             |
      to be {20:clicke}^d         |
      {1:~                     }|*5
    ## grid 3
      {7:-- VISUAL --}                                         |
    ## grid 4
      Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmo          |
      {1:~                                                                               }|
    ## grid 5
      some text                     |
      to be {20:clicked}                 |
      {1:~                             }|*5
    ]]}
    api.nvim_input_mouse('right', 'press', '', 2, 1, 6)
    api.nvim_input_mouse('right', 'release', '', 2, 1, 6)
    screen:expect{grid=[[
    ## grid 1
      [4:-----------------------------------------------------]|*4
      {12:[No Name] [+]                                        }|
      [5:------------------------------]│[2:----------------------]|*7
      {12:[No Name] [+]                  }{11:[No Name] [+]         }|
      [3:-----------------------------------------------------]|
    ## grid 2
      some text             |
      to be {20:clicke}^d         |
      {1:~                     }|*5
    ## grid 3
      {7:-- VISUAL --}                                         |
    ## grid 4
      Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmo          |
      {1:~                                                                               }|
    ## grid 5
      some text                     |
      to be {20:clicked}                 |
      {1:~                             }|*5
    ## grid 6
      {21: Copy }|
    ]], float_pos={
      [6] = {-1, "NW", 2, 2, 5, false, 250, 2, 7, 36};
    }}
    feed('<Down><CR>')
    screen:expect{grid=[[
    ## grid 1
      [4:-----------------------------------------------------]|*4
      {12:[No Name] [+]                                        }|
      [5:------------------------------]│[2:----------------------]|*7
      {12:[No Name] [+]                  }{11:[No Name] [+]         }|
      [3:-----------------------------------------------------]|
    ## grid 2
      some text             |
      to be ^clicked         |
      {1:~                     }|*5
    ## grid 3
                                                           |
    ## grid 4
      Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmo          |
      {1:~                                                                               }|
    ## grid 5
      some text                     |
      to be clicked                 |
      {1:~                             }|*5
    ]]}
    eq('clicked', fn.getreg('"'))

    fn.setreg('"', '')
    api.nvim_input_mouse('left', 'press', '2', 4, 0, 64)
    screen:expect{grid=[[
    ## grid 1
      [4:-----------------------------------------------------]|*4
      {11:[No Name] [+]                                        }|
      [5:------------------------------]│[2:----------------------]|*7
      {12:[No Name] [+]                  [No Name] [+]         }|
      [3:-----------------------------------------------------]|
    ## grid 2
      some text             |
      to be clicked         |
      {1:~                     }|*5
    ## grid 3
      {7:-- VISUAL --}                                         |
    ## grid 4
      Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do {20:eiusm}^o          |
      {1:~                                                                               }|
    ## grid 5
      some text                     |
      to be clicked                 |
      {1:~                             }|*5
    ]]}
    api.nvim_input_mouse('right', 'press', '', 4, 0, 64)
    api.nvim_input_mouse('right', 'release', '', 4, 0, 64)
    screen:expect{grid=[[
    ## grid 1
      [4:-----------------------------------------------------]|*4
      {11:[No Name] [+]                                        }|
      [5:------------------------------]│[2:----------------------]|*7
      {12:[No Name] [+]                  [No Name] [+]         }|
      [3:-----------------------------------------------------]|
    ## grid 2
      some text             |
      to be clicked         |
      {1:~                     }|*5
    ## grid 3
      {7:-- VISUAL --}                                         |
    ## grid 4
      Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do {20:eiusm}^o          |
      {1:~                                                                               }|
    ## grid 5
      some text                     |
      to be clicked                 |
      {1:~                             }|*5
    ## grid 6
      {21: Copy }|
    ]], float_pos={
      [6] = {-1, "NW", 4, 1, 63, false, 250, 2, 1, 63};
    }}
    feed('<Down><CR>')
    screen:expect{grid=[[
    ## grid 1
      [4:-----------------------------------------------------]|*4
      {11:[No Name] [+]                                        }|
      [5:------------------------------]│[2:----------------------]|*7
      {12:[No Name] [+]                  [No Name] [+]         }|
      [3:-----------------------------------------------------]|
    ## grid 2
      some text             |
      to be clicked         |
      {1:~                     }|*5
    ## grid 3
                                                           |
    ## grid 4
      Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do ^eiusmo          |
      {1:~                                                                               }|
    ## grid 5
      some text                     |
      to be clicked                 |
      {1:~                             }|*5
    ]]}
    eq('eiusmo', fn.getreg('"'))

    command('wincmd J')
    screen:try_resize_grid(4, 7, 10)
    screen:expect{grid=[[
    ## grid 1
      [5:------------------------------]│[2:----------------------]|*5
      {12:[No Name] [+]                  [No Name] [+]         }|
      [4:-----------------------------------------------------]|*6
      {11:[No Name] [+]                                        }|
      [3:-----------------------------------------------------]|
    ## grid 2
      some text             |
      to be clicked         |
      {1:~                     }|*3
    ## grid 3
                                                           |
    ## grid 4
      Lorem i|
      psum do|
      lor sit|
       amet, |
      consect|
      etur ad|
      ipiscin|
      g elit,|
       sed do|
       ^eiusmo|
    ## grid 5
      some text                     |
      to be clicked                 |
      {1:~                             }|*3
    ]]}

    fn.setreg('"', '')
    api.nvim_input_mouse('left', 'press', '2', 4, 9, 1)
    screen:expect{grid=[[
    ## grid 1
      [5:------------------------------]│[2:----------------------]|*5
      {12:[No Name] [+]                  [No Name] [+]         }|
      [4:-----------------------------------------------------]|*6
      {11:[No Name] [+]                                        }|
      [3:-----------------------------------------------------]|
    ## grid 2
      some text             |
      to be clicked         |
      {1:~                     }|*3
    ## grid 3
      {7:-- VISUAL --}                                         |
    ## grid 4
      Lorem i|
      psum do|
      lor sit|
       amet, |
      consect|
      etur ad|
      ipiscin|
      g elit,|
       sed do|
       {20:eiusm}^o|
    ## grid 5
      some text                     |
      to be clicked                 |
      {1:~                             }|*3
    ]]}
    api.nvim_input_mouse('right', 'press', '', 4, 9, 1)
    api.nvim_input_mouse('right', 'release', '', 4, 9, 1)
    screen:expect{grid=[[
    ## grid 1
      [5:------------------------------]│[2:----------------------]|*5
      {12:[No Name] [+]                  [No Name] [+]         }|
      [4:-----------------------------------------------------]|*6
      {11:[No Name] [+]                                        }|
      [3:-----------------------------------------------------]|
    ## grid 2
      some text             |
      to be clicked         |
      {1:~                     }|*3
    ## grid 3
      {7:-- VISUAL --}                                         |
    ## grid 4
      Lorem i|
      psum do|
      lor sit|
       amet, |
      consect|
      etur ad|
      ipiscin|
      g elit,|
       sed do|
       {20:eiusm}^o|
    ## grid 5
      some text                     |
      to be clicked                 |
      {1:~                             }|*3
    ## grid 6
      {21: Copy }|
    ]], float_pos={
      [6] = {-1, "SW", 4, 9, 0, false, 250, 2, 14, 0};
    }}
    feed('<Down><CR>')
    screen:expect{grid=[[
    ## grid 1
      [5:------------------------------]│[2:----------------------]|*5
      {12:[No Name] [+]                  [No Name] [+]         }|
      [4:-----------------------------------------------------]|*6
      {11:[No Name] [+]                                        }|
      [3:-----------------------------------------------------]|
    ## grid 2
      some text             |
      to be clicked         |
      {1:~                     }|*3
    ## grid 3
                                                           |
    ## grid 4
      Lorem i|
      psum do|
      lor sit|
       amet, |
      consect|
      etur ad|
      ipiscin|
      g elit,|
       sed do|
       ^eiusmo|
    ## grid 5
      some text                     |
      to be clicked                 |
      {1:~                             }|*3
    ]]}
    eq('eiusmo', fn.getreg('"'))

    screen:try_resize_grid(4, 7, 11)
    screen:expect{grid=[[
    ## grid 1
      [5:------------------------------]│[2:----------------------]|*5
      {12:[No Name] [+]                  [No Name] [+]         }|
      [4:-----------------------------------------------------]|*6
      {11:[No Name] [+]                                        }|
      [3:-----------------------------------------------------]|
    ## grid 2
      some text             |
      to be clicked         |
      {1:~                     }|*3
    ## grid 3
                                                           |
    ## grid 4
      Lorem i|
      psum do|
      lor sit|
       amet, |
      consect|
      etur ad|
      ipiscin|
      g elit,|
       sed do|
       ^eiusmo|
      {1:~      }|
    ## grid 5
      some text                     |
      to be clicked                 |
      {1:~                             }|*3
    ]]}

    fn.setreg('"', '')
    api.nvim_input_mouse('left', 'press', '2', 4, 9, 1)
    screen:expect{grid=[[
    ## grid 1
      [5:------------------------------]│[2:----------------------]|*5
      {12:[No Name] [+]                  [No Name] [+]         }|
      [4:-----------------------------------------------------]|*6
      {11:[No Name] [+]                                        }|
      [3:-----------------------------------------------------]|
    ## grid 2
      some text             |
      to be clicked         |
      {1:~                     }|*3
    ## grid 3
      {7:-- VISUAL --}                                         |
    ## grid 4
      Lorem i|
      psum do|
      lor sit|
       amet, |
      consect|
      etur ad|
      ipiscin|
      g elit,|
       sed do|
       {20:eiusm}^o|
      {1:~      }|
    ## grid 5
      some text                     |
      to be clicked                 |
      {1:~                             }|*3
    ]]}
    api.nvim_input_mouse('right', 'press', '', 4, 9, 1)
    api.nvim_input_mouse('right', 'release', '', 4, 9, 1)
    screen:expect{grid=[[
    ## grid 1
      [5:------------------------------]│[2:----------------------]|*5
      {12:[No Name] [+]                  [No Name] [+]         }|
      [4:-----------------------------------------------------]|*6
      {11:[No Name] [+]                                        }|
      [3:-----------------------------------------------------]|
    ## grid 2
      some text             |
      to be clicked         |
      {1:~                     }|*3
    ## grid 3
      {7:-- VISUAL --}                                         |
    ## grid 4
      Lorem i|
      psum do|
      lor sit|
       amet, |
      consect|
      etur ad|
      ipiscin|
      g elit,|
       sed do|
       {20:eiusm}^o|
      {1:~      }|
    ## grid 5
      some text                     |
      to be clicked                 |
      {1:~                             }|*3
    ## grid 6
      {21: Copy }|
    ]], float_pos={
      [6] = {-1, "NW", 4, 10, 0, false, 250, 2, 16, 0};
    }}
    feed('<Down><CR>')
    screen:expect{grid=[[
    ## grid 1
      [5:------------------------------]│[2:----------------------]|*5
      {12:[No Name] [+]                  [No Name] [+]         }|
      [4:-----------------------------------------------------]|*6
      {11:[No Name] [+]                                        }|
      [3:-----------------------------------------------------]|
    ## grid 2
      some text             |
      to be clicked         |
      {1:~                     }|*3
    ## grid 3
                                                           |
    ## grid 4
      Lorem i|
      psum do|
      lor sit|
       amet, |
      consect|
      etur ad|
      ipiscin|
      g elit,|
       sed do|
       ^eiusmo|
      {1:~      }|
    ## grid 5
      some text                     |
      to be clicked                 |
      {1:~                             }|*3
    ]]}
    eq('eiusmo', fn.getreg('"'))
  end)

  it('supports mouse drag with mouse=a', function()
    command('set mouse=a')
    command('vsplit')
    command('wincmd l')
    command('split')
    command('enew')
    feed('ifoo\nbar<esc>')

    api.nvim_input_mouse('left', 'press', '', 5, 0, 0)
    poke_eventloop()
    api.nvim_input_mouse('left', 'drag', '', 5, 1, 2)

    screen:expect{grid=[[
    ## grid 1
      [4:--------------------------]│[5:--------------------------]|*6
      [4:--------------------------]│{11:[No Name] [+]             }|
      [4:--------------------------]│[2:--------------------------]|*5
      {12:[No Name]                  [No Name]                 }|
      [3:-----------------------------------------------------]|
    ## grid 2
                                |
      {1:~                         }|*4
    ## grid 3
      {7:-- VISUAL --}                                         |
    ## grid 4
                                |
      {1:~                         }|*11
    ## grid 5
      {20:foo}                       |
      {20:ba}^r                       |
      {1:~                         }|*4
    ]]}
  end)

  it('has viewport information', function()
    screen:try_resize(48, 8)
    screen:expect{grid=[[
    ## grid 1
      [2:------------------------------------------------]|*6
      {11:[No Name]                                       }|
      [3:------------------------------------------------]|
    ## grid 2
      ^                                                |
      {1:~                                               }|*5
    ## grid 3
                                                      |
    ]], win_viewport={
      [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0}
    }}
    insert([[
      Lorem ipsum dolor sit amet, consectetur
      adipisicing elit, sed do eiusmod tempor
      incididunt ut labore et dolore magna aliqua.
      Ut enim ad minim veniam, quis nostrud
      exercitation ullamco laboris nisi ut aliquip ex
      ea commodo consequat. Duis aute irure dolor in
      reprehenderit in voluptate velit esse cillum
      dolore eu fugiat nulla pariatur. Excepteur sint
      occaecat cupidatat non proident, sunt in culpa
      qui officia deserunt mollit anim id est
      laborum.]])

    screen:expect{grid=[[
    ## grid 1
      [2:------------------------------------------------]|*6
      {11:[No Name] [+]                                   }|
      [3:------------------------------------------------]|
    ## grid 2
      ea commodo consequat. Duis aute irure dolor in  |
      reprehenderit in voluptate velit esse cillum    |
      dolore eu fugiat nulla pariatur. Excepteur sint |
      occaecat cupidatat non proident, sunt in culpa  |
      qui officia deserunt mollit anim id est         |
      laborum^.                                        |
    ## grid 3
                                                      |
    ]], win_viewport={
      [2] = {win = 1000, topline = 5, botline = 11, curline = 10, curcol = 7, linecount = 11, sum_scroll_delta = 5},
    }}


    feed('<c-u>')
    screen:expect{grid=[[
    ## grid 1
      [2:------------------------------------------------]|*6
      {11:[No Name] [+]                                   }|
      [3:------------------------------------------------]|
    ## grid 2
      incididunt ut labore et dolore magna aliqua.    |
      Ut enim ad minim veniam, quis nostrud           |
      exercitation ullamco laboris nisi ut aliquip ex |
      ea commodo consequat. Duis aute irure dolor in  |
      reprehenderit in voluptate velit esse cillum    |
      ^dolore eu fugiat nulla pariatur. Excepteur sint |
    ## grid 3
                                                      |
    ]], win_viewport={
      [2] = {win = 1000, topline = 2, botline = 9, curline = 7, curcol = 0, linecount = 11, sum_scroll_delta = 2},
    }}

    command("split")
    screen:expect{grid=[[
    ## grid 1
      [4:------------------------------------------------]|*3
      {11:[No Name] [+]                                   }|
      [2:------------------------------------------------]|*2
      {12:[No Name] [+]                                   }|
      [3:------------------------------------------------]|
    ## grid 2
      reprehenderit in voluptate velit esse cillum    |
      dolore eu fugiat nulla pariatur. Excepteur sint |
    ## grid 3
                                                      |
    ## grid 4
      ea commodo consequat. Duis aute irure dolor in  |
      reprehenderit in voluptate velit esse cillum    |
      ^dolore eu fugiat nulla pariatur. Excepteur sint |
    ]], win_viewport={
      [2] = {win = 1000, topline = 6, botline = 9, curline = 7, curcol = 0, linecount = 11, sum_scroll_delta = 6},
      [4] = {win = 1001, topline = 5, botline = 9, curline = 7, curcol = 0, linecount = 11, sum_scroll_delta = 5},
    }}

    feed("b")
    screen:expect{grid=[[
    ## grid 1
      [4:------------------------------------------------]|*3
      {11:[No Name] [+]                                   }|
      [2:------------------------------------------------]|*2
      {12:[No Name] [+]                                   }|
      [3:------------------------------------------------]|
    ## grid 2
      reprehenderit in voluptate velit esse cillum    |
      dolore eu fugiat nulla pariatur. Excepteur sint |
    ## grid 3
                                                      |
    ## grid 4
      ea commodo consequat. Duis aute irure dolor in  |
      reprehenderit in voluptate velit esse ^cillum    |
      dolore eu fugiat nulla pariatur. Excepteur sint |
    ]], win_viewport={
      [2] = {win = 1000, topline = 6, botline = 9, curline = 7, curcol = 0, linecount = 11, sum_scroll_delta = 6},
      [4] = {win = 1001, topline = 5, botline = 9, curline = 6, curcol = 38, linecount = 11, sum_scroll_delta = 5},
    }}

    feed("2k")
    screen:expect{grid=[[
    ## grid 1
      [4:------------------------------------------------]|*3
      {11:[No Name] [+]                                   }|
      [2:------------------------------------------------]|*2
      {12:[No Name] [+]                                   }|
      [3:------------------------------------------------]|
    ## grid 2
      reprehenderit in voluptate velit esse cillum    |
      dolore eu fugiat nulla pariatur. Excepteur sint |
    ## grid 3
                                                      |
    ## grid 4
      exercitation ullamco laboris nisi ut a^liquip ex |
      ea commodo consequat. Duis aute irure dolor in  |
      reprehenderit in voluptate velit esse cillum    |
    ]], win_viewport={
      [2] = {win = 1000, topline = 6, botline = 9, curline = 7, curcol = 0, linecount = 11, sum_scroll_delta = 6},
      [4] = {win = 1001, topline = 4, botline = 8, curline = 4, curcol = 38, linecount = 11, sum_scroll_delta = 4},
    }}

    -- handles non-current window
    api.nvim_win_set_cursor(1000, {1, 10})
    screen:expect{grid=[[
    ## grid 1
      [4:------------------------------------------------]|*3
      {11:[No Name] [+]                                   }|
      [2:------------------------------------------------]|*2
      {12:[No Name] [+]                                   }|
      [3:------------------------------------------------]|
    ## grid 2
      Lorem ipsum dolor sit amet, consectetur         |
      adipisicing elit, sed do eiusmod tempor         |
    ## grid 3
                                                      |
    ## grid 4
      exercitation ullamco laboris nisi ut a^liquip ex |
      ea commodo consequat. Duis aute irure dolor in  |
      reprehenderit in voluptate velit esse cillum    |
    ]], win_viewport={
      [2] = {win = 1000, topline = 0, botline = 3, curline = 0, curcol = 10, linecount = 11, sum_scroll_delta = 0},
      [4] = {win = 1001, topline = 4, botline = 8, curline = 4, curcol = 38, linecount = 11, sum_scroll_delta = 4},
    }}

    -- sum_scroll_delta works with folds
    feed('zfj')
    screen:expect{grid=[[
    ## grid 1
      [4:------------------------------------------------]|*3
      {11:[No Name] [+]                                   }|
      [2:------------------------------------------------]|*2
      {12:[No Name] [+]                                   }|
      [3:------------------------------------------------]|
    ## grid 2
      Lorem ipsum dolor sit amet, consectetur         |
      adipisicing elit, sed do eiusmod tempor         |
    ## grid 3
                                                      |
    ## grid 4
      {13:^+--  2 lines: exercitation ullamco laboris nisi }|
      reprehenderit in voluptate velit esse cillum    |
      dolore eu fugiat nulla pariatur. Excepteur sint |
    ]], win_viewport={
      [2] = {win = 1000, topline = 0, botline = 3, curline = 0, curcol = 10, linecount = 11, sum_scroll_delta = 0},
      [4] = {win = 1001, topline = 4, botline = 9, curline = 4, curcol = 38, linecount = 11, sum_scroll_delta = 4},
    }}

    feed('<c-e>')
    screen:expect{grid=[[
    ## grid 1
      [4:------------------------------------------------]|*3
      {11:[No Name] [+]                                   }|
      [2:------------------------------------------------]|*2
      {12:[No Name] [+]                                   }|
      [3:------------------------------------------------]|
    ## grid 2
      Lorem ipsum dolor sit amet, consectetur         |
      adipisicing elit, sed do eiusmod tempor         |
    ## grid 3
                                                      |
    ## grid 4
      ^reprehenderit in voluptate velit esse cillum    |
      dolore eu fugiat nulla pariatur. Excepteur sint |
      occaecat cupidatat non proident, sunt in culpa  |
    ]], win_viewport={
      [2] = {win = 1000, topline = 0, botline = 3, curline = 0, curcol = 10, linecount = 11, sum_scroll_delta = 0},
      [4] = {win = 1001, topline = 6, botline = 10, curline = 6, curcol = 0, linecount = 11, sum_scroll_delta = 5},
    }}

    command('close | 21vsplit | setlocal number smoothscroll')
    screen:expect{grid=[[
    ## grid 1
      [5:---------------------]│[2:--------------------------]|*6
      {11:[No Name] [+]         }{12:[No Name] [+]             }|
      [3:------------------------------------------------]|
    ## grid 2
      Lorem ipsum dolor sit amet|
      , consectetur             |
      adipisicing elit, sed do e|
      iusmod tempor             |
      incididunt ut labore et do|
      lore magna aliqua.        |
    ## grid 3
                                                      |
    ## grid 5
      {19:  1 }Lorem ipsu^m dolor|
      {19:    } sit amet, consec|
      {19:    }tetur            |
      {19:  2 }adipisicing elit,|
      {19:    } sed do eiusmod t|
      {19:    }empor            |
    ]], win_viewport={
      [2] = {win = 1000, topline = 0, botline = 4, curline = 0, curcol = 10, linecount = 11, sum_scroll_delta = 0};
      [5] = {win = 1002, topline = 0, botline = 3, curline = 0, curcol = 10, linecount = 11, sum_scroll_delta = 0};
    }}

    feed('5<C-E>')
    screen:expect{grid=[[
    ## grid 1
      [5:---------------------]│[2:--------------------------]|*6
      {11:[No Name] [+]         }{12:[No Name] [+]             }|
      [3:------------------------------------------------]|
    ## grid 2
      Lorem ipsum dolor sit amet|
      , consectetur             |
      adipisicing elit, sed do e|
      iusmod tempor             |
      incididunt ut labore et do|
      lore magna aliqua.        |
    ## grid 3
                                                      |
    ## grid 5
      {1:<<<}{19: }empo^r            |
      {19:  3 }incididunt ut lab|
      {19:    }ore et dolore mag|
      {19:    }na aliqua.       |
      {19:  4 }Ut enim ad minim |
      {19:    }veniam, quis n{1:@@@}|
    ]], win_viewport={
      [2] = {win = 1000, topline = 0, botline = 4, curline = 0, curcol = 10, linecount = 11, sum_scroll_delta = 0};
      [5] = {win = 1002, topline = 1, botline = 4, curline = 1, curcol = 38, linecount = 11, sum_scroll_delta = 5};
    }}

    feed('<C-Y>')
    screen:expect{grid=[[
    ## grid 1
      [5:---------------------]│[2:--------------------------]|*6
      {11:[No Name] [+]         }{12:[No Name] [+]             }|
      [3:------------------------------------------------]|
    ## grid 2
      Lorem ipsum dolor sit amet|
      , consectetur             |
      adipisicing elit, sed do e|
      iusmod tempor             |
      incididunt ut labore et do|
      lore magna aliqua.        |
    ## grid 3
                                                      |
    ## grid 5
      {1:<<<}{19: } sed do eiusmod t|
      {19:    }empo^r            |
      {19:  3 }incididunt ut lab|
      {19:    }ore et dolore mag|
      {19:    }na aliqua.       |
      {19:  4 }Ut enim ad min{1:@@@}|
    ]], win_viewport={
      [2] = {win = 1000, topline = 0, botline = 4, curline = 0, curcol = 10, linecount = 11, sum_scroll_delta = 0};
      [5] = {win = 1002, topline = 1, botline = 4, curline = 1, curcol = 38, linecount = 11, sum_scroll_delta = 4};
    }}

    command('set cpoptions+=n')
    screen:expect{grid=[[
    ## grid 1
      [5:---------------------]│[2:--------------------------]|*6
      {11:[No Name] [+]         }{12:[No Name] [+]             }|
      [3:------------------------------------------------]|
    ## grid 2
      Lorem ipsum dolor sit amet|
      , consectetur             |
      adipisicing elit, sed do e|
      iusmod tempor             |
      incididunt ut labore et do|
      lore magna aliqua.        |
    ## grid 3
                                                      |
    ## grid 5
      {1:<<<}d do eiusmod tempo|
      ^r                    |
      {19:  3 }incididunt ut lab|
      ore et dolore magna a|
      liqua.               |
      {19:  4 }Ut enim ad min{1:@@@}|
    ]], win_viewport={
      [2] = {win = 1000, topline = 0, botline = 4, curline = 0, curcol = 10, linecount = 11, sum_scroll_delta = 0};
      [5] = {win = 1002, topline = 1, botline = 4, curline = 1, curcol = 38, linecount = 11, sum_scroll_delta = 4};
    }}

    feed('4<C-E>')
    screen:expect{grid=[[
    ## grid 1
      [5:---------------------]│[2:--------------------------]|*6
      {11:[No Name] [+]         }{12:[No Name] [+]             }|
      [3:------------------------------------------------]|
    ## grid 2
      Lorem ipsum dolor sit amet|
      , consectetur             |
      adipisicing elit, sed do e|
      iusmod tempor             |
      incididunt ut labore et do|
      lore magna aliqua.        |
    ## grid 3
                                                      |
    ## grid 5
      {1:<<<}ua^.               |
      {19:  4 }Ut enim ad minim |
      veniam, quis nostrud |
      {19:  5 }exercitation ulla|
      mco laboris nisi ut a|
      liquip ex            |
    ]], win_viewport={
      [2] = {win = 1000, topline = 0, botline = 4, curline = 0, curcol = 10, linecount = 11, sum_scroll_delta = 0};
      [5] = {win = 1002, topline = 2, botline = 6, curline = 2, curcol = 43, linecount = 11, sum_scroll_delta = 8};
    }}

    feed('2<C-Y>')
    screen:expect{grid=[[
    ## grid 1
      [5:---------------------]│[2:--------------------------]|*6
      {11:[No Name] [+]         }{12:[No Name] [+]             }|
      [3:------------------------------------------------]|
    ## grid 2
      Lorem ipsum dolor sit amet|
      , consectetur             |
      adipisicing elit, sed do e|
      iusmod tempor             |
      incididunt ut labore et do|
      lore magna aliqua.        |
    ## grid 3
                                                      |
    ## grid 5
      {19:  3 }incididunt ut lab|
      ore et dolore magna a|
      liqua^.               |
      {19:  4 }Ut enim ad minim |
      veniam, quis nostrud |
      {19:  5 }exercitation u{1:@@@}|
    ]], win_viewport={
      [2] = {win = 1000, topline = 0, botline = 4, curline = 0, curcol = 10, linecount = 11, sum_scroll_delta = 0};
      [5] = {win = 1002, topline = 2, botline = 5, curline = 2, curcol = 43, linecount = 11, sum_scroll_delta = 6};
    }}

    command('setlocal numberwidth=12')
    screen:expect{grid=[[
    ## grid 1
      [5:---------------------]│[2:--------------------------]|*6
      {11:[No Name] [+]         }{12:[No Name] [+]             }|
      [3:------------------------------------------------]|
    ## grid 2
      Lorem ipsum dolor sit amet|
      , consectetur             |
      adipisicing elit, sed do e|
      iusmod tempor             |
      incididunt ut labore et do|
      lore magna aliqua.        |
    ## grid 3
                                                      |
    ## grid 5
      {19:          3 }incididun|
      t ut labore et dolore|
       magna aliqua^.       |
      {19:          4 }Ut enim a|
      d minim veniam, quis |
      nostrud              |
    ]], win_viewport={
      [2] = {win = 1000, topline = 0, botline = 4, curline = 0, curcol = 10, linecount = 11, sum_scroll_delta = 0};
      [5] = {win = 1002, topline = 2, botline = 5, curline = 2, curcol = 43, linecount = 11, sum_scroll_delta = 6};
    }}

    feed('2<C-E>')
    screen:expect{grid=[[
    ## grid 1
      [5:---------------------]│[2:--------------------------]|*6
      {11:[No Name] [+]         }{12:[No Name] [+]             }|
      [3:------------------------------------------------]|
    ## grid 2
      Lorem ipsum dolor sit amet|
      , consectetur             |
      adipisicing elit, sed do e|
      iusmod tempor             |
      incididunt ut labore et do|
      lore magna aliqua.        |
    ## grid 3
                                                      |
    ## grid 5
      {1:<<<}gna aliqua^.       |
      {19:          4 }Ut enim a|
      d minim veniam, quis |
      nostrud              |
      {19:          5 }exercitat|
      ion ullamco labori{1:@@@}|
    ]], win_viewport={
      [2] = {win = 1000, topline = 0, botline = 4, curline = 0, curcol = 10, linecount = 11, sum_scroll_delta = 0};
      [5] = {win = 1002, topline = 2, botline = 5, curline = 2, curcol = 43, linecount = 11, sum_scroll_delta = 8};
    }}

    feed('<C-E>')
    screen:expect{grid=[[
    ## grid 1
      [5:---------------------]│[2:--------------------------]|*6
      {11:[No Name] [+]         }{12:[No Name] [+]             }|
      [3:------------------------------------------------]|
    ## grid 2
      Lorem ipsum dolor sit amet|
      , consectetur             |
      adipisicing elit, sed do e|
      iusmod tempor             |
      incididunt ut labore et do|
      lore magna aliqua.        |
    ## grid 3
                                                      |
    ## grid 5
      {19:          4 }Ut enim a|
      d minim veniam, quis |
      nostru^d              |
      {19:          5 }exercitat|
      ion ullamco laboris n|
      isi ut aliquip ex    |
    ]], win_viewport={
      [2] = {win = 1000, topline = 0, botline = 4, curline = 0, curcol = 10, linecount = 11, sum_scroll_delta = 0};
      [5] = {win = 1002, topline = 3, botline = 6, curline = 3, curcol = 36, linecount = 11, sum_scroll_delta = 9};
    }}
  end)

  it('scroll_delta is approximated reasonably when scrolling many lines #24234', function()
    command('setlocal number nowrap')
    command('edit test/functional/fixtures/bigfile.txt')
    screen:expect{grid=[[
    ## grid 1
      [2:-----------------------------------------------------]|*12
      {11:test/functional/fixtures/bigfile.txt                 }|
      [3:-----------------------------------------------------]|
    ## grid 2
      {19:    1 }^0000;<control>;Cc;0;BN;;;;;N;NULL;;;;          |
      {19:    2 }0001;<control>;Cc;0;BN;;;;;N;START OF HEADING;;|
      {19:    3 }0002;<control>;Cc;0;BN;;;;;N;START OF TEXT;;;; |
      {19:    4 }0003;<control>;Cc;0;BN;;;;;N;END OF TEXT;;;;   |
      {19:    5 }0004;<control>;Cc;0;BN;;;;;N;END OF TRANSMISSIO|
      {19:    6 }0005;<control>;Cc;0;BN;;;;;N;ENQUIRY;;;;       |
      {19:    7 }0006;<control>;Cc;0;BN;;;;;N;ACKNOWLEDGE;;;;   |
      {19:    8 }0007;<control>;Cc;0;BN;;;;;N;BELL;;;;          |
      {19:    9 }0008;<control>;Cc;0;BN;;;;;N;BACKSPACE;;;;     |
      {19:   10 }0009;<control>;Cc;0;S;;;;;N;CHARACTER TABULATIO|
      {19:   11 }000A;<control>;Cc;0;B;;;;;N;LINE FEED (LF);;;; |
      {19:   12 }000B;<control>;Cc;0;S;;;;;N;LINE TABULATION;;;;|
    ## grid 3
                                                           |
    ]], win_viewport={
      [2] = {win = 1000, topline = 0, botline = 13, curline = 0, curcol = 0, linecount = 30592, sum_scroll_delta = 0};
    }}
    feed('G')
    screen:expect{grid=[[
    ## grid 1
      [2:-----------------------------------------------------]|*12
      {11:test/functional/fixtures/bigfile.txt                 }|
      [3:-----------------------------------------------------]|
    ## grid 2
      {19:30581 }E01E8;VARIATION SELECTOR-249;Mn;0;NSM;;;;;N;;;;|
      {19:30582 }E01E9;VARIATION SELECTOR-250;Mn;0;NSM;;;;;N;;;;|
      {19:30583 }E01EA;VARIATION SELECTOR-251;Mn;0;NSM;;;;;N;;;;|
      {19:30584 }E01EB;VARIATION SELECTOR-252;Mn;0;NSM;;;;;N;;;;|
      {19:30585 }E01EC;VARIATION SELECTOR-253;Mn;0;NSM;;;;;N;;;;|
      {19:30586 }E01ED;VARIATION SELECTOR-254;Mn;0;NSM;;;;;N;;;;|
      {19:30587 }E01EE;VARIATION SELECTOR-255;Mn;0;NSM;;;;;N;;;;|
      {19:30588 }E01EF;VARIATION SELECTOR-256;Mn;0;NSM;;;;;N;;;;|
      {19:30589 }F0000;<Plane 15 Private Use, First>;Co;0;L;;;;;|
      {19:30590 }FFFFD;<Plane 15 Private Use, Last>;Co;0;L;;;;;N|
      {19:30591 }100000;<Plane 16 Private Use, First>;Co;0;L;;;;|
      {19:30592 }^10FFFD;<Plane 16 Private Use, Last>;Co;0;L;;;;;|
    ## grid 3
                                                           |
    ]], win_viewport={
      [2] = {win = 1000, topline = 30580, botline = 30592, curline = 30591, curcol = 0, linecount = 30592, sum_scroll_delta = 30580};
    }}
    feed('gg')
    screen:expect{grid=[[
    ## grid 1
      [2:-----------------------------------------------------]|*12
      {11:test/functional/fixtures/bigfile.txt                 }|
      [3:-----------------------------------------------------]|
    ## grid 2
      {19:    1 }^0000;<control>;Cc;0;BN;;;;;N;NULL;;;;          |
      {19:    2 }0001;<control>;Cc;0;BN;;;;;N;START OF HEADING;;|
      {19:    3 }0002;<control>;Cc;0;BN;;;;;N;START OF TEXT;;;; |
      {19:    4 }0003;<control>;Cc;0;BN;;;;;N;END OF TEXT;;;;   |
      {19:    5 }0004;<control>;Cc;0;BN;;;;;N;END OF TRANSMISSIO|
      {19:    6 }0005;<control>;Cc;0;BN;;;;;N;ENQUIRY;;;;       |
      {19:    7 }0006;<control>;Cc;0;BN;;;;;N;ACKNOWLEDGE;;;;   |
      {19:    8 }0007;<control>;Cc;0;BN;;;;;N;BELL;;;;          |
      {19:    9 }0008;<control>;Cc;0;BN;;;;;N;BACKSPACE;;;;     |
      {19:   10 }0009;<control>;Cc;0;S;;;;;N;CHARACTER TABULATIO|
      {19:   11 }000A;<control>;Cc;0;B;;;;;N;LINE FEED (LF);;;; |
      {19:   12 }000B;<control>;Cc;0;S;;;;;N;LINE TABULATION;;;;|
    ## grid 3
                                                           |
    ]], win_viewport={
      [2] = {win = 1000, topline = 0, botline = 13, curline = 0, curcol = 0, linecount = 30592, sum_scroll_delta = 0};
    }}
    command('setlocal wrap')
    screen:expect{grid=[[
    ## grid 1
      [2:-----------------------------------------------------]|*12
      {11:test/functional/fixtures/bigfile.txt                 }|
      [3:-----------------------------------------------------]|
    ## grid 2
      {19:    1 }^0000;<control>;Cc;0;BN;;;;;N;NULL;;;;          |
      {19:    2 }0001;<control>;Cc;0;BN;;;;;N;START OF HEADING;;|
      {19:      };;                                             |
      {19:    3 }0002;<control>;Cc;0;BN;;;;;N;START OF TEXT;;;; |
      {19:    4 }0003;<control>;Cc;0;BN;;;;;N;END OF TEXT;;;;   |
      {19:    5 }0004;<control>;Cc;0;BN;;;;;N;END OF TRANSMISSIO|
      {19:      }N;;;;                                          |
      {19:    6 }0005;<control>;Cc;0;BN;;;;;N;ENQUIRY;;;;       |
      {19:    7 }0006;<control>;Cc;0;BN;;;;;N;ACKNOWLEDGE;;;;   |
      {19:    8 }0007;<control>;Cc;0;BN;;;;;N;BELL;;;;          |
      {19:    9 }0008;<control>;Cc;0;BN;;;;;N;BACKSPACE;;;;     |
      {19:   10 }0009;<control>;Cc;0;S;;;;;N;CHARACTER TABULA{1:@@@}|
    ## grid 3
                                                           |
    ]], win_viewport={
      [2] = {win = 1000, topline = 0, botline = 10, curline = 0, curcol = 0, linecount = 30592, sum_scroll_delta = 0};
    }}
    feed('G')
    screen:expect{grid=[[
    ## grid 1
      [2:-----------------------------------------------------]|*12
      {11:test/functional/fixtures/bigfile.txt                 }|
      [3:-----------------------------------------------------]|
    ## grid 2
      {19:30587 }E01EE;VARIATION SELECTOR-255;Mn;0;NSM;;;;;N;;;;|
      {19:      };                                              |
      {19:30588 }E01EF;VARIATION SELECTOR-256;Mn;0;NSM;;;;;N;;;;|
      {19:      };                                              |
      {19:30589 }F0000;<Plane 15 Private Use, First>;Co;0;L;;;;;|
      {19:      }N;;;;;                                         |
      {19:30590 }FFFFD;<Plane 15 Private Use, Last>;Co;0;L;;;;;N|
      {19:      };;;;;                                          |
      {19:30591 }100000;<Plane 16 Private Use, First>;Co;0;L;;;;|
      {19:      };N;;;;;                                        |
      {19:30592 }^10FFFD;<Plane 16 Private Use, Last>;Co;0;L;;;;;|
      {19:      }N;;;;;                                         |
    ## grid 3
                                                           |
    ]], win_viewport={
      [2] = {win = 1000, topline = 30586, botline = 30592, curline = 30591, curcol = 0, linecount = 30592, sum_scroll_delta = 30588};
    }}
    feed('gg')
    screen:expect{grid=[[
    ## grid 1
      [2:-----------------------------------------------------]|*12
      {11:test/functional/fixtures/bigfile.txt                 }|
      [3:-----------------------------------------------------]|
    ## grid 2
      {19:    1 }^0000;<control>;Cc;0;BN;;;;;N;NULL;;;;          |
      {19:    2 }0001;<control>;Cc;0;BN;;;;;N;START OF HEADING;;|
      {19:      };;                                             |
      {19:    3 }0002;<control>;Cc;0;BN;;;;;N;START OF TEXT;;;; |
      {19:    4 }0003;<control>;Cc;0;BN;;;;;N;END OF TEXT;;;;   |
      {19:    5 }0004;<control>;Cc;0;BN;;;;;N;END OF TRANSMISSIO|
      {19:      }N;;;;                                          |
      {19:    6 }0005;<control>;Cc;0;BN;;;;;N;ENQUIRY;;;;       |
      {19:    7 }0006;<control>;Cc;0;BN;;;;;N;ACKNOWLEDGE;;;;   |
      {19:    8 }0007;<control>;Cc;0;BN;;;;;N;BELL;;;;          |
      {19:    9 }0008;<control>;Cc;0;BN;;;;;N;BACKSPACE;;;;     |
      {19:   10 }0009;<control>;Cc;0;S;;;;;N;CHARACTER TABULA{1:@@@}|
    ## grid 3
                                                           |
    ]], win_viewport={
      [2] = {win = 1000, topline = 0, botline = 10, curline = 0, curcol = 0, linecount = 30592, sum_scroll_delta = 0};
    }}
  end)

  it('does not crash when dragging mouse across grid boundary', function()
    screen:try_resize(48, 8)
    screen:expect{grid=[[
    ## grid 1
      [2:------------------------------------------------]|*6
      {11:[No Name]                                       }|
      [3:------------------------------------------------]|
    ## grid 2
      ^                                                |
      {1:~                                               }|*5
    ## grid 3
                                                      |
    ]], win_viewport={
      [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0}
    }}
    insert([[
      Lorem ipsum dolor sit amet, consectetur
      adipisicing elit, sed do eiusmod tempor
      incididunt ut labore et dolore magna aliqua.
      Ut enim ad minim veniam, quis nostrud
      exercitation ullamco laboris nisi ut aliquip ex
      ea commodo consequat. Duis aute irure dolor in
      reprehenderit in voluptate velit esse cillum
      dolore eu fugiat nulla pariatur. Excepteur sint
      occaecat cupidatat non proident, sunt in culpa
      qui officia deserunt mollit anim id est
      laborum.]])

    screen:expect{grid=[[
    ## grid 1
      [2:------------------------------------------------]|*6
      {11:[No Name] [+]                                   }|
      [3:------------------------------------------------]|
    ## grid 2
      ea commodo consequat. Duis aute irure dolor in  |
      reprehenderit in voluptate velit esse cillum    |
      dolore eu fugiat nulla pariatur. Excepteur sint |
      occaecat cupidatat non proident, sunt in culpa  |
      qui officia deserunt mollit anim id est         |
      laborum^.                                        |
    ## grid 3
                                                      |
    ]], win_viewport={
      [2] = {win = 1000, topline = 5, botline = 11, curline = 10, curcol = 7, linecount = 11, sum_scroll_delta = 5},
    }}

    api.nvim_input_mouse('left', 'press', '', 1,5, 1)
    poke_eventloop()
    api.nvim_input_mouse('left', 'drag', '', 1, 6, 1)

    screen:expect{grid=[[
    ## grid 1
      [2:------------------------------------------------]|*6
      {11:[No Name] [+]                                   }|
      [3:------------------------------------------------]|
    ## grid 2
      reprehenderit in voluptate velit esse cillum    |
      dolore eu fugiat nulla pariatur. Excepteur sint |
      occaecat cupidatat non proident, sunt in culpa  |
      qui officia deserunt mollit anim id est         |
      l^aborum.                                        |
      {1:~                                               }|
    ## grid 3
      {7:-- VISUAL --}                                    |
    ]], win_viewport={
      [2] = {win = 1000, topline = 6, botline = 12, curline = 10, curcol = 1, linecount = 11, sum_scroll_delta = 6},
    }}
  end)

  it('with winbar', function()
    command('split')
    local win_pos ={
      [2] = {
        height = 5,
        startcol = 0,
        startrow = 7,
        width = 53,
        win = 1000
      },
      [4] = {
        height = 6,
        startcol = 0,
        startrow = 0,
        width = 53,
        win = 1001
      }
    }
    screen:expect{grid=[[
    ## grid 1
      [4:-----------------------------------------------------]|*6
      {11:[No Name]                                            }|
      [2:-----------------------------------------------------]|*5
      {12:[No Name]                                            }|
      [3:-----------------------------------------------------]|
    ## grid 2
                                                           |
      {1:~                                                    }|*4
    ## grid 3
                                                           |
    ## grid 4
      ^                                                     |
      {1:~                                                    }|*5
    ]], win_viewport={
      [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
      [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
    }, win_viewport_margins={
      [2] = {win = 1000, top = 0, bottom = 0, left = 0, right = 0};
      [4] = {win = 1001, top = 0, bottom = 0, left = 0, right = 0};
    }, win_pos = win_pos }

    command('setlocal winbar=very%=bar')
    screen:expect{grid=[[
    ## grid 1
      [4:-----------------------------------------------------]|*6
      {11:[No Name]                                            }|
      [2:-----------------------------------------------------]|*5
      {12:[No Name]                                            }|
      [3:-----------------------------------------------------]|
    ## grid 2
                                                           |
      {1:~                                                    }|*4
    ## grid 3
                                                           |
    ## grid 4
      {7:very                                              bar}|
      ^                                                     |
      {1:~                                                    }|*4
    ]], win_viewport={
      [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
      [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
    }, win_viewport_margins={
      [2] = {win = 1000, top = 0, bottom = 0, left = 0, right = 0};
      [4] = {win = 1001, top = 1, bottom = 0, left = 0, right = 0};
    }, win_pos = win_pos }

    command('setlocal winbar=')
    screen:expect{grid=[[
    ## grid 1
      [4:-----------------------------------------------------]|*6
      {11:[No Name]                                            }|
      [2:-----------------------------------------------------]|*5
      {12:[No Name]                                            }|
      [3:-----------------------------------------------------]|
    ## grid 2
                                                           |
      {1:~                                                    }|*4
    ## grid 3
                                                           |
    ## grid 4
      ^                                                     |
      {1:~                                                    }|*5
    ]], win_viewport={
      [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
      [4] = {win = 1001, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
    }, win_viewport_margins={
      [2] = {win = 1000, top = 0, bottom = 0, left = 0, right = 0};
      [4] = {win = 1001, top = 0, bottom = 0, left = 0, right = 0};
    }, win_pos = win_pos }
  end)

  it('with winbar dragging statusline with mouse works correctly', function()
    api.nvim_set_option_value('winbar', 'Set Up The Bars', {})
    command('split')
    screen:expect([[
    ## grid 1
      [4:-----------------------------------------------------]|*6
      {11:[No Name]                                            }|
      [2:-----------------------------------------------------]|*5
      {12:[No Name]                                            }|
      [3:-----------------------------------------------------]|
    ## grid 2
      {7:Set Up The Bars                                      }|
                                                           |
      {1:~                                                    }|*3
    ## grid 3
                                                           |
    ## grid 4
      {7:Set Up The Bars                                      }|
      ^                                                     |
      {1:~                                                    }|*4
    ]])

    api.nvim_input_mouse('left', 'press', '', 1, 6, 20)
    poke_eventloop()
    api.nvim_input_mouse('left', 'drag', '', 1, 7, 20)
    screen:expect([[
    ## grid 1
      [4:-----------------------------------------------------]|*7
      {11:[No Name]                                            }|
      [2:-----------------------------------------------------]|*4
      {12:[No Name]                                            }|
      [3:-----------------------------------------------------]|
    ## grid 2
      {7:Set Up The Bars                                      }|
                                                           |
      {1:~                                                    }|*2
    ## grid 3
                                                           |
    ## grid 4
      {7:Set Up The Bars                                      }|
      ^                                                     |
      {1:~                                                    }|*5
    ]])

    api.nvim_input_mouse('left', 'drag', '', 1, 4, 20)
    screen:expect([[
    ## grid 1
      [4:-----------------------------------------------------]|*4
      {11:[No Name]                                            }|
      [2:-----------------------------------------------------]|*7
      {12:[No Name]                                            }|
      [3:-----------------------------------------------------]|
    ## grid 2
      {7:Set Up The Bars                                      }|
                                                           |
      {1:~                                                    }|*5
    ## grid 3
                                                           |
    ## grid 4
      {7:Set Up The Bars                                      }|
      ^                                                     |
      {1:~                                                    }|*2
    ]])

    api.nvim_input_mouse('left', 'press', '', 1, 12, 10)
    poke_eventloop()
    api.nvim_input_mouse('left', 'drag', '', 1, 10, 10)
    screen:expect([[
    ## grid 1
      [4:-----------------------------------------------------]|*4
      {11:[No Name]                                            }|
      [2:-----------------------------------------------------]|*5
      {12:[No Name]                                            }|
      [3:-----------------------------------------------------]|*3
    ## grid 2
      {7:Set Up The Bars                                      }|
                                                           |
      {1:~                                                    }|*3
    ## grid 3
                                                           |*3
    ## grid 4
      {7:Set Up The Bars                                      }|
      ^                                                     |
      {1:~                                                    }|*2
    ]])
    eq(3, api.nvim_get_option_value('cmdheight', {}))

    api.nvim_input_mouse('left', 'drag', '', 1, 12, 10)
    screen:expect([[
    ## grid 1
      [4:-----------------------------------------------------]|*4
      {11:[No Name]                                            }|
      [2:-----------------------------------------------------]|*7
      {12:[No Name]                                            }|
      [3:-----------------------------------------------------]|
    ## grid 2
      {7:Set Up The Bars                                      }|
                                                           |
      {1:~                                                    }|*5
    ## grid 3
                                                           |
    ## grid 4
      {7:Set Up The Bars                                      }|
      ^                                                     |
      {1:~                                                    }|*2
    ]])
    eq(1, api.nvim_get_option_value('cmdheight', {}))
  end)

  describe('centered cursorline', function()
    before_each(function()
      -- Force a centered cursorline, this caused some redrawing problems described in #30576.
      -- Most importantly, win_viewport was not received in time, and sum_scroll_delta did not refresh.
      command('set cursorline scrolloff=9999')
    end)
    it('insert line scrolls correctly', function()
      for i = 1, 11 do
        insert('line' .. i .. '\n')
      end
      screen:expect({
        grid = [[
        ## grid 1
          [2:-----------------------------------------------------]|*12
          {11:[No Name] [+]                                        }|
          [3:-----------------------------------------------------]|
        ## grid 2
          line1                                                |
          line2                                                |
          line3                                                |
          line4                                                |
          line5                                                |
          line6                                                |
          line7                                                |
          line8                                                |
          line9                                                |
          line10                                               |
          line11                                               |
          {23:^                                                     }|
        ## grid 3
                                                               |
        ]], win_viewport={
        [2] = {win = 1000, topline = 0, botline = 12, curline = 11, curcol = 0, linecount = 12, sum_scroll_delta = 0};
      }, win_viewport_margins={
        [2] = {
          bottom = 0,
          left = 0,
          right = 0,
          top = 0,
          win = 1000
        }
      }})
      insert('line12\n')
      screen:expect({
        grid = [[
        ## grid 1
          [2:-----------------------------------------------------]|*12
          {11:[No Name] [+]                                        }|
          [3:-----------------------------------------------------]|
        ## grid 2
          line2                                                |
          line3                                                |
          line4                                                |
          line5                                                |
          line6                                                |
          line7                                                |
          line8                                                |
          line9                                                |
          line10                                               |
          line11                                               |
          line12                                               |
          {23:^                                                     }|
        ## grid 3
                                                               |
        ]], win_viewport={
        [2] = {win = 1000, topline = 1, botline = 13, curline = 12, curcol = 0, linecount = 13, sum_scroll_delta = 1};
      }, win_viewport_margins={
        [2] = {
          bottom = 0,
          left = 0,
          right = 0,
          top = 0,
          win = 1000
        }
      }})
    end)

    it('got to top scrolls correctly', function()
      for i = 1, 20 do
        insert('line' .. i .. '\n')
      end
      screen:expect({
        grid = [[
        ## grid 1
          [2:-----------------------------------------------------]|*12
          {11:[No Name] [+]                                        }|
          [3:-----------------------------------------------------]|
        ## grid 2
          line10                                               |
          line11                                               |
          line12                                               |
          line13                                               |
          line14                                               |
          line15                                               |
          line16                                               |
          line17                                               |
          line18                                               |
          line19                                               |
          line20                                               |
          {23:^                                                     }|
        ## grid 3
                                                               |
        ]], win_viewport={
        [2] = {win = 1000, topline = 9, botline = 21, curline = 20, curcol = 0, linecount = 21, sum_scroll_delta = 9};
      }, win_viewport_margins={
        [2] = {
          bottom = 0,
          left = 0,
          right = 0,
          top = 0,
          win = 1000
        }
      }})
      feed('gg')
      screen:expect({
        grid = [[
        ## grid 1
          [2:-----------------------------------------------------]|*12
          {11:[No Name] [+]                                        }|
          [3:-----------------------------------------------------]|
        ## grid 2
          {23:^line1                                                }|
          line2                                                |
          line3                                                |
          line4                                                |
          line5                                                |
          line6                                                |
          line7                                                |
          line8                                                |
          line9                                                |
          line10                                               |
          line11                                               |
          line12                                               |
        ## grid 3
                                                               |
        ]], win_viewport={
        [2] = {win = 1000, topline = 0, botline = 13, curline = 0, curcol = 0, linecount = 21, sum_scroll_delta = 0};
      }, win_viewport_margins={
        [2] = {
          bottom = 0,
          left = 0,
          right = 0,
          top = 0,
          win = 1000
        }
      }})
    end)

    it('scrolls in the middle', function()
      for i = 1, 20 do
        insert('line' .. i .. '\n')
      end
      screen:expect({
        grid = [[
        ## grid 1
          [2:-----------------------------------------------------]|*12
          {11:[No Name] [+]                                        }|
          [3:-----------------------------------------------------]|
        ## grid 2
          line10                                               |
          line11                                               |
          line12                                               |
          line13                                               |
          line14                                               |
          line15                                               |
          line16                                               |
          line17                                               |
          line18                                               |
          line19                                               |
          line20                                               |
          {23:^                                                     }|
        ## grid 3
                                                               |
        ]], win_viewport={
        [2] = {win = 1000, topline = 9, botline = 21, curline = 20, curcol = 0, linecount = 21, sum_scroll_delta = 9};
      }, win_viewport_margins={
        [2] = {
          bottom = 0,
          left = 0,
          right = 0,
          top = 0,
          win = 1000
        }
      }})
      feed('M')
      screen:expect({
        grid = [[
        ## grid 1
          [2:-----------------------------------------------------]|*12
          {11:[No Name] [+]                                        }|
          [3:-----------------------------------------------------]|
        ## grid 2
          line10                                               |
          line11                                               |
          line12                                               |
          line13                                               |
          line14                                               |
          {23:^line15                                               }|
          line16                                               |
          line17                                               |
          line18                                               |
          line19                                               |
          line20                                               |
                                                               |
        ## grid 3
                                                               |
        ]], win_viewport={
        [2] = {win = 1000, topline = 9, botline = 21, curline = 14, curcol = 0, linecount = 21, sum_scroll_delta = 9};
      }, win_viewport_margins={
        [2] = {
          bottom = 0,
          left = 0,
          right = 0,
          top = 0,
          win = 1000
        }
      }})
      feed('k')
      screen:expect({
        grid = [[
        ## grid 1
          [2:-----------------------------------------------------]|*12
          {11:[No Name] [+]                                        }|
          [3:-----------------------------------------------------]|
        ## grid 2
          line9                                                |
          line10                                               |
          line11                                               |
          line12                                               |
          line13                                               |
          {23:^line14                                               }|
          line15                                               |
          line16                                               |
          line17                                               |
          line18                                               |
          line19                                               |
          line20                                               |
        ## grid 3
                                                               |
        ]], win_viewport={
        [2] = {win = 1000, topline = 8, botline = 21, curline = 13, curcol = 0, linecount = 21, sum_scroll_delta = 8};
      }, win_viewport_margins={
        [2] = {
          bottom = 0,
          left = 0,
          right = 0,
          top = 0,
          win = 1000
        }
      }})
    end)
  end)

  it('message grid is shown at the correct position remote re-attach', function()
    feed(':test')
    local expected = {
        grid = [[
        ## grid 1
          [2:-----------------------------------------------------]|*12
          {11:[No Name]                                            }|
          [3:-----------------------------------------------------]|
        ## grid 2
                                                               |
          {1:~                                                    }|*11
        ## grid 3
          :test^                                                |
        ]],
        win_pos = {
        [2] = {
          height = 12,
          startcol = 0,
          startrow = 0,
          width = 53,
          win = 1000
        }
      },
        win_viewport = {
        [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
      },
        win_viewport_margins = {
        [2] = {
          bottom = 0,
          left = 0,
          right = 0,
          top = 0,
          win = 1000
        }
      },
      reset = true
    }
    screen:expect(expected)
    feed('<cr>')
    screen:detach()
    screen:attach()
    feed(':test')
    screen:expect(expected)
  end)
end)

it('headless attach with showcmd', function()
  clear{args={'--headless'}}
  local screen = Screen.new(80, 24, {ext_multigrid=true})
  command('set showcmd')
  feed('1234')
  screen:expect({
    grid = [[
    ## grid 1
      [2:--------------------------------------------------------------------------------]|*23
      [3:--------------------------------------------------------------------------------]|
    ## grid 2
      ^                                                                                |
      {1:~                                                                               }|*22
    ## grid 3
                                                                           1234       |
    ]],
    win_viewport = {
      [2] = {win = 1000, topline = 0, botline = 2, curline = 0, curcol = 0, linecount = 1, sum_scroll_delta = 0};
    },
  })
end)
