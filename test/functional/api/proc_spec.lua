local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local eq = t.eq
local fn = n.fn
local neq = t.neq
local nvim_argv = n.nvim_argv
local exec_lua = n.exec_lua
local request = n.request
local retry = t.retry
local NIL = vim.NIL
local is_os = t.is_os

local function contains(list, needle)
  for _, v in ipairs(list) do
    if v == needle then
      return true
    end
  end
  return false
end

local function cleanup_proc_thread()
  local ok, err = pcall(
    exec_lua,
    [[
    if not ProcChildThread then
      return
    end
    local uv = vim.uv or vim.loop
    if ProcChildThread.thread then
      pcall(function()
        uv.thread_join(ProcChildThread.thread)
      end)
      ProcChildThread.thread = nil
    end
    if ProcChildThread.pid_async then
      ProcChildThread.pid_async:close()
      ProcChildThread.pid_async = nil
    end
    if ProcChildThread.exit_async then
      ProcChildThread.exit_async:close()
      ProcChildThread.exit_async = nil
    end
    ProcChildThread.pid = nil
    ProcChildThread.exited = nil
  ]]
  )
  if not ok then
    t.fail('cleanup_proc_thread failed: ' .. err)
  end
end

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

    it('detects children spawned from threads on linux', function()
      if not is_os('linux') then
        pending('requires linux procfs behavior')
      end

      local this_pid = fn.getpid()
      local main_children_path = string.format('/proc/%d/task/%d/children', this_pid, this_pid)
      if fn.filereadable(main_children_path) == 0 then
        pending('requires /proc/<pid>/task/<tid>/children support')
      end

      exec_lua [[
        ProcChildThread = {}
      ]]

      local initial_children = request('nvim_get_proc_children', this_pid)

      local child_pid = exec_lua [[
        local uv = vim.uv or vim.loop
        local state = ProcChildThread
        state.pid = nil
        state.exited = false
        state.pid_async = uv.new_async(function(pid)
          state.pid = pid
        end)
        state.exit_async = uv.new_async(function()
          state.exited = true
        end)
        state.thread = uv.new_thread(function(pid_async, exit_async)
          local uv = vim.uv or vim.loop
          local handle
          handle, pid = uv.spawn('sleep', { args = { '6' } }, function()
            exit_async:send(1)
            if handle and not handle:is_closing() then
              handle:close()
            end
          end)
          if pid then
            pid_async:send(pid)
            uv.run('default')
          else
            pid_async:send(-1)
          end
        end, state.pid_async, state.exit_async)
        local ok = vim.wait(1500, function()
          return state.pid ~= nil and state.pid > 0
        end, 20)
        if not ok then
          return nil
        end
        return state.pid
      ]]

      if child_pid == nil then
        cleanup_proc_thread()
        pending('failed to spawn child process from thread')
      end

      retry(100, 2000, function()
        local children = request('nvim_get_proc_children', this_pid)
        eq(true, contains(children, child_pid))
      end)

      fn.system({ 'kill', '-KILL', tostring(child_pid) })

      retry(200, 4000, function()
        eq(true, exec_lua('return ProcChildThread.exited'))
      end)

      cleanup_proc_thread()

      -- Restore baseline size to avoid cross-test interference.
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
