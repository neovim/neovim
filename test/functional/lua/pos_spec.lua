-- Test suite for vim.pos
local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local eq = t.eq

local clear = n.clear
local exec_lua = n.exec_lua
local insert = n.insert

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

  it('supports conversion between vim.Pos and lsp.Position', function()
    local buf = exec_lua(function()
      return vim.api.nvim_get_current_buf()
    end)
    insert('Neovim 是 Vim 的分支，专注于扩展性和可用性。')
    local lsp_pos = exec_lua(function()
      local pos = vim.pos(0, 36, { buf = buf })
      return pos:to_lsp('utf-16')
    end)
    eq({ line = 0, character = 20 }, lsp_pos)
    local pos = exec_lua(function()
      return vim.pos.lsp(buf, lsp_pos, 'utf-16')
    end)
    eq({
      buf = buf,
      row = 0,
      col = 36,
    }, pos)
  end)
end)
