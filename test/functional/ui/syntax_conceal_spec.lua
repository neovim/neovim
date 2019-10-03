local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, command = helpers.clear, helpers.feed, helpers.command
local eq = helpers.eq
local insert = helpers.insert

describe('Screen', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(nil,10)
    screen:attach()
    screen:set_default_attr_ids( {
      [0] = {bold=true, foreground=Screen.colors.Blue},
      [1] = {foreground = Screen.colors.LightGrey, background = Screen.colors.DarkGray},
      [2] = {bold = true, reverse = true},
      [3] = {reverse = true},
      [4] = {bold = true},
      [5] = {background = Screen.colors.Yellow},
      [6] = {background = Screen.colors.LightGrey},
    } )
  end)

  after_each(function()
    screen:detach()
  end)

  describe("match and conceal", function()

    before_each(function()
      command("let &conceallevel=1")
    end)

    describe("multiple", function()
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

      it("double characters.", function()
        screen:expect([[
            {1:∧}                                                    |
            {1:∧}                                                    |
            {1:∧}                                                    |
            {1:∧}                                                    |
            {1:∧}                                                    |
            {1:∧}                                                    |
            ^                                                     |
            {0:~                                                    }|
            {0:~                                                    }|
                                                                 |
          ]])
      end)

      it('double characters and move the cursor one line up.', function()
        feed("k")
        screen:expect([[
          {1:∧}                                                    |
          {1:∧}                                                    |
          {1:∧}                                                    |
          {1:∧}                                                    |
          {1:∧}                                                    |
          ^&&                                                   |
                                                               |
          {0:~                                                    }|
          {0:~                                                    }|
                                                               |
        ]])
      end)

      it('double characters and move the cursor to the beginning of the file.', function()
        feed("gg")
        screen:expect([[
          ^&&                                                   |
          {1:∧}                                                    |
          {1:∧}                                                    |
          {1:∧}                                                    |
          {1:∧}                                                    |
          {1:∧}                                                    |
                                                               |
          {0:~                                                    }|
          {0:~                                                    }|
                                                               |
        ]])
      end)

      it('double characters and move the cursor to the second line in the file.', function()
        feed("ggj")
        screen:expect([[
          {1:∧}                                                    |
          ^&&                                                   |
          {1:∧}                                                    |
          {1:∧}                                                    |
          {1:∧}                                                    |
          {1:∧}                                                    |
                                                               |
          {0:~                                                    }|
          {0:~                                                    }|
                                                               |
        ]])
      end)

      it('double characters and then move the cursor to the beginning of the file and back to the end of the file.', function()
        feed("ggG")
        screen:expect([[
          {1:∧}                                                    |
          {1:∧}                                                    |
          {1:∧}                                                    |
          {1:∧}                                                    |
          {1:∧}                                                    |
          {1:∧}                                                    |
          ^                                                     |
          {0:~                                                    }|
          {0:~                                                    }|
                                                               |
        ]])
      end)
    end) -- multiple

    it("keyword instances in initially in the document.", function()
      feed("2ilambda<cr><ESC>")
      command("let &conceallevel=1")
      command("syn keyword kLambda lambda conceal cchar=λ")
      screen:expect([[
        {1:λ}                                                    |
        {1:λ}                                                    |
        ^                                                     |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
                                                             |
      ]])
    end) -- Keyword

    describe("regions in the document", function()

      before_each(function()
        feed("2")
        insert("<r> a region of text </r>\n")
        command("let &conceallevel=1")
      end)

      it('initially and conceal it.', function()
        command("syn region rText start='<r>' end='</r>' conceal cchar=R")
        screen:expect([[
          {1:R}                                                    |
          {1:R}                                                    |
          ^                                                     |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
                                                               |
        ]])
      end)

      it('initially and conceal its start tag and end tag.', function()
        -- concealends has a known bug (todo.txt) where the first match won't
        -- be replaced with cchar.
        command("syn region rText matchgroup=rMatch start='<r>' end='</r>' concealends cchar=-")
        screen:expect([[
          {1: } a region of text {1:-}                                 |
          {1: } a region of text {1:-}                                 |
          ^                                                     |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
                                                               |
        ]])
      end)

      it('that are nested and conceal the nested region\'s start and end tags.', function()
        command("syn region rText contains=rText matchgroup=rMatch start='<r>' end='</r>' concealends cchar=-")
        insert("<r> A region with <r> a nested <r> nested region.</r> </r> </r>\n")
        screen:expect([[
          {1: } a region of text {1:-}                                 |
          {1: } a region of text {1:-}                                 |
          {1: } A region with {1: } a nested {1: } nested region.{1:-}         |
           {1:-} {1:-}                                                 |
          ^                                                     |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
                                                               |
        ]])
      end)
    end) -- regions in the document

    describe("a region of text", function()
      before_each(function()
        command("syntax conceal on")
        feed("2")
        insert("<r> a region of text </r>\n")
        command("syn region rText start='<r>' end='</r>' cchar=-")
      end)

      it("and turn on implicit concealing", function()
        screen:expect([[
          {1:-}                                                    |
          {1:-}                                                    |
          ^                                                     |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
                                                               |
        ]])
      end)

      it("and then turn on, then off, and then back on implicit concealing.", function()
        command("syntax conceal off")
        feed("2")
        insert("<i> italian text </i>\n")
        command("syn region iText start='<i>' end='</i>' cchar=*")
        screen:expect([[
          {1:-}                                                    |
          {1:-}                                                    |
          <i> italian text </i>                                |
          <i> italian text </i>                                |
          ^                                                     |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
                                                               |
        ]])
        command("syntax conceal on")
        command("syn region iText start='<i>' end='</i>' cchar=*")
        screen:expect([[
          {1:-}                                                    |
          {1:-}                                                    |
          {1:*}                                                    |
          {1:*}                                                    |
          ^                                                     |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
                                                               |
        ]])
      end)
    end) -- a region of text (implicit concealing)
  end) -- match and conceal

  describe("let the conceal level be", function()
    before_each(function()
      insert("// No Conceal\n")
      insert('"Conceal without a cchar"\n')
      insert("+ With cchar\n\n")
      command("syn match noConceal '^//.*$'")
      command("syn match concealNoCchar '\".\\{-}\"$' conceal")
      command("syn match concealWCchar '^+.\\{-}$' conceal cchar=C")
    end)

    it("0. No concealing.", function()
      command("let &conceallevel=0")
      screen:expect([[
        // No Conceal                                        |
        "Conceal without a cchar"                            |
        + With cchar                                         |
                                                             |
        ^                                                     |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
                                                             |
      ]])
    end)

    it("1. Conceal using cchar or reference listchars.", function()
      command("let &conceallevel=1")
      screen:expect([[
        // No Conceal                                        |
        {1: }                                                    |
        {1:C}                                                    |
                                                             |
        ^                                                     |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
                                                             |
      ]])
    end)

    it("2. Hidden unless cchar is set.", function()
      command("let &conceallevel=2")
      screen:expect([[
        // No Conceal                                        |
                                                             |
        {1:C}                                                    |
                                                             |
        ^                                                     |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
                                                             |
      ]])
    end)

    it("3. Hide all concealed text.", function()
      command("let &conceallevel=3")
      screen:expect([[
        // No Conceal                                        |
                                                             |
                                                             |
                                                             |
        ^                                                     |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
                                                             |
      ]])
    end)
  end) -- conceallevel


  describe("cursor movement", function()
    before_each(function()
      command("syn keyword concealy barf conceal cchar=b")
      command("set cole=2")
      feed('5Ofoo barf bar barf eggs<esc>')
      screen:expect([[
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo barf bar barf egg^s                               |
                                                             |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
                                                             |
      ]])

    end)

    it('between windows', function()
      feed('k')
      command("split")
      screen:expect([[
        foo {1:b} bar {1:b} eggs                                     |
        foo barf bar barf egg^s                               |
        foo {1:b} bar {1:b} eggs                                     |
                                                             |
        {2:[No Name] [+]                                        }|
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        {3:[No Name] [+]                                        }|
                                                             |
      ]])
      feed('<c-w>w')

      screen:expect([[
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
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
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo barf bar barf egg^s                               |
                                                             |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {4:-- INSERT --}                                         |
      ]])

      feed('<up>')
      screen:expect([[
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo barf bar barf egg^s                               |
        foo {1:b} bar {1:b} eggs                                     |
                                                             |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {4:-- INSERT --}                                         |
      ]])
    end)

    it('between modes cocu=iv', function()
      command('set cocu=iv')
      feed('gg')
      screen:expect([[
        ^foo barf bar barf eggs                               |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
                                                             |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
                                                             |
      ]])

      feed('i')
      screen:expect([[
        ^foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
                                                             |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {4:-- INSERT --}                                         |
      ]])

      feed('<esc>')
      screen:expect([[
        ^foo barf bar barf eggs                               |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
                                                             |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
                                                             |
      ]])

      feed('v')
      screen:expect([[
        ^foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
                                                             |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {4:-- VISUAL --}                                         |
      ]])

      feed('<esc>')
      screen:expect([[
        ^foo barf bar barf eggs                               |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
                                                             |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
                                                             |
      ]])

    end)

    it('between modes cocu=n', function()
      command('set cocu=n')
      feed('gg')
      screen:expect([[
        ^foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
                                                             |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
                                                             |
      ]])

      feed('i')
      screen:expect([[
        ^foo barf bar barf eggs                               |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
                                                             |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {4:-- INSERT --}                                         |
      ]])

      feed('<esc>')
      screen:expect([[
        ^foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
                                                             |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
                                                             |
      ]])


      feed('v')
      screen:expect([[
        ^foo barf bar barf eggs                               |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
                                                             |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {4:-- VISUAL --}                                         |
      ]])

      feed('<esc>')
      screen:expect([[
        ^foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
                                                             |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
                                                             |
      ]])
    end)

    it('and open line', function()
      feed('o')
      screen:expect([[
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        ^                                                     |
                                                             |
        {0:~                                                    }|
        {0:~                                                    }|
        {4:-- INSERT --}                                         |
      ]])
    end)

    it('and open line cocu=i', function()
      command('set cocu=i')
      feed('o')
      screen:expect([[
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        ^                                                     |
                                                             |
        {0:~                                                    }|
        {0:~                                                    }|
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
          foo {1:b} bar {1:b} eggs                                     |
          foo {1:b} bar {1:b} eggs                                     |
                                                               |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
                                                               |
        ]])
      end)

      it('cocu=', function()
        feed('/')
        screen:expect([[
          foo barf bar barf eggs                               |
          foo {1:b} bar {1:b} eggs x                                   |
          foo {1:b} bar {1:b} eggs xy                                  |
          foo {1:b} bar {1:b} eggs                                     |
          foo {1:b} bar {1:b} eggs                                     |
                                                               |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          /^                                                    |
        ]])

        feed('x')
        screen:expect([[
          foo {1:b} bar {1:b} eggs                                     |
          foo barf bar barf eggs {3:x}                             |
          foo {1:b} bar {1:b} eggs {5:x}y                                  |
          foo {1:b} bar {1:b} eggs                                     |
          foo {1:b} bar {1:b} eggs                                     |
                                                               |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          /x^                                                   |
        ]])

        feed('y')
        screen:expect([[
          foo {1:b} bar {1:b} eggs                                     |
          foo {1:b} bar {1:b} eggs x                                   |
          foo barf bar barf eggs {3:xy}                            |
          foo {1:b} bar {1:b} eggs                                     |
          foo {1:b} bar {1:b} eggs                                     |
                                                               |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          /xy^                                                  |
        ]])

        feed('<c-w>')
        screen:expect([[
          foo barf bar barf eggs                               |
          foo {1:b} bar {1:b} eggs x                                   |
          foo {1:b} bar {1:b} eggs xy                                  |
          foo {1:b} bar {1:b} eggs                                     |
          foo {1:b} bar {1:b} eggs                                     |
                                                               |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
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
          foo {1:b} bar {1:b} eggs                                     |
          foo {1:b} bar {1:b} eggs                                     |
                                                               |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          /^                                                    |
        ]])

        feed('x')
        screen:expect([[
          foo {1:b} bar {1:b} eggs                                     |
          foo {1:b} bar {1:b} eggs {3:x}                                   |
          foo {1:b} bar {1:b} eggs {5:x}y                                  |
          foo {1:b} bar {1:b} eggs                                     |
          foo {1:b} bar {1:b} eggs                                     |
                                                               |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          /x^                                                   |
        ]])

        feed('y')
        screen:expect([[
          foo {1:b} bar {1:b} eggs                                     |
          foo {1:b} bar {1:b} eggs x                                   |
          foo {1:b} bar {1:b} eggs {3:xy}                                  |
          foo {1:b} bar {1:b} eggs                                     |
          foo {1:b} bar {1:b} eggs                                     |
                                                               |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          /xy^                                                  |
        ]])

        feed('<c-w>')
        screen:expect([[
          foo {1:b} bar {1:b} eggs                                     |
          foo {1:b} bar {1:b} eggs x                                   |
          foo {1:b} bar {1:b} eggs xy                                  |
          foo {1:b} bar {1:b} eggs                                     |
          foo {1:b} bar {1:b} eggs                                     |
                                                               |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          /^                                                    |
        ]])

        feed('<esc>')
        screen:expect([[
          ^foo barf bar barf eggs                               |
          foo {1:b} bar {1:b} eggs x                                   |
          foo {1:b} bar {1:b} eggs xy                                  |
          foo {1:b} bar {1:b} eggs                                     |
          foo {1:b} bar {1:b} eggs                                     |
                                                               |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
                                                               |
        ]])
      end)

      it('cocu=n', function()
        command('set cocu=n')
        screen:expect([[
          ^foo {1:b} bar {1:b} eggs                                     |
          foo {1:b} bar {1:b} eggs x                                   |
          foo {1:b} bar {1:b} eggs xy                                  |
          foo {1:b} bar {1:b} eggs                                     |
          foo {1:b} bar {1:b} eggs                                     |
                                                               |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
                                                               |
        ]])

        feed('/')
        -- NB: we don't do this redraw. Probably best to still skip it,
        -- to avoid annoying distraction from the cmdline
        screen:expect([[
          foo {1:b} bar {1:b} eggs                                     |
          foo {1:b} bar {1:b} eggs x                                   |
          foo {1:b} bar {1:b} eggs xy                                  |
          foo {1:b} bar {1:b} eggs                                     |
          foo {1:b} bar {1:b} eggs                                     |
                                                               |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          /^                                                    |
        ]])

        feed('x')
        screen:expect([[
          foo {1:b} bar {1:b} eggs                                     |
          foo barf bar barf eggs {3:x}                             |
          foo {1:b} bar {1:b} eggs {5:x}y                                  |
          foo {1:b} bar {1:b} eggs                                     |
          foo {1:b} bar {1:b} eggs                                     |
                                                               |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          /x^                                                   |
        ]])

        feed('<c-w>')
        screen:expect([[
          foo barf bar barf eggs                               |
          foo {1:b} bar {1:b} eggs x                                   |
          foo {1:b} bar {1:b} eggs xy                                  |
          foo {1:b} bar {1:b} eggs                                     |
          foo {1:b} bar {1:b} eggs                                     |
                                                               |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          /^                                                    |
        ]])

        feed('<esc>')
        screen:expect([[
          ^foo {1:b} bar {1:b} eggs                                     |
          foo {1:b} bar {1:b} eggs x                                   |
          foo {1:b} bar {1:b} eggs xy                                  |
          foo {1:b} bar {1:b} eggs                                     |
          foo {1:b} bar {1:b} eggs                                     |
                                                               |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
                                                               |
        ]])
      end)
    end)

    it('redraws properly with concealcursor in visual mode', function()
      command('set concealcursor=v conceallevel=2')

      feed('10Ofoo barf bar barf eggs<esc>')
      feed(':3<cr>o    a<Esc>ggV')
      screen:expect{grid=[[
        ^f{6:oo }{1:b}{6: bar }{1:b}{6: eggs}                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
            a                                                |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        {4:-- VISUAL LINE --}                                    |
      ]]}
      feed(string.rep('j', 15))
      screen:expect{grid=[[
        {6:foo }{1:b}{6: bar }{1:b}{6: eggs}                                     |
        {6:foo }{1:b}{6: bar }{1:b}{6: eggs}                                     |
        {6:foo }{1:b}{6: bar }{1:b}{6: eggs}                                     |
        {6:foo }{1:b}{6: bar }{1:b}{6: eggs}                                     |
        {6:foo }{1:b}{6: bar }{1:b}{6: eggs}                                     |
        {6:foo }{1:b}{6: bar }{1:b}{6: eggs}                                     |
        {6:foo }{1:b}{6: bar }{1:b}{6: eggs}                                     |
        {6:foo }{1:b}{6: bar }{1:b}{6: eggs}                                     |
        ^f{6:oo }{1:b}{6: bar }{1:b}{6: eggs}                                     |
        {4:-- VISUAL LINE --}                                    |
      ]]}
      feed(string.rep('k', 15))
      screen:expect{grid=[[
        ^f{6:oo }{1:b}{6: bar }{1:b}{6: eggs}                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
            a                                                |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        foo {1:b} bar {1:b} eggs                                     |
        {4:-- VISUAL LINE --}                                    |
      ]]}
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
    screen:expect{grid=[[
      aaa                                                  |
      bbb                                                  |
      ccc                                                  |
      ^                                                     |
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
                                                           |
    ]]}

    -- XXX: hack to get notifications, and check only a single line is
    --      updated.  Could use next_msg() also.
    local orig_handle_grid_line = screen._handle_grid_line
    local grid_lines = {}
    function screen._handle_grid_line(self, grid, row, col, items)
      table.insert(grid_lines, {row, col, items})
      orig_handle_grid_line(self, grid, row, col, items)
    end
    feed('k')
    screen:expect{grid=[[
      aaa                                                  |
      bbb                                                  |
      ^ccc                                                  |
                                                           |
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
                                                           |
    ]]}
    eq(grid_lines, {{2, 0, {{'c', 0, 3}}}})
  end)
end)
