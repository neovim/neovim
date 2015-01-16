-- Test Ctrl-A and Ctrl-X, which increment and decrement decimal, hexadecimal,
-- and octal numbers.

local helpers = require('test.functional.helpers')
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute, expect = helpers.execute, helpers.expect

describe('increment and decrement commands', function()
  setup(clear)

  it('should work', function()
    -- Insert some numbers in various bases.
    insert([[
      100     0x100     077     0
      100     0x100     077
      100     0x100     077     0xfF     0xFf
      100     0x100     077]])

    -- Increment and decrement numbers in the first row, interpreting the
    -- numbers as decimal, octal or hexadecimal.
    execute('set nrformats=octal,hex', '1')
    feed('102ll64128$')

    -- For the second row, treat the numbers as decimal or octal.
    -- 0x100 should be interpreted as decimal 0, the character x, and decimal 100.
    execute('set nrformats=octal', '2')
    feed('0102l2w65129blx6lD')

    -- For the third row, treat the numbers as decimal or hexadecimal.
    -- 077 should be interpreted as decimal 77.
    execute('set nrformats=hex', '3')
    feed('0101l257Txldt   ')

    -- For the last row, interpret all numbers as decimal.
    execute('set nrformats=', '4')
    feed('0200l100w78')

    expect([[
      0     0x0ff     0000     -1
      0     1x100     0777777
      -1     0x0     078     0xFE     0xfe
      -100     -100x100     000]])
  end)
end)
