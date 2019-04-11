local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local command = helpers.command
local feed_command = helpers.feed_command
local eq = helpers.eq
local eval = helpers.eval
local iswin = helpers.iswin
local sleep = helpers.sleep

describe('search highlighting', function()
  local screen
  local colors = Screen.colors

  before_each(function()
    clear()
    screen = Screen.new(40, 7)
    screen:attach()
    screen:set_default_attr_ids( {
      [1] = {bold=true, foreground=Screen.colors.Blue},
      [2] = {background = colors.Yellow}, -- Search
      [3] = {reverse = true},
      [4] = {foreground = colors.Red}, -- Message
    })
  end)

  it('is disabled by ":set nohlsearch"', function()
    feed_command('set nohlsearch')
    insert("some text\nmore text")
    feed("gg/text<cr>")
    screen:expect([[
      some ^text                               |
      more text                               |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
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
        some {2:^text}                             |
        more {2:text}stuff                        |
        stupid{2:texttext}stuff                   |
        a {2:text} word                           |
                                              |
      {1:~                                       }|
      /text                                   |
    ]])

    -- overlapping matches not allowed
    feed("3nx")
    screen:expect([[
        some {2:text}                             |
        more {2:text}stuff                        |
        stupid{2:text}^extstuff                    |
        a {2:text} word                           |
                                              |
      {1:~                                       }|
      /text                                   |
    ]])

    feed("ggn*") -- search for entire word
    screen:expect([[
        some {2:text}                             |
        more textstuff                        |
        stupidtextextstuff                    |
        a {2:^text} word                           |
                                              |
      {1:~                                       }|
      /\<text\>                               |
    ]])

    feed_command("nohlsearch")
    screen:expect([[
        some text                             |
        more textstuff                        |
        stupidtextextstuff                    |
        a ^text word                           |
                                              |
      {1:~                                       }|
      :nohlsearch                             |
    ]])
  end)

  it('highlights after EOL', function()
    insert("\n\n\n\n\n\n")

    feed("gg/^<cr>")
    screen:expect([[
      {2: }                                       |
      {2:^ }                                       |
      {2: }                                       |
      {2: }                                       |
      {2: }                                       |
      {2: }                                       |
      /^                                      |
    ]])

    -- Test that highlights are preserved after moving the cursor.
    feed("j")
    screen:expect([[
      {2: }                                       |
      {2: }                                       |
      {2:^ }                                       |
      {2: }                                       |
      {2: }                                       |
      {2: }                                       |
      /^                                      |
    ]])

    -- Repeat the test in rightleft mode.
    command("nohlsearch")
    command("set rightleft")
    feed("gg/^<cr>")

    screen:expect([[
                                             {2: }|
                                             {2:^ }|
                                             {2: }|
                                             {2: }|
                                             {2: }|
                                             {2: }|
      ^/                                      |
    ]])

    feed("j")
    screen:expect([[
                                             {2: }|
                                             {2: }|
                                             {2:^ }|
                                             {2: }|
                                             {2: }|
                                             {2: }|
      ^/                                      |
    ]])
  end)

  it('is preserved during :terminal activity', function()
    if iswin() then
      feed([[:terminal for /L \%I in (1,1,5000) do @(echo xxx & echo xxx & echo xxx)<cr>]])
    else
      feed([[:terminal for i in $(seq 1 5000); do printf 'xxx\nxxx\nxxx\n'; done<cr>]])
    end

    feed(':file term<CR>')
    feed(':vnew<CR>')
    insert([[
      foo bar baz
      bar baz foo
      bar foo baz
    ]])
    feed('/foo')
    sleep(50)  -- Allow some terminal activity.
    -- NB: in earlier versions terminal output was redrawn during cmdline mode.
    -- For now just assert that the screens remain unchanged.
    screen:expect([[
        {3:foo} bar baz       {3:│}                   |
        bar baz {2:foo}       {3:│}                   |
        bar {2:foo} baz       {3:│}                   |
                          {3:│}                   |
      {1:~                   }{3:│}                   |
      {5:[No Name] [+]        }{3:term               }|
      /foo^                                    |
    ]], { [1] = {bold = true, foreground = Screen.colors.Blue1},
          [2] = {background = Screen.colors.Yellow},
          [3] = {reverse = true},
          [4] = {foreground = Screen.colors.Red},
          [5] = {bold = true, reverse = true},
    })
  end)

  it('works with incsearch', function()
    feed_command('set hlsearch')
    feed_command('set incsearch')
    insert([[
      the first line
      in a little file
    ]])
    feed("gg/li")
    screen:expect([[
        the first {3:li}ne                        |
        in a {2:li}ttle file                      |
                                              |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      /li^                                     |
    ]])

    -- check that consecutive matches are caught by C-g/C-t
    feed("<C-g>")
    screen:expect([[
        the first {2:li}ne                        |
        in a {3:li}ttle file                      |
                                              |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      /li^                                     |
    ]])

    feed("<C-t>")
    screen:expect([[
        the first {3:li}ne                        |
        in a {2:li}ttle file                      |
                                              |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      /li^                                     |
    ]])

    feed("t")
    screen:expect([[
        the first line                        |
        in a {3:lit}tle file                      |
                                              |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      /lit^                                    |
    ]])

    feed("<cr>")
    screen:expect([[
        the first line                        |
        in a {2:^lit}tle file                      |
                                              |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      /lit                                    |
    ]])

    feed("/fir")
    screen:expect([[
        the {3:fir}st line                        |
        in a little file                      |
                                              |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      /fir^                                    |
    ]])

    -- incsearch have priority over hlsearch
    feed("<esc>/ttle")
    screen:expect([[
        the first line                        |
        in a li{3:ttle} file                      |
                                              |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      /ttle^                                   |
    ]])

    -- cancelling search resets to the old search term
    feed('<esc>')
    screen:expect([[
        the first line                        |
        in a {2:^lit}tle file                      |
                                              |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]])
    eq('lit', eval('@/'))

    -- cancelling inc search restores the hl state
    feed(':noh<cr>')
    screen:expect([[
        the first line                        |
        in a ^little file                      |
                                              |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      :noh                                    |
    ]])

    feed('/first')
    screen:expect([[
        the {3:first} line                        |
        in a little file                      |
                                              |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      /first^                                  |
    ]])
    feed('<esc>')
    screen:expect([[
        the first line                        |
        in a ^little file                      |
                                              |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]])

    -- test that pressing C-g in an empty command line does not move the cursor
    feed('/<C-g>')
    screen:expect([[
        the first line                        |
        in a little file                      |
                                              |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      /^                                       |
    ]])

    -- same, for C-t
    feed('<ESC>')
    screen:expect([[
        the first line                        |
        in a ^little file                      |
                                              |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]])
    feed('/<C-t>')
    screen:expect([[
        the first line                        |
        in a little file                      |
                                              |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      /^                                       |
    ]])

    -- 8.0.1304, test that C-g and C-t works with incsearch and empty pattern
    feed('<esc>/fi<CR>')
    feed('//')
    screen:expect([[
        the {3:fi}rst line                        |
        in a little {2:fi}le                      |
                                              |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      //^                                      |
    ]])

    feed('<C-g>')
    screen:expect([[
        the {2:fi}rst line                        |
        in a little {3:fi}le                      |
                                              |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      //^                                      |
    ]])
  end)

  it('works with incsearch and offset', function()
    feed_command('set hlsearch')
    feed_command('set incsearch')
    insert([[
      not the match you're looking for
      the match is here]])

    feed("gg/mat/e")
    screen:expect([[
      not the {3:mat}ch you're looking for        |
      the {2:mat}ch is here                       |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      /mat/e^                                  |
    ]])

    -- Search with count and /e offset fixed in Vim patch 7.4.532.
    feed("<esc>2/mat/e")
    screen:expect([[
      not the {2:mat}ch you're looking for        |
      the {3:mat}ch is here                       |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      /mat/e^                                  |
    ]])

    feed("<cr>")
    screen:expect([[
      not the {2:mat}ch you're looking for        |
      the {2:ma^t}ch is here                       |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      /mat/e                                  |
    ]])
  end)

  it('works with multiline regexps', function()
    feed_command('set hlsearch')
    feed('4oa  repeated line<esc>')
    feed('/line\\na<cr>')
    screen:expect([[
                                              |
      a  repeated {2:^line}                        |
      {2:a}  repeated {2:line}                        |
      {2:a}  repeated {2:line}                        |
      {2:a}  repeated line                        |
      {1:~                                       }|
      {4:search hit BOTTOM, continuing at TOP}    |
    ]])

    -- it redraws rows above the changed one
    feed('4Grb')
    screen:expect([[
                                              |
      a  repeated {2:line}                        |
      {2:a}  repeated line                        |
      ^b  repeated {2:line}                        |
      {2:a}  repeated line                        |
      {1:~                                       }|
      {4:search hit BOTTOM, continuing at TOP}    |
    ]])
  end)

  it('works with matchadd and syntax', function()
    screen:set_default_attr_ids( {
        [1] = {bold=true, foreground=Screen.colors.Blue},
        [2] = {background = colors.Yellow},
        [3] = {reverse = true},
        [4] = {foreground = colors.Red},
        [5] = {bold = true, background = colors.Green},
        [6] = {italic = true, background = colors.Magenta},
        [7] = {bold = true, background = colors.Yellow},
    } )
    feed_command('set hlsearch')
    insert([[
      very special text
    ]])
    feed_command("syntax on")
    feed_command("highlight MyGroup guibg=Green gui=bold")
    feed_command("highlight MyGroup2 guibg=Magenta gui=italic")
    feed_command("call matchadd('MyGroup', 'special')")
    feed_command("call matchadd('MyGroup2', 'text', 0)")

    -- searchhl and matchadd matches are exclusive, only the higest priority
    -- is used (and matches with lower priorities are not combined)
    feed_command("/ial te")
    screen:expect([[
        very {5:spec^ial}{2: te}{6:xt}                     |
                                              |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {4:search hit BOTTOM, continuing at TOP}    |
    ]])

    feed_command("call clearmatches()")
    screen:expect([[
        very spec{2:^ial te}xt                     |
                                              |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      :call clearmatches()                    |
    ]])

    -- searchhl has priority over syntax, but in this case
    -- nonconflicting attributes are combined
    feed_command("syntax keyword MyGroup special")
    screen:expect([[
        very {5:spec}{7:^ial}{2: te}xt                     |
                                              |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      :syntax keyword MyGroup special         |
    ]])

  end)
end)

