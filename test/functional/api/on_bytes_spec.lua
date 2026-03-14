local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local eq = t.eq
local api = n.api

describe('API: on_bytes event', function()
  before_each(clear)

  it('handles dd on a single-line buffer correctly', function()
    n.exec_lua(function()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'Hello world' })
      vim.api.nvim_buf_attach(vim.api.nvim_get_current_buf(), false, {
        on_bytes = function(
          _,
          _,
          _,
          _,
          _,
          _,
          old_end_row,
          old_end_col,
          old_end_byte_len,
          new_end_row,
          new_end_col,
          new_end_byte_len
        )
          vim.g.old_end_pos = {
            row = old_end_row,
            col = old_end_col,
            byte_len = old_end_byte_len,
          }
          vim.g.new_end_pos = {
            row = new_end_row,
            col = new_end_col,
            byte_len = new_end_byte_len,
          }
        end,
      })
    end)

    api.nvim_command('normal! dd')

    -- FIXME: old_end_pos should be { row = 0, col = 11, byte_len = 11 }
    local expected_old_pos = { row = 1, col = 0, byte_len = 12 }
    eq(expected_old_pos, api.nvim_get_var('old_end_pos'))

    -- FIXME: new_end_pos should be { row = 0, col = 0, byte_len = 0 }
    local expected_new_pos = { row = 1, col = 0, byte_len = 1 }
    eq(expected_new_pos, api.nvim_get_var('new_end_pos'))
  end)
end)
