local t = require('test.functional.testutil')()
local clear, eq, command, fn = t.clear, t.eq, t.command, t.fn

describe(':z^', function()
  before_each(clear)

  it('correctly sets the cursor after :z^', function()
    command('z^')
    eq(1, fn.line('.'))
  end)
end)
