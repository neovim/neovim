-- Test suite for vim.range
local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local eq = t.eq

local clear = n.clear
local exec_lua = n.exec_lua
local insert = n.insert

describe('vim.range', function()
  before_each(clear)

  it('creates a range', function()
    local range, buf = exec_lua(function()
      local buf = vim.api.nvim_create_buf(false, true)
      return vim.range(buf, 3, 5, 4, 6), buf
    end)
    eq(3, range[1])
    eq(5, range[2])
    eq(4, range[3])
    eq(6, range[4])
    eq(buf, range[5])
  end)

  it('creates a range from two positions', function()
    local range, buf1 = exec_lua(function()
      local buf = vim.api.nvim_create_buf(false, true)
      return vim.range(vim.pos(buf, 3, 5), vim.pos(buf, 4, 6)), buf
    end)
    eq(3, range[1])
    eq(5, range[2])
    eq(4, range[3])
    eq(6, range[4])
    eq(buf1, range[5])

    local buf2 = exec_lua(function()
      return vim.api.nvim_create_buf(false, true)
    end)
    local success = exec_lua(function()
      return pcall(function()
        return vim.range(vim.pos(buf1, 3, 5), vim.pos(buf2, 4, 6))
      end)
    end)
    eq(success, false)
  end)

  it('converts between vim.Range and lsp.Range', function()
    local buf = exec_lua(function()
      return vim.api.nvim_get_current_buf()
    end)
    insert('Neovim 是 Vim 的分支，专注于扩展性和可用性。')
    local lsp_range = exec_lua(function()
      local range = vim.range(buf, 0, 10, 0, 36)
      return range:to_lsp('utf-16')
    end)
    eq({
      ['start'] = { line = 0, character = 8 },
      ['end'] = { line = 0, character = 20 },
    }, lsp_range)
    local range = exec_lua(function()
      return vim.range.lsp(buf, lsp_range, 'utf-16')
    end)
    eq({
      0,
      10,
      0,
      36,
      buf,
    }, range)
  end)

  it('converts between vim.Range and extmark on top of a newline', function()
    local buf = exec_lua(function()
      return vim.api.nvim_get_current_buf()
    end)
    insert('Some text', '\nSome more text')
    local extmark_pos = {
      exec_lua(function()
        local range = vim.range(buf, 0, 0, 1, 0)
        return range:to_extmark()
      end),
    }
    eq({ 0, 0, 0, 9 }, extmark_pos)
    local range = exec_lua(function()
      return vim.range.extmark(buf, extmark_pos[1], extmark_pos[2], extmark_pos[3], extmark_pos[4])
    end)
    eq({ 0, 0, 1, 0, buf }, range)

    local extmark_pos2 = {
      exec_lua(function()
        local range2 = vim.range(buf, 0, 0, 0, 8)
        return range2:to_extmark()
      end),
    }
    eq({ 0, 0, 0, 8 }, extmark_pos2)
    local pos2 = exec_lua(function()
      return vim.range.extmark(
        buf,
        extmark_pos2[1],
        extmark_pos2[2],
        extmark_pos2[3],
        extmark_pos2[4]
      )
    end)
    eq({ 0, 0, 0, 8, buf }, pos2)
  end)

  it('checks whether a range contains a position', function()
    eq(
      true,
      exec_lua(function()
        local buf = vim.api.nvim_create_buf(false, true)
        return vim.range(buf, 0, 0, 1, 5):has(vim.pos(buf, 0, 1))
      end)
    )
  end)

  it('checks whether a range does not contain an empty range just outside it', function()
    eq(
      false,
      exec_lua(function()
        local buf = vim.api.nvim_create_buf(false, true)
        return vim.range(buf, 0, 0, 0, 4):has(vim.range(buf, 0, 0, 0, 0))
      end)
    )
  end)
end)
