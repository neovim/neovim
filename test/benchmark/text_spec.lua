describe('vim.text', function()
  --- @param t number[]
  local function mean(t)
    assert(#t > 0)
    local sum = 0
    for _, v in ipairs(t) do
      sum = sum + v
    end
    return sum / #t
  end

  --- @param t number[]
  local function median(t)
    local len = #t
    if len % 2 == 0 then
      return t[len / 2]
    end
    return t[(len + 1) / 2]
  end

  --- @param f fun(t: number[]): table<number, number|string|table>
  local function measure(f, input, N)
    local stats = {} ---@type number[]
    for _ = 1, N do
      local tic = vim.uv.hrtime()
      f(input)
      local toc = vim.uv.hrtime()
      stats[#stats + 1] = (toc - tic) / 1000000
    end
    table.sort(stats)
    print(
      string.format(
        '\nN: %d, Min: %0.6f ms, Max: %0.6f ms, Median: %0.6f ms, Mean: %0.6f ms',
        N,
        math.min(unpack(stats)),
        math.max(unpack(stats)),
        median(stats),
        mean(stats)
      )
    )
  end

  local input, output = string.rep('😂', 2 ^ 16), string.rep('F09F9882', 2 ^ 16)

  it('hexencode', function()
    measure(vim.text.hexencode, input, 100)
  end)

  it('hexdecode', function()
    measure(vim.text.hexdecode, output, 100)
  end)
end)
