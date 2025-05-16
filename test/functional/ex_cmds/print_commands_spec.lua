local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear, eq, command, fn = n.clear, t.eq, n.command, n.fn
local assert_alive = n.assert_alive

describe(':z^', function()
  before_each(clear)

  it('correctly sets the cursor after :z^', function()
    command('z^')
    eq(1, fn.line('.'))
  end)
end)

describe(':print', function()
  before_each(clear)

  it('does not crash when printing 0xFF byte #34044', function()
    local screen = Screen.new()
    -- Needs raw 0xFF byte, not 0xFF char
    command('call setline(1, "foo\\xFFbar")')
    command('%print')
    screen:expect([[
      ^foo{18:<ff>}bar                                           |
      {1:~                                                    }|*12
      fooÿbar                                              |
    ]])
    assert_alive()
  end)
end)
