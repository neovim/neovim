-- Test suite for vim.range
local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local eq = t.eq

local clear = n.clear
local exec_lua = n.exec_lua
local insert = n.insert

describe('vim.range', function()
  before_each(clear)
  after_each(clear)

  it('creates a range with or without optional fields', function()
    local range = exec_lua(function()
      return vim.range(3, 5, 4, 6)
    end)
    eq(3, range.start.row)
    eq(5, range.start.col)
    eq(4, range.end_.row)
    eq(6, range.end_.col)
    eq(nil, range.start.buf)
    eq(nil, range.end_.buf)
    local buf = exec_lua(function()
      return vim.api.nvim_create_buf(false, true)
    end)
    range = exec_lua(function()
      return vim.range(3, 5, 4, 6, { buf = buf })
    end)
    eq(buf, range.start.buf)
    eq(buf, range.end_.buf)
  end)

  it('create a range from two positions when optional fields are not matched', function()
    local range = exec_lua(function()
      return vim.range(vim.pos(3, 5), vim.pos(4, 6))
    end)
    eq(3, range.start.row)
    eq(5, range.start.col)
    eq(4, range.end_.row)
    eq(6, range.end_.col)
    eq(nil, range.start.buf)
    eq(nil, range.end_.buf)

    local buf1 = exec_lua(function()
      return vim.api.nvim_create_buf(false, true)
    end)
    range = exec_lua(function()
      return vim.range(vim.pos(3, 5, { buf = buf1 }), vim.pos(4, 6, { buf = buf1 }))
    end)
    eq(buf1, range.start.buf)
    eq(buf1, range.end_.buf)

    local buf2 = exec_lua(function()
      return vim.api.nvim_create_buf(false, true)
    end)
    local success = exec_lua(function()
      return pcall(function()
        return vim.range(vim.pos(3, 5, { buf = buf1 }), vim.pos(4, 6, { buf = buf2 }))
      end)
    end)
    eq(success, false)
  end)

  it('supports conversion between vim.Range and lsp.Range', function()
    local buf = exec_lua(function()
      return vim.api.nvim_get_current_buf()
    end)
    insert('Neovim 是 Vim 的分支，专注于扩展性和可用性。')
    local lsp_range = exec_lua(function()
      local range = vim.range(0, 10, 0, 36, { buf = buf })
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
      start = { row = 0, col = 10, buf = buf },
      end_ = { row = 0, col = 36, buf = buf },
    }, range)
  end)
end)
