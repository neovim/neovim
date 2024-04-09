-- " Test for expression comparators.

local t = require('test.functional.testutil')()
local clear, eq = t.clear, t.eq
local eval, command = t.eval, t.command

describe('comparators', function()
  before_each(clear)

  it('is working', function()
    command('set isident+=#')
    eq(1, eval('1 is#1'))
  end)
end)
