local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local clear = helpers.clear
local insert = helpers.insert
local feed = helpers.feed
local expect = helpers.expect
local execute = helpers.execute
local exc_exec = helpers.exc_exec

describe(':undojoin command', function()
  before_each(function()
    clear()
    insert([[
    Line of text 1
    Line of text 2]])
    execute('goto 1')
  end)
  it('joins changes in a buffer', function()
    execute('undojoin | delete')
    expect([[
    Line of text 2]])
    feed('u')
    expect([[
    ]])
  end)
  it('does not corrupt undolist when connected with redo', function()
    feed('ixx<esc>')
    execute('undojoin | redo')
    expect([[
    xxLine of text 1
    Line of text 2]])
  end)
  it('does not raise an error when called twice', function()
    local ret = exc_exec('undojoin | undojoin')
    eq(0, ret)
  end)
end)
