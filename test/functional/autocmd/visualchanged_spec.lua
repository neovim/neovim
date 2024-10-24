local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq = t.eq
local clear = n.clear
local source = n.source
local feed = n.feed
local insert = n.insert
local eval = n.eval
local api = n.api

describe('VisualChanged', function()
  before_each(function()
    clear()
    insert [[
      Hello
      Hello
      Hello]]

    api.nvim_win_set_cursor(0, { 1, 0 })

    source [[
      let g:visual_count = 0
      au VisualChanged * let g:visual_count += 1
    ]]
  end)

  local function count()
    return eval('g:visual_count')
  end

  it('fires when visual mode changes or starts', function()
    feed 'v'
    eq(1, count())

    feed 'iw'
    eq(2, count())

    feed 'V'
    eq(3, count())

    feed '<c-v>'
    eq(4, count())

    feed 'v'
    eq(5, count())

    feed '<esc>v'
    eq(6, count())

    feed '<esc>V'
    eq(7, count())

    feed '<esc><c-v>'
    eq(8, count())
  end)

  it('fires when visual area changes or cursor moves', function()
    feed 'v'
    eq(1, count())

    feed 'iw'
    eq(2, count())

    feed 'Vj0'
    eq(5, count())

    feed '<esc>Vjl'
    eq(8, count())

    feed '<esc>gg<c-v>ejh'
    eq(12, count())
  end)

  it('works with gv', function()
    feed 'vjl'
    eq(3, count())

    feed '<esc>Ggv'
    eq(4, count())
  end)
end)
