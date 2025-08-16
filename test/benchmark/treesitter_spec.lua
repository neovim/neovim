local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local exec_lua = n.exec_lua

describe('treesitter perf', function()
  before_each(function()
    clear()
  end)

  it('can handle large folds', function()
    n.command 'edit ./src/nvim/eval.c'
    exec_lua [[
      local parser = vim.treesitter.get_parser(0, "c", {})
      vim.treesitter.highlighter.new(parser)

      local function keys(k)
        vim.api.nvim_feedkeys(k, 't', true)
      end

      vim.opt.foldmethod = "manual"
      vim.opt.lazyredraw = false

      vim.cmd '1000,7000fold'
      vim.cmd '999'

      local function mk_keys(n)
        local acc = ""
        for _ = 1, n do
          acc = acc .. "j"
        end
        for _ = 1, n do
          acc = acc .. "k"
        end

        return "qq" .. acc .. "q"
      end

      local start = vim.uv.hrtime()
      keys(mk_keys(10))

      for _ = 1, 100 do
        keys "@q"
        vim.cmd'redraw!'
      end

      return vim.uv.hrtime() - start
    ]]
  end)

  local function test_long_line(_pos, _wrap, _line, grid)
    local screen = Screen.new(20, 11)

    local result = exec_lua(function(...)
      local pos, wrap, line = ...

      vim.api.nvim_buf_set_lines(0, 0, 0, false, { line })
      vim.api.nvim_win_set_cursor(0, pos)
      vim.api.nvim_set_option_value('wrap', wrap, { win = 0 })

      vim.treesitter.start(0, 'lua')

      local total = {}
      for _ = 1, 100 do
        local tic = vim.uv.hrtime()
        vim.cmd 'redraw!'
        local toc = vim.uv.hrtime()
        table.insert(total, toc - tic)
      end

      return { total }
    end, _pos, _wrap, _line)

    screen:expect({ grid = grid or '' })

    local total = unpack(result)
    table.sort(total)

    local ms = 1 / 1000000
    local res = string.format(
      'min, 25%%, median, 75%%, max:\n\t%0.2fms,\t%0.2fms,\t%0.2fms,\t%0.2fms,\t%0.2fms',
      total[1] * ms,
      total[1 + math.floor(#total * 0.25)] * ms,
      total[1 + math.floor(#total * 0.5)] * ms,
      total[1 + math.floor(#total * 0.75)] * ms,
      total[#total] * ms
    )
    print('\nTotal ' .. res)
  end

  local long_line = 'local a = { ' .. ('a = 5, '):rep(500) .. '}'
  it('can redraw the beginning of a long line with wrapping', function()
    local grid = [[
      {15:^local} {25:a} {15:=} {16:{} {25:a} {15:=} {26:5}{16:,} {25:a}|
       {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} |
      {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,}|
       {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}|
      {16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} |
      {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=}|
       {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} |
      {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a}|
       {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} |
      {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,}|
                          |
    ]]
    test_long_line({ 1, 0 }, true, long_line, grid)
  end)

  it('can redraw the middle of a long line with wrapping', function()
    local grid = [[
      {1:<<<}{26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} |
      {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,}|
       {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}|
      {16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} |
      {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=}|
       {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} |
      {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a}|
       {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} |
      {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,}|
       {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a}^ {15:=} {26:5}|
                          |
    ]]
    test_long_line({ 1, math.floor(#long_line / 2) }, true, long_line, grid)
  end)

  it('can redraw the end of a long line with wrapping', function()
    local grid = [[
      {1:<<<}{25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=}|
       {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} |
      {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a}|
       {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} |
      {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,}|
       {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}|
      {16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} |
      {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=}|
       {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {25:a} |
      {15:=} {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {16:^}}       |
                          |
    ]]
    test_long_line({ 1, #long_line - 1 }, true, long_line, grid)
  end)

  it('can redraw the beginning of a long line without wrapping', function()
    local grid = [[
      {15:^local} {25:a} {15:=} {16:{} {25:a} {15:=} {26:5}{16:,} {25:a}|
                          |
      {1:~                   }|*8
                          |
    ]]
    test_long_line({ 1, 0 }, false, long_line, grid)
  end)

  it('can redraw the middle of a long line without wrapping', function()
    local grid = [[
      {16:,} {25:a} {15:=} {26:5}{16:,} {25:a}^ {15:=} {26:5}{16:,} {25:a} {15:=} |
                          |
      {1:~                   }|*8
                          |
    ]]
    test_long_line({ 1, math.floor(#long_line / 2) }, false, long_line, grid)
  end)

  it('can redraw the end of a long line without wrapping', function()
    local grid = [[
      {26:5}{16:,} {25:a} {15:=} {26:5}{16:,} {16:^}}         |
                          |
      {1:~                   }|*8
                          |
    ]]
    test_long_line({ 1, #long_line - 1 }, false, long_line, grid)
  end)

  local long_line_mb = 'local a = { ' .. ('À = 5, '):rep(500) .. '}'
  it('can redraw the middle of a long line with multibyte characters', function()
    local grid = [[
      {1:<<<}{26:5}{16:,} {25:À} {15:=} {26:5}{16:,} {25:À} {15:=} {26:5}{16:,} |
      {25:À} {15:=} {26:5}{16:,} {25:À} {15:=} {26:5}{16:,} {25:À} {15:=} {26:5}{16:,}|
       {25:À} {15:=} {26:5}{16:,} {25:À} {15:=} {26:5}{16:,} {25:À} {15:=} {26:5}|
      {16:,} {25:À} {15:=} {26:5}{16:,} {25:À} {15:=} {26:5}{16:,} {25:À} {15:=} |
      {26:5}{16:,} {25:À} {15:=} {26:5}{16:,} {25:À} {15:=} {26:5}{16:,} {25:À} {15:=}|
       {26:5}{16:,} {25:À} {15:=} {26:5}{16:,} {25:À} {15:=} {26:5}{16:,} {25:À} |
      {15:=} {26:5}{16:,} {25:À} {15:=} {26:5}{16:,} {25:À} {15:=} {26:5}{16:,} {25:À}|
       {15:=} {26:5}{16:,} {25:À} {15:=} {26:5}{16:,} {25:À} {15:=} {26:5}{16:,} |
      {25:À} {15:=} {26:5}{16:,} {25:À} {15:=} {26:5}{16:,} {25:À} {15:=} {26:5}{16:,}|
       {25:À} {15:=} {26:5}{16:,} {25:À} {15:=} {26:5}{16:,} {25:À}^ {15:=} {26:5}|
                          |
    ]]
    test_long_line({ 1, math.floor(#long_line_mb / 2) }, true, long_line_mb, grid)
  end)
end)
