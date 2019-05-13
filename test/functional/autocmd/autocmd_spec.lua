local helpers = require('test.functional.helpers')(after_each)

local dedent = helpers.dedent
local eq = helpers.eq
local eval = helpers.eval
local feed = helpers.feed
local clear = helpers.clear
local meths = helpers.meths
local funcs = helpers.funcs
local expect = helpers.expect
local command = helpers.command
local exc_exec = helpers.exc_exec
local curbufmeths = helpers.curbufmeths

describe('autocmd', function()
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

  it('++once', function()  -- :help autocmd-once
    --
    -- ":autocmd ... ++once" executes its handler once, then removes the handler.
    --
    local expected = {
      'Many1',
      'Once1',
      'Once2',
      'Many2',
      'Once3',
      'Many1',
      'Many2',
      'Many1',
      'Many2',
    }
    command('let g:foo = []')
    command('autocmd TabNew * :call add(g:foo, "Many1")')
    command('autocmd TabNew * ++once :call add(g:foo, "Once1")')
    command('autocmd TabNew * ++once :call add(g:foo, "Once2")')
    command('autocmd TabNew * :call add(g:foo, "Many2")')
    command('autocmd TabNew * ++once :call add(g:foo, "Once3")')
    eq(dedent([[

       --- Autocommands ---
       TabNew
           *         :call add(g:foo, "Many1")
                     :call add(g:foo, "Once1")
                     :call add(g:foo, "Once2")
                     :call add(g:foo, "Many2")
                     :call add(g:foo, "Once3")]]),
       funcs.execute('autocmd Tabnew'))
    command('tabnew')
    command('tabnew')
    command('tabnew')
    eq(expected, eval('g:foo'))
    eq(dedent([[

       --- Autocommands ---
       TabNew
           *         :call add(g:foo, "Many1")
                     :call add(g:foo, "Many2")]]),
       funcs.execute('autocmd Tabnew'))

    --
    -- ":autocmd ... ++once" handlers can be deleted.
    --
    expected = {}
    command('let g:foo = []')
    command('autocmd TabNew * ++once :call add(g:foo, "Once1")')
    command('autocmd! TabNew')
    command('tabnew')
    eq(expected, eval('g:foo'))

    --
    -- ":autocmd ... <buffer> ++once ++nested"
    --
    expected = {
      'OptionSet-Once',
      'CursorMoved-Once',
    }
    command('let g:foo = []')
    command('autocmd OptionSet binary ++nested ++once :call add(g:foo, "OptionSet-Once")')
    command('autocmd CursorMoved <buffer> ++once ++nested setlocal binary|:call add(g:foo, "CursorMoved-Once")')
    command("put ='foo bar baz'")
    feed('0llhlh')
    eq(expected, eval('g:foo'))

    --
    -- :autocmd should not show empty section after ++once handlers expire.
    --
    expected = {
      'Once1',
      'Once2',
    }
    command('let g:foo = []')
    command('autocmd! TabNew')  -- Clear all TabNew handlers.
    command('autocmd TabNew * ++once :call add(g:foo, "Once1")')
    command('autocmd TabNew * ++once :call add(g:foo, "Once2")')
    command('tabnew')
    eq(expected, eval('g:foo'))
    eq(dedent([[

       --- Autocommands ---]]),
       funcs.execute('autocmd Tabnew'))
  end)
end)
