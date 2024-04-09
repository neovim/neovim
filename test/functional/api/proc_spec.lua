local t = require('test.functional.testutil')()

local clear = t.clear
local eq = t.eq
local fn = t.fn
local neq = t.neq
local nvim_argv = t.nvim_argv
local request = t.request
local retry = t.retry
local NIL = vim.NIL
local is_os = t.is_os

describe('API', function()
  before_each(clear)

  describe('nvim_get_proc_children', function()
    it('returns child process ids', function()
      local this_pid = fn.getpid()

      -- Might be non-zero already (left-over from some other test?),
      -- but this is not what is tested here.
      local initial_children = request('nvim_get_proc_children', this_pid)

      local job1 = fn.jobstart(nvim_argv)
      retry(nil, nil, function()
        eq(#initial_children + 1, #request('nvim_get_proc_children', this_pid))
      end)

      local job2 = fn.jobstart(nvim_argv)
      retry(nil, nil, function()
        eq(#initial_children + 2, #request('nvim_get_proc_children', this_pid))
      end)

      fn.jobstop(job1)
      retry(nil, nil, function()
        eq(#initial_children + 1, #request('nvim_get_proc_children', this_pid))
      end)

      fn.jobstop(job2)
      retry(nil, nil, function()
        eq(#initial_children, #request('nvim_get_proc_children', this_pid))
      end)
    end)

    it('validation', function()
      local status, rv = pcall(request, 'nvim_get_proc_children', -1)
      eq(false, status)
      eq("Invalid 'pid': -1", string.match(rv, 'Invalid.*'))

      status, rv = pcall(request, 'nvim_get_proc_children', 0)
      eq(false, status)
      eq("Invalid 'pid': 0", string.match(rv, 'Invalid.*'))

      -- Assume PID 99999 does not exist.
      status, rv = pcall(request, 'nvim_get_proc_children', 99999)
      eq(true, status)
      eq({}, rv)
    end)
  end)

  describe('nvim_get_proc', function()
    it('returns process info', function()
      local pid = fn.getpid()
      local pinfo = request('nvim_get_proc', pid)
      eq((is_os('win') and 'nvim.exe' or 'nvim'), pinfo.name)
      eq(pid, pinfo.pid)
      eq('number', type(pinfo.ppid))
      neq(pid, pinfo.ppid)
    end)

    it('validation', function()
      local status, rv = pcall(request, 'nvim_get_proc', -1)
      eq(false, status)
      eq("Invalid 'pid': -1", string.match(rv, 'Invalid.*'))

      status, rv = pcall(request, 'nvim_get_proc', 0)
      eq(false, status)
      eq("Invalid 'pid': 0", string.match(rv, 'Invalid.*'))

      -- Assume PID 99999 does not exist.
      status, rv = pcall(request, 'nvim_get_proc', 99999)
      eq(true, status)
      eq(NIL, rv)
    end)
  end)
end)
