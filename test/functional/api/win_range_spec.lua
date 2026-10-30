-- A window kept to a range of its buffer's lines (nvim_win_set_range).

local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local eq = t.eq
local clear = n.clear
local api = n.api
local pcall_err = t.pcall_err

describe('nvim_win_set_range', function()
  before_each(function()
    clear()
    api.nvim_buf_set_lines(0, 0, -1, false, { 'a', 'b', 'c', 'd', 'e', '', 'g' })
    api.nvim_win_set_range(0, 2, 4)
  end)

  --- The cursor's line after `keys`.
  local function line_after(keys)
    n.feed(keys)
    return api.nvim_win_get_cursor(0)[1]
  end

  it('keeps the cursor in the range', function()
    eq(3, line_after('gg'))
    eq(5, line_after('G'))
    eq(3, line_after('10k'))
    eq(5, line_after('10j'))
    eq({ 2, 4 }, api.nvim_win_get_range(0))
  end)

  it('lets an operator work only in the range', function()
    n.feed('ggdd')
    eq({ 'a', 'b', 'd', 'e', '', 'g' }, api.nvim_buf_get_lines(0, 0, -1, false))
    eq({ 2, 3 }, api.nvim_win_get_range(0))
  end)

  it('follows the edits: lines opened at its ends grow it', function()
    n.feed('Gox<Esc>')
    eq({ 2, 5 }, api.nvim_win_get_range(0))
    n.feed('ggOy<Esc>')
    eq({ 2, 6 }, api.nvim_win_get_range(0))
    -- Lines added above it move it.
    api.nvim_buf_set_lines(0, 0, 0, false, { 'z' })
    eq({ 3, 7 }, api.nvim_win_get_range(0))
  end)

  it("runs to the buffer's end when it ends on its last line", function()
    api.nvim_win_set_range(0, 5, 6)
    n.feed('Go<Esc>')
    eq({ 5, 7 }, api.nvim_win_get_range(0))
    -- The line opened is the cursor's, kept.
    eq(9, line_after('ox<Esc>'))
    eq({ 5, 8 }, api.nvim_win_get_range(0))
    eq({ 'a', 'b', 'c', 'd', 'e', '', 'g', '', 'x' }, api.nvim_buf_get_lines(0, 0, -1, false))
    -- Set to end before the last line, it does not: lines added at the
    -- buffer's end are not its.
    api.nvim_win_set_range(0, 5, 6)
    api.nvim_buf_set_lines(0, -1, -1, false, { 'y' })
    eq({ 5, 6 }, api.nvim_win_get_range(0))
  end)

  it('is a window\'s own: other windows on the buffer are free', function()
    local win = api.nvim_get_current_win()
    n.command('split')
    eq({}, api.nvim_win_get_range(0))
    eq(1, line_after('gg'))
    eq({ 2, 4 }, api.nvim_win_get_range(win))
  end)

  it('is let go', function()
    api.nvim_win_del_range(0)
    eq({}, api.nvim_win_get_range(0))
    eq(1, line_after('gg'))
  end)

  it('takes only lines of the buffer', function()
    eq('Invalid range: 4..2 (the buffer has 7 lines)', pcall_err(api.nvim_win_set_range, 0, 4, 2))
    eq('Invalid range: 0..9 (the buffer has 7 lines)', pcall_err(api.nvim_win_set_range, 0, 0, 9))
  end)
end)
