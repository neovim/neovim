local n = require('test.functional.testnvim')()
local t = require('test.testutil')

local describe, it, before_each = t.describe, t.it, t.before_each

--- Times `cmd` on a new 200k-line buffer of pseudo-random words.
--- @param cmd string
local function bench(cmd)
  local samples = n.exec_lua(function(cmd_)
    local words = { 'foo', 'bar', 'baz', 'qux', 'hello', 'world', 'lorem', 'ipsum' }
    local seed = 1
    local lines = {} --- @type string[]
    for i = 1, 200000 do
      local w = {} --- @type string[]
      for j = 1, 12 do
        seed = (seed * 1103515245 + 12345) % 2147483648
        w[j] = words[math.floor(seed / 65536) % #words + 1]
      end
      lines[i] = table.concat(w, ' ')
    end
    local samples = {} --- @type number[]
    for i = 1, 5 do
      vim.cmd.enew()
      vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
      local t0 = vim.uv.hrtime()
      vim.cmd(cmd_)
      samples[i] = vim.uv.hrtime() - t0
      vim.cmd.bwipeout({ bang = true })
    end
    return samples
  end, cmd)
  t.bench_report(samples, { label = cmd })
end

describe(':sort', function()
  before_each(function()
    n.clear()
    n.command('set undolevels=-1')
  end)

  it('200k lines', function()
    bench('sort')
  end)

  it('200k lines, pattern', function()
    bench([[sort /\w\+ /]])
  end)
end)
