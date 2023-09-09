local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq, eval = helpers.eq, helpers.eval

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
