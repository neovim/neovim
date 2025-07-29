local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local exec_lua = n.exec_lua

-- TODO: test error message has correct stack trace when:
-- task finishes with no continuation
-- task finishes with synchronous wait
-- nil in results

--- @param s string
--- @param f fun()
local function it_exec(s, f)
  it(s, function()
    exec_lua(f)
  end)
end

describe('async', function()
  before_each(function()
    n.clear()
    exec_lua('package.path = ...', package.path)

    exec_lua(function()
      _G.Async = require('async')
      _G.await = Async.await
      _G.run = Async.run
      _G.wrap = Async.wrap
      _G.uv_handles = setmetatable({}, { __mode = 'v' })

      --- @generic T
      --- @param name string
      --- @param handle T?
      --- @return T - ?
      function _G.add_handle(name, handle)
        uv_handles[name] = assert(handle)
        return handle
      end

      function _G.check_task_err(task, pat)
        local ok, err = task:pwait(10)
        if ok then
          error('Expected task to error, but it completed successfully', 2)
        elseif not err:match(pat) then
          error('Unexpected error: ' .. task:traceback(err), 2)
        end
        return err
      end

      function _G.eq(expected, actual)
        assert(
          vim.deep_equal(expected, actual),
          ('%s does not equal %s'):format(vim.inspect(actual), vim.inspect(expected))
        )
      end
    end)
  end)

  after_each(function()
    exec_lua(function()
      for k, v in pairs(uv_handles) do
        assert(v:is_closing(), ('uv handle %s is not closing'):format(k))
      end
      collectgarbage('collect')
      assert(not next(uv_handles), 'Resources not collected')
    end)
  end)

  it_exec('can await a uv callback function', function()
    --- @param path string
    --- @param options uv.spawn.options
    --- @param on_exit fun(code: integer, signal: integer)
    --- @return uv.uv_process_t handle
    local function spawn(path, options, on_exit)
      return add_handle('process', vim.uv.spawn(path, options, on_exit))
    end

    local done = run(function()
      local code1 = await(3, spawn, 'echo', { args = { 'foo' } })
      assert(code1 == 0)

      local code2 = await(3, spawn, 'echo', { args = { 'bar' } })
      assert(code2 == 0)
      await(vim.schedule)

      return true --[[@as boolean]]
    end):wait(1000)

    assert(done)
  end)

  it_exec('callback function can be closed', function()
    local task = run(function()
      await(1, function(_callback)
        -- Never call callback
        return add_handle('timer', vim.uv.new_timer()) --[[@as vim.async.Closable]]
      end)
    end)

    task:close()

    check_task_err(task, 'closed')
  end)

  it_exec('callback function can be double closed', function()
    local task = run(function()
      await(1, function(callback)
        -- Never call callback
        local timer = add_handle('timer', vim.uv.new_timer())

        -- prematurely close the timer
        timer:close(callback)
        return timer --[[@as vim.async.Closable]]
      end)

      return 'FINISH'
    end)

    check_task_err(task, 'handle .* is already closing')
  end)

  -- Same as test above but uses async and wrap
  it_exec('callback function can be closed (2)', function()
    local wfn = wrap(1, function(_callback)
      -- Never call callback
      return add_handle('timer', vim.uv.new_timer()) --[[@as vim.async.Closable]]
    end)

    local task = run(function()
      wfn()
    end)

    task:close()

    check_task_err(task, 'closed')
  end)

  it_exec('callback function can be closed (nested)', function()
    local task = run(function()
      await(run(function()
        await(function(_callback)
          -- Never call callback
          return add_handle('timer', vim.uv.new_timer()) --[[@as vim.async.Closable]]
        end)
      end))
    end)

    task:close()

    check_task_err(task, 'closed')
  end)

  it_exec('can timeout tasks', function()
    local task = run(function()
      await(function(_callback)
        -- Never call callback
        return add_handle('timer', vim.uv.new_timer()) --[[@as vim.async.Closable]]
      end)
    end)

    check_task_err(task, 'timeout')
    task:close()
    check_task_err(task, 'closed')
  end)

  it_exec('handle tasks that error', function()
    local task = run(function()
      await(function(callback)
        local timer = add_handle('timer', vim.uv.new_timer())
        timer:start(1, 0, callback)
        return timer --[[@as vim.async.Closable]]
      end)
      await(vim.schedule)
      error('GOT HERE')
    end)

    check_task_err(task, 'GOT HERE')
  end)

  it_exec('handle tasks that complete', function()
    local task = run(function()
      await(function(callback)
        local timer = add_handle('timer', vim.uv.new_timer())
        timer:start(1, 0, callback)
        return timer --[[@as vim.async.Closable]]
      end)
      await(vim.schedule)
    end)

    task:wait(10)
  end)

  it_exec('can wait on an empty task', function()
    local did_cb = false
    local a = 1

    local task = run(function()
      a = a + 1
    end)

    task:wait(function()
      did_cb = true
    end)

    task:wait(100)

    assert(a == 2)
    assert(did_cb)
  end)

  it_exec('can iterate tasks', function()
    local tasks = {} --- @type vim.async.Task<any>[]

    local expected = {} --- @type table[]

    for i = 1, 10 do
      tasks[i] = run(function()
        if i % 2 == 0 then
          await(vim.schedule)
        end
        return 'FINISH', i
      end)
      expected[i] = { nil, { 'FINISH', i } }
    end

    local results = {} --- @type table[]
    run(function()
      for i, err, r1, r2 in Async.iter(tasks) do
        results[i] = { err, { r1, r2 } }
      end
    end):wait(1000)

    eq(expected, results)
  end)

  it_exec('can await a run task', function()
    local a = run(function()
      return await(run(function()
        await(vim.schedule)
        return 'JJ'
      end))
    end):wait(10)

    assert(a == 'JJ', 'GOT ' .. tostring(a))
  end)

  it_exec('can handle errors in wrapped functions', function()
    local task = run(function()
      await(function(_callback)
        error('ERROR')
      end)
    end)
    check_task_err(task, 'ERROR')
  end)

  it_exec('can pcall errors in wrapped functions', function()
    local task = run(function()
      return pcall(function()
        await(function(_callback)
          error('ERROR', 0)
        end)
      end)
    end)
    local ok, msg = task:wait()
    assert(not ok, 'Expected error, got success')
    eq(msg, 'ERROR')
  end)

  it_exec('iter tasks followed by error', function()
    local task = run(function()
      await(vim.schedule)
      return 'FINISH', 1
    end)

    local expected = { { nil, { 'FINISH', 1 } } }

    local results = {} --- @type table[]
    local task2 = run(function()
      for i, err, r1, r2 in Async.iter({ task }) do
        assert(not err, err)
        results[i] = { err, { r1, r2 } }
      end
      error('GOT HERE')
    end)

    check_task_err(task2, 'async_spec.lua:%d+: GOT HERE')
    eq(expected, results)
  end)

  it_exec('can provide a traceback for nested tasks', function()
    --- @async
    local function t1()
      await(run(function()
        error('GOT HERE')
      end))
    end

    local task = run(function()
      await(run(function()
        await(run(function()
          await(run(function()
            t1()
          end))
        end))
      end))
    end)

    -- Normal tracebacks look like:
    -- > stack traceback:
    -- >         [C]: in function 'error'
    -- >         test/async_spec.lua:312: in function 'a'
    -- >         test/async_spec.lua:315: in function 'b'
    -- >         test/async_spec.lua:318: in function 'c'
    -- >         test/async_spec.lua:320: in function <test/async_spec.lua:310>
    -- >         [C]: in function 'xpcall'
    -- >         test/async_spec.lua:310: in function <test/async_spec.lua:297>
    -- >         [string "<nvim>"]:2: in main chunk

    local err = check_task_err(task, 'GOT HERE')

    local m = [[test/async_spec.lua:%d+: GOT HERE
stack traceback:
        %[thread: 0x%x+%] %[C%]: in function 'error'
        %[thread: 0x%x+%] test/async_spec.lua:%d+: in function <test/async_spec.lua:%d+>
        %[thread: 0x%x+%] test/async_spec.lua:%d+: in function 't1'
        %[thread: 0x%x+%] test/async_spec.lua:%d+: in function <test/async_spec.lua:%d+>
        %[thread: 0x%x+%] test/async_spec.lua:%d+: in function <test/async_spec.lua:%d+>
        %[thread: 0x%x+%] test/async_spec.lua:%d+: in function <test/async_spec.lua:%d+>
        %[thread: 0x%x+%] test/async_spec.lua:%d+: in function <test/async_spec.lua:%d+>]]

    local tb = task:traceback(err):gsub('\t', '        ')
    assert(tb:match(m), 'ERROR: ' .. tb)
  end)

  describe('semaphore', function()
    it_exec('runs', function()
      local ret = {}
      run(function()
        local semaphore = Async.semaphore(3)
        local tasks = {} --- @type vim.async.Task<nil>[]
        for i = 1, 5 do
          tasks[#tasks + 1] = run(function()
            semaphore:with(function()
              ret[#ret + 1] = 'start' .. i
              await(vim.schedule)
              ret[#ret + 1] = 'end' .. i
            end)
          end)
        end
        Async.join(tasks)
      end):wait()

      eq({
        'start1',
        'start2',
        'start3',
        -- Launch 3 tasks, semaphore now full, now wait for one to finish
        'end1',
        'start4',
        'end2',
        'start5',
        -- All tasks started, now wait for them to finish
        'end3',
        'end4',
        'end5',
      }, ret)
    end)
  end)

  it_exec('can async timeout a test', function()
    local eternity = run(await, function(_cb)
      -- Never call callback
    end)

    check_task_err(run(Async.timeout, 10, eternity), 'timeout')
  end)

  it_exec('does not allow coroutine.yield', function()
    local task = run(function()
      coroutine.yield('This will cause an error.')
    end)
    check_task_err(task, 'Unexpected coroutine.yield()')
  end)

  it_exec('does not allow coroutine.resume', function()
    local co --- @type thread
    local task = run(function()
      co = coroutine.running()
      Async.sleep(1)
    end)
    local status, err = coroutine.resume(co)
    assert(not status, 'Expected coroutine.resume to fail')
    assert(err:match('Unexpected coroutine.resume%(%)'), err)
    check_task_err(task, 'Unexpected coroutine.resume%(%)')
  end)

  it_exec('does not need new stack frame for non-deferred continuations', function()
    --- @async
    local function deep(n)
      if n == 0 then
        return 'done'
      end
      await(function(cb)
        cb()
      end)
      return deep(n - 1)
    end

    local res = run(function()
      return deep(10000)
    end):wait()
    assert(res == 'done')
  end)

  it_exec('does not close child tasks created outside of parent', function()
    local t1 = run(function()
      Async.sleep(10)
    end)

    local t2 --- @type vim.async.Task
    local t3 --- @type vim.async.Task

    local parent = run(function()
      t2 = run(function()
        Async.sleep(10)
      end)

      t3 = run(function()
        Async.sleep(10)
      end):detach()

      -- t1 create outside parent, cancellation will not propagate to it
      await(t1)

      -- t2 created inside parent, cancellation will propagate to it
      await(t2)

      -- t3 created inside parent, but is detached, cancellation will not
      -- propagate to it
      await(t3)
    end)

    parent:close()

    check_task_err(parent, 'closed')
    t1:wait() -- was not closed
    check_task_err(t2, 'closed')
    t3:wait() -- was not closed
  end)

  it_exec('automatically awaits child tasks', function()
    local child1, child2 --- @type vim.async.Task, vim.async.Task
    local main = run(function()
      child1 = run(Async.sleep, 10)
      child2 = run(Async.sleep, 10)
      -- do no await child1 or child2
    end)

    main:wait()
    assert(child1:completed())
    assert(child2:completed())
  end)

  it_exec('should not fail the parent task if children finish before parent', function()
    local child1 --- @type vim.async.Task
    local child2 --- @type vim.async.Task
    local main = run(function()
      child1 = run(Async.sleep, 5)
      child2 = run(Async.sleep, 5)
      Async.sleep(20)
      -- do no await child1 or child2
    end)

    -- should exit immediately as neither child1 or child2 are awaited
    main:wait()
    child1:wait()
    child2:wait()
  end)

  it_exec('automatically closes suspended child tasks', function()
    local forever_child --- @type vim.async.Task

    local main = run(function()
      forever_child = run(function()
        while true do
          Async.sleep(1)
        end
      end)
      Async.sleep(2)
    end)
    eq(forever_child:status(), 'suspended')
    main:close()
    check_task_err(main, 'closed')
    check_task_err(forever_child, 'closed')
  end)

  -- it_exec_multi('ping pong', function()
  --   --- @async
  --   --- @param fn async fun()
  --   local function catch_closed(fn)
  --     local ok, err1 = xpcall(fn, function(err)
  --       if err == 'closed' then
  --         return err
  --       end
  --       return debug.traceback(err, 2)
  --     end)
  --     if not ok then
  --       if err1 == 'closed' then
  --         return true
  --       end
  --       error(err1)
  --     end
  --     return false
  --   end
  --
  --   local msgs = {}
  --
  --   --- @async
  --   --- @param sem vim.async.Semaphore
  --   local function player(name, ball, sem)
  --     while true do
  --       -- if catch_closed(function()
  --       sem:acquire()
  --       -- end) then
  --       --   print(("%s: table's gone"):format(name))
  --       --   break
  --       -- end
  --       ball.hits = ball.hits + 1
  --       msgs[#msgs + 1] = name
  --       Async.sleep(2)
  --       sem:release()
  --     end
  --   end
  --
  --   local ball = { hits = 0 }
  --   local p1, p2
  --
  --   --- @async
  --   local function pingPong()
  --     local sem = Async.semaphore()
  --     sem:acquire()
  --
  --     p1 = run('ping', player, 'ping', ball, sem)
  --     p2 = run('pong', player, 'pong', ball, sem)
  --
  --     sem:release()
  --     Async.sleep(22)
  --     -- while ball.hits < 10 do
  --     --   Async.sleep(1)
  --     -- end
  --   end
  --
  --   local p = run('main', pingPong)
  --   p:wait(50)
  --   check_task_err(p1, 'closed')
  --   check_task_err(p2, 'closed')
  --
  --   -- eq(msgs, { 'ping', 'pong', 'ping', 'pong', 'ping', 'pong', 'ping', 'pong', 'ping', 'pong' })
  -- end)
end)
