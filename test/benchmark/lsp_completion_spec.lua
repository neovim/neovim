local n = require('test.functional.testnvim')()
local t = require('test.testutil')

local describe, it, before_each, eq = t.describe, t.it, t.before_each, t.eq
local exec_lua = n.exec_lua
local bench = n.bench

describe('vim.lsp.completion perf', function()
  local convert =
    [[vim.lsp.completion._convert_results('ab', 0, 2, 1, 0, nil, _G.result, 'utf-16')]]

  local function workload()
    return exec_lua('local m = ' .. convert .. ' return { #m, m[1]._fuzzy_score ~= nil }')
  end

  before_each(function()
    n.clear()
    exec_lua(function()
      local items = {} --- @type lsp.CompletionItem[]
      for i = 1, 5000 do
        local label = (i % 2 == 0 and 'ab_%05d' or 'xy_%05d'):format(i)
        local item = {
          label = label,
          sortText = ('%05d'):format(5000 - i),
          textEdit = {
            newText = label,
            range = { start = { line = 0, character = 0 }, ['end'] = { line = 0, character = 2 } },
          },
        }
        if i % 3 == 0 then
          item.detail = 'fn(a: i32) -> Result<Vec<u8>, Error>'
          item.documentation =
            { kind = 'markdown', value = ('Docs for item %d. '):format(i):rep(12) }
        end
        items[i] = item
      end
      _G.result = { isIncomplete = false, items = items }
    end)
  end)

  it('converts 5000 items', function()
    eq({ 2500, false }, workload())
    bench(convert, { n = 20, warmup = 3, label = 'convert 5000 items' })
  end)

  it('converts 5000 items with "fuzzy"', function()
    exec_lua(function()
      vim.o.completeopt = 'menu,popup,fuzzy'
    end)
    eq({ 2500, true }, workload())
    bench(convert, { n = 20, warmup = 3, label = 'convert 5000 items, "fuzzy"' })
  end)
end)
