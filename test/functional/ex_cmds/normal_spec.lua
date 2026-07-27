local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
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
    feed('1q:normal! Ifoo<CR>')
    feed('visual<CR>')
    expect('foo')
  end)

  it('does not execute command in Ex mode when running out of characters', function()
    command('let g:var = 0')
    command('normal! 1q:let g:var = 1')
    eq(0, eval('g:var'))
  end)

  it('"1q:insert" does not hang #17980', function()
    command('normal! 1q:insert')
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
