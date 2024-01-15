local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local command = helpers.command
local api = helpers.api
local eq = helpers.eq
local eval = helpers.eval
local feed = helpers.feed

describe('autocmd SearchWrapped', function()
  before_each(function()
    clear()
    command('set ignorecase')
    command('let g:test = 0')
    command('autocmd! SearchWrapped * let g:test += 1')
    api.nvim_buf_set_lines(0, 0, 1, false, {
      'The quick brown fox',
      'jumps over the lazy dog',
    })
  end)

  it('gets triggered when search wraps the end', function()
    feed('/the<Return>')
    eq(0, eval('g:test'))

    feed('n')
    eq(1, eval('g:test'))

    feed('nn')
    eq(2, eval('g:test'))
  end)

  it('gets triggered when search wraps in reverse order', function()
    feed('/the<Return>')
    eq(0, eval('g:test'))

    feed('NN')
    eq(1, eval('g:test'))

    feed('NN')
    eq(2, eval('g:test'))
  end)

  it('does not get triggered on failed searches', function()
    feed('/blargh<Return>')
    eq(0, eval('g:test'))

    feed('NN')
    eq(0, eval('g:test'))

    feed('NN')
    eq(0, eval('g:test'))
  end)
end)
