-- Test suite for testing interactions with API bindings
local helpers = require('test.functional.helpers')(after_each)

local exec_lua = helpers.exec_lua
local command = helpers.command
local eq = helpers.eq

describe('vim.loader', function()
  before_each(helpers.clear)

  it('handles changing files (#23027)', function()
    exec_lua[[
      vim.loader.enable()
    ]]

    local tmp = helpers.tmpname()
    command('edit ' .. tmp)

    eq(1, exec_lua([[
      vim.api.nvim_buf_set_lines(0, 0, -1, true, {'_G.TEST=1'})
      vim.cmd.write()
      loadfile(...)()
      return _G.TEST
    ]], tmp))

    -- fs latency
    helpers.sleep(10)

    eq(2, exec_lua([[
      vim.api.nvim_buf_set_lines(0, 0, -1, true, {'_G.TEST=2'})
      vim.cmd.write()
      loadfile(...)()
      return _G.TEST
    ]], tmp))
  end)
end)
