-- Test suite for vim.pos
local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local eq = t.eq

local clear = n.clear
local exec_lua = n.exec_lua

describe('vim.pos', function()
  before_each(clear)
  after_each(clear)

  it('creates a position with or without optional fields', function()
    local pos = exec_lua(function()
      return vim.pos(3, 5)
    end)
    eq(3, pos.row)
    eq(5, pos.col)
    eq(nil, pos.buf)

    local buf = exec_lua(function()
      return vim.api.nvim_create_buf(false, true)
    end)
    pos = exec_lua(function()
      return vim.pos(3, 5, { buf = buf })
    end)
    eq(3, pos.row)
    eq(5, pos.col)
    eq(buf, pos.buf)
  end)

  it('supports comparisons by overloaded mathmatical operators', function()
    eq(
      true,
      exec_lua(function()
        return vim.pos(3, 5) < vim.pos(4, 5)
      end)
    )
    eq(
      true,
      exec_lua(function()
        return vim.pos(3, 5) <= vim.pos(3, 6)
      end)
    )
    eq(
      true,
      exec_lua(function()
        return vim.pos(3, 5) > vim.pos(2, 5)
      end)
    )
    eq(
      true,
      exec_lua(function()
        return vim.pos(3, 5) >= vim.pos(3, 5)
      end)
    )
    eq(
      true,
      exec_lua(function()
        return vim.pos(3, 5) == vim.pos(3, 5)
      end)
    )
    eq(
      true,
      exec_lua(function()
        return vim.pos(3, 5) ~= vim.pos(3, 6)
      end)
    )
  end)
end)
