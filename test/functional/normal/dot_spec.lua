local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local command = helpers.command
local expect = helpers.expect
local eq = helpers.eq
local eval = helpers.eval
local feed = helpers.feed

describe('.', function()
  before_each(clear)

  it('toggle repeatbusy flag during repeat sequence execution.', function()
    command('autocmd InsertEnter * let g:test = repeatbusy()')

    feed('afoo<esc>')
    expect('foo')
    eq(0, eval('g:test'))

    feed('.')
    expect('foofoo')
    eq(1, eval('g:test'))
  end)
end)
