local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local eval = n.eval
local command = n.command
local eq = t.eq
local fn = n.fn
local api = n.api
local mkdir = t.mkdir
local rmdir = n.rmdir
local write_file = t.write_file

describe(':help', function()
  before_each(clear)

  it('window closed makes cursor return to a valid win/buf #9773', function()
    n.add_builddir_to_rtp()
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

describe(':helptags', function()
  before_each(function()
    for _, sfx in ipairs({ '', '2' }) do
      fn.mkdir(('Xhelptags%s/doc'):format(sfx), 'p')
      for _, tag in ipairs({ 'Xa', 'Xb' }) do
        write_file(('Xhelptags%s/doc/%s%s.txt'):format(sfx, tag, sfx), ('*%s%s*'):format(tag, sfx))
      end
    end

    clear()
    command('set rtp+=Xhelptags,Xhelptags2')
  end)

  after_each(function()
    rmdir('Xhelptags')
    rmdir('Xhelptags2')
  end)

  it('requires an argument', function()
    local msg = t.pcall_err(command, 'helptags')
    eq(true, msg:find('E471') ~= nil)
  end)

  it('{dir} works', function()
    command('helptags Xhelptags/doc')

    eq(eval("['Xa	Xa.txt	/*Xa*','Xb	Xb.txt	/*Xb*']"), eval("readfile('Xhelptags/doc/tags')"))

    command('help Xa')
    eq('*Xa*', api.nvim_get_current_line())
  end)

  it('ALL works', function()
    command('helptags ALL')

    eq(eval("['Xa	Xa.txt	/*Xa*','Xb	Xb.txt	/*Xb*']"), eval("readfile('Xhelptags/doc/tags')"))
    eq(eval("['Xa2	Xa2.txt	/*Xa2*','Xb2	Xb2.txt	/*Xb2*']"), eval("readfile('Xhelptags2/doc/tags')"))

    command('help Xa2')
    eq('*Xa2*', api.nvim_get_current_line())
  end)

  it('++t works', function()
    command('helptags ++t Xhelptags/doc')
    eq('help-tags	tags	1', eval("readfile('Xhelptags/doc/tags')[-1]"))
  end)

  it('generates help-tag tag for VIMRUNTIME', function()
    command('let $VIMRUNTIME="Xhelptags"')
    command('helptags Xhelptags/doc')
    eq('help-tags	tags	1', eval("readfile('Xhelptags/doc/tags')[-1]"))
  end)

  it('errors on duplicate tags', function()
    -- duplicate tags in different files
    write_file('Xhelptags/doc/Xd.txt', '*Xa*', nil, true)
    local msg = t.pcall_err(command, 'helptags Xhelptags/doc')
    eq(true, msg:find('E154') ~= nil)

    -- tags file should still be generated
    eq(1, eval("filereadable('Xhelptags/doc/tags')"))

    os.remove('Xhelptags/doc/Xd.txt')

    -- duplicate tags in same file
    write_file('Xhelptags/doc/Xa.txt', '*Xa*', nil, true)

    msg = t.pcall_err(command, 'helptags Xhelptags/doc')
    eq(true, msg:find('E154') ~= nil)

    eq(1, eval("filereadable('Xhelptags/doc/tags')"))
  end)

  it('works with translated help files', function()
    write_file('Xhelptags/doc/Xa.nlx', '*Xa*', nil, true)
    command('helptags Xhelptags/doc')
    eq(1, eval("filereadable('Xhelptags/doc/tags-nl')"))
  end)
end)
