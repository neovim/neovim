{:cimport, :cppimport, :internalize, :eq, :neq, :ffi, :lib, :cstr, :to_cstr, :OK, :FAIL} = require 'test.unit.helpers'
require 'lfs'
require 'bit'

fs = cimport './src/nvim/os/os.h'

cppimport 'sys/stat.h'
cppimport 'sys/fcntl.h'
cppimport 'sys/errno.h'

assert_file_exists = (filepath) ->
  eq false, nil == (lfs.attributes filepath, 'r')

assert_file_does_not_exist = (filepath) ->
  eq true, nil == (lfs.attributes filepath, 'r')

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

    os_fchown = (filename, user_id, group_id) ->
      fd = ffi.C.open filename, 0
      res = fs.os_fchown fd, user_id, group_id
      ffi.C.close fd
      return res

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

    describe 'os_fchown', ->
      filename = 'unit-test-directory/test.file'

      it 'does not change owner and group if respective IDs are equal to -1', ->
        uid = lfs.attributes filename, 'uid'
        gid = lfs.attributes filename, 'gid'
        eq 0, os_fchown filename, -1, -1
        eq uid, lfs.attributes filename, 'uid'
        eq gid, lfs.attributes filename, 'gid'

      it 'owner of a file may change the group of the file
      to any group of which that owner is a member', ->
        -- Some systems may not have `id` utility.
        if (os.execute('id -G &> /dev/null') == 0)
          file_gid = lfs.attributes filename, 'gid'

          -- Gets ID of any group of which current user is a member except the
          -- group that owns the file.
          id_fd = io.popen('id -G')
          new_gid = id_fd\read '*n'
          if (new_gid == file_gid)
            new_gid = id_fd\read '*n'
          id_fd\close!

          -- User can be a member of only one group.
          -- In that case we can not perform this test.
          if new_gid
            eq 0, (os_fchown filename, -1, new_gid)
            eq new_gid, (lfs.attributes filename, 'gid')

      it 'returns nonzero if process has not enough permissions', ->
        -- On Windows `os_fchown` always returns 0
        -- because `uv_fs_chown` is no-op on this platform.
        if (ffi.os != 'Windows' and ffi.C.geteuid! != 0)
          -- chown to root
          neq 0, os_fchown filename, 0, 0

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

    os_remove = (path) ->
      fs.os_remove (to_cstr path)

    os_open = (path, flags, mode) ->
      fs.os_open (to_cstr path), flags, mode

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
      before_each ->
        (io.open 'unit-test-directory/test_remove.file', 'w').close!
      after_each ->
        os.remove 'unit-test-directory/test_remove.file'

      it 'returns non-zero when given a non-existing file', ->
        neq 0, (os_remove 'non-existing-file')

      it 'removes the given file and returns 0', ->
        f = 'unit-test-directory/test_remove.file'
        assert_file_exists f
        eq 0, (os_remove f)
        assert_file_does_not_exist f

    describe 'os_open', ->
      before_each ->
        (io.open 'unit-test-directory/test_existing.file', 'w').close!
      after_each ->
        os.remove 'unit-test-directory/test_existing.file'
        os.remove 'test_new_file'

      new_file = 'test_new_file'
      existing_file = 'unit-test-directory/test_existing.file'

      it 'returns -ENOENT for O_RDWR on a non-existing file', ->
        eq -ffi.C.kENOENT, (os_open 'non-existing-file', ffi.C.kO_RDWR, 0)

      it 'returns non-negative for O_CREAT on a non-existing file', ->
        assert_file_does_not_exist new_file
        assert.is_true 0 <= (os_open new_file, ffi.C.kO_CREAT, 0)

      it 'returns non-negative for O_CREAT on a existing file', ->
        assert_file_exists existing_file
        assert.is_true 0 <= (os_open existing_file, ffi.C.kO_CREAT, 0)

      it 'returns -EEXIST for O_CREAT|O_EXCL on a existing file', ->
        assert_file_exists existing_file
        eq -ffi.C.kEEXIST, (os_open existing_file, (bit.bor ffi.C.kO_CREAT, ffi.C.kO_EXCL), 0)

      it 'sets `rwx` permissions for O_CREAT 700', ->
        assert_file_does_not_exist new_file
        --create the file
        os_open new_file, ffi.C.kO_CREAT, tonumber("700", 8)
        --verify permissions
        eq 'rwx------', lfs.attributes(new_file)['permissions']

      it 'sets `rw` permissions for O_CREAT 600', ->
        assert_file_does_not_exist new_file
        --create the file
        os_open new_file, ffi.C.kO_CREAT, tonumber("600", 8)
        --verify permissions
        eq 'rw-------', lfs.attributes(new_file)['permissions']

      it 'returns a non-negative file descriptor for an existing file', ->
        assert.is_true 0 <= (os_open existing_file, ffi.C.kO_RDWR, 0)

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

      file_id_new = () ->
        file_info = ffi.new 'FileID[1]'
        file_info[0].inode = 0
        file_info[0].device_id = 0
        file_info

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

      describe 'os_file_info_get_id', ->
        it 'extracts ino/dev from file_info into file_id', ->
          file_info = file_info_new!
          file_id = file_id_new!
          path = 'unit-test-directory/test.file'
          assert.is_true (fs.os_get_file_info path, file_info)
          fs.os_file_info_get_id(file_info, file_id)
          eq file_info[0].stat.st_ino, file_id[0].inode
          eq file_info[0].stat.st_dev, file_id[0].device_id

      describe 'os_file_info_get_inode', ->
        it 'returns the inode from file_info', ->
          file_info = file_info_new!
          path = 'unit-test-directory/test.file'
          assert.is_true (fs.os_get_file_info path, file_info)
          inode = fs.os_file_info_get_inode(file_info)
          eq file_info[0].stat.st_ino, inode

      describe 'os_get_file_id', ->
        it 'returns false if given an non-existing file', ->
          file_id = file_id_new!
          assert.is_false (fs.os_get_file_id '/non-existent', file_id)

        it 'returns true if given an existing file and fills file_id', ->
          file_id = file_id_new!
          path = 'unit-test-directory/test.file'
          assert.is_true (fs.os_get_file_id path, file_id)
          assert.is_true 0 < file_id[0].inode
          assert.is_true 0 < file_id[0].device_id

      describe 'os_file_id_equal', ->
        it 'returns true if two FileIDs are equal', ->
          file_id = file_id_new!
          path = 'unit-test-directory/test.file'
          assert.is_true (fs.os_get_file_id path, file_id)
          assert.is_true (fs.os_file_id_equal file_id, file_id)

        it 'returns false if two FileIDs are not equal', ->
          file_id_1 = file_id_new!
          file_id_2 = file_id_new!
          path_1 = 'unit-test-directory/test.file'
          path_2 = 'unit-test-directory/test_2.file'
          assert.is_true (fs.os_get_file_id path_1, file_id_1)
          assert.is_true (fs.os_get_file_id path_2, file_id_2)
          assert.is_false (fs.os_file_id_equal file_id_1, file_id_2)

      describe 'os_file_id_equal_file_info', ->
        it 'returns true if file_id and file_info represent the same file', ->
          file_id = file_id_new!
          file_info = file_info_new!
          path = 'unit-test-directory/test.file'
          assert.is_true (fs.os_get_file_id path, file_id)
          assert.is_true (fs.os_get_file_info path, file_info)
          assert.is_true (fs.os_file_id_equal_file_info file_id, file_info)

        it 'returns false if file_id and file_info represent different files',->
          file_id = file_id_new!
          file_info = file_info_new!
          path_1 = 'unit-test-directory/test.file'
          path_2 = 'unit-test-directory/test_2.file'
          assert.is_true (fs.os_get_file_id path_1, file_id)
          assert.is_true (fs.os_get_file_info path_2, file_info)
          assert.is_false (fs.os_file_id_equal_file_info file_id, file_info)

