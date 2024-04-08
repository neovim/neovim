local t = require('test.unit.testutil')(after_each)
local itp = t.gen_itp(it)

local eq = t.eq
local ffi = t.ffi
local cstr = t.cstr
local to_cstr = t.to_cstr
local child_call_once = t.child_call_once

local rbuffer = t.cimport('./test/unit/fixtures/rbuffer.h')

describe('rbuffer functions', function()
  local capacity = 16
  local rbuf

  local function inspect()
    return ffi.string(rbuf.start_ptr, capacity)
  end

  local function write(str)
    local buf = to_cstr(str)
    return rbuffer.rbuffer_write(rbuf, buf, #str)
  end

  local function read(len)
    local buf = cstr(len)
    len = rbuffer.rbuffer_read(rbuf, buf, len)
    return ffi.string(buf, len)
  end

  local function get(idx)
    return ffi.string(rbuffer.rbuffer_get(rbuf, idx), 1)
  end

  before_each(function()
    child_call_once(function()
      rbuf = ffi.gc(rbuffer.rbuffer_new(capacity), rbuffer.rbuffer_free)
      -- fill the internal buffer with the character '0' to simplify inspecting
      ffi.C.memset(rbuf.start_ptr, string.byte('0'), capacity)
    end)
  end)

  describe('RBUFFER_UNTIL_FULL', function()
    local chunks

    local function collect_write_chunks()
      rbuffer.ut_rbuffer_each_write_chunk(rbuf, function(wptr, wcnt)
        table.insert(chunks, ffi.string(wptr, wcnt))
      end)
    end

    before_each(function()
      chunks = {}
    end)

    describe('with empty buffer in one contiguous chunk', function()
      itp('is called once with the empty chunk', function()
        collect_write_chunks()
        eq({ '0000000000000000' }, chunks)
      end)
    end)

    describe('with partially empty buffer in one contiguous chunk', function()
      itp('is called once with the empty chunk', function()
        write('string')
        collect_write_chunks()
        eq({ '0000000000' }, chunks)
      end)
    end)

    describe('with filled buffer in one contiguous chunk', function()
      itp('is not called', function()
        write('abcdefghijklmnopq')
        collect_write_chunks()
        eq({}, chunks)
      end)
    end)

    describe('with buffer partially empty in two contiguous chunks', function()
      itp('is called twice with each filled chunk', function()
        write('1234567890')
        read(8)
        collect_write_chunks()
        eq({ '000000', '12345678' }, chunks)
      end)
    end)

    describe('with buffer empty in two contiguous chunks', function()
      itp('is called twice with each filled chunk', function()
        write('12345678')
        read(8)
        collect_write_chunks()
        eq({ '00000000', '12345678' }, chunks)
      end)
    end)

    describe('with buffer filled in two contiguous chunks', function()
      itp('is not called', function()
        write('12345678')
        read(8)
        write('abcdefghijklmnopq')
        collect_write_chunks()
        eq({}, chunks)
      end)
    end)
  end)

  describe('RBUFFER_UNTIL_EMPTY', function()
    local chunks

    local function collect_read_chunks()
      rbuffer.ut_rbuffer_each_read_chunk(rbuf, function(rptr, rcnt)
        table.insert(chunks, ffi.string(rptr, rcnt))
      end)
    end

    before_each(function()
      chunks = {}
    end)

    describe('with empty buffer', function()
      itp('is not called', function()
        collect_read_chunks()
        eq({}, chunks)
      end)
    end)

    describe('with partially filled buffer in one contiguous chunk', function()
      itp('is called once with the filled chunk', function()
        write('string')
        collect_read_chunks()
        eq({ 'string' }, chunks)
      end)
    end)

    describe('with filled buffer in one contiguous chunk', function()
      itp('is called once with the filled chunk', function()
        write('abcdefghijklmnopq')
        collect_read_chunks()
        eq({ 'abcdefghijklmnop' }, chunks)
      end)
    end)

    describe('with buffer partially filled in two contiguous chunks', function()
      itp('is called twice with each filled chunk', function()
        write('1234567890')
        read(10)
        write('long string')
        collect_read_chunks()
        eq({ 'long s', 'tring' }, chunks)
      end)
    end)

    describe('with buffer filled in two contiguous chunks', function()
      itp('is called twice with each filled chunk', function()
        write('12345678')
        read(8)
        write('abcdefghijklmnopq')
        collect_read_chunks()
        eq({ 'abcdefgh', 'ijklmnop' }, chunks)
      end)
    end)
  end)

  describe('RBUFFER_EACH', function()
    local chars

    local function collect_chars()
      rbuffer.ut_rbuffer_each(rbuf, function(c, i)
        table.insert(chars, { string.char(c), tonumber(i) })
      end)
    end
    before_each(function()
      chars = {}
    end)

    describe('with empty buffer', function()
      itp('is not called', function()
        collect_chars()
        eq({}, chars)
      end)
    end)

    describe('with buffer filled in two contiguous chunks', function()
      itp('collects each character and index', function()
        write('1234567890')
        read(10)
        write('long string')
        collect_chars()
        eq({
          { 'l', 0 },
          { 'o', 1 },
          { 'n', 2 },
          { 'g', 3 },
          { ' ', 4 },
          { 's', 5 },
          { 't', 6 },
          { 'r', 7 },
          { 'i', 8 },
          { 'n', 9 },
          { 'g', 10 },
        }, chars)
      end)
    end)
  end)

  describe('RBUFFER_EACH_REVERSE', function()
    local chars

    local function collect_chars()
      rbuffer.ut_rbuffer_each_reverse(rbuf, function(c, i)
        table.insert(chars, { string.char(c), tonumber(i) })
      end)
    end
    before_each(function()
      chars = {}
    end)

    describe('with empty buffer', function()
      itp('is not called', function()
        collect_chars()
        eq({}, chars)
      end)
    end)

    describe('with buffer filled in two contiguous chunks', function()
      itp('collects each character and index', function()
        write('1234567890')
        read(10)
        write('long string')
        collect_chars()
        eq({
          { 'g', 10 },
          { 'n', 9 },
          { 'i', 8 },
          { 'r', 7 },
          { 't', 6 },
          { 's', 5 },
          { ' ', 4 },
          { 'g', 3 },
          { 'n', 2 },
          { 'o', 1 },
          { 'l', 0 },
        }, chars)
      end)
    end)
  end)

  describe('rbuffer_cmp', function()
    local function cmp(str)
      local rv = rbuffer.rbuffer_cmp(rbuf, to_cstr(str), #str)
      if rv == 0 then
        return 0
      else
        return rv / math.abs(rv)
      end
    end

    describe('with buffer filled in two contiguous chunks', function()
      itp('compares the common longest sequence', function()
        write('1234567890')
        read(10)
        write('long string')
        eq(0, cmp('long string'))
        eq(0, cmp('long strin'))
        eq(-1, cmp('long striM'))
        eq(1, cmp('long strio'))
        eq(0, cmp('long'))
        eq(-1, cmp('lonG'))
        eq(1, cmp('lonh'))
      end)
    end)

    describe('with empty buffer', function()
      itp('returns 0 since no characters are compared', function()
        eq(0, cmp(''))
      end)
    end)
  end)

  describe('rbuffer_write', function()
    itp('fills the internal buffer and returns the write count', function()
      eq(12, write('short string'))
      eq('short string0000', inspect())
    end)

    itp('wont write beyond capacity', function()
      eq(16, write('very very long string'))
      eq('very very long s', inspect())
    end)
  end)

  describe('rbuffer_read', function()
    itp('reads what was previously written', function()
      write('to read')
      eq('to read', read(20))
    end)

    itp('reads nothing if the buffer is empty', function()
      eq('', read(20))
      write('empty')
      eq('empty', read(20))
      eq('', read(20))
    end)
  end)

  describe('rbuffer_get', function()
    itp('fetch the pointer at offset, wrapping if required', function()
      write('1234567890')
      read(10)
      write('long string')
      eq('l', get(0))
      eq('o', get(1))
      eq('n', get(2))
      eq('g', get(3))
      eq(' ', get(4))
      eq('s', get(5))
      eq('t', get(6))
      eq('r', get(7))
      eq('i', get(8))
      eq('n', get(9))
      eq('g', get(10))
    end)
  end)

  describe('wrapping behavior', function()
    itp('writing/reading wraps across the end of the internal buffer', function()
      write('1234567890')
      eq('1234', read(4))
      eq('5678', read(4))
      write('987654321')
      eq('3214567890987654', inspect())
      eq('90987654321', read(20))
      eq('', read(4))
      write('abcdefghijklmnopqrs')
      eq('nopabcdefghijklm', inspect())
      eq('abcdefghijklmnop', read(20))
    end)
  end)
end)
