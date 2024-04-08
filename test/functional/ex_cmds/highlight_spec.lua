local Screen = require('test.functional.ui.screen')
local t = require('test.functional.testutil')(after_each)
local eq, command = t.eq, t.command
local clear = t.clear
local eval, exc_exec = t.eval, t.exc_exec
local exec = t.exec
local fn = t.fn
local api = t.api

describe(':highlight', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new()
    screen:attach()
  end)

  it('invalid color name', function()
    eq(
      'Vim(highlight):E421: Color name or number not recognized: ctermfg=#181818',
      exc_exec('highlight normal ctermfg=#181818')
    )
    eq(
      'Vim(highlight):E421: Color name or number not recognized: ctermbg=#181818',
      exc_exec('highlight normal ctermbg=#181818')
    )
  end)

  it('invalid group name', function()
    eq('Vim(highlight):E411: Highlight group not found: foo', exc_exec('highlight foo'))
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

  it('only the last underline style takes effect #22371', function()
    command('highlight NonText gui=underline,undercurl')
    eq('', eval('synIDattr(hlID("NonText"), "underline", "gui")'))
    eq('1', eval('synIDattr(hlID("NonText"), "undercurl", "gui")'))
    command('highlight NonText gui=undercurl,underline')
    eq('', eval('synIDattr(hlID("NonText"), "undercurl", "gui")'))
    eq('1', eval('synIDattr(hlID("NonText"), "underline", "gui")'))
  end)

  it('clear', function()
    api.nvim_set_var('colors_name', 'foo')
    eq(1, fn.exists('g:colors_name'))
    command('hi clear')
    eq(0, fn.exists('g:colors_name'))
    api.nvim_set_var('colors_name', 'foo')
    eq(1, fn.exists('g:colors_name'))
    exec([[
      func HiClear()
        hi clear
      endfunc
    ]])
    fn.HiClear()
    eq(0, fn.exists('g:colors_name'))
  end)
end)
