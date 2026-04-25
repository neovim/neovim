local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local api = n.api
local eq = t.eq
local poke_eventloop = n.poke_eventloop
local assert_alive = n.assert_alive

local CSI = '\027['

describe(':terminal synchronized output (mode 2026)', function()
  local screen, chan, buf

  before_each(function()
    clear()
    screen = Screen.new(50, 7)
    buf = api.nvim_create_buf(true, true)
    chan = api.nvim_open_term(buf, {})
    api.nvim_win_set_buf(0, buf)
  end)

  it('renders content sent inside a synchronized update', function()
    api.nvim_chan_send(chan, CSI .. '?2026h')
    api.nvim_chan_send(chan, 'synced line 1\r\n')
    api.nvim_chan_send(chan, 'synced line 2\r\n')
    api.nvim_chan_send(chan, CSI .. '?2026l')
    screen:expect([[
      ^synced line 1                                     |
      synced line 2                                     |
                                                        |*4
                                                        |
    ]])
  end)

  it('renders all lines from a synchronized update', function()
    api.nvim_chan_send(chan, CSI .. '?2026h')
    for i = 1, 5 do
      api.nvim_chan_send(chan, 'line ' .. i .. '\r\n')
    end
    api.nvim_chan_send(chan, CSI .. '?2026l')
    screen:expect([[
      ^line 1                                            |
      line 2                                            |
      line 3                                            |
      line 4                                            |
      line 5                                            |
                                                        |
                                                        |
    ]])
    -- Buffer lines should also match.
    local lines = api.nvim_buf_get_lines(buf, 0, -1, true)
    eq('line 1', lines[1])
    eq('line 2', lines[2])
    eq('line 5', lines[5])
  end)

  it('handles multiple synchronized update cycles', function()
    -- First cycle.
    api.nvim_chan_send(chan, CSI .. '?2026h')
    api.nvim_chan_send(chan, 'cycle 1\r\n')
    api.nvim_chan_send(chan, CSI .. '?2026l')
    screen:expect([[
      ^cycle 1                                           |
                                                        |*5
                                                        |
    ]])

    -- Second cycle.
    api.nvim_chan_send(chan, CSI .. '?2026h')
    api.nvim_chan_send(chan, 'cycle 2\r\n')
    api.nvim_chan_send(chan, CSI .. '?2026l')
    screen:expect([[
      ^cycle 1                                           |
      cycle 2                                           |
                                                        |*4
                                                        |
    ]])
  end)

  it('works with content before and after sync', function()
    -- Unsynchronized content.
    api.nvim_chan_send(chan, 'before\r\n')
    poke_eventloop()
    screen:expect([[
      ^before                                            |
                                                        |*5
                                                        |
    ]])

    -- Synchronized content.
    api.nvim_chan_send(chan, CSI .. '?2026h')
    api.nvim_chan_send(chan, 'during\r\n')
    api.nvim_chan_send(chan, CSI .. '?2026l')
    screen:expect([[
      ^before                                            |
      during                                            |
                                                        |*4
                                                        |
    ]])

    -- More unsynchronized content.
    api.nvim_chan_send(chan, 'after\r\n')
    screen:expect([[
      ^before                                            |
      during                                            |
      after                                             |
                                                        |*3
                                                        |
    ]])
  end)

  it('does not crash when mode 2026 is set and queried', function()
    api.nvim_chan_send(chan, CSI .. '?2026h')
    assert_alive()
    api.nvim_chan_send(chan, CSI .. '?2026l')
    assert_alive()
  end)

  it('defers screen update during sync mode', function()
    -- Establish a known screen state first.
    api.nvim_chan_send(chan, 'visible\r\n')
    screen:expect([[
      ^visible                                           |
                                                        |*5
                                                        |
    ]])
    -- Begin sync and send more content — screen should not change.
    api.nvim_chan_send(chan, CSI .. '?2026h')
    api.nvim_chan_send(chan, 'deferred\r\n')
    screen:expect_unchanged()
    -- End sync — now the deferred content should appear.
    api.nvim_chan_send(chan, CSI .. '?2026l')
    screen:expect([[
      ^visible                                           |
      deferred                                          |
                                                        |*4
                                                        |
    ]])
  end)

  it('handles rapid sync on/off toggling', function()
    for i = 1, 5 do
      api.nvim_chan_send(chan, CSI .. '?2026h')
      api.nvim_chan_send(chan, 'rapid ' .. i .. '\r\n')
      api.nvim_chan_send(chan, CSI .. '?2026l')
    end
    screen:expect([[
      ^rapid 1                                           |
      rapid 2                                           |
      rapid 3                                           |
      rapid 4                                           |
      rapid 5                                           |
                                                        |
                                                        |
    ]])
  end)
end)
