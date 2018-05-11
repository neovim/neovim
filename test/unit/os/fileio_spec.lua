local lfs = require('lfs')

local helpers = require('test.unit.helpers')(after_each)
local itp = helpers.gen_itp(it)

local eq = helpers.eq
local ffi = helpers.ffi
local cimport = helpers.cimport
local cppimport = helpers.cppimport

local m = cimport('./src/nvim/os/os.h', './src/nvim/os/fileio.h')
cppimport('fcntl.h')

local fcontents = ''
for i = 0, 255 do
  fcontents = fcontents .. (i == 0 and '\0' or ('%c'):format(i))
end
fcontents = fcontents:rep(16)

local dir = 'Xtest-unit-file_spec.d'
local file1 = dir .. '/file1.dat'
local file2 = dir .. '/file2.dat'
local linkf = dir .. '/file.lnk'
local linkb = dir .. '/broken.lnk'
local filec = dir .. '/created-file.dat'

before_each(function()
  lfs.mkdir(dir);

  local f1 = io.open(file1, 'w')
  f1:write(fcontents)
  f1:close()

  local f2 = io.open(file2, 'w')
  f2:write(fcontents)
  f2:close()

  lfs.link('file1.dat', linkf, true)
  lfs.link('broken.dat', linkb, true)
end)

after_each(function()
  os.remove(file1)
  os.remove(file2)
  os.remove(linkf)
  os.remove(linkb)
  os.remove(filec)
  lfs.rmdir(dir)
end)

local function file_open(fname, flags, mode)
  local ret2 = ffi.new('FileDescriptor')
  local ret1 = m.file_open(ret2, fname, flags, mode)
  return ret1, ret2
end

local function file_open_new(fname, flags, mode)
  local ret1 = ffi.new('int[?]', 1, {0})
  local ret2 = ffi.gc(m.file_open_new(ret1, fname, flags, mode), nil)
  return ret1[0], ret2
end

local function file_open_fd(fd, flags)
  local ret2 = ffi.new('FileDescriptor')
  local ret1 = m.file_open_fd(ret2, fd, flags)
  return ret1, ret2
end

local function file_open_fd_new(fd, flags)
  local ret1 = ffi.new('int[?]', 1, {0})
  local ret2 = ffi.gc(m.file_open_fd_new(ret1, fd, flags), nil)
  return ret1[0], ret2
end

