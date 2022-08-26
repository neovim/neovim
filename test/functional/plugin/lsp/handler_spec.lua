local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local exec_lua = helpers.exec_lua
local pcall_err = helpers.pcall_err
local matches = helpers.matches

describe('lsp-handlers', function()
  describe('vim.lsp._with_extend', function()
    it('should return a table with the default keys', function()
      eq({hello = 'world' }, exec_lua [[
        return vim.lsp._with_extend('test', { hello = 'world' })
      ]])
    end)

    it('should override with config keys', function()
      eq({hello = 'universe', other = true}, exec_lua [[
        return vim.lsp._with_extend('test', { other = true, hello = 'world' }, { hello = 'universe' })
      ]])
    end)

    it('should not allow invalid keys', function()
      matches(
        '.*Invalid option for `test`.*',
        pcall_err(exec_lua, "return vim.lsp._with_extend('test', { hello = 'world' }, { invalid = true })")
      )
    end)
  end)
end)
