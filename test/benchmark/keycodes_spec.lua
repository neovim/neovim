local n = require('test.functional.testnvim')()
local clear = n.clear
local api = n.api
local fn = n.fn

local keycodes = require('src.nvim.keycodes')

describe('nvim_replace_termcodes performance', function()
  it('200 calls with a key repeated 5000 times', function()
    clear()
    local stats = {}
    local sum = 0
    local ms = 1 / 1000000

    for _, keycode in ipairs(keycodes.names) do
      local notation = ('<%s>'):format(keycode[2])
      local str = notation:rep(5000)

      local start = vim.uv.hrtime()
      for _ = 1, 200 do
        api.nvim_replace_termcodes(str, false, true, true)
      end
      local elapsed = vim.uv.hrtime() - start

      table.insert(stats, elapsed)
      sum = sum + elapsed
      io.stdout:write(('\n%-20s%14.6f ms'):format(notation, elapsed * ms))
      io.stdout:flush()
    end
    io.stdout:write('\n')

    table.sort(stats)
    print(('%18s'):rep(6):format('avg', 'min', '25%', 'median', '75%', 'max'))
    print(
      (' %14.6f ms'):rep(6):format(
        sum / #stats * ms,
        stats[1] * ms,
        stats[1 + math.floor(#stats * 0.25)] * ms,
        stats[1 + math.floor(#stats * 0.5)] * ms,
        stats[1 + math.floor(#stats * 0.75)] * ms,
        stats[#stats] * ms
      )
    )
  end)
end)

describe('keytrans() performance', function()
  it('200 calls with a key repeated 5000 times', function()
    clear()
    local stats = {}
    local sum = 0
    local ms = 1 / 1000000

    for _, keycode in ipairs(keycodes.names) do
      local notation = ('<%s>'):format(keycode[2])
      local str = api.nvim_replace_termcodes(notation, false, true, true):rep(5000)

      local start = vim.uv.hrtime()
      for _ = 1, 200 do
        fn.keytrans(str)
      end
      local elapsed = vim.uv.hrtime() - start

      table.insert(stats, elapsed)
      sum = sum + elapsed
      io.stdout:write(('\n%-20s%14.6f ms'):format(notation, elapsed * ms))
      io.stdout:flush()
    end
    io.stdout:write('\n')

    table.sort(stats)
    print((' %17s'):rep(6):format('avg', 'min', '25%', 'median', '75%', 'max'))
    print(
      (' %14.6f ms'):rep(6):format(
        sum / #stats * ms,
        stats[1] * ms,
        stats[1 + math.floor(#stats * 0.25)] * ms,
        stats[1 + math.floor(#stats * 0.5)] * ms,
        stats[1 + math.floor(#stats * 0.75)] * ms,
        stats[#stats] * ms
      )
    )
  end)
end)
