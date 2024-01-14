local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local command = helpers.command
local funcs = helpers.funcs
local feed = helpers.feed
local expect = helpers.expect
local eq = helpers.eq
local eval = helpers.eval

before_each(clear)

describe(':normal!', function()
  it('can get out of Insert mode if called from Ex mode #17924', function()
    feed('gQnormal! Ifoo<CR>')
    expect('foo')
  end)

  it('does not execute command in Ex mode when running out of characters', function()
    command('let g:var = 0')
    command('normal! gQlet g:var = 1')
    eq(0, eval('g:var'))
  end)

  it('gQinsert does not hang #17980', function()
    command('normal! gQinsert')
    expect('')
  end)

  it('can stop Visual mode without closing cmdwin vim-patch:9.0.0234', function()
    feed('q:')
    feed('v')
    eq('v', funcs.mode(1))
    eq(':', funcs.getcmdwintype())
    command('normal! \027')
    eq('n', funcs.mode(1))
    eq(':', funcs.getcmdwintype())
  end)
end)