local function file_write(fp, buf)
  return m.file_write(fp, buf, #buf)
end

local function msgpack_file_write(fp, buf)
  return m.msgpack_file_write(fp, buf, #buf)
end

local function file_read(fp, size)
  local buf = nil
  if size == nil then
    size = 0
  else
    -- For some reason if length of NUL-bytes-string is the same as `char[?]`
    -- size luajit garbage collector crashes. But it does not do so in
    -- os_read[v] tests in os/fs_spec.lua.
    buf = ffi.new('char[?]', size + 1, ('\0'):rep(size))
  end
  local ret1 = m.file_read(fp, buf, size)
  local ret2 = ''
  if buf ~= nil then
    ret2 = ffi.string(buf, size)
  end
  return ret1, ret2
end

local function file_flush(fp)
  return m.file_flush(fp)
end

local function file_fsync(fp)
  return m.file_fsync(fp)
end

local function file_skip(fp, size)
  return m.file_skip(fp, size)
end

describe('file_open_fd', function()
  itp('can use file descriptor returned by os_open for reading', function()
    local fd = m.os_open(file1, m.kO_RDONLY, 0)
    local err, fp = file_open_fd(fd, m.kFileReadOnly)
    eq(0, err)
    eq({#fcontents, fcontents}, {file_read(fp, #fcontents)})
    eq(0, m.file_close(fp, false))
  end)
  itp('can use file descriptor returned by os_open for writing', function()
    eq(nil, lfs.attributes(filec))
    local fd = m.os_open(filec, m.kO_WRONLY + m.kO_CREAT, 384)
    local err, fp = file_open_fd(fd, m.kFileWriteOnly)
    eq(0, err)
    eq(4, file_write(fp, 'test'))
    eq(0, m.file_close(fp, false))
    eq(4, lfs.attributes(filec).size)
    eq('test', io.open(filec):read('*a'))
  end)
end)

describe('file_open_fd_new', function()
  itp('can use file descriptor returned by os_open for reading', function()
    local fd = m.os_open(file1, m.kO_RDONLY, 0)
    local err, fp = file_open_fd_new(fd, m.kFileReadOnly)
    eq(0, err)
    eq({#fcontents, fcontents}, {file_read(fp, #fcontents)})
    eq(0, m.file_free(fp, false))
  end)
  itp('can use file descriptor returned by os_open for writing', function()
    eq(nil, lfs.attributes(filec))
    local fd = m.os_open(filec, m.kO_WRONLY + m.kO_CREAT, 384)
    local err, fp = file_open_fd_new(fd, m.kFileWriteOnly)
    eq(0, err)
    eq(4, file_write(fp, 'test'))
    eq(0, m.file_free(fp, false))
    eq(4, lfs.attributes(filec).size)
    eq('test', io.open(filec):read('*a'))
  end)
end)

describe('file_open', function()
  itp('can create a rwx------ file with kFileCreate', function()
    local err, fp = file_open(filec, m.kFileCreate, 448)
    eq(0, err)
    local attrs = lfs.attributes(filec)
    eq('rwx------', attrs.permissions)
    eq(0, m.file_close(fp, false))
  end)

  itp('can create a rw------- file with kFileCreate', function()
    local err, fp = file_open(filec, m.kFileCreate, 384)
    eq(0, err)
    local attrs = lfs.attributes(filec)
    eq('rw-------', attrs.permissions)
    eq(0, m.file_close(fp, false))
  end)

  itp('can create a rwx------ file with kFileCreateOnly', function()
    local err, fp = file_open(filec, m.kFileCreateOnly, 448)
    eq(0, err)
    local attrs = lfs.attributes(filec)
    eq('rwx------', attrs.permissions)
    eq(0, m.file_close(fp, false))
  end)

  itp('can create a rw------- file with kFileCreateOnly', function()
    local err, fp = file_open(filec, m.kFileCreateOnly, 384)
    eq(0, err)
    local attrs = lfs.attributes(filec)
    eq('rw-------', attrs.permissions)
    eq(0, m.file_close(fp, false))
  end)

  itp('fails to open an existing file with kFileCreateOnly', function()
    local err, _ = file_open(file1, m.kFileCreateOnly, 384)
    eq(m.UV_EEXIST, err)
  end)

  itp('fails to open an symlink with kFileNoSymlink', function()
    local err, _ = file_open(linkf, m.kFileNoSymlink, 384)
    -- err is UV_EMLINK in FreeBSD, but if I use `ok(err == m.UV_ELOOP or err ==
    -- m.UV_EMLINK)`, then I loose the ability to see actual `err` value.
    if err ~= m.UV_ELOOP then eq(m.UV_EMLINK, err) end
  end)

  itp('can open an existing file write-only with kFileCreate', function()
    local err, fp = file_open(file1, m.kFileCreate, 384)
    eq(0, err)
    eq(true, fp.wr)
    eq(0, m.file_close(fp, false))
  end)

  itp('can open an existing file read-only with zero', function()
    local err, fp = file_open(file1, 0, 384)
    eq(0, err)
    eq(false, fp.wr)
    eq(0, m.file_close(fp, false))
  end)

  itp('can open an existing file read-only with kFileReadOnly', function()
    local err, fp = file_open(file1, m.kFileReadOnly, 384)
    eq(0, err)
    eq(false, fp.wr)
    eq(0, m.file_close(fp, false))
  end)

  itp('can open an existing file read-only with kFileNoSymlink', function()
    local err, fp = file_open(file1, m.kFileNoSymlink, 384)
    eq(0, err)
    eq(false, fp.wr)
    eq(0, m.file_close(fp, false))
  end)

  itp('can truncate an existing file with kFileTruncate', function()
    local err, fp = file_open(file1, m.kFileTruncate, 384)
    eq(0, err)
    eq(true, fp.wr)
    eq(0, m.file_close(fp, false))
    local attrs = lfs.attributes(file1)
    eq(0, attrs.size)
  end)

  itp('can open an existing file write-only with kFileWriteOnly', function()
    local err, fp = file_open(file1, m.kFileWriteOnly, 384)
    eq(0, err)
    eq(true, fp.wr)
    eq(0, m.file_close(fp, false))
    local attrs = lfs.attributes(file1)
    eq(4096, attrs.size)
  end)

  itp('fails to create a file with just kFileWriteOnly', function()
    local err, _ = file_open(filec, m.kFileWriteOnly, 384)
    eq(m.UV_ENOENT, err)
    local attrs = lfs.attributes(filec)
    eq(nil, attrs)
  end)

  itp('can truncate an existing file with kFileTruncate when opening a symlink',
  function()
    local err, fp = file_open(linkf, m.kFileTruncate, 384)
    eq(0, err)
    eq(true, fp.wr)
    eq(0, m.file_close(fp, false))
    local attrs = lfs.attributes(file1)
    eq(0, attrs.size)
  end)

  itp('fails to open a directory write-only', function()
    local err, _ = file_open(dir, m.kFileWriteOnly, 384)
    eq(m.UV_EISDIR, err)
  end)

  itp('fails to open a broken symbolic link write-only', function()
    local err, _ = file_open(linkb, m.kFileWriteOnly, 384)
    eq(m.UV_ENOENT, err)
  end)

  itp('fails to open a broken symbolic link read-only', function()
    local err, _ = file_open(linkb, m.kFileReadOnly, 384)
    eq(m.UV_ENOENT, err)
  end)
end)

describe('file_open_new', function()
  itp('can open a file read-only', function()
    local err, fp = file_open_new(file1, 0, 384)
    eq(0, err)
    eq(false, fp.wr)
    eq(0, m.file_free(fp, false))
  end)

  itp('fails to open an existing file with kFileCreateOnly', function()
    local err, fp = file_open_new(file1, m.kFileCreateOnly, 384)
    eq(m.UV_EEXIST, err)
    eq(nil, fp)
  end)
end)

describe('file_close', function()
  itp('can flush writes to disk also with true argument', function()
    local err, fp = file_open(filec, m.kFileCreateOnly, 384)
    eq(0, err)
    local wsize = file_write(fp, 'test')
    eq(4, wsize)
    eq(0, lfs.attributes(filec).size)
    eq(0, m.file_close(fp, true))
    eq(wsize, lfs.attributes(filec).size)
  end)
end)

describe('file_free', function()
  itp('can flush writes to disk also with true argument', function()
    local err, fp = file_open_new(filec, m.kFileCreateOnly, 384)
    eq(0, err)
    local wsize = file_write(fp, 'test')
    eq(4, wsize)
    eq(0, lfs.attributes(filec).size)
    eq(0, m.file_free(fp, true))
    eq(wsize, lfs.attributes(filec).size)
  end)
end)

describe('file_fsync', function()
  itp('can flush writes to disk', function()
    local err, fp = file_open(filec, m.kFileCreateOnly, 384)
    eq(0, file_fsync(fp))
    eq(0, err)
    eq(0, lfs.attributes(filec).size)
    local wsize = file_write(fp, 'test')
    eq(4, wsize)
    eq(0, lfs.attributes(filec).size)
    eq(0, file_fsync(fp))
    eq(wsize, lfs.attributes(filec).size)
    eq(0, m.file_close(fp, false))
  end)
end)

describe('file_flush', function()
  itp('can flush writes to disk', function()
    local err, fp = file_open(filec, m.kFileCreateOnly, 384)
    eq(0, file_flush(fp))
    eq(0, err)
    eq(0, lfs.attributes(filec).size)
    local wsize = file_write(fp, 'test')
    eq(4, wsize)
    eq(0, lfs.attributes(filec).size)
    eq(0, file_flush(fp))
    eq(wsize, lfs.attributes(filec).size)
    eq(0, m.file_close(fp, false))
  end)
end)

describe('file_read', function()
  itp('can read small chunks of input until eof', function()
    local err, fp = file_open(file1, 0, 384)
    eq(0, err)
    eq(false, fp.wr)
    local shift = 0
    while shift < #fcontents do
      local size = 3
      local exp_err = size
      local exp_s = fcontents:sub(shift + 1, shift + size)
      if shift + size >= #fcontents then
        exp_err = #fcontents - shift
        exp_s = (fcontents:sub(shift + 1, shift + size)
                 .. (('\0'):rep(size - exp_err)))
      end
      eq({exp_err, exp_s}, {file_read(fp, size)})
      shift = shift + size
    end
    eq(0, m.file_close(fp, false))
  end)

  itp('can read the whole file at once', function()
    local err, fp = file_open(file1, 0, 384)
    eq(0, err)
    eq(false, fp.wr)
    eq({#fcontents, fcontents}, {file_read(fp, #fcontents)})
    eq({0, ('\0'):rep(#fcontents)}, {file_read(fp, #fcontents)})
    eq(0, m.file_close(fp, false))
  end)

  itp('can read more then 1024 bytes after reading a small chunk', function()
    local err, fp = file_open(file1, 0, 384)
    eq(0, err)
    eq(false, fp.wr)
    eq({5, fcontents:sub(1, 5)}, {file_read(fp, 5)})
    eq({#fcontents - 5, fcontents:sub(6) .. (('\0'):rep(5))},
       {file_read(fp, #fcontents)})
    eq(0, m.file_close(fp, false))
  end)

  itp('can read file by 768-byte-chunks', function()
    local err, fp = file_open(file1, 0, 384)
    eq(0, err)
    eq(false, fp.wr)
    local shift = 0
    while shift < #fcontents do
      local size = 768
      local exp_err = size
      local exp_s = fcontents:sub(shift + 1, shift + size)
      if shift + size >= #fcontents then
        exp_err = #fcontents - shift
        exp_s = (fcontents:sub(shift + 1, shift + size)
                 .. (('\0'):rep(size - exp_err)))
      end
      eq({exp_err, exp_s}, {file_read(fp, size)})
      shift = shift + size
    end
    eq(0, m.file_close(fp, false))
  end)
end)

describe('file_write', function()
  itp('can write the whole file at once', function()
    local err, fp = file_open(filec, m.kFileCreateOnly, 384)
    eq(0, err)
    eq(true, fp.wr)
    local wr = file_write(fp, fcontents)
    eq(#fcontents, wr)
    eq(0, m.file_close(fp, false))
    eq(wr, lfs.attributes(filec).size)
    eq(fcontents, io.open(filec):read('*a'))
  end)

  itp('can write the whole file by small chunks', function()
    local err, fp = file_open(filec, m.kFileCreateOnly, 384)
    eq(0, err)
    eq(true, fp.wr)
    local shift = 0
    while shift < #fcontents do
      local size = 3
      local s = fcontents:sub(shift + 1, shift + size)
      local wr = file_write(fp, s)
      eq(wr, #s)
      shift = shift + size
    end
    eq(0, m.file_close(fp, false))
    eq(#fcontents, lfs.attributes(filec).size)
    eq(fcontents, io.open(filec):read('*a'))
  end)

  itp('can write the whole file by 768-byte-chunks', function()
    local err, fp = file_open(filec, m.kFileCreateOnly, 384)
    eq(0, err)
    eq(true, fp.wr)
    local shift = 0
    while shift < #fcontents do
      local size = 768
      local s = fcontents:sub(shift + 1, shift + size)
      local wr = file_write(fp, s)
      eq(wr, #s)
      shift = shift + size
    end
    eq(0, m.file_close(fp, false))
    eq(#fcontents, lfs.attributes(filec).size)
    eq(fcontents, io.open(filec):read('*a'))
  end)
end)

describe('msgpack_file_write', function()
  itp('can write the whole file at once', function()
    local err, fp = file_open(filec, m.kFileCreateOnly, 384)
    eq(0, err)
    eq(true, fp.wr)
    local wr = msgpack_file_write(fp, fcontents)
    eq(0, wr)
    eq(0, m.file_close(fp, false))
    eq(fcontents, io.open(filec):read('*a'))
  end)
end)

describe('file_skip', function()
  itp('can skip 3 bytes', function()
    local err, fp = file_open(file1, 0, 384)
    eq(0, err)
    eq(false, fp.wr)
    eq(3, file_skip(fp, 3))
    local rd, s = file_read(fp, 3)
    eq(3, rd)
    eq(fcontents:sub(4, 6), s)
    eq(0, m.file_close(fp, false))
  end)
end)
