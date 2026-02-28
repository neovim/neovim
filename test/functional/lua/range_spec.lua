-- Test suite for vim.range
local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local eq = t.eq

local clear = n.clear
local exec_lua = n.exec_lua
local insert = n.insert

describe('vim.range', function()
  before_each(clear)

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

  it('creates a range from two positions when optional fields are not matched', function()
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

  it('converts between vim.Range and lsp.Range', function()
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

  it(':has()', function()
    -- has(vim.range)
    eq(
      true,
      exec_lua(function()
        return vim.range(0, 0, 1, 5):has(vim.range(0, 10, 0, 36))
      end)
    )
    eq(
      false,
      exec_lua(function()
        return vim.range(1, 2, 9, 99):has(vim.range(0, 10, 0, 36))
      end)
    )
    eq(
      false,
      exec_lua(function()
        return vim.range(0, 0, 1, 5):has(vim.range(0, 10, 1, 36))
      end)
    )

    -- has(vim.pos)
    eq(
      true,
      exec_lua(function()
        return vim.range(0, 0, 1, 5):has(vim.pos(0, 1))
      end)
    )

    -- has(vim.range) with identical ranges
    eq(
      true,
      exec_lua(function()
        return vim.range(0, 0, 1, 5):has(vim.range(0, 0, 1, 5))
      end)
    )

    -- has(vim.range) where inner starts before outer
    eq(
      false,
      exec_lua(function()
        return vim.range(1, 0, 2, 0):has(vim.range(0, 5, 1, 5))
      end)
    )

    -- has(vim.range) where inner ends after outer
    eq(
      false,
      exec_lua(function()
        return vim.range(0, 0, 1, 5):has(vim.range(0, 0, 2, 0))
      end)
    )

    -- has(vim.range) single row ranges
    eq(
      true,
      exec_lua(function()
        return vim.range(0, 0, 0, 10):has(vim.range(0, 3, 0, 7))
      end)
    )

    -- has(vim.range) single row range where inner extends beyond outer
    eq(
      false,
      exec_lua(function()
        return vim.range(0, 0, 0, 10):has(vim.range(0, 5, 0, 15))
      end)
    )

    -- has(vim.pos) at start boundary
    eq(
      true,
      exec_lua(function()
        return vim.range(0, 0, 1, 5):has(vim.pos(0, 0))
      end)
    )

    -- has(vim.pos) at end boundary (exclusive, should return false)
    eq(
      false,
      exec_lua(function()
        return vim.range(0, 0, 1, 5):has(vim.pos(1, 5))
      end)
    )

    -- has(vim.pos) before range
    eq(
      false,
      exec_lua(function()
        return vim.range(1, 0, 2, 0):has(vim.pos(0, 5))
      end)
    )

    -- has(vim.pos) after range
    eq(
      false,
      exec_lua(function()
        return vim.range(0, 0, 1, 5):has(vim.pos(2, 0))
      end)
    )

    -- has(vim.pos) in middle of range on same line
    eq(
      true,
      exec_lua(function()
        return vim.range(0, 0, 0, 10):has(vim.pos(0, 5))
      end)
    )

    -- has(vim.pos) in middle of multiline range
    eq(
      true,
      exec_lua(function()
        return vim.range(0, 0, 5, 10):has(vim.pos(2, 5))
      end)
    )

    -- has(vim.range) with buffer field
    local buf = exec_lua(function()
      return vim.api.nvim_create_buf(false, true)
    end)
    eq(
      true,
      exec_lua(function(buf)
        return vim.range(0, 0, 1, 5, { buf = buf }):has(vim.range(0, 1, 0, 3, { buf = buf }))
      end, buf)
    )

    -- has(vim.pos) with buffer field
    eq(
      true,
      exec_lua(function(buf)
        return vim.range(0, 0, 1, 5, { buf = buf }):has(vim.pos(0, 2, { buf = buf }))
      end, buf)
    )

    -- has(vim.range) empty range at start
    eq(
      true,
      exec_lua(function()
        return vim.range(0, 0, 2, 0):has(vim.range(0, 0, 0, 0))
      end)
    )

    -- has(vim.range) empty range at end
    eq(
      false,
      exec_lua(function()
        return vim.range(0, 0, 2, 0):has(vim.range(2, 0, 2, 0))
      end)
    )
  end)
end)
