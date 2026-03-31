local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local clear = n.clear
local exec_lua = n.exec_lua
local eq = t.eq

describe('vim.func._memoize', function()
  before_each(clear)

  it('caches function results based on their parameters', function()
    exec_lua([[
      _G.count = 0

      local adder = vim.func._memoize('concat', function(arg1, arg2)
        _G.count = _G.count + 1
        return arg1 + arg2
      end)

      collectgarbage('stop')
      adder(3, -4)
      adder(3, -4)
      adder(3, -4)
      adder(3, -4)
      adder(3, -4)
      collectgarbage('restart')
    ]])

    eq(1, exec_lua([[return _G.count]]))
  end)

  it('caches function results using a weak table by default', function()
    exec_lua([[
      _G.count = 0

      local adder = vim.func._memoize('concat-2', function(arg1, arg2)
        _G.count = _G.count + 1
        return arg1 + arg2
      end)

      adder(3, -4)
      collectgarbage()
      adder(3, -4)
      collectgarbage()
      adder(3, -4)
    ]])

    eq(3, exec_lua([[return _G.count]]))
  end)

  it('can cache using a strong table', function()
    exec_lua([[
      _G.count = 0

      local adder = vim.func._memoize('concat-2', function(arg1, arg2)
        _G.count = _G.count + 1
        return arg1 + arg2
      end, false)

      adder(3, -4)
      collectgarbage()
      adder(3, -4)
      collectgarbage()
      adder(3, -4)
    ]])

    eq(1, exec_lua([[return _G.count]]))
  end)

  it('can clear a single cache entry', function()
    exec_lua([[
      _G.count = 0

      local adder = vim.func._memoize(function(arg1, arg2)
        return tostring(arg1) .. '%%' .. tostring(arg2)
      end, function(arg1, arg2)
        _G.count = _G.count + 1
        return arg1 + arg2
      end)

      collectgarbage('stop')
      adder(3, -4)
      adder(3, -4)
      adder(3, -4)
      adder(3, -4)
      adder(3, -4)
      adder:clear(3, -4)
      adder(3, -4)
      collectgarbage('restart')
    ]])

    eq(2, exec_lua([[return _G.count]]))
  end)

  it('can clear the entire cache', function()
    exec_lua([[
      _G.count = 0

      local adder = vim.func._memoize(function(arg1, arg2)
        return tostring(arg1) .. '%%' .. tostring(arg2)
      end, function(arg1, arg2)
        _G.count = _G.count + 1
        return arg1 + arg2
      end)

      collectgarbage('stop')
      adder(1, 2)
      adder(3, -4)
      adder(1, 2)
      adder(3, -4)
      adder(1, 2)
      adder(3, -4)
      adder:clear()
      adder(1, 2)
      adder(3, -4)
      collectgarbage('restart')
    ]])

    eq(4, exec_lua([[return _G.count]]))
  end)

  it('can cache functions that return nil', function()
    exec_lua([[
      _G.count = 0

      local adder = vim.func._memoize('concat', function(arg1, arg2)
        _G.count = _G.count + 1
        return nil
      end)

      collectgarbage('stop')
      adder(1, 2)
      adder(1, 2)
      adder(1, 2)
      adder(1, 2)
      adder:clear()
      adder(1, 2)
      collectgarbage('restart')
    ]])

    eq(2, exec_lua([[return _G.count]]))
  end)
end)
