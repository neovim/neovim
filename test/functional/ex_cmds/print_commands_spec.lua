local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear, eq, command, fn = n.clear, t.eq, n.command, n.fn

describe(':z^', function()
  before_each(clear)

  it('correctly sets the cursor after :z^', function()
    command('z^')
    eq(1, fn.line('.'))
  end)
end)
