local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local exec_lua = n.exec_lua
local eq = t.eq
local eval = n.eval
local clear = n.clear

describe('vim.inspect_pos', function()
  before_each(function()
    clear()
  end)

  it('it returns items', function()
    local buf, ns1, ns2 = exec_lua(function()
      local buf = vim.api.nvim_create_buf(true, false)
      _G.buf1 = vim.api.nvim_create_buf(true, false)
      local ns1 = vim.api.nvim_create_namespace('ns1')
      local ns2 = vim.api.nvim_create_namespace('')
      vim.api.nvim_set_current_buf(buf)
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'local a = 123' })
      vim.api.nvim_buf_set_lines(_G.buf1, 0, -1, false, { '--commentline' })
      vim.bo[buf].filetype = 'lua'
      vim.bo[_G.buf1].filetype = 'lua'
      vim.api.nvim_buf_set_extmark(buf, ns1, 0, 10, { hl_group = 'Normal' })
      vim.api.nvim_buf_set_extmark(buf, ns1, 0, 10, { hl_group = 'Normal', end_col = 10 })
      vim.api.nvim_buf_set_extmark(buf, ns2, 0, 10, { hl_group = 'Normal', end_col = 11 })
      vim.cmd('syntax on')
      return buf, ns1, ns2
    end)

    eq('', eval('v:errmsg'))
    -- Only visible highlights with `filter.extmarks == true`
    eq({
      buffer = buf,
      col = 10,
      row = 0,
      extmarks = {
        {
          col = 10,
          end_col = 11,
          end_row = 0,
          id = 1,
          ns = '',
          ns_id = ns2,
          opts = {
            end_row = 0,
            end_col = 11,
            hl_eol = false,
            hl_group = 'Normal',
            hl_group_link = 'Normal',
            ns_id = ns2,
            priority = 4096,
            right_gravity = true,
            end_right_gravity = false,
          },
          row = 0,
        },
      },
      treesitter = {},
      semantic_tokens = {},
      syntax = { { hl_group = 'luaNumber', hl_group_link = 'Constant' } },
    }, exec_lua('return vim.inspect_pos(0, 0, 10)'))
    -- All extmarks with `filters.extmarks == 'all'`
    eq({
      buffer = buf,
      col = 10,
      row = 0,
      extmarks = {
        {
          col = 10,
          end_col = 10,
          end_row = 0,
          id = 1,
          ns = 'ns1',
          ns_id = ns1,
          opts = {
            hl_eol = false,
            hl_group = 'Normal',
            hl_group_link = 'Normal',
            ns_id = ns1,
            priority = 4096,
            right_gravity = true,
          },
          row = 0,
        },
        {
          col = 10,
          end_col = 11,
          end_row = 0,
          id = 1,
          ns = '',
          ns_id = ns2,
          opts = {
            end_row = 0,
            end_col = 11,
            hl_eol = false,
            hl_group = 'Normal',
            hl_group_link = 'Normal',
            ns_id = ns2,
            priority = 4096,
            right_gravity = true,
            end_right_gravity = false,
          },
          row = 0,
        },
        {
          col = 10,
          end_col = 10,
          end_row = 0,
          id = 2,
          ns = 'ns1',
          ns_id = ns1,
          opts = {
            end_row = 0,
            end_col = 10,
            hl_eol = false,
            hl_group = 'Normal',
            hl_group_link = 'Normal',
            ns_id = ns1,
            priority = 4096,
            right_gravity = true,
            end_right_gravity = false,
          },
          row = 0,
        },
      },
      treesitter = {},
      semantic_tokens = {},
      syntax = { { hl_group = 'luaNumber', hl_group_link = 'Constant' } },
    }, exec_lua('return vim.inspect_pos(0, 0, 10, { extmarks = "all" })'))
    -- Syntax from other buffer.
    eq({
      { hl_group = 'luaComment', hl_group_link = 'Comment' },
    }, exec_lua('return vim.inspect_pos(_G.buf1, 0, 10).syntax'))
  end)
end)

describe('vim.show_pos', function()
  before_each(function()
    clear()
  end)

  it('it does not error', function()
    exec_lua(function()
      local buf = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_set_current_buf(buf)
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'local a = 123' })
      vim.bo[buf].filetype = 'lua'
      vim.cmd('syntax on')
      return { buf, vim.show_pos(0, 0, 10) }
    end)
    eq('', eval('v:errmsg'))
  end)
end)
