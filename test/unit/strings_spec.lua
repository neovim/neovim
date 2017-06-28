local helpers = require("test.unit.helpers")(after_each)
local itp = helpers.gen_itp(it)

local cimport = helpers.cimport
local eq = helpers.eq
local ffi = helpers.ffi
local to_cstr = helpers.to_cstr

local strings = cimport('stdlib.h', './src/nvim/strings.h',
                        './src/nvim/memory.h')

describe('vim_strsave_escaped()', function()
  local vim_strsave_escaped = function(s, chars)
    local res = strings.vim_strsave_escaped(to_cstr(s), to_cstr(chars))
    local ret = ffi.string(res)

    -- Explicitly free memory so we are sure it is allocated: if it was not it
    -- will crash.
    strings.xfree(res)
    return ret
  end

  itp('precedes by a backslash all chars from second argument', function()
    eq([[\a\b\c\d]], vim_strsave_escaped('abcd','abcd'))
  end)

  itp('precedes by a backslash chars only from second argument', function()
    eq([[\a\bcd]], vim_strsave_escaped('abcd','ab'))
  end)

  itp('returns a copy of passed string if second argument is empty', function()
    eq('text \n text', vim_strsave_escaped('text \n text',''))
  end)

  itp('returns an empty string if first argument is empty string', function()
    eq('', vim_strsave_escaped('','\r'))
  end)

  itp('returns a copy of passed string if it does not contain chars from 2nd argument', function()
    eq('some text', vim_strsave_escaped('some text', 'a'))
  end)
end)

describe('vim_strnsave_unquoted()', function()
  local vim_strnsave_unquoted = function(s, len)
    local res = strings.vim_strnsave_unquoted(to_cstr(s), len or #s)
    local ret = ffi.string(res)
    -- Explicitly free memory so we are sure it is allocated: if it was not it
    -- will crash.
    strings.xfree(res)
    return ret
  end

  itp('copies unquoted strings as-is', function()
    eq('-c', vim_strnsave_unquoted('-c'))
    eq('', vim_strnsave_unquoted(''))
  end)

  itp('respects length argument', function()
    eq('', vim_strnsave_unquoted('-c', 0))
    eq('-', vim_strnsave_unquoted('-c', 1))
    eq('-', vim_strnsave_unquoted('"-c', 2))
  end)

  itp('unquotes fully quoted word', function()
    eq('/bin/sh', vim_strnsave_unquoted('"/bin/sh"'))
  end)

  itp('unquotes partially quoted word', function()
    eq('/Program Files/sh', vim_strnsave_unquoted('/Program" "Files/sh'))
  end)

  itp('removes ""', function()
    eq('/Program Files/sh', vim_strnsave_unquoted('/""Program" "Files/sh'))
  end)

  itp('performs unescaping of "', function()
    eq('/"Program Files"/sh', vim_strnsave_unquoted('/"\\""Program Files"\\""/sh'))
  end)

  itp('performs unescaping of \\', function()
    eq('/\\Program Files\\foo/sh', vim_strnsave_unquoted('/"\\\\"Program Files"\\\\foo"/sh'))
  end)

  itp('strips quote when there is no pair to it', function()
    eq('/Program Files/sh', vim_strnsave_unquoted('/Program" Files/sh'))
    eq('', vim_strnsave_unquoted('"'))
  end)

  itp('allows string to end with one backslash unescaped', function()
    eq('/Program Files/sh\\', vim_strnsave_unquoted('/Program" Files/sh\\'))
  end)

  itp('does not perform unescaping out of quotes', function()
    eq('/Program\\ Files/sh\\', vim_strnsave_unquoted('/Program\\ Files/sh\\'))
  end)

  itp('does not unescape \\n', function()
    eq('/Program\\nFiles/sh', vim_strnsave_unquoted('/Program"\\n"Files/sh'))
  end)
end)

describe('vim_strchr()', function()
  local vim_strchr = function(s, c)
    local str = to_cstr(s)
    local res = strings.vim_strchr(str, c)
    if res == nil then
      return nil
    else
      return res - str
    end
  end
  itp('handles NUL and <0 correctly', function()
    eq(nil, vim_strchr('abc', 0))
    eq(nil, vim_strchr('abc', -1))
  end)
  itp('works', function()
    eq(0, vim_strchr('abc', ('a'):byte()))
    eq(1, vim_strchr('abc', ('b'):byte()))
    eq(2, vim_strchr('abc', ('c'):byte()))
    eq(0, vim_strchr('a«b»c', ('a'):byte()))
    eq(3, vim_strchr('a«b»c', ('b'):byte()))
    eq(6, vim_strchr('a«b»c', ('c'):byte()))

    eq(nil, vim_strchr('«»', ('«'):byte()))
    -- 0xAB == 171 == '«'
    eq(nil, vim_strchr('\171', 0xAB))
    eq(0, vim_strchr('«»', 0xAB))
    eq(3, vim_strchr('„«»“', 0xAB))

    eq(7, vim_strchr('„«»“', 0x201C))
    eq(nil, vim_strchr('„«»“', 0x201D))
    eq(0, vim_strchr('„«»“', 0x201E))

    eq(0, vim_strchr('\244\143\188\128', 0x10FF00))
    eq(2, vim_strchr('«\244\143\188\128»', 0x10FF00))
    --                   |0xDBFF     |0xDF00  - surrogate pair for 0x10FF00
    eq(nil, vim_strchr('«\237\175\191\237\188\128»', 0x10FF00))
  end)
end)
