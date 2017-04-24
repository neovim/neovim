local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local eval = helpers.eval
local clear = helpers.clear
local meths = helpers.meths
local expect = helpers.expect
local command = helpers.command
local exc_exec = helpers.exc_exec
local curbufmeths = helpers.curbufmeths

describe('autocmds:', function()
  before_each(clear)

  it(':tabnew triggers events in the correct order', function()
    local expected = {
      'WinLeave',
      'TabLeave',
      'WinEnter',
      'TabNew',
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

  it('v:vim_did_enter is 1 after VimEnter', function()
    eq(1, eval('v:vim_did_enter'))
  end)

  describe('BufLeave autocommand', function()
    it('can wipe out the buffer created by :edit which triggered autocmd',
    function()
      meths.set_option('hidden', true)
      curbufmeths.set_lines(0, 1, false, {
        'start of test file xx',
        'end of test file xx'})

      command('autocmd BufLeave * bwipeout yy')
      eq('Vim(edit):E143: Autocommands unexpectedly deleted new buffer yy',
         exc_exec('edit yy'))

      expect([[
        start of test file xx
        end of test file xx]])
    end)
  end)
end)
