local helpers = require('test.functional.helpers')(after_each)
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local expect = helpers.expect

clear()

describe('insert-mode', function()
  it('CTRL-@ inserts last-inserted text, leaves insert-mode', function()
    insert('hello')
    feed('i<C-@>x')
    expect('hellhello')
  end)
  -- C-Space is the same as C-@
  it('CTRL-SPC inserts last-inserted text, leaves insert-mode', function()
    feed('i<C-Space>x')
    expect('hellhellhello')
  end)
  it('CTRL-A inserts last inserted text', function()
    feed('i<C-A>x')
    expect('hellhellhellhelloxo')
  end)
end)
