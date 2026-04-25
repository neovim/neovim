local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local eq = t.eq
local exec_lua = n.exec_lua
local is_os = t.is_os
local pathsep = n.get_pathsep()
local write_file = t.write_file

describe(':log', function()
  local xstate = 'Xstate'
  local name = (is_os('win') and 'nvim-data' or 'nvim')

  before_each(function()
    clear { env = { XDG_STATE_HOME = xstate } }

    local std_state = xstate .. pathsep .. name
    n.mkdir_p(std_state .. pathsep .. 'logs')
    write_file(std_state .. '/logs/nvim.log', [[nvim log]])
    write_file(std_state .. '/logs/foo.log', [[foo log]])
  end)

  after_each(function()
    n.rmdir(xstate)
  end)

  it('without argument opens log folder', function()
    eq(
      xstate .. '/' .. name .. '/logs',
      exec_lua(function()
        vim.cmd('log')
        return vim.fs.normalize(vim.fn.expand('%'))
      end)
    )
  end)

  it('with argument opens corresponding log file', function()
    eq(
      xstate .. '/' .. name .. '/logs/foo.log',
      exec_lua(function()
        vim.cmd('log foo')
        return vim.fs.normalize(vim.fn.expand('%'))
      end)
    )
  end)

  it('nvim works with non-default $NVIM_LOG_FILE', function()
    clear { env = { XDG_STATE_HOME = xstate, NVIM_LOG_FILE = 'Xfoo.log' } }
    write_file('Xfoo.log', [[nvim log]])
    eq(
      'Xfoo.log',
      exec_lua(function()
        vim.cmd('log nvim')
        return vim.fn.expand('%')
      end)
    )
  end)

  it('argument completion', function()
    local completions = exec_lua(function()
      return vim.fn.getcompletion('log ', 'cmdline')
    end)
    eq({ 'foo', 'nvim' }, completions)
  end)

  it('works without runtime', function()
    clear {
      args_rm = { '-u' },
      args = { '-u', 'NONE' },
      env = { VIMRUNTIME = 'non-existent' },
    }
    exec_lua(function()
      vim.cmd('log')
    end)
  end)
end)
