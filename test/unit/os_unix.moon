{:cimport, :eq, :ffi} = require 'test.unit.helpers'

cstr = ffi.typeof 'char[?]'
os = cimport './src/os_unix.h'

describe 'os_unix function', ->
  describe 'mch_isdir', ->
    TRUE = 1
    FALSE = 0

    ffi.cdef('int mch_isdir(char * name);')

    mch_isdir = (name) ->
      name = cstr (string.len name), name
      os.mch_isdir(name)

    setup ->
      lfs.mkdir 'empty-test-directory'
      lfs.touch 'empty-test-directory/test.file'

    teardown ->
      lfs.rmdir 'empty-test-directory'

    it 'returns false if an empty string is given', ->
      eq FALSE, (mch_isdir '')

    it 'returns false if a nonexisting directory is given', ->
      eq FALSE, (mch_isdir 'non-existing-directory')

    it 'returns false if an existing file is given', ->
      eq FALSE, (mch_isdir 'non-existing-directory/test.file')

    it 'returns true if the current directory is given', ->
      eq TRUE, (mch_isdir '.')

    it 'returns true if the parent directory is given', ->
      eq TRUE, (mch_isdir '..')

    it 'returns true if an newly created directory is given', ->
      eq TRUE, (mch_isdir 'empty-test-directory')
