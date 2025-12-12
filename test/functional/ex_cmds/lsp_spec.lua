local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local t_lsp = require('test.functional.plugin.lsp.testutil')

local clear = n.clear
local eq = t.eq
local exec_lua = n.exec_lua

local create_server_definition = t_lsp.create_server_definition

describe(':lsp', function()
  before_each(function()
    clear()
    exec_lua(create_server_definition)
    exec_lua(function()
      local server = _G._create_server()
      vim.lsp.config('dummy', {
        filetypes = { 'lua' },
        cmd = server.cmd,
      })
    end)
  end)

  it('enable', function()
    local is_enabled = exec_lua(function()
      vim.cmd('lsp enable dummy')
      return vim.lsp.is_enabled('dummy')
    end)
    eq(true, is_enabled)
  end)

  it('disable', function()
    local is_enabled = exec_lua(function()
      vim.lsp.enable('dummy')
      vim.cmd('lsp disable dummy')
      return vim.lsp.is_enabled('dummy')
    end)
    eq(false, is_enabled)
  end)

  it('restart', function()
    local is_enabled = exec_lua(function()
      vim.lsp.enable('dummy')
      vim.cmd('lsp restart dummy')
      vim.wait(1000, function()
        return vim.lsp.is_enabled('dummy')
      end, 100)
      return vim.lsp.is_enabled('dummy')
    end)
    eq(true, is_enabled)
  end)
end)
