local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, execute = helpers.clear, helpers.feed, helpers.execute
local insert = helpers.insert

describe('Screen', function()
  local screen  

  before_each(function() 
    clear()
    screen = Screen.new(nil,10)
    screen:attach()
    screen:set_default_attr_ignore( {{bold=true, foreground=255}} )
    screen:set_default_attr_ids( {{foreground = Screen.colors.LightGrey, background = Screen.colors.DarkGray}} )
  end)
  
  after_each(function()
    screen:detach()
  end)  

  describe("match and conceal", function()

    before_each(function()
      execute("let &conceallevel=1")
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
        execute("syn match dAmpersand '[&][&]' conceal cchar=∧")
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
            ~                                                    |
            ~                                                    |
            :syn match dAmpersand '[&][&]' conceal cchar=∧       |
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
          ~                                                    |
          ~                                                    |
          :syn match dAmpersand '[&][&]' conceal cchar=∧       |
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
          ~                                                    |
          ~                                                    |
          :syn match dAmpersand '[&][&]' conceal cchar=∧       |
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
          ~                                                    |
          ~                                                    |
          :syn match dAmpersand '[&][&]' conceal cchar=∧       |
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
          ~                                                    |
          ~                                                    |
          :syn match dAmpersand '[&][&]' conceal cchar=∧       |
        ]])
      end)
    end) -- multiple 
      
    it("keyword instances in initially in the document.", function()
      feed("2ilambda<cr><ESC>")
      execute("let &conceallevel=1")
      execute("syn keyword kLambda lambda conceal cchar=λ")
      screen:expect([[
        {1:λ}                                                    |
        {1:λ}                                                    |
        ^                                                     |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        :syn keyword kLambda lambda conceal cchar=λ          |
      ]])
    end) -- Keyword

    describe("regions in the document", function()

      before_each(function() 
        feed("2")
        insert("<r> a region of text </r>\n")
        execute("let &conceallevel=1")
      end)
      
      it('initially and conceal it.', function()  
        execute("syn region rText start='<r>' end='</r>' conceal cchar=R")
        screen:expect([[
          {1:R}                                                    |
          {1:R}                                                    |
          ^                                                     |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          ~                                                    |
                                                               |
        ]])
      end)

      it('initially and conceal its start tag and end tag.', function()
        -- concealends has a known bug (todo.txt) where the first match won't
        -- be replaced with cchar.
        execute("syn region rText matchgroup=rMatch start='<r>' end='</r>' concealends cchar=-")
        screen:expect([[
          {1: } a region of text {1:-}                                 |
          {1: } a region of text {1:-}                                 |
          ^                                                     |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          ~                                                    |
                                                               |
        ]])
      end)
       
      it('that are nested and conceal the nested region\'s start and end tags.', function()
        execute("syn region rText contains=rText matchgroup=rMatch start='<r>' end='</r>' concealends cchar=-")  
        insert("<r> A region with <r> a nested <r> nested region.</r> </r> </r>\n")
        screen:expect([[
          {1: } a region of text {1:-}                                 |
          {1: } a region of text {1:-}                                 |
          {1: } A region with {1: } a nested {1: } nested region.{1:-}         |
           {1:-} {1:-}                                                 |
          ^                                                     |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          ~                                                    |
                                                               |
        ]])
      end)
    end) -- regions in the document

    describe("a region of text", function()
      before_each(function() 
        execute("syntax conceal on") 
        feed("2")
        insert("<r> a region of text </r>\n")
        execute("syn region rText start='<r>' end='</r>' cchar=-")
      end)

      it("and turn on implicit concealing", function()
        screen:expect([[
          {1:-}                                                    |
          {1:-}                                                    |
          ^                                                     |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          :syn region rText start='<r>' end='</r>' cchar=-     |
        ]])
      end)

      it("and then turn on, then off, and then back on implicit concealing.", function()
        execute("syntax conceal off")
        feed("2")
        insert("<i> italian text </i>\n")
        execute("syn region iText start='<i>' end='</i>' cchar=*")
        screen:expect([[
          {1:-}                                                    |
          {1:-}                                                    |
          <i> italian text </i>                                |
          <i> italian text </i>                                |
          ^                                                     |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          :syn region iText start='<i>' end='</i>' cchar=*     |
        ]])
        execute("syntax conceal on")
        execute("syn region iText start='<i>' end='</i>' cchar=*")
        screen:expect([[
          {1:-}                                                    |
          {1:-}                                                    |
          {1:*}                                                    |
          {1:*}                                                    |
          ^                                                     |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          :syn region iText start='<i>' end='</i>' cchar=*     |
        ]])
      end)
    end) -- a region of text (implicit concealing)
  end) -- match and conceal

  describe("let the conceal level be", function() 
    before_each(function()
      insert("// No Conceal\n") 
      insert('"Conceal without a cchar"\n') 
      insert("+ With cchar\n\n") 
      execute("syn match noConceal '^//.*$'")
      execute("syn match concealNoCchar '\".\\{-}\"$' conceal")
      execute("syn match concealWCchar '^+.\\{-}$' conceal cchar=C")
    end)
    
    it("0. No concealing.", function()    
      execute("let &conceallevel=0")
      screen:expect([[
        // No Conceal                                        |
        "Conceal without a cchar"                            |
        + With cchar                                         |
                                                             |
        ^                                                     |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        :let &conceallevel=0                                 |
      ]])
    end)
    
    it("1. Conceal using cchar or reference listchars.", function()
      execute("let &conceallevel=1")
      screen:expect([[
        // No Conceal                                        |
        {1: }                                                    |
        {1:C}                                                    |
                                                             |
        ^                                                     |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        :let &conceallevel=1                                 |
      ]])
    end)
    
    it("2. Hidden unless cchar is set.", function()
      execute("let &conceallevel=2")
      screen:expect([[
        // No Conceal                                        |
                                                             |
        {1:C}                                                    |
                                                             |
        ^                                                     |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        :let &conceallevel=2                                 |
      ]])
    end)
    
    it("3. Hide all concealed text.", function() 
      execute("let &conceallevel=3")
      screen:expect([[
        // No Conceal                                        |
                                                             |
                                                             |
                                                             |
        ^                                                     |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        :let &conceallevel=3                                 |
      ]])
    end)
  end) -- conceallevel
end)
