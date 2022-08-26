local helpers = require('test.functional.helpers')(after_each)
local clear, eq, command, funcs =
  helpers.clear, helpers.eq, helpers.command, helpers.funcs

describe(':z^', function()
  before_each(clear)

  it('correctly sets the cursor after :z^', function()
    command('z^')
    eq(1, funcs.line('.'))
  end)
end)
