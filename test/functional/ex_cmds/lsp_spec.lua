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
      vim.cmd('set ft=lua')
    end)
  end)

  it('enable with arguments', function()
    local is_enabled = exec_lua(function()
      vim.cmd('lsp enable dummy')
      return vim.lsp.is_enabled('dummy')
    end)
    eq(true, is_enabled)
  end)

  it('enable without arguments', function()
    local is_enabled = exec_lua(function()
      vim.cmd('lsp enable')
      return vim.lsp.is_enabled('dummy')
    end)
    eq(true, is_enabled)
  end)

  it('disable with arguments', function()
    local is_enabled = exec_lua(function()
      vim.lsp.enable('dummy')
      vim.cmd('lsp disable dummy')
      return vim.lsp.is_enabled('dummy')
    end)
    eq(false, is_enabled)
  end)

  it('disable without arguments', function()
    local is_enabled = exec_lua(function()
      vim.lsp.enable('dummy')
      vim.cmd('lsp disable')
      return vim.lsp.is_enabled('dummy')
    end)
    eq(false, is_enabled)
  end)

  it('restart with arguments', function()
    local ids_differ = exec_lua(function()
      vim.lsp.enable('dummy')
      local old_id = vim.lsp.get_clients()[1].id

      vim.cmd('lsp restart dummy')
      vim.wait(1000, function()
        return old_id ~= vim.lsp.get_clients()[1].id
      end)
      local new_id = vim.lsp.get_clients()[1].id
      return old_id ~= new_id
    end)
    eq(true, ids_differ)
  end)

  it('restart without arguments', function()
    local ids_differ = exec_lua(function()
      vim.lsp.enable('dummy')
      local old_id = vim.lsp.get_clients()[1].id

      vim.cmd('lsp restart')
      vim.wait(1000, function()
        return old_id ~= vim.lsp.get_clients()[1].id
      end)
      local new_id = vim.lsp.get_clients()[1].id
      return old_id ~= new_id
    end)
    eq(true, ids_differ)
  end)

  it('stop with arguments', function()
    local running_clients = exec_lua(function()
      vim.lsp.enable('dummy')
      vim.cmd('lsp stop dummy')
      vim.wait(1000, function()
        return #vim.lsp.get_clients() == 0
      end)
      return #vim.lsp.get_clients()
    end)
    eq(0, running_clients)
  end)

  it('stop without arguments', function()
    local running_clients = exec_lua(function()
      vim.lsp.enable('dummy')
      vim.cmd('lsp stop')
      vim.wait(1000, function()
        return #vim.lsp.get_clients() == 0
      end)
      return #vim.lsp.get_clients()
    end)
    eq(0, running_clients)
  end)
end)
