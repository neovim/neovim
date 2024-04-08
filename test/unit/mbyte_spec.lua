local t = require('test.unit.testutil')(after_each)
local itp = t.gen_itp(it)

local ffi = t.ffi
local eq = t.eq

local lib = t.cimport('./src/nvim/mbyte.h', './src/nvim/charset.h', './src/nvim/grid.h')

describe('mbyte', function()
  -- Convert from bytes to string
  local function to_string(bytes)
    local s = {}
    for i = 1, #bytes do
      s[i] = string.char(bytes[i])
    end
    return table.concat(s)
  end

  before_each(function() end)

  itp('utf_ptr2char', function()
    -- For strings with length 1 the first byte is returned.
    for c = 0, 255 do
      eq(c, lib.utf_ptr2char(to_string({ c, 0 })))
    end

    -- Some ill formed byte sequences that should not be recognized as UTF-8
    -- First byte: 0xc0 or 0xc1
    -- Second byte: 0x80 .. 0xbf
    --eq(0x00c0, lib.utf_ptr2char(to_string({0xc0, 0x80})))
    --eq(0x00c1, lib.utf_ptr2char(to_string({0xc1, 0xbf})))
    --
    -- Sequences with more than four bytes
  end)

  for n = 0, 0xF do
    itp(('utf_char2bytes for chars 0x%x - 0x%x'):format(n * 0x1000, n * 0x1000 + 0xFFF), function()
      local char_p = ffi.typeof('char[?]')
      for c = n * 0x1000, n * 0x1000 + 0xFFF do
        local p = char_p(4, 0)
        lib.utf_char2bytes(c, p)
        eq(c, lib.utf_ptr2char(p))
        eq(lib.vim_iswordc(c), lib.vim_iswordp(p))
      end
    end)
  end

  describe('utfc_ptr2schar_len', function()
    local function test_seq(seq)
      local firstc = ffi.new('int[1]')
      local buf = ffi.new('char[32]')
      lib.schar_get(buf, lib.utfc_ptr2schar_len(to_string(seq), #seq, firstc))
      return { ffi.string(buf), firstc[0] }
    end

    local function byte(val)
      return { string.char(val), val }
    end

    itp('1-byte sequences', function()
      eq({ '', 0 }, test_seq { 0 })
      for c = 1, 127 do
        eq(byte(c), test_seq { c })
      end
      for c = 128, 255 do
        eq({ '', c }, test_seq { c })
      end
    end)

    itp('2-byte sequences', function()
      -- No combining characters
      eq(byte(0x7f), test_seq { 0x7f, 0x7f })
      -- No combining characters
      eq(byte(0x7f), test_seq { 0x7f, 0x80 })

      -- No UTF-8 sequence
      eq({ '', 0xc2 }, test_seq { 0xc2, 0x7f })
      -- One UTF-8 character
      eq({ '\xc2\x80', 0x80 }, test_seq { 0xc2, 0x80 })
      -- No UTF-8 sequence
      eq({ '', 0xc2 }, test_seq { 0xc2, 0xc0 })
    end)

    itp('3-byte sequences', function()
      -- No second UTF-8 character
      eq(byte(0x7f), test_seq { 0x7f, 0x80, 0x80 })
      -- No combining character
      eq(byte(0x7f), test_seq { 0x7f, 0xc2, 0x80 })

      -- Combining character is U+0300
      eq({ '\x7f\xcc\x80', 0x7f }, test_seq { 0x7f, 0xcc, 0x80 })

      -- No UTF-8 sequence
      eq({ '', 0xc2 }, test_seq { 0xc2, 0x7f, 0xcc })
      -- Incomplete combining character
      eq({ '\xc2\x80', 0x80 }, test_seq { 0xc2, 0x80, 0xcc })

      -- One UTF-8 character (composing only)
      eq({ ' \xe2\x83\x90', 0x20d0 }, test_seq { 0xe2, 0x83, 0x90 })
    end)

    itp('4-byte sequences', function()
      -- No following combining character
      eq(byte(0x7f), test_seq { 0x7f, 0x7f, 0xcc, 0x80 })
      -- No second UTF-8 character
      eq(byte(0x7f), test_seq { 0x7f, 0xc2, 0xcc, 0x80 })

      -- Combining character U+0300
      eq({ '\x7f\xcc\x80', 0x7f }, test_seq { 0x7f, 0xcc, 0x80, 0xcc })

      -- No UTF-8 sequence
      eq({ '', 0xc2 }, test_seq { 0xc2, 0x7f, 0xcc, 0x80 })
      -- No following UTF-8 character
      eq({ '\xc2\x80', 0x80 }, test_seq { 0xc2, 0x80, 0xcc, 0xcc })
      -- Combining character U+0301
      eq({ '\xc2\x80\xcc\x81', 0x80 }, test_seq { 0xc2, 0x80, 0xcc, 0x81 })

      -- One UTF-8 character
      eq({ '\xf4\x80\x80\x80', 0x100000 }, test_seq { 0xf4, 0x80, 0x80, 0x80 })
    end)

    itp('5+-byte sequences', function()
      -- No following combining character
      eq(byte(0x7f), test_seq { 0x7f, 0x7f, 0xcc, 0x80, 0x80 })
      -- No second UTF-8 character
      eq(byte(0x7f), test_seq { 0x7f, 0xc2, 0xcc, 0x80, 0x80 })

      -- Combining character U+0300
      eq({ '\x7f\xcc\x80', 0x7f }, test_seq { 0x7f, 0xcc, 0x80, 0xcc, 0x00 })

      -- Combining characters U+0300 and U+0301
      eq({ '\x7f\xcc\x80\xcc\x81', 0x7f }, test_seq { 0x7f, 0xcc, 0x80, 0xcc, 0x81 })
      -- Combining characters U+0300, U+0301, U+0302
      eq(
        { '\x7f\xcc\x80\xcc\x81\xcc\x82', 0x7f },
        test_seq { 0x7f, 0xcc, 0x80, 0xcc, 0x81, 0xcc, 0x82 }
      )
      -- Combining characters U+0300, U+0301, U+0302, U+0303
      eq(
        { '\x7f\xcc\x80\xcc\x81\xcc\x82\xcc\x83', 0x7f },
        test_seq { 0x7f, 0xcc, 0x80, 0xcc, 0x81, 0xcc, 0x82, 0xcc, 0x83 }
      )
      -- Combining characters U+0300, U+0301, U+0302, U+0303, U+0304
      eq(
        { '\x7f\xcc\x80\xcc\x81\xcc\x82\xcc\x83\xcc\x84', 0x7f },
        test_seq { 0x7f, 0xcc, 0x80, 0xcc, 0x81, 0xcc, 0x82, 0xcc, 0x83, 0xcc, 0x84 }
      )
      -- Combining characters U+0300, U+0301, U+0302, U+0303, U+0304, U+0305
      eq(
        { '\x7f\xcc\x80\xcc\x81\xcc\x82\xcc\x83\xcc\x84\xcc\x85', 0x7f },
        test_seq { 0x7f, 0xcc, 0x80, 0xcc, 0x81, 0xcc, 0x82, 0xcc, 0x83, 0xcc, 0x84, 0xcc, 0x85 }
      )

      -- Combining characters U+0300, U+0301, U+0302, U+0303, U+0304, U+0305, U+0306
      eq(
        { '\x7f\xcc\x80\xcc\x81\xcc\x82\xcc\x83\xcc\x84\xcc\x85\xcc\x86', 0x7f },
        test_seq {
          0x7f,
          0xcc,
          0x80,
          0xcc,
          0x81,
          0xcc,
          0x82,
          0xcc,
          0x83,
          0xcc,
          0x84,
          0xcc,
          0x85,
          0xcc,
          0x86,
        }
      )

      -- Only three following combining characters U+0300, U+0301, U+0302
      eq(
        { '\x7f\xcc\x80\xcc\x81\xcc\x82', 0x7f },
        test_seq { 0x7f, 0xcc, 0x80, 0xcc, 0x81, 0xcc, 0x82, 0xc2, 0x80, 0xcc, 0x84, 0xcc, 0x85 }
      )

      -- No UTF-8 sequence
      eq({ '', 0xc2 }, test_seq { 0xc2, 0x7f, 0xcc, 0x80, 0x80 })
      -- No following UTF-8 character
      eq({ '\xc2\x80', 0x80 }, test_seq { 0xc2, 0x80, 0xcc, 0xcc, 0x80 })
      -- Combining character U+0301
      eq({ '\xc2\x80\xcc\x81', 0x80 }, test_seq { 0xc2, 0x80, 0xcc, 0x81, 0x7f })
      -- Combining character U+0301
      eq({ '\xc2\x80\xcc\x81', 0x80 }, test_seq { 0xc2, 0x80, 0xcc, 0x81, 0xcc })

      -- One UTF-8 character
      eq({ '\xf4\x80\x80\x80', 0x100000 }, test_seq { 0xf4, 0x80, 0x80, 0x80, 0x7f })

      -- One UTF-8 character
      eq({ '\xf4\x80\x80\x80', 0x100000 }, test_seq { 0xf4, 0x80, 0x80, 0x80, 0x80 })
      -- One UTF-8 character
      eq({ '\xf4\x80\x80\x80', 0x100000 }, test_seq { 0xf4, 0x80, 0x80, 0x80, 0xcc })

      -- Combining characters U+1AB0 and U+0301
      eq(
        { '\xf4\x80\x80\x80\xe1\xaa\xb0\xcc\x81', 0x100000 },
        test_seq { 0xf4, 0x80, 0x80, 0x80, 0xe1, 0xaa, 0xb0, 0xcc, 0x81 }
      )
    end)
  end)

  describe('utf_cp_bounds_len', function()
    local to_cstr = t.to_cstr

    local tests = {
      {
        name = 'for valid string',
        str = 'iÀiiⱠiⱠⱠ𐀀i',
        offsets = {
          b = { 0, 0, 1, 0, 0, 0, 1, 2, 0, 0, 1, 2, 0, 1, 2, 0, 1, 2, 3, 0 },
          e = { 1, 2, 1, 1, 1, 3, 2, 1, 1, 3, 2, 1, 3, 2, 1, 4, 3, 2, 1, 1 },
        },
      },
      {
        name = 'for string with incomplete sequence',
        str = 'i\xC3iÀⱠiÀ\xE2\xB1Ⱡ\xF0\x90\x80',
        offsets = {
          b = { 0, 0, 0, 0, 1, 0, 1, 2, 0, 0, 1, 0, 0, 0, 1, 2, 0, 0, 0 },
          e = { 1, 1, 1, 2, 1, 3, 2, 1, 1, 2, 1, 1, 1, 3, 2, 1, 1, 1, 1 },
        },
      },
      {
        name = 'for string with trailing bytes after multibyte',
        str = 'iÀ\xA0Ⱡ\xA0Ⱡ𐀀\xA0i',
        offsets = {
          b = { 0, 0, 1, 0, 0, 1, 2, 0, 0, 1, 2, 0, 1, 2, 3, 0, 0 },
          e = { 1, 2, 1, 1, 3, 2, 1, 1, 3, 2, 1, 4, 3, 2, 1, 1, 1 },
        },
      },
    }

    for _, test in ipairs(tests) do
      itp(test.name, function()
        local cstr = to_cstr(test.str)
        local b_offsets, e_offsets = {}, {}
        for i = 1, #test.str do
          local result = lib.utf_cp_bounds_len(cstr, cstr + i - 1, #test.str - (i - 1))
          table.insert(b_offsets, result.begin_off)
          table.insert(e_offsets, result.end_off)
        end
        eq(test.offsets, { b = b_offsets, e = e_offsets })
      end)
    end

    itp('does not read before start', function()
      local str = '𐀀'
      local expected_offsets = { b = { 0, 0, 0 }, e = { 1, 1, 1 } }
      local cstr = to_cstr(str) + 1
      local b_offsets, e_offsets = {}, {}
      for i = 1, 3 do
        local result = lib.utf_cp_bounds_len(cstr, cstr + i - 1, 3 - (i - 1))
        table.insert(b_offsets, result.begin_off)
        table.insert(e_offsets, result.end_off)
      end
      eq(expected_offsets, { b = b_offsets, e = e_offsets })
    end)

    itp('does not read past the end', function()
      local str = '𐀀'
      local expected_offsets = { b = { 0, 0, 0 }, e = { 1, 1, 1 } }
      local cstr = to_cstr(str)
      local b_offsets, e_offsets = {}, {}
      for i = 1, 3 do
        local result = lib.utf_cp_bounds_len(cstr, cstr + i - 1, 3 - (i - 1))
        table.insert(b_offsets, result.begin_off)
        table.insert(e_offsets, result.end_off)
      end
      eq(expected_offsets, { b = b_offsets, e = e_offsets })
    end)
  end)
end)
