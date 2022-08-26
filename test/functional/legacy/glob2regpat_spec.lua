-- Tests for signs

local helpers = require('test.functional.helpers')(after_each)
local clear, exc_exec = helpers.clear, helpers.exc_exec
local eq, eval = helpers.eq, helpers.eval

describe('glob2regpat()', function()
  before_each(clear)

  it('handles invalid input', function()
    eq('Vim(call):E806: using Float as a String',
       exc_exec('call glob2regpat(1.33)'))
  end)
  it('returns ^$ for empty input', function()
    eq('^$', eval("glob2regpat('')"))
  end)
  it('handles valid input', function()
    eq('^foo\\.', eval("glob2regpat('foo.*')"))
    eq('\\.vim$', eval("glob2regpat('*.vim')"))
  end)
end)
