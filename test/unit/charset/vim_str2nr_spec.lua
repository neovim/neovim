local t = require('test.unit.testutil')(after_each)
local bit = require('bit')

local itp = t.gen_itp(it)

local child_call_once = t.child_call_once
local cimport = t.cimport
local ffi = t.ffi

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
    return ARGTYPES[arg]({ ucnt })
  else
    icnt = icnt - 1
    return ARGTYPES[arg]({ icnt })
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

local function test_vim_str2nr(s, what, exp, maxlen, strict)
  if strict == nil then
    strict = true
  end
  local bits = {}
  for k, _ in pairs(exp) do
    bits[#bits + 1] = k
  end
  maxlen = maxlen or #s
  local args = {}
  for k, _ in pairs(ARGTYPES) do
    args[k] = arginit(k)
  end
  for case = 0, ((2 ^ #bits) - 1) do
    local cv = {}
    for b = 0, (#bits - 1) do
      if bit.band(case, (2 ^ b)) == 0 then
        local k = bits[b + 1]
        argreset(k, args)
        cv[k] = args[k]
      end
    end
    lib.vim_str2nr(s, cv.pre, cv.len, what, cv.num, cv.unum, maxlen, strict, nil)
    for cck, ccv in pairs(cv) do
      if exp[cck] ~= tonumber(ccv[0]) then
        error(
          ('Failed check (%s = %d) in test (s=%s, w=%u, m=%d, strict=%s): %d'):format(
            cck,
            exp[cck],
            s,
            tonumber(what),
            maxlen,
            tostring(strict),
            tonumber(ccv[0])
          )
        )
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
    test_vim_str2nr('', 0, { len = 0, num = 0, unum = 0, pre = 0 }, 0)
    test_vim_str2nr('', lib.STR2NR_ALL, { len = 0, num = 0, unum = 0, pre = 0 }, 0)
    test_vim_str2nr('', lib.STR2NR_BIN, { len = 0, num = 0, unum = 0, pre = 0 }, 0)
    test_vim_str2nr('', lib.STR2NR_OCT, { len = 0, num = 0, unum = 0, pre = 0 }, 0)
    test_vim_str2nr('', lib.STR2NR_OOCT, { len = 0, num = 0, unum = 0, pre = 0 }, 0)
    test_vim_str2nr('', lib.STR2NR_HEX, { len = 0, num = 0, unum = 0, pre = 0 }, 0)
    test_vim_str2nr(
      '',
      lib.STR2NR_FORCE + lib.STR2NR_DEC,
      { len = 0, num = 0, unum = 0, pre = 0 },
      0
    )
    test_vim_str2nr(
      '',
      lib.STR2NR_FORCE + lib.STR2NR_BIN,
      { len = 0, num = 0, unum = 0, pre = 0 },
      0
    )
    test_vim_str2nr(
      '',
      lib.STR2NR_FORCE + lib.STR2NR_OCT,
      { len = 0, num = 0, unum = 0, pre = 0 },
      0
    )
    test_vim_str2nr(
      '',
      lib.STR2NR_FORCE + lib.STR2NR_OOCT,
      { len = 0, num = 0, unum = 0, pre = 0 },
      0
    )
    test_vim_str2nr(
      '',
      lib.STR2NR_FORCE + lib.STR2NR_OCT + lib.STR2NR_OOCT,
      { len = 0, num = 0, unum = 0, pre = 0 },
      0
    )
    test_vim_str2nr(
      '',
      lib.STR2NR_FORCE + lib.STR2NR_HEX,
      { len = 0, num = 0, unum = 0, pre = 0 },
      0
    )
  end)
  itp('works with decimal numbers', function()
    for _, flags in ipairs({
      0,
      lib.STR2NR_BIN,
      lib.STR2NR_OCT,
      lib.STR2NR_HEX,
      lib.STR2NR_OOCT,
      lib.STR2NR_BIN + lib.STR2NR_OCT,
      lib.STR2NR_BIN + lib.STR2NR_HEX,
      lib.STR2NR_OCT + lib.STR2NR_HEX,
      lib.STR2NR_OOCT + lib.STR2NR_HEX,
      lib.STR2NR_ALL,
      lib.STR2NR_FORCE + lib.STR2NR_DEC,
    }) do
      -- Check that all digits are recognized
      test_vim_str2nr('12345', flags, { len = 5, num = 12345, unum = 12345, pre = 0 }, 0)
      test_vim_str2nr('67890', flags, { len = 5, num = 67890, unum = 67890, pre = 0 }, 0)
      test_vim_str2nr('12345A', flags, { len = 0 }, 0)
      test_vim_str2nr('67890A', flags, { len = 0 }, 0)
      test_vim_str2nr('12345A', flags, { len = 5, num = 12345, unum = 12345, pre = 0 }, 0, false)
      test_vim_str2nr('67890A', flags, { len = 5, num = 67890, unum = 67890, pre = 0 }, 0, false)

      test_vim_str2nr('42', flags, { len = 2, num = 42, unum = 42, pre = 0 }, 0)
      test_vim_str2nr('42', flags, { len = 1, num = 4, unum = 4, pre = 0 }, 1)
      test_vim_str2nr('42', flags, { len = 2, num = 42, unum = 42, pre = 0 }, 2)
      test_vim_str2nr('42', flags, { len = 2, num = 42, unum = 42, pre = 0 }, 3) -- includes NUL byte in maxlen

      test_vim_str2nr('42x', flags, { len = 0 }, 0)
      test_vim_str2nr('42x', flags, { len = 0 }, 3)
      test_vim_str2nr('42x', flags, { len = 2, num = 42, unum = 42, pre = 0 }, 0, false)
      test_vim_str2nr('42x', flags, { len = 2, num = 42, unum = 42, pre = 0 }, 3, false)

      test_vim_str2nr('-42', flags, { len = 3, num = -42, unum = 42, pre = 0 }, 3)
      test_vim_str2nr('-42', flags, { len = 1, num = 0, unum = 0, pre = 0 }, 1)

      test_vim_str2nr('-42x', flags, { len = 0 }, 0)
      test_vim_str2nr('-42x', flags, { len = 0 }, 4)
      test_vim_str2nr('-42x', flags, { len = 3, num = -42, unum = 42, pre = 0 }, 0, false)
      test_vim_str2nr('-42x', flags, { len = 3, num = -42, unum = 42, pre = 0 }, 4, false)
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

      test_vim_str2nr('0b101', flags, { len = 5, num = 5, unum = 5, pre = bin }, 0)
      test_vim_str2nr('0b101', flags, { len = 1, num = 0, unum = 0, pre = 0 }, 1)
      test_vim_str2nr('0b101', flags, { len = 0 }, 2)
      test_vim_str2nr('0b101', flags, { len = 1, num = 0, unum = 0, pre = 0 }, 2, false)
      test_vim_str2nr('0b101', flags, { len = 3, num = 1, unum = 1, pre = bin }, 3)
      test_vim_str2nr('0b101', flags, { len = 4, num = 2, unum = 2, pre = bin }, 4)
      test_vim_str2nr('0b101', flags, { len = 5, num = 5, unum = 5, pre = bin }, 5)
      test_vim_str2nr('0b101', flags, { len = 5, num = 5, unum = 5, pre = bin }, 6)

      test_vim_str2nr('0b1012', flags, { len = 0 }, 0)
      test_vim_str2nr('0b1012', flags, { len = 0 }, 6)
      test_vim_str2nr('0b1012', flags, { len = 5, num = 5, unum = 5, pre = bin }, 0, false)
      test_vim_str2nr('0b1012', flags, { len = 5, num = 5, unum = 5, pre = bin }, 6, false)

      test_vim_str2nr('-0b101', flags, { len = 6, num = -5, unum = 5, pre = bin }, 0)
      test_vim_str2nr('-0b101', flags, { len = 1, num = 0, unum = 0, pre = 0 }, 1)
      test_vim_str2nr('-0b101', flags, { len = 2, num = 0, unum = 0, pre = 0 }, 2)
      test_vim_str2nr('-0b101', flags, { len = 0 }, 3)
      test_vim_str2nr('-0b101', flags, { len = 2, num = 0, unum = 0, pre = 0 }, 3, false)
      test_vim_str2nr('-0b101', flags, { len = 4, num = -1, unum = 1, pre = bin }, 4)
      test_vim_str2nr('-0b101', flags, { len = 5, num = -2, unum = 2, pre = bin }, 5)
      test_vim_str2nr('-0b101', flags, { len = 6, num = -5, unum = 5, pre = bin }, 6)
      test_vim_str2nr('-0b101', flags, { len = 6, num = -5, unum = 5, pre = bin }, 7)

      test_vim_str2nr('-0b1012', flags, { len = 0 }, 0)
      test_vim_str2nr('-0b1012', flags, { len = 0 }, 7)
      test_vim_str2nr('-0b1012', flags, { len = 6, num = -5, unum = 5, pre = bin }, 0, false)
      test_vim_str2nr('-0b1012', flags, { len = 6, num = -5, unum = 5, pre = bin }, 7, false)

      test_vim_str2nr('0B101', flags, { len = 5, num = 5, unum = 5, pre = BIN }, 0)
      test_vim_str2nr('0B101', flags, { len = 1, num = 0, unum = 0, pre = 0 }, 1)
      test_vim_str2nr('0B101', flags, { len = 0 }, 2)
      test_vim_str2nr('0B101', flags, { len = 1, num = 0, unum = 0, pre = 0 }, 2, false)
      test_vim_str2nr('0B101', flags, { len = 3, num = 1, unum = 1, pre = BIN }, 3)
      test_vim_str2nr('0B101', flags, { len = 4, num = 2, unum = 2, pre = BIN }, 4)
      test_vim_str2nr('0B101', flags, { len = 5, num = 5, unum = 5, pre = BIN }, 5)
      test_vim_str2nr('0B101', flags, { len = 5, num = 5, unum = 5, pre = BIN }, 6)

      test_vim_str2nr('0B1012', flags, { len = 0 }, 0)
      test_vim_str2nr('0B1012', flags, { len = 0 }, 6)
      test_vim_str2nr('0B1012', flags, { len = 5, num = 5, unum = 5, pre = BIN }, 0, false)
      test_vim_str2nr('0B1012', flags, { len = 5, num = 5, unum = 5, pre = BIN }, 6, false)

      test_vim_str2nr('-0B101', flags, { len = 6, num = -5, unum = 5, pre = BIN }, 0)
      test_vim_str2nr('-0B101', flags, { len = 1, num = 0, unum = 0, pre = 0 }, 1)
      test_vim_str2nr('-0B101', flags, { len = 2, num = 0, unum = 0, pre = 0 }, 2)
      test_vim_str2nr('-0B101', flags, { len = 0 }, 3)
      test_vim_str2nr('-0B101', flags, { len = 2, num = 0, unum = 0, pre = 0 }, 3, false)
      test_vim_str2nr('-0B101', flags, { len = 4, num = -1, unum = 1, pre = BIN }, 4)
      test_vim_str2nr('-0B101', flags, { len = 5, num = -2, unum = 2, pre = BIN }, 5)
      test_vim_str2nr('-0B101', flags, { len = 6, num = -5, unum = 5, pre = BIN }, 6)
      test_vim_str2nr('-0B101', flags, { len = 6, num = -5, unum = 5, pre = BIN }, 7)

      test_vim_str2nr('-0B1012', flags, { len = 0 }, 0)
      test_vim_str2nr('-0B1012', flags, { len = 0 }, 7)
      test_vim_str2nr('-0B1012', flags, { len = 6, num = -5, unum = 5, pre = BIN }, 0, false)
      test_vim_str2nr('-0B1012', flags, { len = 6, num = -5, unum = 5, pre = BIN }, 7, false)

      if flags > lib.STR2NR_FORCE then
        test_vim_str2nr('-101', flags, { len = 4, num = -5, unum = 5, pre = 0 }, 0)
      end
    end
  end)
  itp('works with octal numbers (0 prefix)', function()
    for _, flags in ipairs({
      lib.STR2NR_OCT,
      lib.STR2NR_OCT + lib.STR2NR_BIN,
      lib.STR2NR_OCT + lib.STR2NR_HEX,
      lib.STR2NR_OCT + lib.STR2NR_OOCT,
      lib.STR2NR_ALL,
      lib.STR2NR_FORCE + lib.STR2NR_OCT,
      lib.STR2NR_FORCE + lib.STR2NR_OOCT,
      lib.STR2NR_FORCE + lib.STR2NR_OCT + lib.STR2NR_OOCT,
    }) do
      local oct
      if flags > lib.STR2NR_FORCE then
        oct = 0
      else
        oct = ('0'):byte()
      end

      -- Check that all digits are recognized
      test_vim_str2nr('012345670', flags, { len = 9, num = 2739128, unum = 2739128, pre = oct }, 0)

      test_vim_str2nr('054', flags, { len = 3, num = 44, unum = 44, pre = oct }, 0)
      test_vim_str2nr('054', flags, { len = 1, num = 0, unum = 0, pre = 0 }, 1)
      test_vim_str2nr('054', flags, { len = 2, num = 5, unum = 5, pre = oct }, 2)
      test_vim_str2nr('054', flags, { len = 3, num = 44, unum = 44, pre = oct }, 3)
      test_vim_str2nr('0548', flags, { len = 3, num = 44, unum = 44, pre = oct }, 3)
      test_vim_str2nr('054', flags, { len = 3, num = 44, unum = 44, pre = oct }, 4)

      test_vim_str2nr('054x', flags, { len = 0 }, 4)
      test_vim_str2nr('054x', flags, { len = 0 }, 0)
      test_vim_str2nr('054x', flags, { len = 3, num = 44, unum = 44, pre = oct }, 4, false)
      test_vim_str2nr('054x', flags, { len = 3, num = 44, unum = 44, pre = oct }, 0, false)

      test_vim_str2nr('-054', flags, { len = 4, num = -44, unum = 44, pre = oct }, 0)
      test_vim_str2nr('-054', flags, { len = 1, num = 0, unum = 0, pre = 0 }, 1)
      test_vim_str2nr('-054', flags, { len = 2, num = 0, unum = 0, pre = 0 }, 2)
      test_vim_str2nr('-054', flags, { len = 3, num = -5, unum = 5, pre = oct }, 3)
      test_vim_str2nr('-054', flags, { len = 4, num = -44, unum = 44, pre = oct }, 4)
      test_vim_str2nr('-0548', flags, { len = 4, num = -44, unum = 44, pre = oct }, 4)
      test_vim_str2nr('-054', flags, { len = 4, num = -44, unum = 44, pre = oct }, 5)

      test_vim_str2nr('-054x', flags, { len = 0 }, 5)
      test_vim_str2nr('-054x', flags, { len = 0 }, 0)
      test_vim_str2nr('-054x', flags, { len = 4, num = -44, unum = 44, pre = oct }, 5, false)
      test_vim_str2nr('-054x', flags, { len = 4, num = -44, unum = 44, pre = oct }, 0, false)

      if flags > lib.STR2NR_FORCE then
        test_vim_str2nr('-54', flags, { len = 3, num = -44, unum = 44, pre = 0 }, 0)
        test_vim_str2nr('-0548', flags, { len = 0 }, 5)
        test_vim_str2nr('-0548', flags, { len = 0 }, 0)
        test_vim_str2nr('-0548', flags, { len = 4, num = -44, unum = 44, pre = 0 }, 5, false)
        test_vim_str2nr('-0548', flags, { len = 4, num = -44, unum = 44, pre = 0 }, 0, false)
      else
        test_vim_str2nr('-0548', flags, { len = 5, num = -548, unum = 548, pre = 0 }, 5)
        test_vim_str2nr('-0548', flags, { len = 5, num = -548, unum = 548, pre = 0 }, 0)
      end
    end
  end)
  itp('works with octal numbers (0o or 0O prefix)', function()
    for _, flags in ipairs({
      lib.STR2NR_OOCT,
      lib.STR2NR_OOCT + lib.STR2NR_BIN,
      lib.STR2NR_OOCT + lib.STR2NR_HEX,
      lib.STR2NR_OCT + lib.STR2NR_OOCT,
      lib.STR2NR_OCT + lib.STR2NR_OOCT + lib.STR2NR_BIN,
      lib.STR2NR_OCT + lib.STR2NR_OOCT + lib.STR2NR_HEX,
      lib.STR2NR_ALL,
      lib.STR2NR_FORCE + lib.STR2NR_OCT,
      lib.STR2NR_FORCE + lib.STR2NR_OOCT,
      lib.STR2NR_FORCE + lib.STR2NR_OCT + lib.STR2NR_OOCT,
    }) do
      local oct
      local OCT
      if flags > lib.STR2NR_FORCE then
        oct = 0
        OCT = 0
      else
        oct = ('o'):byte()
        OCT = ('O'):byte()
      end

      test_vim_str2nr('0o054', flags, { len = 5, num = 44, unum = 44, pre = oct }, 0)
      test_vim_str2nr('0o054', flags, { len = 1, num = 0, unum = 0, pre = 0 }, 1)
      test_vim_str2nr('0o054', flags, { len = 0 }, 2)
      test_vim_str2nr('0o054', flags, { len = 3, num = 0, unum = 0, pre = oct }, 3)
      test_vim_str2nr('0o054', flags, { len = 4, num = 5, unum = 5, pre = oct }, 4)
      test_vim_str2nr('0o054', flags, { len = 5, num = 44, unum = 44, pre = oct }, 5)
      test_vim_str2nr('0o0548', flags, { len = 5, num = 44, unum = 44, pre = oct }, 5)
      test_vim_str2nr('0o054', flags, { len = 5, num = 44, unum = 44, pre = oct }, 6)

      test_vim_str2nr('0o054x', flags, { len = 0 }, 6)
      test_vim_str2nr('0o054x', flags, { len = 0 }, 0)
      test_vim_str2nr('0o054x', flags, { len = 5, num = 44, unum = 44, pre = oct }, 6, false)
      test_vim_str2nr('0o054x', flags, { len = 5, num = 44, unum = 44, pre = oct }, 0, false)

      test_vim_str2nr('-0o054', flags, { len = 6, num = -44, unum = 44, pre = oct }, 0)
      test_vim_str2nr('-0o054', flags, { len = 1, num = 0, unum = 0, pre = 0 }, 1)
      test_vim_str2nr('-0o054', flags, { len = 2, num = 0, unum = 0, pre = 0 }, 2)
      test_vim_str2nr('-0o054', flags, { len = 0 }, 3)
      test_vim_str2nr('-0o054', flags, { len = 4, num = 0, unum = 0, pre = oct }, 4)
      test_vim_str2nr('-0o054', flags, { len = 5, num = -5, unum = 5, pre = oct }, 5)
      test_vim_str2nr('-0o054', flags, { len = 6, num = -44, unum = 44, pre = oct }, 6)
      test_vim_str2nr('-0o0548', flags, { len = 6, num = -44, unum = 44, pre = oct }, 6)
      test_vim_str2nr('-0o054', flags, { len = 6, num = -44, unum = 44, pre = oct }, 7)

      test_vim_str2nr('-0o054x', flags, { len = 0 }, 7)
      test_vim_str2nr('-0o054x', flags, { len = 0 }, 0)
      test_vim_str2nr('-0o054x', flags, { len = 6, num = -44, unum = 44, pre = oct }, 7, false)
      test_vim_str2nr('-0o054x', flags, { len = 6, num = -44, unum = 44, pre = oct }, 0, false)

      test_vim_str2nr('0O054', flags, { len = 5, num = 44, unum = 44, pre = OCT }, 0)
      test_vim_str2nr('0O054', flags, { len = 1, num = 0, unum = 0, pre = 0 }, 1)
      test_vim_str2nr('0O054', flags, { len = 0 }, 2)
      test_vim_str2nr('0O054', flags, { len = 3, num = 0, unum = 0, pre = OCT }, 3)
      test_vim_str2nr('0O054', flags, { len = 4, num = 5, unum = 5, pre = OCT }, 4)
      test_vim_str2nr('0O054', flags, { len = 5, num = 44, unum = 44, pre = OCT }, 5)
      test_vim_str2nr('0O0548', flags, { len = 5, num = 44, unum = 44, pre = OCT }, 5)
      test_vim_str2nr('0O054', flags, { len = 5, num = 44, unum = 44, pre = OCT }, 6)

      test_vim_str2nr('0O054x', flags, { len = 0 }, 6)
      test_vim_str2nr('0O054x', flags, { len = 0 }, 0)
      test_vim_str2nr('0O054x', flags, { len = 5, num = 44, unum = 44, pre = OCT }, 6, false)
      test_vim_str2nr('0O054x', flags, { len = 5, num = 44, unum = 44, pre = OCT }, 0, false)

      test_vim_str2nr('-0O054', flags, { len = 6, num = -44, unum = 44, pre = OCT }, 0)
      test_vim_str2nr('-0O054', flags, { len = 1, num = 0, unum = 0, pre = 0 }, 1)
      test_vim_str2nr('-0O054', flags, { len = 2, num = 0, unum = 0, pre = 0 }, 2)
      test_vim_str2nr('-0O054', flags, { len = 0 }, 3)
      test_vim_str2nr('-0O054', flags, { len = 4, num = 0, unum = 0, pre = OCT }, 4)
      test_vim_str2nr('-0O054', flags, { len = 5, num = -5, unum = 5, pre = OCT }, 5)
      test_vim_str2nr('-0O054', flags, { len = 6, num = -44, unum = 44, pre = OCT }, 6)
      test_vim_str2nr('-0O0548', flags, { len = 6, num = -44, unum = 44, pre = OCT }, 6)
      test_vim_str2nr('-0O054', flags, { len = 6, num = -44, unum = 44, pre = OCT }, 7)

      test_vim_str2nr('-0O054x', flags, { len = 0 }, 7)
      test_vim_str2nr('-0O054x', flags, { len = 0 }, 0)
      test_vim_str2nr('-0O054x', flags, { len = 6, num = -44, unum = 44, pre = OCT }, 7, false)
      test_vim_str2nr('-0O054x', flags, { len = 6, num = -44, unum = 44, pre = OCT }, 0, false)

      if flags > lib.STR2NR_FORCE then
        test_vim_str2nr('-0548', flags, { len = 0 }, 5)
        test_vim_str2nr('-0548', flags, { len = 0 }, 0)
        test_vim_str2nr('-0548', flags, { len = 4, num = -44, unum = 44, pre = 0 }, 5, false)
        test_vim_str2nr('-0548', flags, { len = 4, num = -44, unum = 44, pre = 0 }, 0, false)
        test_vim_str2nr('-055', flags, { len = 4, num = -45, unum = 45, pre = 0 }, 0)
      else
        test_vim_str2nr('-0548', flags, { len = 5, num = -548, unum = 548, pre = 0 }, 5)
        test_vim_str2nr('-0548', flags, { len = 5, num = -548, unum = 548, pre = 0 }, 0)
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
      test_vim_str2nr('0x12345', flags, { len = 7, num = 74565, unum = 74565, pre = hex }, 0)
      test_vim_str2nr('0x67890', flags, { len = 7, num = 424080, unum = 424080, pre = hex }, 0)
      test_vim_str2nr('0xABCDEF', flags, { len = 8, num = 11259375, unum = 11259375, pre = hex }, 0)
      test_vim_str2nr('0xabcdef', flags, { len = 8, num = 11259375, unum = 11259375, pre = hex }, 0)

      test_vim_str2nr('0x101', flags, { len = 5, num = 257, unum = 257, pre = hex }, 0)
      test_vim_str2nr('0x101', flags, { len = 1, num = 0, unum = 0, pre = 0 }, 1)
      test_vim_str2nr('0x101', flags, { len = 0 }, 2)
      test_vim_str2nr('0x101', flags, { len = 1, num = 0, unum = 0, pre = 0 }, 2, false)
      test_vim_str2nr('0x101', flags, { len = 3, num = 1, unum = 1, pre = hex }, 3)
      test_vim_str2nr('0x101', flags, { len = 4, num = 16, unum = 16, pre = hex }, 4)
      test_vim_str2nr('0x101', flags, { len = 5, num = 257, unum = 257, pre = hex }, 5)
      test_vim_str2nr('0x101', flags, { len = 5, num = 257, unum = 257, pre = hex }, 6)

      test_vim_str2nr('0x101G', flags, { len = 0 }, 0)
      test_vim_str2nr('0x101G', flags, { len = 0 }, 6)
      test_vim_str2nr('0x101G', flags, { len = 5, num = 257, unum = 257, pre = hex }, 0, false)
      test_vim_str2nr('0x101G', flags, { len = 5, num = 257, unum = 257, pre = hex }, 6, false)

      test_vim_str2nr('-0x101', flags, { len = 6, num = -257, unum = 257, pre = hex }, 0)
      test_vim_str2nr('-0x101', flags, { len = 1, num = 0, unum = 0, pre = 0 }, 1)
      test_vim_str2nr('-0x101', flags, { len = 2, num = 0, unum = 0, pre = 0 }, 2)
      test_vim_str2nr('-0x101', flags, { len = 0 }, 3)
      test_vim_str2nr('-0x101', flags, { len = 2, num = 0, unum = 0, pre = 0 }, 3, false)
      test_vim_str2nr('-0x101', flags, { len = 4, num = -1, unum = 1, pre = hex }, 4)
      test_vim_str2nr('-0x101', flags, { len = 5, num = -16, unum = 16, pre = hex }, 5)
      test_vim_str2nr('-0x101', flags, { len = 6, num = -257, unum = 257, pre = hex }, 6)
      test_vim_str2nr('-0x101', flags, { len = 6, num = -257, unum = 257, pre = hex }, 7)

      test_vim_str2nr('-0x101G', flags, { len = 0 }, 0)
      test_vim_str2nr('-0x101G', flags, { len = 0 }, 7)
      test_vim_str2nr('-0x101G', flags, { len = 6, num = -257, unum = 257, pre = hex }, 0, false)
      test_vim_str2nr('-0x101G', flags, { len = 6, num = -257, unum = 257, pre = hex }, 7, false)

      test_vim_str2nr('0X101', flags, { len = 5, num = 257, unum = 257, pre = HEX }, 0)
      test_vim_str2nr('0X101', flags, { len = 1, num = 0, unum = 0, pre = 0 }, 1)
      test_vim_str2nr('0X101', flags, { len = 0 }, 2)
      test_vim_str2nr('0X101', flags, { len = 1, num = 0, unum = 0, pre = 0 }, 2, false)
      test_vim_str2nr('0X101', flags, { len = 3, num = 1, unum = 1, pre = HEX }, 3)
      test_vim_str2nr('0X101', flags, { len = 4, num = 16, unum = 16, pre = HEX }, 4)
      test_vim_str2nr('0X101', flags, { len = 5, num = 257, unum = 257, pre = HEX }, 5)
      test_vim_str2nr('0X101', flags, { len = 5, num = 257, unum = 257, pre = HEX }, 6)

      test_vim_str2nr('0X101G', flags, { len = 0 }, 0)
      test_vim_str2nr('0X101G', flags, { len = 0 }, 6)
      test_vim_str2nr('0X101G', flags, { len = 5, num = 257, unum = 257, pre = HEX }, 0, false)
      test_vim_str2nr('0X101G', flags, { len = 5, num = 257, unum = 257, pre = HEX }, 6, false)

      test_vim_str2nr('-0X101', flags, { len = 6, num = -257, unum = 257, pre = HEX }, 0)
      test_vim_str2nr('-0X101', flags, { len = 1, num = 0, unum = 0, pre = 0 }, 1)
      test_vim_str2nr('-0X101', flags, { len = 2, num = 0, unum = 0, pre = 0 }, 2)
      test_vim_str2nr('-0X101', flags, { len = 0 }, 3)
      test_vim_str2nr('-0X101', flags, { len = 2, num = 0, unum = 0, pre = 0 }, 3, false)
      test_vim_str2nr('-0X101', flags, { len = 4, num = -1, unum = 1, pre = HEX }, 4)
      test_vim_str2nr('-0X101', flags, { len = 5, num = -16, unum = 16, pre = HEX }, 5)
      test_vim_str2nr('-0X101', flags, { len = 6, num = -257, unum = 257, pre = HEX }, 6)
      test_vim_str2nr('-0X101', flags, { len = 6, num = -257, unum = 257, pre = HEX }, 7)

      test_vim_str2nr('-0X101G', flags, { len = 0 }, 0)
      test_vim_str2nr('-0X101G', flags, { len = 0 }, 7)
      test_vim_str2nr('-0X101G', flags, { len = 6, num = -257, unum = 257, pre = HEX }, 0, false)
      test_vim_str2nr('-0X101G', flags, { len = 6, num = -257, unum = 257, pre = HEX }, 7, false)

      if flags > lib.STR2NR_FORCE then
        test_vim_str2nr('-101', flags, { len = 4, num = -257, unum = 257, pre = 0 }, 0)
      end
    end
  end)
  -- Test_str2nr() in test_functions.vim already tests normal usage
  itp('works with weirdly quoted numbers', function()
    local flags = lib.STR2NR_DEC + lib.STR2NR_QUOTE
    test_vim_str2nr("'027", flags, { len = 0 }, 0)
    test_vim_str2nr("'027", flags, { len = 0 }, 0, false)
    test_vim_str2nr("1'2'3'4", flags, { len = 7, num = 1234, unum = 1234, pre = 0 }, 0)

    -- counter-intuitive, but like Vim, strict=true should partially accept
    -- these: (' and - are not alphanumeric)
    test_vim_str2nr("7''331", flags, { len = 1, num = 7, unum = 7, pre = 0 }, 0)
    test_vim_str2nr("123'x4", flags, { len = 3, num = 123, unum = 123, pre = 0 }, 0)
    test_vim_str2nr("1337'", flags, { len = 4, num = 1337, unum = 1337, pre = 0 }, 0)
    test_vim_str2nr("-'", flags, { len = 1, num = 0, unum = 0, pre = 0 }, 0)

    flags = lib.STR2NR_HEX + lib.STR2NR_QUOTE
    local hex = ('x'):byte()
    test_vim_str2nr("0x'abcd", flags, { len = 0 }, 0)
    test_vim_str2nr("0x'abcd", flags, { len = 1, num = 0, unum = 0, pre = 0 }, 0, false)
    test_vim_str2nr("0xab''cd", flags, { len = 4, num = 171, unum = 171, pre = hex }, 0)
  end)
end)
