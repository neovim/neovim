ffi = require 'ffi'

-- load neovim shared library
testlib = os.getenv 'NVIM_TEST_LIB'
unless testlib
    testlib = './build/src/libnvim-test.so'

libnvim = ffi.load testlib

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

testinc = os.getenv 'TEST_INCLUDES'
unless testinc
    testinc = './build/test/includes/post'

cppimport = (path) ->
  return cimport testinc .. '/' .. path

cimport './src/types.h'

-- take a pointer to a C-allocated string and return an interned
-- version while also freeing the memory
internalize = (cdata) ->
  ffi.gc cdata, ffi.C.free
  return ffi.string cdata

cstr = ffi.typeof 'char[?]'

to_cstr = (string) ->
  cstr (string.len string) + 1, string

return {
  cimport: cimport
  cppimport: cppimport
  internalize: internalize
  eq: (expected, actual) -> assert.are.same expected, actual
  neq: (expected, actual) -> assert.are_not.same expected, actual
  ffi: ffi
  lib: libnvim
  cstr: cstr
  to_cstr: to_cstr
}
