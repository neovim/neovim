local t = require('test.unit.testutil')
local ffi = t.ffi
local eq = t.eq

t.describe('Unix PTY', function()
  if t.skip(t.is_os('win'), 'N/A: Only applies to Unix PTYs') then
    return
  end

  local itp = t.gen_itp(t.it)
  local c = t.cimport(
    './src/nvim/os/pty_proc.h',
    './src/nvim/event/proc.h',
    './src/nvim/event/loop.h',
    './src/nvim/eval/typval.h',
    './src/nvim/memory.h'
  )
  t.cppimport('fcntl.h')

  local spawned_pty
  local master_fd, slave_fd = -1, -1
  t.before_each(function()
    t.child_cleanup_once(function()
      if spawned_pty then
        local proc = ffi.cast('Proc *', spawned_pty)
        c.proc_stop(proc)
        c.proc_wait(proc, 5000, nil)
      end
      if slave_fd >= 0 then
        ffi.C.close(slave_fd)
      end
      if master_fd >= 0 then
        ffi.C.close(master_fd)
      end
    end)
  end)

  local function read_size(fd)
    local size = ffi.new('struct winsize[1]')
    eq(0, ffi.C.ioctl(fd, ffi.C.kPOSIXTIOCGWINSZ, size))
    return { size[0].ws_col, size[0].ws_row, size[0].ws_xpixel, size[0].ws_ypixel }
  end

  itp('sets the initial pixel size at spawn', function()
    local sleep = vim.fn.exepath('sleep')
    assert(sleep ~= '', 'sleep executable not found')

    local pty = ffi.new('PtyProc[1]', c.pty_proc_init(c.main_loop, nil))
    pty[0].width = 90
    pty[0].height = 32
    pty[0].winsize.ws_xpixel = 900
    pty[0].winsize.ws_ypixel = 640

    local proc = ffi.cast('Proc *', pty)
    proc.events = c.main_loop.events
    proc.argv = ffi.cast('char **', c.xcalloc(3, ffi.sizeof('char *')))
    proc.argv[0] = c.xstrdup(sleep)
    proc.argv[1] = c.xstrdup('30')
    local env = c.tv_dict_alloc()
    proc.env = env
    local status = c.proc_spawn(proc, false, false, false)
    proc.env = nil
    c.tv_dict_free(env)
    eq(0, status)

    spawned_pty = pty
    eq({ 90, 32, 900, 640 }, read_size(pty[0].tty_fd))
    c.proc_stop(proc)
    assert(c.proc_wait(proc, 5000, nil) >= 0, 'PTY child did not exit')
    spawned_pty = nil
  end)

  itp('updates and clears the pixel size on the PTY master', function()
    master_fd = ffi.C.posix_openpt(ffi.C.kO_RDWR)
    assert(master_fd >= 0, 'posix_openpt() failed')
    eq(0, ffi.C.grantpt(master_fd))
    eq(0, ffi.C.unlockpt(master_fd))
    local name = ffi.C.ptsname(master_fd)
    assert(name ~= nil, 'ptsname() failed')
    slave_fd = ffi.C.open(name, ffi.C.kO_RDWR)
    assert(slave_fd >= 0, 'failed to open the PTY slave')

    local pty = ffi.new('PtyProc[1]')
    pty[0].tty_fd = master_fd
    local function resize(width, height, pixel_width, pixel_height)
      c.pty_proc_resize(pty, width, height, pixel_width, pixel_height)
      eq({ width, height, pixel_width, pixel_height }, read_size(master_fd))
    end

    resize(100, 40, 1200, 800)
    resize(100, 40, 1400, 840)
    resize(100, 40, 0, 0)
  end)
end)
