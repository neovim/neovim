local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local exec_capture = n.exec_capture
local exec_lua = n.exec_lua
local matches = t.matches

describe(':uptime', function()
  it('works', function()
    clear()
    matches([[Up %d+ seconds?]], exec_capture('uptime'))
  end)

  it('works without runtime', function()
    clear {
      args_rm = { '-u' },
      args = { '-u', 'NONE' },
      env = { VIMRUNTIME = 'non-existent' },
    }
    exec_lua(function()
      vim.cmd('uptime')
    end)
  end)
end)
