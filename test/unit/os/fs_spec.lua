local helpers = require('test.unit.helpers')

local cimport = helpers.cimport
local cppimport = helpers.cppimport
local internalize = helpers.internalize
local eq = helpers.eq
local neq = helpers.neq
local ffi = helpers.ffi
local lib = helpers.lib
local cstr = helpers.cstr
local to_cstr = helpers.to_cstr
local OK = helpers.OK
local FAIL = helpers.FAIL

require('lfs')
require('bit')

local fs = cimport('./src/nvim/os/os.h')
cppimport('sys/stat.h')
cppimport('sys/fcntl.h')
cppimport('sys/errno.h')

function assert_file_exists(filepath)
  eq(false, nil == (lfs.attributes(filepath, 'r')))
end

function assert_file_does_not_exist(filepath)
  eq(true, nil == (lfs.attributes(filepath, 'r')))
end

describe('fs function', function()

  setup(function()
    lfs.mkdir('unit-test-directory');
    io.open('unit-test-directory/test.file', 'w').close()
    io.open('unit-test-directory/test_2.file', 'w').close()
    lfs.link('test.file', 'unit-test-directory/test_link.file', true)
    -- Since the tests are executed, they are called by an executable. We use
    -- that executable for several asserts.
    absolute_executable = arg[0]
    -- Split absolute_executable into a directory and the actual file name for
    -- later usage.
    directory, executable_name = string.match(absolute_executable, '^(.*)/(.*)$')
  end)

  teardown(function()
    os.remove('unit-test-directory/test.file')
    os.remove('unit-test-directory/test_2.file')
    os.remove('unit-test-directory/test_link.file')
    lfs.rmdir('unit-test-directory')
  end)

  describe('os_dirname', function()
    function os_dirname(buf, len)
      return fs.os_dirname(buf, len)
    end

    before_each(function()
      len = (string.len(lfs.currentdir())) + 1
      buf = cstr(len, '')
    end)

    it('returns OK and writes current directory into the buffer if it is large\n    enough', function()
      eq(OK, (os_dirname(buf, len)))
      eq(lfs.currentdir(), (ffi.string(buf)))
    end)

    -- What kind of other failing cases are possible?
    it('returns FAIL if the buffer is too small', function()
      local buf = cstr((len - 1), '')
      eq(FAIL, (os_dirname(buf, (len - 1))))
    end)
  end)

  function os_isdir(name)
    return fs.os_isdir((to_cstr(name)))
  end

  describe('os_isdir', function()
    it('returns false if an empty string is given', function()
      eq(false, (os_isdir('')))
    end)

    it('returns false if a nonexisting directory is given', function()
      eq(false, (os_isdir('non-existing-directory')))
    end)

    it('returns false if a nonexisting absolute directory is given', function()
      eq(false, (os_isdir('/non-existing-directory')))
    end)

    it('returns false if an existing file is given', function()
      eq(false, (os_isdir('unit-test-directory/test.file')))
    end)

    it('returns true if the current directory is given', function()
      eq(true, (os_isdir('.')))
    end)

    it('returns true if the parent directory is given', function()
      eq(true, (os_isdir('..')))
    end)

    it('returns true if an arbitrary directory is given', function()
      eq(true, (os_isdir('unit-test-directory')))
    end)

    it('returns true if an absolute directory is given', function()
      eq(true, (os_isdir(directory)))
    end)
  end)

  describe('os_can_exe', function()
    function os_can_exe(name)
      return fs.os_can_exe((to_cstr(name)))
    end

    it('returns false when given a directory', function()
      eq(false, (os_can_exe('./unit-test-directory')))
    end)

    it('returns false when given a regular file without executable bit set', function()
      eq(false, (os_can_exe('unit-test-directory/test.file')))
    end)

    it('returns false when the given file does not exists', function()
      eq(false, (os_can_exe('does-not-exist.file')))
    end)

    it('returns true when given an executable inside $PATH', function()
      eq(true, (os_can_exe(executable_name)))
    end)

    it('returns true when given an executable relative to the current dir', function()
      local old_dir = lfs.currentdir()
      lfs.chdir(directory)
      local relative_executable = './' .. executable_name
      eq(true, (os_can_exe(relative_executable)))
      lfs.chdir(old_dir)
    end)
  end)

  describe('file permissions', function()
    function os_getperm(filename)
      local perm = fs.os_getperm((to_cstr(filename)))
      return tonumber(perm)
    end

    function os_setperm(filename, perm)
      return fs.os_setperm((to_cstr(filename)), perm)
    end

    function os_fchown(filename, user_id, group_id)
      local fd = ffi.C.open(filename, 0)
      local res = fs.os_fchown(fd, user_id, group_id)
      ffi.C.close(fd)
      return res
    end

    function os_file_is_readonly(filename)
      return fs.os_file_is_readonly((to_cstr(filename)))
    end

    function os_file_is_writable(filename)
      return fs.os_file_is_writable((to_cstr(filename)))
    end

    function bit_set(number, check_bit)
      return 0 ~= (bit.band(number, check_bit))
    end

    function set_bit(number, to_set)
      return bit.bor(number, to_set)
    end

    function unset_bit(number, to_unset)
      return bit.band(number, (bit.bnot(to_unset)))
    end

    describe('os_getperm', function()
      it('returns -1 when the given file does not exist', function()
        eq(-1, (os_getperm('non-existing-file')))
      end)

      it('returns a perm > 0 when given an existing file', function()
        assert.is_true((os_getperm('unit-test-directory')) > 0)
      end)

      it('returns S_IRUSR when the file is readable', function()
        local perm = os_getperm('unit-test-directory')
        assert.is_true((bit_set(perm, ffi.C.kS_IRUSR)))
      end)
    end)

    describe('os_setperm', function()
      it('can set and unset the executable bit of a file', function()
        local perm = os_getperm('unit-test-directory/test.file')
        perm = unset_bit(perm, ffi.C.kS_IXUSR)
        eq(OK, (os_setperm('unit-test-directory/test.file', perm)))
        perm = os_getperm('unit-test-directory/test.file')
        assert.is_false((bit_set(perm, ffi.C.kS_IXUSR)))
        perm = set_bit(perm, ffi.C.kS_IXUSR)
        eq(OK, os_setperm('unit-test-directory/test.file', perm))
        perm = os_getperm('unit-test-directory/test.file')
        assert.is_true((bit_set(perm, ffi.C.kS_IXUSR)))
      end)

      it('fails if given file does not exist', function()
        local perm = ffi.C.kS_IXUSR
        eq(FAIL, (os_setperm('non-existing-file', perm)))
      end)
    end)

    describe('os_fchown', function()
      local filename = 'unit-test-directory/test.file'
      it('does not change owner and group if respective IDs are equal to -1', function()
        local uid = lfs.attributes(filename, 'uid')
        local gid = lfs.attributes(filename, 'gid')
        eq(0, os_fchown(filename, -1, -1))
        eq(uid, lfs.attributes(filename, 'uid'))
        return eq(gid, lfs.attributes(filename, 'gid'))
      end)

      it('owner of a file may change the group of the file to any group of which that owner is a member', function()
        -- Some systems may not have `id` utility.
        if (os.execute('id -G &> /dev/null') == 0) then
          local file_gid = lfs.attributes(filename, 'gid')

          -- Gets ID of any group of which current user is a member except the
          -- group that owns the file.
          local id_fd = io.popen('id -G')
          local new_gid = id_fd:read('*n')
          if (new_gid == file_gid) then
            new_gid = id_fd:read('*n')
          end
          id_fd:close()

          -- User can be a member of only one group.
          -- In that case we can not perform this test.
          if new_gid then
            eq(0, (os_fchown(filename, -1, new_gid)))
            eq(new_gid, (lfs.attributes(filename, 'gid')))
          end
        end
      end)

      it('returns nonzero if process has not enough permissions', function()
        -- On Windows `os_fchown` always returns 0
        -- because `uv_fs_chown` is no-op on this platform.
        if (ffi.os ~= 'Windows' and ffi.C.geteuid() ~= 0) then
          -- chown to root
          neq(0, os_fchown(filename, 0, 0))
        end
      end)
    end)

    describe('os_file_is_readonly', function()
      it('returns true if the file is readonly', function()
        local perm = os_getperm('unit-test-directory/test.file')
        local perm_orig = perm
        perm = unset_bit(perm, ffi.C.kS_IWUSR)
        perm = unset_bit(perm, ffi.C.kS_IWGRP)
        perm = unset_bit(perm, ffi.C.kS_IWOTH)
        eq(OK, (os_setperm('unit-test-directory/test.file', perm)))
        eq(true, os_file_is_readonly('unit-test-directory/test.file'))
        eq(OK, (os_setperm('unit-test-directory/test.file', perm_orig)))
      end)

      it('returns false if the file is writable', function()
        eq(false, os_file_is_readonly('unit-test-directory/test.file'))
      end)
    end)

    describe('os_file_is_writable', function()
      it('returns 0 if the file is readonly', function()
        local perm = os_getperm('unit-test-directory/test.file')
        local perm_orig = perm
        perm = unset_bit(perm, ffi.C.kS_IWUSR)
        perm = unset_bit(perm, ffi.C.kS_IWGRP)
        perm = unset_bit(perm, ffi.C.kS_IWOTH)
        eq(OK, (os_setperm('unit-test-directory/test.file', perm)))
        eq(0, os_file_is_writable('unit-test-directory/test.file'))
        eq(OK, (os_setperm('unit-test-directory/test.file', perm_orig)))
      end)

      it('returns 1 if the file is writable', function()
        eq(1, os_file_is_writable('unit-test-directory/test.file'))
      end)

      it('returns 2 when given a folder with rights to write into', function()
        eq(2, os_file_is_writable('unit-test-directory'))
      end)
    end)
  end)

  describe('file operations', function()
    function os_file_exists(filename)
      return fs.os_file_exists((to_cstr(filename)))
    end

    function os_rename(path, new_path)
      return fs.os_rename((to_cstr(path)), (to_cstr(new_path)))
    end

    function os_remove(path)
      return fs.os_remove((to_cstr(path)))
    end

    function os_open(path, flags, mode)
      return fs.os_open((to_cstr(path)), flags, mode)
    end

    describe('os_file_exists', function()
      it('returns false when given a non-existing file', function()
        eq(false, (os_file_exists('non-existing-file')))
      end)

      it('returns true when given an existing file', function()
        eq(true, (os_file_exists('unit-test-directory/test.file')))
      end)
    end)

    describe('os_rename', function()
      local test = 'unit-test-directory/test.file'
      local not_exist = 'unit-test-directory/not_exist.file'

      it('can rename file if destination file does not exist', function()
        eq(OK, (os_rename(test, not_exist)))
        eq(false, (os_file_exists(test)))
        eq(true, (os_file_exists(not_exist)))
        eq(OK, (os_rename(not_exist, test)))  -- restore test file
      end)

      it('fail if source file does not exist', function()
        eq(FAIL, (os_rename(not_exist, test)))
      end)

      it('can overwrite destination file if it exists', function()
        local other = 'unit-test-directory/other.file'
        local file = io.open(other, 'w')
        file:write('other')
        file:flush()
        file:close()

        eq(OK, (os_rename(other, test)))
        eq(false, (os_file_exists(other)))
        eq(true, (os_file_exists(test)))
        file = io.open(test, 'r')
        eq('other', (file:read('*all')))
        file:close()
      end)
    end)

    describe('os_remove', function()
      before_each(function()
        io.open('unit-test-directory/test_remove.file', 'w').close()
      end)

      after_each(function()
        os.remove('unit-test-directory/test_remove.file')
      end)

      it('returns non-zero when given a non-existing file', function()
        neq(0, (os_remove('non-existing-file')))
      end)

      it('removes the given file and returns 0', function()
        local f = 'unit-test-directory/test_remove.file'
        assert_file_exists(f)
        eq(0, (os_remove(f)))
        assert_file_does_not_exist(f)
      end)
    end)

    describe('os_open', function()
      before_each(function()
        io.open('unit-test-directory/test_existing.file', 'w').close()
      end)

      after_each(function()
        os.remove('unit-test-directory/test_existing.file')
        os.remove('test_new_file')
      end)

      local new_file = 'test_new_file'
      local existing_file = 'unit-test-directory/test_existing.file'

      it('returns -ENOENT for O_RDWR on a non-existing file', function()
        eq(-ffi.C.kENOENT, (os_open('non-existing-file', ffi.C.kO_RDWR, 0)))
      end)

      it('returns non-negative for O_CREAT on a non-existing file', function()
        assert_file_does_not_exist(new_file)
        assert.is_true(0 <= (os_open(new_file, ffi.C.kO_CREAT, 0)))
      end)

      it('returns non-negative for O_CREAT on a existing file', function()
        assert_file_exists(existing_file)
        assert.is_true(0 <= (os_open(existing_file, ffi.C.kO_CREAT, 0)))
      end)

      it('returns -EEXIST for O_CREAT|O_EXCL on a existing file', function()
        assert_file_exists(existing_file)
        eq(-ffi.C.kEEXIST, (os_open(existing_file, (bit.bor(ffi.C.kO_CREAT, ffi.C.kO_EXCL)), 0)))
      end)

      it('sets `rwx` permissions for O_CREAT 700', function()
        assert_file_does_not_exist(new_file)
        --create the file
        os_open(new_file, ffi.C.kO_CREAT, tonumber("700", 8))
        --verify permissions
        eq('rwx------', lfs.attributes(new_file)['permissions'])
      end)

      it('sets `rw` permissions for O_CREAT 600', function()
        assert_file_does_not_exist(new_file)
        --create the file
        os_open(new_file, ffi.C.kO_CREAT, tonumber("600", 8))
        --verify permissions
        eq('rw-------', lfs.attributes(new_file)['permissions'])
      end)

      it('returns a non-negative file descriptor for an existing file', function()
        assert.is_true(0 <= (os_open(existing_file, ffi.C.kO_RDWR, 0)))
      end)
    end)
  end)

  describe('folder operations', function()
    function os_mkdir(path, mode)
      return fs.os_mkdir(to_cstr(path), mode)
    end

    function os_rmdir(path)
      return fs.os_rmdir(to_cstr(path))
    end

    describe('os_mkdir', function()
      it('returns non-zero when given an already existing directory', function()
        local mode = ffi.C.kS_IRUSR + ffi.C.kS_IWUSR + ffi.C.kS_IXUSR
        neq(0, (os_mkdir('unit-test-directory', mode)))
      end)

      it('creates a directory and returns 0', function()
        local mode = ffi.C.kS_IRUSR + ffi.C.kS_IWUSR + ffi.C.kS_IXUSR
        eq(false, (os_isdir('unit-test-directory/new-dir')))
        eq(0, (os_mkdir('unit-test-directory/new-dir', mode)))
        eq(true, (os_isdir('unit-test-directory/new-dir')))
        lfs.rmdir('unit-test-directory/new-dir')
      end)
    end)

    describe('os_rmdir', function()
      it('returns non_zero when given a non-existing directory', function()
        neq(0, (os_rmdir('non-existing-directory')))
      end)

      it('removes the given directory and returns 0', function()
        lfs.mkdir('unit-test-directory/new-dir')
        eq(0, (os_rmdir('unit-test-directory/new-dir', mode)))
        eq(false, (os_isdir('unit-test-directory/new-dir')))
      end)
    end)
  end)

  describe('FileInfo', function()
    function file_info_new()
      local file_info = ffi.new('FileInfo[1]')
      file_info[0].stat.st_ino = 0
      file_info[0].stat.st_dev = 0
      return file_info
    end

    function is_file_info_filled(file_info)
      return file_info[0].stat.st_ino > 0 and file_info[0].stat.st_dev > 0
    end

    function file_id_new()
      local file_info = ffi.new('FileID[1]')
      file_info[0].inode = 0
      file_info[0].device_id = 0
      return file_info
    end

    describe('os_get_file_info', function()
      it('returns false if given a non-existing file', function()
        local file_info = file_info_new()
        assert.is_false((fs.os_get_file_info('/non-existent', file_info)))
      end)

      it('returns true if given an existing file and fills file_info', function()
        local file_info = file_info_new()
        local path = 'unit-test-directory/test.file'
        assert.is_true((fs.os_get_file_info(path, file_info)))
        assert.is_true((is_file_info_filled(file_info)))
      end)

      it('returns the file info of the linked file, not the link', function()
        local file_info = file_info_new()
        local path = 'unit-test-directory/test_link.file'
        assert.is_true((fs.os_get_file_info(path, file_info)))
        assert.is_true((is_file_info_filled(file_info)))
        local mode = tonumber(file_info[0].stat.st_mode)
        return eq(ffi.C.kS_IFREG, (bit.band(mode, ffi.C.kS_IFMT)))
      end)
    end)

    describe('os_get_file_info_link', function()
      it('returns false if given a non-existing file', function()
        local file_info = file_info_new()
        assert.is_false((fs.os_get_file_info_link('/non-existent', file_info)))
      end)

      it('returns true if given an existing file and fills file_info', function()
        local file_info = file_info_new()
        local path = 'unit-test-directory/test.file'
        assert.is_true((fs.os_get_file_info_link(path, file_info)))
        assert.is_true((is_file_info_filled(file_info)))
      end)

      it('returns the file info of the link, not the linked file', function()
        local file_info = file_info_new()
        local path = 'unit-test-directory/test_link.file'
        assert.is_true((fs.os_get_file_info_link(path, file_info)))
        assert.is_true((is_file_info_filled(file_info)))
        local mode = tonumber(file_info[0].stat.st_mode)
        eq(ffi.C.kS_IFLNK, (bit.band(mode, ffi.C.kS_IFMT)))
      end)
    end)

    describe('os_get_file_info_fd', function()
      it('returns false if given an invalid file descriptor', function()
        local file_info = file_info_new()
        assert.is_false((fs.os_get_file_info_fd(-1, file_info)))
      end)

      it('returns true if given a file descriptor and fills file_info', function()
        local file_info = file_info_new()
        local path = 'unit-test-directory/test.file'
        local fd = ffi.C.open(path, 0)
        assert.is_true((fs.os_get_file_info_fd(fd, file_info)))
        assert.is_true((is_file_info_filled(file_info)))
        ffi.C.close(fd)
      end)
    end)

    describe('os_file_info_id_equal', function()
      it('returns false if file infos represent different files', function()
        local file_info_1 = file_info_new()
        local file_info_2 = file_info_new()
        local path_1 = 'unit-test-directory/test.file'
        local path_2 = 'unit-test-directory/test_2.file'
        assert.is_true((fs.os_get_file_info(path_1, file_info_1)))
        assert.is_true((fs.os_get_file_info(path_2, file_info_2)))
        assert.is_false((fs.os_file_info_id_equal(file_info_1, file_info_2)))
      end)

      it('returns true if file infos represent the same file', function()
        local file_info_1 = file_info_new()
        local file_info_2 = file_info_new()
        local path = 'unit-test-directory/test.file'
        assert.is_true((fs.os_get_file_info(path, file_info_1)))
        assert.is_true((fs.os_get_file_info(path, file_info_2)))
        assert.is_true((fs.os_file_info_id_equal(file_info_1, file_info_2)))
      end)

      it('returns true if file infos represent the same file (symlink)', function()
        local file_info_1 = file_info_new()
        local file_info_2 = file_info_new()
        local path_1 = 'unit-test-directory/test.file'
        local path_2 = 'unit-test-directory/test_link.file'
        assert.is_true((fs.os_get_file_info(path_1, file_info_1)))
        assert.is_true((fs.os_get_file_info(path_2, file_info_2)))
        assert.is_true((fs.os_file_info_id_equal(file_info_1, file_info_2)))
      end)
    end)

    describe('os_file_info_get_id', function()
      it('extracts ino/dev from file_info into file_id', function()
        local file_info = file_info_new()
        local file_id = file_id_new()
        local path = 'unit-test-directory/test.file'
        assert.is_true((fs.os_get_file_info(path, file_info)))
        fs.os_file_info_get_id(file_info, file_id)
        eq(file_info[0].stat.st_ino, file_id[0].inode)
        eq(file_info[0].stat.st_dev, file_id[0].device_id)
      end)
    end)

    describe('os_file_info_get_inode', function()
      it('returns the inode from file_info', function()
        local file_info = file_info_new()
        local path = 'unit-test-directory/test.file'
        assert.is_true((fs.os_get_file_info(path, file_info)))
        local inode = fs.os_file_info_get_inode(file_info)
        eq(file_info[0].stat.st_ino, inode)
      end)
    end)

    describe('os_get_file_id', function()
      it('returns false if given an non-existing file', function()
        local file_id = file_id_new()
        assert.is_false((fs.os_get_file_id('/non-existent', file_id)))
      end)

      it('returns true if given an existing file and fills file_id', function()
        local file_id = file_id_new()
        local path = 'unit-test-directory/test.file'
        assert.is_true((fs.os_get_file_id(path, file_id)))
        assert.is_true(0 < file_id[0].inode)
        assert.is_true(0 < file_id[0].device_id)
      end)
    end)

    describe('os_file_id_equal', function()
      it('returns true if two FileIDs are equal', function()
        local file_id = file_id_new()
        local path = 'unit-test-directory/test.file'
        assert.is_true((fs.os_get_file_id(path, file_id)))
        assert.is_true((fs.os_file_id_equal(file_id, file_id)))
      end)

      it('returns false if two FileIDs are not equal', function()
        local file_id_1 = file_id_new()
        local file_id_2 = file_id_new()
        local path_1 = 'unit-test-directory/test.file'
        local path_2 = 'unit-test-directory/test_2.file'
        assert.is_true((fs.os_get_file_id(path_1, file_id_1)))
        assert.is_true((fs.os_get_file_id(path_2, file_id_2)))
        assert.is_false((fs.os_file_id_equal(file_id_1, file_id_2)))
      end)
    end)

    describe('os_file_id_equal_file_info', function()
      it('returns true if file_id and file_info represent the same file', function()
        local file_id = file_id_new()
        local file_info = file_info_new()
        local path = 'unit-test-directory/test.file'
        assert.is_true((fs.os_get_file_id(path, file_id)))
        assert.is_true((fs.os_get_file_info(path, file_info)))
        assert.is_true((fs.os_file_id_equal_file_info(file_id, file_info)))
      end)

      it('returns false if file_id and file_info represent different files', function()
        local file_id = file_id_new()
        local file_info = file_info_new()
        local path_1 = 'unit-test-directory/test.file'
        local path_2 = 'unit-test-directory/test_2.file'
        assert.is_true((fs.os_get_file_id(path_1, file_id)))
        assert.is_true((fs.os_get_file_info(path_2, file_info)))
        assert.is_false((fs.os_file_id_equal_file_info(file_id, file_info)))
      end)
    end)
  end)
end)
