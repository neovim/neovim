-- Tests for not doing smart indenting when it isn't set.

local n = require('test.functional.testnvim')()

local feed = n.feed
local clear = n.clear
local insert = n.insert
local expect = n.expect
local feed_command = n.feed_command

describe('unset smart indenting', function()
  before_each(clear)

  it('is working', function()
    insert([[
      start text
              some test text
              test text
      test text
              test text]])

    feed_command('set nocin nosi ai')
    feed_command('/some')
    feed('2cc#test<Esc>')

    expect([[
      start text
              #test
      test text
              test text]])
  end)
end)
