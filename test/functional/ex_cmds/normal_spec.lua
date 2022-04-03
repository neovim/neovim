local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local feed = helpers.feed
local expect = helpers.expect

before_each(clear)

describe(':normal', function()
  it('can get out of Insert mode if called from Ex mode #17924', function()
    feed('gQnormal! Ifoo<CR>')
    expect('foo')
  end)
end)
