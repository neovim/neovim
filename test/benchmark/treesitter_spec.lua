local n = require('test.functional.testnvim')()

local clear = n.clear
local exec_lua = n.exec_lua

describe('treesitter perf', function()
  setup(function()
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
end)
