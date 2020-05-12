local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local eval = helpers.eval

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
