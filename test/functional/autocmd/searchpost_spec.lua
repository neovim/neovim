local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local api = n.api
local clear = n.clear
local command = n.command
local eq = t.eq
local eval = n.eval
local feed = n.feed

describe('autocmd SearchPost', function()
  -- set up tests
  before_each(function()
    clear()
    command('set ignorecase')

    -- if incsearch is on, some searching functions will be called on each keypress. These "peek"
    -- searches should not trigger the SearchPost event
    command('set incsearch')

    -- keep track of SearchPost events
    command('let g:test = 0')
    command('autocmd! SearchPost * let g:test += 1')

    -- put some initial content into the buffer
    api.nvim_buf_set_lines(0, 0, 1, false, {
      'All avian aligators amidst aerial astronauts are awesome',
      'Bad bells bing-bong before Bill Benfry Benson becomes bald',
    })
  end)

  local count = function()
    return eval('g:test')
  end

  it('gets triggered when a search is performed', function()
    feed('/al<Return>')
    eq(1, count())
  end)

  it('gets triggered on n/N/*/# in normal mode', function()
    feed('/al<Return>')

    -- check trigger keys
    feed('n')
    eq(2, count())
    feed('N')
    eq(3, count())
    feed('*')
    eq(4, count())
    feed('#')
    eq(5, count())
  end)

  it('gets triggered on n/N/*/# in visual mode', function()
    feed('/al<Return>')

    -- enter visual mode
    feed('v')

    -- check trigger keys
    feed('n')
    eq(2, count())
    feed('N')
    eq(3, count())
    feed('*')
    eq(4, count())
    feed('#')
    eq(5, count())
  end)

  it('gets triggered on the :substitute command', function()
    feed(':%s/a/b<Return>')
    eq(1, count())
  end)
end)
