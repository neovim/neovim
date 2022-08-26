-- Tests for correct display (cursor column position) with +conceal and
-- tabulators.

local helpers = require('test.functional.helpers')(after_each)
local feed, insert, clear, feed_command =
  helpers.feed, helpers.insert, helpers.clear, helpers.feed_command

local expect_pos = function(row, col)
  return helpers.eq({row, col}, helpers.eval('[screenrow(), screencol()]'))
end

describe('cursor and column position with conceal and tabulators', function()
  setup(clear)

  -- luacheck: ignore 621 (Indentation)
  it('are working', function()
    insert([[
      start:
      .concealed.     text
      |concealed|	text

      	.concealed.	text
      	|concealed|	text

      .a.	.b.	.c.	.d.
      |a|	|b|	|c|	|d|]])

    -- Conceal settings.
    feed_command('set conceallevel=2')
    feed_command('set concealcursor=nc')
    feed_command('syntax match test /|/ conceal')
    -- Start test.
    feed_command('/^start:')
    feed('ztj')
    expect_pos(2, 1)
    -- We should end up in the same column when running these commands on the
    -- two lines.
    feed('ft')
    expect_pos(2, 17)
    feed('$')
    expect_pos(2, 20)
    feed('0j')
    expect_pos(3, 1)
    feed('ft')
    expect_pos(3, 17)
    feed('$')
    expect_pos(3, 20)
    feed('j0j')
    expect_pos(5, 8)
    -- Same for next test block.
    feed('ft')
    expect_pos(5, 25)
    feed('$')
    expect_pos(5, 28)
    feed('0j')
    expect_pos(6, 8)
    feed('ft')
    expect_pos(6, 25)
    feed('$')
    expect_pos(6, 28)
    feed('0j0j')
    expect_pos(8, 1)
    -- And check W with multiple tabs and conceals in a line.
    feed('W')
    expect_pos(8, 9)
    feed('W')
    expect_pos(8, 17)
    feed('W')
    expect_pos(8, 25)
    feed('$')
    expect_pos(8, 27)
    feed('0j')
    expect_pos(9, 1)
    feed('W')
    expect_pos(9, 9)
    feed('W')
    expect_pos(9, 17)
    feed('W')
    expect_pos(9, 25)
    feed('$')
    expect_pos(9, 26)
    feed_command('set lbr')
    feed('$')
    expect_pos(9, 26)
    feed_command('set list listchars=tab:>-')
    feed('0')
    expect_pos(9, 1)
    feed('W')
    expect_pos(9, 9)
    feed('W')
    expect_pos(9, 17)
    feed('W')
    expect_pos(9, 25)
    feed('$')
    expect_pos(9, 26)
  end)
end)
