{:cimport, :cppimport, :internalize, :eq, :neq, :ffi, :lib, :cstr, :to_cstr} = require 'test.unit.helpers'
require 'lfs'
require 'bit'

fs = cimport './src/nvim/os/os.h'

-- TODO(aktau): define these constants "better"
FAIL = 0
OK = 1

cppimport 'sys/stat.h'

describe 'fs function', ->
  setup ->
    lfs.mkdir 'unit-test-directory'
    (io.open 'unit-test-directory/test.file', 'w').close!
    (io.open 'unit-test-directory/test_2.file', 'w').close!
    lfs.link 'test.file', 'unit-test-directory/test_link.file', true

    -- Since the tests are executed, they are called by an executable. We use
    -- that executable for several asserts.
    export absolute_executable = arg[0]

    -- Split absolute_executable into a directory and the actual file name for
    -- later usage.
    export directory, executable_name = string.match(absolute_executable, '^(.*)/(.*)$')

  teardown ->
    os.remove 'unit-test-directory/test.file'
    os.remove 'unit-test-directory/test_2.file'
    os.remove 'unit-test-directory/test_link.file'
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

  describe 'path_full_dir_name', ->
    path_full_dir_name = (directory, buffer, len) ->
      directory = to_cstr directory
      fs.path_full_dir_name directory, buffer, len

    before_each ->
      -- Create empty string buffer which will contain the resulting path.
      export len = (string.len lfs.currentdir!) + 22
      export buffer = cstr len, ''

    it 'returns the absolute directory name of a given relative one', ->
      result = path_full_dir_name '..', buffer, len
      eq OK, result
      old_dir = lfs.currentdir!
      lfs.chdir '..'
      expected = lfs.currentdir!
      lfs.chdir old_dir
      eq expected, (ffi.string buffer)

    it 'returns the current directory name if the given string is empty', ->
      eq OK, (path_full_dir_name '', buffer, len)
      eq lfs.currentdir!, (ffi.string buffer)

    it 'fails if the given directory does not exist', ->
      eq FAIL, path_full_dir_name('does_not_exist', buffer, len)

    it 'works with a normal relative dir', ->
      result = path_full_dir_name('unit-test-directory', buffer, len)
      eq lfs.currentdir! .. '/unit-test-directory', (ffi.string buffer)
      eq OK, result

  os_isdir = (name) ->
    fs.os_isdir (to_cstr name)

  describe 'os_isdir', ->
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
    setup ->
      (io.open 'unit-test-directory/test_remove.file', 'w').close!

    teardown ->
      os.remove 'unit-test-directory/test_remove.file'

    os_file_exists = (filename) ->
      fs.os_file_exists (to_cstr filename)

    os_rename = (path, new_path) ->
      fs.os_rename (to_cstr path), (to_cstr new_path)

    os_remove = (path) ->
      fs.os_remove (to_cstr path)

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

    describe 'os_remove', ->
      it 'returns non-zero when given a non-existing file', ->
        neq 0, (os_remove 'non-existing-file')

      it 'removes the given file and returns 0', ->
        eq true, (os_file_exists 'unit-test-directory/test_remove.file')
        eq 0, (os_remove 'unit-test-directory/test_remove.file')
        eq false, (os_file_exists 'unit-test-directory/test_remove.file')

  describe 'folder operations', ->
    os_mkdir = (path, mode) ->
      fs.os_mkdir (to_cstr path), mode

    os_rmdir = (path) ->
      fs.os_rmdir (to_cstr path)

    describe 'os_mkdir', ->
      it 'returns non-zero when given an already existing directory', ->
        mode = ffi.C.kS_IRUSR + ffi.C.kS_IWUSR + ffi.C.kS_IXUSR
        neq 0, (os_mkdir 'unit-test-directory', mode)

      it 'creates a directory and returns 0', ->
        mode = ffi.C.kS_IRUSR + ffi.C.kS_IWUSR + ffi.C.kS_IXUSR
        eq false, (os_isdir 'unit-test-directory/new-dir')
        eq 0, (os_mkdir 'unit-test-directory/new-dir', mode)
        eq true, (os_isdir 'unit-test-directory/new-dir')
        lfs.rmdir 'unit-test-directory/new-dir'

    describe 'os_rmdir', ->
      it 'returns non_zero when given a non-existing directory', ->
        neq 0, (os_rmdir 'non-existing-directory')

      it 'removes the given directory and returns 0', ->
        lfs.mkdir 'unit-test-directory/new-dir'
        eq 0, (os_rmdir 'unit-test-directory/new-dir', mode)
        eq false, (os_isdir 'unit-test-directory/new-dir')

    describe 'FileInfo', ->

      file_info_new = () ->
        file_info = ffi.new 'FileInfo[1]'
        file_info[0].stat.st_ino = 0
        file_info[0].stat.st_dev = 0
        file_info

      is_file_info_filled = (file_info) ->
        file_info[0].stat.st_ino > 0 and file_info[0].stat.st_dev > 0

      describe 'os_get_file_info', ->
        it 'returns false if given a non-existing file', ->
          file_info = file_info_new!
          assert.is_false (fs.os_get_file_info '/non-existent', file_info)

        it 'returns true if given an existing file and fills file_info', ->
          file_info = file_info_new!
          path = 'unit-test-directory/test.file'
          assert.is_true (fs.os_get_file_info path, file_info)
          assert.is_true (is_file_info_filled file_info)

        it 'returns the file info of the linked file, not the link', ->
          file_info = file_info_new!
          path = 'unit-test-directory/test_link.file'
          assert.is_true (fs.os_get_file_info path, file_info)
          assert.is_true (is_file_info_filled file_info)
          mode = tonumber file_info[0].stat.st_mode
          eq ffi.C.kS_IFREG, (bit.band mode, ffi.C.kS_IFMT)

      describe 'os_get_file_info_link', ->
        it 'returns false if given a non-existing file', ->
          file_info = file_info_new!
          assert.is_false (fs.os_get_file_info_link '/non-existent', file_info)

        it 'returns true if given an existing file and fills file_info', ->
          file_info = file_info_new!
          path = 'unit-test-directory/test.file'
          assert.is_true (fs.os_get_file_info_link path, file_info)
          assert.is_true (is_file_info_filled file_info)

        it 'returns the file info of the link, not the linked file', ->
          file_info = file_info_new!
          path = 'unit-test-directory/test_link.file'
          assert.is_true (fs.os_get_file_info_link path, file_info)
          assert.is_true (is_file_info_filled file_info)
          mode = tonumber file_info[0].stat.st_mode
          eq ffi.C.kS_IFLNK, (bit.band mode, ffi.C.kS_IFMT)

      describe 'os_get_file_info_fd', ->
        it 'returns false if given an invalid file descriptor', ->
          file_info = file_info_new!
          assert.is_false (fs.os_get_file_info_fd -1, file_info)

        it 'returns true if given a file descriptor and fills file_info', ->
          file_info = file_info_new!
          path = 'unit-test-directory/test.file'
          fd = ffi.C.open path, 0
          assert.is_true (fs.os_get_file_info_fd fd, file_info)
          assert.is_true (is_file_info_filled file_info)
          ffi.C.close fd

      describe 'os_file_info_id_equal', ->
        it 'returns false if file infos represent different files', ->
          file_info_1 = file_info_new!
          file_info_2 = file_info_new!
          path_1 = 'unit-test-directory/test.file'
          path_2 = 'unit-test-directory/test_2.file'
          assert.is_true (fs.os_get_file_info path_1, file_info_1)
          assert.is_true (fs.os_get_file_info path_2, file_info_2)
          assert.is_false (fs.os_file_info_id_equal file_info_1, file_info_2)

        it 'returns true if file infos represent the same file', ->
          file_info_1 = file_info_new!
          file_info_2 = file_info_new!
          path = 'unit-test-directory/test.file'
          assert.is_true (fs.os_get_file_info path, file_info_1)
          assert.is_true (fs.os_get_file_info path, file_info_2)
          assert.is_true (fs.os_file_info_id_equal file_info_1, file_info_2)

        it 'returns true if file infos represent the same file (symlink)', ->
          file_info_1 = file_info_new!
          file_info_2 = file_info_new!
          path_1 = 'unit-test-directory/test.file'
          path_2 = 'unit-test-directory/test_link.file'
          assert.is_true (fs.os_get_file_info path_1, file_info_1)
          assert.is_true (fs.os_get_file_info path_2, file_info_2)
          assert.is_true (fs.os_file_info_id_equal file_info_1, file_info_2)

