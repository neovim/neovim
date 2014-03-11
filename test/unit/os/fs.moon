{:cimport, :cppimport, :internalize, :eq, :neq, :ffi, :lib, :cstr, :to_cstr} = require 'test.unit.helpers'
require 'lfs'
require 'bit'

-- fs = cimport './src/os/os.h'
-- remove these statements once 'cimport' is working properly for misc1.h
fs = lib
ffi.cdef [[
enum OKFAIL {
  OK = 1, FAIL = 0
};
enum BOOLEAN {
  TRUE = 1, FALSE = 0
};
int mch_dirname(char_u *buf, int len);
int mch_isdir(char_u * name);
int is_executable(char_u *name);
int mch_can_exe(char_u *name);
long mch_getperm(char_u *name);
int mch_setperm(char_u *name, long perm);
]]

-- import constants parsed by ffi
{:OK, :FAIL} = lib
{:TRUE, :FALSE} = lib

cppimport 'sys/stat.h'

describe 'fs function', ->
  setup ->
    lfs.mkdir 'unit-test-directory'
    (io.open 'unit-test-directory/test.file', 'w').close!

    -- Since the tests are executed, they are called by an executable. We use
    -- that executable for several asserts.
    export absolute_executable = arg[0]

    -- Split absolute_executable into a directory and the actual file name for
    -- later usage.
    export directory, executable_name = string.match(absolute_executable, '^(.*)/(.*)$')

  teardown ->
    os.remove 'unit-test-directory/test.file'
    lfs.rmdir 'unit-test-directory'

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
      directory = to_cstr directory
      fs.mch_full_dir_name directory, buffer, len

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
      result = mch_full_dir_name('unit-test-directory', buffer, len)
      eq lfs.currentdir! .. '/unit-test-directory', (ffi.string buffer)
      eq OK, result

  describe 'mch_get_absolute_path', ->
    ffi.cdef 'int mch_get_absolute_path(char *fname, char *buf, int len, int force);'

    mch_get_absolute_path = (filename, buffer, length, force) ->
      filename = to_cstr filename
      fs.mch_get_absolute_path filename, buffer, length, force

    before_each ->
      -- Create empty string buffer which will contain the resulting path.
      export len = (string.len lfs.currentdir!) + 33
      export buffer = cstr len, ''

    it 'fails if given filename contains non-existing directory', ->
      force_expansion = 1
      result = mch_get_absolute_path 'non_existing_dir/test.file', buffer, len, force_expansion
      eq FAIL, result

    it 'concatenates given filename if it does not contain a slash', ->
      force_expansion = 1
      result = mch_get_absolute_path 'test.file', buffer, len, force_expansion
      expected = lfs.currentdir! .. '/test.file'
      eq expected, (ffi.string buffer)
      eq OK, result

    it 'concatenates given filename if it is a directory but does not contain a
    slash', ->
      force_expansion = 1
      result = mch_get_absolute_path '..', buffer, len, force_expansion
      expected = lfs.currentdir! .. '/..'
      eq expected, (ffi.string buffer)
      eq OK, result

    -- Is it possible for every developer to enter '..' directory while running
    -- the unit tests? Which other directory would be better?
    it 'enters given directory (instead of just concatenating the strings) if
    possible and if path contains a slash', ->
      force_expansion = 1
      result = mch_get_absolute_path '../test.file', buffer, len, force_expansion
      old_dir = lfs.currentdir!
      lfs.chdir '..'
      expected = lfs.currentdir! .. '/test.file'
      lfs.chdir old_dir
      eq expected, (ffi.string buffer)
      eq OK, result

    it 'just copies the path if it is already absolute and force=0', ->
      force_expansion = 0
      absolute_path = '/absolute/path'
      result = mch_get_absolute_path absolute_path, buffer, len, force_expansion
      eq absolute_path, (ffi.string buffer)
      eq OK, result

    it 'fails when the path is relative to HOME', ->
      force_expansion = 1
      absolute_path = '~/home.file'
      result = mch_get_absolute_path absolute_path, buffer, len, force_expansion
      eq FAIL, result

    it 'works with some "normal" relative path with directories', ->
      force_expansion = 1
      result = mch_get_absolute_path 'unit-test-directory/test.file', buffer, len, force_expansion
      eq OK, result
      eq lfs.currentdir! .. '/unit-test-directory/test.file', (ffi.string buffer)

    it 'does not modify the given filename', ->
      force_expansion = 1
      filename = to_cstr 'unit-test-directory/test.file'
      -- Don't use the wrapper here but pass a cstring directly to the c
      -- function.
      result = fs.mch_get_absolute_path filename, buffer, len, force_expansion
      eq lfs.currentdir! .. '/unit-test-directory/test.file', (ffi.string buffer)
      eq 'unit-test-directory/test.file', (ffi.string filename)
      eq OK, result

  describe 'append_path', ->
    ffi.cdef 'int append_path(char *path, char *to_append, int max_len);'

    it 'joins given paths with a slash', ->
     path = cstr 100, 'path1'
     to_append = to_cstr 'path2'
     eq OK, (fs.append_path path, to_append, 100)
     eq "path1/path2", (ffi.string path)

    it 'joins given paths without adding an unnecessary slash', ->
     path = cstr 100, 'path1/'
     to_append = to_cstr 'path2'
     eq OK, fs.append_path path, to_append, 100
     eq "path1/path2", (ffi.string path)

    it 'fails if there is not enough space left for to_append', ->
      path = cstr 11, 'path1/'
      to_append = to_cstr 'path2'
      eq FAIL, (fs.append_path path, to_append, 11)

    it 'does not append a slash if to_append is empty', ->
      path = cstr 6, 'path1'
      to_append = to_cstr ''
      eq OK, (fs.append_path path, to_append, 6)
      eq 'path1', (ffi.string path)

    it 'does not append unnecessary dots', ->
      path = cstr 6, 'path1'
      to_append = to_cstr '.'
      eq OK, (fs.append_path path, to_append, 6)
      eq 'path1', (ffi.string path)

    it 'copies to_append to path, if path is empty', ->
      path = cstr 7, ''
      to_append = to_cstr '/path2'
      eq OK, (fs.append_path path, to_append, 7)
      eq '/path2', (ffi.string path)

  describe 'mch_is_absolute_path', ->
    ffi.cdef 'int mch_is_absolute_path(char *fname);'

    mch_is_absolute_path = (filename) ->
      filename = to_cstr filename
      fs.mch_is_absolute_path filename

    it 'returns true if filename starts with a slash', ->
      eq OK, mch_is_absolute_path '/some/directory/'

    it 'returns true if filename starts with a tilde', ->
      eq OK, mch_is_absolute_path '~/in/my/home~/directory'

    it 'returns false if filename starts not with slash nor tilde', ->
      eq FAIL, mch_is_absolute_path 'not/in/my/home~/directory'

  describe 'mch_isdir', ->
    mch_isdir = (name) ->
      fs.mch_isdir (to_cstr name)

    it 'returns false if an empty string is given', ->
      eq FALSE, (mch_isdir '')

    it 'returns false if a nonexisting directory is given', ->
      eq FALSE, (mch_isdir 'non-existing-directory')

    it 'returns false if a nonexisting absolute directory is given', ->
      eq FALSE, (mch_isdir '/non-existing-directory')

    it 'returns false if an existing file is given', ->
      eq FALSE, (mch_isdir 'unit-test-directory/test.file')

    it 'returns true if the current directory is given', ->
      eq TRUE, (mch_isdir '.')

    it 'returns true if the parent directory is given', ->
      eq TRUE, (mch_isdir '..')

    it 'returns true if an arbitrary directory is given', ->
      eq TRUE, (mch_isdir 'unit-test-directory')

    it 'returns true if an absolute directory is given', ->
      eq TRUE, (mch_isdir directory)

  describe 'mch_can_exe', ->
    mch_can_exe = (name) ->
      fs.mch_can_exe (to_cstr name)

    it 'returns false when given a directory', ->
      eq FALSE, (mch_can_exe './unit-test-directory')

    it 'returns false when given a regular file without executable bit set', ->
      eq FALSE, (mch_can_exe 'unit-test-directory/test.file')

    it 'returns false when the given file does not exists', ->
      eq FALSE, (mch_can_exe 'does-not-exist.file')

    it 'returns true when given an executable inside $PATH', ->
      eq TRUE, (mch_can_exe executable_name)

    it 'returns true when given an executable relative to the current dir', ->
      old_dir = lfs.currentdir!
      lfs.chdir directory
      relative_executable = './' .. executable_name
      eq TRUE, (mch_can_exe relative_executable)
      lfs.chdir old_dir

  describe 'file permissions', ->
    mch_getperm = (filename) ->
      perm = fs.mch_getperm (to_cstr filename)
      tonumber perm

    mch_setperm = (filename, perm) ->
      fs.mch_setperm (to_cstr filename), perm

    bit_set = (number, check_bit) ->
      if 0 == (bit.band number, check_bit) then false else true

    set_bit = (number, to_set) ->
      return bit.bor number, to_set

    unset_bit = (number, to_unset) ->
      return bit.band number, (bit.bnot to_unset)

    describe 'mch_getperm', ->
      it 'returns -1 when the given file does not exist', ->
        eq -1, (mch_getperm 'non-existing-file')

      it 'returns a perm > 0 when given an existing file', -> 
        assert.is_true (mch_getperm 'unit-test-directory') > 0

      it 'returns S_IRUSR when the file is readable', ->
        perm = mch_getperm 'unit-test-directory'
        assert.is_true (bit_set perm, ffi.C.kS_IRUSR)

    describe 'mch_setperm', ->
      it 'can set and unset the executable bit of a file', ->
        perm = mch_getperm 'unit-test-directory/test.file'

        perm = unset_bit perm, ffi.C.kS_IXUSR
        eq OK, (mch_setperm 'unit-test-directory/test.file', perm)

        perm = mch_getperm 'unit-test-directory/test.file'
        assert.is_false (bit_set perm, ffi.C.kS_IXUSR)

        perm = set_bit perm, ffi.C.kS_IXUSR
        eq OK, mch_setperm 'unit-test-directory/test.file', perm

        perm = mch_getperm 'unit-test-directory/test.file'
        assert.is_true (bit_set perm, ffi.C.kS_IXUSR)

      it 'fails if given file does not exist', ->
        perm = ffi.C.kS_IXUSR
        eq FAIL, (mch_setperm 'non-existing-file', perm)
