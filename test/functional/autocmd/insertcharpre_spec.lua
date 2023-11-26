local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local feed = helpers.feed
local command = helpers.command
local expect = helpers.expect

describe('autocmd InsertCharPre', function()
  before_each(clear)

  it('Ctrl-] shold not activate InsertCharPre', function()
    command('autocmd InsertCharPre * let v:char="a"')
    feed('ifoo<C-]>')
    expect('aaa')
  end)
end)
