-- Normal mode tests.

local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local feed = n.feed
local fn = n.fn
local command = n.command
local eq = t.eq
local api = n.api

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
    fn.jobstart({ n.nvim_prog, '--clean', '--cmd', 'startinsert' }, {
      term = true,
      env = { VIMRUNTIME = os.getenv('VIMRUNTIME') },
    })
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

  it('replacing with ZWJ emoji sequences', function()
    local screen = Screen.new(30, 8)
    api.nvim_buf_set_lines(0, 0, -1, true, { 'abcdefg' })
    feed('05r🧑‍🌾') -- ZWJ
    screen:expect([[
      🧑‍🌾🧑‍🌾🧑‍🌾🧑‍🌾^🧑‍🌾fg                  |
      {1:~                             }|*6
                                    |
    ]])

    feed('2r🏳️‍⚧️') -- ZWJ and variant selectors
    screen:expect([[
      🧑‍🌾🧑‍🌾🧑‍🌾🧑‍🌾🏳️‍⚧️^🏳️‍⚧️g                 |
      {1:~                             }|*6
                                    |
    ]])
  end)
end)
