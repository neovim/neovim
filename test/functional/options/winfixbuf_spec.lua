local n = require('test.functional.testnvim')()
local t = require('test.testutil')

local clear = n.clear
local exec_lua = n.exec_lua

describe("'winfixbuf'", function()
  before_each(function()
    clear()
  end)

  ---@return integer
  local function setup_winfixbuf()
    return exec_lua([[
      local buffer = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_create_buf(true, true)  -- Make another buffer
      vim.wo.winfixbuf = true
      return buffer
    ]])
  end

  it('nvim_win_set_buf on non-current buffer', function()
    local other_buf = setup_winfixbuf()
    t.eq(
      "Vim:E1513: Cannot switch buffer. 'winfixbuf' is enabled",
      t.pcall_err(n.api.nvim_win_set_buf, 0, other_buf)
    )
  end)

  it('nvim_set_current_buf on non-current buffer', function()
    local other_buf = setup_winfixbuf()
    t.eq(
      "Vim:E1513: Cannot switch buffer. 'winfixbuf' is enabled",
      t.pcall_err(n.api.nvim_set_current_buf, other_buf)
    )
  end)

  it('nvim_win_set_buf on current buffer', function()
    setup_winfixbuf()
    local curbuf = n.api.nvim_get_current_buf()
    n.api.nvim_win_set_buf(0, curbuf)
    t.eq(curbuf, n.api.nvim_get_current_buf())
  end)

  it('nvim_set_current_buf on current buffer', function()
    setup_winfixbuf()
    local curbuf = n.api.nvim_get_current_buf()
    n.api.nvim_set_current_buf(curbuf)
    t.eq(curbuf, n.api.nvim_get_current_buf())
  end)
end)
