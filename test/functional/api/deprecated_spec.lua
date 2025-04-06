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

  describe('nvim_*get_option functions', function()
    it('does not leak memory', function()
      -- String opts caused memory leaks in these functions in Github#32361
      n.exec_lua([[
        vim.api.nvim_get_option('rtp')
        vim.api.nvim_win_get_option(vim.api.nvim_get_current_win(), 'foldmethod')
        vim.api.nvim_buf_get_option(0, 'fileformat')
      ]])
    end)
  end)
end)
