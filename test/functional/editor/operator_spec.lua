-- Operator marks for a forced blockwise motion.

local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local clear = n.clear
local command = n.command
local feed = n.feed
local fn = n.fn
local api = n.api
local eq = t.eq

--- '[ / '] as {lnum, col, coladd}, the slice operatorfunc sees.
local function op_marks()
  local s = fn.getpos("'[")
  local e = fn.getpos("']")
  return { { s[2], s[3], s[4] }, { e[2], e[3], e[4] } }
end

describe('forced blockwise motion', function()
  before_each(function()
    clear()
    command([=[
      function! Op(type) abort
        let g:op_type = a:type
        let g:op_marks = [getpos("'[")[1:3], getpos("']")[1:3]]
      endfunction
      set operatorfunc=Op
    ]=])
  end)

  --- g@ then the same motion as a yank. Positioning keys are part of both.
  local function block(lines, op_keys, yank_keys)
    api.nvim_buf_set_lines(0, 0, -1, true, lines)
    feed(op_keys)
    local typ = fn.eval('g:op_type')
    local marks = fn.eval('g:op_marks')
    feed(yank_keys)
    return {
      type = typ,
      marks = marks,
      yank_marks = op_marks(),
      yank = fn.getreg('"', 1, 1),
    }
  end

  it("'] is the corner of the block for g@ and y #42309", function()
    eq({
      type = 'block',
      marks = { { 2, 1, 0 }, { 3, 1, 0 } },
      yank_marks = { { 2, 1, 0 }, { 3, 1, 0 } },
      yank = { 'a', 'c' },
    }, block({ 'seed', 'ab', 'cd' }, '2G0g@<C-v>j', '2G0y<C-v>j'))

    -- Inclusive charwise motion, same columns as a one-line block.
    eq({
      type = 'block',
      marks = { { 2, 1, 0 }, { 2, 2, 0 } },
      yank_marks = { { 2, 1, 0 }, { 2, 2, 0 } },
      yank = { 'ab' },
    }, block({ 'seed', 'ab', 'cd' }, '2G0g@<C-v>e', '2G0y<C-v>e'))

    -- Short last line: '] keeps the right edge (coladd past EOL).
    command('set virtualedit=block')
    eq({
      type = 'block',
      marks = { { 1, 2, 0 }, { 3, 3, 1 } },
      yank_marks = { { 1, 2, 0 }, { 3, 3, 1 } },
      yank = { 'bcd', 'bcd', 'b  ' },
    }, block({ 'abcdef', 'abcdef', 'ab' }, '1G4|g@<C-v>2j', '1G4|y<C-v>2j'))
    command('set virtualedit=')
  end)

  it('deletes the block, not the whole lines', function()
    api.nvim_buf_set_lines(0, 0, -1, true, { 'ab', 'cd' })
    feed('gg0d<C-v>j')
    eq({ 'b', 'd' }, api.nvim_buf_get_lines(0, 0, -1, true))

    api.nvim_buf_set_lines(0, 0, -1, true, { 'ab', 'cd' })
    feed('gg0<C-v>jd')
    eq({ 'b', 'd' }, api.nvim_buf_get_lines(0, 0, -1, true))
  end)
end)
