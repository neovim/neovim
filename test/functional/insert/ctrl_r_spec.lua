local helpers = require('test.functional.helpers')(after_each)
local clear, feed = helpers.clear, helpers.feed
local expect, command = helpers.expect, helpers.command

describe('insert-mode Ctrl-R', function()
  before_each(clear)

  it('works', function()
    command("let @@ = 'test'")
    feed('i<C-r>"')
    expect('test')
  end)

  it('works with multi-byte text', function()
    command("let @@ = 'påskägg'")
    feed('i<C-r>"')
    expect('påskägg')
  end)
end)
