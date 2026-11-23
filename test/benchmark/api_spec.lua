local n = require('test.functional.testnvim')()
local t = require('test.testutil')

local describe, it = t.describe, t.it

describe('nvim_buf_set_lines() replacement', function()
  -- About 1 MB each.
  local shapes = {
    { name = '12500 lines of 80 bytes', count = 12500, width = 79 },
    { name = '100000 lines of 10 bytes', count = 100000, width = 9 },
  }
  local cases = {
    { name = 'String', body = [[vim.api.nvim_buf_set_lines(0, 0, -1, true, text)]] },
    {
      name = 'vim.split(String)',
      body = [[vim.api.nvim_buf_set_lines(0, 0, -1, true, vim.split(text, '\n', { plain = true }))]],
    },
    { name = 'Array (prebuilt)', body = [[vim.api.nvim_buf_set_lines(0, 0, -1, true, lines)]] },
  }

  for _, shape in ipairs(shapes) do
    describe(shape.name, function()
      t.before_each(function()
        n.clear()
        n.exec_lua(function()
          vim.o.undolevels = -1 -- Exclude undo.
          _G.text = ('%s\n'):format(('x'):rep(shape.width)):rep(shape.count)
          _G.lines = vim.split(_G.text, '\n', { plain = true })
        end)
      end)

      for _, case in ipairs(cases) do
        it(case.name, function()
          n.bench(
            case.body,
            { n = 50, warmup = 5, label = ('%s: %s'):format(shape.name, case.name) }
          )
        end)
      end
    end)
  end
end)
