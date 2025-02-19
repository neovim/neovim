local n = require('test.functional.testnvim')()

local clear = n.clear
local api = n.api
local assert_alive = n.assert_alive

describe(':terminal', function()
  before_each(clear)

  it('handles invalid OSC terminators #30084', function()
    local chan = api.nvim_open_term(0, {})
    api.nvim_chan_send(chan, '\027]8;;https://example.com\027\\Example\027]8;;\027\n')
    assert_alive()
  end)
end)
