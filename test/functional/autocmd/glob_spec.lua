local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local eq = t.eq
local matches = t.matches
local exec_lua = n.exec_lua
local pcall_err = t.pcall_err
local api = n.api

describe('autocmd glob patterns', function()
  before_each(clear)

  it('triggers for matching glob via nvim_exec_autocmds', function()
    local called = exec_lua([[
      vim.g.called = 0
      vim.api.nvim_create_autocmd('User', {
        pattern = { glob = '**/foo.txt' },
        callback = function() vim.g.called = vim.g.called + 1 end,
      })
      vim.api.nvim_exec_autocmds('User', { pattern = 'some/path/foo.txt' })
      return vim.g.called
    ]])

    eq(1, called)
  end)

  it('does not trigger for non-matching glob', function()
    local called = exec_lua([[
      vim.g.called = 0
      vim.api.nvim_create_autocmd('User', {
        pattern = { glob = '**/*.watch' },
        callback = function() vim.g.called = vim.g.called + 1 end,
      })
      vim.api.nvim_exec_autocmds('User', { pattern = 'some/path/file.txt' })
      return vim.g.called
    ]])

    eq(0, called)
  end)

  it('errors when pattern table does not contain glob key', function()
    local msg = pcall_err(
      api.nvim_create_autocmd,
      'User',
      { pattern = { somethingelse = true }, command = '' }
    )
    matches('Invalid key', msg)
  end)

  it('errors when glob is invalid', function()
    local msg =
      pcall_err(api.nvim_create_autocmd, 'User', { pattern = { glob = '' }, command = '' })
    matches("pattern table must contain 'glob' key", msg)
    local msg2 =
      pcall_err(api.nvim_create_autocmd, 'User', { pattern = { glob = true }, command = '' })
    matches("Invalid 'glob'", msg2)
    local msg3 = pcall_err(
      api.nvim_create_autocmd,
      'User',
      { pattern = { glob = { 'glob1', 'glob2' } }, command = '' }
    )
    matches("Invalid 'glob'", msg3)
    local msg4 = pcall_err(
      api.nvim_create_autocmd,
      'User',
      { pattern = { glob = '**/**.dart' }, command = '' }
    )
    matches('Failed to set autocmd', msg4)
  end)
end)
