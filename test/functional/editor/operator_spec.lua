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

describe('operator', function()
  before_each(clear)

  it('forced-blockwise motion (o_CTRL-V): g@ and y get the block #42309', function()
    local marks = [=[[getpos("'[")[1:3], getpos("']")[1:3]]]=]
    n.exec(([[
      func! Op(type) abort
        let g:op = [a:type] + %s
      endfunc
      set operatorfunc=Op
    ]]):format(marks))
    --- Asserts that g@ and y see the same block: '[ and '] marks, and the yanked text.
    local function assert_block(lines, keys, expected_marks, expected_text)
      api.nvim_buf_set_lines(0, 0, -1, true, lines)
      feed(keys)
      eq({ 'block', unpack(expected_marks) }, api.nvim_get_var('op'), keys)
      feed((keys:gsub('g@', 'y')))
      eq(expected_marks, n.eval(marks), keys)
      eq(expected_text, fn.getreg('"', 1, 1), keys)
    end
    assert_block({ 'seed', 'ab', 'cd' }, '2G0g@<C-v>j', { { 2, 1, 0 }, { 3, 1, 0 } }, { 'a', 'c' })
    assert_block({ 'seed', 'ab', 'cd' }, '2G0g@<C-v>e', { { 2, 1, 0 }, { 2, 2, 0 } }, { 'ab' })
    -- Exclusive motion: the block still includes the end.
    assert_block({ 'abcd' }, '02|g@<C-v>l', { { 1, 2, 0 }, { 1, 3, 0 } }, { 'bc' })
    command('set selection=exclusive')
    assert_block({ 'abcd' }, '02|g@<C-v>l', { { 1, 2, 0 }, { 1, 2, 0 } }, { 'b' })
    command('set selection&')
    -- Short last line: '] keeps the right edge (past EOL).
    command('set virtualedit=block')
    assert_block(
      { 'abcdef', 'abcdef', 'ab' },
      '1G4|g@<C-v>2j',
      { { 1, 2, 0 }, { 3, 3, 1 } },
      { 'bcd', 'bcd', 'b  ' }
    )
    -- "d" deletes the block, not the lines.
    api.nvim_buf_set_lines(0, 0, -1, true, { 'ab', 'cd' })
    feed('gg0d<C-v>j')
    eq({ 'b', 'd' }, api.nvim_buf_get_lines(0, 0, -1, true))
  end)
end)
