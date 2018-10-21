local helpers = require('test.functional.helpers')(after_each)

local funcs = helpers.funcs
local neq = helpers.neq
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

  it(':close triggers WinClosed event', function()
    command('let g:triggered = 0')
    command('new')
    command('autocmd WinClosed <buffer> :let g:triggered+=1')
    eq(0, eval('g:triggered'))
    command('close')
    eq(1, eval('g:triggered'))
  end)

  it(':bdelete triggers WinClosed event', function()
    command('let g:triggered = 0')
    command('autocmd WinClosed <buffer> :let g:triggered+=1')
    local first_buffer = eval("bufnr('%')")
    command('new')
    command('bdelete ' .. first_buffer )
    eq(1, eval('g:triggered'))
  end)

  it(':close triggers WinClosed event in another tab', function()
    command('let g:triggered = 0')
    local current_buffer = eval("bufnr('%')")
    command('autocmd WinClosed <buffer> :let g:triggered+=1')
    command('tabnew')
    command('bdelete ' .. current_buffer)
    eq(1, eval('g:triggered'))
  end)

  it('WinClosed events are not recursive in different window', function()
    command('let g:triggered = 0')
    local first_buffer = eval("bufnr('%')")
    command('autocmd WinClosed <buffer> :let g:triggered+=1')
    command('new')
    local second_buffer = eval("bufnr('%')")
    command('autocmd WinClosed <buffer> :bdelete ' .. first_buffer)
    command('new')
    neq(-1, funcs.bufwinnr(first_buffer))
    command('bdelete ' .. second_buffer )
    eq(-1, funcs.bufwinnr(first_buffer))
    eq(0, eval('g:triggered'))
  end)

  it('WinClosed events are not recursive in the same window', function()
    command('let g:triggered = 0')
    command('new')
    local second_buffer = eval("bufnr('%')")
    command('autocmd WinClosed <buffer> :let g:triggered+=1 | bdelete ' .. second_buffer)
    neq(-1, funcs.bufwinnr(second_buffer))
    eq(0, eval('g:triggered'))
    command('bdelete ' .. second_buffer )
    eq(-1, funcs.bufwinnr(second_buffer))
    eq(1, eval('g:triggered'))
  end)

  it('WinClosed events are not recursive in different tab', function()
    command('let g:triggered = 0')
    local first_buffer = eval("bufnr('%')")
    command('autocmd WinClosed <buffer> :let g:triggered+=1')
    command('new')
    local second_buffer = eval("bufnr('%')")
    command('autocmd WinClosed <buffer> :bdelete ' .. first_buffer)
    command('tabnew')
    command('tabnext')
    neq(-1, funcs.bufwinnr(first_buffer))
    command('tabnext')
    command('bdelete ' .. second_buffer )
    eq(-1, funcs.bufwinnr(first_buffer))
    eq(0, eval('g:triggered'))
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
