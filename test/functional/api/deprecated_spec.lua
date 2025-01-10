-- Island of misfit toys.
--- @diagnostic disable: deprecated

local t = require('test.testutil')
local n = require('test.functional.testnvim')()

describe('deprecated', function()
  before_each(n.clear)

  describe('nvim_notify', function()
    it('can notify a info message', function()
      n.api.nvim_notify('hello world', 2, {})
    end)

    it('can be overridden', function()
      n.command('lua vim.notify = function(...) return 42 end')
      t.eq(42, n.api.nvim_exec_lua("return vim.notify('Hello world')", {}))
      n.api.nvim_notify('hello world', 4, {})
    end)
  end)
end)
