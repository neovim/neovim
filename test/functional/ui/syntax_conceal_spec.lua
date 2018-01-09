local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, command = helpers.clear, helpers.feed, helpers.command
local insert = helpers.insert

describe('Screen', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(nil,10)
    screen:attach()
    screen:set_default_attr_ids( {
      [0] = {bold=true, foreground=Screen.colors.Blue},
      [1] = {foreground = Screen.colors.LightGrey, background = Screen.colors.DarkGray}
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
end)
