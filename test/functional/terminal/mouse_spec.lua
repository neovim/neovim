local t = require('test.functional.testutil')(after_each)
local tt = require('test.functional.terminal.testutil')
local clear, eq, eval = t.clear, t.eq, t.eval
local feed, api, command = t.feed, t.api, t.command
local feed_data = tt.feed_data
local is_os = t.is_os
local skip = t.skip

describe(':terminal mouse', function()
  local screen

  before_each(function()
    clear()
    api.nvim_set_option_value('statusline', '==========', {})
    command('highlight StatusLine cterm=NONE')
    command('highlight StatusLineNC cterm=NONE')
    command('highlight VertSplit cterm=NONE')
    screen = tt.screen_setup()
    local lines = {}
    for i = 1, 30 do
      table.insert(lines, 'line' .. tostring(i))
    end
    table.insert(lines, '')
    feed_data(lines)
    screen:expect([[
      line26                                            |
      line27                                            |
      line28                                            |
      line29                                            |
      line30                                            |
      {1: }                                                 |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  describe('when the terminal has focus', function()
    it('will exit focus on mouse-scroll', function()
      eq('t', eval('mode(1)'))
      feed('<ScrollWheelUp><0,0>')
      eq('nt', eval('mode(1)'))
    end)

    it('will exit focus and trigger Normal mode mapping on mouse click', function()
      feed([[<C-\><C-N>qri]])
      command('let g:got_leftmouse = 0')
      command('nnoremap <LeftMouse> <Cmd>let g:got_leftmouse = 1<CR>')
      eq('t', eval('mode(1)'))
      eq(0, eval('g:got_leftmouse'))
      feed('<LeftMouse>')
      eq('nt', eval('mode(1)'))
      eq(1, eval('g:got_leftmouse'))
      feed('q')
      eq('i<LeftMouse>', eval('keytrans(@r)'))
    end)

    it('will exit focus and trigger Normal mode mapping on mouse click with modifier', function()
      feed([[<C-\><C-N>qri]])
      command('let g:got_ctrl_leftmouse = 0')
      command('nnoremap <C-LeftMouse> <Cmd>let g:got_ctrl_leftmouse = 1<CR>')
      eq('t', eval('mode(1)'))
      eq(0, eval('g:got_ctrl_leftmouse'))
      feed('<C-LeftMouse>')
      eq('nt', eval('mode(1)'))
      eq(1, eval('g:got_ctrl_leftmouse'))
      feed('q')
      eq('i<C-LeftMouse>', eval('keytrans(@r)'))
    end)

    it('will exit focus on <C-\\> + mouse-scroll', function()
      eq('t', eval('mode(1)'))
      feed('<C-\\>')
      feed('<ScrollWheelUp><0,0>')
      eq('nt', eval('mode(1)'))
    end)

    it('will not exit focus on left-release', function()
      eq('t', eval('mode(1)'))
      feed('<LeftRelease><0,0>')
      eq('t', eval('mode(1)'))
      command('setlocal number')
      eq('t', eval('mode(1)'))
      feed('<LeftRelease><0,0>')
      eq('t', eval('mode(1)'))
    end)

    it('will not exit focus on mouse movement', function()
      eq('t', eval('mode(1)'))
      feed('<MouseMove><0,0>')
      eq('t', eval('mode(1)'))
      command('setlocal number')
      eq('t', eval('mode(1)'))
      feed('<MouseMove><0,0>')
      eq('t', eval('mode(1)'))
    end)

    describe('with mouse events enabled by the program', function()
      before_each(function()
        tt.enable_mouse()
        tt.feed_data('mouse enabled\n')
        screen:expect([[
          line27                                            |
          line28                                            |
          line29                                            |
          line30                                            |
          mouse enabled                                     |
          {1: }                                                 |
          {3:-- TERMINAL --}                                    |
        ]])
      end)

      it('will forward mouse press, drag and release to the program', function()
        skip(is_os('win'))
        feed('<LeftMouse><1,2>')
        screen:expect([[
          line27                                            |
          line28                                            |
          line29                                            |
          line30                                            |
          mouse enabled                                     |
           "#{1: }                                              |
          {3:-- TERMINAL --}                                    |
        ]])
        feed('<LeftDrag><2,2>')
        screen:expect([[
          line27                                            |
          line28                                            |
          line29                                            |
          line30                                            |
          mouse enabled                                     |
             @##{1: }                                           |
          {3:-- TERMINAL --}                                    |
        ]])
        feed('<LeftDrag><3,2>')
        screen:expect([[
          line27                                            |
          line28                                            |
          line29                                            |
          line30                                            |
          mouse enabled                                     |
                @$#{1: }                                        |
          {3:-- TERMINAL --}                                    |
        ]])
        feed('<LeftRelease><3,2>')
        screen:expect([[
          line27                                            |
          line28                                            |
          line29                                            |
          line30                                            |
          mouse enabled                                     |
                   #$#{1: }                                     |
          {3:-- TERMINAL --}                                    |
        ]])
      end)

      it('will forward mouse scroll to the program', function()
        skip(is_os('win'))
        feed('<ScrollWheelUp><0,0>')
        screen:expect([[
          line27                                            |
          line28                                            |
          line29                                            |
          line30                                            |
          mouse enabled                                     |
          `!!{1: }                                              |
          {3:-- TERMINAL --}                                    |
        ]])
      end)

      it('dragging and scrolling do not interfere with each other', function()
        skip(is_os('win'))
        feed('<LeftMouse><1,2>')
        screen:expect([[
          line27                                            |
          line28                                            |
          line29                                            |
          line30                                            |
          mouse enabled                                     |
           "#{1: }                                              |
          {3:-- TERMINAL --}                                    |
        ]])
        feed('<ScrollWheelUp><1,2>')
        screen:expect([[
          line27                                            |
          line28                                            |
          line29                                            |
          line30                                            |
          mouse enabled                                     |
             `"#{1: }                                           |
          {3:-- TERMINAL --}                                    |
        ]])
        feed('<LeftDrag><2,2>')
        screen:expect([[
          line27                                            |
          line28                                            |
          line29                                            |
          line30                                            |
          mouse enabled                                     |
                @##{1: }                                        |
          {3:-- TERMINAL --}                                    |
        ]])
        feed('<ScrollWheelUp><2,2>')
        screen:expect([[
          line27                                            |
          line28                                            |
          line29                                            |
          line30                                            |
          mouse enabled                                     |
                   `##{1: }                                     |
          {3:-- TERMINAL --}                                    |
        ]])
        feed('<LeftRelease><2,2>')
        screen:expect([[
          line27                                            |
          line28                                            |
          line29                                            |
          line30                                            |
          mouse enabled                                     |
                      ###{1: }                                  |
          {3:-- TERMINAL --}                                    |
        ]])
      end)

      it('will forward mouse clicks to the program with the correct even if set nu', function()
        skip(is_os('win'))
        command('set number')
        -- When the display area such as a number is clicked, it returns to the
        -- normal mode.
        feed('<LeftMouse><3,0>')
        eq('nt', eval('mode(1)'))
        screen:expect([[
          {7: 11 }^line28                                        |
          {7: 12 }line29                                        |
          {7: 13 }line30                                        |
          {7: 14 }mouse enabled                                 |
          {7: 15 }rows: 6, cols: 46                             |
          {7: 16 }{2: }                                             |
                                                            |
        ]])
        -- If click on the coordinate (0,1) of the region of the terminal
        -- (i.e. the coordinate (4,1) of vim), 'CSI !"' is sent to the terminal.
        feed('i<LeftMouse><4,1>')
        screen:expect([[
          {7: 11 }line28                                        |
          {7: 12 }line29                                        |
          {7: 13 }line30                                        |
          {7: 14 }mouse enabled                                 |
          {7: 15 }rows: 6, cols: 46                             |
          {7: 16 } !"{1: }                                          |
          {3:-- TERMINAL --}                                    |
        ]])
      end)

      it('will lose focus if statusline is clicked', function()
        command('set laststatus=2')
        screen:expect([[
          line29                                            |
          line30                                            |
          mouse enabled                                     |
          rows: 5, cols: 50                                 |
          {1: }                                                 |
          ==========                                        |
          {3:-- TERMINAL --}                                    |
        ]])
        feed('<LeftMouse><0,5>')
        screen:expect([[
          line29                                            |
          line30                                            |
          mouse enabled                                     |
          rows: 5, cols: 50                                 |
          {2:^ }                                                 |
          ==========                                        |
                                                            |
        ]])
        feed('<LeftDrag><0,4>')
        screen:expect([[
          mouse enabled                                     |
          rows: 5, cols: 50                                 |
          rows: 4, cols: 50                                 |
          {2:^ }                                                 |
          ==========                                        |
                                                            |*2
        ]])
      end)

      it('will lose focus if right separator is clicked', function()
        command('rightbelow vnew | wincmd p | startinsert')
        screen:expect([[
          line29                  │                         |
          line30                  │{4:~                        }|
          mouse enabled           │{4:~                        }|
          rows: 5, cols: 24       │{4:~                        }|
          {1: }                       │{4:~                        }|
          ==========               ==========               |
          {3:-- TERMINAL --}                                    |
        ]])
        feed('<LeftMouse><24,0>')
        screen:expect([[
          line29                  │                         |
          line30                  │{4:~                        }|
          mouse enabled           │{4:~                        }|
          rows: 5, cols: 24       │{4:~                        }|
          {2:^ }                       │{4:~                        }|
          ==========               ==========               |
                                                            |
        ]])
        feed('<LeftDrag><23,0>')
        screen:expect([[
          line30                 │                          |
          mouse enabled          │{4:~                         }|
          rows: 5, cols: 24      │{4:~                         }|
          rows: 5, cols: 23      │{4:~                         }|
          {2:^ }                      │{4:~                         }|
          ==========              ==========                |
                                                            |
        ]])
      end)

      it('will lose focus if winbar/tabline is clicked', function()
        command('setlocal winbar=WINBAR')
        screen:expect([[
          {3:WINBAR                                            }|
          line29                                            |
          line30                                            |
          mouse enabled                                     |
          rows: 5, cols: 50                                 |
          {1: }                                                 |
          {3:-- TERMINAL --}                                    |
        ]])
        feed('<LeftMouse><0,0>')
        screen:expect([[
          {3:WINBAR                                            }|
          line29                                            |
          line30                                            |
          mouse enabled                                     |
          rows: 5, cols: 50                                 |
          {2:^ }                                                 |
                                                            |
        ]])
        command('set showtabline=2 tabline=TABLINE | startinsert')
        screen:expect([[
          {1:TABLINE                                           }|
          {3:WINBAR                                            }|
          mouse enabled                                     |
          rows: 5, cols: 50                                 |
          rows: 4, cols: 50                                 |
          {1: }                                                 |
          {3:-- TERMINAL --}                                    |
        ]])
        feed('<LeftMouse><0,0>')
        screen:expect([[
          {1:TABLINE                                           }|
          {3:WINBAR                                            }|
          mouse enabled                                     |
          rows: 5, cols: 50                                 |
          rows: 4, cols: 50                                 |
          {2:^ }                                                 |
                                                            |
        ]])
        command('setlocal winbar= | startinsert')
        screen:expect([[
          {1:TABLINE                                           }|
          mouse enabled                                     |
          rows: 5, cols: 50                                 |
          rows: 4, cols: 50                                 |
          rows: 5, cols: 50                                 |
          {1: }                                                 |
          {3:-- TERMINAL --}                                    |
        ]])
        feed('<LeftMouse><0,0>')
        screen:expect([[
          {1:TABLINE                                           }|
          mouse enabled                                     |
          rows: 5, cols: 50                                 |
          rows: 4, cols: 50                                 |
          rows: 5, cols: 50                                 |
          {2:^ }                                                 |
                                                            |
        ]])
      end)
    end)

    describe('with a split window and other buffer', function()
      before_each(function()
        feed('<c-\\><c-n>:vsp<cr>')
        screen:expect([[
          line28                   │line28                  |
          line29                   │line29                  |
          line30                   │line30                  |
          rows: 5, cols: 25        │rows: 5, cols: 25       |
          {2:^ }                        │{2: }                       |
          ==========                ==========              |
          :vsp                                              |
        ]])
        feed(':enew | set number<cr>')
        screen:expect([[
          {7:  1 }^                     │line29                  |
          {4:~                        }│line30                  |
          {4:~                        }│rows: 5, cols: 25       |
          {4:~                        }│rows: 5, cols: 24       |
          {4:~                        }│{2: }                       |
          ==========                ==========              |
          :enew | set number                                |
        ]])
        feed('30iline\n<esc>')
        screen:expect([[
          {7: 27 }line                 │line29                  |
          {7: 28 }line                 │line30                  |
          {7: 29 }line                 │rows: 5, cols: 25       |
          {7: 30 }line                 │rows: 5, cols: 24       |
          {7: 31 }^                     │{2: }                       |
          ==========                ==========              |
                                                            |
        ]])
        feed('<c-w>li')
        screen:expect([[
          {7: 27 }line                 │line29                  |
          {7: 28 }line                 │line30                  |
          {7: 29 }line                 │rows: 5, cols: 25       |
          {7: 30 }line                 │rows: 5, cols: 24       |
          {7: 31 }                     │{1: }                       |
          ==========                ==========              |
          {3:-- TERMINAL --}                                    |
        ]])

        -- enabling mouse won't affect interaction with other windows
        tt.enable_mouse()
        tt.feed_data('mouse enabled\n')
        screen:expect([[
          {7: 27 }line                 │line30                  |
          {7: 28 }line                 │rows: 5, cols: 25       |
          {7: 29 }line                 │rows: 5, cols: 24       |
          {7: 30 }line                 │mouse enabled           |
          {7: 31 }                     │{1: }                       |
          ==========                ==========              |
          {3:-- TERMINAL --}                                    |
        ]])
      end)

      it("scrolling another window keeps focus and respects 'mousescroll'", function()
        feed('<ScrollWheelUp><4,0><ScrollWheelUp><4,0>')
        screen:expect([[
          {7: 21 }line                 │line30                  |
          {7: 22 }line                 │rows: 5, cols: 25       |
          {7: 23 }line                 │rows: 5, cols: 24       |
          {7: 24 }line                 │mouse enabled           |
          {7: 25 }line                 │{1: }                       |
          ==========                ==========              |
          {3:-- TERMINAL --}                                    |
        ]])
        feed('<S-ScrollWheelDown><4,0>')
        screen:expect([[
          {7: 26 }line                 │line30                  |
          {7: 27 }line                 │rows: 5, cols: 25       |
          {7: 28 }line                 │rows: 5, cols: 24       |
          {7: 29 }line                 │mouse enabled           |
          {7: 30 }line                 │{1: }                       |
          ==========                ==========              |
          {3:-- TERMINAL --}                                    |
        ]])
        command('set mousescroll=ver:10')
        feed('<ScrollWheelUp><0,0>')
        screen:expect([[
          {7: 16 }line                 │line30                  |
          {7: 17 }line                 │rows: 5, cols: 25       |
          {7: 18 }line                 │rows: 5, cols: 24       |
          {7: 19 }line                 │mouse enabled           |
          {7: 20 }line                 │{1: }                       |
          ==========                ==========              |
          {3:-- TERMINAL --}                                    |
        ]])
        command('set mousescroll=ver:0')
        feed('<ScrollWheelUp><0,0>')
        screen:expect_unchanged()
        feed([[<C-\><C-N><C-W>w]])
        command('setlocal nowrap')
        feed('0<C-V>gg3ly$4p<C-W>wi')
        screen:expect([[
          {7:  1 }linelinelinelineline │line30                  |
          {7:  2 }linelinelinelineline │rows: 5, cols: 25       |
          {7:  3 }linelinelinelineline │rows: 5, cols: 24       |
          {7:  4 }linelinelinelineline │mouse enabled           |
          {7:  5 }linelinelinelineline │{1: }                       |
          ==========                ==========              |
          {3:-- TERMINAL --}                                    |
        ]])
        feed('<ScrollWheelRight><4,0>')
        screen:expect([[
          {7:  1 }nelinelineline       │line30                  |
          {7:  2 }nelinelineline       │rows: 5, cols: 25       |
          {7:  3 }nelinelineline       │rows: 5, cols: 24       |
          {7:  4 }nelinelineline       │mouse enabled           |
          {7:  5 }nelinelineline       │{1: }                       |
          ==========                ==========              |
          {3:-- TERMINAL --}                                    |
        ]])
        command('set mousescroll=hor:4')
        feed('<ScrollWheelLeft><4,0>')
        screen:expect([[
          {7:  1 }nelinelinelineline   │line30                  |
          {7:  2 }nelinelinelineline   │rows: 5, cols: 25       |
          {7:  3 }nelinelinelineline   │rows: 5, cols: 24       |
          {7:  4 }nelinelinelineline   │mouse enabled           |
          {7:  5 }nelinelinelineline   │{1: }                       |
          ==========                ==========              |
          {3:-- TERMINAL --}                                    |
        ]])
      end)

      it('will lose focus if another window is clicked', function()
        feed('<LeftMouse><5,1>')
        screen:expect([[
          {7: 27 }line                 │line30                  |
          {7: 28 }l^ine                 │rows: 5, cols: 25       |
          {7: 29 }line                 │rows: 5, cols: 24       |
          {7: 30 }line                 │mouse enabled           |
          {7: 31 }                     │{2: }                       |
          ==========                ==========              |
                                                            |
        ]])
      end)

      it('handles terminal size when switching buffers', function()
        api.nvim_set_option_value('hidden', true, {})
        feed('<c-\\><c-n><c-w><c-w>')
        screen:expect([[
          {7: 27 }line                 │line30                  |
          {7: 28 }line                 │rows: 5, cols: 25       |
          {7: 29 }line                 │rows: 5, cols: 24       |
          {7: 30 }line                 │mouse enabled           |
          {7: 31 }^                     │{2: }                       |
          ==========                ==========              |
                                                            |
        ]])
        feed(':bn<cr>')
        screen:expect([[
          rows: 5, cols: 25        │rows: 5, cols: 25       |
          rows: 5, cols: 24        │rows: 5, cols: 24       |
          mouse enabled            │mouse enabled           |
          rows: 5, cols: 25        │rows: 5, cols: 25       |
          {2:^ }                        │{2: }                       |
          ==========                ==========              |
          :bn                                               |
        ]])
        feed(':bn<cr>')
        screen:expect([[
          {7: 27 }line                 │rows: 5, cols: 24       |
          {7: 28 }line                 │mouse enabled           |
          {7: 29 }line                 │rows: 5, cols: 25       |
          {7: 30 }line                 │rows: 5, cols: 24       |
          {7: 31 }^                     │{2: }                       |
          ==========                ==========              |
          :bn                                               |
        ]])
      end)
    end)
  end)
end)
