local uv = vim.uv
local bit = require('bit')

local t = require('test.unit.testutil')
local itp = t.gen_itp(it)

local cimport = t.cimport
local cppimport = t.cppimport
local internalize = t.internalize
local ok = t.ok
local eq = t.eq
local neq = t.neq
local ffi = t.ffi
local cstr = t.cstr
local to_cstr = t.to_cstr
local OK = t.OK
local FAIL = t.FAIL
local NULL = t.NULL
local mkdir = t.mkdir
local endswith = vim.endswith

local NODE_NORMAL = 0
local NODE_WRITABLE = 1

local fs = cimport('./src/nvim/os/os.h', './src/nvim/path.h')
cppimport('sys/stat.h')
cppimport('fcntl.h')
cimport('uv.h')

local s = ''
for i = 0, 255 do
  s = s .. (i == 0 and '\0' or ('%c'):format(i))
end
local fcontents = s:rep(16)

local directory = nil
local absolute_executable = nil
local executable_name = nil

local function set_bit(number, to_set)
  return bit.bor(number, to_set)
end

local function unset_bit(number, to_unset)
  return bit.band(number, (bit.bnot(to_unset)))
end

local function assert_file_exists(filepath)
  neq(nil, uv.fs_stat(filepath))
end

local function assert_file_does_not_exist(filepath)
  eq(nil, uv.fs_stat(filepath))
end

local function os_setperm(filename, perm)
  return fs.os_setperm((to_cstr(filename)), perm)
end

local function os_getperm(filename)
  local perm = fs.os_getperm((to_cstr(filename)))
  return tonumber(perm)
end

