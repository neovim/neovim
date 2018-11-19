local helpers = require("test.unit.helpers")(after_each)
local itp = helpers.gen_itp(it)

local ffi     = helpers.ffi
local eq      = helpers.eq

local mbyte = helpers.cimport("./src/nvim/mbyte.h")
local charset = helpers.cimport('./src/nvim/charset.h')

describe('mbyte', function()

  -- Array for composing characters
  local intp = ffi.typeof('int[?]')
  local function to_intp()
    -- how to get MAX_MCO from globals.h?
    return intp(7, 1)
  end

  -- Convert from bytes to string
  local function to_string(bytes)
    local s = {}
    for i = 1, #bytes do
      s[i] = string.char(bytes[i])
    end
    return table.concat(s)
  end

  before_each(function()
  end)

  itp('utf_ptr2char', function()
    -- For strings with length 1 the first byte is returned.
    for c = 0, 255 do
      eq(c, mbyte.utf_ptr2char(to_string({c, 0})))
    end

    -- Some ill formed byte sequences that should not be recognized as UTF-8
    -- First byte: 0xc0 or 0xc1
    -- Second byte: 0x80 .. 0xbf
    --eq(0x00c0, mbyte.utf_ptr2char(to_string({0xc0, 0x80})))
    --eq(0x00c1, mbyte.utf_ptr2char(to_string({0xc1, 0xbf})))
    --
    -- Sequences with more than four bytes
  end)

  for n = 0, 0xF do
    itp(('utf_char2bytes for chars 0x%x - 0x%x'):format(n * 0x1000, n * 0x1000 + 0xFFF), function()
      local char_p = ffi.typeof('char[?]')
      for c = n * 0x1000, n * 0x1000 + 0xFFF do
        local p = char_p(4, 0)
        mbyte.utf_char2bytes(c, p)
        eq(c, mbyte.utf_ptr2char(p))
        eq(charset.vim_iswordc(c), charset.vim_iswordp(p))
      end
    end)
  end

  describe('utfc_ptr2char_len', function()

    itp('1-byte sequences', function()
      local pcc = to_intp()
      for c = 0, 255 do
        eq(c, mbyte.utfc_ptr2char_len(to_string({c}), pcc, 1))
        eq(0, pcc[0])
      end
    end)

    itp('2-byte sequences', function()
      local pcc = to_intp()
      -- No combining characters
      eq(0x007f, mbyte.utfc_ptr2char_len(to_string({0x7f, 0x7f}), pcc, 2))
      eq(0, pcc[0])
      -- No combining characters
      pcc = to_intp()
      eq(0x007f, mbyte.utfc_ptr2char_len(to_string({0x7f, 0x80}), pcc, 2))
      eq(0, pcc[0])

      -- No UTF-8 sequence
      pcc = to_intp()
      eq(0x00c2, mbyte.utfc_ptr2char_len(to_string({0xc2, 0x7f}), pcc, 2))
      eq(0, pcc[0])
      -- One UTF-8 character
      pcc = to_intp()
      eq(0x0080, mbyte.utfc_ptr2char_len(to_string({0xc2, 0x80}), pcc, 2))
      eq(0, pcc[0])
      -- No UTF-8 sequence
      pcc = to_intp()
      eq(0x00c2, mbyte.utfc_ptr2char_len(to_string({0xc2, 0xc0}), pcc, 2))
      eq(0, pcc[0])
    end)

    itp('3-byte sequences', function()
      local pcc = to_intp()

      -- No second UTF-8 character
      eq(0x007f, mbyte.utfc_ptr2char_len(to_string({0x7f, 0x80, 0x80}), pcc, 3))
      eq(0, pcc[0])
      -- No combining character
      pcc = to_intp()
      eq(0x007f, mbyte.utfc_ptr2char_len(to_string({0x7f, 0xc2, 0x80}), pcc, 3))
      eq(0, pcc[0])

      -- Combining character is U+0300
      pcc = to_intp()
      eq(0x007f, mbyte.utfc_ptr2char_len(to_string({0x7f, 0xcc, 0x80}), pcc, 3))
      eq(0x0300, pcc[0])
      eq(0x0000, pcc[1])

      -- No UTF-8 sequence
      pcc = to_intp()
      eq(0x00c2, mbyte.utfc_ptr2char_len(to_string({0xc2, 0x7f, 0xcc}), pcc, 3))
      eq(0, pcc[0])
      -- Incomplete combining character
      pcc = to_intp()
      eq(0x0080, mbyte.utfc_ptr2char_len(to_string({0xc2, 0x80, 0xcc}), pcc, 3))
      eq(0, pcc[0])

      -- One UTF-8 character
      pcc = to_intp()
      eq(0x20d0, mbyte.utfc_ptr2char_len(to_string({0xe2, 0x83, 0x90}), pcc, 3))
      eq(0, pcc[0])
    end)

    itp('4-byte sequences', function()
      local pcc = to_intp()

      -- No following combining character
      eq(0x007f, mbyte.utfc_ptr2char_len(to_string({0x7f, 0x7f, 0xcc, 0x80}), pcc, 4))
      eq(0, pcc[0])
      -- No second UTF-8 character
      pcc = to_intp()
      eq(0x007f, mbyte.utfc_ptr2char_len(to_string({0x7f, 0xc2, 0xcc, 0x80}), pcc, 4))
      eq(0, pcc[0])

      -- Combining character U+0300
      pcc = to_intp()
      eq(0x007f, mbyte.utfc_ptr2char_len(to_string({0x7f, 0xcc, 0x80, 0xcc}), pcc, 4))
      eq(0x0300, pcc[0])
      eq(0x0000, pcc[1])

      -- No UTF-8 sequence
      pcc = to_intp()
      eq(0x00c2, mbyte.utfc_ptr2char_len(to_string({0xc2, 0x7f, 0xcc, 0x80}), pcc, 4))
      eq(0, pcc[0])
      -- No following UTF-8 character
      pcc = to_intp()
      eq(0x0080, mbyte.utfc_ptr2char_len(to_string({0xc2, 0x80, 0xcc, 0xcc}), pcc, 4))
      eq(0, pcc[0])
      -- Combining character U+0301
      pcc = to_intp()
      eq(0x0080, mbyte.utfc_ptr2char_len(to_string({0xc2, 0x80, 0xcc, 0x81}), pcc, 4))
      eq(0x0301, pcc[0])
      eq(0x0000, pcc[1])

      -- One UTF-8 character
      pcc = to_intp()
      eq(0x100000, mbyte.utfc_ptr2char_len(to_string({0xf4, 0x80, 0x80, 0x80}), pcc, 4))
      eq(0, pcc[0])
    end)

    itp('5+-byte sequences', function()
      local pcc = to_intp()

      -- No following combining character
      eq(0x007f, mbyte.utfc_ptr2char_len(to_string({0x7f, 0x7f, 0xcc, 0x80, 0x80}), pcc, 5))
      eq(0, pcc[0])
      -- No second UTF-8 character
      pcc = to_intp()
      eq(0x007f, mbyte.utfc_ptr2char_len(to_string({0x7f, 0xc2, 0xcc, 0x80, 0x80}), pcc, 5))
      eq(0, pcc[0])

      -- Combining character U+0300
      pcc = to_intp()
      eq(0x007f, mbyte.utfc_ptr2char_len(to_string({0x7f, 0xcc, 0x80, 0xcc}), pcc, 5))
      eq(0x0300, pcc[0])
      eq(0x0000, pcc[1])

      -- Combining characters U+0300 and U+0301
      pcc = to_intp()
      eq(0x007f, mbyte.utfc_ptr2char_len(to_string({0x7f, 0xcc, 0x80, 0xcc, 0x81}), pcc, 5))
      eq(0x0300, pcc[0])
      eq(0x0301, pcc[1])
      eq(0x0000, pcc[2])
      -- Combining characters U+0300, U+0301, U+0302
      pcc = to_intp()
      eq(0x007f, mbyte.utfc_ptr2char_len(to_string({0x7f, 0xcc, 0x80, 0xcc, 0x81, 0xcc, 0x82}), pcc, 7))
      eq(0x0300, pcc[0])
      eq(0x0301, pcc[1])
      eq(0x0302, pcc[2])
      eq(0x0000, pcc[3])
      -- Combining characters U+0300, U+0301, U+0302, U+0303
      pcc = to_intp()
      eq(0x007f, mbyte.utfc_ptr2char_len(to_string({0x7f, 0xcc, 0x80, 0xcc, 0x81, 0xcc, 0x82, 0xcc, 0x83}), pcc, 9))
      eq(0x0300, pcc[0])
      eq(0x0301, pcc[1])
      eq(0x0302, pcc[2])
      eq(0x0303, pcc[3])
      eq(0x0000, pcc[4])
      -- Combining characters U+0300, U+0301, U+0302, U+0303, U+0304
      pcc = to_intp()
      eq(0x007f, mbyte.utfc_ptr2char_len(to_string(
        {0x7f, 0xcc, 0x80, 0xcc, 0x81, 0xcc, 0x82, 0xcc, 0x83, 0xcc, 0x84}), pcc, 11))
      eq(0x0300, pcc[0])
      eq(0x0301, pcc[1])
      eq(0x0302, pcc[2])
      eq(0x0303, pcc[3])
      eq(0x0304, pcc[4])
      eq(0x0000, pcc[5])
      -- Combining characters U+0300, U+0301, U+0302, U+0303, U+0304,
      -- U+0305
      pcc = to_intp()
      eq(0x007f, mbyte.utfc_ptr2char_len(to_string(
        {0x7f, 0xcc, 0x80, 0xcc, 0x81, 0xcc, 0x82, 0xcc, 0x83, 0xcc, 0x84, 0xcc, 0x85}), pcc, 13))
      eq(0x0300, pcc[0])
      eq(0x0301, pcc[1])
      eq(0x0302, pcc[2])
      eq(0x0303, pcc[3])
      eq(0x0304, pcc[4])
      eq(0x0305, pcc[5])
      eq(1, pcc[6])

      -- Combining characters U+0300, U+0301, U+0302, U+0303, U+0304,
      -- U+0305, U+0306, but only save six (= MAX_MCO).
      pcc = to_intp()
      eq(0x007f, mbyte.utfc_ptr2char_len(to_string(
        {0x7f, 0xcc, 0x80, 0xcc, 0x81, 0xcc, 0x82, 0xcc, 0x83, 0xcc, 0x84, 0xcc, 0x85, 0xcc, 0x86}), pcc, 15))
      eq(0x0300, pcc[0])
      eq(0x0301, pcc[1])
      eq(0x0302, pcc[2])
      eq(0x0303, pcc[3])
      eq(0x0304, pcc[4])
      eq(0x0305, pcc[5])
      eq(0x0001, pcc[6])

      -- Only three following combining characters U+0300, U+0301, U+0302
      pcc = to_intp()
      eq(0x007f, mbyte.utfc_ptr2char_len(to_string(
        {0x7f, 0xcc, 0x80, 0xcc, 0x81, 0xcc, 0x82, 0xc2, 0x80, 0xcc, 0x84, 0xcc, 0x85}), pcc, 13))
      eq(0x0300, pcc[0])
      eq(0x0301, pcc[1])
      eq(0x0302, pcc[2])
      eq(0x0000, pcc[3])


      -- No UTF-8 sequence
      pcc = to_intp()
      eq(0x00c2, mbyte.utfc_ptr2char_len(to_string({0xc2, 0x7f, 0xcc, 0x80, 0x80}), pcc, 5))
      eq(0, pcc[0])
      -- No following UTF-8 character
      pcc = to_intp()
      eq(0x0080, mbyte.utfc_ptr2char_len(to_string({0xc2, 0x80, 0xcc, 0xcc, 0x80}), pcc, 5))
      eq(0, pcc[0])
      -- Combining character U+0301
      pcc = to_intp()
      eq(0x0080, mbyte.utfc_ptr2char_len(to_string({0xc2, 0x80, 0xcc, 0x81, 0x7f}), pcc, 5))
      eq(0x0301, pcc[0])
      eq(0x0000, pcc[1])
      -- Combining character U+0301
      pcc = to_intp()
      eq(0x0080, mbyte.utfc_ptr2char_len(to_string({0xc2, 0x80, 0xcc, 0x81, 0xcc}), pcc, 5))
      eq(0x0301, pcc[0])
      eq(0x0000, pcc[1])

      -- One UTF-8 character
      pcc = to_intp()
      eq(0x100000, mbyte.utfc_ptr2char_len(to_string({0xf4, 0x80, 0x80, 0x80, 0x7f}), pcc, 5))
      eq(0, pcc[0])

      -- One UTF-8 character
      pcc = to_intp()
      eq(0x100000, mbyte.utfc_ptr2char_len(to_string({0xf4, 0x80, 0x80, 0x80, 0x80}), pcc, 5))
      eq(0, pcc[0])
      -- One UTF-8 character
      pcc = to_intp()
      eq(0x100000, mbyte.utfc_ptr2char_len(to_string({0xf4, 0x80, 0x80, 0x80, 0xcc}), pcc, 5))
      eq(0, pcc[0])

      -- Combining characters U+1AB0 and U+0301
      pcc = to_intp()
      eq(0x100000, mbyte.utfc_ptr2char_len(to_string(
        {0xf4, 0x80, 0x80, 0x80, 0xe1, 0xaa, 0xb0, 0xcc, 0x81}), pcc, 9))
      eq(0x1ab0, pcc[0])
      eq(0x0301, pcc[1])
      eq(0x0000, pcc[2])
    end)

  end)

end)
