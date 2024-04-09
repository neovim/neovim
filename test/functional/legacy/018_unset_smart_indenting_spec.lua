-- Tests for not doing smart indenting when it isn't set.

local t = require('test.functional.testutil')()

local feed = t.feed
local clear = t.clear
local insert = t.insert
local expect = t.expect
local feed_command = t.feed_command

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
