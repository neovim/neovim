-- " Test for expression comparators.

local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local clear, eq = n.clear, t.eq
local eval, command = n.eval, n.command

describe('comparators', function()
  before_each(clear)

  it('is working', function()
    command('set isident+=#')
    eq(1, eval('1 is#1'))
  end)
end)
