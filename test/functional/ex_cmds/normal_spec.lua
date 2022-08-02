local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local command = helpers.command
local feed = helpers.feed
local expect = helpers.expect
local eq = helpers.eq
local eval = helpers.eval

before_each(clear)

describe(':normal', function()
  it('can get out of Insert mode if called from Ex mode #17924', function()
    feed('gQnormal! Ifoo<CR>')
    expect('foo')
  end)

  it('normal! does not execute command in Ex mode when running out of characters', function()
    command('let g:var = 0')
    command('normal! gQlet g:var = 1')
    eq(0, eval('g:var'))
  end)

  it('normal! gQinsert does not hang #17980', function()
    command('normal! gQinsert')
    expect('')
  end)
end)
