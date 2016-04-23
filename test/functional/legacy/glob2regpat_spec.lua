-- Tests for signs

local helpers = require('test.functional.helpers')
local clear, execute = helpers.clear, helpers.execute
local eq, neq, eval = helpers.eq, helpers.neq, helpers.eval

describe('glob2regpat()', function()
  before_each(clear)

  it('handles invalid input', function()
    execute('call glob2regpat(1.33)')
    helpers.feed('<cr>')
    neq(nil, string.find(eval('v:errmsg'), '^E806:'))
  end)
  it('returns ^$ for empty input', function()
    eq('^$', eval("glob2regpat('')"))
  end)
  it('handles valid input', function()
    eq('^foo\\.', eval("glob2regpat('foo.*')"))
    eq('\\.vim$', eval("glob2regpat('*.vim')"))
  end)
end)
