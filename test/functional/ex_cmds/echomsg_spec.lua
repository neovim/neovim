local _h = require('test.functional.helpers')
local Screen = require('test.functional.ui.screen')
local clear, feed, execute = _h.clear, _h.feed, _h.execute
local insert = _h.insert

-- The tests below don't test anything, but the build output demonstrates the
-- following quirk:
--    If vim_command_output('messages') is called more than once, e.g.:
--        print(helpers.nvim('command_output', 'messages')
--        print(helpers.nvim('command_output', 'messages')
--    The first call prints the full message, but after that it prints
--    truncated messages (like "foo...bar").
-- If the 'T' flag is removed from 'shortmess' option:
--    set shortmess-=T
-- then the non-truncated messages are always printed.

describe('vim_command_output() quirk', function()
  local screen
  it('vim_command_output()  always truncates :echom', function()
    --vim_command_output() truncates :echom
    print(_h.nvim('command_output', 'echom "foo 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560"'))
    print(_h.nvim('command_output', 'echom "foo 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560"'))
  end)

  it('vim_command_output() does not truncate first :messages call', function()
    --vim_command_output() truncates :echom
    execute('echom "foo 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560"')
    --vim_command_output() does not truncate first call to :messages
    print(_h.nvim('command_output', 'messages'))
    --vim_command_output() truncates :messages after the first call
    print(_h.nvim('command_output', 'messages'))
  end)

  it('vim_command_output() does not truncate first :messages call', function()
    execute('set shortmess-=T')
    --vim_command_output() truncates :echom
    execute('echom "foo 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560"')
    --vim_command_output() does not truncate first call to :messages
    print(_h.nvim('command_output', 'messages'))
    --vim_command_output() truncates :messages after the first call
    print(_h.nvim('command_output', 'messages'))
  end)

  before_each(function()
    clear()
    screen = Screen.new()
    screen:attach()
    --Some tests will exercise other 'cmdheight' values.
    _h.nvim('set_option', 'cmdheight', 1)
  end)

  after_each(function()
    screen:detach()
  end)
end)
