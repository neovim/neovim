local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local exec_lua = helpers.exec_lua
local eq = helpers.eq

local function system_sync(cmd, opts)
  return exec_lua([[
    return vim.system(...):wait()
  ]], cmd, opts)
end

local function system_async(cmd, opts)
  exec_lua([[
    local cmd, opts = ...
    _G.done = false
    vim.system(cmd, opts, function(obj)
      _G.done = true
      _G.ret = obj
    end)
  ]], cmd, opts)

  while true do
    if exec_lua[[return _G.done]] then
      break
    end
  end

  return exec_lua[[return _G.ret]]
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

      it ('supports timeout', function()
        eq({
          code = 0,
          signal = 2,
          stdout = '',
          stderr = "Command timed out: 'sleep 10'"
        }, system({ 'sleep', '10' }, { timeout = 1 }))
      end)
    end)
  end

end)
