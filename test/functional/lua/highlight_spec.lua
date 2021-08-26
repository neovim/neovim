local helpers = require('test.functional.helpers')(after_each)
local funcs = helpers.funcs
local exec_lua = helpers.exec_lua
local command = helpers.command
local clear = helpers.clear

describe('vim.highlight.on_yank', function()

  before_each(function()
    clear()
  end)

  it('does not show errors even if buffer is wiped before timeout', function()
    command('new')
    local bufnr = funcs.bufnr("%")
    exec_lua[[
      vim.highlight.on_yank({timeout = 10, on_macro = true, event = {operator = "y", regtype = "v"}})
      vim.cmd('bwipeout!')
    ]]
    exec_lua[[vim.wait(10)]]
    local pattern = [[vim/highlight.lua:%d+: Invalid buffer id: ]] .. bufnr
    local exists = pcall(helpers.assert_log, pattern)
    assert.is_false(exists, string.format("%q should not be in log", pattern))
  end)

end)
