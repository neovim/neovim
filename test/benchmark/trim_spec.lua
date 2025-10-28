describe('vim.trim()', function()
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

  local strings = {
    ['10000 whitespace characters'] = string.rep(' ', 10000),
    ['10000 whitespace characters and one non-whitespace at the end'] = string.rep(' ', 10000)
      .. '0',
    ['10000 whitespace characters and one non-whitespace at the start'] = '0'
      .. string.rep(' ', 10000),
    ['10000 non-whitespace characters'] = string.rep('0', 10000),
    ['10000 whitespace and one non-whitespace in the middle'] = string.rep(' ', 5000)
      .. 'a'
      .. string.rep(' ', 5000),
    ['10000 whitespace characters surrounded by non-whitespace'] = '0'
      .. string.rep(' ', 10000)
      .. '0',
    ['10000 non-whitespace characters surrounded by whitespace'] = ' '
      .. string.rep('0', 10000)
      .. ' ',
  }

  --- @type string[]
  local string_names = vim.tbl_keys(strings)
  table.sort(string_names)

  for _, name in ipairs(string_names) do
    it(name, function()
      measure(vim.trim, strings[name], 100)
    end)
  end
end)
