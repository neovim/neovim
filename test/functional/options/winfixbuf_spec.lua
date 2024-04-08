local t = require('test.functional.testutil')(after_each)
local clear = t.clear
local exec_lua = t.exec_lua

describe("Nvim API calls with 'winfixbuf'", function()
  before_each(function()
    clear()
  end)

  it("Calling vim.api.nvim_win_set_buf with 'winfixbuf'", function()
    local results = exec_lua([[
      local function _setup_two_buffers()
        local buffer = vim.api.nvim_create_buf(true, true)

        vim.api.nvim_create_buf(true, true)  -- Make another buffer

        local current_window = 0
        vim.api.nvim_set_option_value("winfixbuf", true, {win=current_window})

        return buffer
      end

      local other_buffer = _setup_two_buffers()
      local current_window = 0
      local results, _ = pcall(vim.api.nvim_win_set_buf, current_window, other_buffer)

      return results
    ]])

    assert(results == false)
  end)

  it("Calling vim.api.nvim_set_current_buf with 'winfixbuf'", function()
    local results = exec_lua([[
      local function _setup_two_buffers()
        local buffer = vim.api.nvim_create_buf(true, true)

        vim.api.nvim_create_buf(true, true)  -- Make another buffer

        local current_window = 0
        vim.api.nvim_set_option_value("winfixbuf", true, {win=current_window})

        return buffer
      end

      local other_buffer = _setup_two_buffers()
      local results, _ = pcall(vim.api.nvim_set_current_buf, other_buffer)

      return results
    ]])

    assert(results == false)
  end)
end)
