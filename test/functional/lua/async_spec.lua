local n = require('test.functional.testnvim')()
local exec_lua = n.exec_lua

-- TODO: test error message has correct stack trace when:
-- task finishes with no continuation
-- task finishes with synchronous wait
-- nil in results

-- TODO(lewis6991): test for cyclic await
-- - child awaiting an ancestor (not allowed)
-- - cyclic chain with detached tasks

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
      _G.Async = require('vim.async')
      _G.AsyncRuntime = require('vim.async._runtime')
      local safe_pcall = pcall
      local ok, coxpcall = pcall(require, 'coxpcall')
      if ok and type(coxpcall) == 'table' and type(coxpcall.pcall) == 'function' then
        safe_pcall = coxpcall.pcall
      end
      _G.pcall = safe_pcall
      _G.await = Async.await
      _G.run = Async.run
      _G.wrap = Async.wrap
      _G.uv_handles = setmetatable({}, { __mode = 'v' })

      --- Keep track of uv handles so we can ensure they are closed
      --- @generic T
      --- @param name string
      --- @param handle T?
      --- @return T - ?
      function _G.add_handle(name, handle)
        uv_handles[name] = assert(handle)
        return handle
      end

      --- Check task eventually completes with an error
      --- @param task vim.async.Task
      --- @param pat string
      --- @return string
      function _G.check_task_err(task, pat)
        local ok, err = task:pwait(100)
        if ok then
          error('Expected task to error, but it completed successfully', 2)
        elseif not (err:match('^' .. pat .. '$') or (pat == 'closed' and is_closed_error(err))) then
          error('Unexpected error: ' .. tostring(task:traceback(err)), 2)
        end
        return err
      end

      --- @param s string
      --- @return { [1]: string, pattern: boolean }
      function _G.p(s)
        return { s, pattern = true }
      end

      --- @param err any
      --- @return boolean
      function _G.is_closed_error(err)
        return err == 'closed'
          or (type(err) == 'string' and err:match('^closed\nstack traceback:') ~= nil)
      end

      --- @param err any
      --- @return boolean
      function _G.is_timeout_error(err)
        return err == 'timeout'
          or (type(err) == 'string' and err:match('^timeout\nstack traceback:') ~= nil)
      end

      function _G.is_jit()
        return package.loaded.jit ~= nil
      end

      --- @param expected any
      --- @param actual any
      --- @param msg? string
      function _G.eq(expected, actual, msg)
        local match
        if
          type(expected) == 'table'
          and type(expected[1]) == 'string'
          and expected.pattern == true
        then
          match = actual:match(expected[1]) ~= nil
          expected = expected[1]
        else
          match = vim.deep_equal(expected, actual)
        end

        if not match then
          if type(actual) == 'string' then
            actual = '\n│  ' .. actual:gsub('\n', '\n│  ')
          else
            actual = vim.inspect(actual)
          end
          if type(expected) == 'string' then
            expected = '\n│  ' .. expected:gsub('\n', '\n│  ')
          else
            expected = vim.inspect(expected)
          end
          error(
            ('%s\n\nactual: %s\n\nexpected: %s'):format(msg or 'Mismatch:', actual, expected),
            2
          )
        end
      end

      --- @async~
      function _G.eternity()
        await(function(_cb)
          -- Never call callback
          return add_handle('timer', vim.uv.new_timer()) --[[@as vim.async.Closable]]
        end)
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

  describe('basic operations', function()
    it_exec('can error stack trace on sync wait', function()
      local task = run(function()
        error('SYNC ERR')
      end)
      check_task_err(task, '.*async_spec.lua:%d+: SYNC ERR')
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

        return true
      end):wait(1000)

      eq(true, done)
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

    it_exec('can wait on an empty task', function()
      local did_cb = false
      local a = 1

      local task = run(function()
        -- task does not await anything, should complete immediately
        a = a + 1
      end)

      task:on_complete(function()
        did_cb = true
      end) -- non-blocking

      task:wait(100) -- blocking

      assert(a == 2)
      assert(did_cb)
    end)

    it_exec('on_complete observes a pending child task without starting it', function()
      local results = {}

      run(function()
        local child = run(function()
          results[#results + 1] = 'child_started'
          return 'child_done'
        end)

        child:on_complete(function(err, value)
          assert(not err, tostring(err))
          results[#results + 1] = value
        end)
        results[#results + 1] = 'after_on_complete'
      end):wait(100)

      eq({
        'after_on_complete',
        'child_started',
        'child_done',
      }, results)
    end)

    it_exec('child tasks start when the parent reaches a checkpoint', function()
      local results = {}

      run(function()
        run(function()
          results[#results + 1] = 'child_started'
        end)

        results[#results + 1] = 'before_checkpoint'
        await(vim.schedule)
        results[#results + 1] = 'after_checkpoint'
      end):wait(100)

      eq({
        'before_checkpoint',
        'child_started',
        'after_checkpoint',
      }, results)
    end)

    it_exec('child tasks start at an explicit checkpoint', function()
      local results = {}

      run(function()
        run(function()
          results[#results + 1] = 'child_started'
        end)

        results[#results + 1] = 'before_checkpoint'
        Async.checkpoint()
        results[#results + 1] = 'after_checkpoint'
      end):wait(100)

      eq({
        'before_checkpoint',
        'child_started',
        'after_checkpoint',
      }, results)
    end)

    it_exec('handles tasks that complete', function()
      local task = run(function()
        -- should wait for 1 ms
        await(function(callback)
          local timer = add_handle('timer', vim.uv.new_timer())
          timer:start(1, 0, callback)
          return timer --[[@as vim.async.Closable]]
        end)
        await(vim.schedule)
        return nil, 1
      end)

      local r1, r2 = task:wait(10)
      eq(r1, nil)
      eq(r2, 1)
    end)

    it_exec('can provide a traceback for nested tasks', function()
      if not is_jit() then
        return
      end

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

      local err = check_task_err(task, '.*async_spec.lua:%d+: GOT HERE')

      local m = [[.*async_spec.lua:%d+: GOT HERE
stack traceback:
        %[thread: 0x%x+%] %[C%]: in function 'error'
        %[thread: 0x%x+%] .*async_spec.lua:%d+: in function <.*async_spec.lua:%d+>
        %[thread: 0x%x+%] .*async_spec.lua:%d+: in function 't1'
        %[thread: 0x%x+%] .*async_spec.lua:%d+: in function <.*async_spec.lua:%d+>
        %[thread: 0x%x+%] .*async_spec.lua:%d+: in function <.*async_spec.lua:%d+>
        %[thread: 0x%x+%] .*async_spec.lua:%d+: in function <.*async_spec.lua:%d+>
        %[thread: 0x%x+%] .*async_spec.lua:%d+: in function <.*async_spec.lua:%d+>]]

      local tb = tostring(task:traceback(err) or ''):gsub('\t', '        ')
      assert(tb:match(m), 'ERROR: ' .. tostring(tb))
    end)

    it_exec('does not keep completed awaited tasks in later tracebacks', function()
      if not is_jit() then
        return
      end

      for _, await_child in ipairs({
        function()
          await(run(function()
            return 'done'
          end))
        end,
        function()
          local ok = Async.pawait(run(function()
            error('child error')
          end))
          eq(false, ok)
        end,
      }) do
        local task = run(function()
          await_child()
          error('parent error')
        end)

        local err = check_task_err(task, '.*async_spec.lua:%d+: parent error')
        local tb = tostring(task:traceback(err) or '')

        assert(tb:match("%[C%]: in function 'error'"), 'ERROR: ' .. tostring(tb))
        assert(not tb:match('child error'), 'ERROR: ' .. tostring(tb))
        assert(not tb:match('stack traceback:\nstack traceback:'), 'ERROR: ' .. tostring(tb))
      end
    end)

    it_exec('does not print nil for tracebacks without a message', function()
      if not is_jit() then
        return
      end

      local task = run(function()
        await(function() end)
      end)

      local tb = tostring(task:traceback() or '')
      assert(not tb:match('^nil\n'), 'ERROR: ' .. tostring(tb))

      task:close()
      check_task_err(task, 'closed')
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

    it_exec('does not retain unused run arguments after task starts', function()
      local unused = {}
      local weak = setmetatable({ unused }, { __mode = 'v' })

      local task = run(function(_)
        Async.sleep(100)
      end, 'used', unused)

      unused = nil
      collectgarbage('collect')
      collectgarbage('collect')

      local retained = weak[1]
      task:close()
      check_task_err(task, 'closed')
      eq(nil, retained)
    end)
  end)

  describe('task cancellation and closing', function()
    it_exec('can close tasks', function()
      local task = run(eternity)
      task:close()
      check_task_err(task, 'closed')
    end)

    it_exec('can close tasks which waiting on a wrapped callback function', function()
      local wfn = wrap(1, function(_callback)
        return add_handle('timer', vim.uv.new_timer()) --[[@as vim.async.Closable]]
      end)

      local task = run(function()
        wfn()
      end)

      task:close()
      check_task_err(task, 'closed')
    end)

    it_exec('gracefully handles when closables are prematurely closed', function()
      local result = run(function()
        await(1, function(callback)
          local timer = add_handle('timer', vim.uv.new_timer())
          timer:close(callback)
          return timer --[[@as vim.async.Closable]]
        end)

        return 'FINISH'
      end):wait()

      eq('FINISH', result)
    end)

    it_exec('callback function can be closed (nested)', function()
      local child --- @type vim.async.Task
      local task = run(function()
        child = run(eternity)
        await(child)
      end)

      task:close()

      check_task_err(task, 'closed')
      check_task_err(child, 'closed')
    end)

    it_exec('can timeout tasks', function()
      local task = run(eternity)
      check_task_err(task, 'timeout')
      task:close()
      check_task_err(task, 'closed')
    end)

    it_exec('can async timeout a test', function()
      local task = run(eternity)
      check_task_err(run(Async.timeout, 10, task), 'timeout')
    end)

    it_exec('timeout waits for target cleanup before raising timeout', function()
      local cleanup_done = false

      local task = run(function()
        await(function()
          return {
            close = function(_, callback)
              vim.schedule(function()
                cleanup_done = true
                callback()
              end)
            end,
          }
        end)
      end)

      check_task_err(run(Async.timeout, 1, task), 'timeout')
      eq(true, cleanup_done)
      check_task_err(task, 'closed')
    end)

    it_exec('timeout preserves target failure before the deadline', function()
      local task = run(function()
        Async.sleep(1)
        error('TARGET_ERROR')
      end)

      check_task_err(run(Async.timeout, 100, task), '.*async_spec.lua:%d+: TARGET_ERROR')
    end)

    it_exec('returns when the task completes before the timeout', function()
      local timeout_timer = {
        closed = false,
        close = function(self, callback)
          self.closed = true
          if callback then
            callback()
          end
        end,
        is_closing = function(self)
          return self.closed
        end,
        start = function() end,
      }

      AsyncRuntime.config({
        wait = vim.wait,
        schedule = vim.schedule,
        new_timer = function()
          return timeout_timer
        end,
      })

      local ok, err = pcall(function()
        local task = run(function()
          return 'FINISH'
        end)
        eq('FINISH', run(Async.timeout, 100, task):wait(10))
        assert(timeout_timer.closed)
      end)

      AsyncRuntime.config({
        wait = vim.wait,
        schedule = vim.schedule,
        new_timer = vim.uv.new_timer,
      })
      if not ok then
        error(err, 0)
      end
    end)

    it_exec('closes detached child tasks', function()
      local task1 = run(eternity)
      task1:close()

      local task2 = run(function()
        await(task1)
      end)

      check_task_err(task2, 'closed')
    end)
  end)

  describe('error handling', function()
    it_exec('handles tasks that error', function()
      local task = run(function()
        await(function(callback)
          local timer = add_handle('timer', vim.uv.new_timer())
          timer:start(1, 0, callback)
          return timer --[[@as vim.async.Closable]]
        end)
        await(vim.schedule)
        error('GOT HERE')
      end)

      check_task_err(task, '.*async_spec.lua:%d+: GOT HERE')
    end)

    it_exec('can handle errors in wrapped functions', function()
      local task = run(function()
        await(function(_callback)
          error('ERROR')
        end)
      end)
      check_task_err(task, '.*async_spec.lua:%d+: ERROR')
    end)

    it_exec('can pcall errors in wrapped functions', function()
      local task = run(function()
        return pcall(function()
          await(function(_callback)
            error('ERROR')
          end)
        end)
      end)
      local ok, msg = task:wait()
      assert(not ok and msg, 'Expected error, got success')
      assert(msg:match('^.*async_spec.lua:%d+: ERROR'), 'Got unexpected error: ' .. msg)
    end)

    it_exec('handles when a floating child errors', function()
      local parent = run(function()
        local _child = run(function(...)
          Async.sleep(5)
          error('CHILD ERROR')
        end)
      end)

      check_task_err(parent, 'child error: .*async_spec.lua:%d+: CHILD ERROR')
    end)

    it_exec('handles when a floating child errors and parent errors', function()
      local parent = run(function()
        local _child = run(function(...)
          Async.sleep(5)
          error('CHILD ERROR')
        end)
        error('PARENT ERROR')
      end)

      check_task_err(parent, '.*async_spec.lua:%d+: PARENT ERROR')
    end)
  end)

  describe('task iteration', function()
    it_exec('can iterate detached tasks', function()
      local tasks = {} --- @type vim.async.Task<any>[]
      local expected = {} --- @type table[]

      for i = 1, 10 do
        tasks[i] = run(function()
          if i % 2 == 0 then
            await(vim.schedule)
          end
          return 'FINISH', i
        end)
        expected[i] = { 'FINISH', i }
      end

      local results = {} --- @type table[]
      run(function()
        local next_task = Async.iter(tasks)
        while true do
          local task = next_task()
          if not task then
            break
          end
          local r1, r2 = await(task)
          results[r2] = { r1, r2 }
        end
      end):wait(1000)

      eq(expected, results)
    end)

    it_exec('can inspect errors when iterating detached tasks', function()
      local results = {} --- @type table[]
      local tasks = {} --- @type vim.async.Task<any>[]
      local task_err --- @type any

      for i = 1, 10 do
        tasks[i] = run(function()
          await(vim.schedule)
          if i == 3 then
            error('ERROR IN TASK ' .. i)
          end
          return 'FINISH', i
        end)
      end

      run(function()
        local next_task = Async.iter(tasks)
        while true do
          local task = next_task()
          if not task then
            break
          end
          local ok, r1, r2 = Async.pawait(task)
          if not ok then
            task_err = r1
            break
          end
          results[r2] = { r1, r2 }
        end
      end):wait(100)

      --- @cast task_err string
      assert(task_err:match('.*async_spec.lua:%d+: ERROR IN TASK 3'), task_err)

      eq({
        { 'FINISH', 1 },
        { 'FINISH', 2 },
      }, results)
    end)

    it_exec('iterates tasks in completion order', function()
      --- @async
      --- @param count integer
      --- @param id integer
      local function after_schedules(count, id)
        for _ = 1, count do
          await(vim.schedule)
        end
        return id
      end

      local tasks = {
        run(after_schedules, 3, 1),
        run(after_schedules, 1, 2),
        run(after_schedules, 2, 3),
      }

      local order = {}
      run(function()
        local next_task = Async.iter(tasks)
        while true do
          local task = next_task()
          if not task then
            break
          end
          order[#order + 1] = await(task)
        end
      end):wait(100)

      eq({ 2, 3, 1 }, order)
    end)

    it_exec('treats false task errors as errors when iterating', function()
      local task = run(function()
        await(vim.schedule)
        error(false, 0)
      end)

      run(function()
        local completed = Async.iter({ task })()
        local ok, err = Async.pawait(completed)
        eq(false, ok)
        eq(false, err)
      end):wait(100)
    end)

    it_exec('can iter tasks followed by error', function()
      local task = run(function()
        await(vim.schedule)
        return 'FINISH', 1
      end)

      local expected = { { 'FINISH', 1 } }
      local results = {} --- @type table[]

      local task2 = run(function()
        local next_task = Async.iter({ task })
        while true do
          local completed = next_task()
          if not completed then
            break
          end
          local r1, r2 = await(completed)
          results[r2] = { r1, r2 }
        end
        error('GOT HERE')
      end)

      check_task_err(task2, '.*async_spec.lua:%d+: GOT HERE')
      eq(expected, results)
    end)

    it_exec('can iter tasks with cancellation', function()
      local tasks = {} --- @type vim.async.Task<any>[]

      for i = 1, 4 do
        tasks[i] = run(function()
          if i == 2 then
            eternity()
          end
          return 'FINISH', i
        end)
      end

      assert(tasks[2]):close()

      local results = {} --- @type table[]
      local errs = {} --- @type any[]
      run(function()
        local next_task = Async.iter(tasks)
        while true do
          local task = next_task()
          if not task then
            break
          end
          local ok, r1, r2 = Async.pawait(task)
          if ok then
            results[r2] = { r1, r2 }
          else
            errs[#errs + 1] = r1
          end
        end
      end):wait(100)

      eq({
        [1] = { 'FINISH', 1 },
        [3] = { 'FINISH', 3 },
        [4] = { 'FINISH', 4 },
      }, results)
      eq({ 'closed' }, errs)
    end)

    it_exec('can iter tasks with garbage collection', function()
      --- @param task vim.async.Task
      --- @return integer
      local function get_task_callback_count(task)
        --- @diagnostic disable-next-line: invisible
        return vim.tbl_count(task._future._callbacks)
      end

      local task = run(eternity)

      run(function()
        local itr = Async.iter({ task })
        eq(get_task_callback_count(task), 1, 'task should have one callback')
        itr = nil
        collectgarbage('collect')
        eq(get_task_callback_count(task), 0, 'task should have no callbacks')
      end):wait(100)

      task:close()
      check_task_err(task, 'closed')
    end)

    it_exec('handles empty task lists', function()
      run(function()
        eq(nil, Async.iter({})())
      end):wait(100)
    end)
  end)

  describe('child task management', function()
    it_exec('does not close child tasks created outside of parent', function()
      local t1 = run(Async.sleep, 10)
      local t2 --- @type vim.async.Task
      local t3 --- @type vim.async.Task

      local parent = run(function()
        t2 = run(Async.sleep, 10)
        t3 = run(Async.sleep, 10):detach()
        await(t1)
      end)

      parent:close()

      check_task_err(parent, 'closed')
      t1:wait()
      check_task_err(t2, 'closed')
      t3:wait()
    end)

    it_exec('detached pending child starts independently', function()
      local results = {}

      run(function()
        run(function()
          results[#results + 1] = 'detached_started'
        end):detach()

        results[#results + 1] = 'parent_done'
        await(vim.schedule)
      end):wait(100)

      eq({
        'parent_done',
        'detached_started',
      }, results)
    end)

    it_exec('detached child failures do not fail the original parent', function()
      local child --- @type vim.async.Task

      local parent = run(function()
        child = run(function()
          await(vim.schedule)
          error('DETACHED_ERROR')
        end):detach()

        await(vim.schedule)
        return 'parent ok'
      end)

      eq('parent ok', parent:wait(100))
      check_task_err(child, '.*async_spec.lua:%d+: DETACHED_ERROR')
    end)

    it_exec('attaches tasks created from synchronous callbacks inside a task', function()
      local release --- @type fun()?
      local results = {}

      local parent = run(function()
        local function call(callback)
          callback()
        end

        call(function()
          run(function()
            await(function(callback)
              release = callback
            end)
            results[#results + 1] = 'child_done'
          end)
        end)

        results[#results + 1] = 'parent_body_done'
      end)

      local ok, err = parent:pwait(10)
      eq(false, ok)
      assert(is_timeout_error(err), 'Expected timeout, got: ' .. tostring(err))
      eq({ 'parent_body_done' }, results)
      assert(release, 'attached child was not started at parent finish')

      release()
      parent:wait(50)

      eq({ 'parent_body_done', 'child_done' }, results)
    end)

    it_exec('does not attach tasks created from event-loop callbacks', function()
      local release --- @type fun()?
      local child --- @type vim.async.Task
      local results = {}

      local parent = run(function()
        await(function(callback)
          vim.schedule(function()
            child = run(function()
              await(function(child_callback)
                release = child_callback
              end)
              results[#results + 1] = 'child_done'
            end)
            callback()
          end)
        end)

        results[#results + 1] = 'parent_done'
      end)

      parent:wait(50)

      eq({ 'parent_done' }, results)
      assert(child, 'event-loop callback did not create child task')
      assert(release, 'top-level callback task was not started')

      release()
      child:wait(50)

      eq({ 'parent_done', 'child_done' }, results)
    end)

    it_exec('does not run pending children when parent errors before a checkpoint', function()
      local child --- @type vim.async.Task
      local child_ran = false

      local parent = run(function()
        child = run(function()
          child_ran = true
        end)

        error('PARENT_ERROR')
      end)

      check_task_err(parent, '.*async_spec.lua:%d+: PARENT_ERROR')
      check_task_err(child, 'closed')
      eq(false, child_ran)
    end)

    it_exec('synchronous child wait starts only the waited child', function()
      local results = {}

      run(function()
        local child1 = run(function()
          results[#results + 1] = 'child1'
        end)

        run(function()
          results[#results + 1] = 'child2'
        end)

        child1:wait(100)
        eq({ 'child1' }, results)
      end):wait(100)

      eq({ 'child1', 'child2' }, results)
    end)

    it_exec('does not wait for detached task children after sync wait times out', function()
      local detached --- @type vim.async.Task
      local release --- @type fun()?
      local results = {}

      local parent = run(function()
        await(vim.schedule)

        detached = run(function()
          run(function()
            await(function(callback)
              release = callback
            end)
            results[#results + 1] = 'detached_child_done'
          end)
        end):detach()

        local ok, err = detached:pwait(10)
        eq(false, ok)
        assert(is_timeout_error(err), 'Expected timeout, got: ' .. tostring(err))

        results[#results + 1] = 'parent_done'
      end)

      parent:wait(50)

      eq({ 'parent_done' }, results)
      assert(release, 'detached child was not started')

      release()
      detached:wait(50)

      eq({ 'parent_done', 'detached_child_done' }, results)
    end)

    it_exec('automatically awaits child tasks', function()
      local child1, child2 --- @type vim.async.Task, vim.async.Task
      local main = run(function()
        child1 = run(Async.sleep, 10)
        child2 = run(Async.sleep, 10)
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
      end)

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

      eq(forever_child:status(), 'awaiting')
      main:close()
      check_task_err(main, 'closed')
      check_task_err(forever_child, 'closed')
    end)

    it_exec('child failure while parent is suspended closes siblings', function()
      local sibling --- @type vim.async.Task
      local continued = false

      local parent = run(function()
        run(function()
          Async.sleep(1)
          error('CHILD_ERROR')
        end)

        sibling = run(eternity)
        Async.sleep(100)
        continued = true
      end)

      check_task_err(parent, 'child error: .*async_spec.lua:%d+: CHILD_ERROR')
      check_task_err(sibling, 'closed')
      eq(false, continued)
    end)

    it_exec('should not close the parent task when child task is closed', function()
      run(function()
        run(eternity):close()
      end):wait()
    end)
  end)

  describe('semaphore', function()
    it_exec('rejects invalid permit counts', function()
      for _, permits in ipairs({ 0, -1, 1.5, math.huge }) do
        local ok, err = pcall(Async.semaphore, permits)
        eq(false, ok)
        --- @cast err string
        assert(
          err:match('permits: expected positive integer'),
          'Unexpected error: ' .. tostring(err)
        )
      end
    end)

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
        local next_task = Async.iter(tasks)
        while true do
          local task = next_task()
          if not task then
            break
          end
          await(task)
        end
      end):wait()

      eq({
        'start1',
        'start2',
        'start3',
        'end1',
        'end2',
        'end3',
        'start4',
        'start5',
        'end4',
        'end5',
      }, ret)
    end)

    it_exec('ping pong', function()
      local msgs = {}
      local ball = { hits = 0 }
      local max_hits = 10

      --- @async
      --- @param name string
      --- @param sem vim.async.Semaphore
      local function player(name, sem)
        while ball.hits < max_hits do
          local ok, err = pcall(sem.acquire, sem)
          if not ok or ball.hits >= max_hits then
            if not ok and not tostring(err):match('closed') then
              error(err)
            end
            break
          end

          ball.hits = ball.hits + 1
          msgs[#msgs + 1] = name
          Async.sleep(2)
          sem:release()
        end
      end

      run(function()
        local sem = Async.semaphore(1)
        local p1 = run(player, 'ping', sem)
        local p2 = run(player, 'pong', sem)
        local next_task = Async.iter({ p1, p2 })
        while true do
          local task = next_task()
          if not task then
            break
          end
          await(task)
        end
      end):wait()

      eq({ 'ping', 'pong', 'ping', 'pong', 'ping', 'pong', 'ping', 'pong', 'ping', 'pong' }, msgs)
    end)

    it_exec('does not lose a semaphore wake after closing a waiter', function()
      local sem = Async.semaphore(1)
      local second_acquired = false

      run(function()
        sem:acquire()

        local first = run(function()
          sem:acquire()
        end)

        local second = run(function()
          sem:acquire()
          second_acquired = true
        end)

        Async.checkpoint()
        first:close()
        Async.pawait(first)

        sem:release()
        await(second)
      end):wait(100)

      eq(true, second_acquired)
    end)

    it_exec('releases semaphore permits when with errors', function()
      run(function()
        local sem = Async.semaphore(1)

        local ok, err = pcall(function()
          sem:with(function()
            error('WITH_ERROR')
          end)
        end)

        eq(false, ok)
        --- @cast err string
        assert(err:match('WITH_ERROR'), 'Expected WITH_ERROR, got: ' .. tostring(err))

        sem:acquire()
        sem:release()
      end):wait(100)
    end)

    it_exec('releases semaphore permits when with is cancelled', function()
      local release --- @type fun()?
      local sem = Async.semaphore(1)

      local task = run(function()
        sem:with(function()
          await(function(callback)
            release = callback
          end)
        end)
      end)

      run(function()
        Async.checkpoint()
        assert(release, 'semaphore body did not start')

        task:close()
        Async.pawait(task)

        sem:acquire()
        sem:release()
      end):wait(100)

      check_task_err(task, 'closed')
    end)

    it_exec('does not resume semaphore waiters inline on release', function()
      local results = {}

      run(function()
        local sem = Async.semaphore(1)
        sem:acquire()

        run(function()
          sem:acquire()
          results[#results + 1] = 'waiter_acquired'
        end)

        Async.checkpoint()
        results[#results + 1] = 'before_release'
        sem:release()
        results[#results + 1] = 'after_release'

        eq({ 'before_release', 'after_release' }, results)
        await(vim.schedule)
        eq({ 'before_release', 'after_release', 'waiter_acquired' }, results)
      end):wait(100)
    end)
  end)

  describe('queue', function()
    it_exec('does not resume get waiters inline on put_nowait', function()
      local new_queue = require('vim.async._queue')
      local results = {}

      run(function()
        local queue = new_queue()

        run(function()
          local item = queue:get()
          results[#results + 1] = 'got_' .. item
        end)

        Async.checkpoint()
        results[#results + 1] = 'before_put'
        queue:put_nowait('item')
        results[#results + 1] = 'after_put'

        eq({ 'before_put', 'after_put' }, results)
        await(vim.schedule)
        eq({ 'before_put', 'after_put', 'got_item' }, results)
      end):wait(100)
    end)

    it_exec('get waiters retry if a deferred item is consumed first', function()
      local new_queue = require('vim.async._queue')
      local results = {}

      run(function()
        local queue = new_queue()

        run(function()
          results[#results + 1] = queue:get()
        end)

        Async.checkpoint()
        queue:put_nowait('first')
        eq('first', queue:get_nowait())

        await(vim.schedule)
        eq({}, results)

        queue:put_nowait('second')
        await(vim.schedule)
        eq({ 'second' }, results)
      end):wait(100)
    end)

    it_exec('does not resume put waiters inline on get_nowait', function()
      local new_queue = require('vim.async._queue')
      local results = {}

      run(function()
        local queue = new_queue(1)
        queue:put_nowait('first')

        run(function()
          queue:put('second')
          results[#results + 1] = 'put_second'
        end)

        Async.checkpoint()
        results[#results + 1] = 'before_get'
        eq('first', queue:get_nowait())
        results[#results + 1] = 'after_get'

        eq({ 'before_get', 'after_get' }, results)
        await(vim.schedule)
        eq({ 'before_get', 'after_get', 'put_second' }, results)
      end):wait(100)
    end)

    it_exec('put waiters retry if a deferred slot is filled first', function()
      local new_queue = require('vim.async._queue')
      local results = {}

      run(function()
        local queue = new_queue(1)
        queue:put_nowait('first')

        run(function()
          queue:put('second')
          results[#results + 1] = 'put_second'
        end)

        Async.checkpoint()
        eq('first', queue:get_nowait())
        queue:put_nowait('interloper')

        await(vim.schedule)
        eq({}, results)

        eq('interloper', queue:get_nowait())
        await(vim.schedule)
        eq({ 'put_second' }, results)
        eq('second', queue:get_nowait())
      end):wait(100)
    end)
  end)

  describe('coroutine safety', function()
    it_exec('does not allow coroutine.yield', function()
      local task = run(function()
        coroutine.yield('This will cause an error.')
      end)
      check_task_err(task, 'Unexpected coroutine.yield().*')
    end)

    it_exec('does not allow coroutine.resume', function()
      local co --- @type thread
      local task = run(function()
        co = coroutine.running()
        eternity()
      end)

      local status, err = coroutine.resume(co)
      assert(not status, 'Expected coroutine.resume to fail')
      eq(err, 'Unexpected coroutine.resume()')
      check_task_err(task, 'Unexpected coroutine.resume%(%)')
    end)

    it_exec('does not allow coroutine.resume when awaiting detached task', function()
      local t = run(eternity)
      local co --- @type thread
      local task = run(function()
        co = coroutine.running()
        await(t)
      end)

      local status, err = coroutine.resume(co)
      assert(not status, 'Expected coroutine.resume to fail')
      eq(err, 'Unexpected coroutine.resume()')
      check_task_err(task, 'Unexpected coroutine.resume%(%)')
      t:close()
    end)

    it_exec('preserves child errors after invalid coroutine.resume', function()
      local blocker = run(eternity)
      local co --- @type thread
      local parent = run(function()
        co = coroutine.running()
        run(function()
          await(vim.schedule)
          error('CHILD ERROR')
        end)
        await(blocker)
      end)

      local status, err = coroutine.resume(co)
      assert(not status, 'Expected coroutine.resume to fail')
      eq(err, 'Unexpected coroutine.resume()')
      local check_ok, check_err =
        pcall(check_task_err, parent, 'child error: .*async_spec.lua:%d+: CHILD ERROR')

      blocker:close()
      check_task_err(blocker, 'closed')

      if not check_ok then
        error(check_err, 0)
      end
    end)
  end)

  describe('inspect_tree', function()
    it_exec('outside of tasks', function()
      local parent = run('parent', function()
        run('child1', eternity)
        run('child2', eternity)
        run('child3', function(...)
          run('sub_child1', eternity)
          run('sub_child2', eternity)
          run(eternity)
        end)
      end)

      eq(
        p([=[
parent %[awaiting%]
├─ child1 %[awaiting%]
├─ child2 %[awaiting%]
└─ child3 %[awaiting%]
   ├─ sub_child1 %[awaiting%]
   ├─ sub_child2 %[awaiting%]
   └─ %[awaiting%]]=]),
        Async._inspect_tree()
      )

      parent:close()
      check_task_err(parent, 'closed')
    end)

    it_exec('inside a task', function()
      local inspect
      local parent = run('parent', function()
        run('child1', eternity)
        run('child2', eternity)
        run('child3', function(...)
          run('sub_child1', eternity)
          run('sub_child2', eternity)
          run(eternity)
          inspect = Async._inspect_tree()
        end)
      end)

      eq(
        p([=[
parent %[awaiting%]
├─ child1 %[awaiting%]
├─ child2 %[awaiting%]
└─ child3 %[running%]
   ├─ sub_child1 %[awaiting%]
   ├─ sub_child2 %[awaiting%]
   └─ %[awaiting%]]=]),
        inspect
      )

      parent:close()
      check_task_err(parent, 'closed')
    end)

    it_exec('can show task creation locations in debug mode', function()
      AsyncRuntime.config({ debug = true })
      local parent
      local ok, err = pcall(function()
        parent = run('parent', function()
          run('child', eternity)
        end)

        local expected = is_jit()
            and [=[
parent@.*async_spec.lua:%d+ %[awaiting%]
└─ child@.*async_spec.lua:%d+ %[awaiting%]]=]
          or [=[
parent=.* %[awaiting%]
└─ child=.* %[awaiting%]]=]

        eq(p(expected), Async._inspect_tree())
      end)
      if parent then
        parent:close()
      end
      AsyncRuntime.config({ debug = false })
      if parent then
        check_task_err(parent, 'closed')
      end
      if not ok then
        error(err, 0)
      end
    end)
  end)

  describe('pcall and task-control errors', function()
    it_exec('child errors remain terminal after pcall catches delivery', function()
      local results = {}
      local parent = run(function()
        local _child = run(function()
          Async.sleep(5)
          error('CHILD ERROR')
        end)

        local ok1, err1 = pcall(function()
          Async.sleep(100)
        end)

        if not ok1 then
          results[#results + 1] = 'caught_first'
          results[#results + 1] = err1:match('CHILD ERROR') and 'has_error' or 'no_error'
        end

        local ok2, err2 = pcall(function()
          Async.sleep(1)
        end)

        if not ok2 then
          results[#results + 1] = 'caught_second'
          results[#results + 1] = err2:match('CHILD ERROR') and 'has_error' or 'no_error'
        else
          results[#results + 1] = 'no_second_error'
        end

        results[#results + 1] = 'returned'
      end)

      local ok, err = parent:pwait(200)
      eq(false, ok)
      --- @cast err string
      assert(err:match('child error:.*CHILD ERROR'), 'Expected child error, got: ' .. tostring(err))

      eq({
        'caught_first',
        'has_error',
        'caught_second',
        'has_error',
        'returned',
      }, results)
    end)

    it_exec('awaited child errors remain terminal without child wrapper', function()
      local results = {}
      local parent = run(function()
        local child = run(function()
          error('AWAITED CHILD ERROR')
        end)

        local ok1, err1 = pcall(function()
          await(child)
        end)

        if not ok1 then
          results[#results + 1] = err1:match('AWAITED CHILD ERROR') and 'caught_child' or 'other'
          results[#results + 1] = err1:match('child error:') and 'wrapped' or 'unwrapped'
        end

        local ok2, err2 = pcall(function()
          Async.sleep(1)
        end)

        if not ok2 then
          results[#results + 1] = err2:match('AWAITED CHILD ERROR') and 'caught_again' or 'other'
          results[#results + 1] = err2:match('child error:') and 'wrapped' or 'unwrapped'
        end

        results[#results + 1] = 'returned'
      end)

      local ok, err = parent:pwait(200)
      eq(false, ok)
      --- @cast err string
      assert(
        err:match('.*async_spec.lua:%d+: AWAITED CHILD ERROR'),
        'Expected awaited child error, got: ' .. tostring(err)
      )
      assert(not err:match('child error:'), 'Did not expect child wrapper, got: ' .. err)

      eq({
        'caught_child',
        'unwrapped',
        'caught_again',
        'unwrapped',
        'returned',
      }, results)
    end)

    it_exec('false awaited child errors remain terminal after pcall catches delivery', function()
      local parent = run(function()
        local child = run(function()
          error(false, 0)
        end)

        local ok1, err1 = pcall(function()
          await(child)
        end)

        eq(false, ok1)
        eq(false, err1)

        local ok2, err2 = pcall(function()
          Async.sleep(1)
        end)

        eq(false, ok2)
        eq(false, err2)
      end)

      local ok, err = parent:pwait(200)
      eq(false, ok)
      eq(false, err)
    end)

    it_exec('pawait returns successful task results', function()
      local parent = run(function()
        local ok, a, b, c = Async.pawait(run(function()
          Async.sleep(1)
          return 1, 'two', true
        end))

        eq(true, ok)
        eq(1, a)
        eq('two', b)
        eq(true, c)

        return 'parent ok'
      end)

      eq('parent ok', parent:wait(100))
    end)

    it_exec('pawait accepts await callback overloads', function()
      local parent = run(function()
        local ok1, value = Async.pawait(function(callback)
          vim.schedule(function()
            callback('scheduled')
          end)
        end)

        local ok2, a, b = Async.pawait(2, function(prefix, callback)
          vim.schedule(function()
            callback(prefix, 'done')
          end)
        end, 'arg')

        eq({ true, 'scheduled' }, { ok1, value })
        eq({ true, 'arg', 'done' }, { ok2, a, b })

        return 'parent ok'
      end)

      eq('parent ok', parent:wait(100))
    end)

    it_exec('pawait returns awaitable setup errors as data', function()
      local parent = run(function()
        local ok, err = Async.pawait(function(_callback)
          error()
        end)

        eq(false, ok)
        eq('error(nil)', err)

        return 'parent ok'
      end)

      eq('parent ok', parent:wait(100))
    end)

    it_exec('pawait returns synchronous child errors as data', function()
      local results = {}
      local parent = run(function()
        local child = run(function()
          results[#results + 1] = 'child_started'
          error('SYNC CHILD ERROR')
        end)

        results[#results + 1] = 'after_run'
        local ok, err = Async.pawait(child)

        eq(false, ok)
        --- @cast err string
        results[#results + 1] = err:match('SYNC CHILD ERROR') and 'got_error' or 'other'
        results[#results + 1] = err:match('child error:') and 'wrapped' or 'unwrapped'

        Async.sleep(1)
        results[#results + 1] = 'continued'

        return 'parent ok'
      end)

      eq('parent ok', parent:wait(100))
      eq({
        'after_run',
        'child_started',
        'got_error',
        'unwrapped',
        'continued',
      }, results)
    end)

    it_exec('pawait returns asynchronous child errors as data', function()
      local results = {}
      local parent = run(function()
        local ok, err = Async.pawait(run(function()
          Async.sleep(1)
          error('ASYNC CHILD ERROR')
        end))

        eq(false, ok)
        --- @cast err string
        results[#results + 1] = err:match('ASYNC CHILD ERROR') and 'got_error' or 'other'
        results[#results + 1] = err:match('child error:') and 'wrapped' or 'unwrapped'

        Async.sleep(1)
        results[#results + 1] = 'continued'

        return 'parent ok'
      end)

      eq('parent ok', parent:wait(100))
      eq({
        'got_error',
        'unwrapped',
        'continued',
      }, results)
    end)

    it_exec('pawait does not protect current task cancellation', function()
      local results = {}
      local parent = run(function()
        local ok, err = pcall(function()
          Async.pawait(function(_callback)
            return add_handle('pawait_current_cancellation_timer', vim.uv.new_timer())
          end)
        end)

        eq(false, ok)
        results[#results + 1] = is_closed_error(err) and 'caught_closed' or 'other_error'
        results[#results + 1] = Async.is_closing() and 'is_closing' or 'not_closing'
        results[#results + 1] = 'cleanup'
      end)

      run(function()
        Async.sleep(1)
        parent:close()
      end):wait()

      check_task_err(parent, 'closed')
      eq({
        'caught_closed',
        'is_closing',
        'cleanup',
      }, results)
    end)

    it_exec('pawait does not protect unrelated current task errors', function()
      local results = {}
      local parent = run(function()
        local _child = run(function()
          Async.sleep(5)
          error('CHILD ERROR')
        end)

        local ok, err = pcall(function()
          Async.pawait(function(callback)
            local timer = add_handle('pending_child_error_timer', vim.uv.new_timer())
            timer:start(100, 0, function()
              timer:close()
              callback('done')
            end)
            return timer
          end)
        end)

        eq(false, ok)
        --- @cast err string
        results[#results + 1] = err:match('child error:.*CHILD ERROR') and 'child_error'
          or 'other_error'
        results[#results + 1] = Async.is_closing() and 'is_closing' or 'not_closing'
        results[#results + 1] = 'cleanup'
      end)

      local ok, err = parent:pwait(200)
      eq(false, ok)
      --- @cast err string
      assert(err:match('child error:.*CHILD ERROR'), 'Expected child error, got: ' .. tostring(err))

      eq({
        'child_error',
        'not_closing',
        'cleanup',
      }, results)
    end)

    it_exec('cancellations are level-triggered (persist across catches)', function()
      local results = {}
      local task = run(function()
        local ok1, err1 = pcall(function()
          Async.sleep(100)
        end)

        if not ok1 then
          results[#results + 1] = 'caught_first'
          results[#results + 1] = is_closed_error(err1) and 'is_closed' or 'other_error'
        end

        local ok2, err2 = pcall(function()
          Async.sleep(1)
        end)

        if not ok2 then
          results[#results + 1] = 'caught_second'
          results[#results + 1] = is_closed_error(err2) and 'is_closed' or 'other_error'
        end

        results[#results + 1] = 'should_not_reach'
      end)

      run(function()
        Async.sleep(1)
        task:close()
      end):wait()

      check_task_err(task, 'closed')

      eq({
        'caught_first',
        'is_closed',
        'caught_second',
        'is_closed',
        'should_not_reach',
      }, results)
    end)

    it_exec('checkpoint rethrows current task cancellation after cleanup', function()
      local results = {}
      local task = run(function()
        local ok, err = pcall(function()
          Async.sleep(100)
        end)

        eq(false, ok)
        results[#results + 1] = is_closed_error(err) and 'caught_closed' or 'other_error'
        results[#results + 1] = 'cleanup'

        Async.checkpoint()
        results[#results + 1] = 'after_checkpoint'
      end)

      run(function()
        Async.sleep(1)
        task:close()
      end):wait()

      check_task_err(task, 'closed')

      eq({
        'caught_closed',
        'cleanup',
      }, results)
    end)

    it_exec('checkpoint rethrows current task failure after cleanup', function()
      local results = {}
      local parent = run(function()
        local _child = run(function()
          Async.sleep(5)
          error('CHILD ERROR')
        end)

        local ok, err = pcall(function()
          Async.sleep(100)
        end)

        eq(false, ok)
        --- @cast err string
        results[#results + 1] = err:match('CHILD ERROR') and 'caught_child_error' or 'other_error'
        results[#results + 1] = 'cleanup'

        Async.checkpoint()
        results[#results + 1] = 'after_checkpoint'
      end)

      check_task_err(parent, 'child error:.*CHILD ERROR')

      eq({
        'caught_child_error',
        'cleanup',
      }, results)
    end)

    it_exec('can recover synchronous errors inside async tasks', function()
      local results = {}
      run(function()
        local ok = pcall(function()
          error('BAD CONFIG')
        end)

        if not ok then
          results[#results + 1] = 'error_caught'
        end

        Async.sleep(1)
        results[#results + 1] = 'finished'
      end):wait(200)

      eq({
        'error_caught',
        'finished',
      }, results)
    end)

    it_exec('cancellation persists even after pcall catches it', function()
      local results = {}
      local task = run(function()
        for i = 1, 5 do
          local ok, err = pcall(function()
            Async.sleep(10)
          end)

          if not ok then
            if is_closed_error(err) then
              results[#results + 1] = ('closed_iteration_%d'):format(i)
            else
              results[#results + 1] = ('error_iteration_%d'):format(i)
            end
          else
            results[#results + 1] = ('success_iteration_%d'):format(i)
          end
        end
      end)

      run(function()
        Async.sleep(1)
        task:close()
      end):wait()

      check_task_err(task, 'closed')

      eq({
        'closed_iteration_1',
        'closed_iteration_2',
        'closed_iteration_3',
        'closed_iteration_4',
        'closed_iteration_5',
      }, results)
    end)

    it_exec('is_closing() reflects level-triggered cancellation state', function()
      local results = {}
      local task = run(function()
        for _ = 1, 3 do
          results[#results + 1] = ('is_closing_%d'):format(Async.is_closing() and 1 or 0)

          local ok = pcall(function()
            Async.sleep(10)
          end)

          if not ok then
            results[#results + 1] = ('after_catch_is_closing_%d'):format(
              Async.is_closing() and 1 or 0
            )
          end
        end
      end)

      run(function()
        Async.sleep(1)
        task:close()
      end):wait()

      check_task_err(task, 'closed')

      eq({
        'is_closing_0',
        'after_catch_is_closing_1',
        'is_closing_1',
        'after_catch_is_closing_1',
        'is_closing_1',
        'after_catch_is_closing_1',
      }, results)
    end)

    it_exec('first child error remains pending across subsequent awaits', function()
      local results = {}
      local parent = run(function()
        local _child1 = run(function()
          Async.sleep(5)
          error('ERROR_1')
        end)

        local _child2 = run(function()
          Async.sleep(10)
          error('ERROR_2')
        end)

        local ok1, err1 = pcall(function()
          Async.sleep(100)
        end)

        if not ok1 then
          results[#results + 1] = err1:match('ERROR_1') and 'got_error_1' or 'other'
        end

        local ok2, err2 = pcall(function()
          Async.sleep(100)
        end)

        if not ok2 then
          results[#results + 1] = err2:match('ERROR_1') and 'got_error_1_again' or 'other'
        end

        results[#results + 1] = 'returned'
      end)

      local ok, err = parent:pwait(200)
      eq(false, ok)
      --- @cast err string
      assert(
        err:match('child error:.*ERROR_1'),
        'Expected first child error, got: ' .. tostring(err)
      )

      eq({
        'got_error_1',
        'got_error_1_again',
        'returned',
      }, results)
    end)

    it_exec('task error takes precedence over cancellation when both occur', function()
      local task = run(function()
        pcall(function()
          Async.sleep(10)
        end)

        error('TASK_ERROR')
      end)

      run(function()
        Async.sleep(1)
        task:close()
      end):wait()

      local ok, err = task:pwait(100)
      assert(not ok, 'Expected task to error')
      eq(true, err:match('TASK_ERROR') ~= nil, 'Expected TASK_ERROR, got: ' .. tostring(err))
    end)

    it_exec(
      'cancellation takes precedence when task completes successfully while closing',
      function()
        local results = {}
        local task = run(function()
          local ok, err = pcall(function()
            await(function(_callback)
              return {
                close = function(_, callback)
                  results[#results + 1] = 'close_called'
                  callback()
                end,
              }
            end)
          end)

          eq(false, ok)
          eq(true, is_closed_error(err), 'Expected closed error, got: ' .. tostring(err))
          results[#results + 1] = 'caught_close'
          results[#results + 1] = 'completed'
          return 'SUCCESS'
        end)

        eq('awaiting', task:status())
        task:close()
        check_task_err(task, 'closed')

        eq({
          'close_called',
          'caught_close',
          'completed',
        }, results)
      end
    )
  end)

  describe('edge case tests', function()
    it_exec('handles awaiting closable that is already closing', function()
      -- Test for potential issue where is_closing() returns true
      local close_count = 0
      local callback_called = false

      local closable = {
        _closing = false,
        is_closing = function(self)
          return self._closing
        end,
        close = function(self, cb)
          close_count = close_count + 1
          self._closing = true
          if cb then
            vim.schedule(cb)
          end
        end,
      }

      local task = run(function()
        -- Start closing the closable
        closable:close()

        -- Now try to await something that returns this already-closing closable
        local result = await(function(callback)
          vim.schedule(function()
            callback('RESULT')
          end)
          return closable
        end)

        callback_called = true
        return result
      end)

      local result = task:wait(100)
      eq('RESULT', result)
      eq(true, callback_called)
      -- The closable should only be closed once (by the explicit close call)
      -- handle_close_awaiting should detect is_closing and not call close again
      eq(1, close_count)
    end)

    it_exec('child error during parent finalization is handled', function()
      local parent = run(function()
        local _child = run(function()
          Async.sleep(5)
          error('CHILD_ERROR')
        end)

        -- Returning starts finalization, which waits for attached child work.
      end)

      local ok, err = parent:pwait(100)

      eq(false, ok)
      --- @cast err string
      assert(err:match('child error:.*CHILD_ERROR'), 'Expected child error, got: ' .. tostring(err))
    end)

    it_exec('child error during parent finalization completes once and closes siblings', function()
      local completions = 0
      local sibling --- @type vim.async.Task

      local parent = run(function()
        local _child = run(function()
          Async.sleep(1)
          error('CHILD_ERROR')
        end)

        sibling = run(eternity)
      end)

      parent:on_complete(function()
        completions = completions + 1
      end)

      local ok, err = parent:pwait(100)

      eq(false, ok)
      --- @cast err string
      assert(err:match('child error:.*CHILD_ERROR'), 'Expected child error, got: ' .. tostring(err))
      eq(1, completions)
      check_task_err(sibling, 'closed')
    end)

    it_exec('later child error during parent finalization closes earlier siblings', function()
      local completions = 0
      local sibling --- @type vim.async.Task

      local parent = run(function()
        sibling = run(eternity)

        local _child = run(function()
          Async.sleep(1)
          error('CHILD_ERROR')
        end)
      end)

      parent:on_complete(function()
        completions = completions + 1
      end)

      local ok, err = parent:pwait(100)

      eq(false, ok)
      --- @cast err string
      assert(err:match('child error:.*CHILD_ERROR'), 'Expected child error, got: ' .. tostring(err))
      eq(1, completions)
      check_task_err(sibling, 'closed')
    end)

    it_exec('child error during parent finalization waits for sibling cleanup', function()
      local cleanup_done = false
      local sibling --- @type vim.async.Task

      local parent = run(function()
        sibling = run(function()
          await(function()
            return {
              close = function(_, callback)
                vim.schedule(function()
                  cleanup_done = true
                  callback()
                end)
              end,
            }
          end)
        end)

        local _child = run(function()
          Async.sleep(1)
          error('CHILD_ERROR')
        end)
      end)

      local ok, err = parent:pwait(100)

      eq(false, ok)
      --- @cast err string
      assert(err:match('child error:.*CHILD_ERROR'), 'Expected child error, got: ' .. tostring(err))
      eq(true, cleanup_done)
      check_task_err(sibling, 'closed')
    end)

    it_exec('future complete is one-shot', function()
      local future = require('vim.async._future')()
      future:complete(nil, 'first')

      local ok, err = pcall(function()
        future:complete(nil, 'second')
      end)

      eq(false, ok)
      --- @cast err string
      assert(err:match('Future is already completed'), 'Unexpected error: ' .. tostring(err))

      local stat, result = future:result()
      eq(true, stat)
      eq('first', result)
    end)

    it_exec('future false error still completes', function()
      local future = require('vim.async._future')()
      future:complete(false)

      eq(true, future:completed())

      local stat, err = future:result()
      eq(false, stat)
      eq(false, err)
    end)

    it_exec('normalizes nil task errors', function()
      check_task_err(
        run(function()
          error()
        end),
        'error%(nil%)'
      )
    end)

    it_exec('normalizes nil awaitable setup errors', function()
      local task = run(function()
        await(function()
          error()
        end)
      end)

      check_task_err(task, 'error%(nil%)')
    end)

    it_exec('normalizes nil close errors', function()
      local task = run(function()
        await(function()
          return {
            close = function()
              error()
            end,
          }
        end)
      end)

      task:close()
      check_task_err(task, 'error%(nil%)')
    end)

    it_exec('normalizes nil future callback errors', function()
      local future = require('vim.async._future')()
      future:on_complete(function()
        error()
      end)

      local ok, err = pcall(function()
        future:complete(nil, 'value')
      end)

      eq(false, ok)
      --- @cast err string
      assert(err:match('error%(nil%)'), 'Unexpected error: ' .. tostring(err))
    end)

    it_exec('callback called multiple times is handled gracefully', function()
      -- Test that calling callback multiple times doesn't break things
      local call_count = 0
      local results = {}

      local task = run(function()
        local result = await(function(callback)
          call_count = call_count + 1
          callback('FIRST_CALL')

          -- Try calling again (should be ignored)
          vim.schedule(function()
            call_count = call_count + 1
            callback('SECOND_CALL')
          end)
        end)

        table.insert(results, result)
        return result
      end)

      local final_result = task:wait(100)

      -- Should only get the first callback result
      eq('FIRST_CALL', final_result)
      eq(1, #results)
      eq('FIRST_CALL', results[1])

      -- Wait a bit for the second callback to potentially fire
      run(function()
        Async.sleep(20)
      end):wait()

      -- Both callbacks should have been called
      eq(2, call_count)

      -- But only the first one should have been processed
      eq(1, #results)
    end)

    it_exec('closable cleanup happens even if close() errors', function()
      -- Test that if a closable's close() method errors, we handle it gracefully
      local close_called = false

      local task = run(function()
        local result = await(function(callback)
          local closable = {
            close = function()
              close_called = true
              error('CLOSE_ERROR')
            end,
          }

          vim.schedule(function()
            callback('RESULT')
          end)

          return closable
        end)

        return result
      end)

      task:close() -- This should trigger closing the closable

      -- The task should complete with the close error
      local ok, err = task:pwait(100)

      eq(true, close_called, 'close() should have been called')
      assert(not ok, 'Task should have errored')
      assert(err:match('CLOSE_ERROR'), 'Expected CLOSE_ERROR, got: ' .. tostring(err))
    end)
  end)
end)
