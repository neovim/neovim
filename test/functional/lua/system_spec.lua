local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local exec_lua = n.exec_lua
local eq = t.eq

local function system_sync(cmd, opts)
  return exec_lua(function()
    local obj = vim.system(cmd, opts)

    if opts and opts.timeout then
      -- Minor delay before calling wait() so the timeout uv timer can have a headstart over the
      -- internal call to vim.wait() in wait().
      vim.wait(10)
    end

    local res = obj:wait()

    -- Check the process is no longer running
    assert(not vim.api.nvim_get_proc(obj.pid), 'process still exists')

    return res
  end)
end

local function system_async(cmd, opts)
  return exec_lua(function()
    local done = false
    local res --- @type vim.SystemCompleted?
    local obj = vim.system(cmd, opts, function(obj)
      done = true
      res = obj
    end)

    local ok = vim.wait(10000, function()
      return done
    end)

    assert(ok, 'process did not exit')

    -- Check the process is no longer running
    assert(not vim.api.nvim_get_proc(obj.pid), 'process still exists')

    return res
  end)
end

describe('vim.system', function()
  before_each(function()
    clear()
  end)

  for name, system in pairs { sync = system_sync, async = system_async } do
    describe('(' .. name .. ')', function()
      it('can run simple commands', function()
        eq('hello\n', system({ 'echo', 'hello' }, { text = true }).stdout)
      end)

      it('handle input', function()
        eq('hellocat', system({ 'cat' }, { stdin = 'hellocat', text = true }).stdout)
      end)

      it('supports timeout', function()
        eq({
          code = 124,
          signal = 15,
          stdout = '',
          stderr = '',
        }, system({ 'sleep', '10' }, { timeout = 1000 }))
      end)
    end)
  end

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
      system_sync({ 'chmod', '+x', 'test.bat' })
      system_sync({ './test' })
    end)
  end

  it('always captures all content of stdout/stderr #30846', function()
    t.skip(n.fn.executable('git') == 0, 'missing "git" command')
    t.skip(n.fn.isdirectory('.git') == 0, 'missing ".git" directory')
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
