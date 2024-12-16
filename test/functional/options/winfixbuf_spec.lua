local n = require('test.functional.testnvim')()

local clear = n.clear
local exec_lua = n.exec_lua

describe("Nvim API calls with 'winfixbuf'", function()
  before_each(function()
    clear()
  end)

  it('vim.api.nvim_win_set_buf on non-current buffer', function()
    local ok = exec_lua([[
      local function _setup_two_buffers()
        local buffer = vim.api.nvim_create_buf(true, true)

        vim.api.nvim_create_buf(true, true)  -- Make another buffer

        local current_window = 0
        vim.api.nvim_set_option_value("winfixbuf", true, {win=current_window})

        return buffer
      end

      local other_buffer = _setup_two_buffers()
      local current_window = 0
      local ok, _ = pcall(vim.api.nvim_win_set_buf, current_window, other_buffer)

      return ok
    ]])

    assert(not ok)
  end)

  it('vim.api.nvim_set_current_buf on non-current buffer', function()
    local ok = exec_lua([[
      local function _setup_two_buffers()
        local buffer = vim.api.nvim_create_buf(true, true)

        vim.api.nvim_create_buf(true, true)  -- Make another buffer

        local current_window = 0
        vim.api.nvim_set_option_value("winfixbuf", true, {win=current_window})

        return buffer
      end

      local other_buffer = _setup_two_buffers()
      local ok, _ = pcall(vim.api.nvim_set_current_buf, other_buffer)

      return ok
    ]])

    assert(not ok)
  end)

  it('vim.api.nvim_win_set_buf on current buffer', function()
    exec_lua([[
      vim.wo.winfixbuf = true
      local curbuf = vim.api.nvim_get_current_buf()
      vim.api.nvim_win_set_buf(0, curbuf)
      assert(vim.api.nvim_get_current_buf() == curbuf)
    ]])
  end)

  it('vim.api.nvim_set_current_buf on current buffer', function()
    exec_lua([[
      vim.wo.winfixbuf = true
      local curbuf = vim.api.nvim_get_current_buf()
      vim.api.nvim_set_current_buf(curbuf)
      assert(vim.api.nvim_get_current_buf() == curbuf)
    ]])
  end)
end)
