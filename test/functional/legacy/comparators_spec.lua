-- " Test for expression comparators.

local helpers = require('test.functional.helpers')(after_each)
local clear, eq = helpers.clear, helpers.eq
local eval, command = helpers.eval, helpers.command

describe('comparators', function()
  before_each(clear)

  it('is working', function()
    command('set isident+=#')
    eq(1, eval('1 is#1'))
  end)
end)
