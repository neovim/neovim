local n = require('test.functional.testnvim')()

local clear = n.clear
local insert = n.insert
local feed = n.feed
local expect = n.expect
local feed_command = n.feed_command
local command = n.command

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
    command('undojoin | undojoin')
  end)
end)
