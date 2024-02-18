-- Normal mode tests.

local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local feed = helpers.feed
local fn = helpers.fn
local command = helpers.command
local eq = helpers.eq

describe('Normal mode', function()
  before_each(clear)

  it('setting &winhighlight or &winblend does not change curswant #27470', function()
    fn.setline(1, { 'long long lone line', 'short line' })
    feed('ggfi')
    local pos = fn.getcurpos()
    feed('j')
    command('setlocal winblend=10 winhighlight=Visual:Search')
    feed('k')
    eq(pos, fn.getcurpos())
  end)
end)
