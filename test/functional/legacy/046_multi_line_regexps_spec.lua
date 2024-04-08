-- vim: set foldmethod=marker foldmarker=[[,]] :
-- Tests for multi-line regexps with ":s"

local t = require('test.functional.testutil')(after_each)
local clear, feed, insert = t.clear, t.feed, t.insert
local expect = t.expect

describe('multi-line regexp', function()
  setup(clear)

  it('is working', function()
    insert([[
      1 aa
      bb
      cc
      2 dd
      ee
      3 ef
      gh
      4 ij
      5 a8
      8b c9
      9d
      6 e7
      77f
      xxxxx]])

    -- Test if replacing a line break works with a back reference
    feed([[:/^1/,/^2/s/\n\(.\)/ \1/<cr>]])

    -- Test if inserting a line break works with a back reference
    feed([[:/^3/,/^4/s/\(.\)$/\r\1/<cr>]])

    -- Test if replacing a line break with another line break works
    feed([[:/^5/,/^6/s/\(\_d\{3}\)/x\1x/<cr>]])

    expect([[
      1 aa bb cc 2 dd ee
      3 e
      f
      g
      h
      4 i
      j
      5 ax8
      8xb cx9
      9xd
      6 ex7
      7x7f
      xxxxx]])
  end)
end)
