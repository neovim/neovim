ffi = require 'ffi'

-- load neovim shared library
libnvim = ffi.load './build/src/libnvim-test.so'

-- Luajit ffi parser only understands function signatures.
-- This helper function normalizes headers, passes to ffi and returns the
-- library pointer
cimport = (path) ->
  -- Can't parse some of vim types, perhaps need to define those before
  -- automatically importing to ffi

  -- header_file = io.open path, 'rb'
  -- header = header_file\read '*a'
  -- header_file.close!
  -- header = string.gsub header, '#include[^\n]*\n', ''
  -- header = string.gsub header, '#ifndef[^\n]*\n', ''
  -- header = string.gsub header, '#define[^\n]*\n', ''
  -- header = string.gsub header, '#endif[^\n]*\n', ''
  -- ffi.cdef header

  return libnvim

-- take a pointer to a C-allocated string and return an interned
-- version while also freeing the memory
internalize = (cdata) ->
  ffi.gc cdata, ffi.C.free
  return ffi.string cdata

return {
  cimport: cimport
  internalize: internalize
  eq: (expected, actual) -> assert.are.same expected, actual
  ffi: ffi
}
