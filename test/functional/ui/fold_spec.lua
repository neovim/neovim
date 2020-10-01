local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, eq = helpers.clear, helpers.feed, helpers.eq
local command = helpers.command
local feed_command = helpers.feed_command
local insert = helpers.insert
local funcs = helpers.funcs
local meths = helpers.meths
local source = helpers.source
local assert_alive = helpers.assert_alive

describe("folded lines", function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(45, 8)
    screen:attach({rgb=true})
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue1},
      [2] = {reverse = true},
      [3] = {bold = true, reverse = true},
      [4] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
      [5] = {foreground = Screen.colors.DarkBlue, background = Screen.colors.LightGrey},
      [6] = {background = Screen.colors.Yellow},
      [7] = {foreground = Screen.colors.DarkBlue, background = Screen.colors.WebGray},
      [8] = {foreground = Screen.colors.Brown },
      [9] = {bold = true, foreground = Screen.colors.Brown}
    })
  end)

  it("work with more than one signcolumn", function()
    command("set signcolumn=yes:9")
    feed("i<cr><esc>")
    feed("vkzf")
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
  end)

  it("highlighting with relative line numbers", function()
    command("set relativenumber foldmethod=marker")
    feed_command("set foldcolumn=2")
    funcs.setline(1, '{{{1')
    funcs.setline(2, 'line 1')
    funcs.setline(3, '{{{1')
    funcs.setline(4, 'line 2')
    feed("j")
    screen:expect([[
      {7:+ }{8:  1 }{5:+--  2 lines: ·························}|
      {7:+ }{9:  0 }{5:^+--  2 lines: ·························}|
      {1:~                                            }|
      {1:~                                            }|
      {1:~                                            }|
      {1:~                                            }|
      {1:~                                            }|
      :set foldcolumn=2                            |
    ]])
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
    screen:expect{grid=[[
      {7:▾▾}^aa                                         |
      {7:││}bb                                         |
      {7:││}cc                                         |
      {7:││}dd                                         |
      {7:││}ee                                         |
      {7:│ }ff                                         |
      {1:~                                            }|
      :1                                           |
    ]]}

    feed_command("set rightleft")
    screen:expect{grid=[[
                                               a^a{7:▾▾}|
                                               bb{7:││}|
                                               cc{7:││}|
                                               dd{7:││}|
                                               ee{7:││}|
                                               ff{7: │}|
      {1:                                            ~}|
      :set rightleft                               |
    ]]}

    feed_command("set norightleft")
    meths.input_mouse('left', 'press', '', 0, 0, 1)
    screen:expect{grid=[[
    {7:▾▸}{5:^+---  5 lines: aa··························}|
    {7:│ }ff                                         |
    {1:~                                            }|
    {1:~                                            }|
    {1:~                                            }|
    {1:~                                            }|
    {1:~                                            }|
    :set norightleft                             |
    ]]}
  end)

  it("works with multibyte text", function()
    -- Currently the only allowed value of 'maxcombine'
    eq(6, meths.get_option('maxcombine'))
    eq(true, meths.get_option('arabicshape'))
    insert([[
      å 语 x̨̣̘̫̲͚͎̎͂̀̂͛͛̾͢͟ العَرَبِيَّة
      möre text]])
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

    feed('vkzf')
    screen:expect{grid=[[
      {5:^+--  2 lines: å 语 x̎͂̀̂͛͛ العَرَبِيَّة·················}|
      {1:~                                            }|
      {1:~                                            }|
      {1:~                                            }|
      {1:~                                            }|
      {1:~                                            }|
      {1:~                                            }|
                                                   |
    ]]}

    feed_command("set noarabicshape")
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

    feed_command("set number foldcolumn=2")
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

    -- Note: too much of the folded line gets cut off.This is a vim bug.
    feed_command("set rightleft")
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

    feed_command("set nonumber foldcolumn=0")
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

    feed_command("set arabicshape")
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

    feed('zo')
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

    feed_command('set noarabicshape')
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

  end)

  it("work in cmdline window", function()
    feed_command("set foldmethod=manual")
    feed_command("let x = 1")
    feed_command("/alpha")
    feed_command("/omega")

    feed("<cr>q:")
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

    feed("kzfk")
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

    feed("<cr>")
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

    feed("/<c-f>")
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

    feed("ggzfG")
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

  end)

  it("work with autoresize", function()

    funcs.setline(1, 'line 1')
    funcs.setline(2, 'line 2')
    funcs.setline(3, 'line 3')
    funcs.setline(4, 'line 4')

    feed("zfj")
    command("set foldcolumn=0")
    screen:expect{grid=[[
      {5:^+--  2 lines: line 1·························}|
      line 3                                       |
      line 4                                       |
      {1:~                                            }|
      {1:~                                            }|
      {1:~                                            }|
      {1:~                                            }|
                                                   |
    ]]}
    -- should adapt to the current nesting of folds (e.g., 1)
    command("set foldcolumn=auto:1")
    screen:expect{grid=[[
    {7:+}{5:^+--  2 lines: line 1························}|
    {7: }line 3                                      |
    {7: }line 4                                      |
    {1:~                                            }|
    {1:~                                            }|
    {1:~                                            }|
    {1:~                                            }|
                                                 |
    ]]}
    -- fdc should not change with a new fold as the maximum is 1
    feed("zf3j")

    screen:expect{grid=[[
    {7:+}{5:^+--  4 lines: line 1························}|
    {1:~                                            }|
    {1:~                                            }|
    {1:~                                            }|
    {1:~                                            }|
    {1:~                                            }|
    {1:~                                            }|
                                                 |
    ]]}

    -- relax the maximum fdc thus fdc should expand to
    -- accomodate the current number of folds
    command("set foldcolumn=auto:4")
    screen:expect{grid=[[
    {7:+ }{5:^+--  4 lines: line 1·······················}|
    {1:~                                            }|
    {1:~                                            }|
    {1:~                                            }|
    {1:~                                            }|
    {1:~                                            }|
    {1:~                                            }|
                                                 |
    ]]}
  end)

  it('does not crash when foldtext is longer than columns #12988', function()
    source([[
      function! MyFoldText() abort
        return repeat('-', &columns + 100)
      endfunction
    ]])
    command('set foldtext=MyFoldText()')
    feed("i<cr><esc>")
    feed("vkzf")
    screen:expect{grid=[[
    {5:^---------------------------------------------}|
    {1:~                                            }|
    {1:~                                            }|
    {1:~                                            }|
    {1:~                                            }|
    {1:~                                            }|
    {1:~                                            }|
                                                 |
    ]]}
    assert_alive()
  end)
end)
