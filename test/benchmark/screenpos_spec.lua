local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local api = n.api

local function rand_utf8(count, seed)
  math.randomseed(seed)
  local symbols = { 'i', 'À', 'Ⱡ', '𐀀' }
  local s = ''
  for _ = 1, count do
    s = s .. symbols[math.random(1, #symbols)]
  end
  return s
end

local width, height = 100, 50

local benchmark_chars = {
  {
    name = 'ascii',
    line = function(count, _)
      return ('i'):rep(count)
    end,
  },
  {
    name = '2 byte utf-8',
    line = function(count, _)
      return ('À'):rep(count)
    end,
  },
  {
    name = '3 byte utf-8',
    line = function(count, _)
      return ('Ⱡ'):rep(count)
    end,
  },
  {
    name = 'random 1-4 byte utf-8',
    line = function(count, i)
      return rand_utf8(count, 123456 + i)
    end,
  },
}

local benchmark_lines = {
  {
    name = 'long line',
    lines = function(line)
      return { line(width * height - 1, 1) }
    end,
  },
  {
    name = 'multiple lines',
    lines = function(line)
      local lines = {}
      for i = 1, height - 1 do
        table.insert(lines, line(width, i))
      end
      table.insert(lines, line(width - 1, height))
      return lines
    end,
  },
  {
    name = 'multiple wrapped lines',
    lines = function(line)
      local lines = {}
      local count = math.floor(height / 2)
      for i = 1, count - 1 do
        table.insert(lines, line(width * 2, i))
      end
      table.insert(lines, line(width * 2 - 1, count))
      return lines
    end,
  },
}

local N = 10000

local function benchmark(lines, expected_value)
  local lnum = #lines

  local results = t.exec_lua(
    [==[
    local N, lnum = ...

    local values = {}
    local stats = {} -- time in ns
    for i = 1, N do
      local tic = vim.uv.hrtime()
      local result = vim.fn.screenpos(0, lnum, 999999)
      local toc = vim.uv.hrtime()
      table.insert(values, result)
      table.insert(stats, toc - tic)
    end

    return { values, stats }
  ]==],
    N,
    lnum
  )

  for _, value in ipairs(results[1]) do
    t.eq(expected_value, value)
  end
  local stats = results[2]
  table.sort(stats)

  local us = 1 / 1000
  print(
    string.format(
      'min, 25%%, median, 75%%, max:\n\t%0.2fus,\t%0.2fus,\t%0.2fus,\t%0.2fus,\t%0.2fus',
      stats[1] * us,
      stats[1 + math.floor(#stats * 0.25)] * us,
      stats[1 + math.floor(#stats * 0.5)] * us,
      stats[1 + math.floor(#stats * 0.75)] * us,
      stats[#stats] * us
    )
  )
end

local function benchmarks(benchmark_results)
  describe('screenpos() perf', function()
    before_each(n.clear)

    -- no breakindent
    for li, lines_type in ipairs(benchmark_lines) do
      for ci, chars_type in ipairs(benchmark_chars) do
        local name = 'for ' .. lines_type.name .. ', ' .. chars_type.name .. ', nobreakindent'

        local lines = lines_type.lines(chars_type.line)
        local result = benchmark_results[li][ci]

        it(name, function()
          local screen = Screen.new(width, height + 1)
          screen:attach()
          api.nvim_buf_set_lines(0, 0, 1, false, lines)
          -- for smaller screen expect (last line always different, first line same as others)
          n.feed('G$')
          screen:expect(result.screen)
          benchmark(lines, result.value)
        end)
      end
    end

    -- breakindent
    for li, lines_type in ipairs(benchmark_lines) do
      for ci, chars_type in ipairs(benchmark_chars) do
        local name = 'for ' .. lines_type.name .. ', ' .. chars_type.name .. ', breakindent'

        local lines = lines_type.lines(chars_type.line)
        local result = benchmark_results[li][ci]

        it(name, function()
          local screen = Screen.new(width, height + 1)
          screen:attach()
          api.nvim_buf_set_lines(0, 0, 1, false, lines)
          n.command('set breakindent')
          -- for smaller screen expect (last line always different, first line same as others)
          n.feed('G$')
          screen:expect(result.screen)
          benchmark(lines, result.value)
        end)
      end
    end
  end)
end

local ascii_results = {
  screen = [=[
  iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii|*49
  iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii^i |
                                                                                                      |
  ]=],
  value = { col = 100, curscol = 100, endcol = 100, row = 50 },
}
local two_byte_results = {
  screen = [=[
  ÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀ|*49
  ÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀÀ^À |
                                                                                                      |
  ]=],
  value = { col = 100, curscol = 100, endcol = 100, row = 50 },
}
local three_byte_results = {
  screen = [=[
  ⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠ|*49
  ⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠⱠ^Ⱡ |
                                                                                                      |
  ]=],
  value = { col = 100, curscol = 100, endcol = 100, row = 50 },
}

benchmarks({
  {
    ascii_results,
    two_byte_results,
    three_byte_results,
    { -- random
      screen = [=[
  Ⱡ𐀀ii𐀀ⱠÀ𐀀i𐀀𐀀iÀÀÀiÀ𐀀Ⱡ𐀀ⱠiiⱠ𐀀iii𐀀ÀⱠÀⱠⱠÀiiÀⱠÀiⱠi𐀀ÀÀ𐀀𐀀Ⱡ𐀀𐀀Ⱡ𐀀iÀⱠ𐀀i𐀀ÀÀⱠiiÀ𐀀Ⱡ𐀀À𐀀ii𐀀ÀÀ𐀀ÀⱠⱠ𐀀𐀀𐀀𐀀ii𐀀ⱠⱠiⱠⱠ𐀀ⱠÀ𐀀ÀÀiiⱠ|
  𐀀𐀀ÀⱠÀ𐀀𐀀iⱠÀ𐀀𐀀i𐀀𐀀𐀀𐀀ⱠⱠⱠiiiiÀÀ𐀀ⱠÀⱠÀi𐀀i𐀀ⱠⱠÀiÀⱠi𐀀𐀀À𐀀iÀ𐀀ÀÀÀ𐀀𐀀iÀⱠ𐀀𐀀Ⱡ𐀀𐀀ÀiⱠiiⱠⱠÀÀÀÀi𐀀ÀÀⱠ𐀀Àiii𐀀iⱠⱠⱠi𐀀ⱠÀi𐀀iⱠ𐀀ⱠiⱠ|
  ⱠⱠⱠÀi𐀀ÀiⱠÀiⱠiⱠ𐀀ÀiiiÀiiÀÀⱠ𐀀À𐀀ÀⱠÀÀÀⱠ𐀀iⱠⱠ𐀀iⱠÀ𐀀À𐀀ⱠiÀÀÀÀiiÀiÀiÀⱠiÀi𐀀iÀÀⱠ𐀀𐀀ⱠÀ𐀀iⱠ𐀀i𐀀i𐀀ÀⱠi𐀀iⱠÀÀiiⱠ𐀀𐀀ⱠiÀiÀiiÀ|
  iⱠ𐀀iiⱠÀⱠ𐀀iÀÀÀⱠÀiÀ𐀀𐀀𐀀ÀⱠiⱠiÀiⱠiⱠ𐀀𐀀ⱠⱠi𐀀ⱠⱠ𐀀𐀀Ⱡ𐀀ÀiiⱠÀⱠⱠ𐀀iÀiÀÀ𐀀𐀀𐀀ⱠⱠ𐀀iii𐀀À𐀀Ⱡ𐀀iⱠii𐀀i𐀀i𐀀ÀiÀi𐀀Ⱡ𐀀𐀀i𐀀iÀÀiⱠ𐀀Ⱡ𐀀ÀÀÀÀ|
  𐀀ÀⱠiÀⱠÀÀÀⱠ𐀀À𐀀𐀀𐀀i𐀀Ài𐀀𐀀iⱠ𐀀𐀀ÀⱠ𐀀𐀀À𐀀𐀀ⱠÀÀⱠⱠⱠiⱠÀÀii𐀀Ⱡii𐀀Ⱡi𐀀Ài𐀀Ⱡ𐀀𐀀𐀀𐀀iÀ𐀀ⱠÀiÀ𐀀ⱠⱠi𐀀i𐀀ⱠⱠÀⱠ𐀀ⱠÀⱠ𐀀ÀⱠiiⱠ𐀀𐀀Ⱡ𐀀Ⱡ𐀀𐀀À𐀀𐀀Ài|
  iÀÀiÀÀiⱠÀiiⱠiÀiiiÀⱠÀ𐀀Ài𐀀iiÀÀÀiⱠⱠiiⱠ𐀀iÀ𐀀𐀀𐀀ⱠÀÀ𐀀iiⱠ𐀀Ⱡ𐀀ⱠÀⱠ𐀀Ài𐀀i𐀀ÀiÀⱠⱠ𐀀ÀⱠiiⱠÀ𐀀𐀀Ⱡii𐀀𐀀i𐀀𐀀ÀÀiÀ𐀀i𐀀𐀀i𐀀ÀiiiⱠÀÀÀ|
  ÀÀⱠⱠÀⱠⱠÀiiiÀⱠÀⱠⱠi𐀀ⱠÀ𐀀iⱠÀ𐀀ⱠÀiiÀÀÀÀⱠ𐀀𐀀À𐀀iiÀ𐀀𐀀iⱠⱠ𐀀iiⱠⱠ𐀀ÀÀÀ𐀀Ⱡ𐀀À𐀀ÀⱠi𐀀ⱠÀⱠÀⱠⱠiÀ𐀀iÀÀⱠ𐀀ⱠⱠ𐀀𐀀iⱠⱠⱠ𐀀𐀀À𐀀iÀÀi𐀀iⱠⱠ𐀀𐀀|
  ÀÀiiⱠÀ𐀀Ài𐀀iiÀ𐀀iÀⱠÀÀi𐀀𐀀ⱠⱠ𐀀iiⱠⱠiÀ𐀀iⱠÀÀiⱠ𐀀ÀÀiiⱠⱠiÀÀ𐀀À𐀀iⱠÀÀⱠiⱠ𐀀iⱠ𐀀ÀiiⱠÀÀⱠÀÀiÀ𐀀𐀀ⱠⱠÀⱠÀÀⱠ𐀀À𐀀ⱠⱠi𐀀À𐀀𐀀ⱠⱠ𐀀iⱠi𐀀Ⱡ|
  ÀÀⱠ𐀀𐀀ÀⱠⱠⱠÀⱠiⱠⱠⱠÀiiiⱠiiiÀi𐀀𐀀iⱠⱠiiÀiⱠⱠⱠÀÀiii𐀀ÀiⱠÀi𐀀i𐀀𐀀ÀiÀiÀÀiÀ𐀀iÀÀÀiÀⱠⱠÀiÀ𐀀À𐀀iⱠÀⱠ𐀀ii𐀀𐀀iⱠiÀiⱠ𐀀Ⱡ𐀀Ⱡ𐀀𐀀ⱠiÀⱠ|
  ÀⱠii𐀀i𐀀iÀÀÀÀÀ𐀀ÀiÀ𐀀𐀀ÀⱠiiiiiÀⱠ𐀀ÀÀÀⱠi𐀀iⱠiⱠiÀⱠⱠ𐀀𐀀ii𐀀𐀀iÀÀÀⱠiiÀ𐀀iÀiÀ𐀀Ⱡ𐀀Ⱡ𐀀i𐀀iÀⱠiÀ𐀀i𐀀ⱠiⱠÀ𐀀iⱠÀⱠiⱠiÀÀÀÀ𐀀Ⱡ𐀀iⱠⱠÀ|
  𐀀Ⱡ𐀀ⱠÀ𐀀iⱠiÀi𐀀i𐀀𐀀𐀀ⱠÀⱠiÀⱠⱠ𐀀ÀiÀiⱠi𐀀ÀⱠi𐀀𐀀ÀÀi𐀀À𐀀ÀiiⱠ𐀀iⱠÀÀÀiii𐀀ⱠiⱠ𐀀𐀀𐀀ⱠⱠiⱠ𐀀𐀀iiⱠiiiii𐀀𐀀𐀀𐀀𐀀ÀÀÀÀi𐀀𐀀ⱠⱠ𐀀iÀ𐀀ÀiiÀii|
  Ⱡ𐀀𐀀iⱠi𐀀Ⱡ𐀀ⱠⱠiÀÀⱠi𐀀ÀiⱠⱠⱠ𐀀ÀⱠiⱠⱠiⱠⱠÀ𐀀ⱠiiiÀ𐀀𐀀𐀀ÀÀiⱠi𐀀ⱠÀ𐀀ÀⱠÀi𐀀ⱠiÀⱠiiⱠⱠÀⱠiÀÀⱠÀÀÀÀ𐀀iÀⱠⱠiⱠⱠ𐀀ÀÀÀⱠiÀÀiÀⱠ𐀀iÀⱠiiⱠ𐀀|
  iÀⱠi𐀀ÀⱠÀÀÀiÀÀⱠ𐀀À𐀀𐀀𐀀ⱠiiiⱠiiⱠ𐀀À𐀀iii𐀀À𐀀ⱠⱠi𐀀iiⱠÀ𐀀𐀀i𐀀ⱠÀ𐀀𐀀i𐀀ÀiⱠÀÀiÀÀi𐀀𐀀Ⱡ𐀀À𐀀i𐀀iÀⱠⱠⱠ𐀀ÀÀÀⱠÀÀⱠⱠⱠⱠⱠi𐀀𐀀iiⱠÀi𐀀𐀀ⱠⱠ|
  iiⱠⱠⱠ𐀀ÀⱠ𐀀Àiii𐀀ÀÀii𐀀À𐀀iiⱠÀⱠiiⱠ𐀀Ⱡ𐀀ÀⱠ𐀀iÀiⱠiiÀÀiÀÀiⱠiⱠⱠiⱠ𐀀Ⱡi𐀀𐀀ÀÀÀÀiⱠii𐀀ⱠÀ𐀀Ⱡ𐀀i𐀀ⱠiⱠⱠ𐀀i𐀀ⱠiⱠⱠ𐀀ÀiⱠ𐀀iÀi𐀀𐀀ÀÀ𐀀𐀀i|
  iÀÀi𐀀ÀÀÀ𐀀ÀⱠ𐀀ÀÀÀ𐀀𐀀𐀀iiⱠÀÀⱠ𐀀ⱠÀ𐀀iiiÀÀiiⱠ𐀀𐀀ⱠiiⱠiÀiⱠⱠÀ𐀀ⱠiⱠÀ𐀀i𐀀𐀀𐀀ⱠÀ𐀀Ⱡ𐀀ÀÀÀⱠⱠ𐀀𐀀À𐀀iiⱠⱠⱠⱠⱠÀ𐀀𐀀iⱠⱠiiÀiⱠÀiÀⱠiÀ𐀀À𐀀i|
  ÀⱠⱠ𐀀ÀⱠi𐀀i𐀀ⱠÀÀÀiiiⱠ𐀀ⱠÀⱠÀÀⱠ𐀀ÀÀiÀiÀÀⱠÀⱠiⱠiÀ𐀀iⱠÀ𐀀𐀀𐀀ÀⱠⱠ𐀀ⱠⱠ𐀀ÀⱠⱠⱠii𐀀ÀÀÀÀiÀi𐀀ⱠⱠÀiⱠiⱠÀⱠ𐀀ÀiⱠⱠiÀⱠi𐀀𐀀𐀀ÀÀiiÀÀ𐀀𐀀ÀⱠ|
  À𐀀ÀÀÀÀ𐀀ÀÀ𐀀i𐀀ⱠÀⱠiⱠÀÀ𐀀ⱠiÀÀiⱠÀⱠⱠÀ𐀀iÀ𐀀i𐀀𐀀ⱠÀÀÀⱠⱠiÀiiiiⱠⱠi𐀀ÀⱠi𐀀i𐀀i𐀀𐀀𐀀ⱠÀⱠiiiÀi𐀀ÀⱠi𐀀iiÀÀⱠÀÀⱠiiÀ𐀀À𐀀ÀÀ𐀀ⱠÀⱠÀ𐀀iⱠ|
  Ⱡ𐀀ÀiⱠ𐀀iiÀ𐀀À𐀀𐀀À𐀀ÀÀiiiiiiⱠⱠiiÀi𐀀iÀ𐀀ÀÀiⱠ𐀀ÀⱠÀÀÀiÀⱠⱠ𐀀À𐀀𐀀iÀ𐀀𐀀ii𐀀ⱠÀ𐀀ii𐀀𐀀iⱠÀ𐀀ÀÀÀiÀii𐀀iⱠ𐀀ⱠⱠ𐀀ÀⱠiiiⱠⱠⱠi𐀀ÀÀiÀ𐀀𐀀À|
  ⱠiÀ𐀀ⱠÀ𐀀iÀⱠi𐀀ÀiiiÀÀ𐀀ÀⱠ𐀀ⱠⱠⱠÀⱠ𐀀ⱠÀiiÀi𐀀i𐀀𐀀iⱠÀⱠiⱠiiÀÀ𐀀𐀀𐀀Ài𐀀𐀀iiⱠiⱠÀⱠ𐀀iiⱠÀi𐀀ⱠⱠⱠi𐀀ÀÀiÀⱠ𐀀𐀀ÀiⱠÀiiÀÀⱠ𐀀ⱠiiÀⱠⱠÀiÀ|
  i𐀀𐀀Ài𐀀𐀀ⱠÀiÀÀⱠⱠi𐀀𐀀ÀÀⱠÀÀⱠⱠⱠⱠ𐀀ÀiⱠiiⱠⱠÀiiiⱠⱠÀ𐀀Ⱡii𐀀i𐀀ⱠÀ𐀀ÀÀⱠⱠiÀiÀÀiⱠÀiiiiÀⱠiiÀⱠⱠⱠÀÀi𐀀À𐀀ⱠⱠ𐀀Ⱡi𐀀ⱠⱠ𐀀𐀀𐀀iⱠÀÀⱠ𐀀ⱠⱠ|
  iÀÀⱠⱠⱠiiÀii𐀀𐀀ⱠÀiii𐀀ⱠÀ𐀀ⱠiiÀ𐀀iⱠ𐀀ÀⱠ𐀀Ⱡ𐀀𐀀Ⱡi𐀀ÀiⱠÀⱠ𐀀ÀÀi𐀀ⱠiÀÀÀÀⱠÀⱠiⱠiⱠⱠ𐀀𐀀ÀⱠÀⱠ𐀀𐀀ÀÀ𐀀ⱠⱠ𐀀𐀀i𐀀Ⱡii𐀀iii𐀀Ⱡi𐀀Ⱡ𐀀Ⱡi𐀀𐀀ÀⱠi|
  À𐀀𐀀ÀⱠÀiiiÀiiÀⱠi𐀀iiiⱠiiⱠÀÀ𐀀ⱠÀ𐀀ⱠⱠⱠ𐀀i𐀀ÀÀiⱠiiiⱠiiÀÀiⱠ𐀀À𐀀i𐀀Ⱡ𐀀ⱠÀiⱠⱠ𐀀ÀⱠⱠ𐀀𐀀ÀiⱠÀÀⱠiiⱠi𐀀i𐀀ⱠÀÀiⱠ𐀀Ⱡ𐀀iⱠⱠ𐀀ÀÀÀiÀÀii|
  ⱠÀ𐀀𐀀ⱠiⱠÀ𐀀ÀÀÀⱠⱠÀⱠ𐀀ÀiⱠii𐀀𐀀ÀⱠ𐀀iÀÀiiÀiÀÀ𐀀iⱠÀiÀ𐀀𐀀À𐀀Ⱡ𐀀𐀀iiⱠⱠ𐀀ⱠÀⱠÀiÀiÀ𐀀iⱠⱠiÀi𐀀Ⱡ𐀀iiiÀⱠ𐀀ÀⱠiÀiiiⱠiiÀⱠÀiⱠiÀÀiⱠÀi|
  𐀀𐀀ÀÀi𐀀À𐀀𐀀ÀⱠⱠⱠ𐀀À𐀀𐀀À𐀀ÀiⱠⱠ𐀀𐀀ⱠÀiⱠiⱠÀ𐀀ÀiⱠiiii𐀀iⱠiⱠÀ𐀀ÀⱠ𐀀𐀀iÀⱠiÀi𐀀𐀀ⱠÀiⱠiÀⱠⱠ𐀀iⱠ𐀀ÀⱠÀii𐀀ⱠÀⱠii𐀀Ⱡ𐀀ÀÀi𐀀ÀÀiÀiÀⱠ𐀀ÀⱠⱠ|
  𐀀iiii𐀀iⱠÀÀⱠiÀⱠ𐀀ⱠiÀiⱠi𐀀iⱠⱠⱠÀⱠⱠÀⱠ𐀀iÀⱠⱠii𐀀iii𐀀À𐀀ⱠⱠⱠÀiÀÀ𐀀iiiiⱠⱠⱠi𐀀𐀀iiⱠ𐀀ⱠiⱠ𐀀i𐀀𐀀ÀÀⱠⱠ𐀀iⱠiⱠÀÀÀⱠⱠÀ𐀀iÀⱠⱠⱠⱠÀ𐀀iÀ|
  ÀÀÀ𐀀ÀÀⱠiⱠÀiiÀÀ𐀀Ⱡ𐀀Àii𐀀ⱠⱠ𐀀iÀÀ𐀀𐀀Ⱡ𐀀iⱠ𐀀iⱠÀⱠⱠ𐀀ÀÀ𐀀𐀀À𐀀ÀⱠiⱠÀiÀ𐀀iÀi𐀀ⱠiⱠ𐀀i𐀀iiⱠⱠiⱠÀÀ𐀀Ⱡ𐀀ⱠⱠ𐀀𐀀𐀀ⱠⱠiⱠⱠ𐀀ⱠⱠⱠ𐀀ÀiⱠⱠi𐀀iÀÀÀ|
  ÀÀⱠiiÀÀÀⱠÀ𐀀𐀀iÀÀÀiÀi𐀀iⱠiⱠ𐀀iÀÀÀ𐀀𐀀𐀀iÀiÀÀiÀÀi𐀀i𐀀𐀀ⱠÀ𐀀ii𐀀𐀀Ⱡ𐀀À𐀀iÀÀⱠ𐀀iÀÀÀⱠÀÀ𐀀𐀀iⱠ𐀀ⱠiÀⱠi𐀀𐀀𐀀iⱠ𐀀ⱠⱠⱠi𐀀𐀀ÀÀÀ𐀀ÀⱠÀiii|
  iiⱠi𐀀ÀÀiⱠ𐀀𐀀ⱠⱠÀ𐀀𐀀iÀⱠiⱠÀⱠÀiÀiⱠÀ𐀀𐀀ⱠiÀⱠⱠⱠⱠ𐀀iiⱠÀÀ𐀀ÀiÀ𐀀Ⱡ𐀀ÀiⱠⱠ𐀀À𐀀ⱠiiⱠiⱠ𐀀iⱠ𐀀ÀÀ𐀀ÀÀiⱠÀi𐀀ÀⱠii𐀀𐀀𐀀ÀÀ𐀀iⱠ𐀀iⱠÀⱠⱠiii𐀀|
  iÀiⱠÀi𐀀À𐀀𐀀iiÀ𐀀𐀀𐀀Ài𐀀𐀀ⱠÀÀ𐀀ii𐀀𐀀i𐀀ii𐀀Ⱡ𐀀𐀀𐀀ⱠÀⱠ𐀀ÀⱠ𐀀iÀÀÀⱠÀÀ𐀀𐀀iⱠⱠiÀ𐀀ÀⱠ𐀀iiÀÀiⱠⱠⱠⱠ𐀀Ⱡ𐀀Ⱡ𐀀À𐀀iⱠⱠiⱠ𐀀iiii𐀀Ⱡi𐀀ÀiⱠ𐀀ÀÀii|
  ⱠÀii𐀀ÀⱠⱠ𐀀𐀀i𐀀iiⱠ𐀀i𐀀Ⱡ𐀀À𐀀𐀀ⱠⱠiiÀiiÀi𐀀ii𐀀𐀀iiiÀiiⱠiÀ𐀀𐀀ÀÀÀ𐀀ÀⱠ𐀀Ài𐀀À𐀀ÀiiÀÀ𐀀Ⱡ𐀀ⱠⱠiiÀÀⱠ𐀀𐀀i𐀀𐀀ⱠⱠ𐀀𐀀𐀀𐀀ⱠiⱠ𐀀ⱠⱠÀ𐀀ⱠÀÀÀÀÀ|
  iⱠⱠⱠ𐀀ÀⱠ𐀀𐀀ÀiÀ𐀀À𐀀iiÀ𐀀𐀀iⱠiiⱠⱠÀiⱠÀⱠ𐀀ⱠÀÀ𐀀iiÀ𐀀𐀀ⱠÀiÀ𐀀iⱠiⱠÀⱠiiiⱠiiⱠⱠⱠiiÀ𐀀iÀ𐀀iⱠⱠ𐀀Ⱡi𐀀ⱠⱠÀiⱠ𐀀i𐀀𐀀𐀀iiⱠiÀ𐀀ÀⱠⱠÀÀÀ𐀀i𐀀|
  ÀÀÀii𐀀ⱠiⱠⱠiⱠ𐀀ⱠiⱠ𐀀ÀÀi𐀀𐀀ÀÀⱠⱠiÀÀiÀⱠÀ𐀀ⱠÀⱠ𐀀𐀀𐀀iⱠiⱠiⱠ𐀀À𐀀𐀀ÀⱠ𐀀𐀀iiÀⱠ𐀀i𐀀𐀀𐀀iiⱠÀ𐀀𐀀ÀiⱠi𐀀ⱠiÀ𐀀iÀⱠÀiÀⱠⱠⱠ𐀀ÀⱠ𐀀Ⱡ𐀀À𐀀ⱠÀiii|
  𐀀ÀÀ𐀀𐀀iⱠⱠ𐀀ⱠiⱠii𐀀𐀀ⱠⱠÀÀⱠÀⱠiÀⱠⱠ𐀀ÀⱠⱠÀ𐀀ii𐀀𐀀𐀀ii𐀀𐀀Ⱡii𐀀𐀀ÀÀÀiⱠÀiiiiiⱠiÀⱠⱠÀ𐀀𐀀ⱠÀⱠÀiiiⱠ𐀀ÀÀⱠÀi𐀀ⱠiÀiÀi𐀀ÀⱠiⱠiiⱠ𐀀iÀÀÀ|
  ⱠiiÀii𐀀ÀÀi𐀀𐀀ⱠÀÀⱠⱠ𐀀ii𐀀ÀⱠiⱠⱠÀ𐀀𐀀ⱠⱠiⱠⱠii𐀀iÀiiiⱠ𐀀iiⱠÀÀÀÀ𐀀ⱠÀi𐀀iⱠi𐀀ii𐀀Ⱡ𐀀ⱠÀiii𐀀𐀀ÀÀÀiiⱠÀ𐀀Ⱡ𐀀ⱠÀⱠⱠ𐀀𐀀𐀀𐀀𐀀À𐀀ÀⱠⱠi𐀀ⱠⱠ|
  ÀⱠ𐀀iiⱠⱠⱠÀÀ𐀀iÀiÀ𐀀ⱠⱠÀiÀⱠÀ𐀀ÀÀÀiⱠ𐀀𐀀ⱠÀ𐀀ÀⱠÀÀ𐀀𐀀𐀀𐀀𐀀ÀÀ𐀀𐀀iÀⱠⱠiⱠiÀiiiⱠiÀÀiⱠÀ𐀀𐀀Ài𐀀iⱠÀ𐀀ⱠÀÀÀ𐀀𐀀𐀀ÀⱠiiⱠ𐀀ÀⱠÀÀ𐀀iÀⱠÀⱠ𐀀À𐀀|
  𐀀Ⱡ𐀀ⱠⱠⱠⱠⱠⱠⱠiiⱠ𐀀ÀÀ𐀀iÀⱠiⱠÀÀⱠÀ𐀀i𐀀𐀀Ⱡ𐀀ⱠⱠÀⱠⱠ𐀀ⱠⱠ𐀀𐀀ÀⱠⱠiÀÀÀÀÀiⱠÀ𐀀ⱠÀÀ𐀀iÀi𐀀iⱠ𐀀Ⱡ𐀀Ⱡii𐀀iⱠⱠⱠⱠⱠⱠi𐀀iÀÀ𐀀ⱠÀiÀⱠiÀ𐀀𐀀ii𐀀𐀀𐀀À|
  iⱠi𐀀ÀⱠi𐀀Ⱡ𐀀Àiii𐀀Ⱡii𐀀Ⱡii𐀀𐀀Ⱡ𐀀ⱠÀÀii𐀀ⱠⱠ𐀀i𐀀𐀀ⱠiiⱠÀÀiⱠÀiⱠⱠÀⱠÀÀiÀi𐀀iⱠⱠ𐀀ⱠÀ𐀀iⱠÀÀ𐀀i𐀀𐀀ÀiⱠⱠÀiÀiiiⱠⱠⱠ𐀀À𐀀ÀÀiÀÀⱠÀⱠ𐀀ÀⱠ|
  𐀀𐀀Ⱡ𐀀ⱠÀÀ𐀀iiÀi𐀀𐀀iiÀÀ𐀀𐀀𐀀iⱠ𐀀À𐀀iⱠⱠⱠÀⱠiÀÀiÀⱠiiiÀiÀÀⱠⱠⱠÀÀⱠⱠiÀiⱠⱠⱠⱠÀiÀⱠiÀ𐀀À𐀀À𐀀𐀀iiiⱠ𐀀𐀀𐀀ÀⱠ𐀀ÀiÀÀiⱠÀÀⱠⱠÀⱠiiⱠi𐀀i𐀀|
  iÀiiⱠiiiiⱠÀ𐀀ÀÀÀiÀi𐀀iiiⱠ𐀀𐀀ⱠÀiⱠÀⱠiⱠÀiⱠÀⱠiÀⱠÀⱠÀÀÀÀiÀⱠi𐀀ⱠiⱠi𐀀Ⱡ𐀀À𐀀i𐀀𐀀ⱠiiÀⱠ𐀀ⱠÀⱠⱠⱠii𐀀𐀀iiiiii𐀀À𐀀iÀiiÀⱠÀⱠiⱠi𐀀|
  À𐀀i𐀀ⱠÀiⱠ𐀀ⱠÀⱠ𐀀𐀀ⱠⱠiⱠiiiⱠÀⱠÀⱠⱠÀ𐀀𐀀Ⱡ𐀀𐀀i𐀀ⱠÀ𐀀iⱠⱠiⱠiⱠ𐀀Ⱡiii𐀀𐀀À𐀀Ⱡ𐀀ⱠÀÀⱠÀ𐀀iÀⱠÀiⱠÀÀ𐀀Ⱡii𐀀ⱠiiiiⱠÀ𐀀Ài𐀀𐀀ⱠiⱠÀÀ𐀀𐀀ⱠiⱠⱠÀÀ|
  Ⱡ𐀀ÀⱠⱠ𐀀𐀀iⱠⱠ𐀀iÀÀiÀ𐀀ⱠÀ𐀀𐀀𐀀𐀀iⱠ𐀀À𐀀ⱠⱠ𐀀Ⱡ𐀀𐀀iⱠiⱠⱠ𐀀ⱠⱠÀÀⱠⱠÀÀⱠ𐀀𐀀ⱠÀÀii𐀀𐀀𐀀ÀÀⱠ𐀀i𐀀Ⱡ𐀀iiiÀÀÀⱠiÀiÀ𐀀ii𐀀𐀀iⱠⱠⱠii𐀀iiⱠⱠi𐀀ÀÀ𐀀i|
  𐀀ÀÀ𐀀𐀀ⱠÀ𐀀ⱠⱠⱠÀ𐀀Ⱡ𐀀ii𐀀Ⱡ𐀀𐀀ⱠⱠ𐀀À𐀀𐀀𐀀ⱠiⱠⱠⱠ𐀀ⱠÀi𐀀𐀀Ⱡ𐀀Ài𐀀ⱠÀÀi𐀀À𐀀iⱠiⱠⱠ𐀀iiÀiⱠⱠÀ𐀀À𐀀iiⱠⱠⱠⱠ𐀀ÀÀⱠⱠⱠiÀⱠ𐀀i𐀀i𐀀iiÀ𐀀i𐀀ⱠiÀÀÀiÀ|
  Ⱡii𐀀i𐀀ⱠiÀiiÀÀÀ𐀀Àii𐀀ⱠÀⱠi𐀀ⱠⱠiⱠⱠi𐀀i𐀀𐀀iⱠⱠ𐀀𐀀iⱠ𐀀iⱠⱠ𐀀ÀiiⱠiⱠiii𐀀ÀÀÀi𐀀ⱠiÀⱠⱠⱠÀⱠⱠⱠⱠⱠⱠÀiiÀⱠi𐀀ÀÀiÀⱠ𐀀ÀiⱠⱠÀ𐀀𐀀iiÀ𐀀𐀀À|
  iⱠⱠiⱠiiⱠÀÀⱠ𐀀iÀÀiÀ𐀀iiⱠÀ𐀀i𐀀ⱠⱠ𐀀iⱠⱠ𐀀À𐀀𐀀iiⱠⱠⱠ𐀀ⱠiⱠi𐀀iⱠ𐀀ⱠⱠÀiⱠ𐀀𐀀Ⱡ𐀀Ⱡi𐀀iⱠⱠÀ𐀀À𐀀ÀⱠⱠ𐀀ÀⱠⱠi𐀀Ⱡi𐀀iÀⱠÀ𐀀À𐀀ⱠÀ𐀀ⱠÀÀi𐀀Ⱡ𐀀iiÀ|
  ⱠⱠⱠ𐀀ⱠiÀⱠⱠiiiiiiⱠi𐀀i𐀀ⱠÀ𐀀i𐀀𐀀ⱠⱠÀⱠi𐀀ÀÀÀÀⱠ𐀀ⱠⱠ𐀀i𐀀iiÀ𐀀Ài𐀀𐀀i𐀀i𐀀𐀀ÀⱠⱠⱠii𐀀ÀiiÀiⱠiⱠ𐀀iiⱠⱠⱠⱠ𐀀i𐀀ii𐀀iiÀÀ𐀀𐀀ÀⱠ𐀀ÀⱠ𐀀iÀ𐀀𐀀|
  iⱠÀiⱠii𐀀𐀀ÀiⱠⱠiiÀ𐀀ÀÀ𐀀𐀀ⱠÀⱠ𐀀iⱠiiⱠiiÀi𐀀ⱠⱠⱠiÀi𐀀𐀀ÀⱠÀÀⱠi𐀀iÀⱠÀⱠÀ𐀀𐀀À𐀀𐀀À𐀀ⱠiÀÀi𐀀iÀÀ𐀀ÀⱠⱠⱠi𐀀iⱠⱠi𐀀iiⱠⱠⱠÀiÀ𐀀𐀀Ⱡ𐀀ÀÀ𐀀À|
  ÀiⱠÀÀⱠÀÀÀⱠⱠÀⱠii𐀀i𐀀i𐀀iiⱠiÀiÀÀÀⱠⱠiⱠiiÀÀÀⱠÀⱠÀÀÀⱠii𐀀Ⱡ𐀀Ⱡi𐀀ÀⱠⱠiÀÀⱠi𐀀Ⱡ𐀀𐀀ÀⱠⱠ𐀀iⱠⱠ𐀀iÀiÀÀⱠÀÀ𐀀i𐀀𐀀ÀⱠiÀⱠⱠ𐀀𐀀ÀⱠⱠiⱠÀi|
  ÀiⱠÀiiiÀⱠ𐀀𐀀iⱠ𐀀𐀀iÀÀÀⱠÀⱠiÀiÀi𐀀Ⱡ𐀀À𐀀iiⱠ𐀀ÀiÀⱠⱠ𐀀iiiⱠ𐀀Ài𐀀𐀀𐀀𐀀𐀀𐀀𐀀ÀⱠÀ𐀀ÀiÀ𐀀ÀÀ𐀀iⱠⱠ𐀀Ⱡ𐀀i𐀀𐀀iii𐀀𐀀𐀀𐀀ⱠⱠi𐀀ii𐀀𐀀ⱠⱠⱠ𐀀ÀiⱠÀⱠ|
  À𐀀ⱠÀ𐀀𐀀𐀀À𐀀ÀiÀⱠiiⱠⱠÀⱠⱠiⱠÀÀ𐀀𐀀i𐀀𐀀𐀀ⱠiÀⱠÀÀ𐀀𐀀𐀀À𐀀ⱠⱠiÀiÀi𐀀ⱠiÀiiⱠÀ𐀀ÀiiiⱠⱠiⱠ𐀀ⱠiÀ𐀀ÀⱠÀÀi𐀀ⱠiⱠiiⱠiÀiiⱠÀⱠiiÀi𐀀Ⱡ𐀀𐀀iⱠi|
  ÀÀ𐀀iÀÀÀ𐀀Ⱡ𐀀𐀀ÀⱠⱠ𐀀Ⱡ𐀀Ⱡ𐀀ⱠÀ𐀀i𐀀ÀÀiÀÀ𐀀À𐀀𐀀𐀀iÀiⱠiiÀⱠÀiⱠii𐀀𐀀iÀii𐀀Ⱡ𐀀ⱠÀⱠiⱠiⱠ𐀀ÀⱠÀ𐀀i𐀀iⱠⱠ𐀀ⱠⱠⱠÀÀÀii𐀀Ⱡ𐀀𐀀i𐀀i𐀀𐀀iⱠi𐀀À𐀀𐀀^Ⱡ |
                                                                                                      |
      ]=],
      value = { col = 100, curscol = 100, endcol = 100, row = 50 },
    },
  },
  {
    ascii_results,
    two_byte_results,
    three_byte_results,
    { -- random
      screen = [=[
  Ⱡ𐀀ii𐀀ⱠÀ𐀀i𐀀𐀀iÀÀÀiÀ𐀀Ⱡ𐀀ⱠiiⱠ𐀀iii𐀀ÀⱠÀⱠⱠÀiiÀⱠÀiⱠi𐀀ÀÀ𐀀𐀀Ⱡ𐀀𐀀Ⱡ𐀀iÀⱠ𐀀i𐀀ÀÀⱠiiÀ𐀀Ⱡ𐀀À𐀀ii𐀀ÀÀ𐀀ÀⱠⱠ𐀀𐀀𐀀𐀀ii𐀀ⱠⱠiⱠⱠ𐀀ⱠÀ𐀀ÀÀiiⱠ|
  iiⱠ𐀀iÀÀiⱠⱠÀi𐀀ⱠⱠÀ𐀀𐀀ÀiiiiÀiⱠ𐀀iⱠÀiⱠiⱠⱠÀiÀ𐀀ⱠiiⱠⱠÀ𐀀Àii𐀀ⱠÀⱠiⱠÀⱠÀⱠii𐀀Ài𐀀ⱠⱠ𐀀ÀÀÀi𐀀ÀÀÀ𐀀iⱠ𐀀iⱠÀ𐀀iⱠi𐀀ÀiÀ𐀀ⱠⱠiÀ𐀀𐀀Ⱡi|
  iÀiiiⱠÀÀ𐀀ⱠⱠⱠi𐀀À𐀀𐀀iiiÀÀiiÀⱠÀ𐀀À𐀀ⱠⱠ𐀀𐀀ⱠⱠⱠi𐀀iiÀⱠ𐀀ⱠⱠⱠÀiⱠiⱠiÀÀÀi𐀀iⱠ𐀀ÀÀiⱠ𐀀iÀÀi𐀀i𐀀𐀀ÀiÀⱠ𐀀𐀀iⱠ𐀀ÀÀiÀÀⱠ𐀀𐀀ⱠⱠ𐀀𐀀𐀀𐀀Ⱡ𐀀𐀀|
  ÀⱠiⱠiÀ𐀀i𐀀ⱠⱠiⱠⱠÀ𐀀ÀÀÀÀ𐀀𐀀ÀⱠⱠ𐀀ⱠÀÀiⱠ𐀀i𐀀Ⱡ𐀀ÀⱠi𐀀ⱠÀⱠÀ𐀀ⱠⱠ𐀀i𐀀iⱠÀi𐀀i𐀀𐀀À𐀀iÀiⱠⱠⱠ𐀀ÀiÀⱠÀ𐀀ÀÀÀi𐀀𐀀𐀀ⱠÀi𐀀𐀀À𐀀À𐀀𐀀iiⱠiÀi𐀀i𐀀Ⱡ|
  Ⱡ𐀀i𐀀𐀀ÀiÀⱠⱠⱠⱠⱠÀÀⱠⱠÀⱠ𐀀ii𐀀ÀⱠiⱠiii𐀀i𐀀i𐀀𐀀𐀀À𐀀ii𐀀iÀiiiÀÀⱠiiiⱠiiⱠÀ𐀀À𐀀𐀀ÀⱠ𐀀iÀÀiiÀiÀ𐀀iⱠi𐀀𐀀À𐀀ÀiiⱠ𐀀iÀ𐀀𐀀iⱠⱠÀÀⱠⱠiiÀ|
  𐀀ÀiⱠⱠÀ𐀀𐀀𐀀i𐀀i𐀀i𐀀ⱠÀ𐀀ÀiiÀⱠ𐀀ÀÀÀi𐀀ⱠÀiÀⱠi𐀀ⱠÀiiÀÀÀiiiÀiⱠⱠiÀ𐀀ⱠⱠ𐀀iÀⱠÀⱠⱠiÀÀⱠÀⱠÀÀii𐀀Ⱡi𐀀iiÀÀÀiⱠ𐀀i𐀀𐀀i𐀀iiÀ𐀀𐀀𐀀ⱠÀiⱠ𐀀|
  i𐀀ÀⱠiⱠi𐀀ⱠiⱠ𐀀Ⱡi𐀀ⱠÀ𐀀𐀀𐀀ⱠÀiiiii𐀀Ⱡ𐀀iiiÀiiÀ𐀀𐀀𐀀À𐀀𐀀Ⱡ𐀀ⱠÀ𐀀ⱠⱠⱠiÀÀÀÀii𐀀i𐀀ÀiiⱠÀiÀ𐀀iⱠⱠiÀⱠii𐀀i𐀀Ⱡ𐀀𐀀iⱠⱠÀ𐀀ⱠiiiⱠⱠÀÀ𐀀iÀⱠ|
  Ⱡ𐀀𐀀ⱠⱠ𐀀À𐀀ÀⱠ𐀀ÀⱠÀ𐀀𐀀iⱠⱠÀÀiÀⱠ𐀀ÀiÀⱠi𐀀ⱠÀ𐀀𐀀𐀀𐀀Ⱡ𐀀iⱠÀ𐀀iÀ𐀀iÀ𐀀iÀÀⱠi𐀀iÀⱠi𐀀ⱠiiⱠÀ𐀀À𐀀ⱠⱠÀÀi𐀀ⱠⱠ𐀀iiⱠÀiⱠ𐀀𐀀𐀀𐀀ⱠⱠⱠÀⱠiÀⱠiÀÀ𐀀À|
  ÀⱠÀÀ𐀀i𐀀iⱠÀÀÀⱠ𐀀𐀀ÀⱠÀÀiii𐀀𐀀iiÀiiⱠÀÀⱠiÀiÀÀ𐀀i𐀀i𐀀ⱠiⱠⱠiⱠÀiiÀⱠ𐀀ⱠⱠÀiÀⱠ𐀀𐀀iÀ𐀀Ⱡ𐀀iÀ𐀀ⱠÀÀⱠÀÀÀ𐀀𐀀i𐀀𐀀À𐀀𐀀ii𐀀À𐀀𐀀ⱠÀ𐀀ⱠⱠⱠ𐀀𐀀|
  ÀÀÀÀiⱠiⱠⱠⱠiⱠ𐀀ⱠÀÀÀ𐀀ÀÀiⱠÀ𐀀ÀiⱠÀⱠÀⱠⱠÀÀⱠiÀⱠⱠiiⱠÀ𐀀ⱠⱠÀiⱠ𐀀iÀⱠ𐀀Ⱡ𐀀Ⱡ𐀀iⱠÀⱠi𐀀𐀀Ⱡ𐀀iÀ𐀀ÀⱠ𐀀ÀÀⱠ𐀀Ⱡi𐀀iⱠÀ𐀀𐀀𐀀𐀀i𐀀i𐀀𐀀𐀀ÀⱠiÀÀ𐀀i|
  𐀀𐀀iiÀ𐀀ÀⱠ𐀀𐀀𐀀𐀀𐀀Àiii𐀀𐀀𐀀Ⱡ𐀀𐀀i𐀀ÀÀ𐀀iiÀiiiiÀ𐀀iⱠiⱠiÀⱠÀⱠÀiⱠⱠⱠⱠⱠⱠⱠⱠⱠÀiiⱠiÀⱠÀ𐀀iiⱠÀⱠiⱠⱠÀiⱠ𐀀iⱠ𐀀iiⱠÀ𐀀𐀀Àii𐀀i𐀀ÀⱠÀÀiÀÀ|
  𐀀𐀀𐀀i𐀀iÀ𐀀𐀀iÀ𐀀Ài𐀀𐀀ⱠⱠ𐀀ⱠÀi𐀀𐀀ÀÀiiiⱠiⱠ𐀀iⱠÀⱠÀ𐀀ⱠÀ𐀀ⱠiiiiÀiⱠÀiiiⱠⱠÀ𐀀Ⱡ𐀀𐀀𐀀ÀⱠiÀⱠiiiiⱠiⱠ𐀀Ⱡ𐀀ÀⱠÀii𐀀i𐀀Ⱡ𐀀À𐀀iⱠⱠ𐀀iⱠiiii𐀀|
  iⱠÀÀⱠÀÀ𐀀𐀀𐀀iiiÀ𐀀À𐀀iÀÀi𐀀À𐀀ÀⱠÀiÀii𐀀ⱠⱠii𐀀ⱠⱠ𐀀𐀀ÀⱠ𐀀ÀÀ𐀀ÀÀÀÀi𐀀ÀⱠ𐀀À𐀀ÀiiⱠ𐀀ÀÀⱠiⱠ𐀀Ⱡ𐀀ÀÀ𐀀ⱠⱠ𐀀ⱠⱠÀ𐀀ⱠⱠⱠ𐀀iiÀⱠÀⱠiⱠi𐀀ii𐀀Ài|
  Ⱡ𐀀ⱠÀ𐀀Ⱡi𐀀iÀ𐀀Ⱡ𐀀𐀀iÀiÀ𐀀iⱠi𐀀ⱠÀiⱠⱠiÀ𐀀iⱠiÀⱠi𐀀𐀀iⱠiⱠⱠ𐀀ÀÀi𐀀iÀⱠⱠ𐀀ⱠÀ𐀀𐀀𐀀ⱠⱠiÀÀiⱠⱠⱠ𐀀𐀀ⱠⱠⱠⱠÀiⱠ𐀀Ài𐀀iÀⱠii𐀀ÀⱠii𐀀Ⱡ𐀀ÀⱠÀ𐀀Ⱡi|
  𐀀ⱠⱠⱠⱠⱠ𐀀Ⱡ𐀀ÀÀ𐀀𐀀iÀÀⱠiÀiiⱠÀiⱠ𐀀𐀀ÀÀiÀⱠ𐀀ÀÀⱠ𐀀À𐀀À𐀀iⱠⱠÀiⱠÀiiiⱠÀiÀÀÀ𐀀iⱠⱠⱠÀÀiⱠⱠⱠ𐀀ii𐀀ii𐀀iⱠⱠii𐀀iⱠÀi𐀀𐀀𐀀ii𐀀ÀⱠⱠiⱠÀ𐀀ⱠⱠ|
  𐀀iⱠ𐀀ⱠⱠⱠÀÀ𐀀iiiÀÀⱠii𐀀i𐀀ÀÀⱠ𐀀ⱠⱠiⱠⱠⱠiⱠ𐀀i𐀀À𐀀ⱠⱠⱠi𐀀Ài𐀀ⱠÀ𐀀ÀⱠiiiiⱠiiⱠⱠi𐀀𐀀ÀⱠ𐀀ⱠiÀÀ𐀀iiiⱠÀiⱠi𐀀À𐀀𐀀i𐀀𐀀iiⱠ𐀀À𐀀iiⱠⱠÀ𐀀iⱠ|
  ⱠⱠÀÀⱠⱠ𐀀iÀⱠ𐀀iⱠⱠÀÀ𐀀ÀiⱠ𐀀iÀⱠⱠⱠ𐀀𐀀À𐀀ii𐀀𐀀À𐀀𐀀ÀⱠⱠⱠÀⱠiiⱠ𐀀𐀀ii𐀀ⱠⱠÀⱠiⱠi𐀀ⱠⱠ𐀀i𐀀𐀀𐀀𐀀Ⱡ𐀀iÀiⱠⱠ𐀀À𐀀ÀⱠⱠⱠÀÀ𐀀𐀀iÀⱠi𐀀𐀀ÀiⱠⱠÀÀiÀÀ|
  𐀀ⱠÀiÀ𐀀ⱠⱠ𐀀i𐀀ⱠⱠ𐀀𐀀𐀀𐀀𐀀𐀀iⱠÀⱠⱠiiÀⱠ𐀀𐀀i𐀀ⱠⱠ𐀀ⱠⱠⱠ𐀀𐀀iÀiÀⱠ𐀀À𐀀À𐀀𐀀ⱠiiiⱠiiiⱠiⱠ𐀀ÀiiiⱠ𐀀À𐀀ÀⱠⱠÀ𐀀À𐀀𐀀𐀀ⱠiⱠi𐀀ⱠÀÀⱠiiⱠⱠⱠⱠ𐀀ÀⱠ𐀀𐀀|
  Ⱡ𐀀iÀÀⱠ𐀀ⱠⱠÀⱠÀ𐀀ⱠⱠÀiiÀÀÀⱠ𐀀i𐀀Ⱡ𐀀ⱠÀ𐀀𐀀iⱠⱠⱠⱠiiⱠⱠⱠÀiⱠÀiiⱠÀ𐀀Ⱡ𐀀Ⱡi𐀀𐀀ⱠÀ𐀀ÀⱠⱠ𐀀ÀⱠÀⱠ𐀀Ⱡ𐀀iⱠi𐀀ÀⱠⱠii𐀀ÀⱠÀ𐀀Ⱡ𐀀Ài𐀀À𐀀ÀÀⱠiⱠⱠii𐀀|
  ÀⱠⱠⱠÀⱠⱠii𐀀Ài𐀀Ⱡi𐀀i𐀀i𐀀Ⱡ𐀀ÀÀÀiÀÀi𐀀ÀÀÀ𐀀i𐀀iÀ𐀀𐀀ⱠiÀi𐀀𐀀𐀀ⱠÀiÀ𐀀𐀀iÀÀⱠⱠ𐀀ⱠⱠⱠⱠÀÀÀÀiiÀ𐀀iiⱠⱠⱠi𐀀ⱠÀi𐀀ÀⱠⱠÀ𐀀ⱠiiⱠ𐀀𐀀i𐀀Ⱡi𐀀𐀀À|
  ÀⱠiiÀi𐀀ⱠÀÀiÀⱠi𐀀ÀⱠⱠ𐀀ⱠiÀiiⱠiiⱠⱠ𐀀ii𐀀i𐀀𐀀𐀀𐀀i𐀀ⱠⱠÀⱠÀÀiÀÀÀⱠÀⱠⱠÀÀⱠ𐀀ÀÀ𐀀ÀÀⱠÀ𐀀𐀀ÀiⱠ𐀀ⱠⱠ𐀀iÀ𐀀Ⱡ𐀀iÀⱠⱠ𐀀iÀiiii𐀀ii𐀀𐀀ⱠⱠⱠ𐀀Ⱡ|
  𐀀ÀiÀⱠÀiiÀÀiiⱠⱠⱠi𐀀ÀÀiⱠ𐀀iⱠⱠÀ𐀀𐀀𐀀ÀⱠⱠÀ𐀀ⱠÀÀⱠ𐀀ÀÀ𐀀𐀀Ⱡ𐀀ÀÀ𐀀ÀⱠ𐀀ⱠÀiÀ𐀀iⱠ𐀀ⱠⱠ𐀀𐀀À𐀀iii𐀀iiⱠÀⱠiⱠÀⱠ𐀀Ⱡ𐀀i𐀀𐀀ÀⱠⱠi𐀀𐀀ⱠⱠ𐀀𐀀𐀀𐀀À𐀀Ⱡ𐀀|
  𐀀iiÀⱠiⱠiÀⱠ𐀀i𐀀iii𐀀Ⱡ𐀀i𐀀iÀÀi𐀀Ⱡii𐀀ÀiÀiiiÀⱠÀ𐀀ÀÀⱠ𐀀Ⱡ𐀀iiÀi𐀀i𐀀𐀀i𐀀ⱠiiiÀⱠⱠⱠiiÀ𐀀À𐀀𐀀iÀ𐀀iⱠÀⱠÀÀi𐀀ⱠiÀⱠÀ𐀀𐀀iÀÀ𐀀i𐀀𐀀ÀÀⱠ𐀀|
  ÀiÀⱠⱠⱠⱠii𐀀ÀÀ𐀀𐀀𐀀Ⱡi𐀀À𐀀ÀⱠiiÀi𐀀Ⱡii𐀀iÀÀ𐀀ⱠiⱠ𐀀ⱠiiiⱠÀÀiÀÀÀÀ𐀀ⱠⱠii𐀀À𐀀ÀiÀi𐀀ÀÀi𐀀iⱠiÀi𐀀ÀiÀi𐀀ÀiÀⱠ𐀀i𐀀Ⱡi𐀀𐀀𐀀ⱠⱠ𐀀ⱠÀⱠÀⱠi|
  i𐀀ⱠiÀⱠⱠÀÀ𐀀𐀀ii𐀀ÀÀ𐀀iÀiÀⱠÀiiii𐀀ÀiÀⱠi𐀀i𐀀𐀀i𐀀𐀀iⱠ𐀀iÀi𐀀ÀÀÀÀiⱠiÀⱠÀÀⱠiiÀÀⱠⱠi𐀀iⱠiiⱠi𐀀Ⱡ𐀀𐀀ÀⱠⱠÀⱠiⱠⱠÀ𐀀iiÀⱠⱠⱠ𐀀𐀀Ⱡi𐀀Ⱡi|
  ii𐀀iÀÀÀÀÀÀiÀ𐀀À𐀀iiⱠiⱠⱠi𐀀À𐀀ÀⱠÀ𐀀ⱠⱠ𐀀𐀀𐀀iⱠⱠiiⱠÀÀⱠÀiiⱠÀⱠⱠÀ𐀀𐀀Ⱡ𐀀ÀÀÀÀⱠ𐀀𐀀𐀀ⱠⱠÀⱠ𐀀ÀiⱠiÀⱠiÀÀ𐀀ii𐀀iiiÀⱠÀⱠⱠ𐀀ⱠÀiÀÀ𐀀ⱠⱠⱠÀ|
  𐀀𐀀À𐀀𐀀iÀⱠ𐀀ⱠiⱠÀÀ𐀀iÀÀ𐀀À𐀀iÀÀⱠⱠÀiii𐀀À𐀀ÀⱠÀⱠⱠÀⱠⱠi𐀀ÀÀÀi𐀀À𐀀ⱠiÀi𐀀i𐀀i𐀀ÀiÀÀiÀÀ𐀀𐀀À𐀀ⱠÀ𐀀ⱠÀⱠ𐀀ⱠiÀ𐀀𐀀ÀiÀÀ𐀀𐀀𐀀À𐀀Ⱡi𐀀i𐀀i𐀀Ài|
  𐀀𐀀iⱠ𐀀i𐀀ÀⱠⱠÀ𐀀iÀ𐀀ÀiⱠⱠi𐀀iiⱠÀ𐀀ÀiiÀⱠ𐀀Ⱡ𐀀ÀÀiÀiⱠi𐀀À𐀀𐀀iÀiÀiⱠi𐀀ⱠⱠⱠi𐀀À𐀀ÀⱠⱠ𐀀Ⱡ𐀀ÀÀⱠiÀiÀ𐀀Ⱡ𐀀ÀⱠiⱠⱠÀÀÀi𐀀i𐀀Ⱡi𐀀À𐀀ii𐀀ⱠÀ𐀀Ⱡ|
  ⱠiⱠ𐀀iÀⱠⱠ𐀀i𐀀À𐀀iÀÀ𐀀𐀀ÀⱠⱠÀⱠÀ𐀀iiiÀ𐀀i𐀀iÀ𐀀ⱠⱠ𐀀iÀⱠ𐀀ⱠÀi𐀀iiii𐀀iⱠⱠ𐀀ÀiÀ𐀀Àii𐀀Ⱡ𐀀𐀀ⱠiÀii𐀀𐀀Ⱡ𐀀𐀀ⱠiⱠ𐀀iⱠiⱠi𐀀iiiⱠⱠⱠi𐀀iiÀi𐀀Ⱡ|
  i𐀀i𐀀ÀÀÀ𐀀ÀiÀⱠiÀiiⱠÀÀÀiÀiiii𐀀i𐀀ÀÀiiiⱠÀiÀⱠÀiⱠ𐀀iiⱠiⱠⱠiÀi𐀀ⱠⱠ𐀀ÀⱠiⱠ𐀀ⱠÀiiⱠÀ𐀀ÀⱠⱠ𐀀ⱠiÀi𐀀À𐀀𐀀iiÀ𐀀𐀀ÀiⱠⱠiⱠ𐀀ÀⱠiÀÀⱠ𐀀i|
  Ài𐀀𐀀𐀀iÀi𐀀Ài𐀀À𐀀ⱠⱠ𐀀ⱠÀiiÀⱠ𐀀i𐀀i𐀀𐀀ⱠiⱠÀ𐀀𐀀Ⱡ𐀀iÀ𐀀ÀÀⱠiⱠⱠiÀ𐀀iÀ𐀀ⱠiÀÀÀÀⱠiiÀ𐀀𐀀ÀⱠⱠiÀ𐀀iiÀ𐀀À𐀀iÀiÀÀ𐀀iÀiÀÀiiÀ𐀀ÀⱠⱠÀiiÀÀⱠ|
  𐀀ⱠÀⱠiⱠⱠÀ𐀀ÀiiÀ𐀀iÀⱠⱠⱠⱠiÀÀi𐀀iÀi𐀀iiiⱠ𐀀iⱠ𐀀𐀀𐀀𐀀ÀÀÀⱠi𐀀iⱠi𐀀ⱠÀⱠⱠ𐀀𐀀À𐀀iiÀⱠ𐀀𐀀ⱠⱠ𐀀𐀀ÀiⱠÀÀÀⱠ𐀀𐀀ÀiⱠ𐀀𐀀iÀÀiÀ𐀀ⱠÀi𐀀𐀀ⱠⱠⱠⱠ𐀀Ⱡi|
  iÀi𐀀ⱠⱠÀ𐀀𐀀i𐀀Àii𐀀ÀiÀÀiÀiÀÀ𐀀ÀÀ𐀀À𐀀ⱠⱠⱠÀÀÀⱠii𐀀ⱠÀÀⱠⱠi𐀀ⱠⱠiⱠⱠ𐀀Ⱡ𐀀ÀiÀiiii𐀀ÀiⱠÀiiiiⱠⱠiiⱠÀÀÀⱠÀⱠ𐀀𐀀𐀀iiⱠⱠ𐀀ⱠÀⱠ𐀀iⱠⱠ𐀀𐀀Ⱡ|
  À𐀀À𐀀ⱠⱠⱠiÀ𐀀ÀⱠÀⱠⱠiiⱠii𐀀ⱠÀÀÀ𐀀iⱠiiiiiÀ𐀀ÀÀiÀÀⱠ𐀀𐀀iiⱠi𐀀𐀀Ài𐀀ⱠÀÀiⱠⱠⱠⱠ𐀀iⱠiⱠⱠⱠⱠⱠÀÀⱠiiÀiⱠ𐀀iÀiiⱠiiii𐀀ii𐀀À𐀀ⱠÀ𐀀Ⱡ𐀀ÀⱠ|
  ÀⱠÀiiiiⱠiiⱠiÀi𐀀𐀀ⱠÀÀ𐀀Ài𐀀Ài𐀀ÀiⱠÀ𐀀ⱠⱠⱠⱠ𐀀ⱠiÀ𐀀iⱠⱠÀⱠi𐀀Ài𐀀ⱠiiⱠ𐀀Ⱡii𐀀ÀÀÀⱠ𐀀ÀÀÀⱠÀiÀⱠiⱠiⱠi𐀀𐀀À𐀀𐀀𐀀ÀⱠiⱠⱠⱠⱠÀiiÀⱠ𐀀À𐀀𐀀À|
  iÀ𐀀ÀⱠⱠÀiÀi𐀀Ài𐀀ÀiⱠⱠÀ𐀀iⱠÀ𐀀i𐀀ÀiiÀÀÀⱠÀÀⱠ𐀀À𐀀À𐀀ÀÀÀÀⱠi𐀀iⱠÀ𐀀𐀀ÀⱠiÀiⱠⱠiÀ𐀀ⱠⱠÀ𐀀𐀀Ⱡ𐀀ÀÀ𐀀ⱠⱠÀÀiÀi𐀀𐀀𐀀À𐀀ÀⱠ𐀀iⱠⱠ𐀀𐀀𐀀i𐀀ⱠÀ𐀀Ⱡ|
  Ⱡi𐀀ÀÀ𐀀ⱠÀiÀi𐀀i𐀀ÀⱠ𐀀Ⱡ𐀀ÀⱠ𐀀ⱠÀⱠⱠⱠ𐀀𐀀ÀiiiiⱠⱠi𐀀ⱠÀⱠÀ𐀀Ⱡ𐀀i𐀀À𐀀𐀀𐀀Ⱡ𐀀ÀiÀÀⱠⱠiiⱠiÀiⱠⱠÀiÀÀⱠⱠÀÀⱠÀ𐀀ⱠiⱠ𐀀𐀀i𐀀i𐀀𐀀ÀⱠÀⱠⱠⱠÀÀiiÀ𐀀|
  ⱠⱠⱠiiÀⱠⱠiÀⱠ𐀀ÀiⱠⱠÀⱠiÀⱠⱠÀÀi𐀀ÀÀiÀ𐀀𐀀i𐀀i𐀀iiÀÀiⱠ𐀀Ⱡ𐀀𐀀𐀀ÀiiⱠ𐀀Ài𐀀iiiiÀiⱠⱠii𐀀Ⱡi𐀀iⱠⱠ𐀀ÀÀⱠ𐀀iÀⱠⱠⱠiÀ𐀀𐀀iÀⱠiⱠÀ𐀀ÀⱠÀiⱠ𐀀À|
  𐀀ⱠⱠⱠiⱠⱠiiii𐀀𐀀i𐀀Àiiii𐀀À𐀀Ⱡi𐀀iⱠ𐀀ⱠiÀiÀⱠi𐀀𐀀ÀiÀiiÀÀÀ𐀀𐀀i𐀀À𐀀ÀⱠÀiiÀⱠ𐀀ⱠⱠ𐀀𐀀Ⱡ𐀀ÀÀiÀ𐀀iⱠ𐀀𐀀iÀÀⱠi𐀀iⱠiÀ𐀀ⱠⱠ𐀀ÀÀⱠiÀ𐀀ÀⱠⱠÀⱠ|
  Ⱡii𐀀𐀀ⱠÀiⱠⱠÀÀ𐀀ÀÀÀÀÀÀÀⱠiⱠⱠÀÀi𐀀ÀiⱠÀ𐀀𐀀i𐀀ⱠÀii𐀀Ⱡ𐀀𐀀À𐀀𐀀ÀiÀ𐀀i𐀀𐀀ⱠÀiÀÀⱠiiⱠⱠiⱠÀiÀⱠÀi𐀀iÀ𐀀À𐀀𐀀ⱠⱠi𐀀ⱠÀiÀÀÀⱠÀiÀÀⱠiⱠ𐀀iÀ|
  𐀀ÀⱠiÀⱠⱠⱠÀÀⱠÀⱠ𐀀iiiiÀiÀÀⱠ𐀀Ⱡiii𐀀𐀀iiⱠiÀ𐀀𐀀i𐀀ÀiiÀⱠ𐀀𐀀Ⱡ𐀀Ⱡ𐀀Ⱡii𐀀ⱠiⱠÀiⱠⱠÀÀÀⱠÀ𐀀Ⱡ𐀀𐀀𐀀À𐀀Ⱡ𐀀Ⱡ𐀀ⱠÀ𐀀ⱠⱠiⱠ𐀀𐀀ÀiiiÀ𐀀ÀiÀiⱠÀ𐀀À|
  i𐀀ⱠiⱠi𐀀ii𐀀𐀀iiiⱠⱠÀÀiiii𐀀ÀiⱠⱠÀi𐀀ÀÀÀÀiÀiiⱠ𐀀ÀⱠiⱠⱠiÀⱠ𐀀ÀⱠⱠ𐀀ÀÀÀ𐀀ⱠÀ𐀀À𐀀iⱠi𐀀iÀÀi𐀀iÀÀiⱠⱠ𐀀ⱠiÀÀiÀ𐀀iⱠ𐀀ⱠÀⱠÀii𐀀𐀀ⱠⱠi𐀀|
  iⱠ𐀀À𐀀𐀀Ài𐀀ÀⱠ𐀀Ⱡ𐀀𐀀ⱠÀ𐀀ⱠⱠⱠiÀ𐀀ÀiⱠⱠⱠÀⱠÀⱠiÀⱠi𐀀ÀÀÀⱠÀiÀⱠÀÀÀiii𐀀𐀀ÀiiⱠÀi𐀀iÀ𐀀À𐀀ÀiiÀÀÀiÀiÀÀi𐀀iiiiÀ𐀀ÀⱠⱠiiⱠi𐀀iiⱠ𐀀À𐀀𐀀|
  ⱠⱠÀÀiⱠ𐀀iⱠiÀÀⱠⱠi𐀀ⱠÀÀiⱠ𐀀ⱠⱠÀÀÀii𐀀𐀀iiⱠ𐀀iⱠ𐀀iⱠⱠ𐀀Ài𐀀iiÀÀⱠⱠ𐀀Ⱡ𐀀𐀀𐀀i𐀀ÀÀi𐀀𐀀ⱠiÀi𐀀iÀiiⱠⱠÀⱠⱠiⱠÀiⱠⱠⱠÀÀÀ𐀀ⱠÀ𐀀ⱠÀⱠⱠiÀÀⱠ𐀀|
  Àii𐀀i𐀀iⱠÀÀⱠⱠÀii𐀀ⱠⱠiÀiÀiⱠÀiⱠ𐀀Ⱡi𐀀𐀀𐀀À𐀀𐀀𐀀𐀀𐀀iⱠ𐀀ⱠⱠi𐀀i𐀀iⱠ𐀀ⱠⱠÀⱠ𐀀iⱠⱠⱠiⱠⱠ𐀀ⱠⱠⱠⱠ𐀀ⱠÀÀⱠⱠⱠⱠÀ𐀀ⱠÀⱠÀiiÀiÀiÀⱠi𐀀𐀀𐀀𐀀À𐀀𐀀𐀀À|
  ⱠiÀiⱠi𐀀𐀀ÀiⱠiⱠÀ𐀀iÀii𐀀ⱠÀ𐀀𐀀ⱠÀiÀÀ𐀀ⱠÀÀⱠ𐀀iÀiⱠ𐀀𐀀Ⱡ𐀀ⱠⱠⱠÀ𐀀iÀⱠiⱠÀÀ𐀀ⱠÀⱠⱠⱠⱠÀ𐀀𐀀À𐀀Ⱡ𐀀À𐀀iⱠi𐀀i𐀀Ⱡi𐀀Ⱡ𐀀𐀀iiiⱠiⱠ𐀀À𐀀ⱠÀ𐀀𐀀iÀÀi|
  Ⱡi𐀀ÀÀiÀi𐀀iⱠÀ𐀀𐀀ⱠiⱠÀⱠÀ𐀀iÀÀÀⱠ𐀀𐀀iÀÀiⱠ𐀀ii𐀀i𐀀𐀀iiiⱠⱠⱠÀÀiⱠÀ𐀀i𐀀ÀiⱠÀÀⱠⱠi𐀀ⱠÀ𐀀À𐀀iiⱠⱠ𐀀𐀀iÀⱠÀi𐀀À𐀀𐀀iÀ𐀀ii𐀀𐀀À𐀀iÀ𐀀𐀀iÀi𐀀|
  iⱠÀiiiⱠ𐀀ⱠiÀⱠⱠⱠⱠ𐀀À𐀀ⱠⱠ𐀀ⱠⱠi𐀀𐀀𐀀ⱠÀÀ𐀀𐀀Ⱡ𐀀iÀ𐀀ⱠiⱠÀ𐀀ⱠⱠiÀi𐀀ÀiÀⱠⱠÀ𐀀𐀀iiÀⱠ𐀀ⱠⱠi𐀀𐀀ÀⱠÀiⱠⱠiÀÀ𐀀iÀÀÀ𐀀𐀀ÀⱠii𐀀ÀiiÀⱠÀⱠÀi𐀀𐀀iⱠ|
  iÀ𐀀ⱠÀi𐀀iⱠⱠii𐀀ⱠÀ𐀀Ài𐀀𐀀iⱠ𐀀iÀi𐀀À𐀀iÀÀiÀ𐀀ÀÀiiiÀⱠⱠi𐀀ⱠiiiⱠi𐀀iÀÀ𐀀𐀀ⱠⱠⱠÀiiⱠÀⱠÀⱠiⱠi𐀀ⱠÀÀ𐀀Ⱡ𐀀i𐀀ⱠÀÀ𐀀iÀ𐀀Ⱡ𐀀iÀ𐀀Ⱡ𐀀ⱠÀⱠÀÀ𐀀|
  ⱠÀ𐀀𐀀ÀiÀiⱠiⱠⱠi𐀀𐀀𐀀ÀⱠⱠi𐀀À𐀀i𐀀𐀀𐀀𐀀iiÀÀÀÀ𐀀Ⱡ𐀀ii𐀀i𐀀iÀi𐀀ⱠⱠ𐀀iÀ𐀀𐀀𐀀ⱠⱠⱠ𐀀𐀀𐀀𐀀i𐀀𐀀ⱠiⱠ𐀀i𐀀iⱠi𐀀i𐀀ÀⱠ𐀀iⱠⱠⱠ𐀀À𐀀𐀀iiⱠi𐀀ÀÀÀiii^𐀀 |
                                                                                                      |
      ]=],
      value = { col = 100, curscol = 100, endcol = 100, row = 50 },
    },
  },
  {
    ascii_results,
    two_byte_results,
    three_byte_results,
    { -- random
      screen = [=[
  Ⱡ𐀀ii𐀀ⱠÀ𐀀i𐀀𐀀iÀÀÀiÀ𐀀Ⱡ𐀀ⱠiiⱠ𐀀iii𐀀ÀⱠÀⱠⱠÀiiÀⱠÀiⱠi𐀀ÀÀ𐀀𐀀Ⱡ𐀀𐀀Ⱡ𐀀iÀⱠ𐀀i𐀀ÀÀⱠiiÀ𐀀Ⱡ𐀀À𐀀ii𐀀ÀÀ𐀀ÀⱠⱠ𐀀𐀀𐀀𐀀ii𐀀ⱠⱠiⱠⱠ𐀀ⱠÀ𐀀ÀÀiiⱠ|
  𐀀𐀀ÀⱠÀ𐀀𐀀iⱠÀ𐀀𐀀i𐀀𐀀𐀀𐀀ⱠⱠⱠiiiiÀÀ𐀀ⱠÀⱠÀi𐀀i𐀀ⱠⱠÀiÀⱠi𐀀𐀀À𐀀iÀ𐀀ÀÀÀ𐀀𐀀iÀⱠ𐀀𐀀Ⱡ𐀀𐀀ÀiⱠiiⱠⱠÀÀÀÀi𐀀ÀÀⱠ𐀀Àiii𐀀iⱠⱠⱠi𐀀ⱠÀi𐀀iⱠ𐀀ⱠiⱠ|
  iiⱠ𐀀iÀÀiⱠⱠÀi𐀀ⱠⱠÀ𐀀𐀀ÀiiiiÀiⱠ𐀀iⱠÀiⱠiⱠⱠÀiÀ𐀀ⱠiiⱠⱠÀ𐀀Àii𐀀ⱠÀⱠiⱠÀⱠÀⱠii𐀀Ài𐀀ⱠⱠ𐀀ÀÀÀi𐀀ÀÀÀ𐀀iⱠ𐀀iⱠÀ𐀀iⱠi𐀀ÀiÀ𐀀ⱠⱠiÀ𐀀𐀀Ⱡi|
  À𐀀𐀀iÀiÀÀÀÀⱠⱠⱠ𐀀iÀÀiⱠ𐀀À𐀀ⱠÀiiⱠ𐀀iiⱠⱠ𐀀iÀiⱠⱠÀⱠÀ𐀀Ài𐀀iⱠ𐀀𐀀iiⱠÀⱠiÀÀÀiÀiiÀ𐀀i𐀀ÀÀⱠ𐀀𐀀𐀀i𐀀𐀀ⱠⱠi𐀀À𐀀iⱠi𐀀ⱠⱠiiiÀⱠ𐀀ⱠÀiÀiⱠⱠ|
  iÀiiiⱠÀÀ𐀀ⱠⱠⱠi𐀀À𐀀𐀀iiiÀÀiiÀⱠÀ𐀀À𐀀ⱠⱠ𐀀𐀀ⱠⱠⱠi𐀀iiÀⱠ𐀀ⱠⱠⱠÀiⱠiⱠiÀÀÀi𐀀iⱠ𐀀ÀÀiⱠ𐀀iÀÀi𐀀i𐀀𐀀ÀiÀⱠ𐀀𐀀iⱠ𐀀ÀÀiÀÀⱠ𐀀𐀀ⱠⱠ𐀀𐀀𐀀𐀀Ⱡ𐀀𐀀|
  𐀀ÀÀⱠÀ𐀀ÀÀiÀÀÀⱠiiⱠiiÀⱠÀiⱠÀiÀiⱠⱠ𐀀ÀÀÀⱠiiÀⱠ𐀀iÀi𐀀ⱠⱠ𐀀𐀀ÀÀ𐀀ÀiÀÀⱠi𐀀iÀⱠ𐀀À𐀀ⱠⱠÀ𐀀Ⱡiii𐀀ⱠiiⱠiÀⱠⱠiⱠÀⱠ𐀀ⱠÀÀⱠ𐀀À𐀀ÀiÀÀⱠⱠÀÀ|
  ÀⱠiⱠiÀ𐀀i𐀀ⱠⱠiⱠⱠÀ𐀀ÀÀÀÀ𐀀𐀀ÀⱠⱠ𐀀ⱠÀÀiⱠ𐀀i𐀀Ⱡ𐀀ÀⱠi𐀀ⱠÀⱠÀ𐀀ⱠⱠ𐀀i𐀀iⱠÀi𐀀i𐀀𐀀À𐀀iÀiⱠⱠⱠ𐀀ÀiÀⱠÀ𐀀ÀÀÀi𐀀𐀀𐀀ⱠÀi𐀀𐀀À𐀀À𐀀𐀀iiⱠiÀi𐀀i𐀀Ⱡ|
  𐀀𐀀i𐀀ÀⱠⱠ𐀀𐀀𐀀iⱠⱠ𐀀À𐀀ÀⱠiÀ𐀀𐀀ⱠÀi𐀀𐀀iiiⱠ𐀀𐀀iⱠÀÀ𐀀ⱠiiÀⱠⱠÀ𐀀𐀀ⱠÀⱠⱠÀiⱠⱠÀⱠÀⱠiⱠⱠ𐀀𐀀𐀀iⱠⱠⱠiⱠⱠii𐀀ÀⱠi𐀀ÀÀⱠⱠi𐀀À𐀀Ⱡ𐀀ÀÀ𐀀Ⱡ𐀀iⱠiiⱠⱠ|
  Ⱡ𐀀i𐀀𐀀ÀiÀⱠⱠⱠⱠⱠÀÀⱠⱠÀⱠ𐀀ii𐀀ÀⱠiⱠiii𐀀i𐀀i𐀀𐀀𐀀À𐀀ii𐀀iÀiiiÀÀⱠiiiⱠiiⱠÀ𐀀À𐀀𐀀ÀⱠ𐀀iÀÀiiÀiÀ𐀀iⱠi𐀀𐀀À𐀀ÀiiⱠ𐀀iÀ𐀀𐀀iⱠⱠÀÀⱠⱠiiÀ|
  i𐀀𐀀𐀀ÀÀi𐀀ⱠⱠⱠⱠⱠÀiiÀ𐀀𐀀ii𐀀Ⱡ𐀀Ài𐀀iⱠiÀÀⱠÀ𐀀ÀⱠiⱠÀi𐀀𐀀iiⱠ𐀀i𐀀ⱠÀiⱠii𐀀𐀀À𐀀𐀀ⱠⱠÀⱠiÀiⱠÀÀi𐀀i𐀀ⱠÀiⱠⱠⱠ𐀀𐀀ÀiⱠⱠⱠÀÀi𐀀ÀⱠⱠÀiⱠ𐀀ⱠÀ|
  𐀀ÀiⱠⱠÀ𐀀𐀀𐀀i𐀀i𐀀i𐀀ⱠÀ𐀀ÀiiÀⱠ𐀀ÀÀÀi𐀀ⱠÀiÀⱠi𐀀ⱠÀiiÀÀÀiiiÀiⱠⱠiÀ𐀀ⱠⱠ𐀀iÀⱠÀⱠⱠiÀÀⱠÀⱠÀÀii𐀀Ⱡi𐀀iiÀÀÀiⱠ𐀀i𐀀𐀀i𐀀iiÀ𐀀𐀀𐀀ⱠÀiⱠ𐀀|
  À𐀀ⱠⱠⱠⱠ𐀀ÀiⱠⱠiÀ𐀀i𐀀ÀⱠÀⱠiiÀiÀÀiⱠ𐀀𐀀𐀀Ⱡ𐀀ÀⱠi𐀀𐀀iⱠⱠⱠiiⱠÀi𐀀𐀀𐀀iⱠÀÀÀⱠi𐀀À𐀀iiiⱠÀⱠiÀ𐀀iⱠ𐀀ii𐀀𐀀𐀀ÀⱠⱠÀÀⱠⱠⱠⱠiÀi𐀀Àiii𐀀ii𐀀𐀀À|
  i𐀀ÀⱠiⱠi𐀀ⱠiⱠ𐀀Ⱡi𐀀ⱠÀ𐀀𐀀𐀀ⱠÀiiiii𐀀Ⱡ𐀀iiiÀiiÀ𐀀𐀀𐀀À𐀀𐀀Ⱡ𐀀ⱠÀ𐀀ⱠⱠⱠiÀÀÀÀii𐀀i𐀀ÀiiⱠÀiÀ𐀀iⱠⱠiÀⱠii𐀀i𐀀Ⱡ𐀀𐀀iⱠⱠÀ𐀀ⱠiiiⱠⱠÀÀ𐀀iÀⱠ|
  𐀀iii𐀀ÀⱠiⱠÀ𐀀𐀀i𐀀ÀⱠ𐀀𐀀ⱠⱠÀiⱠ𐀀𐀀iⱠ𐀀ⱠiiⱠiiⱠÀ𐀀𐀀ⱠiÀÀⱠÀiÀⱠ𐀀ÀⱠ𐀀ⱠÀi𐀀Ⱡi𐀀𐀀𐀀𐀀𐀀À𐀀𐀀𐀀i𐀀iÀ𐀀À𐀀ÀÀÀ𐀀ⱠⱠ𐀀iiÀ𐀀ÀÀÀⱠÀ𐀀ⱠÀⱠÀiÀiiÀⱠ|
  Ⱡ𐀀𐀀ⱠⱠ𐀀À𐀀ÀⱠ𐀀ÀⱠÀ𐀀𐀀iⱠⱠÀÀiÀⱠ𐀀ÀiÀⱠi𐀀ⱠÀ𐀀𐀀𐀀𐀀Ⱡ𐀀iⱠÀ𐀀iÀ𐀀iÀ𐀀iÀÀⱠi𐀀iÀⱠi𐀀ⱠiiⱠÀ𐀀À𐀀ⱠⱠÀÀi𐀀ⱠⱠ𐀀iiⱠÀiⱠ𐀀𐀀𐀀𐀀ⱠⱠⱠÀⱠiÀⱠiÀÀ𐀀À|
  ÀⱠ𐀀iiiÀÀ𐀀ÀⱠiⱠ𐀀ⱠⱠⱠ𐀀iÀ𐀀ⱠiⱠ𐀀i𐀀ÀÀiⱠ𐀀ÀiiⱠⱠiÀÀ𐀀ÀiⱠiÀ𐀀i𐀀ÀiÀ𐀀ÀⱠiÀiⱠⱠi𐀀iⱠÀiÀÀⱠⱠiÀiⱠÀⱠi𐀀𐀀ⱠiÀⱠii𐀀ⱠiiⱠi𐀀Ⱡi𐀀ÀiÀÀ𐀀|
  ÀⱠÀÀ𐀀i𐀀iⱠÀÀÀⱠ𐀀𐀀ÀⱠÀÀiii𐀀𐀀iiÀiiⱠÀÀⱠiÀiÀÀ𐀀i𐀀i𐀀ⱠiⱠⱠiⱠÀiiÀⱠ𐀀ⱠⱠÀiÀⱠ𐀀𐀀iÀ𐀀Ⱡ𐀀iÀ𐀀ⱠÀÀⱠÀÀÀ𐀀𐀀i𐀀𐀀À𐀀𐀀ii𐀀À𐀀𐀀ⱠÀ𐀀ⱠⱠⱠ𐀀𐀀|
  Ⱡ𐀀i𐀀𐀀i𐀀𐀀Ⱡ𐀀iÀ𐀀ÀiⱠiiÀÀiÀÀÀiÀiiⱠⱠ𐀀iⱠiÀi𐀀Ⱡ𐀀ⱠÀ𐀀Ⱡ𐀀𐀀𐀀ⱠÀⱠ𐀀ⱠiiⱠiiiⱠÀÀiÀ𐀀ÀÀ𐀀ÀⱠÀ𐀀iiÀÀiÀiÀÀÀⱠⱠÀÀii𐀀ⱠÀÀiⱠiÀÀ𐀀iiiÀ|
  ÀÀÀÀiⱠiⱠⱠⱠiⱠ𐀀ⱠÀÀÀ𐀀ÀÀiⱠÀ𐀀ÀiⱠÀⱠÀⱠⱠÀÀⱠiÀⱠⱠiiⱠÀ𐀀ⱠⱠÀiⱠ𐀀iÀⱠ𐀀Ⱡ𐀀Ⱡ𐀀iⱠÀⱠi𐀀𐀀Ⱡ𐀀iÀ𐀀ÀⱠ𐀀ÀÀⱠ𐀀Ⱡi𐀀iⱠÀ𐀀𐀀𐀀𐀀i𐀀i𐀀𐀀𐀀ÀⱠiÀÀ𐀀i|
  i𐀀iÀ𐀀i𐀀iⱠⱠⱠÀÀiiiⱠi𐀀iÀÀ𐀀iⱠÀÀ𐀀ii𐀀i𐀀𐀀ÀÀÀÀiÀiiÀiiiÀiÀi𐀀𐀀ⱠⱠÀⱠⱠÀiÀÀⱠiⱠⱠiÀⱠÀiⱠⱠ𐀀ⱠⱠⱠÀⱠÀⱠ𐀀iiⱠⱠⱠ𐀀iÀ𐀀iⱠ𐀀iÀiÀiÀi|
  𐀀𐀀iiÀ𐀀ÀⱠ𐀀𐀀𐀀𐀀𐀀Àiii𐀀𐀀𐀀Ⱡ𐀀𐀀i𐀀ÀÀ𐀀iiÀiiiiÀ𐀀iⱠiⱠiÀⱠÀⱠÀiⱠⱠⱠⱠⱠⱠⱠⱠⱠÀiiⱠiÀⱠÀ𐀀iiⱠÀⱠiⱠⱠÀiⱠ𐀀iⱠ𐀀iiⱠÀ𐀀𐀀Àii𐀀i𐀀ÀⱠÀÀiÀÀ|
  Ⱡ𐀀iÀiÀÀÀÀⱠi𐀀ⱠⱠi𐀀ⱠⱠⱠ𐀀ⱠⱠ𐀀iÀÀÀiÀi𐀀Ài𐀀𐀀𐀀ⱠÀiⱠiⱠ𐀀𐀀Àiii𐀀ÀÀiⱠÀiⱠ𐀀𐀀i𐀀ÀÀiiÀiⱠⱠi𐀀À𐀀ÀⱠÀⱠiiiiii𐀀Ⱡ𐀀ÀⱠ𐀀ⱠⱠⱠ𐀀𐀀iⱠⱠⱠⱠiÀ|
  𐀀𐀀𐀀i𐀀iÀ𐀀𐀀iÀ𐀀Ài𐀀𐀀ⱠⱠ𐀀ⱠÀi𐀀𐀀ÀÀiiiⱠiⱠ𐀀iⱠÀⱠÀ𐀀ⱠÀ𐀀ⱠiiiiÀiⱠÀiiiⱠⱠÀ𐀀Ⱡ𐀀𐀀𐀀ÀⱠiÀⱠiiiiⱠiⱠ𐀀Ⱡ𐀀ÀⱠÀii𐀀i𐀀Ⱡ𐀀À𐀀iⱠⱠ𐀀iⱠiiii𐀀|
  ÀÀÀⱠⱠÀ𐀀À𐀀À𐀀iⱠ𐀀𐀀𐀀À𐀀ⱠⱠ𐀀ÀiÀiÀi𐀀Ⱡ𐀀iiⱠiiÀⱠÀⱠ𐀀ⱠÀi𐀀𐀀iÀiÀⱠi𐀀À𐀀𐀀ÀⱠ𐀀𐀀iⱠÀ𐀀Ⱡ𐀀ÀiÀÀⱠÀiÀ𐀀ⱠⱠⱠiiÀi𐀀ÀⱠiÀÀÀiⱠⱠiÀÀiÀⱠÀⱠÀ|
  iⱠÀÀⱠÀÀ𐀀𐀀𐀀iiiÀ𐀀À𐀀iÀÀi𐀀À𐀀ÀⱠÀiÀii𐀀ⱠⱠii𐀀ⱠⱠ𐀀𐀀ÀⱠ𐀀ÀÀ𐀀ÀÀÀÀi𐀀ÀⱠ𐀀À𐀀ÀiiⱠ𐀀ÀÀⱠiⱠ𐀀Ⱡ𐀀ÀÀ𐀀ⱠⱠ𐀀ⱠⱠÀ𐀀ⱠⱠⱠ𐀀iiÀⱠÀⱠiⱠi𐀀ii𐀀Ài|
  ÀiÀⱠ𐀀À𐀀𐀀ii𐀀𐀀ⱠⱠiiiiⱠiÀiⱠiÀiÀ𐀀ÀiⱠÀiiÀÀÀ𐀀𐀀Ⱡ𐀀ⱠⱠ𐀀iÀiⱠ𐀀ii𐀀ⱠÀ𐀀ⱠiⱠÀiiⱠÀⱠ𐀀Ài𐀀Àii𐀀iiÀiⱠÀiⱠⱠÀiÀ𐀀i𐀀ⱠÀ𐀀iÀÀⱠii𐀀iÀ𐀀|
  Ⱡ𐀀ⱠÀ𐀀Ⱡi𐀀iÀ𐀀Ⱡ𐀀𐀀iÀiÀ𐀀iⱠi𐀀ⱠÀiⱠⱠiÀ𐀀iⱠiÀⱠi𐀀𐀀iⱠiⱠⱠ𐀀ÀÀi𐀀iÀⱠⱠ𐀀ⱠÀ𐀀𐀀𐀀ⱠⱠiÀÀiⱠⱠⱠ𐀀𐀀ⱠⱠⱠⱠÀiⱠ𐀀Ài𐀀iÀⱠii𐀀ÀⱠii𐀀Ⱡ𐀀ÀⱠÀ𐀀Ⱡi|
  À𐀀iⱠⱠiⱠi𐀀iⱠii𐀀Ⱡi𐀀ii𐀀iⱠÀ𐀀ⱠÀÀi𐀀iÀ𐀀iÀ𐀀ⱠÀⱠiⱠÀⱠi𐀀Ⱡ𐀀ÀⱠⱠiⱠ𐀀iⱠiÀ𐀀À𐀀ÀⱠi𐀀𐀀iÀi𐀀À𐀀Ⱡ𐀀ⱠⱠi𐀀𐀀𐀀iⱠÀ𐀀ÀⱠÀ𐀀i𐀀i𐀀iÀⱠÀÀÀ𐀀iⱠ𐀀|
  𐀀ⱠⱠⱠⱠⱠ𐀀Ⱡ𐀀ÀÀ𐀀𐀀iÀÀⱠiÀiiⱠÀiⱠ𐀀𐀀ÀÀiÀⱠ𐀀ÀÀⱠ𐀀À𐀀À𐀀iⱠⱠÀiⱠÀiiiⱠÀiÀÀÀ𐀀iⱠⱠⱠÀÀiⱠⱠⱠ𐀀ii𐀀ii𐀀iⱠⱠii𐀀iⱠÀi𐀀𐀀𐀀ii𐀀ÀⱠⱠiⱠÀ𐀀ⱠⱠ|
  𐀀iiⱠi𐀀ÀⱠ𐀀ÀiⱠÀÀiÀÀÀÀⱠ𐀀ÀiiⱠi𐀀iⱠi𐀀ÀⱠÀ𐀀𐀀𐀀iÀiÀ𐀀ⱠiÀ𐀀ⱠⱠÀÀi𐀀Ⱡ𐀀i𐀀ⱠÀⱠiⱠiⱠiii𐀀ÀⱠⱠ𐀀𐀀ÀⱠ𐀀𐀀ii𐀀ÀiiÀÀⱠiÀ𐀀ÀÀÀiÀⱠÀ𐀀Ài𐀀Ⱡ|
  𐀀iⱠ𐀀ⱠⱠⱠÀÀ𐀀iiiÀÀⱠii𐀀i𐀀ÀÀⱠ𐀀ⱠⱠiⱠⱠⱠiⱠ𐀀i𐀀À𐀀ⱠⱠⱠi𐀀Ài𐀀ⱠÀ𐀀ÀⱠiiiiⱠiiⱠⱠi𐀀𐀀ÀⱠ𐀀ⱠiÀÀ𐀀iiiⱠÀiⱠi𐀀À𐀀𐀀i𐀀𐀀iiⱠ𐀀À𐀀iiⱠⱠÀ𐀀iⱠ|
  ÀⱠ𐀀ⱠⱠⱠÀii𐀀iiⱠⱠ𐀀iⱠ𐀀iiⱠii𐀀𐀀𐀀iiⱠiÀ𐀀ⱠⱠÀÀÀiⱠⱠ𐀀À𐀀ⱠⱠⱠ𐀀ÀiⱠ𐀀ÀiⱠ𐀀i𐀀ÀÀ𐀀Ⱡ𐀀Ⱡ𐀀iÀ𐀀iiiÀⱠiÀⱠiÀⱠⱠÀⱠii𐀀ⱠⱠⱠÀii𐀀i𐀀iiⱠiÀ𐀀𐀀|
  ⱠⱠÀÀⱠⱠ𐀀iÀⱠ𐀀iⱠⱠÀÀ𐀀ÀiⱠ𐀀iÀⱠⱠⱠ𐀀𐀀À𐀀ii𐀀𐀀À𐀀𐀀ÀⱠⱠⱠÀⱠiiⱠ𐀀𐀀ii𐀀ⱠⱠÀⱠiⱠi𐀀ⱠⱠ𐀀i𐀀𐀀𐀀𐀀Ⱡ𐀀iÀiⱠⱠ𐀀À𐀀ÀⱠⱠⱠÀÀ𐀀𐀀iÀⱠi𐀀𐀀ÀiⱠⱠÀÀiÀÀ|
  ÀiⱠii𐀀ÀÀⱠi𐀀ÀⱠi𐀀À𐀀ii𐀀iⱠi𐀀ÀⱠ𐀀À𐀀ÀÀⱠⱠ𐀀i𐀀ⱠiiⱠ𐀀ÀÀ𐀀À𐀀i𐀀𐀀i𐀀Ⱡ𐀀Ⱡi𐀀𐀀𐀀i𐀀Ài𐀀𐀀ÀⱠⱠi𐀀ÀiÀⱠÀiiiÀÀⱠⱠi𐀀ÀiÀiⱠÀÀiÀ𐀀𐀀ÀiiiiÀ|
  𐀀ⱠÀiÀ𐀀ⱠⱠ𐀀i𐀀ⱠⱠ𐀀𐀀𐀀𐀀𐀀𐀀iⱠÀⱠⱠiiÀⱠ𐀀𐀀i𐀀ⱠⱠ𐀀ⱠⱠⱠ𐀀𐀀iÀiÀⱠ𐀀À𐀀À𐀀𐀀ⱠiiiⱠiiiⱠiⱠ𐀀ÀiiiⱠ𐀀À𐀀ÀⱠⱠÀ𐀀À𐀀𐀀𐀀ⱠiⱠi𐀀ⱠÀÀⱠiiⱠⱠⱠⱠ𐀀ÀⱠ𐀀𐀀|
  Ⱡ𐀀ⱠⱠÀ𐀀iⱠ𐀀ⱠiiⱠi𐀀ÀⱠⱠ𐀀iÀiÀÀiⱠi𐀀iiÀ𐀀ⱠⱠⱠiÀⱠ𐀀ⱠⱠⱠÀ𐀀ⱠiⱠ𐀀𐀀ÀⱠÀÀ𐀀ÀⱠⱠiⱠ𐀀𐀀iiÀÀ𐀀À𐀀iⱠiÀ𐀀iÀ𐀀𐀀iiiiii𐀀ÀiⱠ𐀀𐀀i𐀀Ài𐀀À𐀀𐀀i𐀀Ⱡ|
  Ⱡ𐀀iÀÀⱠ𐀀ⱠⱠÀⱠÀ𐀀ⱠⱠÀiiÀÀÀⱠ𐀀i𐀀Ⱡ𐀀ⱠÀ𐀀𐀀iⱠⱠⱠⱠiiⱠⱠⱠÀiⱠÀiiⱠÀ𐀀Ⱡ𐀀Ⱡi𐀀𐀀ⱠÀ𐀀ÀⱠⱠ𐀀ÀⱠÀⱠ𐀀Ⱡ𐀀iⱠi𐀀ÀⱠⱠii𐀀ÀⱠÀ𐀀Ⱡ𐀀Ài𐀀À𐀀ÀÀⱠiⱠⱠii𐀀|
  ⱠÀⱠⱠⱠiⱠ𐀀Ⱡ𐀀Ⱡ𐀀ⱠiiⱠÀ𐀀ÀiiÀi𐀀iÀÀiiiiÀⱠÀⱠÀⱠiiⱠ𐀀𐀀ⱠÀÀ𐀀𐀀À𐀀ÀⱠⱠ𐀀𐀀iii𐀀iiÀ𐀀ⱠiⱠⱠÀ𐀀ÀÀii𐀀ⱠÀⱠi𐀀𐀀Ⱡi𐀀ÀⱠⱠ𐀀ÀÀÀ𐀀iÀⱠⱠ𐀀ÀÀi𐀀i|
  ÀⱠⱠⱠÀⱠⱠii𐀀Ài𐀀Ⱡi𐀀i𐀀i𐀀Ⱡ𐀀ÀÀÀiÀÀi𐀀ÀÀÀ𐀀i𐀀iÀ𐀀𐀀ⱠiÀi𐀀𐀀𐀀ⱠÀiÀ𐀀𐀀iÀÀⱠⱠ𐀀ⱠⱠⱠⱠÀÀÀÀiiÀ𐀀iiⱠⱠⱠi𐀀ⱠÀi𐀀ÀⱠⱠÀ𐀀ⱠiiⱠ𐀀𐀀i𐀀Ⱡi𐀀𐀀À|
  𐀀À𐀀Ⱡ𐀀𐀀iÀÀiⱠiiÀⱠÀiÀⱠÀⱠⱠ𐀀iⱠⱠÀiⱠⱠⱠⱠ𐀀iⱠÀÀⱠⱠiⱠ𐀀ÀiⱠⱠi𐀀𐀀ⱠiÀ𐀀ÀiÀi𐀀i𐀀Ⱡi𐀀ⱠÀiiÀⱠÀi𐀀Ài𐀀ÀÀÀi𐀀𐀀ÀⱠi𐀀ⱠiⱠÀiÀiⱠ𐀀ii𐀀𐀀𐀀À|
  ÀⱠiiÀi𐀀ⱠÀÀiÀⱠi𐀀ÀⱠⱠ𐀀ⱠiÀiiⱠiiⱠⱠ𐀀ii𐀀i𐀀𐀀𐀀𐀀i𐀀ⱠⱠÀⱠÀÀiÀÀÀⱠÀⱠⱠÀÀⱠ𐀀ÀÀ𐀀ÀÀⱠÀ𐀀𐀀ÀiⱠ𐀀ⱠⱠ𐀀iÀ𐀀Ⱡ𐀀iÀⱠⱠ𐀀iÀiiii𐀀ii𐀀𐀀ⱠⱠⱠ𐀀Ⱡ|
  ⱠÀ𐀀ⱠⱠÀÀiⱠⱠ𐀀iⱠⱠⱠÀⱠ𐀀ⱠⱠ𐀀iⱠ𐀀𐀀𐀀𐀀ⱠiÀ𐀀ⱠⱠÀ𐀀Ⱡ𐀀ÀÀii𐀀Ⱡ𐀀ÀÀ𐀀ÀÀⱠ𐀀ⱠÀiÀ𐀀𐀀À𐀀À𐀀𐀀iⱠi𐀀ÀⱠⱠⱠⱠ𐀀ⱠⱠÀÀ𐀀𐀀𐀀ÀÀiiⱠÀÀ𐀀ⱠⱠⱠiÀⱠÀⱠⱠiÀⱠ𐀀|
  𐀀ÀiÀⱠÀiiÀÀiiⱠⱠⱠi𐀀ÀÀiⱠ𐀀iⱠⱠÀ𐀀𐀀𐀀ÀⱠⱠÀ𐀀ⱠÀÀⱠ𐀀ÀÀ𐀀𐀀Ⱡ𐀀ÀÀ𐀀ÀⱠ𐀀ⱠÀiÀ𐀀iⱠ𐀀ⱠⱠ𐀀𐀀À𐀀iii𐀀iiⱠÀⱠiⱠÀⱠ𐀀Ⱡ𐀀i𐀀𐀀ÀⱠⱠi𐀀𐀀ⱠⱠ𐀀𐀀𐀀𐀀À𐀀Ⱡ𐀀|
  Àiiiii𐀀iⱠÀÀÀiiⱠiii𐀀𐀀ÀiÀⱠÀÀiⱠⱠ𐀀iiÀÀⱠ𐀀ⱠiÀⱠ𐀀𐀀ii𐀀iⱠÀ𐀀iiⱠ𐀀Ⱡ𐀀𐀀i𐀀Ⱡ𐀀i𐀀𐀀𐀀ÀⱠiⱠiⱠi𐀀iiiÀii𐀀𐀀Àii𐀀À𐀀Ⱡ𐀀𐀀Ⱡ𐀀i𐀀ⱠÀⱠii𐀀Ⱡ|
  𐀀iiÀⱠiⱠiÀⱠ𐀀i𐀀iii𐀀Ⱡ𐀀i𐀀iÀÀi𐀀Ⱡii𐀀ÀiÀiiiÀⱠÀ𐀀ÀÀⱠ𐀀Ⱡ𐀀iiÀi𐀀i𐀀𐀀i𐀀ⱠiiiÀⱠⱠⱠiiÀ𐀀À𐀀𐀀iÀ𐀀iⱠÀⱠÀÀi𐀀ⱠiÀⱠÀ𐀀𐀀iÀÀ𐀀i𐀀𐀀ÀÀⱠ𐀀|
  𐀀iⱠⱠÀ𐀀ÀⱠÀ𐀀iⱠ𐀀Àii𐀀i𐀀𐀀ÀÀi𐀀𐀀𐀀iiⱠÀ𐀀ii𐀀Ⱡ𐀀𐀀iⱠi𐀀iÀ𐀀À𐀀ⱠⱠ𐀀À𐀀i𐀀𐀀iⱠiiÀÀⱠⱠⱠiÀÀiÀÀ𐀀𐀀𐀀À𐀀𐀀𐀀ⱠÀⱠ𐀀iÀ𐀀𐀀Ⱡ𐀀ⱠⱠii𐀀𐀀ÀÀⱠÀi𐀀𐀀i|
  ÀiÀⱠⱠⱠⱠii𐀀ÀÀ𐀀𐀀𐀀Ⱡi𐀀À𐀀ÀⱠiiÀi𐀀Ⱡii𐀀iÀÀ𐀀ⱠiⱠ𐀀ⱠiiiⱠÀÀiÀÀÀÀ𐀀ⱠⱠii𐀀À𐀀ÀiÀi𐀀ÀÀi𐀀iⱠiÀi𐀀ÀiÀi𐀀ÀiÀⱠ𐀀i𐀀Ⱡi𐀀𐀀𐀀ⱠⱠ𐀀ⱠÀⱠÀⱠi|
  À𐀀𐀀i𐀀Ài𐀀𐀀ⱠiⱠÀⱠiiⱠiⱠÀ𐀀𐀀ÀiÀ𐀀𐀀ÀÀⱠⱠⱠ𐀀ⱠiÀⱠⱠÀ𐀀Ⱡi𐀀𐀀ÀiÀ𐀀À𐀀iⱠi𐀀𐀀ÀÀ𐀀iⱠiⱠⱠ𐀀ÀÀ𐀀𐀀ÀiÀÀ𐀀ÀÀ𐀀i𐀀ÀÀ𐀀𐀀ÀÀⱠii𐀀Ⱡ𐀀Ⱡ𐀀iiÀÀÀi𐀀À|
  i𐀀ⱠiÀⱠⱠÀÀ𐀀𐀀ii𐀀ÀÀ𐀀iÀiÀⱠÀiiii𐀀ÀiÀⱠi𐀀i𐀀𐀀i𐀀𐀀iⱠ𐀀iÀi𐀀ÀÀÀÀiⱠiÀⱠÀÀⱠiiÀÀⱠⱠi𐀀iⱠiiⱠi𐀀Ⱡ𐀀𐀀ÀⱠⱠÀⱠiⱠⱠÀ𐀀iiÀⱠⱠⱠ𐀀𐀀Ⱡi𐀀Ⱡi|
  ⱠÀⱠ𐀀ÀⱠ𐀀iⱠÀ𐀀ⱠiⱠii𐀀ÀⱠÀÀ𐀀i𐀀Ⱡi𐀀ⱠiÀ𐀀ⱠÀÀÀiÀÀÀⱠ𐀀𐀀ⱠiiⱠ𐀀ÀⱠiiÀiiⱠⱠi𐀀ÀiiⱠ𐀀iÀⱠÀi𐀀À𐀀ÀiÀÀÀi𐀀ÀÀⱠⱠiÀiⱠ𐀀ii𐀀ⱠÀiⱠÀⱠⱠi^i |
                                                                                                      |
      ]=],
      value = { col = 100, curscol = 100, endcol = 100, row = 50 },
    },
  },
})
