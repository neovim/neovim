local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local command = helpers.command
local eval = helpers.eval

describe('autocmds:', function()
  before_each(clear)

  it(':tabnew triggers events in the correct order', function()
    local expected = {
      'WinLeave',
      'TabLeave',
      'TabNew',
      'WinEnter',
      'TabEnter',
      'BufLeave',
      'BufEnter'
    }
    command('let g:foo = []')
    command('autocmd BufEnter * :call add(g:foo, "BufEnter")')
    command('autocmd BufLeave * :call add(g:foo, "BufLeave")')
    command('autocmd TabEnter * :call add(g:foo, "TabEnter")')
    command('autocmd TabLeave * :call add(g:foo, "TabLeave")')
    command('autocmd TabNew   * :call add(g:foo, "TabNew")')
    command('autocmd WinEnter * :call add(g:foo, "WinEnter")')
    command('autocmd WinLeave * :call add(g:foo, "WinLeave")')
    command('tabnew')
    assert.same(expected, eval('g:foo'))
  end)
end)
