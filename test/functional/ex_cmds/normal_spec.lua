local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local command = n.command
local fn = n.fn
local feed = n.feed
local expect = n.expect
local eq = t.eq
local eval = n.eval

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
    eq('v', fn.mode(1))
    eq(':', fn.getcmdwintype())
    command('normal! \027')
    eq('n', fn.mode(1))
    eq(':', fn.getcmdwintype())
  end)
end)
