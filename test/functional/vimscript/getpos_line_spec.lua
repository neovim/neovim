-- Tests for line(), getpos(), getcurpos(), getcharpos().

local helpers = require('test.functional.helpers')(after_each)
local eval = helpers.eval
local getpos = helpers.funcs.getpos
local insert = helpers.insert
local clear = helpers.clear
local eq = helpers.eq
local feed = helpers.feed

describe('getpos() function', function()
  before_each(function()
    clear()
    insert([[
    First line of text
    Second line of text
    Third line of text
    Fourth line of text]])
  end)

  it('getpos("v"), getpos("v$")', function()
    local maxcol = eval('v:maxcol')
    feed('gg0')

    -- "v" (charwise-visual)
    feed('ljv3ljl')
    eq({0, 2, 2, 0}, getpos('v'))   -- Visual start.
    eq({0, 3, 6, 0}, getpos('.'))   -- Cursor position.
    eq({0, 3, 6, 0}, getpos('v$'))  -- Visual end.

    -- "V" (linewise-visual)
    feed('V')
    eq({0, 2, maxcol, 0}, getpos('v'))
    eq({0, 3, maxcol, 0}, getpos('v$'))
    feed('o')
    eq({0, 3, maxcol, 0}, getpos('v'))
    eq({0, 2, maxcol, 0}, getpos('v$'))
    feed('o')

    -- "^v" (blockwise-visual)
    feed('\22')
    local v_pos = getpos('v')   -- Visual start.
    local v_end = getpos('v$')  -- Visual end.
    eq({0, 2, 2, 0}, v_pos)
    eq({0, 3, 6, 0}, v_end)
    -- "o" changes the result: "start" and "end" are swapped.
    feed('o')
    eq(v_end, getpos('v'))
    eq(v_pos, getpos('v$'))
    -- "O" changes the result of getpos('v').
    feed('O')
    eq({0, 3, 2, 0}, getpos('v'))
    eq({0, 2, 6, 0}, getpos('v$'))
  end)

end)

