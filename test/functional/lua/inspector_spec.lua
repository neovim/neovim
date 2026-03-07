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
          hl_group = 'Normal',
          hl_group_link = 'Normal',
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
      syntax = {
        {
          hl_group = 'luaNumber',
          hl_group_link = 'Constant',
          row = 0,
          col = 10,
          end_row = 0,
          end_col = 11,
        },
      },
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
          hl_group = 'Normal',
          hl_group_link = 'Normal',
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
          hl_group = 'Normal',
          hl_group_link = 'Normal',
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
          hl_group = 'Normal',
          hl_group_link = 'Normal',
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
      syntax = {
        {
          hl_group = 'luaNumber',
          hl_group_link = 'Constant',
          row = 0,
          col = 10,
          end_row = 0,
          end_col = 11,
        },
      },
    }, exec_lua('return vim.inspect_pos(0, 0, 10, { extmarks = "all" })'))
    -- Syntax from other buffer.
    eq({
      {
        hl_group = 'luaComment',
        hl_group_link = 'Comment',
        row = 0,
        col = 10,
        end_row = 0,
        end_col = 11,
      },
    }, exec_lua('return vim.inspect_pos(_G.buf1, 0, 10).syntax'))
  end)

  it('returns items in a range', function()
    exec_lua(function()
      local buf = vim.api.nvim_create_buf(true, false)
      local ns = vim.api.nvim_create_namespace('range_test')
      vim.api.nvim_set_current_buf(buf)
      -- "local a = 123"
      --  0123456789012 (13 chars)
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'local a = 123' })
      vim.bo[buf].filetype = 'lua'
      -- Extmark spanning cols 6-7 ("a")
      vim.api.nvim_buf_set_extmark(buf, ns, 0, 6, { hl_group = 'Identifier', end_col = 7 })
      -- Extmark spanning cols 10-13 ("123")
      vim.api.nvim_buf_set_extmark(buf, ns, 0, 10, { hl_group = 'Number', end_col = 13 })
      -- Extmark outside range at col 0-5 ("local")
      vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, { hl_group = 'Keyword', end_col = 5 })
      vim.cmd('syntax on')
      _G.buf = buf
      _G.ns = ns
    end)

    -- Range query from col 6 to col 10 (exclusive): should include "a" extmark
    -- but not "123" (starts at col 10 which is the exclusive end) or "local" (ends at col 5)
    local result = exec_lua(function()
      return vim.inspect_pos(0, 0, 6, { end_row = 0, end_col = 10, treesitter = false })
    end)

    eq(0, result.row)
    eq(6, result.col)
    eq(0, result.end_row)
    eq(10, result.end_col)

    -- Should have extmark for "a" (Identifier) which overlaps [6,10)
    -- The "Keyword" extmark ends at col 5, so it doesn't overlap [6,10)
    -- The "Number" extmark starts at col 10, which equals end_col (exclusive), so no overlap
    eq(1, #result.extmarks)
    eq('Identifier', result.extmarks[1].hl_group)

    -- Range query from col 5 to col 13 should include all three extmarks
    local result2 = exec_lua(function()
      return vim.inspect_pos(0, 0, 0, { end_row = 0, end_col = 14, treesitter = false })
    end)
    eq(3, #result2.extmarks)

    -- Syntax: range query should collect unique syntax groups
    local syntax_result = exec_lua(function()
      return vim.inspect_pos(0, 0, 0, {
        end_row = 0,
        end_col = 14,
        extmarks = false,
        treesitter = false,
      })
    end)
    -- Should have syntax items across the range (e.g. luaStatement for 'local', luaNumber for '123')
    assert(#syntax_result.syntax > 0, 'expected syntax items in range')
  end)

  it('single position query omits end_row/end_col from result', function()
    exec_lua(function()
      local buf = vim.api.nvim_create_buf(true, false)
      vim.api.nvim_set_current_buf(buf)
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'hello' })
    end)

    local result = exec_lua('return vim.inspect_pos(0, 0, 0)')
    eq(nil, result.end_row)
    eq(nil, result.end_col)
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
