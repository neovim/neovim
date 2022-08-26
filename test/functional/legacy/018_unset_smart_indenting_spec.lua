-- Tests for not doing smart indenting when it isn't set.

local helpers = require('test.functional.helpers')(after_each)

local feed = helpers.feed
local clear = helpers.clear
local insert = helpers.insert
local expect = helpers.expect
local feed_command = helpers.feed_command

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
