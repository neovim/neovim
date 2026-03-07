-- Test suite for vim.pos
local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local eq = t.eq

local clear = n.clear
local exec_lua = n.exec_lua
local insert = n.insert

describe('vim.pos', function()
  before_each(clear)

  it('creates a position with or without optional fields', function()
    local pos = exec_lua(function()
      return vim.pos(3, 5)
    end)
    eq(3, pos[1])
    eq(5, pos[2])
    eq(nil, pos[3])

    local buf = exec_lua(function()
      return vim.api.nvim_create_buf(false, true)
    end)
    pos = exec_lua(function()
      return vim.pos(3, 5, { buf = buf })
    end)
    eq(3, pos[1])
    eq(5, pos[2])
    eq(buf, pos[3])
  end)

  it('comparisons by overloaded operators', function()
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

  it('converts between vim.Pos and lsp.Position', function()
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
      0,
      36,
      buf,
    }, pos)
  end)

  it("converts between vim.Pos and extmark on buffer's last line", function()
    local buf = exec_lua(function()
      return vim.api.nvim_get_current_buf()
    end)
    insert('Some text')
    local extmark_pos = {
      exec_lua(function()
        local pos = vim.pos(1, 0, { buf = buf })
        return pos:to_extmark()
      end),
    }
    eq({ 0, 9 }, extmark_pos)
    local pos = exec_lua(function()
      return vim.pos.extmark(extmark_pos[1], extmark_pos[2], { buf = buf })
    end)
    eq({ 0, 9, buf }, pos)

    local extmark_pos2 = {
      exec_lua(function()
        local pos2 = vim.pos(0, 9, { buf = buf })
        return pos2:to_extmark()
      end),
    }
    eq({ 0, 9 }, extmark_pos2)
    local pos2 = exec_lua(function()
      return vim.pos.extmark(extmark_pos2[1], extmark_pos2[2], { buf = buf })
    end)
    eq({ 0, 9, buf }, pos2)
  end)
end)
