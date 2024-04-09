local t = require('test.functional.testutil')()

local assert_alive = t.assert_alive
local clear = t.clear
local feed = t.feed

describe("'tabstop' option", function()
  before_each(function()
    clear()
  end)

  -- NOTE: Setting 'tabstop' to a big number reproduces crash #2838.
  -- Disallowing big 'tabstop' would not fix #2838, only hide it.
  it('tabstop=<big-number> does not crash #2838', function()
    -- Insert a <Tab> character for 'tabstop' to work with.
    feed('i<Tab><Esc>')
    -- Set 'tabstop' to a very high value.
    -- Use feed(), not command(), to provoke crash.
    feed(':set tabstop=3000000000<CR>')
    assert_alive()
  end)
end)
