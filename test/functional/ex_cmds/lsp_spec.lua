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

  it('fails if runtime is missing/broken', function()
    clear {
      args_rm = { '-u' },
      args = { '-u', 'NONE' },
      env = { VIMRUNTIME = 'non-existent' },
    }
    t.matches(
      [[Vim%(lsp%):Lua: .*module 'vim%.lsp' not found:]],
      vim.split(t.pcall_err(n.command, 'lsp enable dummy'), '\n')[1]
    )
  end)

  for _, test_with_arguments in ipairs({ true, false }) do
    local test_message_suffix, lsp_command_suffix
    if test_with_arguments then
      test_message_suffix = ' with arguments'
      lsp_command_suffix = ' dummy'
    else
      test_message_suffix = ' without arguments'
      lsp_command_suffix = ''
    end

    it('enable' .. test_message_suffix, function()
      local is_enabled = exec_lua(function()
        vim.cmd('lsp enable' .. lsp_command_suffix)
        return vim.lsp.is_enabled('dummy')
      end)
      eq(true, is_enabled)
    end)

    it('disable' .. test_message_suffix, function()
      local is_enabled = exec_lua(function()
        vim.lsp.enable('dummy')
        vim.cmd('lsp disable' .. lsp_command_suffix)
        return vim.lsp.is_enabled('dummy')
      end)
      eq(false, is_enabled)
    end)

    it('restart' .. test_message_suffix, function()
      local ids_differ = exec_lua(function()
        vim.lsp.enable('dummy')
        local old_id = vim.lsp.get_clients()[1].id

        vim.cmd('lsp restart' .. lsp_command_suffix)
        vim.wait(1000, function()
          return old_id ~= vim.lsp.get_clients()[1].id
        end)
        local new_id = vim.lsp.get_clients()[1].id
        return old_id ~= new_id
      end)
      eq(true, ids_differ)
    end)

    it('stop' .. test_message_suffix, function()
      local running_clients = exec_lua(function()
        vim.lsp.enable('dummy')
        vim.cmd('lsp stop' .. lsp_command_suffix)
        vim.wait(1000, function()
          return #vim.lsp.get_clients() == 0
        end)
        return #vim.lsp.get_clients()
      end)
      eq(0, running_clients)
    end)
  end

  it('subcommand completion', function()
    local completions = exec_lua(function()
      return vim.fn.getcompletion('lsp ', 'cmdline')
    end)
    eq({ 'disable', 'enable', 'restart', 'stop' }, completions)
  end)

  it('argument completion', function()
    local completions = exec_lua(function()
      return vim.fn.getcompletion('lsp enable ', 'cmdline')
    end)
    eq({ 'dummy' }, completions)
  end)

  it('argument completion with spaces', function()
    local cmd_length = exec_lua(function()
      local server = _G._create_server()
      vim.lsp.config('client name with space', {
        cmd = server.cmd,
      })
      local completion = vim.fn.getcompletion('lsp enable cl ', 'cmdline')[1]
      return #vim.api.nvim_parse_cmd('lsp enable ' .. completion, {}).args
    end)
    eq(2, cmd_length)
  end)

  it('argument completion with special characters', function()
    local cmd_length = exec_lua(function()
      local server = _G._create_server()
      vim.lsp.config('client"name|with\tsymbols', {
        cmd = server.cmd,
      })
      local completion = vim.fn.getcompletion('lsp enable cl ', 'cmdline')[1]
      return #vim.api.nvim_parse_cmd('lsp enable ' .. completion, {}).args
    end)
    eq(2, cmd_length)
  end)
end)
