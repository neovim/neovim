local _h = require('test.functional.helpers')
local Screen = require('test.functional.ui.screen')
local clear, feed, execute = _h.clear, _h.feed, _h.execute
local insert = _h.insert

describe('Screen', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new()
    screen:attach()
  end)

  after_each(function()
    screen:detach()
  end)

  describe('echomsg', function()
    it('one line does not cause scroll', function()
      execute('echom "line1, normal message"')
      screen:expect([[
      ^                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      line1, normal message                                |
      ]])
    end)

    it('two lines causes 1-line scroll', function()
      _h.nvim('set_option', 'cmdheight', 1)
      execute('echom "line1 line1 line1 line1" | echom "line2 line2 line2 line2"')
      screen:expect([[
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      line1 line1 line1 line1                              |
      line2 line2 line2 line2                              |
      Press ENTER or type command to continue^             |
      ]])
    end)

    it('one very long line cause 1-line scroll', function()
      execute('echom "line1.a line1.b line1.c line1.d line1.e line1.f line1.g line1.h"')
      screen:expect([[
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      line1.a line1.b line1.c line1.d line1.e line1.f line1|
      .g line1.h                                           |
      Press ENTER or type command to continue^             |
      ]])
    end)
  end)
end)
