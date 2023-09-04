local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local exec_lua = helpers.exec_lua
local eq = helpers.eq

local function system_sync(cmd, opts)
  return exec_lua([[
    local obj = vim.system(...)
    local pid = obj.pid
    local res = obj:wait()

    -- Check the process is no longer running
    vim.fn.systemlist({'ps', 'p', tostring(pid)})
    assert(vim.v.shell_error == 1, 'process still exists')

    return res
  ]], cmd, opts)
end

local function system_async(cmd, opts)
  return exec_lua([[
    local cmd, opts = ...
    _G.done = false
    local obj = vim.system(cmd, opts, function(obj)
      _G.done = true
      _G.ret = obj
    end)

    local done = vim.wait(10000, function()
      return _G.done
    end)

    assert(done, 'process did not exit')

    -- Check the process is no longer running
    vim.fn.systemlist({'ps', 'p', tostring(obj.pid)})
    assert(vim.v.shell_error == 1, 'process still exists')

    return _G.ret
  ]], cmd, opts)
end

describe('vim.system', function()
  before_each(function()
    clear()
  end)

  for name, system in pairs{ sync = system_sync, async = system_async, } do
    describe('('..name..')', function()
      it('can run simple commands', function()
        eq('hello\n', system({'echo', 'hello' }, { text = true }).stdout)
      end)

      it('handle input', function()
        eq('hellocat', system({ 'cat' }, { stdin = 'hellocat', text = true }).stdout)
      end)

      it('supports timeout', function()
        eq({
          code = 124,
          signal = 15,
          stdout = '',
          stderr = ''
        }, system({ 'sleep', '10' }, { timeout = 1 }))
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
      vim.fn.systemlist({'ps', 'p', tostring(cmd.pid)})
      assert(vim.v.shell_error == 1, 'dwqdqd '..vim.v.shell_error)

      assert(signal == 2)
    ]])
  end)

end)
