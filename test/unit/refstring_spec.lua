local t = require('test.unit.testutil')
local itp = t.gen_itp(it)

local cimport = t.cimport
local eq = t.eq
local ffi = t.ffi
local to_cstr = t.to_cstr
local NULL = t.NULL

local api = cimport('./src/nvim/api/private/helpers.h')

local new_String = function(str_literal)
  return ffi.gc(
    ffi.new('String', {
      data = api.xstrdup(to_cstr(str_literal)),
      size = #str_literal,
    }),
    api.api_free_string
  )
end

describe('RefString', function()
  itp('can be created from a string', function()
    local str = new_String('foobar')
    local rs = api.ref_string_new(str)
    eq('foobar', ffi.string(rs.data, rs.size))
    eq(1, rs.refcount[0])
  end)

  itp('copy and free', function()
    local str = new_String('foobar')

    local rs = api.ref_string_new_alloc(str)
    eq('foobar', ffi.string(rs.data, rs.size))

    local rs2 = api.ref_string_copy(rs)
    eq('foobar', ffi.string(rs2.data, rs2.size))
    eq(2, rs.refcount[0])
    eq(2, rs2.refcount[0])

    api.ref_string_free(rs)
    eq(NULL, rs.refcount)
    eq(1, rs2.refcount[0])

    api.ref_string_free(rs2)
    eq(NULL, rs2.refcount)
  end)

  itp('copy-on-write', function()
    local str = new_String('foobar')
    local str2 = new_String('baz')

    local rs = api.ref_string_new(str)
    local rs2 = api.ref_string_copy(rs)
    local rs3 = api.ref_string_copy(rs)
    eq(3, rs.refcount[0])

    api.ref_string_set(rs, str2)

    eq(1, rs.refcount[0])
    eq(2, rs2.refcount[0])
    eq(2, rs3.refcount[0])

    eq('baz', ffi.string(rs.data, rs.size))
    eq('foobar', ffi.string(rs2.data, rs2.size))
    eq('foobar', ffi.string(rs3.data, rs3.size))
  end)

  itp('static value copy and free', function()
    local rs = ffi.new('RefString', {
      data = to_cstr('foobar'),
      size = 6,
      refcount = NULL,
    })

    local rs2 = api.ref_string_copy(rs)
    eq('foobar', ffi.string(rs2.data, rs2.size))
    eq(NULL, rs2.refcount)

    api.ref_string_free(rs)
    eq(NULL, rs.refcount)
    eq(NULL, rs.data)
    eq('foobar', ffi.string(rs2.data, rs2.size))
    eq(NULL, rs2.refcount)
  end)

  itp('static value copy-on-write', function()
    local rs = ffi.new('RefString', {
      data = to_cstr('foobar'),
      size = 6,
      refcount = NULL,
    })

    local rs2 = api.ref_string_copy(rs)
    local rs3 = api.ref_string_copy(rs)
    eq(NULL, rs2.refcount)
    eq(NULL, rs3.refcount)

    api.ref_string_set(rs, new_String('baz'))

    eq(1, rs.refcount[0])
    eq(NULL, rs2.refcount)
    eq(NULL, rs3.refcount)

    eq('baz', ffi.string(rs.data, rs.size))
    eq('foobar', ffi.string(rs2.data, rs2.size))
    eq('foobar', ffi.string(rs3.data, rs3.size))
  end)

  itp('string conversion', function()
    local rs = api.ref_string_new_alloc(new_String('foobar'))
    local rs2 = api.ref_string_copy(rs)
    eq(2, rs.refcount[0])

    local str = api.ref_string_as_string(rs)
    eq('foobar', ffi.string(str.data, str.size))
    eq(NULL, rs.refcount)
    eq(NULL, rs.data)
    eq(1, rs2.refcount[0])

    local str2 = api.ref_string_as_string(rs2)
    eq('foobar', ffi.string(str2.data, str2.size))
    eq(NULL, rs2.refcount)
    eq(NULL, rs2.data)
  end)
end)
