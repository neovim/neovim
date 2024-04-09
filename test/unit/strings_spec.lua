local t = require('test.unit.testutil')
local itp = t.gen_itp(it)

local cimport = t.cimport
local eq = t.eq
local ffi = t.ffi
local to_cstr = t.to_cstr

local strings = cimport('stdlib.h', './src/nvim/strings.h', './src/nvim/memory.h')

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
    eq([[\a\b\c\d]], vim_strsave_escaped('abcd', 'abcd'))
  end)

  itp('precedes by a backslash chars only from second argument', function()
    eq([[\a\bcd]], vim_strsave_escaped('abcd', 'ab'))
  end)

  itp('returns a copy of passed string if second argument is empty', function()
    eq('text \n text', vim_strsave_escaped('text \n text', ''))
  end)

  itp('returns an empty string if first argument is empty string', function()
    eq('', vim_strsave_escaped('', '\r'))
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

describe('vim_snprintf()', function()
  local function a(expected, buf, bsize, fmt, ...)
    eq(#expected, strings.vim_snprintf(buf, bsize, fmt, ...))
    if bsize > 0 then
      local actual = ffi.string(buf, math.min(#expected + 1, bsize))
      eq(expected:sub(1, bsize - 1) .. '\0', actual)
    end
  end

  local function i(n)
    return ffi.cast('int', n)
  end
  local function l(n)
    return ffi.cast('long', n)
  end
  local function ll(n)
    return ffi.cast('long long', n)
  end
  local function z(n)
    return ffi.cast('ptrdiff_t', n)
  end
  local function u(n)
    return ffi.cast('unsigned', n)
  end
  local function ul(n)
    return ffi.cast('unsigned long', n)
  end
  local function ull(n)
    return ffi.cast('unsigned long long', n)
  end
  local function uz(n)
    return ffi.cast('size_t', n)
  end

  itp('truncation', function()
    for bsize = 0, 14 do
      local buf = ffi.gc(strings.xmalloc(bsize), strings.xfree)
      a('1.00000001e7', buf, bsize, '%.8g', 10000000.1)
      a('1234567', buf, bsize, '%d', i(1234567))
      a('1234567', buf, bsize, '%ld', l(1234567))
      a('  1234567', buf, bsize, '%9ld', l(1234567))
      a('1234567  ', buf, bsize, '%-9ld', l(1234567))
      a('deadbeef', buf, bsize, '%x', u(0xdeadbeef))
      a('001100', buf, bsize, '%06b', u(12))
      a('one two', buf, bsize, '%s %s', 'one', 'two')
      a('1.234000', buf, bsize, '%f', 1.234)
      a('1.234000e+00', buf, bsize, '%e', 1.234)
      a('nan', buf, bsize, '%f', 0.0 / 0.0)
      a('inf', buf, bsize, '%f', 1.0 / 0.0)
      a('-inf', buf, bsize, '%f', -1.0 / 0.0)
      a('-0.000000', buf, bsize, '%f', -0.0)
      a('漢語', buf, bsize, '%s', '漢語')
      a('  漢語', buf, bsize, '%8s', '漢語')
      a('漢語  ', buf, bsize, '%-8s', '漢語')
      a('漢', buf, bsize, '%.3s', '漢語')
      a('  foo', buf, bsize, '%5S', 'foo')
      a('%%%', buf, bsize, '%%%%%%')
      a('0x87654321', buf, bsize, '%p', ffi.cast('char *', 0x87654321))
      a('0x0087654321', buf, bsize, '%012p', ffi.cast('char *', 0x87654321))
    end
  end)

  itp('positional arguments', function()
    for bsize = 0, 24 do
      local buf = ffi.gc(strings.xmalloc(bsize), strings.xfree)
      a('1234567  ', buf, bsize, '%1$*2$ld', l(1234567), i(-9))
      a('1234567  ', buf, bsize, '%1$*2$.*3$ld', l(1234567), i(-9), i(5))
      a('1234567  ', buf, bsize, '%1$*3$.*2$ld', l(1234567), i(5), i(-9))
      a('1234567  ', buf, bsize, '%3$*1$.*2$ld', i(-9), i(5), l(1234567))
      a('1234567', buf, bsize, '%1$ld', l(1234567))
      a('  1234567', buf, bsize, '%1$*2$ld', l(1234567), i(9))
      a('9 12345 7654321', buf, bsize, '%2$ld %1$d %3$lu', i(12345), l(9), ul(7654321))
      a('9 1234567 7654321', buf, bsize, '%2$d %1$ld %3$lu', l(1234567), i(9), ul(7654321))
      a('9 1234567 7654321', buf, bsize, '%2$d %1$lld %3$lu', ll(1234567), i(9), ul(7654321))
      a('9 12345 7654321', buf, bsize, '%2$ld %1$u %3$lu', u(12345), l(9), ul(7654321))
      a('9 1234567 7654321', buf, bsize, '%2$d %1$lu %3$lu', ul(1234567), i(9), ul(7654321))
      a('9 1234567 7654321', buf, bsize, '%2$d %1$llu %3$lu', ull(1234567), i(9), ul(7654321))
      a('9 deadbeef 7654321', buf, bsize, '%2$d %1$x %3$lu', u(0xdeadbeef), i(9), ul(7654321))
      a('9 c 7654321', buf, bsize, '%2$ld %1$c %3$lu', i(('c'):byte()), l(9), ul(7654321))
      a('9 hi 7654321', buf, bsize, '%2$ld %1$s %3$lu', 'hi', l(9), ul(7654321))
      a('9 0.000000e+00 7654321', buf, bsize, '%2$ld %1$e %3$lu', 0.0, l(9), ul(7654321))
      a('two one two', buf, bsize, '%2$s %1$s %2$s', 'one', 'two', 'three')
      a('three one two', buf, bsize, '%3$s %1$s %2$s', 'one', 'two', 'three')
      a('1234567', buf, bsize, '%1$d', i(1234567))
      a('deadbeef', buf, bsize, '%1$x', u(0xdeadbeef))
      a('001100', buf, bsize, '%2$0*1$b', i(6), u(12))
      a('001100', buf, bsize, '%1$0.*2$b', u(12), i(6))
      a('one two', buf, bsize, '%1$s %2$s', 'one', 'two')
      a('001100', buf, bsize, '%06b', u(12))
      a('two one', buf, bsize, '%2$s %1$s', 'one', 'two')
      a('1.234000', buf, bsize, '%1$f', 1.234)
      a('1.234000e+00', buf, bsize, '%1$e', 1.234)
      a('nan', buf, bsize, '%1$f', 0.0 / 0.0)
      a('inf', buf, bsize, '%1$f', 1.0 / 0.0)
      a('-inf', buf, bsize, '%1$f', -1.0 / 0.0)
      a('-0.000000', buf, bsize, '%1$f', -0.0)
    end
  end)

  itp('%zd and %zu', function()
    local bsize = 20
    local buf = ffi.gc(strings.xmalloc(bsize), strings.xfree)
    a('-1234567 -7654321', buf, bsize, '%zd %zd', z(-1234567), z(-7654321))
    a('-7654321 -1234567', buf, bsize, '%2$zd %1$zd', z(-1234567), z(-7654321))
    a('1234567 7654321', buf, bsize, '%zu %zu', uz(1234567), uz(7654321))
    a('7654321 1234567', buf, bsize, '%2$zu %1$zu', uz(1234567), uz(7654321))
  end)
end)

describe('strcase_save()', function()
  local strcase_save = function(input_string, upper)
    local res = strings.strcase_save(to_cstr(input_string), upper)
    return ffi.string(res)
  end

  itp('decodes overlong encoded characters.', function()
    eq('A', strcase_save('\xc1\x81', true))
    eq('a', strcase_save('\xc1\x81', false))
  end)
end)

describe('reverse_text', function()
  local reverse_text = function(str)
    return t.internalize(strings.reverse_text(to_cstr(str)))
  end

  itp('handles empty string', function()
    eq('', reverse_text(''))
  end)

  itp('handles simple cases', function()
    eq('a', reverse_text('a'))
    eq('ba', reverse_text('ab'))
  end)

  itp('handles multibyte characters', function()
    eq('bα', reverse_text('αb'))
    eq('Yötön yö', reverse_text('öy nötöY'))
  end)

  itp('handles combining chars', function()
    local utf8_COMBINING_RING_ABOVE = '\204\138'
    local utf8_COMBINING_RING_BELOW = '\204\165'
    eq(
      'bba' .. utf8_COMBINING_RING_ABOVE .. utf8_COMBINING_RING_BELOW .. 'aa',
      reverse_text('aaa' .. utf8_COMBINING_RING_ABOVE .. utf8_COMBINING_RING_BELOW .. 'bb')
    )
  end)

  itp('treats invalid utf as separate characters', function()
    eq('\192ba', reverse_text('ab\192'))
  end)

  itp('treats an incomplete utf continuation sequence as valid', function()
    eq('\194ba', reverse_text('ab\194'))
  end)
end)
