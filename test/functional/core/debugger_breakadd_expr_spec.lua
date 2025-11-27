local n = require('test.functional.testnvim')()

local clear = n.clear
local command = n.command
local assert_alive = n.assert_alive

describe(':breakadd expr with eval in user function', function()
  before_each(function()
    clear()
  end)

  it('does not segfault when setting expr breakpoint before calling function', function()
    command([[
      func Foo()
        eval 1
      endfunc

      breakadd expr abs(0)
      call Foo()
    ]])
    -- If we reach here, Neovim did not crash. Just assert something trivial.
    assert_alive()
  end)
end)
