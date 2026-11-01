local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local t_lsp = require('test.functional.plugin.lsp.testutil')

local describe, it, before_each = t.describe, t.it, t.before_each
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
      [[.*module 'vim%.lsp' not found:]],
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
      --- @type boolean, integer?
      local ids_differ, attached_buffer_count = exec_lua(function()
        vim.lsp.enable('dummy')
        local old_id = vim.lsp.get_clients()[1].id

        vim.cmd('lsp restart' .. lsp_command_suffix)
        return vim.wait(1000, function()
          local new_client = vim.lsp.get_clients()[1]
          if new_client == nil then
            return false
          end
          return old_id ~= new_client.id, #new_client.attached_buffers
        end)
      end)
      eq(true, ids_differ)
      eq(1, attached_buffer_count)
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

  it('stop, restart, disable a client that has not initialized', function()
    local starts = t.tmpname()
    eq(
      { { 'dummy' }, true, true, true },
      exec_lua(function()
        local server = _G._create_server({ handlers = { initialize = function() end } })
        vim.lsp.config('dummy', {
          cmd = function(...)
            vim.fn.writefile({ 'start' }, starts, 'a')
            return server.cmd(...)
          end,
        })
        local function clients()
          return vim.lsp.get_clients({ _uninitialized = true })
        end
        local function stopped()
          return vim.wait(1000, function()
            return #clients() == 0
          end)
        end
        vim.lsp.enable('dummy')
        local old_id = clients()[1].id
        local completion = vim.fn.getcompletion('lsp stop ', 'cmdline')

        vim.cmd('lsp restart dummy')
        local restarted = vim.wait(1000, function()
          return #clients() == 1 and clients()[1].id ~= old_id
        end)

        vim.cmd('lsp stop')
        local stopped_by_stop = stopped()

        vim.lsp.enable('dummy')
        vim.cmd('lsp disable')
        return { completion, restarted, stopped_by_stop, stopped() }
      end)
    )

    -- No restart while Nvim exits: nothing would stop the new client.
    n.expect_exit(exec_lua, function()
      vim.fn.writefile({}, starts)
      vim.lsp.enable('dummy')
      vim.cmd('lsp restart dummy')
      vim.cmd('qall!')
    end)
    eq('start\n', t.read_file(starts))
  end)

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
