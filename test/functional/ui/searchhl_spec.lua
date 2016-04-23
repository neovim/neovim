local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute = helpers.execute

describe('search highlighting', function()
  local screen
  local colors = Screen.colors
  local hl_colors = {
    NonText = colors.Blue,
    Search = colors.Yellow,
    Message = colors.Red,
  }

  before_each(function()
    clear()
    screen = Screen.new(40, 7)
    screen:attach()
    --ignore highligting of ~-lines
    screen:set_default_attr_ids( {
      [1] = {background = hl_colors.Search},
      [2] = {reverse = true},
      [3] = {foreground = hl_colors.Message},
    })
    screen:set_default_attr_ignore( {{bold=true, foreground=hl_colors.NonText}} )
  end)

  it('is disabled by ":set nohlsearch"', function()
    execute('set nohlsearch')
    insert("some text\nmore text")
    feed("gg/text<cr>")
    screen:expect([[
      some ^text                               |
      more text                               |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
      /text                                   |
    ]])
  end)

  it('works', function()
    insert([[
      some text
      more textstuff
      stupidtexttextstuff
      a text word
    ]])

    -- 'hlsearch' is enabled by default. #2859
    feed("gg/text<cr>")
    screen:expect([[
        some {1:^text}                             |
        more {1:text}stuff                        |
        stupid{1:texttext}stuff                   |
        a {1:text} word                           |
                                              |
      ~                                       |
      /text                                   |
    ]])

    -- overlapping matches not allowed
    feed("3nx")
    screen:expect([[
        some {1:text}                             |
        more {1:text}stuff                        |
        stupid{1:text}^extstuff                    |
        a {1:text} word                           |
                                              |
      ~                                       |
      /text                                   |
    ]])

    feed("ggn*") -- search for entire word
    screen:expect([[
        some {1:text}                             |
        more textstuff                        |
        stupidtextextstuff                    |
        a {1:^text} word                           |
                                              |
      ~                                       |
      /\<text\>                               |
    ]])

    execute("nohlsearch")
    screen:expect([[
        some text                             |
        more textstuff                        |
        stupidtextextstuff                    |
        a ^text word                           |
                                              |
      ~                                       |
      :nohlsearch                             |
    ]])
  end)

  it('works with incsearch', function()
    execute('set hlsearch')
    execute('set incsearch')
    insert([[
      the first line
      in a little file
    ]])
    feed("gg/li")
    screen:expect([[
        the first {2:li}ne                        |
        in a little file                      |
                                              |
      ~                                       |
      ~                                       |
      ~                                       |
      /li^                                     |
    ]])

    feed("t")
    screen:expect([[
        the first line                        |
        in a {2:lit}tle file                      |
                                              |
      ~                                       |
      ~                                       |
      ~                                       |
      /lit^                                    |
    ]])

    feed("<cr>")
    screen:expect([[
        the first line                        |
        in a {1:^lit}tle file                      |
                                              |
      ~                                       |
      ~                                       |
      ~                                       |
      /lit                                    |
    ]])

    feed("/fir")
    screen:expect([[
        the {2:fir}st line                        |
        in a {1:lit}tle file                      |
                                              |
      ~                                       |
      ~                                       |
      ~                                       |
      /fir^                                    |
    ]])

    -- incsearch have priority over hlsearch
    feed("<esc>/ttle")
    screen:expect([[
        the first line                        |
        in a {1:li}{2:ttle} file                      |
                                              |
      ~                                       |
      ~                                       |
      ~                                       |
      /ttle^                                   |
    ]])
  end)

  it('works with incsearch and offset', function()
    execute('set hlsearch')
    execute('set incsearch')
    insert([[
      not the match you're looking for
      the match is here]])

    feed("gg/mat/e")
    screen:expect([[
      not the {2:mat}ch you're looking for        |
      the match is here                       |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
      /mat/e^                                  |
    ]])

    -- Search with count and /e offset fixed in Vim patch 7.4.532.
    feed("<esc>2/mat/e")
    screen:expect([[
      not the match you're looking for        |
      the {2:mat}ch is here                       |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
      /mat/e^                                  |
    ]])

    feed("<cr>")
    screen:expect([[
      not the {1:mat}ch you're looking for        |
      the {1:ma^t}ch is here                       |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
      /mat/e                                  |
    ]])
  end)

  it('works with multiline regexps', function()
    execute('set hlsearch')
    feed('4oa  repeated line<esc>')
    feed('/line\\na<cr>')
    screen:expect([[
                                              |
      a  repeated {1:^line}                        |
      {1:a}  repeated {1:line}                        |
      {1:a}  repeated {1:line}                        |
      {1:a}  repeated line                        |
      ~                                       |
      {3:search hit BOTTOM, continuing at TOP}    |
    ]])

    -- it redraws rows above the changed one
    feed('4Grb')
    screen:expect([[
                                              |
      a  repeated {1:line}                        |
      {1:a}  repeated line                        |
      ^b  repeated {1:line}                        |
      {1:a}  repeated line                        |
      ~                                       |
      {3:search hit BOTTOM, continuing at TOP}    |
    ]])
  end)

  it('works with matchadd and syntax', function()
    execute('set hlsearch')
    insert([[
      very special text
    ]])
    execute("syntax on")
    execute("highlight MyGroup guibg=Green gui=bold")
    execute("highlight MyGroup2 guibg=Magenta gui=italic")
    execute("call matchadd('MyGroup', 'special')")
    execute("call matchadd('MyGroup2', 'text', 0)")

    -- searchhl and matchadd matches are exclusive, only the higest priority
    -- is used (and matches with lower priorities are not combined)
    execute("/ial te")
    screen:expect([[
        very {4:spec^ial}{1: te}{5:xt}                     |
                                              |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
      {3:search hit BOTTOM, continuing at TOP}    |
    ]], {[1] = {background = hl_colors.Search}, [2] = {reverse = true},
    [3] = {foreground = hl_colors.Message}, [4] = {bold = true, background =
    colors.Green}, [5] = {italic = true, background = colors.Magenta}})

    execute("call clearmatches()")
    screen:expect([[
        very spec{1:^ial te}xt                     |
                                              |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
      :call clearmatches()                    |
    ]])

    -- searchhl has priority over syntax, but in this case
    -- nonconflicting attributes are combined
    execute("syntax keyword MyGroup special")
    screen:expect([[
        very {4:spec}{5:^ial}{1: te}xt                     |
                                              |
      ~                                       |
      ~                                       |
      ~                                       |
      ~                                       |
      :syntax keyword MyGroup special         |
    ]], {[1] = {background =  hl_colors.Search}, [2] = {reverse = true},
    [3] = {foreground = hl_colors.Message}, [4] = {bold = true,
    background = colors.Green}, [5] = {bold = true, background = hl_colors.Search}})

  end)
end)

