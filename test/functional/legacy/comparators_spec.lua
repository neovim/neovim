-- " Test for expression comparators.

local helpers = require('test.functional.helpers')
local clear, eq = helpers.clear, helpers.eq
local eval, execute = helpers.eval, helpers.execute

describe('comparators', function()
  before_each(clear)

  it('is working', function()
    execute('set isident+=#')
    eq(1, eval('1 is#1'))
  end)
end)
