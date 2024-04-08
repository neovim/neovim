local t = require('test.functional.testutil')(after_each)

local clear = t.clear
local command = t.command
local eq = t.eq
local fn = t.fn
local api = t.api
local mkdir = t.mkdir
local rmdir = t.rmdir
local write_file = t.write_file

describe(':help', function()
  before_each(clear)

  it('window closed makes cursor return to a valid win/buf #9773', function()
    t.add_builddir_to_rtp()
    command('help help')
    eq(1001, fn.win_getid())
    command('quit')
    eq(1000, fn.win_getid())

    command('autocmd WinNew * wincmd p')

    command('help help')
    -- Window 1002 is opened, but the autocmd switches back to 1000 and
    -- creates the help buffer there instead.
    eq(1000, fn.win_getid())
    command('quit')
    -- Before #9773, Nvim would crash on quitting the help window.
    eq(1002, fn.win_getid())
  end)

  it('multibyte help tags work #23975', function()
    mkdir('Xhelptags')
    finally(function()
      rmdir('Xhelptags')
    end)
    mkdir('Xhelptags/doc')
    write_file('Xhelptags/doc/Xhelptags.txt', '*…*')
    command('helptags Xhelptags/doc')
    command('set rtp+=Xhelptags')
    command('help …')
    eq('*…*', api.nvim_get_current_line())
  end)
end)
