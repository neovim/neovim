-- Test Ctrl-A and Ctrl-X, which increment and decrement decimal, hexadecimal,
-- and octal numbers.

local t = require('test.functional.testutil')(after_each)
local clear, feed, insert = t.clear, t.feed, t.insert
local feed_command, expect = t.feed_command, t.expect

describe('increment and decrement commands', function()
  setup(clear)

  it('should work', function()
    -- Insert some numbers in various bases.
    insert([[
      0b101   100     0x100     077     0
      0b101   100     0x100     077
      100     0x100     077     0xfF     0xFf
      100     0x100     077
      0x0b101  0b1101]])

    -- Increment and decrement numbers in the first row, interpreting the
    -- numbers as decimal, octal or hexadecimal.
    feed_command('set nrformats=bin,octal,hex', '1')
    feed('63l102ll64128$')

    -- For the second row, treat the numbers as decimal or octal.
    -- 0x100 should be interpreted as decimal 0, the character x, and decimal 100.
    feed_command('set nrformats=octal', '2')
    feed('0w102l2w65129blx6lD')

    -- For the third row, treat the numbers as decimal or hexadecimal.
    -- 077 should be interpreted as decimal 77.
    feed_command('set nrformats=hex', '3')
    feed('0101l257Txldt   ')

    -- For the fourth row, interpret all numbers as decimal.
    feed_command('set nrformats=', '4')
    feed('0200l100w78')

    -- For the last row, interpret as binary and hexadecimal.
    feed_command('set nrformats=bin,hex', '5')
    feed('010065l6432')

    expect([[
      0b011   0     0x0ff     0000     -1
      1b101   0     1x100     0777777
      -1     0x0     078     0xFE     0xfe
      -100     -100x100     000
      0x0b0de  0b0101101]])
  end)
end)
