local t = require('test.functional.testutil')(after_each)
local clear = t.clear
local exec_lua = t.exec_lua
local eq = t.eq

local function system_sync(cmd, opts)
  return exec_lua(
    [[
    local cmd, opts = ...
    local obj = vim.system(...)

    if opts.timeout then
      -- Minor delay before calling wait() so the timeout uv timer can have a headstart over the
      -- internal call to vim.wait() in wait().
      vim.wait(10)
    end

    local res = obj:wait()

    -- Check the process is no longer running
    local proc = vim.api.nvim_get_proc(obj.pid)
    assert(not proc, 'process still exists')

    return res
  ]],
    cmd,
    opts
  )
end

local function system_async(cmd, opts)
  return exec_lua(
    [[
    local cmd, opts = ...
    _G.done = false
    local obj = vim.system(cmd, opts, function(obj)
      _G.done = true
      _G.ret = obj
    end)

    local ok = vim.wait(10000, function()
      return _G.done
    end)

    assert(ok, 'process did not exit')

    -- Check the process is no longer running
    local proc = vim.api.nvim_get_proc(obj.pid)
    assert(not proc, 'process still exists')

    return _G.ret
  ]],
    cmd,
    opts
  )
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
    exec_lua([[
      local signal
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
    ]])
  end)

  it('SystemObj:wait() does not process non-fast events #27292', function()
    eq(
      false,
      exec_lua([[
        _G.processed = false
        local cmd = vim.system({ 'sleep', '1' })
        vim.schedule(function() _G.processed = true end)
        cmd:wait()
        return _G.processed
      ]])
    )
    eq(true, exec_lua([[return _G.processed]]))
  end)
end)
