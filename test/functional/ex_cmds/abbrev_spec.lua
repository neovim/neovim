local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local clear = n.clear
local command = n.command
local feed = n.feed
local eq = t.eq

describe('position-aware cabbrev (:prefix)', function()
  before_each(function()
    clear()
    command('let g:hit = 0')
  end)

  it('expands at command position, via CR and via space trigger', function()
    command('cabbrev :w :let g:hit = 1')
    feed(':w<CR>')
    eq(1, n.eval('g:hit'))
    command('let g:hit = 0')
    feed(':w <CR>')
    eq(1, n.eval('g:hit'))
  end)

  it('single character mapping expands at command position, not in argument position', function()
    command('cabbrev :e :let g:hit = 1')
    feed(':e<CR>')
    eq(1, n.eval('g:hit'))
    command('let g:hit = 0')
    feed(':echo e<CR>')
    eq(0, n.eval('g:hit'))
  end)

  it('abbreviated form of LHS still expands', function()
    command('cabbrev :delete :let g:hit = 1')
    feed(':d<CR>')
    eq(1, n.eval('g:hit'))
  end)

  it('does not expand when word is a command argument', function()
    command('cabbrev :w :let g:hit = 1')
    feed(':echo w<CR>')
    eq(0, n.eval('g:hit'))
  end)

  it('does not expand when used as a variable name', function()
    command('cabbrev :w :let g:hit = 1')
    feed(':let g:w = 1<CR>')
    eq(0, n.eval('g:hit'))
  end)

  it('does not expand mid-argument', function()
    command('cabbrev :e :let g:hit = 1')
    feed(':let g:e = 1<CR>')
    eq(0, n.eval('g:hit'))
  end)

  it('unknown command LHS expands at command position, not in argument position', function()
    command('cabbrev :duck :let g:hit = 1')
    feed(':duck<CR>')
    eq(1, n.eval('g:hit'))
    command('let g:hit = 0')
    feed(':echo duck<CR>')
    eq(0, n.eval('g:hit'))
  end)

  it('expands as command after pipe, not in argument position after pipe', function()
    command('cabbrev :wr :let g:hit = 1')
    feed(':let g:x = 0 | wr<CR>')
    eq(1, n.eval('g:hit'))
    command('let g:hit = 0')
    feed(':let g:x = 0 | echo wr<CR>')
    eq(0, n.eval('g:hit'))
  end)

  it('expands as command after pipe with range, not in argument position', function()
    n.api.nvim_buf_set_lines(0, 0, -1, true, { 'a', 'b', 'c' })
    command('cabbrev :d :delete')
    feed(':let g:x = 0 | 1,2d<CR>')
    eq({ 'c' }, n.api.nvim_buf_get_lines(0, 0, -1, true))

    n.api.nvim_buf_set_lines(0, 0, -1, true, { 'a', 'b', 'c' })
    command('cabbrev :w :let g:hit = 1')
    feed(':let g:x = 0 | echo 1,2w<CR>')
    eq(0, n.eval('g:hit'))
  end)

  it('expands after a plain line range (no pipe)', function()
    n.api.nvim_buf_set_lines(0, 0, -1, true, { 'a', 'b', 'c' })
    command('cabbrev :d :delete')
    feed(':2,3d<CR>')
    eq({ 'a' }, n.api.nvim_buf_get_lines(0, 0, -1, true))
  end)

  it('abclear removes position-aware abbreviation', function()
    command('cabbrev :w :let g:hit = 1')
    command('abclear')
    feed(':w<CR>')
    eq(0, n.eval('g:hit'))
  end)

  it('cabclear removes position-aware abbreviation', function()
    command('cabbrev :w :let g:hit = 1')
    command('cabclear')
    feed(':w<CR>')
    eq(0, n.eval('g:hit'))
  end)

  it('abclear removes regular cabbrev too', function()
    command('cabbrev w :let g:hit = 1')
    command('abclear')
    feed(':w<CR>')
    eq(0, n.eval('g:hit'))
  end)

  it('cabclear does not affect insert abbreviations', function()
    command('iabbrev w :let g:hit = 1')
    command('cabbrev :w :let g:hit = 2')
    command('cabclear')
    feed(':w<CR>')
    eq(0, n.eval('g:hit'))
  end)

  it('regular cabbrev expands at command position, not in argument position', function()
    command('cabbrev w :let g:hit = 1')
    feed(':w<CR>')
    eq(1, n.eval('g:hit'))
    command('let g:hit = 0')
    feed(':echo w<CR>')
    eq(0, n.eval('g:hit'))
  end)

  it('regular abbrev still works after position-aware is cleared', function()
    command('cabbrev :w :let g:hit = 1')
    command('cabbrev w :let g:hit = 2')
    command('cabclear')
    command('let g:hit = 0')
    command('cabbrev w :let g:hit = 2')
    feed(':w<CR>')
    eq(2, n.eval('g:hit'))
  end)

  it('iabbrev is unaffected by cabclear', function()
    command('iabbrev w :let g:hit = 1')
    command('cabclear')
    feed('iw <Esc>')
    eq(0, n.eval('g:hit'))
  end)

  it('expands with various cmdline modifiers, alone and combined with a range', function()
    command('cabbrev :gr :let g:hit = 1')

    -- single modifier, no range
    feed(':silent gr<CR>')
    eq(1, n.eval('g:hit'))
    command('let g:hit = 0')

    -- stacked modifiers, no range
    feed(':silent topleft verbose gr<CR>')
    eq(1, n.eval('g:hit'))
    command('let g:hit = 0')

    -- Range-bearing cases below use :delete as the cabbrev target instead of
    -- :let, since :let never accepts a range (E481) regardless of whether
    -- modifier/range parsing itself is correct. Buffer state replaces g:hit
    -- as the success signal here.
    command('cabbrev :gr :delete')

    -- range with no modifiers
    n.api.nvim_buf_set_lines(0, 0, -1, true, { 'a', 'b', 'c' })
    feed(':1,2gr<CR>')
    eq({ 'c' }, n.api.nvim_buf_get_lines(0, 0, -1, true))

    -- stacked modifiers with a range in between the modifiers and the command
    n.api.nvim_buf_set_lines(0, 0, -1, true, { 'a', 'b', 'c' })
    feed(':silent topleft verbose 1,2gr<CR>')
    eq({ 'c' }, n.api.nvim_buf_get_lines(0, 0, -1, true))

    -- modifiers + range after a pipe
    n.api.nvim_buf_set_lines(0, 0, -1, true, { 'a', 'b', 'c' })
    feed(':let g:x = 0 | silent verbose 1,2gr<CR>')
    eq({ 'c' }, n.api.nvim_buf_get_lines(0, 0, -1, true))
  end)
end)
