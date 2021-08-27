local helpers = require('test.functional.helpers')(after_each)
local exec_lua = helpers.exec_lua
local eq = helpers.eq
local eval = helpers.eval
local command = helpers.command
local clear = helpers.clear

describe('vim.highlight.on_yank', function()

  before_each(function()
    clear()
  end)

  it('does not show errors even if buffer is wiped before timeout', function()
    command('new')
    exec_lua[[
      vim.highlight.on_yank({timeout = 10, on_macro = true, event = {operator = "y", regtype = "v"}})
      vim.cmd('bwipeout!')
    ]]
    helpers.sleep(10)
    helpers.feed('<cr>') -- avoid hang if error message exists
    eq('', eval('v:errmsg'))
  end)

end)
