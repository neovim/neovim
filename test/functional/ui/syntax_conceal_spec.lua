local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear, feed, command = n.clear, n.feed, n.command
local eq = t.eq
local insert = n.insert
local poke_eventloop = n.poke_eventloop
local exec = n.exec

describe('Screen', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(nil, 10)
    screen:set_default_attr_ids({
      [0] = { bold = true, foreground = Screen.colors.Blue },
      [1] = { foreground = Screen.colors.LightGrey, background = Screen.colors.DarkGray },
      [2] = { bold = true, reverse = true },
      [3] = { reverse = true },
      [4] = { bold = true },
      [5] = { background = Screen.colors.Yellow },
      [6] = { foreground = Screen.colors.Black, background = Screen.colors.LightGrey },
    })
  end)

  describe('match and conceal', function()
    before_each(function()
      command('let &conceallevel=1')
    end)

    describe('multiple', function()
      before_each(function()
        insert([[
          &&
          &&
          &&
          &&
          &&
          &&
          ]])
        command("syn match dAmpersand '[&][&]' conceal cchar=∧")
      end)

      it('double characters.', function()
        screen:expect([[
            {1:∧}                                                    |*6
            ^                                                     |
            {0:~                                                    }|*2
                                                                 |
          ]])
      end)

      it('double characters and move the cursor one line up.', function()
        feed('k')
        screen:expect([[
          {1:∧}                                                    |*5
          ^&&                                                   |
                                                               |
          {0:~                                                    }|*2
                                                               |
        ]])
      end)

      it('double characters and move the cursor to the beginning of the file.', function()
        feed('gg')
        screen:expect([[
          ^&&                                                   |
          {1:∧}                                                    |*5
                                                               |
          {0:~                                                    }|*2
                                                               |
        ]])
      end)

      it('double characters and move the cursor to the second line in the file.', function()
        feed('ggj')
        screen:expect([[
          {1:∧}                                                    |
          ^&&                                                   |
          {1:∧}                                                    |*4
                                                               |
          {0:~                                                    }|*2
                                                               |
        ]])
      end)

      it(
        'double characters and then move the cursor to the beginning of the file and back to the end of the file.',
        function()
          feed('ggG')
          screen:expect([[
          {1:∧}                                                    |*6
          ^                                                     |
          {0:~                                                    }|*2
                                                               |
        ]])
        end
      )
    end) -- multiple

    it('keyword instances in initially in the document.', function()
      feed('2ilambda<cr><ESC>')
      command('let &conceallevel=1')
      command('syn keyword kLambda lambda conceal cchar=λ')
      screen:expect([[
        {1:λ}                                                    |*2
        ^                                                     |
        {0:~                                                    }|*6
                                                             |
      ]])
    end) -- Keyword

    describe('regions in the document', function()
      before_each(function()
        feed('2')
        insert('<r> a region of text </r>\n')
        command('let &conceallevel=1')
      end)

      it('initially and conceal it.', function()
        command("syn region rText start='<r>' end='</r>' conceal cchar=R")
        screen:expect([[
          {1:R}                                                    |*2
          ^                                                     |
          {0:~                                                    }|*6
                                                               |
        ]])
      end)

      it('initially and conceal its start tag and end tag.', function()
        -- concealends has a known bug (todo.txt) where the first match won't
        -- be replaced with cchar.
        command("syn region rText matchgroup=rMatch start='<r>' end='</r>' concealends cchar=-")
        screen:expect([[
          {1: } a region of text {1:-}                                 |*2
          ^                                                     |
          {0:~                                                    }|*6
                                                               |
        ]])
      end)

      it("that are nested and conceal the nested region's start and end tags.", function()
        command(
          "syn region rText contains=rText matchgroup=rMatch start='<r>' end='</r>' concealends cchar=-"
        )
        insert('<r> A region with <r> a nested <r> nested region.</r> </r> </r>\n')
        screen:expect([[
          {1: } a region of text {1:-}                                 |*2
          {1: } A region with {1: } a nested {1: } nested region.{1:-}         |
           {1:-} {1:-}                                                 |
          ^                                                     |
          {0:~                                                    }|*4
                                                               |
        ]])
      end)
    end) -- regions in the document

    describe('a region of text', function()
      before_each(function()
        command('syntax conceal on')
        feed('2')
        insert('<r> a region of text </r>\n')
        command("syn region rText start='<r>' end='</r>' cchar=-")
      end)

      it('and turn on implicit concealing', function()
        screen:expect([[
          {1:-}                                                    |*2
          ^                                                     |
          {0:~                                                    }|*6
                                                               |
        ]])
      end)

      it('and then turn on, then off, and then back on implicit concealing.', function()
        command('syntax conceal off')
        feed('2')
        insert('<i> italian text </i>\n')
        command("syn region iText start='<i>' end='</i>' cchar=*")
        screen:expect([[
          {1:-}                                                    |*2
          <i> italian text </i>                                |*2
          ^                                                     |
          {0:~                                                    }|*4
                                                               |
        ]])
        command('syntax conceal on')
        command("syn region iText start='<i>' end='</i>' cchar=*")
        screen:expect([[
          {1:-}                                                    |*2
          {1:*}                                                    |*2
          ^                                                     |
          {0:~                                                    }|*4
                                                               |
        ]])
      end)
    end) -- a region of text (implicit concealing)

    it('cursor position when entering Insert mode with cocu=ni #13916', function()
      insert([[foobarfoobarfoobar]])
      -- move to end of line
      feed('$')
      command('set concealcursor=ni')
      command('syn match Foo /foobar/ conceal cchar=&')
      screen:expect([[
        {1:&&&}^                                                  |
        {0:~                                                    }|*8
                                                             |
      ]])
      feed('i')
      -- cursor should stay in place, not jump to column 16
      screen:expect([[
        {1:&&&}^                                                  |
        {0:~                                                    }|*8
        {4:-- INSERT --}                                         |
      ]])
    end)

    it('cursor position when scrolling in Normal mode with cocu=n #31271', function()
      insert(('foo\n'):rep(9) .. 'foofoobarfoofoo' .. ('\nfoo'):rep(9))
      command('set concealcursor=n')
      command('syn match Foo /bar/ conceal cchar=&')
      feed('gg5<C-E>10gg$')
      screen:expect([[
        foo                                                  |*4
        foofoo{1:&}foofo^o                                        |
        foo                                                  |*4
                                                             |
      ]])
      feed('zz')
      screen:expect_unchanged()
      feed('zt')
      screen:expect([[
        foofoo{1:&}foofo^o                                        |
        foo                                                  |*8
                                                             |
      ]])
      feed('zt')
      screen:expect_unchanged()
      feed('zb')
      screen:expect([[
        foo                                                  |*8
        foofoo{1:&}foofo^o                                        |
                                                             |
      ]])
      feed('zb')
      screen:expect_unchanged()
    end)
  end) -- match and conceal

  describe('let the conceal level be', function()
    before_each(function()
      insert('// No Conceal\n')
      insert('"Conceal without a cchar"\n')
      insert('+ With cchar\n\n')
      command("syn match noConceal '^//.*$'")
      command('syn match concealNoCchar \'".\\{-}"$\' conceal')
      command("syn match concealWCchar '^+.\\{-}$' conceal cchar=C")
    end)

    it('0. No concealing.', function()
      command('let &conceallevel=0')
      screen:expect([[
        // No Conceal                                        |
        "Conceal without a cchar"                            |
        + With cchar                                         |
                                                             |
        ^                                                     |
        {0:~                                                    }|*4
                                                             |
      ]])
    end)

    it('1. Conceal using cchar or reference listchars.', function()
      command('let &conceallevel=1')
      screen:expect([[
        // No Conceal                                        |
        {1: }                                                    |
        {1:C}                                                    |
                                                             |
        ^                                                     |
        {0:~                                                    }|*4
                                                             |
      ]])
    end)

    it('2. Hidden unless cchar is set.', function()
      command('let &conceallevel=2')
      screen:expect([[
        // No Conceal                                        |
                                                             |
        {1:C}                                                    |
                                                             |
        ^                                                     |
        {0:~                                                    }|*4
                                                             |
      ]])
    end)

    it('3. Hide all concealed text.', function()
      command('let &conceallevel=3')
      screen:expect([[
        // No Conceal                                        |
                                                             |*3
        ^                                                     |
        {0:~                                                    }|*4
                                                             |
      ]])
    end)
  end) -- conceallevel

  describe('cursor movement', function()
    before_each(function()
      command('syn keyword concealy barf conceal cchar=b')
      command('set cole=2')
      feed('5Ofoo barf bar barf eggs<esc>')
      screen:expect([[
        foo {1:b} bar {1:b} eggs                                     |*4
        foo barf bar barf egg^s                               |
                                                             |
        {0:~                                                    }|*3
                                                             |
      ]])
    end)

    it('between windows', function()
      feed('k')
      command('split')
      screen:expect([[
        foo {1:b} bar {1:b} eggs                                     |
        foo barf bar barf egg^s                               |
        foo {1:b} bar {1:b} eggs                                     |
                                                             |
        {2:[No Name] [+]                                        }|
        foo {1:b} bar {1:b} eggs                                     |*3
        {3:[No Name] [+]                                        }|
                                                             |
      ]])
      feed('<c-w>w')

      screen:expect([[
        foo {1:b} bar {1:b} eggs                                     |*3
                                                             |
        {3:[No Name] [+]                                        }|
        foo {1:b} bar {1:b} eggs                                     |
        foo barf bar barf egg^s                               |
        foo {1:b} bar {1:b} eggs                                     |
        {2:[No Name] [+]                                        }|
                                                             |
      ]])
    end)

    it('in insert mode', function()
      feed('i')
      screen:expect([[
        foo {1:b} bar {1:b} eggs                                     |*4
        foo barf bar barf egg^s                               |
                                                             |
        {0:~                                                    }|*3
        {4:-- INSERT --}                                         |
      ]])

      feed('<up>')
      screen:expect([[
        foo {1:b} bar {1:b} eggs                                     |*3
        foo barf bar barf egg^s                               |
        foo {1:b} bar {1:b} eggs                                     |
                                                             |
        {0:~                                                    }|*3
        {4:-- INSERT --}                                         |
      ]])
    end)

    it('between modes cocu=iv', function()
      command('set cocu=iv')
      feed('gg')
      screen:expect([[
        ^foo barf bar barf eggs                               |
        foo {1:b} bar {1:b} eggs                                     |*4
                                                             |
        {0:~                                                    }|*3
                                                             |
      ]])

      feed('i')
      screen:expect([[
        ^foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |*4
                                                             |
        {0:~                                                    }|*3
        {4:-- INSERT --}                                         |
      ]])

      feed('<esc>')
      screen:expect([[
        ^foo barf bar barf eggs                               |
        foo {1:b} bar {1:b} eggs                                     |*4
                                                             |
        {0:~                                                    }|*3
                                                             |
      ]])

      feed('v')
      screen:expect([[
        ^foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |*4
                                                             |
        {0:~                                                    }|*3
        {4:-- VISUAL --}                                         |
      ]])

      feed('<esc>')
      screen:expect([[
        ^foo barf bar barf eggs                               |
        foo {1:b} bar {1:b} eggs                                     |*4
                                                             |
        {0:~                                                    }|*3
                                                             |
      ]])
    end)

    it('between modes cocu=n', function()
      command('set cocu=n')
      feed('gg')
      screen:expect([[
        ^foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |*4
                                                             |
        {0:~                                                    }|*3
                                                             |
      ]])

      feed('i')
      screen:expect([[
        ^foo barf bar barf eggs                               |
        foo {1:b} bar {1:b} eggs                                     |*4
                                                             |
        {0:~                                                    }|*3
        {4:-- INSERT --}                                         |
      ]])

      feed('<esc>')
      screen:expect([[
        ^foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |*4
                                                             |
        {0:~                                                    }|*3
                                                             |
      ]])

      feed('v')
      screen:expect([[
        ^foo barf bar barf eggs                               |
        foo {1:b} bar {1:b} eggs                                     |*4
                                                             |
        {0:~                                                    }|*3
        {4:-- VISUAL --}                                         |
      ]])

      feed('<esc>')
      screen:expect([[
        ^foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |*4
                                                             |
        {0:~                                                    }|*3
                                                             |
      ]])

      feed('r')
      screen:expect_unchanged()

      feed('m')
      screen:expect([[
        ^moo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |*4
                                                             |
        {0:~                                                    }|*3
                                                             |
      ]])
    end)

    it('and open line', function()
      feed('o')
      screen:expect([[
        foo {1:b} bar {1:b} eggs                                     |*5
        ^                                                     |
                                                             |
        {0:~                                                    }|*2
        {4:-- INSERT --}                                         |
      ]])
    end)

    it('and open line cocu=i', function()
      command('set cocu=i')
      feed('o')
      screen:expect([[
        foo {1:b} bar {1:b} eggs                                     |*5
        ^                                                     |
                                                             |
        {0:~                                                    }|*2
        {4:-- INSERT --}                                         |
      ]])
    end)

    describe('with incsearch', function()
      before_each(function()
        command('set incsearch hlsearch')
        feed('2GA x<esc>3GA xy<esc>gg')
        screen:expect([[
          ^foo barf bar barf eggs                               |
          foo {1:b} bar {1:b} eggs x                                   |
          foo {1:b} bar {1:b} eggs xy                                  |
          foo {1:b} bar {1:b} eggs                                     |*2
                                                               |
          {0:~                                                    }|*3
                                                               |
        ]])
      end)

      it('cocu=', function()
        feed('/')
        screen:expect([[
          foo barf bar barf eggs                               |
          foo {1:b} bar {1:b} eggs x                                   |
          foo {1:b} bar {1:b} eggs xy                                  |
          foo {1:b} bar {1:b} eggs                                     |*2
                                                               |
          {0:~                                                    }|*3
          /^                                                    |
        ]])

        feed('x')
        screen:expect([[
          foo {1:b} bar {1:b} eggs                                     |
          foo barf bar barf eggs {3:x}                             |
          foo {1:b} bar {1:b} eggs {5:x}y                                  |
          foo {1:b} bar {1:b} eggs                                     |*2
                                                               |
          {0:~                                                    }|*3
          /x^                                                   |
        ]])

        feed('y')
        screen:expect([[
          foo {1:b} bar {1:b} eggs                                     |
          foo {1:b} bar {1:b} eggs x                                   |
          foo barf bar barf eggs {3:xy}                            |
          foo {1:b} bar {1:b} eggs                                     |*2
                                                               |
          {0:~                                                    }|*3
          /xy^                                                  |
        ]])

        feed('<c-w>')
        screen:expect([[
          foo barf bar barf eggs                               |
          foo {1:b} bar {1:b} eggs x                                   |
          foo {1:b} bar {1:b} eggs xy                                  |
          foo {1:b} bar {1:b} eggs                                     |*2
                                                               |
          {0:~                                                    }|*3
          /^                                                    |
        ]])
      end)

      it('cocu=c', function()
        command('set cocu=c')

        feed('/')
        -- NB: we don't do this redraw. Probably best to still skip it,
        -- to avoid annoying distraction from the cmdline
        screen:expect([[
          foo barf bar barf eggs                               |
          foo {1:b} bar {1:b} eggs x                                   |
          foo {1:b} bar {1:b} eggs xy                                  |
          foo {1:b} bar {1:b} eggs                                     |*2
                                                               |
          {0:~                                                    }|*3
          /^                                                    |
        ]])

        feed('x')
        screen:expect([[
          foo {1:b} bar {1:b} eggs                                     |
          foo {1:b} bar {1:b} eggs {3:x}                                   |
          foo {1:b} bar {1:b} eggs {5:x}y                                  |
          foo {1:b} bar {1:b} eggs                                     |*2
                                                               |
          {0:~                                                    }|*3
          /x^                                                   |
        ]])

        feed('y')
        screen:expect([[
          foo {1:b} bar {1:b} eggs                                     |
          foo {1:b} bar {1:b} eggs x                                   |
          foo {1:b} bar {1:b} eggs {3:xy}                                  |
          foo {1:b} bar {1:b} eggs                                     |*2
                                                               |
          {0:~                                                    }|*3
          /xy^                                                  |
        ]])

        feed('<c-w>')
        screen:expect([[
          foo {1:b} bar {1:b} eggs                                     |
          foo {1:b} bar {1:b} eggs x                                   |
          foo {1:b} bar {1:b} eggs xy                                  |
          foo {1:b} bar {1:b} eggs                                     |*2
                                                               |
          {0:~                                                    }|*3
          /^                                                    |
        ]])

        feed('<esc>')
        screen:expect([[
          ^foo barf bar barf eggs                               |
          foo {1:b} bar {1:b} eggs x                                   |
          foo {1:b} bar {1:b} eggs xy                                  |
          foo {1:b} bar {1:b} eggs                                     |*2
                                                               |
          {0:~                                                    }|*3
                                                               |
        ]])
      end)

      it('cocu=n', function()
        command('set cocu=n')
        screen:expect([[
          ^foo {1:b} bar {1:b} eggs                                     |
          foo {1:b} bar {1:b} eggs x                                   |
          foo {1:b} bar {1:b} eggs xy                                  |
          foo {1:b} bar {1:b} eggs                                     |*2
                                                               |
          {0:~                                                    }|*3
                                                               |
        ]])

        feed('/')
        -- NB: we don't do this redraw. Probably best to still skip it,
        -- to avoid annoying distraction from the cmdline
        screen:expect([[
          foo {1:b} bar {1:b} eggs                                     |
          foo {1:b} bar {1:b} eggs x                                   |
          foo {1:b} bar {1:b} eggs xy                                  |
          foo {1:b} bar {1:b} eggs                                     |*2
                                                               |
          {0:~                                                    }|*3
          /^                                                    |
        ]])

        feed('x')
        screen:expect([[
          foo {1:b} bar {1:b} eggs                                     |
          foo barf bar barf eggs {3:x}                             |
          foo {1:b} bar {1:b} eggs {5:x}y                                  |
          foo {1:b} bar {1:b} eggs                                     |*2
                                                               |
          {0:~                                                    }|*3
          /x^                                                   |
        ]])

        feed('<c-w>')
        screen:expect([[
          foo barf bar barf eggs                               |
          foo {1:b} bar {1:b} eggs x                                   |
          foo {1:b} bar {1:b} eggs xy                                  |
          foo {1:b} bar {1:b} eggs                                     |*2
                                                               |
          {0:~                                                    }|*3
          /^                                                    |
        ]])

        feed('<esc>')
        screen:expect([[
          ^foo {1:b} bar {1:b} eggs                                     |
          foo {1:b} bar {1:b} eggs x                                   |
          foo {1:b} bar {1:b} eggs xy                                  |
          foo {1:b} bar {1:b} eggs                                     |*2
                                                               |
          {0:~                                                    }|*3
                                                               |
        ]])
      end)
    end)

    it('redraws properly with concealcursor in visual mode', function()
      command('set concealcursor=v conceallevel=2')

      feed('10Ofoo barf bar barf eggs<esc>')
      feed(':3<cr>o    a<Esc>ggV')
      screen:expect {
        grid = [[
        ^f{6:oo }{1:b}{6: bar }{1:b}{6: eggs}                                     |
        foo {1:b} bar {1:b} eggs                                     |*2
            a                                                |
        foo {1:b} bar {1:b} eggs                                     |*5
        {4:-- VISUAL LINE --}                                    |
      ]],
      }
      feed(string.rep('j', 15))
      screen:expect {
        grid = [[
        {6:foo }{1:b}{6: bar }{1:b}{6: eggs}                                     |*8
        ^f{6:oo }{1:b}{6: bar }{1:b}{6: eggs}                                     |
        {4:-- VISUAL LINE --}                                    |
      ]],
      }
      feed(string.rep('k', 15))
      screen:expect {
        grid = [[
        ^f{6:oo }{1:b}{6: bar }{1:b}{6: eggs}                                     |
        foo {1:b} bar {1:b} eggs                                     |*2
            a                                                |
        foo {1:b} bar {1:b} eggs                                     |*5
        {4:-- VISUAL LINE --}                                    |
      ]],
      }
    end)
  end)

  it('redraws not too much with conceallevel=1', function()
    command('set conceallevel=1')
    command('set redrawdebug+=nodelta')

    insert([[
    aaa
    bbb
    ccc
    ]])
    screen:expect {
      grid = [[
      aaa                                                  |
      bbb                                                  |
      ccc                                                  |
      ^                                                     |
      {0:~                                                    }|*5
                                                           |
    ]],
    }

    -- XXX: hack to get notifications, and check only a single line is
    --      updated.  Could use next_msg() also.
    local orig_handle_grid_line = screen._handle_grid_line
    local grid_lines = {}
    function screen._handle_grid_line(self, grid, row, col, items)
      table.insert(grid_lines, { row, col, items })
      orig_handle_grid_line(self, grid, row, col, items)
    end
    feed('k')
    screen:expect {
      grid = [[
      aaa                                                  |
      bbb                                                  |
      ^ccc                                                  |
                                                           |
      {0:~                                                    }|*5
                                                           |
    ]],
    }
    eq({ { 2, 0, { { 'c', 0, 3 }, { ' ', 0, 50 } } }, { 3, 0, { { ' ', 0, 53 } } } }, grid_lines)
  end)

  it('K_EVENT should not cause extra redraws with concealcursor #13196', function()
    command('set conceallevel=1')
    command('set concealcursor=nv')
    command('set redrawdebug+=nodelta')

    insert([[
    aaa
    bbb
    ccc
    ]])
    screen:expect {
      grid = [[
      aaa                                                  |
      bbb                                                  |
      ccc                                                  |
      ^                                                     |
      {0:~                                                    }|*5
                                                           |
    ]],
    }

    -- XXX: hack to get notifications, and check only a single line is
    --      updated.  Could use next_msg() also.
    local orig_handle_grid_line = screen._handle_grid_line
    local grid_lines = {}
    function screen._handle_grid_line(self, grid, row, col, items)
      table.insert(grid_lines, { row, col, items })
      orig_handle_grid_line(self, grid, row, col, items)
    end
    feed('k')
    screen:expect {
      grid = [[
      aaa                                                  |
      bbb                                                  |
      ^ccc                                                  |
                                                           |
      {0:~                                                    }|*5
                                                           |
    ]],
    }
    eq({ { 2, 0, { { 'c', 0, 3 }, { ' ', 0, 50 } } } }, grid_lines)
    grid_lines = {}
    poke_eventloop() -- causes K_EVENT key
    screen:expect_unchanged()
    eq({}, grid_lines) -- no redraw was done
  end)

  describe('concealed line has the correct cursor column', function()
    -- oldtest: Test_cursor_column_in_concealed_line_after_window_scroll()
    it('after window scroll', function()
      insert([[
        3split
        let m = matchadd('Conceal', '=')
        setl conceallevel=2 concealcursor=nc
        normal gg
        "==expr==]])
      feed('gg')
      command('file Xcolesearch')
      command('set nomodified')

      command('so')
      screen:expect {
        grid = [[
        ^3split                                               |
        let m  matchadd('Conceal', '')                       |
        setl conceallevel2 concealcursornc                   |
        {2:Xcolesearch                                          }|
        3split                                               |
        let m = matchadd('Conceal', '=')                     |
        setl conceallevel=2 concealcursor=nc                 |
        normal gg                                            |
        {3:Xcolesearch                                          }|
                                                             |
      ]],
      }

      -- Jump to something that is beyond the bottom of the window,
      -- so there's a scroll down.
      feed('/expr<CR>')

      -- Are the concealed parts of the current line really hidden?
      -- Is the window's cursor column properly updated for hidden
      -- parts of the current line?
      screen:expect {
        grid = [[
        setl conceallevel2 concealcursornc                   |
        normal gg                                            |
        "{5:^expr}                                                |
        {2:Xcolesearch                                          }|
        3split                                               |
        let m = matchadd('Conceal', '=')                     |
        setl conceallevel=2 concealcursor=nc                 |
        normal gg                                            |
        {3:Xcolesearch                                          }|
        /expr                                                |
      ]],
      }
    end)

    -- oldtest: Test_cursor_column_in_concealed_line_after_leftcol_change()
    it('after leftcol change', function()
      exec([[
        0put = 'ab' .. repeat('-', &columns) .. 'c'
        call matchadd('Conceal', '-')
        set nowrap ss=0 cole=3 cocu=n
      ]])

      -- Go to the end of the line (3 columns beyond the end of the screen).
      -- Horizontal scroll would center the cursor in the screen line, but conceal
      -- makes it go to screen column 1.
      feed('$')

      -- Are the concealed parts of the current line really hidden?
      -- Is the window's cursor column properly updated for conceal?
      screen:expect {
        grid = [[
        ^c                                                    |
                                                             |
        {0:~                                                    }|*7
                                                             |
      ]],
      }
    end)
  end)
end)
