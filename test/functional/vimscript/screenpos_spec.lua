local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local describe, it, before_each = t.describe, t.it, t.before_each
local clear, eq, api = n.clear, t.eq, n.api
local command, fn = n.command, n.fn
local exec_lua, feed = n.exec_lua, n.feed

before_each(clear)

describe('screenpos() function', function()
  it('clamps a large column to the end of the line', function()
    Screen.new(20, 4)
    api.nvim_buf_set_lines(0, 0, -1, true, { 'abc' })
    eq({ row = 1, col = 4, endcol = 4, curscol = 4 }, fn.screenpos(0, 1, 0x7fffffff))
  end)

  it('works in floating window with border', function()
    local opts = {
      relative = 'editor',
      height = 8,
      width = 12,
      row = 6,
      col = 8,
      anchor = 'NW',
      style = 'minimal',
      border = 'none',
      focusable = 1,
    }
    local float = api.nvim_open_win(api.nvim_create_buf(false, true), false, opts)
    command('redraw')
    eq({ row = 7, col = 9, endcol = 9, curscol = 9 }, fn.screenpos(float, 1, 1))

    -- only left border
    opts.border = { '', '', '', '', '', '', '', '|' }
    api.nvim_win_set_config(float, opts)
    command('redraw')
    eq({ row = 7, col = 10, endcol = 10, curscol = 10 }, fn.screenpos(float, 1, 1))

    -- only top border
    opts.border = { '', '_', '', '', '', '', '', '' }
    api.nvim_win_set_config(float, opts)
    command('redraw')
    eq({ row = 8, col = 9, endcol = 9, curscol = 9 }, fn.screenpos(float, 1, 1))

    -- both left and top border
    opts.border = 'single'
    api.nvim_win_set_config(float, opts)
    command('redraw')
    eq({ row = 8, col = 10, endcol = 10, curscol = 10 }, fn.screenpos(float, 1, 1))
  end)

  it('works for folded line with virt_lines attached to line above', function()
    Screen.new(20, 8)
    api.nvim_buf_set_lines(0, 0, -1, true, { 'aaa', ('b'):rep(120), 'ccc', 'ddd' })
    local ns = api.nvim_create_namespace('')
    api.nvim_buf_set_extmark(
      0,
      ns,
      0,
      0,
      { virt_lines = { { { 'abb' } }, { { 'acc' } }, { { 'add' } } } }
    )
    api.nvim_buf_set_extmark(0, ns, 1, 2, { end_col = 10, conceal = '' })
    command('set conceallevel=2 concealcursor=nvic')
    command('2,3fold')
    api.nvim_win_set_cursor(0, { 2, 78 })
    fn.winrestview({ topline = 1 })
    command('redraw')
    eq(1, fn.wincol())
    eq({ row = 5, col = 1, endcol = 1, curscol = 1 }, fn.screenpos(0, 2, 1))
    eq({ row = 5, col = 1, endcol = 1, curscol = 1 }, fn.screenpos(0, 3, 1))
    eq({ row = 6, col = 1, endcol = 1, curscol = 1 }, fn.screenpos(0, 4, 1))
    api.nvim_win_set_cursor(0, { 1, 0 })

    feed('<C-E>')
    eq({ row = 4, col = 1, endcol = 1, curscol = 1 }, fn.screenpos(0, 2, 1))
    eq({ row = 4, col = 1, endcol = 1, curscol = 1 }, fn.screenpos(0, 3, 1))
    eq({ row = 5, col = 1, endcol = 1, curscol = 1 }, fn.screenpos(0, 4, 1))

    feed('<C-E>')
    eq({ row = 3, col = 1, endcol = 1, curscol = 1 }, fn.screenpos(0, 2, 1))
    eq({ row = 3, col = 1, endcol = 1, curscol = 1 }, fn.screenpos(0, 3, 1))
    eq({ row = 4, col = 1, endcol = 1, curscol = 1 }, fn.screenpos(0, 4, 1))

    feed('<C-E>')
    eq({ row = 2, col = 1, endcol = 1, curscol = 1 }, fn.screenpos(0, 2, 1))
    eq({ row = 2, col = 1, endcol = 1, curscol = 1 }, fn.screenpos(0, 3, 1))
    eq({ row = 3, col = 1, endcol = 1, curscol = 1 }, fn.screenpos(0, 4, 1))

    feed('<C-E>')
    eq({ row = 1, col = 1, endcol = 1, curscol = 1 }, fn.screenpos(0, 2, 1))
    eq({ row = 1, col = 1, endcol = 1, curscol = 1 }, fn.screenpos(0, 3, 1))
    eq({ row = 2, col = 1, endcol = 1, curscol = 1 }, fn.screenpos(0, 4, 1))
  end)

  it("conceal-aware wrap discounts only what 'smoothscroll' still shows (#14409)", function()
    Screen.new(20, 8)
    command('set wrap smoothscroll scrolloff=0 conceallevel=2 concealcursor=nvic')

    local plain, concealed = exec_lua(function()
      local ns = vim.api.nvim_create_namespace('conceal_wrap_smoothscroll')
      local function positions(prefix, hidden)
        vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
        vim.api.nvim_buf_set_lines(0, 0, -1, true, { ('a'):rep(prefix) .. ('b'):rep(200) })
        if hidden then
          vim.api.nvim_buf_set_extmark(0, ns, 0, 0, { end_col = prefix, conceal = '' })
        end
        vim.api.nvim_win_set_cursor(0, { 1, prefix + 124 })
        vim.fn.winrestview({ topline = 1, lnum = 1, col = prefix + 124, skipcol = 120 })
        vim.cmd('redraw')

        local result = {}
        for _, offset in ipairs({ 0, 119, 120, 121 }) do
          local pos = vim.fn.screenpos(0, 1, prefix + offset + 1)
          result[#result + 1] = { pos.row, pos.col, pos.curscol }
        end
        return { skipcol = vim.fn.winsaveview().skipcol, positions = result }
      end
      return positions(0, false), positions(200, true)
    end)

    eq({
      skipcol = 120,
      positions = { { 0, 0, 0 }, { 0, 0, 0 }, { 1, 1, 1 }, { 1, 2, 2 } },
    }, plain)
    eq(plain, concealed)
  end)
end)
