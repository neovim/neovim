local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
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

  it('fires when a block changes its end-of-line extent without moving', function()
    api.nvim_buf_set_lines(0, 0, -1, true, { 'abcde', 'ab' })
    feed 'gg0<c-v>jll'
    local initial_count = count()
    local cursor = api.nvim_win_get_cursor(0)
    local anchor = eval('getpos("v")')

    feed '$'
    eq(initial_count + 1, count())
    eq(cursor, api.nvim_win_get_cursor(0))
    eq(anchor, eval('getpos("v")'))

    feed '$'
    eq(initial_count + 1, count())

    feed '3|'
    eq(initial_count + 2, count())
    eq(cursor, api.nvim_win_get_cursor(0))
    eq(anchor, eval('getpos("v")'))
  end)

  it('works with gv', function()
    feed 'vjl'
    eq(3, count())

    feed '<esc>Ggv'
    eq(4, count())
  end)
end)
