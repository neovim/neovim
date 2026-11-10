local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local clear = n.clear
local exec_lua = n.exec_lua
local eq = t.eq

describe('vim.system', function()
  before_each(function()
    clear()
  end)

  for name, system in pairs { sync = n.system_sync, async = n.system_async } do
    describe('(' .. name .. ')', function()
      it('failure modes', function()
        t.matches('cmd: expected non%-empty list of strings', t.pcall_err(system, {}))
        t.matches('cmd: expected non%-empty list of strings', t.pcall_err(system, { 42 }))

        t.matches(
          "ENOENT%: no such file .* %(cmd%): 'non%-existent%-cmd'",
          t.pcall_err(system, { 'non-existent-cmd', 'arg1', 'arg2' }, { text = true })
        )

        t.matches(
          "ENOENT%: no such file .* %(cwd%): 'non%-existent%-cwd'",
          t.pcall_err(system, { 'echo', 'hello' }, { cwd = 'non-existent-cwd', text = true })
        )
      end)

      it('can run simple commands', function()
        eq('hello\n', system({ 'echo', 'hello' }, { text = true }).stdout)
      end)

      it('handle input', function()
        eq('hellocat', system({ 'cat' }, { stdin = 'hellocat', text = true }).stdout)
      end)

      it('uses real pipes for stdin/stdout #35984', function()
        if t.is_os('win') then
          return -- Not applicable for Windows.
        end
        local res = system(
          { 'bash', '-c', 'wc /dev/stdin > /dev/stdout' },
          { stdin = 'pipe\npipy text\n' }
        )
        eq({ '2', '3', '15', '/dev/stdin' }, vim.split(res.stdout, '%s+', { trimempty = true }))
      end)

      it('can set environment', function()
        local function test_env(opt)
          eq('TESTVAL', system({ n.testprg('printenv-test'), 'TEST' }, opt).stdout)
        end

        test_env({ env = { TEST = 'TESTVAL' }, text = true })
        test_env({ clear_env = true, env = { TEST = 'TESTVAL' }, text = true })
      end)

      it('can set environment with clear_env = true and env = nil', function()
        exec_lua(function()
          vim.env.TEST = 'TESTVAL'
        end)

        -- Not passing env with clear_env should not clear the environment
        eq(
          'TESTVAL',
          system({ n.testprg('printenv-test'), 'TEST' }, { clear_env = true, text = true }).stdout
        )

        -- Passing env = {} with clear_env should clear the environment
        eq(
          '',
          system(
            { n.testprg('printenv-test'), 'TEST' },
            { env = {}, clear_env = true, text = true }
          ).stdout
        )
      end)

      it('supports timeout', function()
        if name == 'sync' then
          -- Stops the process (SIGTERM), as the `timeout` option does.
          eq(
            { code = 124, signal = 15, stdout = '', stderr = '' },
            exec_lua(function()
              return vim.system({ 'sleep', '10' }):wait(1)
            end)
          )
        end
        if name == 'sync' and not t.is_os('win') then
          eq(
            { 0, { code = 0, signal = 0, stdout = 'late', stderr = '' } },
            exec_lua(function()
              -- The shell exits before its child closes the inherited output pipes.
              local obj = vim.system({ 'sh', '-c', '(sleep 0.3; printf late) & exit 0' })
              assert(vim.wait(1000, function()
                return obj:is_closing()
              end, nil, true))
              -- After a timeout: the output so far, and exit code of the shell (not 124). #37922
              return { obj:wait(100).code, obj:wait() }
            end)
          )
        end

        eq({
          code = 124,
          signal = 15,
          stdout = '',
          stderr = '',
        }, system({ 'sleep', '10' }, { timeout = 1000 }))
      end)
    end)
  end

  it('timeout excludes prior event-loop blocking #42521', function()
    eq(
      0,
      exec_lua(function(prg)
        vim.uv.sleep(300) -- Ensure stale/outdated cached loop time relative to timeout=200 below.
        return vim.system({ prg, 'PATH' }, { timeout = 200 }):wait().code
      end, n.testprg('printenv-test'))
    )
  end)

  it('kill processes', function()
    exec_lua(function()
      local signal --- @type integer?
      local cmd = vim.system({ 'cat', '-' }, { stdin = true }, function(r)
        signal = r.signal
      end) -- run forever

      cmd:kill('sigint')

      -- wait for the process not to exist
      local done = vim.wait(2000, function()
        return signal ~= nil
      end)

      assert(done, 'process did not exit')

      -- Check the process is no longer running
      local proc = vim.api.nvim_get_proc(cmd.pid)
      assert(not proc, 'process still exists')

      assert(signal == 2)
    end)
  end)

  it('SystemObj:wait(): CTRL-C stops the process, fails with "interrupted"', function()
    exec_lua(function()
      function _G.Wait()
        local signal --- @type integer?
        -- "nvim" handles SIGTERM, which is unwanted here, so use "cat" instead.
        local cmd = vim.system({ 'cat', '-' }, { stdin = true }, function(r)
          signal = r.signal
        end)
        vim.rpcnotify(1, 'ready')
        local _, err = pcall(cmd.wait, cmd)
        vim.wait(2000, function()
          return signal ~= nil
        end)
        vim.rpcnotify(1, 'wait', err, signal)
      end
    end)
    n.feed(':lua _G.Wait()<CR>')
    eq({ 'notification', 'ready', {} }, n.next_msg(5000))
    n.feed('<C-C>')
    eq({ 'notification', 'wait', { 'interrupted', 15 } }, n.next_msg(5000))
  end)

  it('SystemObj:close() stops the process (SIGTERM, SIGKILL), also via Task:close()', function()
    eq(
      { 15, true, 15 },
      exec_lua(function(nvim_prog)
        local cmd = { nvim_prog, '--clean', '--headless' }
        local closed = false
        local obj = vim.system(cmd)
        obj:close(function()
          closed = true
        end)
        assert(vim.wait(5000, function()
          return closed
        end))
        -- After exit, calls `on_close` at once.
        local closed_again = false
        obj:close(function()
          closed_again = true
        end)

        local task_obj --- @type vim.SystemObj?
        local task = vim.async.run(function()
          return vim.async.await(1, function(on_exit)
            task_obj = vim.system(cmd, {}, on_exit)
            return task_obj
          end)
        end)
        task:close()
        assert(vim.wait(5000, function()
          return task:completed()
        end))
        return { obj:wait(0).signal, closed_again, assert(task_obj):wait(0).signal }
      end, n.nvim_prog)
    )

    if t.is_os('win') then
      return
    end
    -- Escalates to SIGKILL after 2s, if SIGTERM doesn't stop it. Does not wait for its descendant
    -- (`sleep`), which keeps the output pipes open.
    eq(
      9,
      exec_lua(function()
        local cmd = { 'sh', '-c', 'trap "" TERM; sleep 10 & echo $!; read x' }
        local obj = vim.system(cmd, { stdin = true })
        local pid = tonumber(obj:wait(5000, function(stdout)
          return stdout:find('\n') ~= nil
        end).stdout)
        local closed = false
        obj:close(function()
          closed = true
        end)
        local ok = vim.wait(5000, function()
          return closed
        end)
        vim.uv.kill(assert(pid), 'sigkill') -- Cleanup.
        assert(ok)
        return obj:wait(0).signal
      end)
    )

    -- After process exit, does not wait for a descendant (`sleep`) that keeps the pipes open.
    exec_lua(function()
      local obj = vim.system({ 'sh', '-c', 'sleep 10 & echo $!' })
      local pid = tonumber(obj:wait(5000, function(stdout)
        return stdout:find('\n') ~= nil
      end).stdout)
      assert(vim.wait(5000, function()
        return obj:is_closing()
      end))
      local closed = false
      obj:close(function()
        closed = true
      end)
      local ok = vim.wait(5000, function()
        return closed
      end)
      vim.uv.kill(assert(pid), 'sigkill') -- Cleanup.
      assert(ok)
    end)
  end)

  it('SystemObj:wait() can return before process exit', function()
    t.skip(t.is_os('win'), 'shell command is POSIX-only')

    exec_lua(function()
      local exited
      local obj = vim.system({ 'sh', '-c', 'echo READY; sleep 1; echo LATER' }, nil, function(out)
        exited = out
      end)
      local res = obj:wait(10000, function(stdout)
        return stdout:match('READY') ~= nil
      end)
      assert(res.code == nil and res.stdout == 'READY\n', vim.inspect(res))
      assert(vim.api.nvim_get_proc(obj.pid), 'process already exited')
      assert(vim.wait(5000, function()
        return exited ~= nil
      end))
      assert(exited.code == 0 and exited.stdout == 'READY\nLATER\n', vim.inspect(exited))
    end)
  end)

  it('SystemObj:wait() does not process non-fast events #27292', function()
    eq(
      false,
      exec_lua(function()
        _G.processed = false
        local cmd = vim.system({ 'sleep', '1' })
        vim.schedule(function()
          _G.processed = true
        end)
        cmd:wait()
        return _G.processed
      end)
    )
    eq(true, exec_lua([[return _G.processed]]))
  end)

  if t.is_os('win') then
    it('can resolve windows command extensions', function()
      t.write_file('test.bat', 'echo hello world')
      n.system_sync({ 'chmod', '+x', 'test.bat' })
      n.system_sync({ './test' })
    end)

    it('launches cmd.exe when shellslash is set', function()
      n.command('set shellslash')
      local path = exec_lua([[return vim.fn.exepath('cmd.exe')]])
      t.neq(nil, path:find('/', 1, true))

      local result = n.system_sync({ 'cmd.exe', '/c', 'echo OK' })
      eq(0, result.code)
      eq('OK\r\n', result.stdout)
      eq('', result.stderr)
    end)
  end

  it('always captures all content of stdout/stderr #30846', function()
    t.skip(n.fn.executable('git') == 0, 'N/A: missing "git" command')
    t.skip(n.fn.isdirectory('.git') == 0, 'N/A: missing ".git" directory')
    eq(
      0,
      exec_lua(function()
        local done = 0
        local fail = 0
        for _ = 1, 200 do
          vim.system(
            { 'git', 'show', ':0:test/functional/plugin/lsp_spec.lua' },
            { text = true },
            function(o)
              if o.code ~= 0 or #o.stdout == 0 then
                fail = fail + 1
              end
              done = done + 1
            end
          )
        end

        local ok = vim.wait(10000, function()
          return done == 200
        end, 200)
        return fail + (ok and 0 or 1)
      end)
    )
  end)
end)
