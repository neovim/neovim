-- cdef_buffer keeps a list of all the lines that have been defined.
-- cdef_buffer is global because anything defined by ffi.cdef is permanent to the process

export cdef_buffer = {}

cimport = (...) ->
  paths = {...}
  ffi = require 'ffi'
  libnvim = ffi.load './build/src/libnvim-test.so'

  for path in *paths
    new_cdefs = {}
    header_file = io.popen "/usr/bin/env cc -E #{path}"

    if not header_file
      error "cannot find #{path}"

    for line in header_file\lines! do
      if not line\match '^#[^\n]*$'
        -- find if line has already been cdef'ed
        defined = [buffer_line for buffer_line in *cdef_buffer when line == buffer_line]
        if next(defined) == nil
          table.insert(new_cdefs, line)

    header_file.close!

    -- add the lines to the buffer
    for line in *new_cdefs
      table.insert(cdef_buffer, line)

    ffi.cdef table.concat(new_cdefs, "\n")

  -- take a pointer to a C-allocated string and return an interned
  -- version while also freeing the memory
  internalize = (cdata) ->
    ffi.gc cdata, ffi.C.free
    return ffi.string cdata

  cstr = ffi.typeof 'char[?]'

  to_cstr = (string) ->
    cstr (string.len string) + 1, string

  return {
    ffi: ffi
    lib: libnvim
    cstr: cstr
    to_cstr: to_cstr
    internalize: internalize
  }


return {
  cimport: cimport
  eq: (expected, actual) -> assert.are.same expected, actual
}
