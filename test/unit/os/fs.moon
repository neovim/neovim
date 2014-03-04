{:cimport, :internalize, :eq, :ffi, :lib, :cstr} = require 'test.unit.helpers'
require 'lfs'

-- fs = cimport './src/os/os.h'
-- remove these statements once 'cimport' is working properly for misc1.h
fs = lib
ffi.cdef [[
enum OKFAIL {
  OK = 1, FAIL = 0
};
int mch_dirname(char_u *buf, int len);
]]

-- import constants parsed by ffi
{:OK, :FAIL} = lib

describe 'fs function', ->

  describe 'mch_dirname', ->

    mch_dirname = (buf, len) ->
      fs.mch_dirname buf, len

    before_each ->
      export len = (string.len lfs.currentdir!) + 1
      export buf = cstr len, ''

    it 'returns OK and writes current directory into the buffer if it is large
    enough', ->
      eq OK, (mch_dirname buf, len)
      eq lfs.currentdir!, (ffi.string buf)

    -- What kind of other failing cases are possible?
    it 'returns FAIL if the buffer is too small', ->
      buf = cstr (len-1), ''
      eq FAIL, (mch_dirname buf, (len-1))

  describe 'mch_full_dir_name', ->
    ffi.cdef 'int mch_full_dir_name(char *directory, char *buffer, int len);'

    mch_full_dir_name = (directory, buffer, len) ->
      directory = cstr (string.len directory), directory
      fs.mch_full_dir_name(directory, buffer, len)

    before_each ->
      -- Create empty string buffer which will contain the resulting path.
      export len = (string.len lfs.currentdir!) + 22
      export buffer = cstr len, ''

    it 'returns the absolute directory name of a given relative one', ->
      result = mch_full_dir_name '..', buffer, len
      eq OK, result
      old_dir = lfs.currentdir!
      lfs.chdir '..'
      expected = lfs.currentdir!
      lfs.chdir old_dir
      eq expected, (ffi.string buffer)

    it 'returns the current directory name if the given string is empty', ->
      eq OK, (mch_full_dir_name '', buffer, len)
      eq lfs.currentdir!, (ffi.string buffer)

    it 'fails if the given directory does not exist', ->
      eq FAIL, mch_full_dir_name('does_not_exist', buffer, len)

    it 'works with a normal relative dir', ->
      lfs.mkdir 'empty-test-directory'
      result = mch_full_dir_name('empty-test-directory', buffer, len)
      lfs.rmdir 'empty-test-directory'
      eq lfs.currentdir! .. '/empty-test-directory', (ffi.string buffer)
      eq OK, result

  describe 'mch_full_name', ->
    ffi.cdef 'int mch_full_name(char *fname, char *buf, int len, int force);'

    mch_full_name = (filename, buffer, length, force) ->
      filename = cstr (string.len filename) + 1, filename
      fs.mch_full_name filename, buffer, length, force

    before_each ->
      -- Create empty string buffer which will contain the resulting path.
      export len = (string.len lfs.currentdir!) + 33
      export buffer = cstr len, ''

      -- Create a directory and an empty file inside in order to know some
      -- existing relative path.
      lfs.mkdir 'empty-test-directory'
      lfs.touch 'empty-test-directory/empty.file'

    after_each ->
      lfs.rmdir 'empty-test-directory'

    it 'fails if given filename contains non-existing directory', ->
      force_expansion = 1
      result = mch_full_name 'non_existing_dir/test.file', buffer, len, force_expansion
      eq FAIL, result

    it 'concatenates given filename if it does not contain a slash', ->
      force_expansion = 1
      result = mch_full_name 'test.file', buffer, len, force_expansion
      expected = lfs.currentdir! .. '/test.file'
      eq expected, (ffi.string buffer)
      eq OK, result

    it 'concatenates given filename if it is a directory but does not contain a
    slash', ->
      force_expansion = 1
      result = mch_full_name '..', buffer, len, force_expansion
      expected = lfs.currentdir! .. '/..'
      eq expected, (ffi.string buffer)
      eq OK, result

    -- Is it possible for every developer to enter '..' directory while running
    -- the unit tests? Which other directory would be better?
    it 'enters given directory (instead of just concatenating the strings) if
    possible and if path contains a slash', ->
      force_expansion = 1
      result = mch_full_name '../test.file', buffer, len, force_expansion
      old_dir = lfs.currentdir!
      lfs.chdir '..'
      expected = lfs.currentdir! .. '/test.file'
      lfs.chdir old_dir
      eq expected, (ffi.string buffer)
      eq OK, result

    it 'just copies the path if it is already absolute and force=0', ->
      force_expansion = 0
      absolute_path = '/absolute/path'
      result = mch_full_name absolute_path, buffer, len, force_expansion
      eq absolute_path, (ffi.string buffer)
      eq OK, result

    it 'fails when the path is relative to HOME', ->
      force_expansion = 1
      absolute_path = '~/home.file'
      result = mch_full_name absolute_path, buffer, len, force_expansion
      eq FAIL, result

    it 'works with some "normal" relative path with directories', ->
      force_expansion = 1
      result = mch_full_name 'empty-test-directory/empty.file', buffer, len, force_expansion
      eq OK, result
      eq lfs.currentdir! .. '/empty-test-directory/empty.file', (ffi.string buffer)

    it 'does not modify the given filename', ->
      force_expansion = 1
      filename = cstr 100, 'empty-test-directory/empty.file'
      result = fs.mch_full_name filename, buffer, len, force_expansion
      eq lfs.currentdir! .. '/empty-test-directory/empty.file', (ffi.string buffer)
      eq 'empty-test-directory/empty.file', (ffi.string filename)
      eq OK, result

  describe 'append_path', ->
    ffi.cdef 'int append_path(char *path, char *to_append, int max_len);'

    it 'joins given paths with a slash', ->
     path = cstr 100, 'path1'
     to_append = cstr 6, 'path2'
     eq OK, (fs.append_path path, to_append, 100)
     eq "path1/path2", (ffi.string path)

    it 'joins given paths without adding an unnecessary slash', ->
     path = cstr 100, 'path1/'
     to_append = cstr 6, 'path2'
     eq OK, fs.append_path path, to_append, 100
     eq "path1/path2", (ffi.string path)

    it 'fails if there is not enough space left for to_append', ->
      path = cstr 11, 'path1/'
      to_append = cstr 6, 'path2'
      eq FAIL, (fs.append_path path, to_append, 11)

    it 'does not append a slash if to_append is empty', ->
      path = cstr 6, 'path1'
      to_append = cstr 1, ''
      eq OK, (fs.append_path path, to_append, 6)
      eq 'path1', (ffi.string path)

    it 'does not append unnecessary dots', ->
      path = cstr 6, 'path1'
      to_append = cstr 2, '.'
      eq OK, (fs.append_path path, to_append, 6)
      eq 'path1', (ffi.string path)

    it 'copies to_append to path, if path is empty', ->
      path = cstr 7, ''
      to_append = cstr 7, '/path2'
      eq OK, (fs.append_path path, to_append, 7)
      eq '/path2', (ffi.string path)

  describe 'mch_is_full_name', ->
    ffi.cdef 'int mch_is_full_name(char *fname);'

    mch_is_full_name = (filename) ->
      filename = cstr (string.len filename) + 1, filename
      fs.mch_is_full_name filename

    it 'returns true if filename starts with a slash', ->
      eq OK, mch_is_full_name '/some/directory/'

    it 'returns true if filename starts with a tilde', ->
      eq OK, mch_is_full_name '~/in/my/home~/directory'

    it 'returns false if filename starts not with slash nor tilde', ->
      eq FAIL, mch_is_full_name 'not/in/my/home~/directory'
