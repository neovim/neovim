local t = require('test.unit.testutil')(after_each)
local itp = t.gen_itp(it)

local cimport = t.cimport
local cstr = t.cstr
local eq = t.eq
local ffi = t.ffi
local to_cstr = t.to_cstr

local cimp = cimport('stdlib.h', './src/nvim/memory.h')

describe('xstrlcat()', function()
  local function test_xstrlcat(dst, src, dsize)
    assert.is_true(dsize >= 1 + string.len(dst)) -- sanity check for tests
    local dst_cstr = cstr(dsize, dst)
    local src_cstr = to_cstr(src)
    eq(string.len(dst .. src), cimp.xstrlcat(dst_cstr, src_cstr, dsize))
    return ffi.string(dst_cstr)
  end

  local function test_xstrlcat_overlap(dst, src_idx, dsize)
    assert.is_true(dsize >= 1 + string.len(dst)) -- sanity check for tests
    local dst_cstr = cstr(dsize, dst)
    local src_cstr = dst_cstr + src_idx -- pointer into `dst` (overlaps)
    eq(string.len(dst) + string.len(dst) - src_idx, cimp.xstrlcat(dst_cstr, src_cstr, dsize))
    return ffi.string(dst_cstr)
  end

  itp('concatenates strings', function()
    eq('ab', test_xstrlcat('a', 'b', 3))
    eq('ab', test_xstrlcat('a', 'b', 4096))
    eq('ABCיהZdefgiיהZ', test_xstrlcat('ABCיהZ', 'defgiיהZ', 4096))
    eq('b', test_xstrlcat('', 'b', 4096))
    eq('a', test_xstrlcat('a', '', 4096))
  end)

  itp('concatenates overlapping strings', function()
    eq('abcabc', test_xstrlcat_overlap('abc', 0, 7))
    eq('abca', test_xstrlcat_overlap('abc', 0, 5))
    eq('abcb', test_xstrlcat_overlap('abc', 1, 5))
    eq('abcc', test_xstrlcat_overlap('abc', 2, 10))
    eq('abcabc', test_xstrlcat_overlap('abc', 0, 2343))
  end)

  itp('truncates if `dsize` is too small', function()
    eq('a', test_xstrlcat('a', 'b', 2))
    eq('', test_xstrlcat('', 'b', 1))
    eq('ABCיהZd', test_xstrlcat('ABCיהZ', 'defgiיהZ', 10))
  end)
end)
