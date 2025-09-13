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
    screen:add_extra_attr_ids({
      [100] = { foreground = Screen.colors.Gray100, background = Screen.colors.Grey0 },
      [101] = { foreground = Screen.colors.White, background = Screen.colors.DarkGreen },
      [102] = { background = Screen.colors.WebGreen, bold = true },
      [103] = { background = Screen.colors.Magenta1, italic = true },
      [104] = { background = Screen.colors.Yellow1, bold = true },
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
      {13:+--  2 lines: some text·················}|
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
      some {100:^text}                               |
      more {100:text}stuff                          |
      stupid{100:texttext}stuff                     |
      a {100:text} word                             |
                                              |
      {101:~                                       }|
      /text                                   |
    ]])

    -- overlapping matches not allowed
    feed('3nx')
    screen:expect([[
      some {100:text}                               |
      more {100:text}stuff                          |
      stupid{100:text}^extstuff                      |
      a {100:text} word                             |
                                              |
      {101:~                                       }|
      /text                                   |
    ]])

    feed('ggn*') -- search for entire word
    screen:expect([[
      some {100:text}                               |
      more textstuff                          |
      stupidtextextstuff                      |
      a {100:^text} word                             |
                                              |
      {101:~                                       }|
      /\<text\>                               |
    ]])

    feed_command('nohlsearch')
    screen:expect([[
      some text                               |
      more textstuff                          |
      stupidtextextstuff                      |
      a ^text word                             |
                                              |
      {101:~                                       }|
      :nohlsearch                             |
    ]])
  end

  it("works when 'winhighlight' is not set", function()
    screen:add_extra_attr_ids({
      [100] = { background = Screen.colors.Yellow1 },
      [101] = { foreground = Screen.colors.Blue1, bold = true },
    })
    test_search_hl()
  end)

  it("works when 'winhighlight' doesn't change Search highlight", function()
    command('setlocal winhl=NonText:Underlined')
    screen:add_extra_attr_ids({
      [100] = { background = Screen.colors.Yellow },
      [101] = { foreground = Screen.colors.SlateBlue, underline = true },
    })
    test_search_hl()
  end)

  it("works when 'winhighlight' changes Search highlight", function()
    command('setlocal winhl=Search:Underlined')
    screen:add_extra_attr_ids({
      [100] = { foreground = Screen.colors.SlateBlue, underline = true },
      [101] = { foreground = Screen.colors.Blue1, bold = true },
    })
    test_search_hl()
  end)

  describe('CurSearch highlight', function()
    before_each(function()
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
      screen:expect([[
        There is no way that a {100:^bee} should be    |
        able to fly. Its wings are too small    |
        to get its fat little body off the      |
        ground. The {10:bee}, of course, flies       |
        anyway because {10:bee}s don't care what     |
        humans think is impossible.             |
        {19:search hit BOTTOM, continuing at TOP}    |
      ]])

      feed('nn')
      screen:expect([[
        There is no way that a {10:bee} should be    |
        able to fly. Its wings are too small    |
        to get its fat little body off the      |
        ground. The {10:bee}, of course, flies       |
        anyway because {100:^bee}s don't care what     |
        humans think is impossible.             |
        /bee                                    |
      ]])

      feed('N')
      screen:expect([[
        There is no way that a {10:bee} should be    |
        able to fly. Its wings are too small    |
        to get its fat little body off the      |
        ground. The {100:^bee}, of course, flies       |
        anyway because {10:bee}s don't care what     |
        humans think is impossible.             |
        ?bee                                    |
      ]])
    end)

    -- oldtest: Test_hlsearch_cursearch()
    it('works for multiline match, no duplicate highlight', function()
      command([[call setline(1, ['one', 'foo', 'bar', 'baz', 'foo the foo and foo', 'bar'])]])
      feed('gg/foo<CR>')
      screen:expect([[
        one                                     |
        {100:^foo}                                     |
        bar                                     |
        baz                                     |
        {10:foo} the {10:foo} and {10:foo}                     |
        bar                                     |
        /foo                                    |
      ]])
      feed('n')
      screen:expect([[
        one                                     |
        {10:foo}                                     |
        bar                                     |
        baz                                     |
        {100:^foo} the {10:foo} and {10:foo}                     |
        bar                                     |
        /foo                                    |
      ]])
      feed('n')
      screen:expect([[
        one                                     |
        {10:foo}                                     |
        bar                                     |
        baz                                     |
        {10:foo} the {100:^foo} and {10:foo}                     |
        bar                                     |
        /foo                                    |
      ]])
      feed('n')
      screen:expect([[
        one                                     |
        {10:foo}                                     |
        bar                                     |
        baz                                     |
        {10:foo} the {10:foo} and {100:^foo}                     |
        bar                                     |
        /foo                                    |
      ]])
      command([[call setline(5, 'foo')]])
      feed('0?<CR>')
      screen:expect([[
        one                                     |
        {100:^foo}                                     |
        bar                                     |
        baz                                     |
        {10:foo}                                     |
        bar                                     |
        ?foo                                    |
      ]])
      feed('gg/foo\\nbar<CR>')
      screen:expect([[
        one                                     |
        {100:^foo }                                    |
        {100:bar}                                     |
        baz                                     |
        {10:foo }                                    |
        {10:bar}                                     |
        /foo\nbar                               |
      ]])
      command([[call setline(1, ['---', 'abcdefg', 'hijkl', '---', 'abcdefg', 'hijkl'])]])
      feed('gg/efg\\nhij<CR>')
      screen:expect([[
        ---                                     |
        abcd{100:^efg }                                |
        {100:hij}kl                                   |
        ---                                     |
        abcd{10:efg }                                |
        {10:hij}kl                                   |
        /efg\nhij                               |
      ]])
      feed('n')
      screen:expect([[
        ---                                     |
        abcd{10:efg }                                |
        {10:hij}kl                                   |
        ---                                     |
        abcd{100:^efg }                                |
        {100:hij}kl                                   |
        /efg\nhij                               |
      ]])

      -- check clearing CurSearch when using it for another match
      feed('G?^abcd<CR>Y')
      screen:expect([[
        ---                                     |
        {10:abcd}efg                                 |
        hijkl                                   |
        ---                                     |
        {100:^abcd}efg                                 |
        hijkl                                   |
        ?^abcd                                  |
      ]])
      feed('kkP')
      screen:expect([[
        ---                                     |
        {10:abcd}efg                                 |
        {100:^abcd}efg                                 |
        hijkl                                   |
        ---                                     |
        {10:abcd}efg                                 |
        ?^abcd                                  |
      ]])
    end)
  end)

  it('highlights after EOL', function()
    insert('\n\n\n\n\n\n')

    feed('gg/^<cr>')
    screen:expect([[
      {10: }                                       |
      {10:^ }                                       |
      {10: }                                       |*4
      /^                                      |
    ]])

    -- Test that highlights are preserved after moving the cursor.
    feed('j')
    screen:expect([[
      {10: }                                       |*2
      {10:^ }                                       |
      {10: }                                       |*3
      /^                                      |
    ]])

    -- Repeat the test in rightleft mode.
    command('nohlsearch')
    command('set rightleft')
    feed('gg/^<cr>')

    screen:expect([[
                                             {10: }|
                                             {10:^ }|
                                             {10: }|*4
      ^/                                      |
    ]])

    feed('j')
    screen:expect([[
                                             {10: }|*2
                                             {10:^ }|
                                             {10: }|*3
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
    screen:expect([[
      {2:foo} bar baz         │{MATCH:%d+}: {10:foo}{MATCH:%s+}|
      bar baz {10:foo}         │{MATCH:%d+}: {10:foo}{MATCH:%s+}|
      bar {10:foo} baz         │{MATCH:%d+}: {10:foo}{MATCH:%s+}|
      {1:~                   }│{MATCH:.*}|*2
      {3:[No Name] [+]        }{101:term [-]           }|
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
      the first {2:li}ne      │the first {10:li}ne     |
      in a {10:li}ttle file    │in a {10:li}ttle file   |
      {1:~                   }│{1:~                  }|*4
      /li^                                     |
    ]])

    -- check that consecutive matches are caught by C-g/C-t
    feed('<C-g>')
    screen:expect([[
      the first {10:li}ne      │the first {10:li}ne     |
      in a {2:li}ttle file    │in a {10:li}ttle file   |
      {1:~                   }│{1:~                  }|*4
      /li^                                     |
    ]])

    feed('<C-t>')
    screen:expect([[
      the first {2:li}ne      │the first {10:li}ne     |
      in a {10:li}ttle file    │in a {10:li}ttle file   |
      {1:~                   }│{1:~                  }|*4
      /li^                                     |
    ]])

    feed('t')
    screen:expect([[
      the first line      │the first line     |
      in a {2:lit}tle file    │in a {10:lit}tle file   |
      {1:~                   }│{1:~                  }|*4
      /lit^                                    |
    ]])

    feed('<cr>')
    screen:expect([[
      the first line      │the first line     |
      in a {10:^lit}tle file    │in a {10:lit}tle file   |
      {1:~                   }│{1:~                  }|*4
      /lit                                    |
    ]])

    feed('/fir')
    screen:expect([[
      the {2:fir}st line      │the {10:fir}st line     |
      in a little file    │in a little file   |
      {1:~                   }│{1:~                  }|*4
      /fir^                                    |
    ]])

    -- incsearch have priority over hlsearch
    feed('<esc>/ttle')
    screen:expect([[
      the first line      │the first line     |
      in a li{2:ttle} file    │in a li{10:ttle} file   |
      {1:~                   }│{1:~                  }|*4
      /ttle^                                   |
    ]])

    -- cancelling search resets to the old search term
    feed('<esc>')
    screen:expect([[
      the first line      │the first line     |
      in a {10:^lit}tle file    │in a {10:lit}tle file   |
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
      the {2:first} line      │the {10:first} line     |
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
      the {10:fi}rst line      │the {10:fi}rst line     |
      in a little {10:^fi}le    │in a little {10:fi}le   |
      {1:~                   }│{1:~                  }|*4
      /fi                                     |
    ]])
    feed('//')
    screen:expect([[
      the {2:fi}rst line      │the {10:fi}rst line     |
      in a little {10:fi}le    │in a little {10:fi}le   |
      {1:~                   }│{1:~                  }|*4
      //^                                      |
    ]])
    feed('<C-g>')
    screen:expect([[
      the {10:fi}rst line      │the {10:fi}rst line     |
      in a little {2:fi}le    │in a little {10:fi}le   |
      {1:~                   }│{1:~                  }|*4
      //^                                      |
    ]])
    feed('<Esc>')

    -- incsearch works after c_CTRL-R_CTRL-R
    command('let @" = "file"')
    feed('/<C-R><C-R>"')
    screen:expect([[
      the first line      │the first line     |
      in a little {2:file}    │in a little {10:file}   |
      {1:~                   }│{1:~                  }|*4
      /file^                                   |
    ]])
    feed('<Esc>')

    command('set rtp^=test/functional/fixtures')
    -- incsearch works after c_CTRL-R inserts clipboard register

    command('let @* = "first"')
    feed('/<C-R>*')
    screen:expect([[
      the {2:first} line      │the {10:first} line     |
      in a little file    │in a little file   |
      {1:~                   }│{1:~                  }|*4
      /first^                                  |
    ]])
    feed('<Esc>')

    command('let @+ = "little"')
    feed('/<C-R>+')
    screen:expect([[
      the first line      │the first line     |
      in a {2:little} file    │in a {10:little} file   |
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
      not the {2:mat}ch you're looking for        |
      the {10:mat}ch is here                       |
      {1:~                                       }|*4
      /mat/e^                                  |
    ]])

    -- Search with count and /e offset fixed in Vim patch 7.4.532.
    feed('<esc>2/mat/e')
    screen:expect([[
      not the {10:mat}ch you're looking for        |
      the {2:mat}ch is here                       |
      {1:~                                       }|*4
      /mat/e^                                  |
    ]])

    feed('<cr>')
    screen:expect([[
      not the {10:mat}ch you're looking for        |
      the {10:ma^t}ch is here                       |
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
      a  repeated {10:^line }                       |
      {10:a}  repeated {10:line }                       |*2
      {10:a}  repeated line                        |
      {1:~                                       }|
      {19:search hit BOTTOM, continuing at TOP}    |
    ]])

    -- it redraws rows above the changed one
    feed('4Grb')
    screen:expect([[
                                              |
      a  repeated {10:line }                       |
      {10:a}  repeated line                        |
      ^b  repeated {10:line }                       |
      {10:a}  repeated line                        |
      {1:~                                       }|
      {19:search hit BOTTOM, continuing at TOP}    |
    ]])
  end)

  it('works with matchadd and syntax', function()
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
    screen:expect([[
      very {102:spec^ial}{10: te}{103:xt}                       |
                                              |
      {1:~                                       }|*4
      {19:search hit BOTTOM, continuing at TOP}    |
    ]])

    -- check highlights work also in folds
    feed('zf4j')
    screen:expect([[
      {13:^+--  2 lines: very special text·········}|
      {1:~                                       }|*5
      {19:search hit BOTTOM, continuing at TOP}    |
    ]])
    command('%foldopen')
    screen:expect([[
      very {102:spec^ial}{10: te}{103:xt}                       |
                                              |
      {1:~                                       }|*4
      {19:search hit BOTTOM, continuing at TOP}    |
    ]])

    feed_command('call clearmatches()')
    screen:expect([[
      very spec{10:^ial te}xt                       |
                                              |
      {1:~                                       }|*4
      :call clearmatches()                    |
    ]])

    -- searchhl has priority over syntax, but in this case
    -- nonconflicting attributes are combined
    feed_command('syntax keyword MyGroup special')
    screen:expect([[
      very {102:spec}{104:^ial}{10: te}xt                       |
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
      {2:a/b}/c                                   |
      {1:~                                       }|*5
      :%g@a/b^                                 |
    ]])
  end)

  it('incsearch is still visible after :redraw from K_EVENT', function()
    fn.setline(1, { 'foo', 'bar' })
    feed('/foo<CR>/bar')
    screen:expect([[
      foo                                     |
      {2:bar}                                     |
      {1:~                                       }|*4
      /bar^                                    |
    ]])
    command('redraw!')
    -- There is an intermediate state where :redraw! removes 'incsearch' highlight.
    screen:expect_unchanged(true)
  end)

  it('no ml_get error with incsearch and <Cmd> mapping that opens window', function()
    command('cnoremap <F3> <Cmd>vnew<Bar>redraw!<CR>')
    fn.setline(1, { 'foo', 'bar', 'baz' })
    feed('G/z')
    screen:expect([[
      foo                                     |
      bar                                     |
      ba{2:z}                                     |
      {1:~                                       }|*3
      /z^                                      |
    ]])
    feed('<F3>')
    screen:expect([[
                          │foo                |
      {1:~                   }│bar                |
      {1:~                   }│baz                |
      {1:~                   }│{1:~                  }|*2
      {3:[No Name]            }{2:[No Name] [+]      }|
      /z^                                      |
    ]])
    eq('', n.api.nvim_get_vvar('errmsg'))
    feed('<C-G>')
    screen:expect_unchanged(true)
    eq('', n.api.nvim_get_vvar('errmsg'))
  end)

  it('highlight is not after redraw during substitute confirm prompt', function()
    fn.setline(1, { 'foo', 'bar' })
    command('set nohlsearch')
    feed(':%s/bar/baz/c<CR>')
    screen:try_resize(screen._width, screen._height - 1)
    screen:expect([[
      foo                                     |
      {2:bar}                                     |
      {1:~                                       }|
      {3:                                        }|
      {6:replace with baz? (y)es/(n)o/(a)ll/(q)ui}|
      {6:t/(l)ast/scroll up(^E)/down(^Y)}^         |
    ]])
  end)
end)
