local t = require('test.unit.testutil')
local itp = t.gen_itp(it)

local cimport = t.cimport
local eq = t.eq
local ffi = t.ffi
local to_cstr = t.to_cstr
local NULL = t.NULL

local api = cimport('./src/nvim/api/private/helpers.h')

describe('RefString', function()
  itp('can be created from a string', function()
    local rs = api.ref_string_new(to_cstr('foobar'))
    eq('foobar', ffi.string(rs))
    eq(1, api.ref_string_get_refcount(rs))
    api.ref_string_free(rs)
  end)

  itp('copy and free', function()
    local rs = api.ref_string_new(to_cstr('foobar'))
    eq('foobar', ffi.string(rs))

    local rs2 = api.ref_string_copy(rs)
    eq('foobar', ffi.string(rs2))
    eq(2, api.ref_string_get_refcount(rs))
    eq(2, api.ref_string_get_refcount(rs2))

    api.ref_string_free(rs)
    eq(1, api.ref_string_get_refcount(rs2))

    api.ref_string_free(rs2)
  end)

  itp('static value copy and free', function()
    local rs = ffi.cast('const char *', to_cstr('\xff\xff\xff\xfffoobar')) + 4
    local refcount = api.ref_string_get_refcount(rs)
    eq(math.pow(2, 32) - 1, refcount)

    local rs2 = api.ref_string_copy(rs)
    eq(refcount, api.ref_string_get_refcount(rs))
    eq('foobar', ffi.string(rs2))

    api.ref_string_free(rs)
    eq(refcount, api.ref_string_get_refcount(rs))
    eq('foobar', ffi.string(rs2))
  end)
end)
