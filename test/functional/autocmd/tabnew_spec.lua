local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local command = n.command
local eq = t.eq
local eval = n.eval

describe('autocmd TabNew', function()
  before_each(clear)

  it('matches when opening any new tab', function()
    command('autocmd! TabNew * let g:test = "tabnew:".tabpagenr().":".bufnr("")')
    command('tabnew')
    eq('tabnew:2:1', eval('g:test'))
    command('tabnew test.x')
    eq('tabnew:3:2', eval('g:test'))
  end)

  it('matches when opening a new tab for FILE', function()
    command('let g:test = "foo"')
    command('autocmd! TabNew Xtest-tabnew let g:test = "bar"')
    command('tabnew Xtest-tabnewX')
    eq('foo', eval('g:test'))
    command('tabnew Xtest-tabnew')
    eq('bar', eval('g:test'))
  end)
end)
