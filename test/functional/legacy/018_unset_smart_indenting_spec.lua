-- Tests for not doing smart indenting when it isn't set.

local helpers = require('test.functional.helpers')(after_each)
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect

describe('unset smart indenting', function()
  setup(clear)

  it('is working', function()
    insert([[
      start text
              some test text
              test text
      test text
              test text]])

    execute('set nocin nosi ai')
    execute('/some')
    feed('2cc#test<Esc>')

    expect([[
      start text
              #test
      test text
              test text]])
  end)
end)
