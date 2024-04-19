-- Normal mode tests.

local t = require('test.functional.testutil')()
local Screen = require('test.functional.ui.screen')
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

  it('&showcmd does not crash with :startinsert #28419', function()
    local screen = Screen.new(60, 17)
    screen:attach()
    fn.termopen(
      { t.nvim_prog, '--clean', '--cmd', 'startinsert' },
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
