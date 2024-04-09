local t = require('test.functional.testutil')()
local clear = t.clear
local eq, eval = t.eq, t.eval

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
