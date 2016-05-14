-- Test argument list commands

local helpers = require('test.functional.helpers')
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect
local eq, eval = helpers.eq, helpers.eval

describe('argument list commands', function()
  before_each(clear)

  it('is working', function()
    execute('args a b c')
    execute('last')
    eq(2, eval('argidx()'))
    execute('%argdelete')
    eq(0, eval('argidx()'))

    execute('args a b c')
    eq(0, eval('argidx()'))
    execute('next')
    eq(1, eval('argidx()'))
    execute('next')
    eq(2, eval('argidx()'))
    execute('1argdelete')
    eq(1, eval('argidx()'))
    execute('1argdelete')
    eq(0, eval('argidx()'))
    execute('1argdelete')
    eq(0, eval('argidx()'))
  end)
end)
