-- Normal mode tests.

local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local feed = n.feed
local fn = n.fn
local command = n.command
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

  it('&showcmd does not crash with :startinsert #28419', function()
    local screen = Screen.new(60, 17)
    screen:attach()
    fn.termopen(
      { n.nvim_prog, '--clean', '--cmd', 'startinsert' },
      { env = { VIMRUNTIME = os.getenv('VIMRUNTIME') } }
    )
    screen:expect({
      grid = [[
        ^                                                            |
        ~                                                           |*13
        [No Name]                                 0,1            All|
        -- INSERT --                                                |
                                                                    |
      ]],
      attr_ids = {},
    })
  end)
end)
