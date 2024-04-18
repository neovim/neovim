local t = require('test.functional.testutil')()

local eq = t.eq
local clear = t.clear
local insert = t.insert
local feed = t.feed
local expect = t.expect
local feed_command = t.feed_command
local exc_exec = t.exc_exec

describe(':undojoin command', function()
  before_each(function()
    clear()
    insert([[
    Line of text 1
    Line of text 2]])
    feed_command('goto 1')
  end)
  it('joins changes in a buffer', function()
    feed_command('undojoin | delete')
    expect([[
    Line of text 2]])
    feed('u')
    expect([[
    ]])
  end)
  it('does not corrupt undolist when connected with redo', function()
    feed('ixx<esc>')
    feed_command('undojoin | redo')
    expect([[
    xxLine of text 1
    Line of text 2]])
  end)
  it('does not raise an error when called twice', function()
    local ret = exc_exec('undojoin | undojoin')
    eq(0, ret)
  end)
end)
