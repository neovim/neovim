local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local funcs = helpers.funcs

describe(':help', function()
  before_each(clear)

  it('window closed makes cursor return to a valid win/buf #9773', function()
    helpers.add_builddir_to_rtp()
    command('help help')
    eq(1001, funcs.win_getid())
    command('quit')
    eq(1000, funcs.win_getid())

    command('autocmd WinNew * wincmd p')

    command('help help')
    -- Window 1002 is opened, but the autocmd switches back to 1000 and
    -- creates the help buffer there instead.
    eq(1000, funcs.win_getid())
    command('quit')
    -- Before #9773, Nvim would crash on quitting the help window.
    eq(1002, funcs.win_getid())
  end)
end)
