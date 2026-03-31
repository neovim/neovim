local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local eq, eval = t.eq, n.eval

describe('glob2regpat()', function()
  before_each(clear)

  it('returns ^$ for empty input', function()
    eq('^$', eval("glob2regpat('')"))
  end)
  it('handles valid input', function()
    eq('^foo\\.', eval("glob2regpat('foo.*')"))
    eq('\\.vim$', eval("glob2regpat('*.vim')"))
  end)
end)
