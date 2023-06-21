local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, eq = helpers.clear, helpers.feed, helpers.eq
local command = helpers.command
local feed_command = helpers.feed_command
local insert = helpers.insert
local funcs = helpers.funcs
local meths = helpers.meths
local exec = helpers.exec
local assert_alive = helpers.assert_alive


local content1 = [[
        This is a
        valid English
        sentence composed by
        an exhausted developer
        in his cave.
        ]]

describe("folded lines", function()
  before_each(function()
    clear()
    command('hi VertSplit gui=reverse')
  end)

  local function with_ext_multigrid(multigrid)
    local screen
    before_each(function()
      screen = Screen.new(45, 8)
      screen:attach({rgb=true, ext_multigrid=multigrid})
      screen:set_default_attr_ids({
        [1] = {bold = true, foreground = Screen.colors.Blue1},
        [2] = {reverse = true},
        [3] = {bold = true, reverse = true},
        [4] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
        [5] = {foreground = Screen.colors.DarkBlue, background = Screen.colors.LightGrey},
        [6] = {background = Screen.colors.Yellow},
        [7] = {foreground = Screen.colors.DarkBlue, background = Screen.colors.WebGray},
        [8] = {foreground = Screen.colors.Brown },
        [9] = {bold = true, foreground = Screen.colors.Brown},
        [10] = {background = Screen.colors.LightGrey, underline = true},
        [11] = {bold=true},
        [12] = {foreground = Screen.colors.Red},
        [13] = {foreground = Screen.colors.Red, background = Screen.colors.LightGrey},
        [14] = {background = Screen.colors.Red},
        [15] = {foreground = Screen.colors.DarkBlue, background = Screen.colors.Red},
        [16] = {background = Screen.colors.LightGrey},
      })
    end)

    it("work with more than one signcolumn", function()
      command("set signcolumn=yes:9")
      feed("i<cr><esc>")
      feed("vkzf")
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          {7:                  }{5:^+--  2 lines: ·············}|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          {7:                  }{5:^+--  2 lines: ·············}|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
                                                       |
        ]])
      end
    end)

    local function test_folded_cursorline()
      command("set number cursorline foldcolumn=2")
      command("hi link CursorLineFold Search")
      insert(content1)
      feed("ggzf3jj")
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          {7:+ }{8:  1 }{5:+--  4 lines: This is a················}|
          {6:  }{9:  5 }{12:^in his cave.                           }|
          {7:  }{8:  6 }                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          {7:+ }{8:  1 }{5:+--  4 lines: This is a················}|
          {6:  }{9:  5 }{12:^in his cave.                           }|
          {7:  }{8:  6 }                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
                                                       |
        ]])
      end
      feed("k")
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          {6:+ }{9:  1 }{13:^+--  4 lines: This is a················}|
          {7:  }{8:  5 }in his cave.                           |
          {7:  }{8:  6 }                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          {6:+ }{9:  1 }{13:^+--  4 lines: This is a················}|
          {7:  }{8:  5 }in his cave.                           |
          {7:  }{8:  6 }                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
                                                       |
        ]])
      end
      -- CursorLine is applied correctly with screenrow motions #22232
      feed("jgk")
      screen:expect_unchanged(true)
      -- CursorLine is applied correctly when closing a fold when cursor is not at fold start
      feed("zo4Gzc")
      screen:expect_unchanged(true)
      command("set cursorlineopt=line")
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          {7:+ }{8:  1 }{13:^+--  4 lines: This is a················}|
          {7:  }{8:  5 }in his cave.                           |
          {7:  }{8:  6 }                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          {7:+ }{8:  1 }{13:^+--  4 lines: This is a················}|
          {7:  }{8:  5 }in his cave.                           |
          {7:  }{8:  6 }                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
                                                       |
        ]])
      end
      command("set relativenumber cursorlineopt=number")
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          {6:+ }{9:1   }{5:^+--  4 lines: This is a················}|
          {7:  }{8:  1 }in his cave.                           |
          {7:  }{8:  2 }                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          {6:+ }{9:1   }{5:^+--  4 lines: This is a················}|
          {7:  }{8:  1 }in his cave.                           |
          {7:  }{8:  2 }                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
                                                       |
        ]])
      end
    end

    describe("when 'cursorline' is set", function()
      it('with high-priority CursorLine', function()
        command("hi! CursorLine guibg=NONE guifg=Red gui=NONE")
        test_folded_cursorline()
      end)

      it('with low-priority CursorLine', function()
        command("hi! CursorLine guibg=NONE guifg=NONE gui=underline")
        local attrs = screen:get_default_attr_ids()
        attrs[12] = {underline = true}
        attrs[13] = {foreground = Screen.colors.DarkBlue, background = Screen.colors.LightGrey, underline = true}
        screen:set_default_attr_ids(attrs)
        test_folded_cursorline()
      end)
    end)

    it("work with spell", function()
      command("set spell")
      insert(content1)

      feed("gg")
      feed("zf3j")
      if not multigrid then
        screen:expect{grid=[[
          {5:^+--  4 lines: This is a······················}|
          in his cave.                                 |
                                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
                                                       |
        ]]}
      end
    end)

    it("work with matches", function()
      insert(content1)
      command("highlight MyWord gui=bold guibg=red   guifg=white")
      command("call matchadd('MyWord', '\\V' . 'test', -1)")
      feed("gg")
      feed("zf3j")
      if not multigrid then
        screen:expect{grid=[[
          {5:^+--  4 lines: This is a······················}|
          in his cave.                                 |
                                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
                                                       |
        ]]}
      end
    end)

    it("works with multibyte fillchars", function()
      insert([[
        aa
        bb
        cc
        dd
        ee
        ff]])
      command("set fillchars+=foldopen:▾,foldsep:│,foldclose:▸")
      feed_command('1')
      command("set foldcolumn=2")
      feed('zf4j')
      feed('zf2j')
      feed('zO')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
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

      feed_command("set rightleft")
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
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

      feed_command("set norightleft")
      if multigrid then
        meths.input_mouse('left', 'press', '', 2, 0, 1)
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          {7:▾▸}{5:^+---  5 lines: aa··························}|
          {7:│ }ff                                         |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
          :set norightleft                             |
        ]])
      else
        meths.input_mouse('left', 'press', '', 0, 0, 1)
        screen:expect([[
          {7:▾▸}{5:^+---  5 lines: aa··························}|
          {7:│ }ff                                         |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          :set norightleft                             |
        ]])
      end
    end)

    it("works with split", function()
      insert([[
        aa
        bb
        cc
        dd
        ee
        ff]])
      feed_command('2')
      command("set foldcolumn=1")
      feed('zf3j')
      feed_command('1')
      feed('zf2j')
      feed('zO')
      feed_command("rightbelow new")
      insert([[
        aa
        bb
        cc
        dd
        ee
        ff]])
      feed_command('2')
      command("set foldcolumn=1")
      feed('zf3j')
      feed_command('1')
      feed('zf2j')
      if multigrid then
        meths.input_mouse('left', 'press', '', 4, 0, 0)
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          {2:[No Name] [+]                                }|
          [4:---------------------------------------------]|
          [4:---------------------------------------------]|
          [4:---------------------------------------------]|
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
        meths.input_mouse('left', 'press', '', 0, 3, 0)
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
        meths.input_mouse('left', 'press', '', 4, 1, 0)
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          {2:[No Name] [+]                                }|
          [4:---------------------------------------------]|
          [4:---------------------------------------------]|
          [4:---------------------------------------------]|
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
        meths.input_mouse('left', 'press', '', 0, 4, 0)
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
        meths.input_mouse('left', 'press', '', 2, 1, 0)
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          {3:[No Name] [+]                                }|
          [4:---------------------------------------------]|
          [4:---------------------------------------------]|
          [4:---------------------------------------------]|
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
        meths.input_mouse('left', 'press', '', 0, 1, 0)
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
        meths.input_mouse('left', 'press', '', 2, 0, 0)
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          {3:[No Name] [+]                                }|
          [4:---------------------------------------------]|
          [4:---------------------------------------------]|
          [4:---------------------------------------------]|
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
        meths.input_mouse('left', 'press', '', 0, 0, 0)
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

    it("works with vsplit", function()
      insert([[
        aa
        bb
        cc
        dd
        ee
        ff]])
      feed_command('2')
      command("set foldcolumn=1")
      feed('zf3j')
      feed_command('1')
      feed('zf2j')
      feed('zO')
      feed_command("rightbelow vnew")
      insert([[
        aa
        bb
        cc
        dd
        ee
        ff]])
      feed_command('2')
      command("set foldcolumn=1")
      feed('zf3j')
      feed_command('1')
      feed('zf2j')
      if multigrid then
        meths.input_mouse('left', 'press', '', 4, 0, 0)
        screen:expect([[
        ## grid 1
          [2:----------------------]{2:│}[4:----------------------]|
          [2:----------------------]{2:│}[4:----------------------]|
          [2:----------------------]{2:│}[4:----------------------]|
          [2:----------------------]{2:│}[4:----------------------]|
          [2:----------------------]{2:│}[4:----------------------]|
          [2:----------------------]{2:│}[4:----------------------]|
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
          {1:~                     }|
          {1:~                     }|
          {1:~                     }|
        ]])
      else
        meths.input_mouse('left', 'press', '', 0, 0, 23)
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
        meths.input_mouse('left', 'press', '', 4, 1, 0)
        screen:expect([[
        ## grid 1
          [2:----------------------]{2:│}[4:----------------------]|
          [2:----------------------]{2:│}[4:----------------------]|
          [2:----------------------]{2:│}[4:----------------------]|
          [2:----------------------]{2:│}[4:----------------------]|
          [2:----------------------]{2:│}[4:----------------------]|
          [2:----------------------]{2:│}[4:----------------------]|
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
        meths.input_mouse('left', 'press', '', 0, 1, 23)
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
        meths.input_mouse('left', 'press', '', 2, 1, 0)
        screen:expect([[
        ## grid 1
          [2:----------------------]{2:│}[4:----------------------]|
          [2:----------------------]{2:│}[4:----------------------]|
          [2:----------------------]{2:│}[4:----------------------]|
          [2:----------------------]{2:│}[4:----------------------]|
          [2:----------------------]{2:│}[4:----------------------]|
          [2:----------------------]{2:│}[4:----------------------]|
          {3:[No Name] [+]          }{2:[No Name] [+]         }|
          [3:---------------------------------------------]|
        ## grid 2
          {7:-}aa                   |
          {7:+}{5:^+---  4 lines: bb····}|
          {7:│}ff                   |
          {1:~                     }|
          {1:~                     }|
          {1:~                     }|
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
        meths.input_mouse('left', 'press', '', 0, 1, 0)
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
        meths.input_mouse('left', 'press', '', 2, 0, 0)
        screen:expect([[
        ## grid 1
          [2:----------------------]{2:│}[4:----------------------]|
          [2:----------------------]{2:│}[4:----------------------]|
          [2:----------------------]{2:│}[4:----------------------]|
          [2:----------------------]{2:│}[4:----------------------]|
          [2:----------------------]{2:│}[4:----------------------]|
          [2:----------------------]{2:│}[4:----------------------]|
          {3:[No Name] [+]          }{2:[No Name] [+]         }|
          [3:---------------------------------------------]|
        ## grid 2
          {7:+}{5:^+--  6 lines: aa·····}|
          {1:~                     }|
          {1:~                     }|
          {1:~                     }|
          {1:~                     }|
          {1:~                     }|
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
        meths.input_mouse('left', 'press', '', 0, 0, 0)
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

    it("works with tab", function()
      insert([[
        aa
        bb
        cc
        dd
        ee
        ff]])
      feed_command('2')
      command("set foldcolumn=2")
      feed('zf3j')
      feed_command('1')
      feed('zf2j')
      feed('zO')
      feed_command("tab split")
      if multigrid then
        meths.input_mouse('left', 'press', '', 4, 1, 1)
        screen:expect([[
        ## grid 1
          {10: + [No Name] }{11: + [No Name] }{2:                  }{10:X}|
          [4:---------------------------------------------]|
          [4:---------------------------------------------]|
          [4:---------------------------------------------]|
          [4:---------------------------------------------]|
          [4:---------------------------------------------]|
          [4:---------------------------------------------]|
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
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ]])
      else
        meths.input_mouse('left', 'press', '', 0, 2, 1)
        screen:expect([[
          {10: + [No Name] }{11: + [No Name] }{2:                  }{10:X}|
          {7:- }^aa                                         |
          {7:│+}{5:+---  4 lines: bb··························}|
          {7:│ }ff                                         |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          :tab split                                   |
        ]])
      end

      if multigrid then
        meths.input_mouse('left', 'press', '', 4, 0, 0)
        screen:expect([[
        ## grid 1
          {10: + [No Name] }{11: + [No Name] }{2:                  }{10:X}|
          [4:---------------------------------------------]|
          [4:---------------------------------------------]|
          [4:---------------------------------------------]|
          [4:---------------------------------------------]|
          [4:---------------------------------------------]|
          [4:---------------------------------------------]|
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
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ]])
      else
        meths.input_mouse('left', 'press', '', 0, 1, 0)
        screen:expect([[
          {10: + [No Name] }{11: + [No Name] }{2:                  }{10:X}|
          {7:+ }{5:^+--  6 lines: aa···························}|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          :tab split                                   |
        ]])
      end

      feed_command("tabnext")
      if multigrid then
        meths.input_mouse('left', 'press', '', 2, 1, 1)
        screen:expect([[
        ## grid 1
          {11: + [No Name] }{10: + [No Name] }{2:                  }{10:X}|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          {7:- }^aa                                         |
          {7:│+}{5:+---  4 lines: bb··························}|
          {7:│ }ff                                         |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
          :tabnext                                     |
        ## grid 4 (hidden)
          {7:+ }{5:+--  6 lines: aa···························}|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ]])
      else
        meths.input_mouse('left', 'press', '', 0, 2, 1)
        screen:expect([[
          {11: + [No Name] }{10: + [No Name] }{2:                  }{10:X}|
          {7:- }^aa                                         |
          {7:│+}{5:+---  4 lines: bb··························}|
          {7:│ }ff                                         |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          :tabnext                                     |
        ]])
      end

      if multigrid then
        meths.input_mouse('left', 'press', '', 2, 0, 0)
        screen:expect([[
        ## grid 1
          {11: + [No Name] }{10: + [No Name] }{2:                  }{10:X}|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          {7:+ }{5:^+--  6 lines: aa···························}|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
          :tabnext                                     |
        ## grid 4 (hidden)
          {7:+ }{5:+--  6 lines: aa···························}|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ]])
      else
        meths.input_mouse('left', 'press', '', 0, 1, 0)
        screen:expect([[
          {11: + [No Name] }{10: + [No Name] }{2:                  }{10:X}|
          {7:+ }{5:^+--  6 lines: aa···························}|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          :tabnext                                     |
        ]])
      end
    end)

    it("works with multibyte text", function()
      -- Currently the only allowed value of 'maxcombine'
      eq(6, meths.get_option_value('maxcombine', {}))
      eq(true, meths.get_option_value('arabicshape', {}))
      insert([[
        å 语 x̨̣̘̫̲͚͎̎͂̀̂͛͛̾͢͟ العَرَبِيَّة
        möre text]])
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          å 语 x̎͂̀̂͛͛ ﺎﻠﻋَﺮَﺒِﻳَّﺓ                               |
          möre tex^t                                    |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          å 语 x̎͂̀̂͛͛ ﺎﻠﻋَﺮَﺒِﻳَّﺓ                               |
          möre tex^t                                    |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
                                                       |
        ]])
      end

      feed('vkzf')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          {5:^+--  2 lines: å 语 x̎͂̀̂͛͛ العَرَبِيَّة·················}|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          {5:^+--  2 lines: å 语 x̎͂̀̂͛͛ العَرَبِيَّة·················}|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
                                                       |
        ]])
      end

      feed_command("set noarabicshape")
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          {5:^+--  2 lines: å 语 x̎͂̀̂͛͛ العَرَبِيَّة·················}|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
          :set noarabicshape                           |
        ]])
      else
        screen:expect([[
          {5:^+--  2 lines: å 语 x̎͂̀̂͛͛ العَرَبِيَّة·················}|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          :set noarabicshape                           |
        ]])
      end

      feed_command("set number foldcolumn=2")
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          {7:+ }{8:  1 }{5:^+--  2 lines: å 语 x̎͂̀̂͛͛ العَرَبِيَّة···········}|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
          :set number foldcolumn=2                     |
        ]])
      else
        screen:expect([[
          {7:+ }{8:  1 }{5:^+--  2 lines: å 语 x̎͂̀̂͛͛ العَرَبِيَّة···········}|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          :set number foldcolumn=2                     |
        ]])
      end

      -- Note: too much of the folded line gets cut off.This is a vim bug.
      feed_command("set rightleft")
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          {5:···········ةيَّبِرَعَلا x̎͂̀̂͛͛ 语 å :senil 2  --^+}{8: 1  }{7: +}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
        ## grid 3
          :set rightleft                               |
        ]])
      else
        screen:expect([[
          {5:···········ةيَّبِرَعَلا x̎͂̀̂͛͛ 语 å :senil 2  --^+}{8: 1  }{7: +}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          :set rightleft                               |
        ]])
      end

      feed_command("set nonumber foldcolumn=0")
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          {5:·················ةيَّبِرَعَلا x̎͂̀̂͛͛ 语 å :senil 2  --^+}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
        ## grid 3
          :set nonumber foldcolumn=0                   |
        ]])
      else
        screen:expect([[
          {5:·················ةيَّبِرَعَلا x̎͂̀̂͛͛ 语 å :senil 2  --^+}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          :set nonumber foldcolumn=0                   |
        ]])
      end

      feed_command("set arabicshape")
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          {5:·················ةيَّبِرَعَلا x̎͂̀̂͛͛ 语 å :senil 2  --^+}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
        ## grid 3
          :set arabicshape                             |
        ]])
      else
        screen:expect([[
          {5:·················ةيَّبِرَعَلا x̎͂̀̂͛͛ 语 å :senil 2  --^+}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          :set arabicshape                             |
        ]])
      end

      feed('zo')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
                                         ﺔﻴَّﺑِﺮَﻌَ^ﻟﺍ x̎͂̀̂͛͛ 语 å|
                                              txet eröm|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
        ## grid 3
          :set arabicshape                             |
        ]])
      else
        screen:expect([[
                                         ﺔﻴَّﺑِﺮَﻌَ^ﻟﺍ x̎͂̀̂͛͛ 语 å|
                                              txet eröm|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          :set arabicshape                             |
        ]])
      end

      feed_command('set noarabicshape')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
                                         ةيَّبِرَعَ^لا x̎͂̀̂͛͛ 语 å|
                                              txet eröm|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
        ## grid 3
          :set noarabicshape                           |
        ]])
      else
        screen:expect([[
                                         ةيَّبِرَعَ^لا x̎͂̀̂͛͛ 语 å|
                                              txet eröm|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          {1:                                            ~}|
          :set noarabicshape                           |
        ]])
      end

    end)

    it("work in cmdline window", function()
      feed_command("set foldmethod=manual")
      feed_command("let x = 1")
      feed_command("/alpha")
      feed_command("/omega")

      feed("<cr>q:")
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          {2:[No Name]                                    }|
          [4:---------------------------------------------]|
          [4:---------------------------------------------]|
          [4:---------------------------------------------]|
          [4:---------------------------------------------]|
          {3:[Command Line]                               }|
          [3:---------------------------------------------]|
        ## grid 2
                                                       |
        ## grid 3
          :                                            |
        ## grid 4
          {1::}set foldmethod=manual                       |
          {1::}let x = 1                                   |
          {1::}^                                            |
          {1:~                                            }|
        ]])
      else
        screen:expect([[
                                                       |
          {2:[No Name]                                    }|
          {1::}set foldmethod=manual                       |
          {1::}let x = 1                                   |
          {1::}^                                            |
          {1:~                                            }|
          {3:[Command Line]                               }|
          :                                            |
        ]])
      end

      feed("kzfk")
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          {2:[No Name]                                    }|
          [4:---------------------------------------------]|
          [4:---------------------------------------------]|
          [4:---------------------------------------------]|
          [4:---------------------------------------------]|
          {3:[Command Line]                               }|
          [3:---------------------------------------------]|
        ## grid 2
                                                       |
        ## grid 3
          :                                            |
        ## grid 4
          {1::}{5:^+--  2 lines: set foldmethod=manual·········}|
          {1::}                                            |
          {1:~                                            }|
          {1:~                                            }|
        ]])
      else
        screen:expect([[
                                                       |
          {2:[No Name]                                    }|
          {1::}{5:^+--  2 lines: set foldmethod=manual·········}|
          {1::}                                            |
          {1:~                                            }|
          {1:~                                            }|
          {3:[Command Line]                               }|
          :                                            |
        ]])
      end

      feed("<cr>")
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          ^                                             |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
          :                                            |
        ]])
      else
        screen:expect([[
          ^                                             |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          :                                            |
        ]])
      end

      feed("/<c-f>")
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          {2:[No Name]                                    }|
          [5:---------------------------------------------]|
          [5:---------------------------------------------]|
          [5:---------------------------------------------]|
          [5:---------------------------------------------]|
          {3:[Command Line]                               }|
          [3:---------------------------------------------]|
        ## grid 2
                                                       |
        ## grid 3
          /                                            |
        ## grid 5
          {1:/}alpha                                       |
          {1:/}{6:omega}                                       |
          {1:/}^                                            |
          {1:~                                            }|
        ]])
      else
        screen:expect([[
                                                       |
          {2:[No Name]                                    }|
          {1:/}alpha                                       |
          {1:/}{6:omega}                                       |
          {1:/}^                                            |
          {1:~                                            }|
          {3:[Command Line]                               }|
          /                                            |
        ]])
      end

      feed("ggzfG")
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          {2:[No Name]                                    }|
          [5:---------------------------------------------]|
          [5:---------------------------------------------]|
          [5:---------------------------------------------]|
          [5:---------------------------------------------]|
          {3:[Command Line]                               }|
          [3:---------------------------------------------]|
        ## grid 2
                                                       |
        ## grid 3
          /                                            |
        ## grid 5
          {1:/}{5:^+--  3 lines: alpha·························}|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ]])
      else
        screen:expect([[
                                                       |
          {2:[No Name]                                    }|
          {1:/}{5:^+--  3 lines: alpha·························}|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {3:[Command Line]                               }|
          /                                            |
        ]])
      end

    end)

    it("work with autoresize", function()

      funcs.setline(1, 'line 1')
      funcs.setline(2, 'line 2')
      funcs.setline(3, 'line 3')
      funcs.setline(4, 'line 4')

      feed("zfj")
      command("set foldcolumn=0")
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          {5:^+--  2 lines: line 1·························}|
          line 3                                       |
          line 4                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          {5:^+--  2 lines: line 1·························}|
          line 3                                       |
          line 4                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
                                                       |
        ]])
      end
      -- should adapt to the current nesting of folds (e.g., 1)
      command("set foldcolumn=auto:1")
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          {7:+}{5:^+--  2 lines: line 1························}|
          {7: }line 3                                      |
          {7: }line 4                                      |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          {7:+}{5:^+--  2 lines: line 1························}|
          {7: }line 3                                      |
          {7: }line 4                                      |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
                                                       |
        ]])
      end
      command("set foldcolumn=auto")
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          {7:+}{5:^+--  2 lines: line 1························}|
          {7: }line 3                                      |
          {7: }line 4                                      |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
                                                       |
        ]], unchanged=true}
      else
        screen:expect{grid=[[
          {7:+}{5:^+--  2 lines: line 1························}|
          {7: }line 3                                      |
          {7: }line 4                                      |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
                                                       |
        ]], unchanged=true}
      end
      -- fdc should not change with a new fold as the maximum is 1
      feed("zf3j")

      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          {7:+}{5:^+--  4 lines: line 1························}|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          {7:+}{5:^+--  4 lines: line 1························}|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
                                                       |
        ]])
      end

      command("set foldcolumn=auto:1")
      if multigrid then screen:expect{grid=[[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          {7:+}{5:^+--  4 lines: line 1························}|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
                                                       |
        ]], unchanged=true}
      else
        screen:expect{grid=[[
          {7:+}{5:^+--  4 lines: line 1························}|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
                                                       |
        ]], unchanged=true}
      end

      -- relax the maximum fdc thus fdc should expand to
      -- accommodate the current number of folds
      command("set foldcolumn=auto:4")
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          {7:+ }{5:^+--  4 lines: line 1·······················}|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          {7:+ }{5:^+--  4 lines: line 1·······················}|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
                                                       |
        ]])
      end
    end)

    it('does not crash when foldtext is longer than columns #12988', function()
      exec([[
        function! MyFoldText() abort
          return repeat('-', &columns + 100)
        endfunction
      ]])
      command('set foldtext=MyFoldText()')
      feed("i<cr><esc>")
      feed("vkzf")
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          {5:^---------------------------------------------}|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          {5:^---------------------------------------------}|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
                                                       |
        ]])
      end
      assert_alive()
    end)

    it('work correctly with :move #18668', function()
      screen:try_resize(45, 12)
      exec([[
        set foldmethod=expr foldexpr=indent(v:lnum)
        let content = ['', '', 'Line1', '  Line2', '  Line3',
              \ 'Line4', '  Line5', '  Line6',
              \ 'Line7', '  Line8', '  Line9']
        call append(0, content)
        normal! zM
        call cursor(4, 1)
        move 2
        move 1
      ]])
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
                                                       |
          {5:^+--  2 lines: Line2··························}|
                                                       |
          Line1                                        |
          Line4                                        |
          {5:+--  2 lines: Line5··························}|
          Line7                                        |
          {5:+--  2 lines: Line8··························}|
                                                       |
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
                                                       |
          {5:^+--  2 lines: Line2··························}|
                                                       |
          Line1                                        |
          Line4                                        |
          {5:+--  2 lines: Line5··························}|
          Line7                                        |
          {5:+--  2 lines: Line8··························}|
                                                       |
          {1:~                                            }|
          {1:~                                            }|
                                                       |
        ]])
      end
    end)

    it('fold text is shown when text has been scrolled to the right #19123', function()
      insert(content1)
      command('set number nowrap')
      command('3,4fold')
      feed('gg')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          {8:  1 }^This is a                                |
          {8:  2 }valid English                            |
          {8:  3 }{5:+--  2 lines: sentence composed by·······}|
          {8:  5 }in his cave.                             |
          {8:  6 }                                         |
          {1:~                                            }|
          {1:~                                            }|
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
          {1:~                                            }|
          {1:~                                            }|
                                                       |
        ]])
      end

      feed('zl')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          {8:  1 }^his is a                                 |
          {8:  2 }alid English                             |
          {8:  3 }{5:+--  2 lines: sentence composed by·······}|
          {8:  5 }n his cave.                              |
          {8:  6 }                                         |
          {1:~                                            }|
          {1:~                                            }|
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
          {1:~                                            }|
          {1:~                                            }|
                                                       |
        ]])
      end
    end)

    it('fold attached virtual lines are drawn and scrolled correctly #21837', function()
      funcs.setline(1, 'line 1')
      funcs.setline(2, 'line 2')
      funcs.setline(3, 'line 3')
      funcs.setline(4, 'line 4')
      feed("zfj")
      local ns = meths.create_namespace('ns')
      meths.buf_set_extmark(0, ns, 0, 0, { virt_lines_above = true, virt_lines = {{{"virt_line above line 1", ""}}} })
      meths.buf_set_extmark(0, ns, 1, 0, { virt_lines = {{{"virt_line below line 2", ""}}} })
      meths.buf_set_extmark(0, ns, 2, 0, { virt_lines_above = true, virt_lines = {{{"virt_line above line 3", ""}}} })
      meths.buf_set_extmark(0, ns, 3, 0, { virt_lines = {{{"virt_line below line 4", ""}}} })
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          {5:^+--  2 lines: line 1·························}|
          virt_line above line 3                       |
          line 3                                       |
          line 4                                       |
          virt_line below line 4                       |
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          {5:^+--  2 lines: line 1·························}|
          virt_line above line 3                       |
          line 3                                       |
          line 4                                       |
          virt_line below line 4                       |
          {1:~                                            }|
          {1:~                                            }|
                                                       |
        ]])
      end

      feed('jzfj')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          {5:+--  2 lines: line 1·························}|
          {5:^+--  2 lines: line 3·························}|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          {5:+--  2 lines: line 1·························}|
          {5:^+--  2 lines: line 3·························}|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
                                                       |
        ]])
      end

      feed('kzo<C-Y>')
      funcs.setline(5, 'line 5')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
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
        ]])
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

      meths.input_mouse('left', 'press', '', multigrid and 2 or 0, 4, 0)
      eq({
        column = 1,
        line = 3,
        screencol = 1,
        screenrow = 5,
        wincol = 1,
        winid = 1000,
        winrow = 5,
      }, funcs.getmousepos())

      meths.buf_set_extmark(0, ns, 1, 0, { virt_lines = {{{"more virt_line below line 2", ""}}} })
      feed('G<C-E>')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
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
        ]])
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
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          line 2                                       |
          virt_line below line 2                       |
          more virt_line below line 2                  |
          {5:+--  2 lines: line 3·························}|
          ^line 5                                       |
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          line 2                                       |
          virt_line below line 2                       |
          more virt_line below line 2                  |
          {5:+--  2 lines: line 3·························}|
          ^line 5                                       |
          {1:~                                            }|
          {1:~                                            }|
                                                       |
        ]])
      end

      feed('<C-E>')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          virt_line below line 2                       |
          more virt_line below line 2                  |
          {5:+--  2 lines: line 3·························}|
          ^line 5                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          virt_line below line 2                       |
          more virt_line below line 2                  |
          {5:+--  2 lines: line 3·························}|
          ^line 5                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
                                                       |
        ]])
      end

      feed('<C-E>')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          more virt_line below line 2                  |
          {5:+--  2 lines: line 3·························}|
          ^line 5                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          more virt_line below line 2                  |
          {5:+--  2 lines: line 3·························}|
          ^line 5                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
                                                       |
        ]])
      end

      feed('<C-E>')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          {5:+--  2 lines: line 3·························}|
          ^line 5                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          {5:+--  2 lines: line 3·························}|
          ^line 5                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
                                                       |
        ]])
      end

      feed('<C-E>')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          ^line 5                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          ^line 5                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
                                                       |
        ]])
      end

      feed('3<C-Y>')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          virt_line below line 2                       |
          more virt_line below line 2                  |
          {5:+--  2 lines: line 3·························}|
          ^line 5                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          virt_line below line 2                       |
          more virt_line below line 2                  |
          {5:+--  2 lines: line 3·························}|
          ^line 5                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
                                                       |
        ]])
      end

      meths.input_mouse('left', 'press', '3', multigrid and 2 or 0, 3, 0)
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          virt_line below line 2                       |
          more virt_line below line 2                  |
          {5:+--  2 lines: line 3·························}|
          ^l{16:ine 5}                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
          {11:-- VISUAL LINE --}                            |
        ]])
      else
        screen:expect([[
          virt_line below line 2                       |
          more virt_line below line 2                  |
          {5:+--  2 lines: line 3·························}|
          ^l{16:ine 5}                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {11:-- VISUAL LINE --}                            |
        ]])
      end

      meths.input_mouse('left', 'drag', '3', multigrid and 2 or 0, 7, 0)
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          more virt_line below line 2                  |
          {5:+--  2 lines: line 3·························}|
          ^l{16:ine 5}                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
          {11:-- VISUAL LINE --}                            |
        ]])
      else
        screen:expect([[
          more virt_line below line 2                  |
          {5:+--  2 lines: line 3·························}|
          ^l{16:ine 5}                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {11:-- VISUAL LINE --}                            |
        ]])
      end

      meths.input_mouse('left', 'drag', '3', multigrid and 2 or 0, 7, 5)
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          {5:+--  2 lines: line 3·························}|
          {16:line }^5                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
          {11:-- VISUAL LINE --}                            |
        ]])
      else
        screen:expect([[
          {5:+--  2 lines: line 3·························}|
          {16:line }^5                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {11:-- VISUAL LINE --}                            |
        ]])
      end
    end)

    it('Folded and Visual highlights are combined #19691', function()
      command('hi! Visual guibg=Red')
      insert([[
        " foo
        " {{{1
        set nocp
        " }}}1
        " bar
        " {{{1
        set foldmethod=marker
        " }}}1
        " baz]])
      feed('gg')
      command('source')
      feed('<C-V>G3l')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          {14:" fo}o                                        |
          {15:+-- }{5: 3 lines: "······························}|
          {14:" ba}r                                        |
          {15:+-- }{5: 3 lines: "······························}|
          {14:" b}^az                                        |
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
          {11:-- VISUAL BLOCK --}                           |
        ]])
      else
        screen:expect([[
          {14:" fo}o                                        |
          {15:+-- }{5: 3 lines: "······························}|
          {14:" ba}r                                        |
          {15:+-- }{5: 3 lines: "······························}|
          {14:" b}^az                                        |
          {1:~                                            }|
          {1:~                                            }|
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
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          {2:line} 1                                       |
          {5:+--  2 lines: line 2·························}|
          {6:line} 4                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
          /line^                                        |
        ]])
      else
        screen:expect([[
          {2:line} 1                                       |
          {5:+--  2 lines: line 2·························}|
          {6:line} 4                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          /line^                                        |
        ]])
      end
      feed('<Esc>')
      funcs.matchadd('Search', 'line')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          {6:line} 1                                       |
          {5:+--  2 lines: line 2·························}|
          {6:line} ^4                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
        ## grid 3
                                                       |
        ]])
      else
        screen:expect([[
          {6:line} 1                                       |
          {5:+--  2 lines: line 2·························}|
          {6:line} ^4                                       |
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
          {1:~                                            }|
                                                       |
        ]])
      end
    end)
  end

  describe("with ext_multigrid", function()
    with_ext_multigrid(true)
  end)

  describe('without ext_multigrid', function()
    with_ext_multigrid(false)
  end)
end)