describe('fs.c', function()
  local function os_isdir(name)
    return fs.os_isdir(to_cstr(name))
  end

  before_each(function()
    mkdir('unit-test-directory')

    io.open('unit-test-directory/test.file', 'w'):close()

    io.open('unit-test-directory/test_2.file', 'w'):close()
    uv.fs_symlink('test.file', 'unit-test-directory/test_link.file')

    uv.fs_symlink('non_existing_file.file', 'unit-test-directory/test_broken_link.file')
    -- The tests are invoked with an absolute path to `busted` executable.
    absolute_executable = arg[0]
    -- Split the absolute_executable path into a directory and filename.
    directory, executable_name = string.match(absolute_executable, '^(.*)/(.*)$')
  end)

  after_each(function()
    os.remove('unit-test-directory/test.file')
    os.remove('unit-test-directory/test_2.file')
    os.remove('unit-test-directory/test_link.file')
    os.remove('unit-test-directory/test_hlink.file')
    os.remove('unit-test-directory/test_broken_link.file')
    uv.fs_rmdir('unit-test-directory')
  end)

  describe('os_dirname', function()
    itp('returns OK and writes current directory to the buffer', function()
      local length = string.len(uv.cwd()) + 1
      local buf = cstr(length, '')
      eq(OK, fs.os_dirname(buf, length))
      eq(uv.cwd(), ffi.string(buf))
    end)

    itp('returns FAIL if the buffer is too small', function()
      local length = string.len(uv.cwd()) + 1
      local buf = cstr(length - 1, '')
      eq(FAIL, fs.os_dirname(buf, length - 1))
    end)
  end)

  describe('os_chdir', function()
    itp('fails with path="~"', function()
      eq(false, os_isdir('~'), 'sanity check: no literal "~" directory')
      local length = 4096
      local expected_cwd = cstr(length, '')
      local cwd = cstr(length, '')
      eq(OK, fs.os_dirname(expected_cwd, length))

      -- os_chdir returns 0 for success, not OK (1).
      neq(0, fs.os_chdir('~')) -- fail
      neq(0, fs.os_chdir('~/')) -- fail

      eq(OK, fs.os_dirname(cwd, length))
      -- CWD did not change.
      eq(ffi.string(expected_cwd), ffi.string(cwd))
    end)
  end)

  describe('os_isdir', function()
    itp('returns false if an empty string is given', function()
      eq(false, (os_isdir('')))
    end)

    itp('returns false if a nonexisting directory is given', function()
      eq(false, (os_isdir('non-existing-directory')))
    end)

    itp('returns false if a nonexisting absolute directory is given', function()
      eq(false, (os_isdir('/non-existing-directory')))
    end)

    itp('returns false if an existing file is given', function()
      eq(false, (os_isdir('unit-test-directory/test.file')))
    end)

    itp('returns true if the current directory is given', function()
      eq(true, (os_isdir('.')))
    end)

    itp('returns true if the parent directory is given', function()
      eq(true, (os_isdir('..')))
    end)

    itp('returns true if an arbitrary directory is given', function()
      eq(true, (os_isdir('unit-test-directory')))
    end)

    itp('returns true if an absolute directory is given', function()
      eq(true, (os_isdir(directory)))
    end)
  end)

  describe('os_can_exe', function()
    local function os_can_exe(name)
      local buf = ffi.new('char *[1]')
      buf[0] = NULL
      local ce_ret = fs.os_can_exe(to_cstr(name), buf, true)

      -- When os_can_exe returns true, it must set the path.
      -- When it returns false, the path must be NULL.
      if ce_ret then
        neq(NULL, buf[0])
        return internalize(buf[0])
      else
        eq(NULL, buf[0])
        return nil
      end
    end

    local function cant_exe(name)
      eq(nil, os_can_exe(name))
    end

    local function exe(name)
      return os_can_exe(name)
    end

    itp('returns false when given a directory', function()
      cant_exe('./unit-test-directory')
    end)

    itp('returns false when given a regular file without executable bit set', function()
      cant_exe('unit-test-directory/test.file')
    end)

    itp('returns false when the given file does not exists', function()
      cant_exe('does-not-exist.file')
    end)

    itp('returns the absolute path when given an executable inside $PATH', function()
      local fullpath = exe('ls')
      eq(true, fs.path_is_absolute(to_cstr(fullpath)))
    end)

    itp('returns the absolute path when given an executable relative to the current dir', function()
      local old_dir = uv.cwd()

      uv.chdir(directory)

      -- Rely on currentdir to resolve symlinks, if any. Testing against
      -- the absolute path taken from arg[0] may result in failure where
      -- the path has a symlink in it.
      local canonical = uv.cwd() .. '/' .. executable_name
      local expected = exe(canonical)
      local relative_executable = './' .. executable_name
      local res = exe(relative_executable)

      -- Don't test yet; we need to chdir back first.
      uv.chdir(old_dir)
      eq(expected, res)
    end)
  end)

  describe('file permissions', function()
    local function os_fchown(filename, user_id, group_id)
      local fd = ffi.C.open(filename, 0)
      local res = fs.os_fchown(fd, user_id, group_id)
      ffi.C.close(fd)
      return res
    end

    local function os_file_is_readable(filename)
      return fs.os_file_is_readable((to_cstr(filename)))
    end

    local function os_file_is_writable(filename)
      return fs.os_file_is_writable((to_cstr(filename)))
    end

    local function bit_set(number, check_bit)
      return 0 ~= (bit.band(number, check_bit))
    end

    describe('os_getperm', function()
      itp('returns UV_ENOENT when the given file does not exist', function()
        eq(ffi.C.UV_ENOENT, (os_getperm('non-existing-file')))
      end)

      itp('returns a perm > 0 when given an existing file', function()
        assert.is_true((os_getperm('unit-test-directory')) > 0)
      end)

      itp('returns S_IRUSR when the file is readable', function()
        local perm = os_getperm('unit-test-directory')
        assert.is_true((bit_set(perm, ffi.C.kS_IRUSR)))
      end)
    end)

    describe('os_setperm', function()
      itp('can set and unset the executable bit of a file', function()
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

      itp('fails if given file does not exist', function()
        local perm = ffi.C.kS_IXUSR
        eq(FAIL, (os_setperm('non-existing-file', perm)))
      end)
    end)

    describe('os_fchown', function()
      local filename = 'unit-test-directory/test.file'
      itp('does not change owner and group if respective IDs are equal to -1', function()
        local uid = uv.fs_stat(filename).uid
        local gid = uv.fs_stat(filename).gid
        eq(0, os_fchown(filename, -1ULL, -1ULL))
        eq(uid, uv.fs_stat(filename).uid)
        return eq(gid, uv.fs_stat(filename).gid)
      end)

      -- Some systems may not have `id` utility.
      if os.execute('id -G > /dev/null 2>&1') ~= 0 then
        pending('skipped (missing `id` utility)', function() end)
      else
        itp(
          'owner of a file may change the group of the file to any group of which that owner is a member',
          function()
            local file_gid = uv.fs_stat(filename).gid

            -- Gets ID of any group of which current user is a member except the
            -- group that owns the file.
            local id_fd = io.popen('id -G')
            local new_gid = id_fd:read('*n')
            if new_gid == file_gid then
              new_gid = id_fd:read('*n')
            end
            id_fd:close()

            -- User can be a member of only one group.
            -- In that case we can not perform this test.
            if new_gid then
              eq(0, (os_fchown(filename, -1ULL, new_gid)))
              eq(new_gid, uv.fs_stat(filename).gid)
            end
          end
        )
      end

      if ffi.os == 'Windows' or ffi.C.geteuid() == 0 then
        pending('skipped (uv_fs_chown is no-op on Windows)', function() end)
      else
        itp('returns nonzero if process has not enough permissions', function()
          -- chown to root
          neq(0, os_fchown(filename, 0, 0))
        end)
      end
    end)

    describe('os_file_is_readable', function()
      itp('returns false if the file is not readable', function()
        local perm = os_getperm('unit-test-directory/test.file')
        perm = unset_bit(perm, ffi.C.kS_IRUSR)
        perm = unset_bit(perm, ffi.C.kS_IRGRP)
        perm = unset_bit(perm, ffi.C.kS_IROTH)
        eq(OK, (os_setperm('unit-test-directory/test.file', perm)))
        eq(false, os_file_is_readable('unit-test-directory/test.file'))
      end)

      itp('returns false if the file does not exist', function()
        eq(false, os_file_is_readable('unit-test-directory/what_are_you_smoking.gif'))
      end)

      itp('returns true if the file is readable', function()
        eq(true, os_file_is_readable('unit-test-directory/test.file'))
      end)
    end)

    describe('os_file_is_writable', function()
      itp('returns 0 if the file is readonly', function()
        local perm = os_getperm('unit-test-directory/test.file')
        perm = unset_bit(perm, ffi.C.kS_IWUSR)
        perm = unset_bit(perm, ffi.C.kS_IWGRP)
        perm = unset_bit(perm, ffi.C.kS_IWOTH)
        eq(OK, (os_setperm('unit-test-directory/test.file', perm)))
        eq(0, os_file_is_writable('unit-test-directory/test.file'))
      end)

      itp('returns 1 if the file is writable', function()
        eq(1, os_file_is_writable('unit-test-directory/test.file'))
      end)

      itp('returns 2 when given a folder with rights to write into', function()
        eq(2, os_file_is_writable('unit-test-directory'))
      end)
    end)
  end)

  describe('file operations', function()
    local function os_path_exists(filename)
      return fs.os_path_exists((to_cstr(filename)))
    end
    local function os_rename(path, new_path)
      return fs.os_rename((to_cstr(path)), (to_cstr(new_path)))
    end
    local function os_remove(path)
      return fs.os_remove((to_cstr(path)))
    end
    local function os_open(path, flags, mode)
      return fs.os_open((to_cstr(path)), flags, mode)
    end
    local function os_close(fd)
      return fs.os_close(fd)
    end
    -- For some reason if length of NUL-bytes-string is the same as `char[?]`
    -- size luajit crashes. Though it does not do so in this test suite, better
    -- be cautios and allocate more elements then needed. I only did this to
    -- strings.
    local function os_read(fd, size)
      local buf = nil
      if size == nil then
        size = 0
      else
        buf = ffi.new('char[?]', size + 1, ('\0'):rep(size))
      end
      local eof = ffi.new('bool[?]', 1, { true })
      local ret2 = fs.os_read(fd, eof, buf, size, false)
      local ret1 = eof[0]
      local ret3 = ''
      if buf ~= nil then
        ret3 = ffi.string(buf, size)
      end
      return ret1, ret2, ret3
    end
    local function os_readv(fd, sizes)
      local bufs = {}
      for i, size in ipairs(sizes) do
        bufs[i] = {
          iov_base = ffi.new('char[?]', size + 1, ('\0'):rep(size)),
          iov_len = size,
        }
      end
      local iov = ffi.new('struct iovec[?]', #sizes, bufs)
      local eof = ffi.new('bool[?]', 1, { true })
      local ret2 = fs.os_readv(fd, eof, iov, #sizes, false)
      local ret1 = eof[0]
      local ret3 = {}
      for i = 1, #sizes do
        -- Warning: iov may not be used.
        ret3[i] = ffi.string(bufs[i].iov_base, bufs[i].iov_len)
      end
      return ret1, ret2, ret3
    end
    local function os_write(fd, data)
      return fs.os_write(fd, data, data and #data or 0, false)
    end

    describe('os_path_exists', function()
      itp('returns false when given a non-existing file', function()
        eq(false, (os_path_exists('non-existing-file')))
      end)

      itp('returns true when given an existing file', function()
        eq(true, (os_path_exists('unit-test-directory/test.file')))
      end)

      itp('returns false when given a broken symlink', function()
        eq(false, (os_path_exists('unit-test-directory/test_broken_link.file')))
      end)

      itp('returns true when given a directory', function()
        eq(true, (os_path_exists('unit-test-directory')))
      end)
    end)

    describe('os_rename', function()
      local test = 'unit-test-directory/test.file'
      local not_exist = 'unit-test-directory/not_exist.file'

      itp('can rename file if destination file does not exist', function()
        eq(OK, (os_rename(test, not_exist)))
        eq(false, (os_path_exists(test)))
        eq(true, (os_path_exists(not_exist)))
        eq(OK, (os_rename(not_exist, test))) -- restore test file
      end)

      itp('fail if source file does not exist', function()
        eq(FAIL, (os_rename(not_exist, test)))
      end)

      itp('can overwrite destination file if it exists', function()
        local other = 'unit-test-directory/other.file'
        local file = io.open(other, 'w')
        file:write('other')
        file:flush()
        file:close()

        eq(OK, (os_rename(other, test)))
        eq(false, (os_path_exists(other)))
        eq(true, (os_path_exists(test)))
        file = io.open(test, 'r')
        eq('other', (file:read('*all')))
        file:close()
      end)
    end)

    describe('os_remove', function()
      before_each(function()
        io.open('unit-test-directory/test_remove.file', 'w'):close()
      end)

      after_each(function()
        os.remove('unit-test-directory/test_remove.file')
      end)

      itp('returns non-zero when given a non-existing file', function()
        neq(0, (os_remove('non-existing-file')))
      end)

      itp('removes the given file and returns 0', function()
        local f = 'unit-test-directory/test_remove.file'
        assert_file_exists(f)
        eq(0, (os_remove(f)))
        assert_file_does_not_exist(f)
      end)
    end)

    describe('os_dup', function()
      itp('returns new file descriptor', function()
        local dup0 = fs.os_dup(0)
        local dup1 = fs.os_dup(1)
        local dup2 = fs.os_dup(2)
        local tbl = {
          [0] = true,
          [1] = true,
          [2] = true,
          [tonumber(dup0)] = true,
          [tonumber(dup1)] = true,
          [tonumber(dup2)] = true,
        }
        local i = 0
        for _, _ in pairs(tbl) do
          i = i + 1
        end
        eq(i, 6) -- All fds must be unique
      end)
    end)

    describe('os_open', function()
      local new_file = 'test_new_file'
      local existing_file = 'unit-test-directory/test_existing.file'

      before_each(function()
        (io.open(existing_file, 'w')):close()
      end)

      after_each(function()
        os.remove(existing_file)
        os.remove(new_file)
      end)

      itp('returns UV_ENOENT for O_RDWR on a non-existing file', function()
        eq(ffi.C.UV_ENOENT, (os_open('non-existing-file', ffi.C.kO_RDWR, 0)))
      end)

      itp(
        'returns non-negative for O_CREAT on a non-existing file which then can be closed',
        function()
          assert_file_does_not_exist(new_file)
          local fd = os_open(new_file, ffi.C.kO_CREAT, 0)
          assert.is_true(0 <= fd)
          eq(0, os_close(fd))
        end
      )

      itp('returns non-negative for O_CREAT on a existing file which then can be closed', function()
        assert_file_exists(existing_file)
        local fd = os_open(existing_file, ffi.C.kO_CREAT, 0)
        assert.is_true(0 <= fd)
        eq(0, os_close(fd))
      end)

      itp('returns UV_EEXIST for O_CREAT|O_EXCL on a existing file', function()
        assert_file_exists(existing_file)
        eq(ffi.C.UV_EEXIST, (os_open(existing_file, (bit.bor(ffi.C.kO_CREAT, ffi.C.kO_EXCL)), 0)))
      end)

      itp('sets `rwx` permissions for O_CREAT 700 which then can be closed', function()
        assert_file_does_not_exist(new_file)
        --create the file
        local fd = os_open(new_file, ffi.C.kO_CREAT, tonumber('700', 8))
        --verify permissions
        eq(33216, uv.fs_stat(new_file).mode)
        eq(0, os_close(fd))
      end)

      itp('sets `rw` permissions for O_CREAT 600 which then can be closed', function()
        assert_file_does_not_exist(new_file)
        --create the file
        local fd = os_open(new_file, ffi.C.kO_CREAT, tonumber('600', 8))
        --verify permissions
        eq(33152, uv.fs_stat(new_file).mode)
        eq(0, os_close(fd))
      end)

      itp(
        'returns a non-negative file descriptor for an existing file which then can be closed',
        function()
          local fd = os_open(existing_file, ffi.C.kO_RDWR, 0)
          assert.is_true(0 <= fd)
          eq(0, os_close(fd))
        end
      )
    end)

    describe('os_close', function()
      itp('returns EBADF for negative file descriptors', function()
        eq(ffi.C.UV_EBADF, os_close(-1))
        eq(ffi.C.UV_EBADF, os_close(-1000))
      end)
    end)

    describe('os_read', function()
      local file = 'test-unit-os-fs_spec-os_read.dat'

      before_each(function()
        local f = io.open(file, 'w')
        f:write(fcontents)
        f:close()
      end)

      after_each(function()
        os.remove(file)
      end)

      itp('can read zero bytes from a file', function()
        local fd = os_open(file, ffi.C.kO_RDONLY, 0)
        ok(fd >= 0)
        eq({ false, 0, '' }, { os_read(fd, nil) })
        eq({ false, 0, '' }, { os_read(fd, 0) })
        eq(0, os_close(fd))
      end)

      itp('can read from a file multiple times', function()
        local fd = os_open(file, ffi.C.kO_RDONLY, 0)
        ok(fd >= 0)
        eq({ false, 2, '\000\001' }, { os_read(fd, 2) })
        eq({ false, 2, '\002\003' }, { os_read(fd, 2) })
        eq(0, os_close(fd))
      end)

      itp('can read the whole file at once and then report eof', function()
        local fd = os_open(file, ffi.C.kO_RDONLY, 0)
        ok(fd >= 0)
        eq({ false, #fcontents, fcontents }, { os_read(fd, #fcontents) })
        eq({ true, 0, ('\0'):rep(#fcontents) }, { os_read(fd, #fcontents) })
        eq(0, os_close(fd))
      end)

      itp('can read the whole file in two calls, one partially', function()
        local fd = os_open(file, ffi.C.kO_RDONLY, 0)
        ok(fd >= 0)
        eq(
          { false, #fcontents * 3 / 4, fcontents:sub(1, #fcontents * 3 / 4) },
          { os_read(fd, #fcontents * 3 / 4) }
        )
        eq({
          true,
          (#fcontents * 1 / 4),
          fcontents:sub(#fcontents * 3 / 4 + 1) .. ('\0'):rep(#fcontents * 2 / 4),
        }, { os_read(fd, #fcontents * 3 / 4) })
        eq(0, os_close(fd))
      end)
    end)

    describe('os_readv', function()
      -- Function may be absent
      if not pcall(function()
        return fs.os_readv
      end) then
        return
      end
      local file = 'test-unit-os-fs_spec-os_readv.dat'

      before_each(function()
        local f = io.open(file, 'w')
        f:write(fcontents)
        f:close()
      end)

      after_each(function()
        os.remove(file)
      end)

      itp('can read zero bytes from a file', function()
        local fd = os_open(file, ffi.C.kO_RDONLY, 0)
        ok(fd >= 0)
        eq({ false, 0, {} }, { os_readv(fd, {}) })
        eq({ false, 0, { '', '', '' } }, { os_readv(fd, { 0, 0, 0 }) })
        eq(0, os_close(fd))
      end)

      itp('can read from a file multiple times to a differently-sized buffers', function()
        local fd = os_open(file, ffi.C.kO_RDONLY, 0)
        ok(fd >= 0)
        eq({ false, 2, { '\000\001' } }, { os_readv(fd, { 2 }) })
        eq({ false, 5, { '\002\003', '\004\005\006' } }, { os_readv(fd, { 2, 3 }) })
        eq(0, os_close(fd))
      end)

      itp('can read the whole file at once and then report eof', function()
        local fd = os_open(file, ffi.C.kO_RDONLY, 0)
        ok(fd >= 0)
        eq({
          false,
          #fcontents,
          {
            fcontents:sub(1, #fcontents * 1 / 4),
            fcontents:sub(#fcontents * 1 / 4 + 1, #fcontents * 3 / 4),
            fcontents:sub(#fcontents * 3 / 4 + 1, #fcontents * 15 / 16),
            fcontents:sub(#fcontents * 15 / 16 + 1, #fcontents),
          },
        }, {
          os_readv(
            fd,
            { #fcontents * 1 / 4, #fcontents * 2 / 4, #fcontents * 3 / 16, #fcontents * 1 / 16 }
          ),
        })
        eq({ true, 0, { '\0' } }, { os_readv(fd, { 1 }) })
        eq(0, os_close(fd))
      end)

      itp('can read the whole file in two calls, one partially', function()
        local fd = os_open(file, ffi.C.kO_RDONLY, 0)
        ok(fd >= 0)
        eq(
          { false, #fcontents * 3 / 4, { fcontents:sub(1, #fcontents * 3 / 4) } },
          { os_readv(fd, { #fcontents * 3 / 4 }) }
        )
        eq({
          true,
          (#fcontents * 1 / 4),
          { fcontents:sub(#fcontents * 3 / 4 + 1) .. ('\0'):rep(#fcontents * 2 / 4) },
        }, { os_readv(fd, { #fcontents * 3 / 4 }) })
        eq(0, os_close(fd))
      end)
    end)

    describe('os_write', function()
      -- Function may be absent
      local file = 'test-unit-os-fs_spec-os_write.dat'

      before_each(function()
        local f = io.open(file, 'w')
        f:write(fcontents)
        f:close()
      end)

      after_each(function()
        os.remove(file)
      end)

      itp('can write zero bytes to a file', function()
        local fd = os_open(file, ffi.C.kO_WRONLY, 0)
        ok(fd >= 0)
        eq(0, os_write(fd, ''))
        eq(0, os_write(fd, nil))
        eq(fcontents, io.open(file, 'r'):read('*a'))
        eq(0, os_close(fd))
      end)

      itp('can write some data to a file', function()
        local fd = os_open(file, ffi.C.kO_WRONLY, 0)
        ok(fd >= 0)
        eq(3, os_write(fd, 'abc'))
        eq(4, os_write(fd, ' def'))
        eq('abc def' .. fcontents:sub(8), io.open(file, 'r'):read('*a'))
        eq(0, os_close(fd))
      end)
    end)

    describe('os_nodetype', function()
      before_each(function()
        os.remove('non-existing-file')
      end)

      itp('returns NODE_NORMAL for non-existing file', function()
        eq(NODE_NORMAL, fs.os_nodetype(to_cstr('non-existing-file')))
      end)

      itp('returns NODE_WRITABLE for /dev/stderr', function()
        eq(NODE_WRITABLE, fs.os_nodetype(to_cstr('/dev/stderr')))
      end)
    end)
  end)

  describe('folder operations', function()
    local function os_mkdir(path, mode)
      return fs.os_mkdir(to_cstr(path), mode)
    end

    local function os_rmdir(path)
      return fs.os_rmdir(to_cstr(path))
    end

    local function os_mkdir_recurse(path, mode)
      local failed_str = ffi.new('char *[1]', { nil })
      local created_str = ffi.new('char *[1]', { nil })
      local ret = fs.os_mkdir_recurse(path, mode, failed_str, created_str)
      local failed_dir = failed_str[0]
      if failed_dir ~= nil then
        failed_dir = ffi.string(failed_dir)
      end
      local created_dir = created_str[0]
      if created_dir ~= nil then
        created_dir = ffi.string(created_dir)
      end
      return ret, failed_dir, created_dir
    end

    describe('os_mkdir', function()
      itp('returns non-zero when given an already existing directory', function()
        local mode = ffi.C.kS_IRUSR + ffi.C.kS_IWUSR + ffi.C.kS_IXUSR
        neq(0, (os_mkdir('unit-test-directory', mode)))
      end)

      itp('creates a directory and returns 0', function()
        local mode = ffi.C.kS_IRUSR + ffi.C.kS_IWUSR + ffi.C.kS_IXUSR
        eq(false, (os_isdir('unit-test-directory/new-dir')))
        eq(0, (os_mkdir('unit-test-directory/new-dir', mode)))
        eq(true, (os_isdir('unit-test-directory/new-dir')))
        uv.fs_rmdir('unit-test-directory/new-dir')
      end)
    end)

    describe('os_mkdir_recurse', function()
      itp('returns zero when given an already existing directory', function()
        local mode = ffi.C.kS_IRUSR + ffi.C.kS_IWUSR + ffi.C.kS_IXUSR
        local ret, failed_dir, created_dir = os_mkdir_recurse('unit-test-directory', mode)
        eq(0, ret)
        eq(nil, failed_dir)
        eq(nil, created_dir)
      end)

      itp('fails to create a directory where there is a file', function()
        local mode = ffi.C.kS_IRUSR + ffi.C.kS_IWUSR + ffi.C.kS_IXUSR
        local ret, failed_dir, created_dir = os_mkdir_recurse('unit-test-directory/test.file', mode)
        neq(0, ret)
        eq('unit-test-directory/test.file', failed_dir)
        eq(nil, created_dir)
      end)

      itp('fails to create a directory where there is a file in path', function()
        local mode = ffi.C.kS_IRUSR + ffi.C.kS_IWUSR + ffi.C.kS_IXUSR
        local ret, failed_dir, created_dir =
          os_mkdir_recurse('unit-test-directory/test.file/test', mode)
        neq(0, ret)
        eq('unit-test-directory/test.file', failed_dir)
        eq(nil, created_dir)
      end)

      itp('succeeds to create a directory', function()
        local mode = ffi.C.kS_IRUSR + ffi.C.kS_IWUSR + ffi.C.kS_IXUSR
        local ret, failed_dir, created_dir =
          os_mkdir_recurse('unit-test-directory/new-dir-recurse', mode)
        eq(0, ret)
        eq(nil, failed_dir)
        ok(endswith(created_dir, 'unit-test-directory/new-dir-recurse'))
        eq(true, os_isdir('unit-test-directory/new-dir-recurse'))
        uv.fs_rmdir('unit-test-directory/new-dir-recurse')
        eq(false, os_isdir('unit-test-directory/new-dir-recurse'))
      end)

      itp('succeeds to create a directory ending with ///', function()
        local mode = ffi.C.kS_IRUSR + ffi.C.kS_IWUSR + ffi.C.kS_IXUSR
        local ret, failed_dir, created_dir =
          os_mkdir_recurse('unit-test-directory/new-dir-recurse///', mode)
        eq(0, ret)
        eq(nil, failed_dir)
        ok(endswith(created_dir, 'unit-test-directory/new-dir-recurse'))
        eq(true, os_isdir('unit-test-directory/new-dir-recurse'))
        uv.fs_rmdir('unit-test-directory/new-dir-recurse')
        eq(false, os_isdir('unit-test-directory/new-dir-recurse'))
      end)

      itp('succeeds to create a directory ending with /', function()
        local mode = ffi.C.kS_IRUSR + ffi.C.kS_IWUSR + ffi.C.kS_IXUSR
        local ret, failed_dir, created_dir =
          os_mkdir_recurse('unit-test-directory/new-dir-recurse/', mode)
        eq(0, ret)
        eq(nil, failed_dir)
        ok(endswith(created_dir, 'unit-test-directory/new-dir-recurse'))
        eq(true, os_isdir('unit-test-directory/new-dir-recurse'))
        uv.fs_rmdir('unit-test-directory/new-dir-recurse')
        eq(false, os_isdir('unit-test-directory/new-dir-recurse'))
      end)

      itp('succeeds to create a directory tree', function()
        local mode = ffi.C.kS_IRUSR + ffi.C.kS_IWUSR + ffi.C.kS_IXUSR
        local ret, failed_dir, created_dir =
          os_mkdir_recurse('unit-test-directory/new-dir-recurse/1/2/3', mode)
        eq(0, ret)
        eq(nil, failed_dir)
        ok(endswith(created_dir, 'unit-test-directory/new-dir-recurse'))
        eq(true, os_isdir('unit-test-directory/new-dir-recurse'))
        eq(true, os_isdir('unit-test-directory/new-dir-recurse/1'))
        eq(true, os_isdir('unit-test-directory/new-dir-recurse/1/2'))
        eq(true, os_isdir('unit-test-directory/new-dir-recurse/1/2/3'))
        uv.fs_rmdir('unit-test-directory/new-dir-recurse/1/2/3')
        uv.fs_rmdir('unit-test-directory/new-dir-recurse/1/2')
        uv.fs_rmdir('unit-test-directory/new-dir-recurse/1')
        uv.fs_rmdir('unit-test-directory/new-dir-recurse')
        eq(false, os_isdir('unit-test-directory/new-dir-recurse'))
      end)
    end)

    describe('os_rmdir', function()
      itp('returns non_zero when given a non-existing directory', function()
        neq(0, (os_rmdir('non-existing-directory')))
      end)

      itp('removes the given directory and returns 0', function()
        mkdir('unit-test-directory/new-dir')
        eq(0, os_rmdir('unit-test-directory/new-dir'))
        eq(false, (os_isdir('unit-test-directory/new-dir')))
      end)
    end)
  end)

  describe('FileInfo', function()
    local function file_info_new()
      local info = ffi.new('FileInfo[1]')
      info[0].stat.st_ino = 0
      info[0].stat.st_dev = 0
      return info
    end

    -- Returns true if the FileInfo object has non-empty fields.
    local function has_fileinfo(info)
      return info[0].stat.st_ino > 0 and info[0].stat.st_dev > 0
    end

    local function file_id_new()
      local info = ffi.new('FileID[1]')
      info[0].inode = 0
      info[0].device_id = 0
      return info
    end

    describe('os_fileinfo', function()
      itp('returns false if path=NULL', function()
        local info = file_info_new()
        assert.is_false((fs.os_fileinfo(nil, info)))
      end)

      itp('returns false if given a non-existing file', function()
        local info = file_info_new()
        assert.is_false((fs.os_fileinfo('/non-existent', info)))
      end)

      itp('returns true if given an existing file and fills FileInfo', function()
        local info = file_info_new()
        local path = 'unit-test-directory/test.file'
        assert.is_true((fs.os_fileinfo(path, info)))
        assert.is_true((has_fileinfo(info)))
      end)

      itp('returns the FileInfo of the linked file, not the link', function()
        local info = file_info_new()
        local path = 'unit-test-directory/test_link.file'
        assert.is_true((fs.os_fileinfo(path, info)))
        assert.is_true((has_fileinfo(info)))
        local mode = tonumber(info[0].stat.st_mode)
        return eq(ffi.C.kS_IFREG, (bit.band(mode, ffi.C.kS_IFMT)))
      end)
    end)

    describe('os_fileinfo_link', function()
      itp('returns false for non-existing file', function()
        local info = file_info_new()
        assert.is_false((fs.os_fileinfo_link('/non-existent', info)))
      end)

      itp('returns true and fills FileInfo for existing file', function()
        local info = file_info_new()
        local path = 'unit-test-directory/test.file'
        assert.is_true((fs.os_fileinfo_link(path, info)))
        assert.is_true((has_fileinfo(info)))
      end)

      itp('returns FileInfo of the link, not its target', function()
        local info = file_info_new()
        local link = 'unit-test-directory/test_link.file'
        assert.is_true((fs.os_fileinfo_link(link, info)))
        assert.is_true((has_fileinfo(info)))
        local mode = tonumber(info[0].stat.st_mode)
        eq(ffi.C.kS_IFLNK, (bit.band(mode, ffi.C.kS_IFMT)))
      end)
    end)

    describe('os_fileinfo_fd', function()
      itp('returns false if given an invalid file descriptor', function()
        local info = file_info_new()
        assert.is_false((fs.os_fileinfo_fd(-1, info)))
      end)

      itp('returns true if given a file descriptor and fills FileInfo', function()
        local info = file_info_new()
        local path = 'unit-test-directory/test.file'
        local fd = ffi.C.open(path, 0)
        assert.is_true((fs.os_fileinfo_fd(fd, info)))
        assert.is_true((has_fileinfo(info)))
        ffi.C.close(fd)
      end)
    end)

    describe('os_fileinfo_id_equal', function()
      itp('returns false if file infos represent different files', function()
        local file_info_1 = file_info_new()
        local file_info_2 = file_info_new()
        local path_1 = 'unit-test-directory/test.file'
        local path_2 = 'unit-test-directory/test_2.file'
        assert.is_true((fs.os_fileinfo(path_1, file_info_1)))
        assert.is_true((fs.os_fileinfo(path_2, file_info_2)))
        assert.is_false((fs.os_fileinfo_id_equal(file_info_1, file_info_2)))
      end)

      itp('returns true if file infos represent the same file', function()
        local file_info_1 = file_info_new()
        local file_info_2 = file_info_new()
        local path = 'unit-test-directory/test.file'
        assert.is_true((fs.os_fileinfo(path, file_info_1)))
        assert.is_true((fs.os_fileinfo(path, file_info_2)))
        assert.is_true((fs.os_fileinfo_id_equal(file_info_1, file_info_2)))
      end)

      itp('returns true if file infos represent the same file (symlink)', function()
        local file_info_1 = file_info_new()
        local file_info_2 = file_info_new()
        local path_1 = 'unit-test-directory/test.file'
        local path_2 = 'unit-test-directory/test_link.file'
        assert.is_true((fs.os_fileinfo(path_1, file_info_1)))
        assert.is_true((fs.os_fileinfo(path_2, file_info_2)))
        assert.is_true((fs.os_fileinfo_id_equal(file_info_1, file_info_2)))
      end)
    end)

    describe('os_fileinfo_id', function()
      itp('extracts ino/dev from FileInfo into file_id', function()
        local info = file_info_new()
        local file_id = file_id_new()
        local path = 'unit-test-directory/test.file'
        assert.is_true((fs.os_fileinfo(path, info)))
        fs.os_fileinfo_id(info, file_id)
        eq(info[0].stat.st_ino, file_id[0].inode)
        eq(info[0].stat.st_dev, file_id[0].device_id)
      end)
    end)

    describe('os_fileinfo_inode', function()
      itp('returns the inode from FileInfo', function()
        local info = file_info_new()
        local path = 'unit-test-directory/test.file'
        assert.is_true((fs.os_fileinfo(path, info)))
        local inode = fs.os_fileinfo_inode(info)
        eq(info[0].stat.st_ino, inode)
      end)
    end)

    describe('os_fileinfo_size', function()
      itp('returns the correct size of a file', function()
        local path = 'unit-test-directory/test.file'
        local file = io.open(path, 'w')
        file:write('some bytes to get filesize != 0')
        file:flush()
        file:close()
        local size = uv.fs_stat(path).size
        local info = file_info_new()
        assert.is_true(fs.os_fileinfo(path, info))
        eq(size, fs.os_fileinfo_size(info))
      end)
    end)

    describe('os_fileinfo_hardlinks', function()
      itp('returns the correct number of hardlinks', function()
        local path = 'unit-test-directory/test.file'
        local path_link = 'unit-test-directory/test_hlink.file'
        local info = file_info_new()
        assert.is_true(fs.os_fileinfo(path, info))
        eq(1, fs.os_fileinfo_hardlinks(info))
        uv.fs_link(path, path_link)
        assert.is_true(fs.os_fileinfo(path, info))
        eq(2, fs.os_fileinfo_hardlinks(info))
      end)
    end)

    describe('os_fileinfo_blocksize', function()
      itp('returns the correct blocksize of a file', function()
        local path = 'unit-test-directory/test.file'
        local blksize = uv.fs_stat(path).blksize
        local info = file_info_new()
        assert.is_true(fs.os_fileinfo(path, info))
        if blksize then
          eq(blksize, fs.os_fileinfo_blocksize(info))
        else
          -- luafs doesn't support blksize on windows
          -- libuv on windows returns a constant value as blocksize
          -- checking for this constant value should be enough
          eq(2048, fs.os_fileinfo_blocksize(info))
        end
      end)
    end)

    describe('os_fileid', function()
      itp('returns false if given an non-existing file', function()
        local file_id = file_id_new()
        assert.is_false((fs.os_fileid('/non-existent', file_id)))
      end)

      itp('returns true if given an existing file and fills file_id', function()
        local file_id = file_id_new()
        local path = 'unit-test-directory/test.file'
        assert.is_true((fs.os_fileid(path, file_id)))
        assert.is_true(0 < file_id[0].inode)
        assert.is_true(0 < file_id[0].device_id)
      end)
    end)

    describe('os_fileid_equal', function()
      itp('returns true if two FileIDs are equal', function()
        local file_id = file_id_new()
        local path = 'unit-test-directory/test.file'
        assert.is_true((fs.os_fileid(path, file_id)))
        assert.is_true((fs.os_fileid_equal(file_id, file_id)))
      end)

      itp('returns false if two FileIDs are not equal', function()
        local file_id_1 = file_id_new()
        local file_id_2 = file_id_new()
        local path_1 = 'unit-test-directory/test.file'
        local path_2 = 'unit-test-directory/test_2.file'
        assert.is_true((fs.os_fileid(path_1, file_id_1)))
        assert.is_true((fs.os_fileid(path_2, file_id_2)))
        assert.is_false((fs.os_fileid_equal(file_id_1, file_id_2)))
      end)
    end)

    describe('os_fileid_equal_fileinfo', function()
      itp('returns true if file_id and FileInfo represent the same file', function()
        local file_id = file_id_new()
        local info = file_info_new()
        local path = 'unit-test-directory/test.file'
        assert.is_true((fs.os_fileid(path, file_id)))
        assert.is_true((fs.os_fileinfo(path, info)))
        assert.is_true((fs.os_fileid_equal_fileinfo(file_id, info)))
      end)

      itp('returns false if file_id and FileInfo represent different files', function()
        local file_id = file_id_new()
        local info = file_info_new()
        local path_1 = 'unit-test-directory/test.file'
        local path_2 = 'unit-test-directory/test_2.file'
        assert.is_true((fs.os_fileid(path_1, file_id)))
        assert.is_true((fs.os_fileinfo(path_2, info)))
        assert.is_false((fs.os_fileid_equal_fileinfo(file_id, info)))
      end)
    end)
  end)
end)
