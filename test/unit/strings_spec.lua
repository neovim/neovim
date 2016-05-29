local helpers = require("test.unit.helpers")

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

  it('precedes by a backslash all chars from second argument', function()
    eq([[\a\b\c\d]], vim_strsave_escaped('abcd','abcd'))
  end)

  it('precedes by a backslash chars only from second argument', function()
    eq([[\a\bcd]], vim_strsave_escaped('abcd','ab'))
  end)

  it('returns a copy of passed string if second argument is empty', function()
    eq('text \n text', vim_strsave_escaped('text \n text',''))
  end)

  it('returns an empty string if first argument is empty string', function()
    eq('', vim_strsave_escaped('','\r'))
  end)

  it('returns a copy of passed string if it does not contain chars from 2nd argument', function()
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

  it('copies unquoted strings as-is', function()
    eq('-c', vim_strnsave_unquoted('-c'))
    eq('', vim_strnsave_unquoted(''))
  end)

  it('respects length argument', function()
    eq('', vim_strnsave_unquoted('-c', 0))
    eq('-', vim_strnsave_unquoted('-c', 1))
    eq('-', vim_strnsave_unquoted('"-c', 2))
  end)

  it('unquotes fully quoted word', function()
    eq('/bin/sh', vim_strnsave_unquoted('"/bin/sh"'))
  end)

  it('unquotes partially quoted word', function()
    eq('/Program Files/sh', vim_strnsave_unquoted('/Program" "Files/sh'))
  end)

  it('removes ""', function()
    eq('/Program Files/sh', vim_strnsave_unquoted('/""Program" "Files/sh'))
  end)

  it('performs unescaping of "', function()
    eq('/"Program Files"/sh', vim_strnsave_unquoted('/"\\""Program Files"\\""/sh'))
  end)

  it('performs unescaping of \\', function()
    eq('/\\Program Files\\foo/sh', vim_strnsave_unquoted('/"\\\\"Program Files"\\\\foo"/sh'))
  end)

  it('strips quote when there is no pair to it', function()
    eq('/Program Files/sh', vim_strnsave_unquoted('/Program" Files/sh'))
    eq('', vim_strnsave_unquoted('"'))
  end)

  it('allows string to end with one backslash unescaped', function()
    eq('/Program Files/sh\\', vim_strnsave_unquoted('/Program" Files/sh\\'))
  end)

  it('does not perform unescaping out of quotes', function()
    eq('/Program\\ Files/sh\\', vim_strnsave_unquoted('/Program\\ Files/sh\\'))
  end)

  it('does not unescape \\n', function()
    eq('/Program\\nFiles/sh', vim_strnsave_unquoted('/Program"\\n"Files/sh'))
  end)
end)
