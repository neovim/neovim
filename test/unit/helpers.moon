ffi = require 'ffi'

-- load neovim shared library
libnvim = ffi.load './build/src/libnvim-test.so'

-- Luajit ffi parser doesn't understand preprocessor directives, so
-- this helper function removes common directives before passing it the to ffi.
-- It will return a pointer to the library table, emulating 'requires'
cimport = (path) ->
  header_file = io.open path, 'rb'

  if not header_file
    error "cannot find #{path}"

  header = header_file\read '*a'
  header_file.close!
  header = string.gsub header, '#include[^\n]*\n', ''
  header = string.gsub header, '#ifndef[^\n]*\n', ''
  header = string.gsub header, '#define[^\n]*\n', ''
  header = string.gsub header, '#endif[^\n]*\n', ''
  ffi.cdef header

  return libnvim

cimport './src/types.h'

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
  lib: libnvim
  cstr: ffi.typeof 'char[?]'
}
