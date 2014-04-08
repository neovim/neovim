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
int os_dirname(char_u *buf, int len);
bool os_isdir(char_u * name);
bool is_executable(char_u *name);
bool os_can_exe(char_u *name);
int32_t os_getperm(char_u *name);
int os_setperm(char_u *name, long perm);
bool os_file_exists(const char_u *name);
bool os_file_is_readonly(char *fname);
int os_file_is_writable(const char *name);
int os_rename(const char_u *path, const char_u *new_path);
]]

-- import constants parsed by ffi
{:OK, :FAIL} = lib

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

  describe 'os_dirname', ->
    os_dirname = (buf, len) ->
      fs.os_dirname buf, len

    before_each ->
      export len = (string.len lfs.currentdir!) + 1
      export buf = cstr len, ''

    it 'returns OK and writes current directory into the buffer if it is large
    enough', ->
      eq OK, (os_dirname buf, len)
      eq lfs.currentdir!, (ffi.string buf)

    -- What kind of other failing cases are possible?
    it 'returns FAIL if the buffer is too small', ->
      buf = cstr (len-1), ''
      eq FAIL, (os_dirname buf, (len-1))

  describe 'os_full_dir_name', ->
    ffi.cdef 'int os_full_dir_name(char *directory, char *buffer, int len);'

    os_full_dir_name = (directory, buffer, len) ->
      directory = to_cstr directory
      fs.os_full_dir_name directory, buffer, len

    before_each ->
      -- Create empty string buffer which will contain the resulting path.
      export len = (string.len lfs.currentdir!) + 22
      export buffer = cstr len, ''

    it 'returns the absolute directory name of a given relative one', ->
      result = os_full_dir_name '..', buffer, len
      eq OK, result
      old_dir = lfs.currentdir!
      lfs.chdir '..'
      expected = lfs.currentdir!
      lfs.chdir old_dir
      eq expected, (ffi.string buffer)

    it 'returns the current directory name if the given string is empty', ->
      eq OK, (os_full_dir_name '', buffer, len)
      eq lfs.currentdir!, (ffi.string buffer)

    it 'fails if the given directory does not exist', ->
      eq FAIL, os_full_dir_name('does_not_exist', buffer, len)

    it 'works with a normal relative dir', ->
      result = os_full_dir_name('unit-test-directory', buffer, len)
      eq lfs.currentdir! .. '/unit-test-directory', (ffi.string buffer)
      eq OK, result

  describe 'os_isdir', ->
    os_isdir = (name) ->
      fs.os_isdir (to_cstr name)

    it 'returns false if an empty string is given', ->
      eq false, (os_isdir '')

    it 'returns false if a nonexisting directory is given', ->
      eq false, (os_isdir 'non-existing-directory')

    it 'returns false if a nonexisting absolute directory is given', ->
      eq false, (os_isdir '/non-existing-directory')

    it 'returns false if an existing file is given', ->
      eq false, (os_isdir 'unit-test-directory/test.file')

    it 'returns true if the current directory is given', ->
      eq true, (os_isdir '.')

    it 'returns true if the parent directory is given', ->
      eq true, (os_isdir '..')

    it 'returns true if an arbitrary directory is given', ->
      eq true, (os_isdir 'unit-test-directory')

    it 'returns true if an absolute directory is given', ->
      eq true, (os_isdir directory)

  describe 'os_can_exe', ->
    os_can_exe = (name) ->
      fs.os_can_exe (to_cstr name)

    it 'returns false when given a directory', ->
      eq false, (os_can_exe './unit-test-directory')

    it 'returns false when given a regular file without executable bit set', ->
      eq false, (os_can_exe 'unit-test-directory/test.file')

    it 'returns false when the given file does not exists', ->
      eq false, (os_can_exe 'does-not-exist.file')

    it 'returns true when given an executable inside $PATH', ->
      eq true, (os_can_exe executable_name)

    it 'returns true when given an executable relative to the current dir', ->
      old_dir = lfs.currentdir!
      lfs.chdir directory
      relative_executable = './' .. executable_name
      eq true, (os_can_exe relative_executable)
      lfs.chdir old_dir

  describe 'file permissions', ->
    os_getperm = (filename) ->
      perm = fs.os_getperm (to_cstr filename)
      tonumber perm

    os_setperm = (filename, perm) ->
      fs.os_setperm (to_cstr filename), perm

    os_file_is_readonly = (filename) ->
      fs.os_file_is_readonly (to_cstr filename)

    os_file_is_writable = (filename) ->
      fs.os_file_is_writable (to_cstr filename)

    bit_set = (number, check_bit) ->
      if 0 == (bit.band number, check_bit) then false else true

    set_bit = (number, to_set) ->
      return bit.bor number, to_set

    unset_bit = (number, to_unset) ->
      return bit.band number, (bit.bnot to_unset)

    describe 'os_getperm', ->
      it 'returns -1 when the given file does not exist', ->
        eq -1, (os_getperm 'non-existing-file')

      it 'returns a perm > 0 when given an existing file', -> 
        assert.is_true (os_getperm 'unit-test-directory') > 0

      it 'returns S_IRUSR when the file is readable', ->
        perm = os_getperm 'unit-test-directory'
        assert.is_true (bit_set perm, ffi.C.kS_IRUSR)

    describe 'os_setperm', ->
      it 'can set and unset the executable bit of a file', ->
        perm = os_getperm 'unit-test-directory/test.file'

        perm = unset_bit perm, ffi.C.kS_IXUSR
        eq OK, (os_setperm 'unit-test-directory/test.file', perm)

        perm = os_getperm 'unit-test-directory/test.file'
        assert.is_false (bit_set perm, ffi.C.kS_IXUSR)

        perm = set_bit perm, ffi.C.kS_IXUSR
        eq OK, os_setperm 'unit-test-directory/test.file', perm

        perm = os_getperm 'unit-test-directory/test.file'
        assert.is_true (bit_set perm, ffi.C.kS_IXUSR)

      it 'fails if given file does not exist', ->
        perm = ffi.C.kS_IXUSR
        eq FAIL, (os_setperm 'non-existing-file', perm)

    describe 'os_file_is_readonly', ->
      it 'returns true if the file is readonly', ->
        perm = os_getperm 'unit-test-directory/test.file'
        perm_orig = perm
        perm = unset_bit perm, ffi.C.kS_IWUSR
        perm = unset_bit perm, ffi.C.kS_IWGRP
        perm = unset_bit perm, ffi.C.kS_IWOTH
        eq OK, (os_setperm 'unit-test-directory/test.file', perm)
        eq true, os_file_is_readonly 'unit-test-directory/test.file'
        eq OK, (os_setperm 'unit-test-directory/test.file', perm_orig)

      it 'returns false if the file is writable', ->
        eq false, os_file_is_readonly 'unit-test-directory/test.file'

    describe 'os_file_is_writable', ->
      it 'returns 0 if the file is readonly', ->
        perm = os_getperm 'unit-test-directory/test.file'
        perm_orig = perm
        perm = unset_bit perm, ffi.C.kS_IWUSR
        perm = unset_bit perm, ffi.C.kS_IWGRP
        perm = unset_bit perm, ffi.C.kS_IWOTH
        eq OK, (os_setperm 'unit-test-directory/test.file', perm)
        eq 0, os_file_is_writable 'unit-test-directory/test.file'
        eq OK, (os_setperm 'unit-test-directory/test.file', perm_orig)

      it 'returns 1 if the file is writable', ->
        eq 1, os_file_is_writable 'unit-test-directory/test.file'

      it 'returns 2 when given a folder with rights to write into', ->
        eq 2, os_file_is_writable 'unit-test-directory'

  describe 'file operations', ->
    os_file_exists = (filename) ->
      fs.os_file_exists (to_cstr filename)

    os_rename = (path, new_path) ->
      fs.os_rename (to_cstr path), (to_cstr new_path)

    describe 'os_file_exists', ->
      it 'returns false when given a non-existing file', ->
        eq false, (os_file_exists 'non-existing-file')

      it 'returns true when given an existing file', ->
        eq true, (os_file_exists 'unit-test-directory/test.file')

    describe 'os_rename', ->
      test = 'unit-test-directory/test.file'
      not_exist = 'unit-test-directory/not_exist.file'

      it 'can rename file if destination file does not exist', ->
        eq OK, (os_rename test, not_exist)
        eq false, (os_file_exists test)
        eq true, (os_file_exists not_exist)
        eq OK, (os_rename not_exist, test)  -- restore test file

      it 'fail if source file does not exist', ->
        eq FAIL, (os_rename not_exist, test)
  
      it 'can overwrite destination file if it exists', ->
        other = 'unit-test-directory/other.file'
        file = io.open other, 'w'
        file\write 'other'
        file\flush!
        file\close!

        eq OK, (os_rename other, test)
        eq false, (os_file_exists other)
        eq true, (os_file_exists test)
        file = io.open test, 'r'
        eq 'other', (file\read '*all')
        file\close!
