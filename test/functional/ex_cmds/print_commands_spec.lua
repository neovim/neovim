local helpers = require('test.functional.testunit')(after_each)
local clear, eq, command, fn = helpers.clear, helpers.eq, helpers.command, helpers.fn

describe(':z^', function()
  before_each(clear)

  it('correctly sets the cursor after :z^', function()
    command('z^')
    eq(1, fn.line('.'))
  end)
end)
