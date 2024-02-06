local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, eq = helpers.clear, helpers.feed, helpers.eq
local command = helpers.command
local feed_command = helpers.feed_command
local insert = helpers.insert
local fn = helpers.fn
local api = helpers.api
local exec = helpers.exec
local assert_alive = helpers.assert_alive

local content1 = [[
        This is a
        valid English
        sentence composed by
        an exhausted developer
        in his cave.
        ]]

describe('folded lines', function()
  before_each(function()
    clear()
    command('hi VertSplit gui=reverse')
  end)

  local function with_ext_multigrid(multigrid)
    local screen
    before_each(function()
      screen = Screen.new(45, 8)
      screen:attach({ rgb = true, ext_multigrid = multigrid })
      screen:set_default_attr_ids({
        [1] = { bold = true, foreground = Screen.colors.Blue1 },
        [2] = { reverse = true },
        [3] = { bold = true, reverse = true },
        [4] = { foreground = Screen.colors.White, background = Screen.colors.Red },
        [5] = { foreground = Screen.colors.DarkBlue, background = Screen.colors.LightGrey },
        [6] = { background = Screen.colors.Yellow },
        [7] = { foreground = Screen.colors.DarkBlue, background = Screen.colors.WebGray },
        [8] = { foreground = Screen.colors.Brown },
        [9] = { bold = true, foreground = Screen.colors.Brown },
        [10] = { background = Screen.colors.LightGrey, underline = true },
        [11] = { bold = true },
        [12] = { foreground = Screen.colors.Red },
        [13] = { foreground = Screen.colors.Red, background = Screen.colors.LightGrey },
        [14] = { background = Screen.colors.Red },
        [15] = { foreground = Screen.colors.DarkBlue, background = Screen.colors.Red },
        [16] = { background = Screen.colors.LightGrey },
        [17] = { background = Screen.colors.Yellow, foreground = Screen.colors.Red },
        [18] = {
          background = Screen.colors.LightGrey,
          bold = true,
          foreground = Screen.colors.Blue,
        },
        [19] = { background = Screen.colors.Yellow, foreground = Screen.colors.DarkBlue },
        [20] = { background = Screen.colors.Red, bold = true, foreground = Screen.colors.Blue },
      })
    end)

    it('with more than one signcolumn', function()
      command('set signcolumn=yes:9')
      feed('i<cr><esc>')
      feed('vkzf')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {7:                  }{5:^+--  2 lines: ·············}|
          {1:~                                            }|*6
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          {7:                  }{5:^+--  2 lines: ·············}|
          {1:~                                            }|*6
                                                       |
        ]])
      end
    end)

    local function test_folded_cursorline(foldtext)
      if not foldtext then
        command('set foldtext=')
      end
      command('set number cursorline foldcolumn=2')
      command('hi link CursorLineFold Search')
      insert(content1)
      feed('ggzf3jj')

      if multigrid then
        if foldtext then
          screen:expect([[
          ## grid 1
            [2:---------------------------------------------]|*7
            [3:---------------------------------------------]|
          ## grid 2
            {7:+ }{8:  1 }{5:+--  4 lines: This is a················}|
            {6:  }{9:  5 }{12:^in his cave.                           }|
            {7:  }{8:  6 }                                       |
            {1:~                                            }|*4
          ## grid 3
                                                         |
          ]])
        else
          screen:expect([[
          ## grid 1
            [2:---------------------------------------------]|*7
            [3:---------------------------------------------]|
          ## grid 2
            {7:+ }{8:  1 }{5:This is a······························}|
            {6:  }{9:  5 }{12:^in his cave.                           }|
            {7:  }{8:  6 }                                       |
            {1:~                                            }|*4
          ## grid 3
                                                         |
          ]])
        end
      else
        if foldtext then
          screen:expect([[
            {7:+ }{8:  1 }{5:+--  4 lines: This is a················}|
            {6:  }{9:  5 }{12:^in his cave.                           }|
            {7:  }{8:  6 }                                       |
            {1:~                                            }|*4
                                                         |
          ]])
        else
          screen:expect([[
            {7:+ }{8:  1 }{5:This is a······························}|
            {6:  }{9:  5 }{12:^in his cave.                           }|
            {7:  }{8:  6 }                                       |
            {1:~                                            }|*4
                                                         |
          ]])
        end
      end

      feed('k')

      if multigrid then
        if foldtext then
          screen:expect([[
          ## grid 1
            [2:---------------------------------------------]|*7
            [3:---------------------------------------------]|
          ## grid 2
            {6:+ }{9:  1 }{13:^+--  4 lines: This is a················}|
            {7:  }{8:  5 }in his cave.                           |
            {7:  }{8:  6 }                                       |
            {1:~                                            }|*4
          ## grid 3
                                                         |
          ]])
        else
          screen:expect([[
          ## grid 1
            [2:---------------------------------------------]|*7
            [3:---------------------------------------------]|
          ## grid 2
            {6:+ }{9:  1 }{13:^This is a······························}|
            {7:  }{8:  5 }in his cave.                           |
            {7:  }{8:  6 }                                       |
            {1:~                                            }|*4
          ## grid 3
                                                         |
          ]])
        end
      else
        if foldtext then
          screen:expect([[
            {6:+ }{9:  1 }{13:^+--  4 lines: This is a················}|
            {7:  }{8:  5 }in his cave.                           |
            {7:  }{8:  6 }                                       |
            {1:~                                            }|*4
                                                         |
          ]])
        else
          screen:expect([[
            {6:+ }{9:  1 }{13:^This is a······························}|
            {7:  }{8:  5 }in his cave.                           |
            {7:  }{8:  6 }                                       |
            {1:~                                            }|*4
                                                         |
          ]])
        end
      end

      -- CursorLine is applied correctly with screenrow motions #22232
      feed('jgk')
      screen:expect_unchanged()
      -- CursorLine is applied correctly when closing a fold when cursor is not at fold start
      feed('zo4Gzc')
      screen:expect_unchanged()
      command('set cursorlineopt=line')

      if multigrid then
        if foldtext then
          screen:expect([[
          ## grid 1
            [2:---------------------------------------------]|*7
            [3:---------------------------------------------]|
          ## grid 2
            {7:+ }{8:  1 }{13:^+--  4 lines: This is a················}|
            {7:  }{8:  5 }in his cave.                           |
            {7:  }{8:  6 }                                       |
            {1:~                                            }|*4
          ## grid 3
                                                         |
          ]])
        else
          screen:expect([[
          ## grid 1
            [2:---------------------------------------------]|*7
            [3:---------------------------------------------]|
          ## grid 2
            {7:+ }{8:  1 }{13:^This is a······························}|
            {7:  }{8:  5 }in his cave.                           |
            {7:  }{8:  6 }                                       |
            {1:~                                            }|*4
          ## grid 3
                                                         |
          ]])
        end
      else
        if foldtext then
          screen:expect([[
            {7:+ }{8:  1 }{13:^+--  4 lines: This is a················}|
            {7:  }{8:  5 }in his cave.                           |
            {7:  }{8:  6 }                                       |
            {1:~                                            }|*4
                                                         |
          ]])
        else
          screen:expect([[
            {7:+ }{8:  1 }{13:^This is a······························}|
            {7:  }{8:  5 }in his cave.                           |
            {7:  }{8:  6 }                                       |
            {1:~                                            }|*4
                                                         |
          ]])
        end
      end

      command('set relativenumber cursorlineopt=number')

      if multigrid then
        if foldtext then
          screen:expect([[
          ## grid 1
            [2:---------------------------------------------]|*7
            [3:---------------------------------------------]|
          ## grid 2
            {6:+ }{9:1   }{5:^+--  4 lines: This is a················}|
            {7:  }{8:  1 }in his cave.                           |
            {7:  }{8:  2 }                                       |
            {1:~                                            }|*4
          ## grid 3
                                                         |
          ]])
        else
          screen:expect([[
          ## grid 1
            [2:---------------------------------------------]|*7
            [3:---------------------------------------------]|
          ## grid 2
            {6:+ }{9:1   }{5:^This is a······························}|
            {7:  }{8:  1 }in his cave.                           |
            {7:  }{8:  2 }                                       |
            {1:~                                            }|*4
          ## grid 3
                                                         |
          ]])
        end
      else
        if foldtext then
          screen:expect([[
            {6:+ }{9:1   }{5:^+--  4 lines: This is a················}|
            {7:  }{8:  1 }in his cave.                           |
            {7:  }{8:  2 }                                       |
            {1:~                                            }|*4
                                                         |
          ]])
        else
          screen:expect([[
            {6:+ }{9:1   }{5:^This is a······························}|
            {7:  }{8:  1 }in his cave.                           |
            {7:  }{8:  2 }                                       |
            {1:~                                            }|*4
                                                         |
          ]])
        end
      end
    end

    describe("when 'cursorline' is set", function()
      local function cursorline_tests(foldtext)
        local sfx = not foldtext and ' (transparent foldtext)' or ''
        it('with high-priority CursorLine' .. sfx, function()
          command('hi! CursorLine guibg=NONE guifg=Red gui=NONE')
          test_folded_cursorline(foldtext)
        end)

        it('with low-priority CursorLine' .. sfx, function()
          command('hi! CursorLine guibg=NONE guifg=NONE gui=underline')
          local attrs = screen:get_default_attr_ids()
          attrs[12] = { underline = true }
          attrs[13] = {
            foreground = Screen.colors.DarkBlue,
            background = Screen.colors.LightGrey,
            underline = true,
          }
          screen:set_default_attr_ids(attrs)
          test_folded_cursorline(foldtext)
        end)
      end

      cursorline_tests(true)
      cursorline_tests(false)
    end)

    it('with spell', function()
      command('set spell')
      insert(content1)

      feed('gg')
      feed('zf3j')
      if not multigrid then
        screen:expect {
          grid = [[
          {5:^+--  4 lines: This is a······················}|
          in his cave.                                 |
                                                       |
          {1:~                                            }|*4
                                                       |
        ]],
        }
      end
    end)

    it('with matches', function()
      insert(content1)
      command('highlight MyWord gui=bold guibg=red   guifg=white')
      command("call matchadd('MyWord', '\\V' . 'test', -1)")
      feed('gg')
      feed('zf3j')
      if not multigrid then
        screen:expect {
          grid = [[
          {5:^+--  4 lines: This is a······················}|
          in his cave.                                 |
                                                       |
          {1:~                                            }|*4
                                                       |
        ]],
        }
      end
    end)

    it('with multibyte fillchars', function()
      insert([[
        aa
        bb
        cc
        dd
        ee
        ff]])
      command('set fillchars+=foldopen:▾,foldsep:│,foldclose:▸')
      feed_command('1')
      command('set foldcolumn=2')
      feed('zf4j')
      feed('zf2j')
      feed('zO')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {7:▾▾}^aa                                         |
          {7:││}bb                                         |
          {7:││}cc                                         |
          {7:││}dd                                         |
          {7:││}ee                                         |
          {7:│ }ff                                         |
          {1:~                                            }|
        ## grid 3
          :1                                           |
        ]])
      else
        screen:expect([[
          {7:▾▾}^aa                                         |
          {7:││}bb                                         |
          {7:││}cc                                         |
          {7:││}dd                                         |
          {7:││}ee                                         |
          {7:│ }ff                                         |
          {1:~                                            }|
          :1                                           |
        ]])
      end

      feed_command('set rightleft')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
                                                   a^a{7:▾▾}|
                                                   bb{7:││}|
                                                   cc{7:││}|
                                                   dd{7:││}|
                                                   ee{7:││}|
                                                   ff{7: │}|
          {1:                                            ~}|
        ## grid 3
          :set rightleft                               |
        ]])
      else
        screen:expect([[
                                                   a^a{7:▾▾}|
                                                   bb{7:││}|
                                                   cc{7:││}|
                                                   dd{7:││}|
                                                   ee{7:││}|
                                                   ff{7: │}|
          {1:                                            ~}|
          :set rightleft                               |
        ]])
      end

      feed_command('set norightleft')
      if multigrid then
        api.nvim_input_mouse('left', 'press', '', 2, 0, 1)
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {7:▾▸}{5:^+---  5 lines: aa··························}|
          {7:│ }ff                                         |
          {1:~                                            }|*5
        ## grid 3
          :set norightleft                             |
        ]])
      else
        api.nvim_input_mouse('left', 'press', '', 0, 0, 1)
        screen:expect([[
          {7:▾▸}{5:^+---  5 lines: aa··························}|
          {7:│ }ff                                         |
          {1:~                                            }|*5
          :set norightleft                             |
        ]])
      end

      if multigrid then
        api.nvim_input_mouse('left', 'press', '', 2, 0, 0)
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {7:▸ }{5:^+--  6 lines: aa···························}|
          {1:~                                            }|*6
        ## grid 3
          :set norightleft                             |
        ]])
      else
        api.nvim_input_mouse('left', 'press', '', 0, 0, 0)
        screen:expect([[
          {7:▸ }{5:^+--  6 lines: aa···························}|
          {1:~                                            }|*6
          :set norightleft                             |
        ]])
      end

      -- Add a winbar to avoid double-clicks
      command('setlocal winbar=!!!!!!')
      if multigrid then
        api.nvim_input_mouse('left', 'press', '', 2, 1, 0)
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {11:!!!!!!                                       }|
          {7:▾▸}{5:^+---  5 lines: aa··························}|
          {7:│ }ff                                         |
          {1:~                                            }|*4
        ## grid 3
          :set norightleft                             |
        ]])
      else
        api.nvim_input_mouse('left', 'press', '', 0, 1, 0)
        screen:expect([[
          {11:!!!!!!                                       }|
          {7:▾▸}{5:^+---  5 lines: aa··························}|
          {7:│ }ff                                         |
          {1:~                                            }|*4
          :set norightleft                             |
        ]])
      end

      if multigrid then
        api.nvim_input_mouse('left', 'press', '', 2, 1, 1)
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {11:!!!!!!                                       }|
          {7:▾▾}^aa                                         |
          {7:││}bb                                         |
          {7:││}cc                                         |
          {7:││}dd                                         |
          {7:││}ee                                         |
          {7:│ }ff                                         |
        ## grid 3
          :set norightleft                             |
        ]])
      else
        api.nvim_input_mouse('left', 'press', '', 0, 1, 1)
        screen:expect([[
          {11:!!!!!!                                       }|
          {7:▾▾}^aa                                         |
          {7:││}bb                                         |
          {7:││}cc                                         |
          {7:││}dd                                         |
          {7:││}ee                                         |
          {7:│ }ff                                         |
          :set norightleft                             |
        ]])
      end
    end)

    it('with split', function()
      insert([[
        aa
        bb
        cc
        dd
        ee
        ff]])
      feed_command('2')
      command('set foldcolumn=1')
      feed('zf3j')
      feed_command('1')
      feed('zf2j')
      feed('zO')
      feed_command('rightbelow new')
      insert([[
        aa
        bb
        cc
        dd
        ee
        ff]])
      feed_command('2')
      command('set foldcolumn=1')
      feed('zf3j')
      feed_command('1')
      feed('zf2j')
      if multigrid then
        api.nvim_input_mouse('left', 'press', '', 4, 0, 0)
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*2
          {2:[No Name] [+]                                }|
          [4:---------------------------------------------]|*3
          {3:[No Name] [+]                                }|
          [3:---------------------------------------------]|
        ## grid 2
          {7:-}aa                                          |
          {7:-}bb                                          |
        ## grid 3
          :1                                           |
        ## grid 4
          {7:-}^aa                                          |
          {7:+}{5:+---  4 lines: bb···························}|
          {7:│}ff                                          |
        ]])
      else
        api.nvim_input_mouse('left', 'press', '', 0, 3, 0)
        screen:expect([[
          {7:-}aa                                          |
          {7:-}bb                                          |
          {2:[No Name] [+]                                }|
          {7:-}^aa                                          |
          {7:+}{5:+---  4 lines: bb···························}|
          {7:│}ff                                          |
          {3:[No Name] [+]                                }|
          :1                                           |
        ]])
      end

      if multigrid then
        api.nvim_input_mouse('left', 'press', '', 4, 1, 0)
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*2
          {2:[No Name] [+]                                }|
          [4:---------------------------------------------]|*3
          {3:[No Name] [+]                                }|
          [3:---------------------------------------------]|
        ## grid 2
          {7:-}aa                                          |
          {7:-}bb                                          |
        ## grid 3
          :1                                           |
        ## grid 4
          {7:-}^aa                                          |
          {7:-}bb                                          |
          {7:2}cc                                          |
        ]])
      else
        api.nvim_input_mouse('left', 'press', '', 0, 4, 0)
        screen:expect([[
          {7:-}aa                                          |
          {7:-}bb                                          |
          {2:[No Name] [+]                                }|
          {7:-}^aa                                          |
          {7:-}bb                                          |
          {7:2}cc                                          |
          {3:[No Name] [+]                                }|
          :1                                           |
        ]])
      end

      if multigrid then
        api.nvim_input_mouse('left', 'press', '', 2, 1, 0)
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*2
          {3:[No Name] [+]                                }|
          [4:---------------------------------------------]|*3
          {2:[No Name] [+]                                }|
          [3:---------------------------------------------]|
        ## grid 2
          {7:-}aa                                          |
          {7:+}{5:^+---  4 lines: bb···························}|
        ## grid 3
          :1                                           |
        ## grid 4
          {7:-}aa                                          |
          {7:-}bb                                          |
          {7:2}cc                                          |
        ]])
      else
        api.nvim_input_mouse('left', 'press', '', 0, 1, 0)
        screen:expect([[
          {7:-}aa                                          |
          {7:+}{5:^+---  4 lines: bb···························}|
          {3:[No Name] [+]                                }|
          {7:-}aa                                          |
          {7:-}bb                                          |
          {7:2}cc                                          |
          {2:[No Name] [+]                                }|
          :1                                           |
        ]])
      end

      if multigrid then
        api.nvim_input_mouse('left', 'press', '', 2, 0, 0)
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*2
          {3:[No Name] [+]                                }|
          [4:---------------------------------------------]|*3
          {2:[No Name] [+]                                }|
          [3:---------------------------------------------]|
        ## grid 2
          {7:+}{5:^+--  6 lines: aa····························}|
          {1:~                                            }|
        ## grid 3
          :1                                           |
        ## grid 4
          {7:-}aa                                          |
          {7:-}bb                                          |
          {7:2}cc                                          |
        ]])
      else
        api.nvim_input_mouse('left', 'press', '', 0, 0, 0)
        screen:expect([[
          {7:+}{5:^+--  6 lines: aa····························}|
          {1:~                                            }|
          {3:[No Name] [+]                                }|
          {7:-}aa                                          |
          {7:-}bb                                          |
          {7:2}cc                                          |
          {2:[No Name] [+]                                }|
          :1                                           |
        ]])
      end
    end)

    it('with vsplit', function()
      insert([[
        aa
        bb
        cc
        dd
        ee
        ff]])
      feed_command('2')
      command('set foldcolumn=1')
      feed('zf3j')
      feed_command('1')
      feed('zf2j')
      feed('zO')
      feed_command('rightbelow vnew')
      insert([[
        aa
        bb
        cc
        dd
        ee
        ff]])
      feed_command('2')
      command('set foldcolumn=1')
      feed('zf3j')
      feed_command('1')
      feed('zf2j')
      if multigrid then
        api.nvim_input_mouse('left', 'press', '', 4, 0, 0)
        screen:expect([[
        ## grid 1
          [2:----------------------]{2:│}[4:----------------------]|*6
          {2:[No Name] [+]          }{3:[No Name] [+]         }|
          [3:---------------------------------------------]|
        ## grid 2
          {7:-}aa                   |
          {7:-}bb                   |
          {7:2}cc                   |
          {7:2}dd                   |
          {7:2}ee                   |
          {7:│}ff                   |
        ## grid 3
          :1                                           |
        ## grid 4
          {7:-}^aa                   |
          {7:+}{5:+---  4 lines: bb····}|
          {7:│}ff                   |
          {1:~                     }|*3
        ]])
      else
        api.nvim_input_mouse('left', 'press', '', 0, 0, 23)
        screen:expect([[
          {7:-}aa                   {2:│}{7:-}^aa                   |
          {7:-}bb                   {2:│}{7:+}{5:+---  4 lines: bb····}|
          {7:2}cc                   {2:│}{7:│}ff                   |
          {7:2}dd                   {2:│}{1:~                     }|
          {7:2}ee                   {2:│}{1:~                     }|
          {7:│}ff                   {2:│}{1:~                     }|
          {2:[No Name] [+]          }{3:[No Name] [+]         }|
          :1                                           |
        ]])
      end

      if multigrid then
        api.nvim_input_mouse('left', 'press', '', 4, 1, 0)
        screen:expect([[
        ## grid 1
          [2:----------------------]{2:│}[4:----------------------]|*6
          {2:[No Name] [+]          }{3:[No Name] [+]         }|
          [3:---------------------------------------------]|
        ## grid 2
          {7:-}aa                   |
          {7:-}bb                   |
          {7:2}cc                   |
          {7:2}dd                   |
          {7:2}ee                   |
          {7:│}ff                   |
        ## grid 3
          :1                                           |
        ## grid 4
          {7:-}^aa                   |
          {7:-}bb                   |
          {7:2}cc                   |
          {7:2}dd                   |
          {7:2}ee                   |
          {7:│}ff                   |
        ]])
      else
        api.nvim_input_mouse('left', 'press', '', 0, 1, 23)
        screen:expect([[
          {7:-}aa                   {2:│}{7:-}^aa                   |
          {7:-}bb                   {2:│}{7:-}bb                   |
          {7:2}cc                   {2:│}{7:2}cc                   |
          {7:2}dd                   {2:│}{7:2}dd                   |
          {7:2}ee                   {2:│}{7:2}ee                   |
          {7:│}ff                   {2:│}{7:│}ff                   |
          {2:[No Name] [+]          }{3:[No Name] [+]         }|
          :1                                           |
        ]])
      end

      if multigrid then
        api.nvim_input_mouse('left', 'press', '', 2, 1, 0)
        screen:expect([[
        ## grid 1
          [2:----------------------]{2:│}[4:----------------------]|*6
          {3:[No Name] [+]          }{2:[No Name] [+]         }|
          [3:---------------------------------------------]|
        ## grid 2
          {7:-}aa                   |
          {7:+}{5:^+---  4 lines: bb····}|
          {7:│}ff                   |
          {1:~                     }|*3
        ## grid 3
          :1                                           |
        ## grid 4
          {7:-}aa                   |
          {7:-}bb                   |
          {7:2}cc                   |
          {7:2}dd                   |
          {7:2}ee                   |
          {7:│}ff                   |
        ]])
      else
        api.nvim_input_mouse('left', 'press', '', 0, 1, 0)
        screen:expect([[
          {7:-}aa                   {2:│}{7:-}aa                   |
          {7:+}{5:^+---  4 lines: bb····}{2:│}{7:-}bb                   |
          {7:│}ff                   {2:│}{7:2}cc                   |
          {1:~                     }{2:│}{7:2}dd                   |
          {1:~                     }{2:│}{7:2}ee                   |
          {1:~                     }{2:│}{7:│}ff                   |
          {3:[No Name] [+]          }{2:[No Name] [+]         }|
          :1                                           |
        ]])
      end

      if multigrid then
        api.nvim_input_mouse('left', 'press', '', 2, 0, 0)
        screen:expect([[
        ## grid 1
          [2:----------------------]{2:│}[4:----------------------]|*6
          {3:[No Name] [+]          }{2:[No Name] [+]         }|
          [3:---------------------------------------------]|
        ## grid 2
          {7:+}{5:^+--  6 lines: aa·····}|
          {1:~                     }|*5
        ## grid 3
          :1                                           |
        ## grid 4
          {7:-}aa                   |
          {7:-}bb                   |
          {7:2}cc                   |
          {7:2}dd                   |
          {7:2}ee                   |
          {7:│}ff                   |
        ]])
      else
        api.nvim_input_mouse('left', 'press', '', 0, 0, 0)
        screen:expect([[
          {7:+}{5:^+--  6 lines: aa·····}{2:│}{7:-}aa                   |
          {1:~                     }{2:│}{7:-}bb                   |
          {1:~                     }{2:│}{7:2}cc                   |
          {1:~                     }{2:│}{7:2}dd                   |
          {1:~                     }{2:│}{7:2}ee                   |
          {1:~                     }{2:│}{7:│}ff                   |
          {3:[No Name] [+]          }{2:[No Name] [+]         }|
          :1                                           |
        ]])
      end
    end)

    it('with tabpages', function()
      insert([[
        aa
        bb
        cc
        dd
        ee
        ff]])
      feed_command('2')
      command('set foldcolumn=2')
      feed('zf3j')
      feed_command('1')
      feed('zf2j')
      feed('zO')
      feed_command('tab split')
      if multigrid then
        api.nvim_input_mouse('left', 'press', '', 4, 1, 1)
        screen:expect([[
        ## grid 1
          {10: + [No Name] }{11: + [No Name] }{2:                  }{10:X}|
          [4:---------------------------------------------]|*6
          [3:---------------------------------------------]|
        ## grid 2 (hidden)
          {7:- }aa                                         |
          {7:│-}bb                                         |
          {7:││}cc                                         |
          {7:││}dd                                         |
          {7:││}ee                                         |
          {7:│ }ff                                         |
          {1:~                                            }|
        ## grid 3
          :tab split                                   |
        ## grid 4
          {7:- }^aa                                         |
          {7:│+}{5:+---  4 lines: bb··························}|
          {7:│ }ff                                         |
          {1:~                                            }|*3
        ]])
      else
        api.nvim_input_mouse('left', 'press', '', 0, 2, 1)
        screen:expect([[
          {10: + [No Name] }{11: + [No Name] }{2:                  }{10:X}|
          {7:- }^aa                                         |
          {7:│+}{5:+---  4 lines: bb··························}|
          {7:│ }ff                                         |
          {1:~                                            }|*3
          :tab split                                   |
        ]])
      end

      if multigrid then
        api.nvim_input_mouse('left', 'press', '', 4, 0, 0)
        screen:expect([[
        ## grid 1
          {10: + [No Name] }{11: + [No Name] }{2:                  }{10:X}|
          [4:---------------------------------------------]|*6
          [3:---------------------------------------------]|
        ## grid 2 (hidden)
          {7:- }aa                                         |
          {7:│-}bb                                         |
          {7:││}cc                                         |
          {7:││}dd                                         |
          {7:││}ee                                         |
          {7:│ }ff                                         |
          {1:~                                            }|
        ## grid 3
          :tab split                                   |
        ## grid 4
          {7:+ }{5:^+--  6 lines: aa···························}|
          {1:~                                            }|*5
        ]])
      else
        api.nvim_input_mouse('left', 'press', '', 0, 1, 0)
        screen:expect([[
          {10: + [No Name] }{11: + [No Name] }{2:                  }{10:X}|
          {7:+ }{5:^+--  6 lines: aa···························}|
          {1:~                                            }|*5
          :tab split                                   |
        ]])
      end

      feed_command('tabnext')
      if multigrid then
        api.nvim_input_mouse('left', 'press', '', 2, 1, 1)
        screen:expect([[
        ## grid 1
          {11: + [No Name] }{10: + [No Name] }{2:                  }{10:X}|
          [2:---------------------------------------------]|*6
          [3:---------------------------------------------]|
        ## grid 2
          {7:- }^aa                                         |
          {7:│+}{5:+---  4 lines: bb··························}|
          {7:│ }ff                                         |
          {1:~                                            }|*3
        ## grid 3
          :tabnext                                     |
        ## grid 4 (hidden)
          {7:+ }{5:+--  6 lines: aa···························}|
          {1:~                                            }|*5
        ]])
      else
        api.nvim_input_mouse('left', 'press', '', 0, 2, 1)
        screen:expect([[
          {11: + [No Name] }{10: + [No Name] }{2:                  }{10:X}|
          {7:- }^aa                                         |
          {7:│+}{5:+---  4 lines: bb··························}|
          {7:│ }ff                                         |
          {1:~                                            }|*3
          :tabnext                                     |
        ]])
      end

      if multigrid then
        api.nvim_input_mouse('left', 'press', '', 2, 0, 0)
        screen:expect([[
        ## grid 1
          {11: + [No Name] }{10: + [No Name] }{2:                  }{10:X}|
          [2:---------------------------------------------]|*6
          [3:---------------------------------------------]|
        ## grid 2
          {7:+ }{5:^+--  6 lines: aa···························}|
          {1:~                                            }|*5
        ## grid 3
          :tabnext                                     |
        ## grid 4 (hidden)
          {7:+ }{5:+--  6 lines: aa···························}|
          {1:~                                            }|*5
        ]])
      else
        api.nvim_input_mouse('left', 'press', '', 0, 1, 0)
        screen:expect([[
          {11: + [No Name] }{10: + [No Name] }{2:                  }{10:X}|
          {7:+ }{5:^+--  6 lines: aa···························}|
          {1:~                                            }|*5
          :tabnext                                     |
        ]])
      end
    end)

    it('with multibyte text', function()
      eq(true, api.nvim_get_option_value('arabicshape', {}))
      insert([[
        å 语 x̨̣̘̫̲͚͎̎͂̀̂͛͛̾͢͟ العَرَبِيَّة
        möre text]])
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          å 语 x̨̣̘̫̲͚͎̎͂̀̂͛͛̾͢ ﺎﻠﻋَﺮَﺒِﻳَّﺓ                               |
          möre tex^t                                    |
          {1:~                                            }|*5
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          å 语 x̨̣̘̫̲͚͎̎͂̀̂͛͛̾͢ ﺎﻠﻋَﺮَﺒِﻳَّﺓ                               |
          möre tex^t                                    |
          {1:~                                            }|*5
                                                       |
        ]])
      end

      feed('vkzf')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {5:^+--  2 lines: å 语 x̨̣̘̫̲͚͎̎͂̀̂͛͛̾͢ ﺎﻠﻋَﺮَﺒِﻳَّﺓ·················}|
          {1:~                                            }|*6
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          {5:^+--  2 lines: å 语 x̨̣̘̫̲͚͎̎͂̀̂͛͛̾͢ ﺎﻠﻋَﺮَﺒِﻳَّﺓ·················}|
          {1:~                                            }|*6
                                                       |
        ]])
      end

      feed_command('set noarabicshape')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {5:^+--  2 lines: å 语 x̨̣̘̫̲͚͎̎͂̀̂͛͛̾͢ العَرَبِيَّة·················}|
          {1:~                                            }|*6
        ## grid 3
          :set noarabicshape                           |
        ]])
      else
        screen:expect([[
          {5:^+--  2 lines: å 语 x̨̣̘̫̲͚͎̎͂̀̂͛͛̾͢ العَرَبِيَّة·················}|
          {1:~                                            }|*6
          :set noarabicshape                           |
        ]])
      end

      feed_command('set number foldcolumn=2')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {7:+ }{8:  1 }{5:^+--  2 lines: å 语 x̨̣̘̫̲͚͎̎͂̀̂͛͛̾͢ العَرَبِيَّة···········}|
          {1:~                                            }|*6
        ## grid 3
          :set number foldcolumn=2                     |
        ]])
      else
        screen:expect([[
          {7:+ }{8:  1 }{5:^+--  2 lines: å 语 x̨̣̘̫̲͚͎̎͂̀̂͛͛̾͢ العَرَبِيَّة···········}|
          {1:~                                            }|*6
          :set number foldcolumn=2                     |
        ]])
      end

      -- Note: too much of the folded line gets cut off.This is a vim bug.
      feed_command('set rightleft')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {5:···········ةيَّبِرَعَلا x̨̣̘̫̲͚͎̎͂̀̂͛͛̾͢ 语 å :senil 2  --^+}{8: 1  }{7: +}|
          {1:                                            ~}|*6
        ## grid 3
          :set rightleft                               |
        ]])
      else
        screen:expect([[
          {5:···········ةيَّبِرَعَلا x̨̣̘̫̲͚͎̎͂̀̂͛͛̾͢ 语 å :senil 2  --^+}{8: 1  }{7: +}|
          {1:                                            ~}|*6
          :set rightleft                               |
        ]])
      end

      feed_command('set nonumber foldcolumn=0')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {5:·················ةيَّبِرَعَلا x̨̣̘̫̲͚͎̎͂̀̂͛͛̾͢ 语 å :senil 2  --^+}|
          {1:                                            ~}|*6
        ## grid 3
          :set nonumber foldcolumn=0                   |
        ]])
      else
        screen:expect([[
          {5:·················ةيَّبِرَعَلا x̨̣̘̫̲͚͎̎͂̀̂͛͛̾͢ 语 å :senil 2  --^+}|
          {1:                                            ~}|*6
          :set nonumber foldcolumn=0                   |
        ]])
      end

      feed_command('set arabicshape')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {5:·················ﺔﻴَّﺑِﺮَﻌَﻟﺍ x̨̣̘̫̲͚͎̎͂̀̂͛͛̾͢ 语 å :senil 2  --^+}|
          {1:                                            ~}|*6
        ## grid 3
          :set arabicshape                             |
        ]])
      else
        screen:expect([[
          {5:·················ﺔﻴَّﺑِﺮَﻌَﻟﺍ x̨̣̘̫̲͚͎̎͂̀̂͛͛̾͢ 语 å :senil 2  --^+}|
          {1:                                            ~}|*6
          :set arabicshape                             |
        ]])
      end

      feed('zo')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
                                         ﺔﻴَّﺑِﺮَﻌَ^ﻟﺍ x̨̣̘̫̲͚͎̎͂̀̂͛͛̾͢ 语 å|
                                              txet eröm|
          {1:                                            ~}|*5
        ## grid 3
          :set arabicshape                             |
        ]])
      else
        screen:expect([[
                                         ﺔﻴَّﺑِﺮَﻌَ^ﻟﺍ x̨̣̘̫̲͚͎̎͂̀̂͛͛̾͢ 语 å|
                                              txet eröm|
          {1:                                            ~}|*5
          :set arabicshape                             |
        ]])
      end

      feed_command('set noarabicshape')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
                                         ةيَّبِرَعَ^لا x̨̣̘̫̲͚͎̎͂̀̂͛͛̾͢ 语 å|
                                              txet eröm|
          {1:                                            ~}|*5
        ## grid 3
          :set noarabicshape                           |
        ]])
      else
        screen:expect([[
                                         ةيَّبِرَعَ^لا x̨̣̘̫̲͚͎̎͂̀̂͛͛̾͢ 语 å|
                                              txet eröm|
          {1:                                            ~}|*5
          :set noarabicshape                           |
        ]])
      end
    end)

    it('in cmdline window', function()
      feed_command('set foldmethod=manual foldcolumn=1')
      feed_command('let x = 1')
      feed_command('/alpha')
      feed_command('/omega')

      feed('<cr>q:')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          {2:[No Name]                                    }|
          [4:---------------------------------------------]|*4
          {3:[Command Line]                               }|
          [3:---------------------------------------------]|
        ## grid 2
          {7: }                                            |
        ## grid 3
          :                                            |
        ## grid 4
          {1::}{7: }set foldmethod=manual foldcolumn=1         |
          {1::}{7: }let x = 1                                  |
          {1::}{7: }^                                           |
          {1:~                                            }|
        ]])
      else
        screen:expect([[
          {7: }                                            |
          {2:[No Name]                                    }|
          {1::}{7: }set foldmethod=manual foldcolumn=1         |
          {1::}{7: }let x = 1                                  |
          {1::}{7: }^                                           |
          {1:~                                            }|
          {3:[Command Line]                               }|
          :                                            |
        ]])
      end

      feed('kzfk')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          {2:[No Name]                                    }|
          [4:---------------------------------------------]|*4
          {3:[Command Line]                               }|
          [3:---------------------------------------------]|
        ## grid 2
          {7: }                                            |
        ## grid 3
          :                                            |
        ## grid 4
          {1::}{7:+}{5:^+--  2 lines: set foldmethod=manual foldcol}|
          {1::}{7: }                                           |
          {1:~                                            }|*2
        ]])
      else
        screen:expect([[
          {7: }                                            |
          {2:[No Name]                                    }|
          {1::}{7:+}{5:^+--  2 lines: set foldmethod=manual foldcol}|
          {1::}{7: }                                           |
          {1:~                                            }|*2
          {3:[Command Line]                               }|
          :                                            |
        ]])
      end

      feed('<cr>')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {7: }^                                            |
          {1:~                                            }|*6
        ## grid 3
          :                                            |
        ]])
      else
        screen:expect([[
          {7: }^                                            |
          {1:~                                            }|*6
          :                                            |
        ]])
      end

      feed('/<c-f>')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          {2:[No Name]                                    }|
          [5:---------------------------------------------]|*4
          {3:[Command Line]                               }|
          [3:---------------------------------------------]|
        ## grid 2
          {7: }                                            |
        ## grid 3
          /                                            |
        ## grid 5
          {1:/}{7: }alpha                                      |
          {1:/}{7: }{6:omega}                                      |
          {1:/}{7: }^                                           |
          {1:~                                            }|
        ]])
      else
        screen:expect([[
          {7: }                                            |
          {2:[No Name]                                    }|
          {1:/}{7: }alpha                                      |
          {1:/}{7: }{6:omega}                                      |
          {1:/}{7: }^                                           |
          {1:~                                            }|
          {3:[Command Line]                               }|
          /                                            |
        ]])
      end

      feed('ggzfG')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          {2:[No Name]                                    }|
          [5:---------------------------------------------]|*4
          {3:[Command Line]                               }|
          [3:---------------------------------------------]|
        ## grid 2
          {7: }                                            |
        ## grid 3
          /                                            |
        ## grid 5
          {1:/}{7:+}{5:^+--  3 lines: alpha························}|
          {1:~                                            }|*3
        ]])
      else
        screen:expect([[
          {7: }                                            |
          {2:[No Name]                                    }|
          {1:/}{7:+}{5:^+--  3 lines: alpha························}|
          {1:~                                            }|*3
          {3:[Command Line]                               }|
          /                                            |
        ]])
      end
    end)

    it('foldcolumn autoresize', function()
      fn.setline(1, 'line 1')
      fn.setline(2, 'line 2')
      fn.setline(3, 'line 3')
      fn.setline(4, 'line 4')

      feed('zfj')
      command('set foldcolumn=0')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {5:^+--  2 lines: line 1·························}|
          line 3                                       |
          line 4                                       |
          {1:~                                            }|*4
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          {5:^+--  2 lines: line 1·························}|
          line 3                                       |
          line 4                                       |
          {1:~                                            }|*4
                                                       |
        ]])
      end
      -- should adapt to the current nesting of folds (e.g., 1)
      command('set foldcolumn=auto:1')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {7:+}{5:^+--  2 lines: line 1························}|
          {7: }line 3                                      |
          {7: }line 4                                      |
          {1:~                                            }|*4
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          {7:+}{5:^+--  2 lines: line 1························}|
          {7: }line 3                                      |
          {7: }line 4                                      |
          {1:~                                            }|*4
                                                       |
        ]])
      end
      command('set foldcolumn=auto')
      if multigrid then
        screen:expect {
          grid = [[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {7:+}{5:^+--  2 lines: line 1························}|
          {7: }line 3                                      |
          {7: }line 4                                      |
          {1:~                                            }|*4
        ## grid 3
                                                       |
        ]],
          unchanged = true,
        }
      else
        screen:expect {
          grid = [[
          {7:+}{5:^+--  2 lines: line 1························}|
          {7: }line 3                                      |
          {7: }line 4                                      |
          {1:~                                            }|*4
                                                       |
        ]],
          unchanged = true,
        }
      end
      -- fdc should not change with a new fold as the maximum is 1
      feed('zf3j')

      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {7:+}{5:^+--  4 lines: line 1························}|
          {1:~                                            }|*6
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          {7:+}{5:^+--  4 lines: line 1························}|
          {1:~                                            }|*6
                                                       |
        ]])
      end

      command('set foldcolumn=auto:1')
      if multigrid then
        screen:expect {
          grid = [[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {7:+}{5:^+--  4 lines: line 1························}|
          {1:~                                            }|*6
        ## grid 3
                                                       |
        ]],
          unchanged = true,
        }
      else
        screen:expect {
          grid = [[
          {7:+}{5:^+--  4 lines: line 1························}|
          {1:~                                            }|*6
                                                       |
        ]],
          unchanged = true,
        }
      end

      -- relax the maximum fdc thus fdc should expand to
      -- accommodate the current number of folds
      command('set foldcolumn=auto:4')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {7:+ }{5:^+--  4 lines: line 1·······················}|
          {1:~                                            }|*6
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          {7:+ }{5:^+--  4 lines: line 1·······················}|
          {1:~                                            }|*6
                                                       |
        ]])
      end
    end)

    it('no crash when foldtext is longer than columns #12988', function()
      exec([[
        function! MyFoldText() abort
          return repeat('-', &columns + 100)
        endfunction
      ]])
      command('set foldtext=MyFoldText()')
      feed('i<cr><esc>')
      feed('vkzf')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {5:^---------------------------------------------}|
          {1:~                                            }|*6
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          {5:^---------------------------------------------}|
          {1:~                                            }|*6
                                                       |
        ]])
      end
      assert_alive()
    end)

    it('fold text is shown when text has been scrolled to the right #19123', function()
      insert(content1)
      command('set number nowrap')
      command('3,4fold')
      feed('gg')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {8:  1 }^This is a                                |
          {8:  2 }valid English                            |
          {8:  3 }{5:+--  2 lines: sentence composed by·······}|
          {8:  5 }in his cave.                             |
          {8:  6 }                                         |
          {1:~                                            }|*2
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          {8:  1 }^This is a                                |
          {8:  2 }valid English                            |
          {8:  3 }{5:+--  2 lines: sentence composed by·······}|
          {8:  5 }in his cave.                             |
          {8:  6 }                                         |
          {1:~                                            }|*2
                                                       |
        ]])
      end

      feed('zl')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {8:  1 }^his is a                                 |
          {8:  2 }alid English                             |
          {8:  3 }{5:+--  2 lines: sentence composed by·······}|
          {8:  5 }n his cave.                              |
          {8:  6 }                                         |
          {1:~                                            }|*2
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          {8:  1 }^his is a                                 |
          {8:  2 }alid English                             |
          {8:  3 }{5:+--  2 lines: sentence composed by·······}|
          {8:  5 }n his cave.                              |
          {8:  6 }                                         |
          {1:~                                            }|*2
                                                       |
        ]])
      end
    end)

    it('fold attached virtual lines are drawn and scrolled correctly #21837', function()
      fn.setline(1, 'line 1')
      fn.setline(2, 'line 2')
      fn.setline(3, 'line 3')
      fn.setline(4, 'line 4')
      feed('zfj')
      local ns = api.nvim_create_namespace('ns')
      api.nvim_buf_set_extmark(
        0,
        ns,
        0,
        0,
        { virt_lines_above = true, virt_lines = { { { 'virt_line above line 1', '' } } } }
      )
      api.nvim_buf_set_extmark(
        0,
        ns,
        1,
        0,
        { virt_lines = { { { 'virt_line below line 2', '' } } } }
      )
      api.nvim_buf_set_extmark(
        0,
        ns,
        2,
        0,
        { virt_lines_above = true, virt_lines = { { { 'virt_line above line 3', '' } } } }
      )
      api.nvim_buf_set_extmark(
        0,
        ns,
        3,
        0,
        { virt_lines = { { { 'virt_line below line 4', '' } } } }
      )
      if multigrid then
        screen:expect {
          grid = [[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {5:^+--  2 lines: line 1·························}|
          virt_line above line 3                       |
          line 3                                       |
          line 4                                       |
          virt_line below line 4                       |
          {1:~                                            }|*2
        ## grid 3
                                                       |
        ]],
          win_viewport = {
            [2] = {
              win = 1000,
              topline = 0,
              botline = 5,
              curline = 0,
              curcol = 0,
              linecount = 4,
              sum_scroll_delta = 0,
            },
          },
        }
      else
        screen:expect([[
          {5:^+--  2 lines: line 1·························}|
          virt_line above line 3                       |
          line 3                                       |
          line 4                                       |
          virt_line below line 4                       |
          {1:~                                            }|*2
                                                       |
        ]])
      end

      feed('jzfj')
      if multigrid then
        screen:expect {
          grid = [[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {5:+--  2 lines: line 1·························}|
          {5:^+--  2 lines: line 3·························}|
          {1:~                                            }|*5
        ## grid 3
                                                       |
        ]],
          win_viewport = {
            [2] = {
              win = 1000,
              topline = 0,
              botline = 5,
              curline = 2,
              curcol = 0,
              linecount = 4,
              sum_scroll_delta = 0,
            },
          },
        }
      else
        screen:expect([[
          {5:+--  2 lines: line 1·························}|
          {5:^+--  2 lines: line 3·························}|
          {1:~                                            }|*5
                                                       |
        ]])
      end

      feed('kzo<C-Y>')
      fn.setline(5, 'line 5')
      if multigrid then
        screen:expect {
          grid = [[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          virt_line above line 1                       |
          ^line 1                                       |
          line 2                                       |
          virt_line below line 2                       |
          {5:+--  2 lines: line 3·························}|
          line 5                                       |
          {1:~                                            }|
        ## grid 3
                                                       |
        ]],
          win_viewport = {
            [2] = {
              win = 1000,
              topline = 0,
              botline = 6,
              curline = 0,
              curcol = 0,
              linecount = 5,
              sum_scroll_delta = -1,
            },
          },
        }
      else
        screen:expect([[
          virt_line above line 1                       |
          ^line 1                                       |
          line 2                                       |
          virt_line below line 2                       |
          {5:+--  2 lines: line 3·························}|
          line 5                                       |
          {1:~                                            }|
                                                       |
        ]])
      end

      api.nvim_input_mouse('left', 'press', '', multigrid and 2 or 0, 4, 0)
      eq({
        screencol = 1,
        screenrow = 5,
        winid = 1000,
        wincol = 1,
        winrow = 5,
        line = 3,
        column = 1,
        coladd = 0,
      }, fn.getmousepos())

      api.nvim_buf_set_extmark(
        0,
        ns,
        1,
        0,
        { virt_lines = { { { 'more virt_line below line 2', '' } } } }
      )
      feed('G<C-E>')
      if multigrid then
        screen:expect {
          grid = [[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          line 1                                       |
          line 2                                       |
          virt_line below line 2                       |
          more virt_line below line 2                  |
          {5:+--  2 lines: line 3·························}|
          ^line 5                                       |
          {1:~                                            }|
        ## grid 3
                                                       |
        ]],
          win_viewport = {
            [2] = {
              win = 1000,
              topline = 0,
              botline = 6,
              curline = 4,
              curcol = 0,
              linecount = 5,
              sum_scroll_delta = 0,
            },
          },
        }
      else
        screen:expect([[
          line 1                                       |
          line 2                                       |
          virt_line below line 2                       |
          more virt_line below line 2                  |
          {5:+--  2 lines: line 3·························}|
          ^line 5                                       |
          {1:~                                            }|
                                                       |
        ]])
      end

      feed('<C-E>')
      if multigrid then
        screen:expect {
          grid = [[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          line 2                                       |
          virt_line below line 2                       |
          more virt_line below line 2                  |
          {5:+--  2 lines: line 3·························}|
          ^line 5                                       |
          {1:~                                            }|*2
        ## grid 3
                                                       |
        ]],
          win_viewport = {
            [2] = {
              win = 1000,
              topline = 1,
              botline = 6,
              curline = 4,
              curcol = 0,
              linecount = 5,
              sum_scroll_delta = 1,
            },
          },
        }
      else
        screen:expect([[
          line 2                                       |
          virt_line below line 2                       |
          more virt_line below line 2                  |
          {5:+--  2 lines: line 3·························}|
          ^line 5                                       |
          {1:~                                            }|*2
                                                       |
        ]])
      end

      feed('<C-E>')
      if multigrid then
        screen:expect {
          grid = [[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          virt_line below line 2                       |
          more virt_line below line 2                  |
          {5:+--  2 lines: line 3·························}|
          ^line 5                                       |
          {1:~                                            }|*3
        ## grid 3
                                                       |
        ]],
          win_viewport = {
            [2] = {
              win = 1000,
              topline = 2,
              botline = 6,
              curline = 4,
              curcol = 0,
              linecount = 5,
              sum_scroll_delta = 2,
            },
          },
        }
      else
        screen:expect([[
          virt_line below line 2                       |
          more virt_line below line 2                  |
          {5:+--  2 lines: line 3·························}|
          ^line 5                                       |
          {1:~                                            }|*3
                                                       |
        ]])
      end

      feed('<C-E>')
      if multigrid then
        screen:expect {
          grid = [[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          more virt_line below line 2                  |
          {5:+--  2 lines: line 3·························}|
          ^line 5                                       |
          {1:~                                            }|*4
        ## grid 3
                                                       |
        ]],
          win_viewport = {
            [2] = {
              win = 1000,
              topline = 2,
              botline = 6,
              curline = 4,
              curcol = 0,
              linecount = 5,
              sum_scroll_delta = 3,
            },
          },
        }
      else
        screen:expect([[
          more virt_line below line 2                  |
          {5:+--  2 lines: line 3·························}|
          ^line 5                                       |
          {1:~                                            }|*4
                                                       |
        ]])
      end

      feed('<C-E>')
      if multigrid then
        screen:expect {
          grid = [[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {5:+--  2 lines: line 3·························}|
          ^line 5                                       |
          {1:~                                            }|*5
        ## grid 3
                                                       |
        ]],
          win_viewport = {
            [2] = {
              win = 1000,
              topline = 2,
              botline = 6,
              curline = 4,
              curcol = 0,
              linecount = 5,
              sum_scroll_delta = 4,
            },
          },
        }
      else
        screen:expect([[
          {5:+--  2 lines: line 3·························}|
          ^line 5                                       |
          {1:~                                            }|*5
                                                       |
        ]])
      end

      feed('<C-E>')
      if multigrid then
        screen:expect {
          grid = [[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          ^line 5                                       |
          {1:~                                            }|*6
        ## grid 3
                                                       |
        ]],
          win_viewport = {
            [2] = {
              win = 1000,
              topline = 4,
              botline = 6,
              curline = 4,
              curcol = 0,
              linecount = 5,
              sum_scroll_delta = 5,
            },
          },
        }
      else
        screen:expect([[
          ^line 5                                       |
          {1:~                                            }|*6
                                                       |
        ]])
      end

      feed('3<C-Y>')
      if multigrid then
        screen:expect {
          grid = [[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          virt_line below line 2                       |
          more virt_line below line 2                  |
          {5:+--  2 lines: line 3·························}|
          ^line 5                                       |
          {1:~                                            }|*3
        ## grid 3
                                                       |
        ]],
          win_viewport = {
            [2] = {
              win = 1000,
              topline = 2,
              botline = 6,
              curline = 4,
              curcol = 0,
              linecount = 5,
              sum_scroll_delta = 2,
            },
          },
        }
      else
        screen:expect([[
          virt_line below line 2                       |
          more virt_line below line 2                  |
          {5:+--  2 lines: line 3·························}|
          ^line 5                                       |
          {1:~                                            }|*3
                                                       |
        ]])
      end

      api.nvim_input_mouse('left', 'press', '3', multigrid and 2 or 0, 3, 0)
      if multigrid then
        screen:expect {
          grid = [[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          virt_line below line 2                       |
          more virt_line below line 2                  |
          {5:+--  2 lines: line 3·························}|
          ^l{16:ine 5}                                       |
          {1:~                                            }|*3
        ## grid 3
          {11:-- VISUAL LINE --}                            |
        ]],
          win_viewport = {
            [2] = {
              win = 1000,
              topline = 2,
              botline = 6,
              curline = 4,
              curcol = 0,
              linecount = 5,
              sum_scroll_delta = 2,
            },
          },
        }
      else
        screen:expect([[
          virt_line below line 2                       |
          more virt_line below line 2                  |
          {5:+--  2 lines: line 3·························}|
          ^l{16:ine 5}                                       |
          {1:~                                            }|*3
          {11:-- VISUAL LINE --}                            |
        ]])
      end

      api.nvim_input_mouse('left', 'drag', '3', multigrid and 2 or 0, 7, 0)
      if multigrid then
        screen:expect {
          grid = [[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          more virt_line below line 2                  |
          {5:+--  2 lines: line 3·························}|
          ^l{16:ine 5}                                       |
          {1:~                                            }|*4
        ## grid 3
          {11:-- VISUAL LINE --}                            |
        ]],
          win_viewport = {
            [2] = {
              win = 1000,
              topline = 2,
              botline = 6,
              curline = 4,
              curcol = 0,
              linecount = 5,
              sum_scroll_delta = 3,
            },
          },
        }
      else
        screen:expect([[
          more virt_line below line 2                  |
          {5:+--  2 lines: line 3·························}|
          ^l{16:ine 5}                                       |
          {1:~                                            }|*4
          {11:-- VISUAL LINE --}                            |
        ]])
      end

      api.nvim_input_mouse('left', 'drag', '3', multigrid and 2 or 0, 7, 5)
      if multigrid then
        screen:expect {
          grid = [[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {5:+--  2 lines: line 3·························}|
          {16:line }^5                                       |
          {1:~                                            }|*5
        ## grid 3
          {11:-- VISUAL LINE --}                            |
        ]],
          win_viewport = {
            [2] = {
              win = 1000,
              topline = 2,
              botline = 6,
              curline = 4,
              curcol = 5,
              linecount = 5,
              sum_scroll_delta = 4,
            },
          },
        }
      else
        screen:expect([[
          {5:+--  2 lines: line 3·························}|
          {16:line }^5                                       |
          {1:~                                            }|*5
          {11:-- VISUAL LINE --}                            |
        ]])
      end

      feed('<Esc>gg')
      command('botright 1split | wincmd w')
      if multigrid then
        screen:expect {
          grid = [[
        ## grid 1
          [2:---------------------------------------------]|*4
          {3:[No Name] [+]                                }|
          [4:---------------------------------------------]|
          {2:[No Name] [+]                                }|
          [3:---------------------------------------------]|
        ## grid 2
          ^line 1                                       |
          line 2                                       |
          virt_line below line 2                       |
          more virt_line below line 2                  |
        ## grid 3
                                                       |
        ## grid 4
          line 1                                       |
        ]],
          win_viewport = {
            [2] = {
              win = 1000,
              topline = 0,
              botline = 3,
              curline = 0,
              curcol = 0,
              linecount = 5,
              sum_scroll_delta = 0,
            },
            [4] = {
              win = 1001,
              topline = 0,
              botline = 2,
              curline = 0,
              curcol = 0,
              linecount = 5,
              sum_scroll_delta = 0,
            },
          },
        }
      else
        screen:expect([[
          ^line 1                                       |
          line 2                                       |
          virt_line below line 2                       |
          more virt_line below line 2                  |
          {3:[No Name] [+]                                }|
          line 1                                       |
          {2:[No Name] [+]                                }|
                                                       |
        ]])
      end

      feed('<C-Y>')
      if multigrid then
        screen:expect {
          grid = [[
        ## grid 1
          [2:---------------------------------------------]|*4
          {3:[No Name] [+]                                }|
          [4:---------------------------------------------]|
          {2:[No Name] [+]                                }|
          [3:---------------------------------------------]|
        ## grid 2
          virt_line above line 1                       |
          ^line 1                                       |
          line 2                                       |
          virt_line below line 2                       |
        ## grid 3
                                                       |
        ## grid 4
          line 1                                       |
        ]],
          win_viewport = {
            [2] = {
              win = 1000,
              topline = 0,
              botline = 3,
              curline = 0,
              curcol = 0,
              linecount = 5,
              sum_scroll_delta = -1,
            },
            [4] = {
              win = 1001,
              topline = 0,
              botline = 2,
              curline = 0,
              curcol = 0,
              linecount = 5,
              sum_scroll_delta = 0,
            },
          },
        }
      else
        screen:expect([[
          virt_line above line 1                       |
          ^line 1                                       |
          line 2                                       |
          virt_line below line 2                       |
          {3:[No Name] [+]                                }|
          line 1                                       |
          {2:[No Name] [+]                                }|
                                                       |
        ]])
      end
    end)

    it('Folded and Visual highlights are combined #19691', function()
      command('hi! Visual guibg=Red')
      insert([[
        " foofoofoofoofoofoo
        " 口 {{{1
        set nocp
        " }}}1
        " barbarbarbarbarbar
        " 口 {{{1
        set foldmethod=marker
        " }}}1
        " bazbazbazbazbazbaz]])
      feed('gg')
      command('source')
      feed('<C-V>G15l')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {14:" foofoofoofoofo}ofoo                         |
          {15:+--  3 lines: " }{5:口···························}|
          {14:" barbarbarbarba}rbar                         |
          {15:+--  3 lines: " }{5:口···························}|
          {14:" bazbazbazbazb}^azbaz                         |
          {1:~                                            }|*2
        ## grid 3
          {11:-- VISUAL BLOCK --}                           |
        ]])
      else
        screen:expect([[
          {14:" foofoofoofoofo}ofoo                         |
          {15:+--  3 lines: " }{5:口···························}|
          {14:" barbarbarbarba}rbar                         |
          {15:+--  3 lines: " }{5:口···························}|
          {14:" bazbazbazbazb}^azbaz                         |
          {1:~                                            }|*2
          {11:-- VISUAL BLOCK --}                           |
        ]])
      end

      feed('l')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {14:" foofoofoofoofoo}foo                         |
          {15:+--  3 lines: " 口}{5:···························}|
          {14:" barbarbarbarbar}bar                         |
          {15:+--  3 lines: " 口}{5:···························}|
          {14:" bazbazbazbazba}^zbaz                         |
          {1:~                                            }|*2
        ## grid 3
          {11:-- VISUAL BLOCK --}                           |
        ]])
      else
        screen:expect([[
          {14:" foofoofoofoofoo}foo                         |
          {15:+--  3 lines: " 口}{5:···························}|
          {14:" barbarbarbarbar}bar                         |
          {15:+--  3 lines: " 口}{5:···························}|
          {14:" bazbazbazbazba}^zbaz                         |
          {1:~                                            }|*2
          {11:-- VISUAL BLOCK --}                           |
        ]])
      end

      feed('l')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {14:" foofoofoofoofoof}oo                         |
          {15:+--  3 lines: " 口}{5:···························}|
          {14:" barbarbarbarbarb}ar                         |
          {15:+--  3 lines: " 口}{5:···························}|
          {14:" bazbazbazbazbaz}^baz                         |
          {1:~                                            }|*2
        ## grid 3
          {11:-- VISUAL BLOCK --}                           |
        ]])
      else
        screen:expect([[
          {14:" foofoofoofoofoof}oo                         |
          {15:+--  3 lines: " 口}{5:···························}|
          {14:" barbarbarbarbarb}ar                         |
          {15:+--  3 lines: " 口}{5:···························}|
          {14:" bazbazbazbazbaz}^baz                         |
          {1:~                                            }|*2
          {11:-- VISUAL BLOCK --}                           |
        ]])
      end

      feed('2l')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {14:" foofoofoofoofoofoo}                         |
          {15:+--  3 lines: " 口··}{5:·························}|
          {14:" barbarbarbarbarbar}                         |
          {15:+--  3 lines: " 口··}{5:·························}|
          {14:" bazbazbazbazbazba}^z                         |
          {1:~                                            }|*2
        ## grid 3
          {11:-- VISUAL BLOCK --}                           |
        ]])
      else
        screen:expect([[
          {14:" foofoofoofoofoofoo}                         |
          {15:+--  3 lines: " 口··}{5:·························}|
          {14:" barbarbarbarbarbar}                         |
          {15:+--  3 lines: " 口··}{5:·························}|
          {14:" bazbazbazbazbazba}^z                         |
          {1:~                                            }|*2
          {11:-- VISUAL BLOCK --}                           |
        ]])
      end

      feed('O16l')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          " foofoofoofoofo{14:ofoo}                         |
          {5:+--  3 lines: " }{15:口··}{5:·························}|
          " barbarbarbarba{14:rbar}                         |
          {5:+--  3 lines: " }{15:口··}{5:·························}|
          " bazbazbazbazba^z{14:baz}                         |
          {1:~                                            }|*2
        ## grid 3
          {11:-- VISUAL BLOCK --}                           |
        ]])
      else
        screen:expect([[
          " foofoofoofoofo{14:ofoo}                         |
          {5:+--  3 lines: " }{15:口··}{5:·························}|
          " barbarbarbarba{14:rbar}                         |
          {5:+--  3 lines: " }{15:口··}{5:·························}|
          " bazbazbazbazba^z{14:baz}                         |
          {1:~                                            }|*2
          {11:-- VISUAL BLOCK --}                           |
        ]])
      end

      feed('l')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          " foofoofoofoofoo{14:foo}                         |
          {5:+--  3 lines: " }{15:口··}{5:·························}|
          " barbarbarbarbar{14:bar}                         |
          {5:+--  3 lines: " }{15:口··}{5:·························}|
          " bazbazbazbazbaz^b{14:az}                         |
          {1:~                                            }|*2
        ## grid 3
          {11:-- VISUAL BLOCK --}                           |
        ]])
      else
        screen:expect([[
          " foofoofoofoofoo{14:foo}                         |
          {5:+--  3 lines: " }{15:口··}{5:·························}|
          " barbarbarbarbar{14:bar}                         |
          {5:+--  3 lines: " }{15:口··}{5:·························}|
          " bazbazbazbazbaz^b{14:az}                         |
          {1:~                                            }|*2
          {11:-- VISUAL BLOCK --}                           |
        ]])
      end
    end)

    it('do not show search or match highlight #24084', function()
      insert([[
        line 1
        line 2
        line 3
        line 4]])
      command('2,3fold')
      feed('/line')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {2:line} 1                                       |
          {5:+--  2 lines: line 2·························}|
          {6:line} 4                                       |
          {1:~                                            }|*4
        ## grid 3
          /line^                                        |
        ]])
      else
        screen:expect([[
          {2:line} 1                                       |
          {5:+--  2 lines: line 2·························}|
          {6:line} 4                                       |
          {1:~                                            }|*4
          /line^                                        |
        ]])
      end
      feed('<Esc>')
      fn.matchadd('Search', 'line')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|*7
          [3:---------------------------------------------]|
        ## grid 2
          {6:line} 1                                       |
          {5:+--  2 lines: line 2·························}|
          {6:line} ^4                                       |
          {1:~                                            }|*4
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          {6:line} 1                                       |
          {5:+--  2 lines: line 2·························}|
          {6:line} ^4                                       |
          {1:~                                            }|*4
                                                       |
        ]])
      end
    end)

    it('foldtext with virtual text format', function()
      screen:try_resize(30, 7)
      insert(content1)
      command('hi! CursorLine guibg=NONE guifg=Red gui=NONE')
      command('hi F0 guibg=Red guifg=Black')
      command('hi F1 guifg=White')
      api.nvim_set_option_value('cursorline', true, {})
      api.nvim_set_option_value('foldcolumn', '4', {})
      api.nvim_set_option_value(
        'foldtext',
        '['
          .. '["▶", ["F0", "F1"]], '
          .. '[v:folddashes], '
          .. '["\t", "Search"], '
          .. '[getline(v:foldstart), "NonText"]]',
        {}
      )

      command('3,4fold')
      command('5,6fold')
      command('2,6fold')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:------------------------------]|*6
          [3:------------------------------]|
        ## grid 2
          {7:    }This is a                 |
          {7:+   }{4:^▶}{13:-}{17:      }{18:valid English}{13:·····}|
          {1:~                             }|*4
        ## grid 3
                                        |
        ]])
      else
        screen:expect([[
          {7:    }This is a                 |
          {7:+   }{4:^▶}{13:-}{17:      }{18:valid English}{13:·····}|
          {1:~                             }|*4
                                        |
        ]])
      end
      eq('▶-\tvalid English', fn.foldtextresult(2))

      feed('zo')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:------------------------------]|*6
          [3:------------------------------]|
        ## grid 2
          {7:    }This is a                 |
          {7:-   }valid English             |
          {7:│+  }{4:▶}{5:--}{19:     }{18:sentence composed }|
          {7:│+  }{4:^▶}{13:--}{17:     }{18:in his cave.}{13:······}|
          {1:~                             }|*2
        ## grid 3
                                        |
        ]])
      else
        screen:expect([[
          {7:    }This is a                 |
          {7:-   }valid English             |
          {7:│+  }{4:▶}{5:--}{19:     }{18:sentence composed }|
          {7:│+  }{4:^▶}{13:--}{17:     }{18:in his cave.}{13:······}|
          {1:~                             }|*2
                                        |
        ]])
      end
      eq('▶--\tsentence composed by', fn.foldtextresult(3))
      eq('▶--\tin his cave.', fn.foldtextresult(5))

      command('hi! Visual guibg=Red')
      feed('V2k')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:------------------------------]|*6
          [3:------------------------------]|
        ## grid 2
          {7:    }This is a                 |
          {7:-   }^v{14:alid English}             |
          {7:│+  }{4:▶}{15:--}{19:     }{20:sentence composed }|
          {7:│+  }{4:▶}{15:--}{19:     }{20:in his cave.}{15:······}|
          {1:~                             }|*2
        ## grid 3
          {11:-- VISUAL LINE --}             |
        ]])
      else
        screen:expect([[
          {7:    }This is a                 |
          {7:-   }^v{14:alid English}             |
          {7:│+  }{4:▶}{15:--}{19:     }{20:sentence composed }|
          {7:│+  }{4:▶}{15:--}{19:     }{20:in his cave.}{15:······}|
          {1:~                             }|*2
          {11:-- VISUAL LINE --}             |
        ]])
      end

      api.nvim_set_option_value('rightleft', true, {})
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:------------------------------]|*6
          [3:------------------------------]|
        ## grid 2
                           a si sihT{7:    }|
                       {14:hsilgnE dila}^v{7:   -}|
          {20: desopmoc ecnetnes}{19:     }{15:--}{4:▶}{7:  +│}|
          {15:······}{20:.evac sih ni}{19:     }{15:--}{4:▶}{7:  +│}|
          {1:                             ~}|*2
        ## grid 3
          {11:-- VISUAL LINE --}             |
        ]])
      else
        screen:expect([[
                           a si sihT{7:    }|
                       {14:hsilgnE dila}^v{7:   -}|
          {20: desopmoc ecnetnes}{19:     }{15:--}{4:▶}{7:  +│}|
          {15:······}{20:.evac sih ni}{19:     }{15:--}{4:▶}{7:  +│}|
          {1:                             ~}|*2
          {11:-- VISUAL LINE --}             |
        ]])
      end
    end)

    it('transparent foldtext', function()
      screen:try_resize(30, 7)
      insert(content1)
      command('hi! CursorLine guibg=NONE guifg=Red gui=NONE')
      command('hi F0 guibg=Red guifg=Black')
      command('hi F1 guifg=White')
      api.nvim_set_option_value('cursorline', true, {})
      api.nvim_set_option_value('foldcolumn', '4', {})
      api.nvim_set_option_value('foldtext', '', {})

      command('3,4fold')
      command('5,6fold')
      command('2,6fold')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:------------------------------]|*6
          [3:------------------------------]|
        ## grid 2
          {7:    }This is a                 |
          {7:+   }{13:^valid English·············}|
          {1:~                             }|*4
        ## grid 3
                                        |
        ]])
      else
        screen:expect([[
          {7:    }This is a                 |
          {7:+   }{13:^valid English·············}|
          {1:~                             }|*4
                                        |
        ]])
      end

      feed('zo')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:------------------------------]|*6
          [3:------------------------------]|
        ## grid 2
          {7:    }This is a                 |
          {7:-   }valid English             |
          {7:│+  }{5:sentence composed by······}|
          {7:│+  }{13:^in his cave.··············}|
          {1:~                             }|*2
        ## grid 3
                                        |
        ]])
      else
        screen:expect([[
          {7:    }This is a                 |
          {7:-   }valid English             |
          {7:│+  }{5:sentence composed by······}|
          {7:│+  }{13:^in his cave.··············}|
          {1:~                             }|*2
                                        |
        ]])
      end

      command('hi! Visual guibg=Red')
      feed('V2k')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:------------------------------]|*6
          [3:------------------------------]|
        ## grid 2
          {7:    }This is a                 |
          {7:-   }^v{14:alid English}             |
          {7:│+  }{15:sentence composed by······}|
          {7:│+  }{15:in his cave.··············}|
          {1:~                             }|*2
        ## grid 3
          {11:-- VISUAL LINE --}             |
        ]])
      else
        screen:expect([[
          {7:    }This is a                 |
          {7:-   }^v{14:alid English}             |
          {7:│+  }{15:sentence composed by······}|
          {7:│+  }{15:in his cave.··············}|
          {1:~                             }|*2
          {11:-- VISUAL LINE --}             |
        ]])
      end

      api.nvim_set_option_value('rightleft', true, {})
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:------------------------------]|*6
          [3:------------------------------]|
        ## grid 2
                           a si sihT{7:    }|
                       {14:hsilgnE dila}^v{7:   -}|
          {15:······yb desopmoc ecnetnes}{7:  +│}|
          {15:··············.evac sih ni}{7:  +│}|
          {1:                             ~}|*2
        ## grid 3
          {11:-- VISUAL LINE --}             |
        ]])
      else
        screen:expect([[
                           a si sihT{7:    }|
                       {14:hsilgnE dila}^v{7:   -}|
          {15:······yb desopmoc ecnetnes}{7:  +│}|
          {15:··············.evac sih ni}{7:  +│}|
          {1:                             ~}|*2
          {11:-- VISUAL LINE --}             |
        ]])
      end
    end)
  end

  describe('with ext_multigrid', function()
    with_ext_multigrid(true)
  end)

  describe('without ext_multigrid', function()
    with_ext_multigrid(false)
  end)
end)
