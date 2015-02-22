local helpers = require('test.functional.helpers')
local Screen = require('test.functional.ui.screen')
local clear, feed, execute = helpers.clear, helpers.feed, helpers.execute
local insert = helpers.insert

describe('Screen', function()
  local screen   
  
  describe("Concealing multiple '&&' With 'syn-match'", function()
    before_each(function()
      clear()
      screen = Screen.new()
      screen:attach()
      screen:set_default_attr_ignore( {{}, {bold=true, foreground=255}} ) 
      insert([[
        &&
        &&
        &&
        &&
        &&
        &&
        ]])
      screen:expect([[
        &&                                                   |
        &&                                                   |
        &&                                                   |
        &&                                                   |
        &&                                                   |
        &&                                                   |
        ^                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
                                                             |
      ]])
      execute("let &conceallevel=1")
      execute("syn match dAmpersand '[&][&]' conceal cchar=∧")
    end)

    after_each(function()
      screen:detach()
    end)

    -- Begin && concealing tests
    it('Conceal All &&', function()
      screen:expect([[
          {1:∧}                                                    |
          {1:∧}                                                    |
          {1:∧}                                                    |
          {1:∧}                                                    |
          {1:∧}                                                    |
          {1:∧}                                                    |
          ^                                                    |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          ~                                                    |
          :syn match dAmpersand '[&][&]' conceal cchar=∧       |
        ]], {[1] = {foreground = Screen.colors.LightGrey, background = Screen.colors.DarkGray}})
    end)
    it('Move Cursor Up', function() 
      feed("k")
      screen:expect([[
        {1:∧}                                                    |
        {1:∧}                                                    |
        {1:∧}                                                    |
        {1:∧}                                                    |
        {1:∧}                                                    |
        ^&                                                   |
                                                             |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        :syn match dAmpersand '[&][&]' conceal cchar=∧       |
      ]], {[1] = {foreground = Screen.colors.LightGrey, background = Screen.colors.DarkGray}})
    end)
    it('Move Cursor to Top', function()
      feed("gg")
      screen:expect([[
        ^&                                                   |
        {1:∧}                                                    |
        {1:∧}                                                    |
        {1:∧}                                                    |
        {1:∧}                                                    |
        {1:∧}                                                    |
                                                             |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        :syn match dAmpersand '[&][&]' conceal cchar=∧       |
      ]], {[1] = {foreground = Screen.colors.LightGrey, background = Screen.colors.DarkGray}})
    end)
    it('Move Cursor Down', function() 
      feed("ggj")
      screen:expect([[
        {1:∧}                                                    |
        ^&                                                   |
        {1:∧}                                                    |
        {1:∧}                                                    |
        {1:∧}                                                    |
        {1:∧}                                                    |
                                                             |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        :syn match dAmpersand '[&][&]' conceal cchar=∧       |
      ]], {[1] = {foreground = Screen.colors.LightGrey, background = Screen.colors.DarkGray}})
    end)
    it('Move Cursor to Bottom', function() 
      feed("ggG")
      screen:expect([[
        {1:∧}                                                    |
        {1:∧}                                                    |
        {1:∧}                                                    |
        {1:∧}                                                    |
        {1:∧}                                                    |
        {1:∧}                                                    |
        ^                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        ~                                                    |
        :syn match dAmpersand '[&][&]' conceal cchar=∧       |
      ]], {[1] = {foreground = Screen.colors.LightGrey, background = Screen.colors.DarkGray}})
    end)
  end)
end)

