local n = require('test.functional.testnvim')()

local clear = n.clear
local api = n.api
local assert_alive = n.assert_alive

local OSC_PREFIX = string.char(0x1b, 0x5d)
local BEL = string.char(0x07)
local NUL = string.char(0x00)

describe(':terminal', function()
  before_each(clear)

  it('handles invalid OSC terminators #30084', function()
    local chan = api.nvim_open_term(0, {})
    api.nvim_chan_send(chan, '\027]8;;https://example.com\027\\Example\027]8;;\027\n')
    assert_alive()
  end)

  it('handles OSC-2 title setting', function()
    -- OSC-2 should set title.
    local chan = api.nvim_open_term(0, {})
    local input = OSC_PREFIX .. '2;This title set with OSC 2' .. BEL
    api.nvim_chan_send(chan, input)
    --- @type string
    local term_title = api.nvim_buf_get_var(0, 'term_title')
    assert.Equal(term_title, 'This title set with OSC 2')
    assert_alive()
  end)

  it('handles OSC-0 title and icon setting', function()
    -- OSC-0 should set title and icon name to the same string. We currently ignore the icon name,
    -- but the title should still be reflected.
    local chan = api.nvim_open_term(0, {})
    local input = OSC_PREFIX .. '0;This title set with OSC 0' .. BEL
    api.nvim_chan_send(chan, input)
    --- @type string
    local term_title = api.nvim_buf_get_var(0, 'term_title')
    assert.Equal(term_title, 'This title set with OSC 0')
    assert_alive()
  end)

  it('handles control character following OSC prefix #34028', function()
    local chan = api.nvim_open_term(0, {})
    -- In order to test for the crash found in #34028 we need a ctrl char following the OSC_PREFIX
    -- which causes `string_fragment()` to be called while in OSC_COMMAND mode, this caused
    -- initial_string to be flipped back to false. At the end we need two more non-BEL control
    -- characters, one to write into the 1 byte buffer, then another to trigger the callback one
    -- more time so that realloc notices that it's internal data has been overwritten.
    local input = OSC_PREFIX .. NUL .. '0;aaaaaaaaaaaaaaaaaaaaaaaaaaa' .. NUL .. NUL
    api.nvim_chan_send(chan, input)
    assert_alive()

    -- On some platforms such as MacOS we need a longer string to reproduce the crash from #34028.
    input = OSC_PREFIX .. NUL .. '0;'
    for _ = 1, 256 do
      input = input .. 'a'
    end
    input = input .. NUL .. NUL
    api.nvim_chan_send(chan, input)
    assert_alive()
  end)
end)
