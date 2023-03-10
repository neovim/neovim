local helpers = require('test.functional.helpers')(after_each)
local exec_lua = helpers.exec_lua
local eq = helpers.eq
local eval = helpers.eval
local clear = helpers.clear

describe('vim.inspect_pos', function()
  before_each(function()
    clear()
  end)

  it('it returns items', function()
    local ret = exec_lua([[
      local buf = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_set_current_buf(buf)
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {"local a = 123"})
      vim.api.nvim_buf_set_option(buf, "filetype", "lua")
      vim.cmd("syntax on")
      return {buf, vim.inspect_pos(0, 0, 10)}
    ]])
    local buf, items = unpack(ret)
    eq('', eval('v:errmsg'))
    eq({
      buffer = buf,
      col = 10,
      row = 0,
      extmarks = {},
      treesitter = {},
      semantic_tokens = {},
      syntax = {
        {
          hl_group = 'luaNumber',
          hl_group_link = 'Constant',
        },
      },
    }, items)
  end)
end)

describe('vim.show_pos', function()
  before_each(function()
    clear()
  end)

  it('it does not error', function()
    exec_lua([[
      local buf = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_set_current_buf(buf)
      vim.api.nvim_buf_set_lines(0, 0, -1, false, {"local a = 123"})
      vim.api.nvim_buf_set_option(buf, "filetype", "lua")
      vim.cmd("syntax on")
      return {buf, vim.show_pos(0, 0, 10)}
    ]])
    eq('', eval('v:errmsg'))
  end)
end)
