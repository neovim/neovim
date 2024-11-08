local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear, feed, insert = n.clear, n.feed, n.insert
local command = n.command
local feed_command = n.feed_command
local eq = t.eq
local eval = n.eval
local fn = n.fn
local testprg = n.testprg

describe('search highlighting', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(40, 7)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = { bold = true, foreground = Screen.colors.Blue },
      [2] = { background = Screen.colors.Yellow }, -- Search
      [3] = { reverse = true },
      [4] = { foreground = Screen.colors.Red }, -- WarningMsg
      [5] = { bold = true, reverse = true }, -- StatusLine
      [6] = { foreground = Screen.colors.Blue4, background = Screen.colors.LightGrey }, -- Folded
    })
  end)

  it('is disabled by ":set nohlsearch"', function()
    feed_command('set nohlsearch')
    insert('some text\nmore text')
    feed('gg/text<cr>')
    screen:expect([[
      some ^text                               |
      more text                               |
      {1:~                                       }|*4
      /text                                   |
    ]])
  end)

  it('is disabled in folded text', function()
    insert('some text\nmore text')
    feed_command('1,2fold')
    feed('gg/text')
    screen:expect {
      grid = [[
      {6:+--  2 lines: some text·················}|
      {1:~                                       }|*5
      /text^                                   |
    ]],
      win_viewport = {
        [2] = {
          win = 1000,
          topline = 0,
          botline = 3,
          curline = 0,
          curcol = 9,
          linecount = 2,
          sum_scroll_delta = 0,
        },
      },
    }
  end)

  local function test_search_hl()
    insert([[
      some text
      more textstuff
      stupidtexttextstuff
      a text word
    ]])

    -- 'hlsearch' is enabled by default. #2859
    feed('gg/text<cr>')
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
    feed('3nx')
    screen:expect([[
        some {2:text}                             |
        more {2:text}stuff                        |
        stupid{2:text}^extstuff                    |
        a {2:text} word                           |
                                              |
      {1:~                                       }|
      /text                                   |
    ]])

    feed('ggn*') -- search for entire word
    screen:expect([[
        some {2:text}                             |
        more textstuff                        |
        stupidtextextstuff                    |
        a {2:^text} word                           |
                                              |
      {1:~                                       }|
      /\<text\>                               |
    ]])

    feed_command('nohlsearch')
    screen:expect([[
        some text                             |
        more textstuff                        |
        stupidtextextstuff                    |
        a ^text word                           |
                                              |
      {1:~                                       }|
      :nohlsearch                             |
    ]])
  end

  it("works when 'winhighlight' is not set", function()
    test_search_hl()
  end)

  it("works when 'winhighlight' doesn't change Search highlight", function()
    command('setlocal winhl=NonText:Underlined')
    local attrs = screen:get_default_attr_ids()
    attrs[1] = { foreground = Screen.colors.SlateBlue, underline = true }
    screen:set_default_attr_ids(attrs)
    test_search_hl()
  end)

  it("works when 'winhighlight' changes Search highlight", function()
    command('setlocal winhl=Search:Underlined')
    local attrs = screen:get_default_attr_ids()
    attrs[2] = { foreground = Screen.colors.SlateBlue, underline = true }
    screen:set_default_attr_ids(attrs)
    test_search_hl()
  end)

  describe('CurSearch highlight', function()
    before_each(function()
      screen:set_default_attr_ids({
        [1] = { background = Screen.colors.Yellow }, -- Search
        [2] = { foreground = Screen.colors.White, background = Screen.colors.Black }, -- CurSearch
        [3] = { foreground = Screen.colors.Red }, -- WarningMsg
      })
      command('highlight CurSearch guibg=Black guifg=White')
    end)

    it('works for match under cursor', function()
      insert([[
        There is no way that a bee should be
        able to fly. Its wings are too small
        to get its fat little body off the
        ground. The bee, of course, flies
        anyway because bees don't care what
        humans think is impossible.]])

      feed('/bee<CR>')
      screen:expect {
        grid = [[
        There is no way that a {2:^bee} should be    |
        able to fly. Its wings are too small    |
        to get its fat little body off the      |
        ground. The {1:bee}, of course, flies       |
        anyway because {1:bee}s don't care what     |
        humans think is impossible.             |
        {3:search hit BOTTOM, continuing at TOP}    |
      ]],
      }

      feed('nn')
      screen:expect {
        grid = [[
        There is no way that a {1:bee} should be    |
        able to fly. Its wings are too small    |
        to get its fat little body off the      |
        ground. The {1:bee}, of course, flies       |
        anyway because {2:^bee}s don't care what     |
        humans think is impossible.             |
        /bee                                    |
      ]],
      }

      feed('N')
      screen:expect {
        grid = [[
        There is no way that a {1:bee} should be    |
        able to fly. Its wings are too small    |
        to get its fat little body off the      |
        ground. The {2:^bee}, of course, flies       |
        anyway because {1:bee}s don't care what     |
        humans think is impossible.             |
        ?bee                                    |
      ]],
      }
    end)

    -- oldtest: Test_hlsearch_cursearch()
    it('works for multiline match, no duplicate highlight', function()
      command([[call setline(1, ['one', 'foo', 'bar', 'baz', 'foo the foo and foo', 'bar'])]])
      feed('gg/foo<CR>')
      screen:expect([[
        one                                     |
        {2:^foo}                                     |
        bar                                     |
        baz                                     |
        {1:foo} the {1:foo} and {1:foo}                     |
        bar                                     |
        /foo                                    |
      ]])
      feed('n')
      screen:expect([[
        one                                     |
        {1:foo}                                     |
        bar                                     |
        baz                                     |
        {2:^foo} the {1:foo} and {1:foo}                     |
        bar                                     |
        /foo                                    |
      ]])
      feed('n')
      screen:expect([[
        one                                     |
        {1:foo}                                     |
        bar                                     |
        baz                                     |
        {1:foo} the {2:^foo} and {1:foo}                     |
        bar                                     |
        /foo                                    |
      ]])
      feed('n')
      screen:expect([[
        one                                     |
        {1:foo}                                     |
        bar                                     |
        baz                                     |
        {1:foo} the {1:foo} and {2:^foo}                     |
        bar                                     |
        /foo                                    |
      ]])
      command([[call setline(5, 'foo')]])
      feed('0?<CR>')
      screen:expect([[
        one                                     |
        {2:^foo}                                     |
        bar                                     |
        baz                                     |
        {1:foo}                                     |
        bar                                     |
        ?foo                                    |
      ]])
      feed('gg/foo\\nbar<CR>')
      screen:expect([[
        one                                     |
        {2:^foo }                                    |
        {2:bar}                                     |
        baz                                     |
        {1:foo }                                    |
        {1:bar}                                     |
        /foo\nbar                               |
      ]])
      command([[call setline(1, ['---', 'abcdefg', 'hijkl', '---', 'abcdefg', 'hijkl'])]])
      feed('gg/efg\\nhij<CR>')
      screen:expect([[
        ---                                     |
        abcd{2:^efg }                                |
        {2:hij}kl                                   |
        ---                                     |
        abcd{1:efg }                                |
        {1:hij}kl                                   |
        /efg\nhij                               |
      ]])
      feed('n')
      screen:expect([[
        ---                                     |
        abcd{1:efg }                                |
        {1:hij}kl                                   |
        ---                                     |
        abcd{2:^efg }                                |
        {2:hij}kl                                   |
        /efg\nhij                               |
      ]])

      -- check clearing CurSearch when using it for another match
      feed('G?^abcd<CR>Y')
      screen:expect([[
        ---                                     |
        {1:abcd}efg                                 |
        hijkl                                   |
        ---                                     |
        {2:^abcd}efg                                 |
        hijkl                                   |
        ?^abcd                                  |
      ]])
      feed('kkP')
      screen:expect([[
        ---                                     |
        {1:abcd}efg                                 |
        {2:^abcd}efg                                 |
        hijkl                                   |
        ---                                     |
        {1:abcd}efg                                 |
        ?^abcd                                  |
      ]])
    end)
  end)

  it('highlights after EOL', function()
    insert('\n\n\n\n\n\n')

    feed('gg/^<cr>')
    screen:expect([[
      {2: }                                       |
      {2:^ }                                       |
      {2: }                                       |*4
      /^                                      |
    ]])

    -- Test that highlights are preserved after moving the cursor.
    feed('j')
    screen:expect([[
      {2: }                                       |*2
      {2:^ }                                       |
      {2: }                                       |*3
      /^                                      |
    ]])

    -- Repeat the test in rightleft mode.
    command('nohlsearch')
    command('set rightleft')
    feed('gg/^<cr>')

    screen:expect([[
                                             {2: }|
                                             {2:^ }|
                                             {2: }|*4
      ^/                                      |
    ]])

    feed('j')
    screen:expect([[
                                             {2: }|*2
                                             {2:^ }|
                                             {2: }|*3
      ^/                                      |
    ]])
  end)

  it('is preserved during :terminal activity', function()
    feed((':terminal "%s" REP 5000 foo<cr>'):format(testprg('shell-test')))
    feed(':file term<CR>')
    screen:expect([[
      ^0: foo                                  |
      1: foo                                  |
      2: foo                                  |
      3: foo                                  |
      4: foo                                  |
      5: foo                                  |
      :file term                              |
    ]])

    feed('G') -- Follow :terminal output.
    feed(':vnew<CR>')
    insert([[
      foo bar baz
      bar baz foo
      bar foo baz]])
    feed('/foo')
    screen:set_default_attr_ids({
      [1] = { bold = true, foreground = Screen.colors.Blue },
      [2] = { background = Screen.colors.Yellow }, -- Search
      [3] = { reverse = true },
      [4] = { bold = true, reverse = true },
      [5] = { foreground = Screen.colors.White, background = Screen.colors.DarkGreen },
    })
    screen:expect([[
      {3:foo} bar baz         │{MATCH:%d+}: {2:foo}{MATCH:%s+}|
      bar baz {2:foo}         │{MATCH:%d+}: {2:foo}{MATCH:%s+}|
      bar {2:foo} baz         │{MATCH:%d+}: {2:foo}{MATCH:%s+}|
      {1:~                   }│{MATCH:.*}|*2
      {4:[No Name] [+]        }{5:term               }|
      /foo^                                    |
    ]])
  end)

  it('works with incsearch', function()
    command('set hlsearch')
    command('set incsearch')
    command('set laststatus=0')
    insert([[
      the first line
      in a little file]])
    command('vsplit')
    feed('gg/li')
    screen:expect([[
      the first {3:li}ne      │the first {2:li}ne     |
      in a {2:li}ttle file    │in a {2:li}ttle file   |
      {1:~                   }│{1:~                  }|*4
      /li^                                     |
    ]])

    -- check that consecutive matches are caught by C-g/C-t
    feed('<C-g>')
    screen:expect([[
      the first {2:li}ne      │the first {2:li}ne     |
      in a {3:li}ttle file    │in a {2:li}ttle file   |
      {1:~                   }│{1:~                  }|*4
      /li^                                     |
    ]])

    feed('<C-t>')
    screen:expect([[
      the first {3:li}ne      │the first {2:li}ne     |
      in a {2:li}ttle file    │in a {2:li}ttle file   |
      {1:~                   }│{1:~                  }|*4
      /li^                                     |
    ]])

    feed('t')
    screen:expect([[
      the first line      │the first line     |
      in a {3:lit}tle file    │in a {2:lit}tle file   |
      {1:~                   }│{1:~                  }|*4
      /lit^                                    |
    ]])

    feed('<cr>')
    screen:expect([[
      the first line      │the first line     |
      in a {2:^lit}tle file    │in a {2:lit}tle file   |
      {1:~                   }│{1:~                  }|*4
      /lit                                    |
    ]])

    feed('/fir')
    screen:expect([[
      the {3:fir}st line      │the {2:fir}st line     |
      in a little file    │in a little file   |
      {1:~                   }│{1:~                  }|*4
      /fir^                                    |
    ]])

    -- incsearch have priority over hlsearch
    feed('<esc>/ttle')
    screen:expect([[
      the first line      │the first line     |
      in a li{3:ttle} file    │in a li{2:ttle} file   |
      {1:~                   }│{1:~                  }|*4
      /ttle^                                   |
    ]])

    -- cancelling search resets to the old search term
    feed('<esc>')
    screen:expect([[
      the first line      │the first line     |
      in a {2:^lit}tle file    │in a {2:lit}tle file   |
      {1:~                   }│{1:~                  }|*4
                                              |
    ]])
    eq('lit', eval('@/'))

    -- cancelling inc search restores the hl state
    feed(':noh<cr>')
    screen:expect([[
      the first line      │the first line     |
      in a ^little file    │in a little file   |
      {1:~                   }│{1:~                  }|*4
      :noh                                    |
    ]])

    feed('/first')
    screen:expect([[
      the {3:first} line      │the {2:first} line     |
      in a little file    │in a little file   |
      {1:~                   }│{1:~                  }|*4
      /first^                                  |
    ]])
    feed('<esc>')
    screen:expect([[
      the first line      │the first line     |
      in a ^little file    │in a little file   |
      {1:~                   }│{1:~                  }|*4
                                              |
    ]])

    -- test that pressing C-g in an empty command line does not move the cursor
    feed('gg0')
    command([[let @/ = 'i']])
    -- moves to next match of previous search pattern, just like /<cr>
    feed('/<c-g><cr>')
    eq({ 0, 1, 6, 0 }, fn.getpos('.'))
    -- moves to next match of previous search pattern, just like /<cr>
    feed('/<cr>')
    eq({ 0, 1, 12, 0 }, fn.getpos('.'))
    -- moves to next match of previous search pattern, just like /<cr>
    feed('/<c-t><cr>')
    eq({ 0, 2, 1, 0 }, fn.getpos('.'))

    -- 8.0.1304, test that C-g and C-t works with incsearch and empty pattern
    feed('<esc>/fi<CR>')
    screen:expect([[
      the {2:fi}rst line      │the {2:fi}rst line     |
      in a little {2:^fi}le    │in a little {2:fi}le   |
      {1:~                   }│{1:~                  }|*4
      /fi                                     |
    ]])
    feed('//')
    screen:expect([[
      the {3:fi}rst line      │the {2:fi}rst line     |
      in a little {2:fi}le    │in a little {2:fi}le   |
      {1:~                   }│{1:~                  }|*4
      //^                                      |
    ]])
    feed('<C-g>')
    screen:expect([[
      the {2:fi}rst line      │the {2:fi}rst line     |
      in a little {3:fi}le    │in a little {2:fi}le   |
      {1:~                   }│{1:~                  }|*4
      //^                                      |
    ]])
    feed('<Esc>')

    -- incsearch works after c_CTRL-R_CTRL-R
    command('let @" = "file"')
    feed('/<C-R><C-R>"')
    screen:expect([[
      the first line      │the first line     |
      in a little {3:file}    │in a little {2:file}   |
      {1:~                   }│{1:~                  }|*4
      /file^                                   |
    ]])
    feed('<Esc>')

    command('set rtp^=test/functional/fixtures')
    -- incsearch works after c_CTRL-R inserts clipboard register

    command('let @* = "first"')
    feed('/<C-R>*')
    screen:expect([[
      the {3:first} line      │the {2:first} line     |
      in a little file    │in a little file   |
      {1:~                   }│{1:~                  }|*4
      /first^                                  |
    ]])
    feed('<Esc>')

    command('let @+ = "little"')
    feed('/<C-R>+')
    screen:expect([[
      the first line      │the first line     |
      in a {3:little} file    │in a {2:little} file   |
      {1:~                   }│{1:~                  }|*4
      /little^                                 |
    ]])
    feed('<Esc>')
  end)

  it('works with incsearch and offset', function()
    feed_command('set hlsearch')
    feed_command('set incsearch')
    insert([[
      not the match you're looking for
      the match is here]])

    feed('gg/mat/e')
    screen:expect([[
      not the {3:mat}ch you're looking for        |
      the {2:mat}ch is here                       |
      {1:~                                       }|*4
      /mat/e^                                  |
    ]])

    -- Search with count and /e offset fixed in Vim patch 7.4.532.
    feed('<esc>2/mat/e')
    screen:expect([[
      not the {2:mat}ch you're looking for        |
      the {3:mat}ch is here                       |
      {1:~                                       }|*4
      /mat/e^                                  |
    ]])

    feed('<cr>')
    screen:expect([[
      not the {2:mat}ch you're looking for        |
      the {2:ma^t}ch is here                       |
      {1:~                                       }|*4
      /mat/e                                  |
    ]])
  end)

  it('works with multiline regexps', function()
    feed_command('set hlsearch')
    feed('4oa  repeated line<esc>')
    feed('/line\\na<cr>')
    screen:expect([[
                                              |
      a  repeated {2:^line }                       |
      {2:a}  repeated {2:line }                       |*2
      {2:a}  repeated line                        |
      {1:~                                       }|
      {4:search hit BOTTOM, continuing at TOP}    |
    ]])

    -- it redraws rows above the changed one
    feed('4Grb')
    screen:expect([[
                                              |
      a  repeated {2:line }                       |
      {2:a}  repeated line                        |
      ^b  repeated {2:line }                       |
      {2:a}  repeated line                        |
      {1:~                                       }|
      {4:search hit BOTTOM, continuing at TOP}    |
    ]])
  end)

  it('works with matchadd and syntax', function()
    screen:set_default_attr_ids {
      [1] = { bold = true, foreground = Screen.colors.Blue },
      [2] = { background = Screen.colors.Yellow },
      [3] = { reverse = true },
      [4] = { foreground = Screen.colors.Red },
      [5] = { bold = true, background = Screen.colors.Green },
      [6] = { italic = true, background = Screen.colors.Magenta },
      [7] = { bold = true, background = Screen.colors.Yellow },
      [8] = { foreground = Screen.colors.Blue4, background = Screen.colors.LightGray },
    }
    feed_command('set hlsearch')
    insert [[
      very special text
    ]]
    feed_command('syntax on')
    feed_command('highlight MyGroup guibg=Green gui=bold')
    feed_command('highlight MyGroup2 guibg=Magenta gui=italic')
    feed_command("call matchadd('MyGroup', 'special')")
    feed_command("call matchadd('MyGroup2', 'text', 0)")

    -- searchhl and matchadd matches are exclusive, only the highest priority
    -- is used (and matches with lower priorities are not combined)
    feed_command('/ial te')
    screen:expect {
      grid = [[
        very {5:spec^ial}{2: te}{6:xt}                     |
                                              |
      {1:~                                       }|*4
      {4:search hit BOTTOM, continuing at TOP}    |
    ]],
      win_viewport = {
        [2] = {
          win = 1000,
          topline = 0,
          botline = 3,
          curline = 0,
          curcol = 11,
          linecount = 2,
          sum_scroll_delta = 0,
        },
      },
    }

    -- check highlights work also in folds
    feed('zf4j')
    screen:expect {
      grid = [[
      {8:^+--  2 lines: very special text·········}|
      {1:~                                       }|*5
      {4:search hit BOTTOM, continuing at TOP}    |
    ]],
    }
    command('%foldopen')
    screen:expect([[
        very {5:spec^ial}{2: te}{6:xt}                     |
                                              |
      {1:~                                       }|*4
      {4:search hit BOTTOM, continuing at TOP}    |
    ]])

    feed_command('call clearmatches()')
    screen:expect([[
        very spec{2:^ial te}xt                     |
                                              |
      {1:~                                       }|*4
      :call clearmatches()                    |
    ]])

    -- searchhl has priority over syntax, but in this case
    -- nonconflicting attributes are combined
    feed_command('syntax keyword MyGroup special')
    screen:expect([[
        very {5:spec}{7:^ial}{2: te}xt                     |
                                              |
      {1:~                                       }|*4
      :syntax keyword MyGroup special         |
    ]])
  end)

  it('highlights entire pattern on :%g@a/b', function()
    command('set inccommand=nosplit')
    feed('ia/b/c<Esc>')
    feed(':%g@a/b')
    screen:expect([[
      {3:a/b}/c                                   |
      {1:~                                       }|*5
      :%g@a/b^                                 |
    ]])
  end)

  it('incsearch is still visible after :redraw from K_EVENT', function()
    fn.setline(1, { 'foo', 'bar' })
    feed('/foo<CR>/bar')
    screen:expect([[
      foo                                     |
      {3:bar}                                     |
      {1:~                                       }|*4
      /bar^                                    |
    ]])
    command('redraw!')
    -- There is an intermediate state where :redraw! removes 'incsearch' highlight.
    screen:expect_unchanged(true)
  end)
end)
