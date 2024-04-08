-- Normal mode tests.

local t = require('test.functional.testutil')(after_each)
local clear = t.clear
local feed = t.feed
local fn = t.fn
local command = t.command
local eq = t.eq

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
