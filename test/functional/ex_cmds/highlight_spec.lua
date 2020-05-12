local Screen = require('test.functional.ui.screen')
local helpers = require("test.functional.helpers")(after_each)
local eq, command = helpers.eq, helpers.command
local clear = helpers.clear
local eval, exc_exec = helpers.eval, helpers.exc_exec

describe(':highlight', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new()
    screen:attach()
  end)

  it('invalid color name', function()
    eq('Vim(highlight):E421: Color name or number not recognized: ctermfg=#181818',
       exc_exec("highlight normal ctermfg=#181818"))
    eq('Vim(highlight):E421: Color name or number not recognized: ctermbg=#181818',
       exc_exec("highlight normal ctermbg=#181818"))
  end)

  it('invalid group name', function()
    eq('Vim(highlight):E411: highlight group not found: foo',
       exc_exec("highlight foo"))
  end)

  it('"Normal" foreground with red', function()
    eq('', eval('synIDattr(hlID("Normal"), "fg", "cterm")'))
    command('highlight normal ctermfg=red')
    eq('9', eval('synIDattr(hlID("Normal"), "fg", "cterm")'))
  end)

  it('"Normal" background with red', function()
    eq('', eval('synIDattr(hlID("Normal"), "bg", "cterm")'))
    command('highlight normal ctermbg=red')
    eq('9', eval('synIDattr(hlID("Normal"), "bg", "cterm")'))
  end)
end)
