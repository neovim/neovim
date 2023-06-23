local helpers = require('test.functional.helpers')(after_each)
local clear, nvim, eq = helpers.clear, helpers.nvim, helpers.eq
local command = helpers.command
local eval = helpers.eval

describe('autocmd TabMoved * ', function()
  before_each(clear)

  it('matches when moving any tab via :tabmove', function()
    command('au! TabMoved * echom "tabmoved:".tabpagenr()')
    repeat
      command('tabnew')
    until nvim('eval', 'tabpagenr()') == 3 -- current tab is now 3
    eq("tabmoved:1", nvim('exec', 'tabmove 0', true))
    command('tabnext 2') -- current tab is now 2
    eq("tabmoved:3", nvim('exec', 'tabmove $', true))
    eq("tabmoved:2", nvim('exec', 'tabmove -1', true))
  end)

  it('does not trigger when a tab is moved to the same page number', function()
    command('let g:test = 0')
    command('au! TabMoved * let g:test += 1')
    repeat
      command('tabnew')
    until nvim('eval', 'tabpagenr()') == 3 -- current tab is now 3
    command('tabmove $')
    eq(0, eval('g:test'))
  end)

  it('is not triggered when tabs are created or closed', function()
    command('let g:test = 0')
    command('au! TabMoved * let g:test += 1')
    command('file Xtestfile1')
    command('0tabedit Xtestfile2')
    command('tabclose')
    eq(0, eval('g:test'))
  end)
end)
