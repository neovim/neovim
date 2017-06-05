{:cimport, :internalize, :eq, :ffi} = require 'test.unit.helpers'
require 'lfs'

fs = cimport './src/fs.h'
cstr = ffi.typeof 'char[?]'

describe 'fs function', ->
  describe 'mch_dirname', ->
    ffi.cdef 'int mch_dirname(char *buf, int len);'

    mch_dirname = (buf, len) ->
      fs.mch_dirname buf, len

    OK = 1
    FAIL = 0

    before_each ->
      export len = string.len(lfs.currentdir()) + 1

    it 'returns OK and writes current directory into the buffer if it is buffer
    is large enough', ->
      buf = ffi.new 'char[?]', len
      eq OK, (mch_dirname buf, len)
      eq lfs.currentdir(), ffi.string(buf)

    -- What kind of other failing cases are possible?
    it 'returns FAIL if the buffer is too small', ->
      buf = ffi.new 'char[?]', 0
      eq FAIL, (mch_dirname buf, 0)

  describe 'mch_FullName', ->
    ffi.cdef 'int mch_FullName(char *fname, char *buf, int len, int force);'

    mch_FullName = (filename, buffer, length, force) ->
      filename = cstr(string.len(filename) + 1, filename)
      fs.mch_FullName(filename, buffer, length, force)

    OK = 1
    FAIL = 0

    before_each ->
      -- Create empty string buffer which will contain the resulting path
      export len = string.len(lfs.currentdir()) + 11
      export buffer = cstr(len, '')

    it 'failes if given filename contains non-existing directory', ->
      result = mch_FullName('nonexistingdir/test.file', buffer, len, 1)
      eq FAIL, result

    it 'concatenates given filename if it does not contain a slash', ->
      result = mch_FullName('test.file', buffer, len, 1)
      eq OK, result
      expected = lfs.currentdir() .. '/test.file'
      eq expected, ffi.string(buffer)

    it 'concatenates given filename if it is a directory but does not contain a
    slash', ->
      result = mch_FullName('..', buffer, len, 1)
      eq OK, result
      expected = lfs.currentdir() .. '/..'
      eq expected, ffi.string(buffer)

    -- Is it possible for every developer to enter '..' directory while running
    -- the unit tests? Which other directory would be better?
    it 'enters given directory if possible and if path contains a slash', ->
      result = mch_FullName('../test.file', buffer, 200, 1)
      eq OK, result
      old_dir = lfs.currentdir()
      lfs.chdir('..')
      expected = lfs.currentdir() .. '/test.file'
      lfs.chdir(old_dir)
      eq expected, ffi.string(buffer)

  describe 'mch_isFullName', ->
    ffi.cdef 'int mch_isFullName(char *fname);'

    mch_isFullName = (filename) ->
      filename = cstr(string.len(filename) + 1, filename)
      fs.mch_isFullName(filename)

    TRUE = 1
    FALSE = 0

    it 'returns true if filename starts with a slash', ->
      eq TRUE, mch_isFullName('/some/directory/')

    it 'returns true if filename starts with a tilde', ->
      eq TRUE, mch_isFullName('~/in/my/home~/directory')

    it 'returns false if filename starts not with slash nor tilde', ->
      eq FALSE, mch_isFullName('not/in/my/home~/directory')
