local helpers = require("test.unit.helpers")(after_each)
local bit = require('bit')

local itp = helpers.gen_itp(it)

local child_call_once = helpers.child_call_once
local cimport = helpers.cimport
local ffi = helpers.ffi

local lib = cimport('./src/nvim/charset.h')

local ARGTYPES

child_call_once(function()
  ARGTYPES = {
    num = ffi.typeof('varnumber_T[1]'),
    unum = ffi.typeof('uvarnumber_T[1]'),
    pre = ffi.typeof('int[1]'),
    len = ffi.typeof('int[1]'),
  }
end)

local icnt = -42
local ucnt = 4242

local function arginit(arg)
  if arg == 'unum' then
    ucnt = ucnt + 1
    return ARGTYPES[arg]({ucnt})
  else
    icnt = icnt - 1
    return ARGTYPES[arg]({icnt})
  end
end

local function argreset(arg, args)
  if arg == 'unum' then
    ucnt = ucnt + 1
    args[arg][0] = ucnt
  else
    icnt = icnt - 1
    args[arg][0] = icnt
  end
end

local function test_vim_str2nr(s, what, exp, maxlen)
  local bits = {}
  for k, _ in pairs(exp) do
    bits[#bits + 1] = k
  end
  maxlen = maxlen or #s
  local args = {}
  for k, _ in pairs(ARGTYPES) do
    args[k] = arginit(k)
  end
  for case = 0, ((2 ^ (#bits)) - 1) do
    local cv = {}
    for b = 0, (#bits - 1) do
      if bit.band(case, (2 ^ b)) == 0 then
        local k = bits[b + 1]
        argreset(k, args)
        cv[k] = args[k]
      end
    end
    lib.vim_str2nr(s, cv.pre, cv.len, what, cv.num, cv.unum, maxlen)
    for cck, ccv in pairs(cv) do
      if exp[cck] ~= tonumber(ccv[0]) then
        error(('Failed check (%s = %d) in test (s=%s, w=%u, m=%d): %d'):format(
          cck, exp[cck], s, tonumber(what), maxlen, tonumber(ccv[0])
        ))
      end
    end
  end
end

local _itp = itp
itp = function(...)
  collectgarbage('restart')
  _itp(...)
end

describe('vim_str2nr()', function()
  itp('works fine when it has nothing to do', function()
    test_vim_str2nr('', 0, {len = 0, num = 0, unum = 0, pre = 0}, 0)
    test_vim_str2nr('', lib.STR2NR_ALL, {len = 0, num = 0, unum = 0, pre = 0}, 0)
    test_vim_str2nr('', lib.STR2NR_BIN, {len = 0, num = 0, unum = 0, pre = 0}, 0)
    test_vim_str2nr('', lib.STR2NR_OCT, {len = 0, num = 0, unum = 0, pre = 0}, 0)
    test_vim_str2nr('', lib.STR2NR_HEX, {len = 0, num = 0, unum = 0, pre = 0}, 0)
    test_vim_str2nr('', lib.STR2NR_FORCE + lib.STR2NR_DEC, {len = 0, num = 0, unum = 0, pre = 0}, 0)
    test_vim_str2nr('', lib.STR2NR_FORCE + lib.STR2NR_BIN, {len = 0, num = 0, unum = 0, pre = 0}, 0)
    test_vim_str2nr('', lib.STR2NR_FORCE + lib.STR2NR_OCT, {len = 0, num = 0, unum = 0, pre = 0}, 0)
    test_vim_str2nr('', lib.STR2NR_FORCE + lib.STR2NR_HEX, {len = 0, num = 0, unum = 0, pre = 0}, 0)
  end)
  itp('works with decimal numbers', function()
    for _, flags in ipairs({
      0,
      lib.STR2NR_BIN,
      lib.STR2NR_OCT,
      lib.STR2NR_HEX,
      lib.STR2NR_BIN + lib.STR2NR_OCT,
      lib.STR2NR_BIN + lib.STR2NR_HEX,
      lib.STR2NR_OCT + lib.STR2NR_HEX,
      lib.STR2NR_ALL,
      lib.STR2NR_FORCE + lib.STR2NR_DEC,
    }) do
      -- Check that all digits are recognized
      test_vim_str2nr( '12345',  flags, {len = 5, num =  12345, unum = 12345, pre = 0}, 0)
      test_vim_str2nr( '67890',  flags, {len = 5, num =  67890, unum = 67890, pre = 0}, 0)
      test_vim_str2nr( '12345A',  flags, {len = 5, num =  12345, unum = 12345, pre = 0}, 0)
      test_vim_str2nr( '67890A',  flags, {len = 5, num =  67890, unum = 67890, pre = 0}, 0)

      test_vim_str2nr( '42',  flags, {len = 2, num =  42, unum = 42, pre = 0}, 0)
      test_vim_str2nr( '42',  flags, {len = 1, num =   4, unum =  4, pre = 0}, 1)
      test_vim_str2nr( '42',  flags, {len = 2, num =  42, unum = 42, pre = 0}, 2)
      test_vim_str2nr( '42',  flags, {len = 2, num =  42, unum = 42, pre = 0}, 3)  -- includes NUL byte in maxlen

      test_vim_str2nr( '42x', flags, {len = 2, num =  42, unum = 42, pre = 0}, 0)
      test_vim_str2nr( '42x', flags, {len = 2, num =  42, unum = 42, pre = 0}, 3)

      test_vim_str2nr('-42',  flags, {len = 3, num = -42, unum = 42, pre = 0}, 3)
      test_vim_str2nr('-42',  flags, {len = 1, num =   0, unum =  0, pre = 0}, 1)

      test_vim_str2nr('-42x', flags, {len = 3, num = -42, unum = 42, pre = 0}, 0)
      test_vim_str2nr('-42x', flags, {len = 3, num = -42, unum = 42, pre = 0}, 4)
    end
  end)
  itp('works with binary numbers', function()
    for _, flags in ipairs({
      lib.STR2NR_BIN,
      lib.STR2NR_BIN + lib.STR2NR_OCT,
      lib.STR2NR_BIN + lib.STR2NR_HEX,
      lib.STR2NR_ALL,
      lib.STR2NR_FORCE + lib.STR2NR_BIN,
    }) do
      local bin
      local BIN
      if flags > lib.STR2NR_FORCE then
        bin = 0
        BIN = 0
      else
        bin = ('b'):byte()
        BIN = ('B'):byte()
      end

      test_vim_str2nr( '0b101',  flags, {len = 5, num =   5, unum =  5, pre = bin}, 0)
      test_vim_str2nr( '0b101',  flags, {len = 1, num =   0, unum =  0, pre = 0  }, 1)
      test_vim_str2nr( '0b101',  flags, {len = 1, num =   0, unum =  0, pre = 0  }, 2)
      test_vim_str2nr( '0b101',  flags, {len = 3, num =   1, unum =  1, pre = bin}, 3)
      test_vim_str2nr( '0b101',  flags, {len = 4, num =   2, unum =  2, pre = bin}, 4)
      test_vim_str2nr( '0b101',  flags, {len = 5, num =   5, unum =  5, pre = bin}, 5)
      test_vim_str2nr( '0b101',  flags, {len = 5, num =   5, unum =  5, pre = bin}, 6)

      test_vim_str2nr( '0b1012', flags, {len = 5, num =   5, unum =  5, pre = bin}, 0)
      test_vim_str2nr( '0b1012', flags, {len = 5, num =   5, unum =  5, pre = bin}, 6)

      test_vim_str2nr('-0b101',  flags, {len = 6, num =  -5, unum =  5, pre = bin}, 0)
      test_vim_str2nr('-0b101',  flags, {len = 1, num =   0, unum =  0, pre = 0  }, 1)
      test_vim_str2nr('-0b101',  flags, {len = 2, num =   0, unum =  0, pre = 0  }, 2)
      test_vim_str2nr('-0b101',  flags, {len = 2, num =   0, unum =  0, pre = 0  }, 3)
      test_vim_str2nr('-0b101',  flags, {len = 4, num =  -1, unum =  1, pre = bin}, 4)
      test_vim_str2nr('-0b101',  flags, {len = 5, num =  -2, unum =  2, pre = bin}, 5)
      test_vim_str2nr('-0b101',  flags, {len = 6, num =  -5, unum =  5, pre = bin}, 6)
      test_vim_str2nr('-0b101',  flags, {len = 6, num =  -5, unum =  5, pre = bin}, 7)

      test_vim_str2nr('-0b1012', flags, {len = 6, num =  -5, unum =  5, pre = bin}, 0)
      test_vim_str2nr('-0b1012', flags, {len = 6, num =  -5, unum =  5, pre = bin}, 7)

      test_vim_str2nr( '0B101',  flags, {len = 5, num =   5, unum =  5, pre = BIN}, 0)
      test_vim_str2nr( '0B101',  flags, {len = 1, num =   0, unum =  0, pre = 0  }, 1)
      test_vim_str2nr( '0B101',  flags, {len = 1, num =   0, unum =  0, pre = 0  }, 2)
      test_vim_str2nr( '0B101',  flags, {len = 3, num =   1, unum =  1, pre = BIN}, 3)
      test_vim_str2nr( '0B101',  flags, {len = 4, num =   2, unum =  2, pre = BIN}, 4)
      test_vim_str2nr( '0B101',  flags, {len = 5, num =   5, unum =  5, pre = BIN}, 5)
      test_vim_str2nr( '0B101',  flags, {len = 5, num =   5, unum =  5, pre = BIN}, 6)

      test_vim_str2nr( '0B1012', flags, {len = 5, num =   5, unum =  5, pre = BIN}, 0)
      test_vim_str2nr( '0B1012', flags, {len = 5, num =   5, unum =  5, pre = BIN}, 6)

      test_vim_str2nr('-0B101',  flags, {len = 6, num =  -5, unum =  5, pre = BIN}, 0)
      test_vim_str2nr('-0B101',  flags, {len = 1, num =   0, unum =  0, pre = 0  }, 1)
      test_vim_str2nr('-0B101',  flags, {len = 2, num =   0, unum =  0, pre = 0  }, 2)
      test_vim_str2nr('-0B101',  flags, {len = 2, num =   0, unum =  0, pre = 0  }, 3)
      test_vim_str2nr('-0B101',  flags, {len = 4, num =  -1, unum =  1, pre = BIN}, 4)
      test_vim_str2nr('-0B101',  flags, {len = 5, num =  -2, unum =  2, pre = BIN}, 5)
      test_vim_str2nr('-0B101',  flags, {len = 6, num =  -5, unum =  5, pre = BIN}, 6)
      test_vim_str2nr('-0B101',  flags, {len = 6, num =  -5, unum =  5, pre = BIN}, 7)

      test_vim_str2nr('-0B1012', flags, {len = 6, num =  -5, unum =  5, pre = BIN}, 0)
      test_vim_str2nr('-0B1012', flags, {len = 6, num =  -5, unum =  5, pre = BIN}, 7)

      if flags > lib.STR2NR_FORCE then
        test_vim_str2nr('-101', flags, {len = 4, num = -5, unum = 5, pre = 0}, 0)
      end
    end
  end)
  itp('works with octal numbers', function()
    for _, flags in ipairs({
      lib.STR2NR_OCT,
      lib.STR2NR_OCT + lib.STR2NR_BIN,
      lib.STR2NR_OCT + lib.STR2NR_HEX,
      lib.STR2NR_ALL,
      lib.STR2NR_FORCE + lib.STR2NR_OCT,
    }) do
      local oct
      if flags > lib.STR2NR_FORCE then
        oct = 0
      else
        oct = ('0'):byte()
      end

      -- Check that all digits are recognized
      test_vim_str2nr( '012345670', flags, {len = 9, num = 2739128, unum = 2739128, pre = oct}, 0)

      test_vim_str2nr( '054',  flags, {len = 3, num =  44, unum = 44, pre = oct}, 0)
      test_vim_str2nr( '054',  flags, {len = 1, num =   0, unum =  0, pre = 0  }, 1)
      test_vim_str2nr( '054',  flags, {len = 2, num =   5, unum =  5, pre = oct}, 2)
      test_vim_str2nr( '054',  flags, {len = 3, num =  44, unum = 44, pre = oct}, 3)
      test_vim_str2nr( '0548', flags, {len = 3, num =  44, unum = 44, pre = oct}, 3)
      test_vim_str2nr( '054',  flags, {len = 3, num =  44, unum = 44, pre = oct}, 4)

      test_vim_str2nr( '054x', flags, {len = 3, num =  44, unum = 44, pre = oct}, 4)
      test_vim_str2nr( '054x', flags, {len = 3, num =  44, unum = 44, pre = oct}, 0)

      test_vim_str2nr('-054',  flags, {len = 4, num = -44, unum = 44, pre = oct}, 0)
      test_vim_str2nr('-054',  flags, {len = 1, num =   0, unum =  0, pre = 0  }, 1)
      test_vim_str2nr('-054',  flags, {len = 2, num =   0, unum =  0, pre = 0  }, 2)
      test_vim_str2nr('-054',  flags, {len = 3, num =  -5, unum =  5, pre = oct}, 3)
      test_vim_str2nr('-054',  flags, {len = 4, num = -44, unum = 44, pre = oct}, 4)
      test_vim_str2nr('-0548', flags, {len = 4, num = -44, unum = 44, pre = oct}, 4)
      test_vim_str2nr('-054',  flags, {len = 4, num = -44, unum = 44, pre = oct}, 5)

      test_vim_str2nr('-054x', flags, {len = 4, num = -44, unum = 44, pre = oct}, 5)
      test_vim_str2nr('-054x', flags, {len = 4, num = -44, unum = 44, pre = oct}, 0)

      if flags > lib.STR2NR_FORCE then
        test_vim_str2nr('-54', flags, {len = 3, num = -44, unum = 44, pre = 0}, 0)
        test_vim_str2nr('-0548', flags, {len = 4, num = -44, unum = 44, pre = 0}, 5)
        test_vim_str2nr('-0548', flags, {len = 4, num = -44, unum = 44, pre = 0}, 0)
      else
        test_vim_str2nr('-0548', flags, {len = 5, num = -548, unum = 548, pre = 0}, 5)
        test_vim_str2nr('-0548', flags, {len = 5, num = -548, unum = 548, pre = 0}, 0)
      end
    end
  end)
  itp('works with hexadecimal numbers', function()
    for _, flags in ipairs({
      lib.STR2NR_HEX,
      lib.STR2NR_HEX + lib.STR2NR_BIN,
      lib.STR2NR_HEX + lib.STR2NR_OCT,
      lib.STR2NR_ALL,
      lib.STR2NR_FORCE + lib.STR2NR_HEX,
    }) do
      local hex
      local HEX
      if flags > lib.STR2NR_FORCE then
        hex = 0
        HEX = 0
      else
        hex = ('x'):byte()
        HEX = ('X'):byte()
      end

      -- Check that all digits are recognized
      test_vim_str2nr('0x12345', flags, {len = 7, num = 74565, unum = 74565, pre = hex}, 0)
      test_vim_str2nr('0x67890', flags, {len = 7, num = 424080, unum = 424080, pre = hex}, 0)
      test_vim_str2nr('0xABCDEF', flags, {len = 8, num = 11259375, unum = 11259375, pre = hex}, 0)
      test_vim_str2nr('0xabcdef', flags, {len = 8, num = 11259375, unum = 11259375, pre = hex}, 0)

      test_vim_str2nr( '0x101',  flags, {len = 5, num = 257, unum =257, pre = hex}, 0)
      test_vim_str2nr( '0x101',  flags, {len = 1, num =   0, unum =  0, pre = 0  }, 1)
      test_vim_str2nr( '0x101',  flags, {len = 1, num =   0, unum =  0, pre = 0  }, 2)
      test_vim_str2nr( '0x101',  flags, {len = 3, num =   1, unum =  1, pre = hex}, 3)
      test_vim_str2nr( '0x101',  flags, {len = 4, num =  16, unum = 16, pre = hex}, 4)
      test_vim_str2nr( '0x101',  flags, {len = 5, num = 257, unum =257, pre = hex}, 5)
      test_vim_str2nr( '0x101',  flags, {len = 5, num = 257, unum =257, pre = hex}, 6)

      test_vim_str2nr( '0x101G', flags, {len = 5, num = 257, unum =257, pre = hex}, 0)
      test_vim_str2nr( '0x101G', flags, {len = 5, num = 257, unum =257, pre = hex}, 6)

      test_vim_str2nr('-0x101',  flags, {len = 6, num =-257, unum =257, pre = hex}, 0)
      test_vim_str2nr('-0x101',  flags, {len = 1, num =   0, unum =  0, pre = 0  }, 1)
      test_vim_str2nr('-0x101',  flags, {len = 2, num =   0, unum =  0, pre = 0  }, 2)
      test_vim_str2nr('-0x101',  flags, {len = 2, num =   0, unum =  0, pre = 0  }, 3)
      test_vim_str2nr('-0x101',  flags, {len = 4, num =  -1, unum =  1, pre = hex}, 4)
      test_vim_str2nr('-0x101',  flags, {len = 5, num = -16, unum = 16, pre = hex}, 5)
      test_vim_str2nr('-0x101',  flags, {len = 6, num =-257, unum =257, pre = hex}, 6)
      test_vim_str2nr('-0x101',  flags, {len = 6, num =-257, unum =257, pre = hex}, 7)

      test_vim_str2nr('-0x101G', flags, {len = 6, num =-257, unum =257, pre = hex}, 0)
      test_vim_str2nr('-0x101G', flags, {len = 6, num =-257, unum =257, pre = hex}, 7)

      test_vim_str2nr( '0X101',  flags, {len = 5, num = 257, unum =257, pre = HEX}, 0)
      test_vim_str2nr( '0X101',  flags, {len = 1, num =   0, unum =  0, pre = 0  }, 1)
      test_vim_str2nr( '0X101',  flags, {len = 1, num =   0, unum =  0, pre = 0  }, 2)
      test_vim_str2nr( '0X101',  flags, {len = 3, num =   1, unum =  1, pre = HEX}, 3)
      test_vim_str2nr( '0X101',  flags, {len = 4, num =  16, unum = 16, pre = HEX}, 4)
      test_vim_str2nr( '0X101',  flags, {len = 5, num = 257, unum =257, pre = HEX}, 5)
      test_vim_str2nr( '0X101',  flags, {len = 5, num = 257, unum =257, pre = HEX}, 6)

      test_vim_str2nr( '0X101G', flags, {len = 5, num = 257, unum =257, pre = HEX}, 0)
      test_vim_str2nr( '0X101G', flags, {len = 5, num = 257, unum =257, pre = HEX}, 6)

      test_vim_str2nr('-0X101',  flags, {len = 6, num =-257, unum =257, pre = HEX}, 0)
      test_vim_str2nr('-0X101',  flags, {len = 1, num =   0, unum =  0, pre = 0  }, 1)
      test_vim_str2nr('-0X101',  flags, {len = 2, num =   0, unum =  0, pre = 0  }, 2)
      test_vim_str2nr('-0X101',  flags, {len = 2, num =   0, unum =  0, pre = 0  }, 3)
      test_vim_str2nr('-0X101',  flags, {len = 4, num =  -1, unum =  1, pre = HEX}, 4)
      test_vim_str2nr('-0X101',  flags, {len = 5, num = -16, unum = 16, pre = HEX}, 5)
      test_vim_str2nr('-0X101',  flags, {len = 6, num =-257, unum =257, pre = HEX}, 6)
      test_vim_str2nr('-0X101',  flags, {len = 6, num =-257, unum =257, pre = HEX}, 7)

      test_vim_str2nr('-0X101G', flags, {len = 6, num =-257, unum =257, pre = HEX}, 0)
      test_vim_str2nr('-0X101G', flags, {len = 6, num =-257, unum =257, pre = HEX}, 7)

      if flags > lib.STR2NR_FORCE then
        test_vim_str2nr('-101', flags, {len = 4, num = -257, unum = 257, pre = 0}, 0)
      end
    end
  end)
end)
