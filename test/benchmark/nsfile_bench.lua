-- Compare the speed of line operations: nsfile (a u8 variable in a Numstore
-- database) against
-- native Neovim (memline, through the buffer API).
--
-- Usage:
--   build/bin/nsnvim -l test/benchmark/nsfile_bench.lua nsfile [N]
--   build/bin/nsnvim -l test/benchmark/nsfile_bench.lua txn [N]
--   build/bin/nsnvim -l test/benchmark/nsfile_bench.lua native [N]
--
-- "nsfile" commits each call. "txn" runs all phases in one open transaction
-- and commits once at the end.
--
-- N is the number of operations per phase (default 1000).
--
-- Note: "native" goes through nvim_buf_set_lines(), which also does API work
-- (extmarks, buffer events). Undo is off for it. Its swap file is off.

local mode = arg[1]
local n = tonumber(arg[2]) or 1000
if mode ~= 'nsfile' and mode ~= 'txn' and mode ~= 'native' then
  print('usage: nsnvim -l test/benchmark/nsfile_bench.lua nsfile|txn|native [N]')
  os.exit(1)
end

local uv = vim.uv
local ffi = require('ffi')

--- One backend: the same operations on nsfile or on a native buffer.
local backend = {}

if mode == 'nsfile' or mode == 'txn' then
  ffi.cdef([[
    typedef struct nsfile nsfile_T;
    int nsf_db_open(const char *path, char *errbuf, size_t errlen);
    int nsf_db_close(void);
    nsfile_T *nsf_open(const char *var, char *errbuf, size_t errlen);
    int nsf_close(nsfile_T *f);
    int nsf_cleanup(const char *path);
    const char *nsf_errmsg(const nsfile_T *f);
    int32_t nsf_line_count(const nsfile_T *f);
    char *nsf_get(nsfile_T *f, int32_t lnum, size_t *lenp);
    int nsf_insert(nsfile_T *f, int32_t after, const char *text, size_t len);
    int nsf_replace(nsfile_T *f, int32_t lnum, const char *text, size_t len);
    int nsf_delete(nsfile_T *f, int32_t lnum);
    int nsf_begin(nsfile_T *f);
    int nsf_commit(nsfile_T *f);
  ]])
  local C = ffi.C
  local path = 'Xbench-nsfile.db'
  local f

  local function check(ret)
    if ret ~= 1 then
      error(ffi.string(C.nsf_errmsg(f)))
    end
  end

  function backend.open()
    C.nsf_cleanup(path)
    local err = ffi.new('char[256]')
    if C.nsf_db_open(path, err, 256) ~= 1 then
      error(ffi.string(err))
    end
    f = C.nsf_open('bench', err, 256)
    if f == nil then
      error(ffi.string(err))
    end
    if mode == 'txn' then
      check(C.nsf_begin(f))
    end
  end
  function backend.commit()
    check(C.nsf_commit(f))
  end
  function backend.close()
    C.nsf_close(f)
    C.nsf_db_close()
    C.nsf_cleanup(path)
  end
  function backend.count()
    return C.nsf_line_count(f)
  end
  function backend.append(after, s)
    check(C.nsf_insert(f, after, s, #s))
  end
  local len = ffi.new('size_t[1]')
  function backend.get(lnum)
    local p = C.nsf_get(f, lnum, len)
    if p == nil then
      error(ffi.string(C.nsf_errmsg(f)))
    end
    return p
  end
  function backend.replace(lnum, s)
    check(C.nsf_replace(f, lnum, s, #s))
  end
  function backend.delete(lnum)
    check(C.nsf_delete(f, lnum))
  end
else
  local api = vim.api
  local buf
  function backend.open()
    buf = api.nvim_create_buf(false, true)
    vim.bo[buf].undolevels = -1
    vim.bo[buf].swapfile = false
  end
  function backend.commit() end
  function backend.close()
    api.nvim_buf_delete(buf, { force = true })
  end
  function backend.count()
    -- An empty buffer has one empty line; the benchmark appends to it.
    return api.nvim_buf_line_count(buf)
  end
  function backend.append(after, s)
    api.nvim_buf_set_lines(buf, after, after, true, { s })
  end
  function backend.get(lnum)
    return api.nvim_buf_get_lines(buf, lnum - 1, lnum, true)[1]
  end
  function backend.replace(lnum, s)
    api.nvim_buf_set_lines(buf, lnum - 1, lnum, true, { s })
  end
  function backend.delete(lnum)
    api.nvim_buf_set_lines(buf, lnum - 1, lnum, true, {})
  end
end

--- Run "fn" n times and print the cost per operation.
local function phase(name, fn)
  local t0 = uv.hrtime()
  for i = 1, n do
    fn(i)
  end
  local ms = (uv.hrtime() - t0) / 1e6
  print(('%-8s %-24s %10.1f ms total %10.4f ms/op'):format(mode, name, ms, ms / n))
end

math.randomseed(1)
local line = 'the quick brown fox jumps over the lazy dog'

backend.open()
phase('append at end', function(i)
  backend.append(backend.count(), line .. ' ' .. i)
end)
phase('insert in middle', function()
  local c = backend.count()
  backend.append(math.random(0, c), line)
end)
phase('get (sequential)', function(i)
  backend.get((i - 1) % backend.count() + 1)
end)
phase('get (random)', function()
  backend.get(math.random(1, backend.count()))
end)
phase('replace (type 1 char)', function()
  local lnum = math.random(1, backend.count())
  backend.replace(lnum, 'x' .. line)
end)
phase('delete (random)', function()
  backend.delete(math.random(1, backend.count()))
end)
if mode == 'txn' then
  local t0 = uv.hrtime()
  backend.commit()
  local ms = (uv.hrtime() - t0) / 1e6
  print(('%-8s %-24s %10.1f ms total'):format(mode, 'commit (once)', ms))
end
backend.close()
