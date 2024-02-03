local helpers = require('test.functional.testunit')(after_each)
local api = helpers.api
local Screen = require('test.functional.ui.screen')

local function rand_utf8(count, seed)
  math.randomseed(seed)
  local symbols = { 'i', 'À', 'Ⴀ', '𐀀' }
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

  local results = helpers.exec_lua(
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
    helpers.eq(expected_value, value)
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
    before_each(helpers.clear)

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
          helpers.feed('G$')
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
          helpers.command('set breakindent')
          -- for smaller screen expect (last line always different, first line same as others)
          helpers.feed('G$')
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

benchmarks({
  {
    ascii_results,
    two_byte_results,
    { -- random
      screen = [=[
  Ⴀ𐀀ii𐀀ႠÀ𐀀i𐀀𐀀iÀÀÀiÀ𐀀Ⴀ𐀀ႠiiႠ𐀀iii𐀀ÀႠÀႠႠÀiiÀႠÀiႠi𐀀ÀÀ𐀀𐀀Ⴀ𐀀𐀀Ⴀ𐀀iÀႠ𐀀i𐀀ÀÀႠiiÀ𐀀Ⴀ𐀀À𐀀ii𐀀ÀÀ𐀀ÀႠႠ𐀀𐀀𐀀𐀀ii𐀀ႠႠiႠႠ𐀀ႠÀ𐀀ÀÀiiႠ|
  𐀀𐀀ÀႠÀ𐀀𐀀iႠÀ𐀀𐀀i𐀀𐀀𐀀𐀀ႠႠႠiiiiÀÀ𐀀ႠÀႠÀi𐀀i𐀀ႠႠÀiÀႠi𐀀𐀀À𐀀iÀ𐀀ÀÀÀ𐀀𐀀iÀႠ𐀀𐀀Ⴀ𐀀𐀀ÀiႠiiႠႠÀÀÀÀi𐀀ÀÀႠ𐀀Àiii𐀀iႠႠႠi𐀀ႠÀi𐀀iႠ𐀀ႠiႠ|
  ႠႠႠÀi𐀀ÀiႠÀiႠiႠ𐀀ÀiiiÀiiÀÀႠ𐀀À𐀀ÀႠÀÀÀႠ𐀀iႠႠ𐀀iႠÀ𐀀À𐀀ႠiÀÀÀÀiiÀiÀiÀႠiÀi𐀀iÀÀႠ𐀀𐀀ႠÀ𐀀iႠ𐀀i𐀀i𐀀ÀႠi𐀀iႠÀÀiiႠ𐀀𐀀ႠiÀiÀiiÀ|
  iႠ𐀀iiႠÀႠ𐀀iÀÀÀႠÀiÀ𐀀𐀀𐀀ÀႠiႠiÀiႠiႠ𐀀𐀀ႠႠi𐀀ႠႠ𐀀𐀀Ⴀ𐀀ÀiiႠÀႠႠ𐀀iÀiÀÀ𐀀𐀀𐀀ႠႠ𐀀iii𐀀À𐀀Ⴀ𐀀iႠii𐀀i𐀀i𐀀ÀiÀi𐀀Ⴀ𐀀𐀀i𐀀iÀÀiႠ𐀀Ⴀ𐀀ÀÀÀÀ|
  𐀀ÀႠiÀႠÀÀÀႠ𐀀À𐀀𐀀𐀀i𐀀Ài𐀀𐀀iႠ𐀀𐀀ÀႠ𐀀𐀀À𐀀𐀀ႠÀÀႠႠႠiႠÀÀii𐀀Ⴀii𐀀Ⴀi𐀀Ài𐀀Ⴀ𐀀𐀀𐀀𐀀iÀ𐀀ႠÀiÀ𐀀ႠႠi𐀀i𐀀ႠႠÀႠ𐀀ႠÀႠ𐀀ÀႠiiႠ𐀀𐀀Ⴀ𐀀Ⴀ𐀀𐀀À𐀀𐀀Ài|
  iÀÀiÀÀiႠÀiiႠiÀiiiÀႠÀ𐀀Ài𐀀iiÀÀÀiႠႠiiႠ𐀀iÀ𐀀𐀀𐀀ႠÀÀ𐀀iiႠ𐀀Ⴀ𐀀ႠÀႠ𐀀Ài𐀀i𐀀ÀiÀႠႠ𐀀ÀႠiiႠÀ𐀀𐀀Ⴀii𐀀𐀀i𐀀𐀀ÀÀiÀ𐀀i𐀀𐀀i𐀀ÀiiiႠÀÀÀ|
  ÀÀႠႠÀႠႠÀiiiÀႠÀႠႠi𐀀ႠÀ𐀀iႠÀ𐀀ႠÀiiÀÀÀÀႠ𐀀𐀀À𐀀iiÀ𐀀𐀀iႠႠ𐀀iiႠႠ𐀀ÀÀÀ𐀀Ⴀ𐀀À𐀀ÀႠi𐀀ႠÀႠÀႠႠiÀ𐀀iÀÀႠ𐀀ႠႠ𐀀𐀀iႠႠႠ𐀀𐀀À𐀀iÀÀi𐀀iႠႠ𐀀𐀀|
  ÀÀiiႠÀ𐀀Ài𐀀iiÀ𐀀iÀႠÀÀi𐀀𐀀ႠႠ𐀀iiႠႠiÀ𐀀iႠÀÀiႠ𐀀ÀÀiiႠႠiÀÀ𐀀À𐀀iႠÀÀႠiႠ𐀀iႠ𐀀ÀiiႠÀÀႠÀÀiÀ𐀀𐀀ႠႠÀႠÀÀႠ𐀀À𐀀ႠႠi𐀀À𐀀𐀀ႠႠ𐀀iႠi𐀀Ⴀ|
  ÀÀႠ𐀀𐀀ÀႠႠႠÀႠiႠႠႠÀiiiႠiiiÀi𐀀𐀀iႠႠiiÀiႠႠႠÀÀiii𐀀ÀiႠÀi𐀀i𐀀𐀀ÀiÀiÀÀiÀ𐀀iÀÀÀiÀႠႠÀiÀ𐀀À𐀀iႠÀႠ𐀀ii𐀀𐀀iႠiÀiႠ𐀀Ⴀ𐀀Ⴀ𐀀𐀀ႠiÀႠ|
  ÀႠii𐀀i𐀀iÀÀÀÀÀ𐀀ÀiÀ𐀀𐀀ÀႠiiiiiÀႠ𐀀ÀÀÀႠi𐀀iႠiႠiÀႠႠ𐀀𐀀ii𐀀𐀀iÀÀÀႠiiÀ𐀀iÀiÀ𐀀Ⴀ𐀀Ⴀ𐀀i𐀀iÀႠiÀ𐀀i𐀀ႠiႠÀ𐀀iႠÀႠiႠiÀÀÀÀ𐀀Ⴀ𐀀iႠႠÀ|
  𐀀Ⴀ𐀀ႠÀ𐀀iႠiÀi𐀀i𐀀𐀀𐀀ႠÀႠiÀႠႠ𐀀ÀiÀiႠi𐀀ÀႠi𐀀𐀀ÀÀi𐀀À𐀀ÀiiႠ𐀀iႠÀÀÀiii𐀀ႠiႠ𐀀𐀀𐀀ႠႠiႠ𐀀𐀀iiႠiiiii𐀀𐀀𐀀𐀀𐀀ÀÀÀÀi𐀀𐀀ႠႠ𐀀iÀ𐀀ÀiiÀii|
  Ⴀ𐀀𐀀iႠi𐀀Ⴀ𐀀ႠႠiÀÀႠi𐀀ÀiႠႠႠ𐀀ÀႠiႠႠiႠႠÀ𐀀ႠiiiÀ𐀀𐀀𐀀ÀÀiႠi𐀀ႠÀ𐀀ÀႠÀi𐀀ႠiÀႠiiႠႠÀႠiÀÀႠÀÀÀÀ𐀀iÀႠႠiႠႠ𐀀ÀÀÀႠiÀÀiÀႠ𐀀iÀႠiiႠ𐀀|
  iÀႠi𐀀ÀႠÀÀÀiÀÀႠ𐀀À𐀀𐀀𐀀ႠiiiႠiiႠ𐀀À𐀀iii𐀀À𐀀ႠႠi𐀀iiႠÀ𐀀𐀀i𐀀ႠÀ𐀀𐀀i𐀀ÀiႠÀÀiÀÀi𐀀𐀀Ⴀ𐀀À𐀀i𐀀iÀႠႠႠ𐀀ÀÀÀႠÀÀႠႠႠႠႠi𐀀𐀀iiႠÀi𐀀𐀀ႠႠ|
  iiႠႠႠ𐀀ÀႠ𐀀Àiii𐀀ÀÀii𐀀À𐀀iiႠÀႠiiႠ𐀀Ⴀ𐀀ÀႠ𐀀iÀiႠiiÀÀiÀÀiႠiႠႠiႠ𐀀Ⴀi𐀀𐀀ÀÀÀÀiႠii𐀀ႠÀ𐀀Ⴀ𐀀i𐀀ႠiႠႠ𐀀i𐀀ႠiႠႠ𐀀ÀiႠ𐀀iÀi𐀀𐀀ÀÀ𐀀𐀀i|
  iÀÀi𐀀ÀÀÀ𐀀ÀႠ𐀀ÀÀÀ𐀀𐀀𐀀iiႠÀÀႠ𐀀ႠÀ𐀀iiiÀÀiiႠ𐀀𐀀ႠiiႠiÀiႠႠÀ𐀀ႠiႠÀ𐀀i𐀀𐀀𐀀ႠÀ𐀀Ⴀ𐀀ÀÀÀႠႠ𐀀𐀀À𐀀iiႠႠႠႠႠÀ𐀀𐀀iႠႠiiÀiႠÀiÀႠiÀ𐀀À𐀀i|
  ÀႠႠ𐀀ÀႠi𐀀i𐀀ႠÀÀÀiiiႠ𐀀ႠÀႠÀÀႠ𐀀ÀÀiÀiÀÀႠÀႠiႠiÀ𐀀iႠÀ𐀀𐀀𐀀ÀႠႠ𐀀ႠႠ𐀀ÀႠႠႠii𐀀ÀÀÀÀiÀi𐀀ႠႠÀiႠiႠÀႠ𐀀ÀiႠႠiÀႠi𐀀𐀀𐀀ÀÀiiÀÀ𐀀𐀀ÀႠ|
  À𐀀ÀÀÀÀ𐀀ÀÀ𐀀i𐀀ႠÀႠiႠÀÀ𐀀ႠiÀÀiႠÀႠႠÀ𐀀iÀ𐀀i𐀀𐀀ႠÀÀÀႠႠiÀiiiiႠႠi𐀀ÀႠi𐀀i𐀀i𐀀𐀀𐀀ႠÀႠiiiÀi𐀀ÀႠi𐀀iiÀÀႠÀÀႠiiÀ𐀀À𐀀ÀÀ𐀀ႠÀႠÀ𐀀iႠ|
  Ⴀ𐀀ÀiႠ𐀀iiÀ𐀀À𐀀𐀀À𐀀ÀÀiiiiiiႠႠiiÀi𐀀iÀ𐀀ÀÀiႠ𐀀ÀႠÀÀÀiÀႠႠ𐀀À𐀀𐀀iÀ𐀀𐀀ii𐀀ႠÀ𐀀ii𐀀𐀀iႠÀ𐀀ÀÀÀiÀii𐀀iႠ𐀀ႠႠ𐀀ÀႠiiiႠႠႠi𐀀ÀÀiÀ𐀀𐀀À|
  ႠiÀ𐀀ႠÀ𐀀iÀႠi𐀀ÀiiiÀÀ𐀀ÀႠ𐀀ႠႠႠÀႠ𐀀ႠÀiiÀi𐀀i𐀀𐀀iႠÀႠiႠiiÀÀ𐀀𐀀𐀀Ài𐀀𐀀iiႠiႠÀႠ𐀀iiႠÀi𐀀ႠႠႠi𐀀ÀÀiÀႠ𐀀𐀀ÀiႠÀiiÀÀႠ𐀀ႠiiÀႠႠÀiÀ|
  i𐀀𐀀Ài𐀀𐀀ႠÀiÀÀႠႠi𐀀𐀀ÀÀႠÀÀႠႠႠႠ𐀀ÀiႠiiႠႠÀiiiႠႠÀ𐀀Ⴀii𐀀i𐀀ႠÀ𐀀ÀÀႠႠiÀiÀÀiႠÀiiiiÀႠiiÀႠႠႠÀÀi𐀀À𐀀ႠႠ𐀀Ⴀi𐀀ႠႠ𐀀𐀀𐀀iႠÀÀႠ𐀀ႠႠ|
  iÀÀႠႠႠiiÀii𐀀𐀀ႠÀiii𐀀ႠÀ𐀀ႠiiÀ𐀀iႠ𐀀ÀႠ𐀀Ⴀ𐀀𐀀Ⴀi𐀀ÀiႠÀႠ𐀀ÀÀi𐀀ႠiÀÀÀÀႠÀႠiႠiႠႠ𐀀𐀀ÀႠÀႠ𐀀𐀀ÀÀ𐀀ႠႠ𐀀𐀀i𐀀Ⴀii𐀀iii𐀀Ⴀi𐀀Ⴀ𐀀Ⴀi𐀀𐀀ÀႠi|
  À𐀀𐀀ÀႠÀiiiÀiiÀႠi𐀀iiiႠiiႠÀÀ𐀀ႠÀ𐀀ႠႠႠ𐀀i𐀀ÀÀiႠiiiႠiiÀÀiႠ𐀀À𐀀i𐀀Ⴀ𐀀ႠÀiႠႠ𐀀ÀႠႠ𐀀𐀀ÀiႠÀÀႠiiႠi𐀀i𐀀ႠÀÀiႠ𐀀Ⴀ𐀀iႠႠ𐀀ÀÀÀiÀÀii|
  ႠÀ𐀀𐀀ႠiႠÀ𐀀ÀÀÀႠႠÀႠ𐀀ÀiႠii𐀀𐀀ÀႠ𐀀iÀÀiiÀiÀÀ𐀀iႠÀiÀ𐀀𐀀À𐀀Ⴀ𐀀𐀀iiႠႠ𐀀ႠÀႠÀiÀiÀ𐀀iႠႠiÀi𐀀Ⴀ𐀀iiiÀႠ𐀀ÀႠiÀiiiႠiiÀႠÀiႠiÀÀiႠÀi|
  𐀀𐀀ÀÀi𐀀À𐀀𐀀ÀႠႠႠ𐀀À𐀀𐀀À𐀀ÀiႠႠ𐀀𐀀ႠÀiႠiႠÀ𐀀ÀiႠiiii𐀀iႠiႠÀ𐀀ÀႠ𐀀𐀀iÀႠiÀi𐀀𐀀ႠÀiႠiÀႠႠ𐀀iႠ𐀀ÀႠÀii𐀀ႠÀႠii𐀀Ⴀ𐀀ÀÀi𐀀ÀÀiÀiÀႠ𐀀ÀႠႠ|
  𐀀iiii𐀀iႠÀÀႠiÀႠ𐀀ႠiÀiႠi𐀀iႠႠႠÀႠႠÀႠ𐀀iÀႠႠii𐀀iii𐀀À𐀀ႠႠႠÀiÀÀ𐀀iiiiႠႠႠi𐀀𐀀iiႠ𐀀ႠiႠ𐀀i𐀀𐀀ÀÀႠႠ𐀀iႠiႠÀÀÀႠႠÀ𐀀iÀႠႠႠႠÀ𐀀iÀ|
  ÀÀÀ𐀀ÀÀႠiႠÀiiÀÀ𐀀Ⴀ𐀀Àii𐀀ႠႠ𐀀iÀÀ𐀀𐀀Ⴀ𐀀iႠ𐀀iႠÀႠႠ𐀀ÀÀ𐀀𐀀À𐀀ÀႠiႠÀiÀ𐀀iÀi𐀀ႠiႠ𐀀i𐀀iiႠႠiႠÀÀ𐀀Ⴀ𐀀ႠႠ𐀀𐀀𐀀ႠႠiႠႠ𐀀ႠႠႠ𐀀ÀiႠႠi𐀀iÀÀÀ|
  ÀÀႠiiÀÀÀႠÀ𐀀𐀀iÀÀÀiÀi𐀀iႠiႠ𐀀iÀÀÀ𐀀𐀀𐀀iÀiÀÀiÀÀi𐀀i𐀀𐀀ႠÀ𐀀ii𐀀𐀀Ⴀ𐀀À𐀀iÀÀႠ𐀀iÀÀÀႠÀÀ𐀀𐀀iႠ𐀀ႠiÀႠi𐀀𐀀𐀀iႠ𐀀ႠႠႠi𐀀𐀀ÀÀÀ𐀀ÀႠÀiii|
  iiႠi𐀀ÀÀiႠ𐀀𐀀ႠႠÀ𐀀𐀀iÀႠiႠÀႠÀiÀiႠÀ𐀀𐀀ႠiÀႠႠႠႠ𐀀iiႠÀÀ𐀀ÀiÀ𐀀Ⴀ𐀀ÀiႠႠ𐀀À𐀀ႠiiႠiႠ𐀀iႠ𐀀ÀÀ𐀀ÀÀiႠÀi𐀀ÀႠii𐀀𐀀𐀀ÀÀ𐀀iႠ𐀀iႠÀႠႠiii𐀀|
  iÀiႠÀi𐀀À𐀀𐀀iiÀ𐀀𐀀𐀀Ài𐀀𐀀ႠÀÀ𐀀ii𐀀𐀀i𐀀ii𐀀Ⴀ𐀀𐀀𐀀ႠÀႠ𐀀ÀႠ𐀀iÀÀÀႠÀÀ𐀀𐀀iႠႠiÀ𐀀ÀႠ𐀀iiÀÀiႠႠႠႠ𐀀Ⴀ𐀀Ⴀ𐀀À𐀀iႠႠiႠ𐀀iiii𐀀Ⴀi𐀀ÀiႠ𐀀ÀÀii|
  ႠÀii𐀀ÀႠႠ𐀀𐀀i𐀀iiႠ𐀀i𐀀Ⴀ𐀀À𐀀𐀀ႠႠiiÀiiÀi𐀀ii𐀀𐀀iiiÀiiႠiÀ𐀀𐀀ÀÀÀ𐀀ÀႠ𐀀Ài𐀀À𐀀ÀiiÀÀ𐀀Ⴀ𐀀ႠႠiiÀÀႠ𐀀𐀀i𐀀𐀀ႠႠ𐀀𐀀𐀀𐀀ႠiႠ𐀀ႠႠÀ𐀀ႠÀÀÀÀÀ|
  iႠႠႠ𐀀ÀႠ𐀀𐀀ÀiÀ𐀀À𐀀iiÀ𐀀𐀀iႠiiႠႠÀiႠÀႠ𐀀ႠÀÀ𐀀iiÀ𐀀𐀀ႠÀiÀ𐀀iႠiႠÀႠiiiႠiiႠႠႠiiÀ𐀀iÀ𐀀iႠႠ𐀀Ⴀi𐀀ႠႠÀiႠ𐀀i𐀀𐀀𐀀iiႠiÀ𐀀ÀႠႠÀÀÀ𐀀i𐀀|
  ÀÀÀii𐀀ႠiႠႠiႠ𐀀ႠiႠ𐀀ÀÀi𐀀𐀀ÀÀႠႠiÀÀiÀႠÀ𐀀ႠÀႠ𐀀𐀀𐀀iႠiႠiႠ𐀀À𐀀𐀀ÀႠ𐀀𐀀iiÀႠ𐀀i𐀀𐀀𐀀iiႠÀ𐀀𐀀ÀiႠi𐀀ႠiÀ𐀀iÀႠÀiÀႠႠႠ𐀀ÀႠ𐀀Ⴀ𐀀À𐀀ႠÀiii|
  𐀀ÀÀ𐀀𐀀iႠႠ𐀀ႠiႠii𐀀𐀀ႠႠÀÀႠÀႠiÀႠႠ𐀀ÀႠႠÀ𐀀ii𐀀𐀀𐀀ii𐀀𐀀Ⴀii𐀀𐀀ÀÀÀiႠÀiiiiiႠiÀႠႠÀ𐀀𐀀ႠÀႠÀiiiႠ𐀀ÀÀႠÀi𐀀ႠiÀiÀi𐀀ÀႠiႠiiႠ𐀀iÀÀÀ|
  ႠiiÀii𐀀ÀÀi𐀀𐀀ႠÀÀႠႠ𐀀ii𐀀ÀႠiႠႠÀ𐀀𐀀ႠႠiႠႠii𐀀iÀiiiႠ𐀀iiႠÀÀÀÀ𐀀ႠÀi𐀀iႠi𐀀ii𐀀Ⴀ𐀀ႠÀiii𐀀𐀀ÀÀÀiiႠÀ𐀀Ⴀ𐀀ႠÀႠႠ𐀀𐀀𐀀𐀀𐀀À𐀀ÀႠႠi𐀀ႠႠ|
  ÀႠ𐀀iiႠႠႠÀÀ𐀀iÀiÀ𐀀ႠႠÀiÀႠÀ𐀀ÀÀÀiႠ𐀀𐀀ႠÀ𐀀ÀႠÀÀ𐀀𐀀𐀀𐀀𐀀ÀÀ𐀀𐀀iÀႠႠiႠiÀiiiႠiÀÀiႠÀ𐀀𐀀Ài𐀀iႠÀ𐀀ႠÀÀÀ𐀀𐀀𐀀ÀႠiiႠ𐀀ÀႠÀÀ𐀀iÀႠÀႠ𐀀À𐀀|
  𐀀Ⴀ𐀀ႠႠႠႠႠႠႠiiႠ𐀀ÀÀ𐀀iÀႠiႠÀÀႠÀ𐀀i𐀀𐀀Ⴀ𐀀ႠႠÀႠႠ𐀀ႠႠ𐀀𐀀ÀႠႠiÀÀÀÀÀiႠÀ𐀀ႠÀÀ𐀀iÀi𐀀iႠ𐀀Ⴀ𐀀Ⴀii𐀀iႠႠႠႠႠႠi𐀀iÀÀ𐀀ႠÀiÀႠiÀ𐀀𐀀ii𐀀𐀀𐀀À|
  iႠi𐀀ÀႠi𐀀Ⴀ𐀀Àiii𐀀Ⴀii𐀀Ⴀii𐀀𐀀Ⴀ𐀀ႠÀÀii𐀀ႠႠ𐀀i𐀀𐀀ႠiiႠÀÀiႠÀiႠႠÀႠÀÀiÀi𐀀iႠႠ𐀀ႠÀ𐀀iႠÀÀ𐀀i𐀀𐀀ÀiႠႠÀiÀiiiႠႠႠ𐀀À𐀀ÀÀiÀÀႠÀႠ𐀀ÀႠ|
  𐀀𐀀Ⴀ𐀀ႠÀÀ𐀀iiÀi𐀀𐀀iiÀÀ𐀀𐀀𐀀iႠ𐀀À𐀀iႠႠႠÀႠiÀÀiÀႠiiiÀiÀÀႠႠႠÀÀႠႠiÀiႠႠႠႠÀiÀႠiÀ𐀀À𐀀À𐀀𐀀iiiႠ𐀀𐀀𐀀ÀႠ𐀀ÀiÀÀiႠÀÀႠႠÀႠiiႠi𐀀i𐀀|
  iÀiiႠiiiiႠÀ𐀀ÀÀÀiÀi𐀀iiiႠ𐀀𐀀ႠÀiႠÀႠiႠÀiႠÀႠiÀႠÀႠÀÀÀÀiÀႠi𐀀ႠiႠi𐀀Ⴀ𐀀À𐀀i𐀀𐀀ႠiiÀႠ𐀀ႠÀႠႠႠii𐀀𐀀iiiiii𐀀À𐀀iÀiiÀႠÀႠiႠi𐀀|
  À𐀀i𐀀ႠÀiႠ𐀀ႠÀႠ𐀀𐀀ႠႠiႠiiiႠÀႠÀႠႠÀ𐀀𐀀Ⴀ𐀀𐀀i𐀀ႠÀ𐀀iႠႠiႠiႠ𐀀Ⴀiii𐀀𐀀À𐀀Ⴀ𐀀ႠÀÀႠÀ𐀀iÀႠÀiႠÀÀ𐀀Ⴀii𐀀ႠiiiiႠÀ𐀀Ài𐀀𐀀ႠiႠÀÀ𐀀𐀀ႠiႠႠÀÀ|
  Ⴀ𐀀ÀႠႠ𐀀𐀀iႠႠ𐀀iÀÀiÀ𐀀ႠÀ𐀀𐀀𐀀𐀀iႠ𐀀À𐀀ႠႠ𐀀Ⴀ𐀀𐀀iႠiႠႠ𐀀ႠႠÀÀႠႠÀÀႠ𐀀𐀀ႠÀÀii𐀀𐀀𐀀ÀÀႠ𐀀i𐀀Ⴀ𐀀iiiÀÀÀႠiÀiÀ𐀀ii𐀀𐀀iႠႠႠii𐀀iiႠႠi𐀀ÀÀ𐀀i|
  𐀀ÀÀ𐀀𐀀ႠÀ𐀀ႠႠႠÀ𐀀Ⴀ𐀀ii𐀀Ⴀ𐀀𐀀ႠႠ𐀀À𐀀𐀀𐀀ႠiႠႠႠ𐀀ႠÀi𐀀𐀀Ⴀ𐀀Ài𐀀ႠÀÀi𐀀À𐀀iႠiႠႠ𐀀iiÀiႠႠÀ𐀀À𐀀iiႠႠႠႠ𐀀ÀÀႠႠႠiÀႠ𐀀i𐀀i𐀀iiÀ𐀀i𐀀ႠiÀÀÀiÀ|
  Ⴀii𐀀i𐀀ႠiÀiiÀÀÀ𐀀Àii𐀀ႠÀႠi𐀀ႠႠiႠႠi𐀀i𐀀𐀀iႠႠ𐀀𐀀iႠ𐀀iႠႠ𐀀ÀiiႠiႠiii𐀀ÀÀÀi𐀀ႠiÀႠႠႠÀႠႠႠႠႠႠÀiiÀႠi𐀀ÀÀiÀႠ𐀀ÀiႠႠÀ𐀀𐀀iiÀ𐀀𐀀À|
  iႠႠiႠiiႠÀÀႠ𐀀iÀÀiÀ𐀀iiႠÀ𐀀i𐀀ႠႠ𐀀iႠႠ𐀀À𐀀𐀀iiႠႠႠ𐀀ႠiႠi𐀀iႠ𐀀ႠႠÀiႠ𐀀𐀀Ⴀ𐀀Ⴀi𐀀iႠႠÀ𐀀À𐀀ÀႠႠ𐀀ÀႠႠi𐀀Ⴀi𐀀iÀႠÀ𐀀À𐀀ႠÀ𐀀ႠÀÀi𐀀Ⴀ𐀀iiÀ|
  ႠႠႠ𐀀ႠiÀႠႠiiiiiiႠi𐀀i𐀀ႠÀ𐀀i𐀀𐀀ႠႠÀႠi𐀀ÀÀÀÀႠ𐀀ႠႠ𐀀i𐀀iiÀ𐀀Ài𐀀𐀀i𐀀i𐀀𐀀ÀႠႠႠii𐀀ÀiiÀiႠiႠ𐀀iiႠႠႠႠ𐀀i𐀀ii𐀀iiÀÀ𐀀𐀀ÀႠ𐀀ÀႠ𐀀iÀ𐀀𐀀|
  iႠÀiႠii𐀀𐀀ÀiႠႠiiÀ𐀀ÀÀ𐀀𐀀ႠÀႠ𐀀iႠiiႠiiÀi𐀀ႠႠႠiÀi𐀀𐀀ÀႠÀÀႠi𐀀iÀႠÀႠÀ𐀀𐀀À𐀀𐀀À𐀀ႠiÀÀi𐀀iÀÀ𐀀ÀႠႠႠi𐀀iႠႠi𐀀iiႠႠႠÀiÀ𐀀𐀀Ⴀ𐀀ÀÀ𐀀À|
  ÀiႠÀÀႠÀÀÀႠႠÀႠii𐀀i𐀀i𐀀iiႠiÀiÀÀÀႠႠiႠiiÀÀÀႠÀႠÀÀÀႠii𐀀Ⴀ𐀀Ⴀi𐀀ÀႠႠiÀÀႠi𐀀Ⴀ𐀀𐀀ÀႠႠ𐀀iႠႠ𐀀iÀiÀÀႠÀÀ𐀀i𐀀𐀀ÀႠiÀႠႠ𐀀𐀀ÀႠႠiႠÀi|
  ÀiႠÀiiiÀႠ𐀀𐀀iႠ𐀀𐀀iÀÀÀႠÀႠiÀiÀi𐀀Ⴀ𐀀À𐀀iiႠ𐀀ÀiÀႠႠ𐀀iiiႠ𐀀Ài𐀀𐀀𐀀𐀀𐀀𐀀𐀀ÀႠÀ𐀀ÀiÀ𐀀ÀÀ𐀀iႠႠ𐀀Ⴀ𐀀i𐀀𐀀iii𐀀𐀀𐀀𐀀ႠႠi𐀀ii𐀀𐀀ႠႠႠ𐀀ÀiႠÀႠ|
  À𐀀ႠÀ𐀀𐀀𐀀À𐀀ÀiÀႠiiႠႠÀႠႠiႠÀÀ𐀀𐀀i𐀀𐀀𐀀ႠiÀႠÀÀ𐀀𐀀𐀀À𐀀ႠႠiÀiÀi𐀀ႠiÀiiႠÀ𐀀ÀiiiႠႠiႠ𐀀ႠiÀ𐀀ÀႠÀÀi𐀀ႠiႠiiႠiÀiiႠÀႠiiÀi𐀀Ⴀ𐀀𐀀iႠi|
  ÀÀ𐀀iÀÀÀ𐀀Ⴀ𐀀𐀀ÀႠႠ𐀀Ⴀ𐀀Ⴀ𐀀ႠÀ𐀀i𐀀ÀÀiÀÀ𐀀À𐀀𐀀𐀀iÀiႠiiÀႠÀiႠii𐀀𐀀iÀii𐀀Ⴀ𐀀ႠÀႠiႠiႠ𐀀ÀႠÀ𐀀i𐀀iႠႠ𐀀ႠႠႠÀÀÀii𐀀Ⴀ𐀀𐀀i𐀀i𐀀𐀀iႠi𐀀À𐀀𐀀^Ⴀ |
                                                                                                      |
      ]=],
      value = { col = 100, curscol = 100, endcol = 100, row = 50 },
    },
  },
  {
    ascii_results,
    two_byte_results,
    { -- random
      screen = [=[
  Ⴀ𐀀ii𐀀ႠÀ𐀀i𐀀𐀀iÀÀÀiÀ𐀀Ⴀ𐀀ႠiiႠ𐀀iii𐀀ÀႠÀႠႠÀiiÀႠÀiႠi𐀀ÀÀ𐀀𐀀Ⴀ𐀀𐀀Ⴀ𐀀iÀႠ𐀀i𐀀ÀÀႠiiÀ𐀀Ⴀ𐀀À𐀀ii𐀀ÀÀ𐀀ÀႠႠ𐀀𐀀𐀀𐀀ii𐀀ႠႠiႠႠ𐀀ႠÀ𐀀ÀÀiiႠ|
  iiႠ𐀀iÀÀiႠႠÀi𐀀ႠႠÀ𐀀𐀀ÀiiiiÀiႠ𐀀iႠÀiႠiႠႠÀiÀ𐀀ႠiiႠႠÀ𐀀Àii𐀀ႠÀႠiႠÀႠÀႠii𐀀Ài𐀀ႠႠ𐀀ÀÀÀi𐀀ÀÀÀ𐀀iႠ𐀀iႠÀ𐀀iႠi𐀀ÀiÀ𐀀ႠႠiÀ𐀀𐀀Ⴀi|
  iÀiiiႠÀÀ𐀀ႠႠႠi𐀀À𐀀𐀀iiiÀÀiiÀႠÀ𐀀À𐀀ႠႠ𐀀𐀀ႠႠႠi𐀀iiÀႠ𐀀ႠႠႠÀiႠiႠiÀÀÀi𐀀iႠ𐀀ÀÀiႠ𐀀iÀÀi𐀀i𐀀𐀀ÀiÀႠ𐀀𐀀iႠ𐀀ÀÀiÀÀႠ𐀀𐀀ႠႠ𐀀𐀀𐀀𐀀Ⴀ𐀀𐀀|
  ÀႠiႠiÀ𐀀i𐀀ႠႠiႠႠÀ𐀀ÀÀÀÀ𐀀𐀀ÀႠႠ𐀀ႠÀÀiႠ𐀀i𐀀Ⴀ𐀀ÀႠi𐀀ႠÀႠÀ𐀀ႠႠ𐀀i𐀀iႠÀi𐀀i𐀀𐀀À𐀀iÀiႠႠႠ𐀀ÀiÀႠÀ𐀀ÀÀÀi𐀀𐀀𐀀ႠÀi𐀀𐀀À𐀀À𐀀𐀀iiႠiÀi𐀀i𐀀Ⴀ|
  Ⴀ𐀀i𐀀𐀀ÀiÀႠႠႠႠႠÀÀႠႠÀႠ𐀀ii𐀀ÀႠiႠiii𐀀i𐀀i𐀀𐀀𐀀À𐀀ii𐀀iÀiiiÀÀႠiiiႠiiႠÀ𐀀À𐀀𐀀ÀႠ𐀀iÀÀiiÀiÀ𐀀iႠi𐀀𐀀À𐀀ÀiiႠ𐀀iÀ𐀀𐀀iႠႠÀÀႠႠiiÀ|
  𐀀ÀiႠႠÀ𐀀𐀀𐀀i𐀀i𐀀i𐀀ႠÀ𐀀ÀiiÀႠ𐀀ÀÀÀi𐀀ႠÀiÀႠi𐀀ႠÀiiÀÀÀiiiÀiႠႠiÀ𐀀ႠႠ𐀀iÀႠÀႠႠiÀÀႠÀႠÀÀii𐀀Ⴀi𐀀iiÀÀÀiႠ𐀀i𐀀𐀀i𐀀iiÀ𐀀𐀀𐀀ႠÀiႠ𐀀|
  i𐀀ÀႠiႠi𐀀ႠiႠ𐀀Ⴀi𐀀ႠÀ𐀀𐀀𐀀ႠÀiiiii𐀀Ⴀ𐀀iiiÀiiÀ𐀀𐀀𐀀À𐀀𐀀Ⴀ𐀀ႠÀ𐀀ႠႠႠiÀÀÀÀii𐀀i𐀀ÀiiႠÀiÀ𐀀iႠႠiÀႠii𐀀i𐀀Ⴀ𐀀𐀀iႠႠÀ𐀀ႠiiiႠႠÀÀ𐀀iÀႠ|
  Ⴀ𐀀𐀀ႠႠ𐀀À𐀀ÀႠ𐀀ÀႠÀ𐀀𐀀iႠႠÀÀiÀႠ𐀀ÀiÀႠi𐀀ႠÀ𐀀𐀀𐀀𐀀Ⴀ𐀀iႠÀ𐀀iÀ𐀀iÀ𐀀iÀÀႠi𐀀iÀႠi𐀀ႠiiႠÀ𐀀À𐀀ႠႠÀÀi𐀀ႠႠ𐀀iiႠÀiႠ𐀀𐀀𐀀𐀀ႠႠႠÀႠiÀႠiÀÀ𐀀À|
  ÀႠÀÀ𐀀i𐀀iႠÀÀÀႠ𐀀𐀀ÀႠÀÀiii𐀀𐀀iiÀiiႠÀÀႠiÀiÀÀ𐀀i𐀀i𐀀ႠiႠႠiႠÀiiÀႠ𐀀ႠႠÀiÀႠ𐀀𐀀iÀ𐀀Ⴀ𐀀iÀ𐀀ႠÀÀႠÀÀÀ𐀀𐀀i𐀀𐀀À𐀀𐀀ii𐀀À𐀀𐀀ႠÀ𐀀ႠႠႠ𐀀𐀀|
  ÀÀÀÀiႠiႠႠႠiႠ𐀀ႠÀÀÀ𐀀ÀÀiႠÀ𐀀ÀiႠÀႠÀႠႠÀÀႠiÀႠႠiiႠÀ𐀀ႠႠÀiႠ𐀀iÀႠ𐀀Ⴀ𐀀Ⴀ𐀀iႠÀႠi𐀀𐀀Ⴀ𐀀iÀ𐀀ÀႠ𐀀ÀÀႠ𐀀Ⴀi𐀀iႠÀ𐀀𐀀𐀀𐀀i𐀀i𐀀𐀀𐀀ÀႠiÀÀ𐀀i|
  𐀀𐀀iiÀ𐀀ÀႠ𐀀𐀀𐀀𐀀𐀀Àiii𐀀𐀀𐀀Ⴀ𐀀𐀀i𐀀ÀÀ𐀀iiÀiiiiÀ𐀀iႠiႠiÀႠÀႠÀiႠႠႠႠႠႠႠႠႠÀiiႠiÀႠÀ𐀀iiႠÀႠiႠႠÀiႠ𐀀iႠ𐀀iiႠÀ𐀀𐀀Àii𐀀i𐀀ÀႠÀÀiÀÀ|
  𐀀𐀀𐀀i𐀀iÀ𐀀𐀀iÀ𐀀Ài𐀀𐀀ႠႠ𐀀ႠÀi𐀀𐀀ÀÀiiiႠiႠ𐀀iႠÀႠÀ𐀀ႠÀ𐀀ႠiiiiÀiႠÀiiiႠႠÀ𐀀Ⴀ𐀀𐀀𐀀ÀႠiÀႠiiiiႠiႠ𐀀Ⴀ𐀀ÀႠÀii𐀀i𐀀Ⴀ𐀀À𐀀iႠႠ𐀀iႠiiii𐀀|
  iႠÀÀႠÀÀ𐀀𐀀𐀀iiiÀ𐀀À𐀀iÀÀi𐀀À𐀀ÀႠÀiÀii𐀀ႠႠii𐀀ႠႠ𐀀𐀀ÀႠ𐀀ÀÀ𐀀ÀÀÀÀi𐀀ÀႠ𐀀À𐀀ÀiiႠ𐀀ÀÀႠiႠ𐀀Ⴀ𐀀ÀÀ𐀀ႠႠ𐀀ႠႠÀ𐀀ႠႠႠ𐀀iiÀႠÀႠiႠi𐀀ii𐀀Ài|
  Ⴀ𐀀ႠÀ𐀀Ⴀi𐀀iÀ𐀀Ⴀ𐀀𐀀iÀiÀ𐀀iႠi𐀀ႠÀiႠႠiÀ𐀀iႠiÀႠi𐀀𐀀iႠiႠႠ𐀀ÀÀi𐀀iÀႠႠ𐀀ႠÀ𐀀𐀀𐀀ႠႠiÀÀiႠႠႠ𐀀𐀀ႠႠႠႠÀiႠ𐀀Ài𐀀iÀႠii𐀀ÀႠii𐀀Ⴀ𐀀ÀႠÀ𐀀Ⴀi|
  𐀀ႠႠႠႠႠ𐀀Ⴀ𐀀ÀÀ𐀀𐀀iÀÀႠiÀiiႠÀiႠ𐀀𐀀ÀÀiÀႠ𐀀ÀÀႠ𐀀À𐀀À𐀀iႠႠÀiႠÀiiiႠÀiÀÀÀ𐀀iႠႠႠÀÀiႠႠႠ𐀀ii𐀀ii𐀀iႠႠii𐀀iႠÀi𐀀𐀀𐀀ii𐀀ÀႠႠiႠÀ𐀀ႠႠ|
  𐀀iႠ𐀀ႠႠႠÀÀ𐀀iiiÀÀႠii𐀀i𐀀ÀÀႠ𐀀ႠႠiႠႠႠiႠ𐀀i𐀀À𐀀ႠႠႠi𐀀Ài𐀀ႠÀ𐀀ÀႠiiiiႠiiႠႠi𐀀𐀀ÀႠ𐀀ႠiÀÀ𐀀iiiႠÀiႠi𐀀À𐀀𐀀i𐀀𐀀iiႠ𐀀À𐀀iiႠႠÀ𐀀iႠ|
  ႠႠÀÀႠႠ𐀀iÀႠ𐀀iႠႠÀÀ𐀀ÀiႠ𐀀iÀႠႠႠ𐀀𐀀À𐀀ii𐀀𐀀À𐀀𐀀ÀႠႠႠÀႠiiႠ𐀀𐀀ii𐀀ႠႠÀႠiႠi𐀀ႠႠ𐀀i𐀀𐀀𐀀𐀀Ⴀ𐀀iÀiႠႠ𐀀À𐀀ÀႠႠႠÀÀ𐀀𐀀iÀႠi𐀀𐀀ÀiႠႠÀÀiÀÀ|
  𐀀ႠÀiÀ𐀀ႠႠ𐀀i𐀀ႠႠ𐀀𐀀𐀀𐀀𐀀𐀀iႠÀႠႠiiÀႠ𐀀𐀀i𐀀ႠႠ𐀀ႠႠႠ𐀀𐀀iÀiÀႠ𐀀À𐀀À𐀀𐀀ႠiiiႠiiiႠiႠ𐀀ÀiiiႠ𐀀À𐀀ÀႠႠÀ𐀀À𐀀𐀀𐀀ႠiႠi𐀀ႠÀÀႠiiႠႠႠႠ𐀀ÀႠ𐀀𐀀|
  Ⴀ𐀀iÀÀႠ𐀀ႠႠÀႠÀ𐀀ႠႠÀiiÀÀÀႠ𐀀i𐀀Ⴀ𐀀ႠÀ𐀀𐀀iႠႠႠႠiiႠႠႠÀiႠÀiiႠÀ𐀀Ⴀ𐀀Ⴀi𐀀𐀀ႠÀ𐀀ÀႠႠ𐀀ÀႠÀႠ𐀀Ⴀ𐀀iႠi𐀀ÀႠႠii𐀀ÀႠÀ𐀀Ⴀ𐀀Ài𐀀À𐀀ÀÀႠiႠႠii𐀀|
  ÀႠႠႠÀႠႠii𐀀Ài𐀀Ⴀi𐀀i𐀀i𐀀Ⴀ𐀀ÀÀÀiÀÀi𐀀ÀÀÀ𐀀i𐀀iÀ𐀀𐀀ႠiÀi𐀀𐀀𐀀ႠÀiÀ𐀀𐀀iÀÀႠႠ𐀀ႠႠႠႠÀÀÀÀiiÀ𐀀iiႠႠႠi𐀀ႠÀi𐀀ÀႠႠÀ𐀀ႠiiႠ𐀀𐀀i𐀀Ⴀi𐀀𐀀À|
  ÀႠiiÀi𐀀ႠÀÀiÀႠi𐀀ÀႠႠ𐀀ႠiÀiiႠiiႠႠ𐀀ii𐀀i𐀀𐀀𐀀𐀀i𐀀ႠႠÀႠÀÀiÀÀÀႠÀႠႠÀÀႠ𐀀ÀÀ𐀀ÀÀႠÀ𐀀𐀀ÀiႠ𐀀ႠႠ𐀀iÀ𐀀Ⴀ𐀀iÀႠႠ𐀀iÀiiii𐀀ii𐀀𐀀ႠႠႠ𐀀Ⴀ|
  𐀀ÀiÀႠÀiiÀÀiiႠႠႠi𐀀ÀÀiႠ𐀀iႠႠÀ𐀀𐀀𐀀ÀႠႠÀ𐀀ႠÀÀႠ𐀀ÀÀ𐀀𐀀Ⴀ𐀀ÀÀ𐀀ÀႠ𐀀ႠÀiÀ𐀀iႠ𐀀ႠႠ𐀀𐀀À𐀀iii𐀀iiႠÀႠiႠÀႠ𐀀Ⴀ𐀀i𐀀𐀀ÀႠႠi𐀀𐀀ႠႠ𐀀𐀀𐀀𐀀À𐀀Ⴀ𐀀|
  𐀀iiÀႠiႠiÀႠ𐀀i𐀀iii𐀀Ⴀ𐀀i𐀀iÀÀi𐀀Ⴀii𐀀ÀiÀiiiÀႠÀ𐀀ÀÀႠ𐀀Ⴀ𐀀iiÀi𐀀i𐀀𐀀i𐀀ႠiiiÀႠႠႠiiÀ𐀀À𐀀𐀀iÀ𐀀iႠÀႠÀÀi𐀀ႠiÀႠÀ𐀀𐀀iÀÀ𐀀i𐀀𐀀ÀÀႠ𐀀|
  ÀiÀႠႠႠႠii𐀀ÀÀ𐀀𐀀𐀀Ⴀi𐀀À𐀀ÀႠiiÀi𐀀Ⴀii𐀀iÀÀ𐀀ႠiႠ𐀀ႠiiiႠÀÀiÀÀÀÀ𐀀ႠႠii𐀀À𐀀ÀiÀi𐀀ÀÀi𐀀iႠiÀi𐀀ÀiÀi𐀀ÀiÀႠ𐀀i𐀀Ⴀi𐀀𐀀𐀀ႠႠ𐀀ႠÀႠÀႠi|
  i𐀀ႠiÀႠႠÀÀ𐀀𐀀ii𐀀ÀÀ𐀀iÀiÀႠÀiiii𐀀ÀiÀႠi𐀀i𐀀𐀀i𐀀𐀀iႠ𐀀iÀi𐀀ÀÀÀÀiႠiÀႠÀÀႠiiÀÀႠႠi𐀀iႠiiႠi𐀀Ⴀ𐀀𐀀ÀႠႠÀႠiႠႠÀ𐀀iiÀႠႠႠ𐀀𐀀Ⴀi𐀀Ⴀi|
  ii𐀀iÀÀÀÀÀÀiÀ𐀀À𐀀iiႠiႠႠi𐀀À𐀀ÀႠÀ𐀀ႠႠ𐀀𐀀𐀀iႠႠiiႠÀÀႠÀiiႠÀႠႠÀ𐀀𐀀Ⴀ𐀀ÀÀÀÀႠ𐀀𐀀𐀀ႠႠÀႠ𐀀ÀiႠiÀႠiÀÀ𐀀ii𐀀iiiÀႠÀႠႠ𐀀ႠÀiÀÀ𐀀ႠႠႠÀ|
  𐀀𐀀À𐀀𐀀iÀႠ𐀀ႠiႠÀÀ𐀀iÀÀ𐀀À𐀀iÀÀႠႠÀiii𐀀À𐀀ÀႠÀႠႠÀႠႠi𐀀ÀÀÀi𐀀À𐀀ႠiÀi𐀀i𐀀i𐀀ÀiÀÀiÀÀ𐀀𐀀À𐀀ႠÀ𐀀ႠÀႠ𐀀ႠiÀ𐀀𐀀ÀiÀÀ𐀀𐀀𐀀À𐀀Ⴀi𐀀i𐀀i𐀀Ài|
  𐀀𐀀iႠ𐀀i𐀀ÀႠႠÀ𐀀iÀ𐀀ÀiႠႠi𐀀iiႠÀ𐀀ÀiiÀႠ𐀀Ⴀ𐀀ÀÀiÀiႠi𐀀À𐀀𐀀iÀiÀiႠi𐀀ႠႠႠi𐀀À𐀀ÀႠႠ𐀀Ⴀ𐀀ÀÀႠiÀiÀ𐀀Ⴀ𐀀ÀႠiႠႠÀÀÀi𐀀i𐀀Ⴀi𐀀À𐀀ii𐀀ႠÀ𐀀Ⴀ|
  ႠiႠ𐀀iÀႠႠ𐀀i𐀀À𐀀iÀÀ𐀀𐀀ÀႠႠÀႠÀ𐀀iiiÀ𐀀i𐀀iÀ𐀀ႠႠ𐀀iÀႠ𐀀ႠÀi𐀀iiii𐀀iႠႠ𐀀ÀiÀ𐀀Àii𐀀Ⴀ𐀀𐀀ႠiÀii𐀀𐀀Ⴀ𐀀𐀀ႠiႠ𐀀iႠiႠi𐀀iiiႠႠႠi𐀀iiÀi𐀀Ⴀ|
  i𐀀i𐀀ÀÀÀ𐀀ÀiÀႠiÀiiႠÀÀÀiÀiiii𐀀i𐀀ÀÀiiiႠÀiÀႠÀiႠ𐀀iiႠiႠႠiÀi𐀀ႠႠ𐀀ÀႠiႠ𐀀ႠÀiiႠÀ𐀀ÀႠႠ𐀀ႠiÀi𐀀À𐀀𐀀iiÀ𐀀𐀀ÀiႠႠiႠ𐀀ÀႠiÀÀႠ𐀀i|
  Ài𐀀𐀀𐀀iÀi𐀀Ài𐀀À𐀀ႠႠ𐀀ႠÀiiÀႠ𐀀i𐀀i𐀀𐀀ႠiႠÀ𐀀𐀀Ⴀ𐀀iÀ𐀀ÀÀႠiႠႠiÀ𐀀iÀ𐀀ႠiÀÀÀÀႠiiÀ𐀀𐀀ÀႠႠiÀ𐀀iiÀ𐀀À𐀀iÀiÀÀ𐀀iÀiÀÀiiÀ𐀀ÀႠႠÀiiÀÀႠ|
  𐀀ႠÀႠiႠႠÀ𐀀ÀiiÀ𐀀iÀႠႠႠႠiÀÀi𐀀iÀi𐀀iiiႠ𐀀iႠ𐀀𐀀𐀀𐀀ÀÀÀႠi𐀀iႠi𐀀ႠÀႠႠ𐀀𐀀À𐀀iiÀႠ𐀀𐀀ႠႠ𐀀𐀀ÀiႠÀÀÀႠ𐀀𐀀ÀiႠ𐀀𐀀iÀÀiÀ𐀀ႠÀi𐀀𐀀ႠႠႠႠ𐀀Ⴀi|
  iÀi𐀀ႠႠÀ𐀀𐀀i𐀀Àii𐀀ÀiÀÀiÀiÀÀ𐀀ÀÀ𐀀À𐀀ႠႠႠÀÀÀႠii𐀀ႠÀÀႠႠi𐀀ႠႠiႠႠ𐀀Ⴀ𐀀ÀiÀiiii𐀀ÀiႠÀiiiiႠႠiiႠÀÀÀႠÀႠ𐀀𐀀𐀀iiႠႠ𐀀ႠÀႠ𐀀iႠႠ𐀀𐀀Ⴀ|
  À𐀀À𐀀ႠႠႠiÀ𐀀ÀႠÀႠႠiiႠii𐀀ႠÀÀÀ𐀀iႠiiiiiÀ𐀀ÀÀiÀÀႠ𐀀𐀀iiႠi𐀀𐀀Ài𐀀ႠÀÀiႠႠႠႠ𐀀iႠiႠႠႠႠႠÀÀႠiiÀiႠ𐀀iÀiiႠiiii𐀀ii𐀀À𐀀ႠÀ𐀀Ⴀ𐀀ÀႠ|
  ÀႠÀiiiiႠiiႠiÀi𐀀𐀀ႠÀÀ𐀀Ài𐀀Ài𐀀ÀiႠÀ𐀀ႠႠႠႠ𐀀ႠiÀ𐀀iႠႠÀႠi𐀀Ài𐀀ႠiiႠ𐀀Ⴀii𐀀ÀÀÀႠ𐀀ÀÀÀႠÀiÀႠiႠiႠi𐀀𐀀À𐀀𐀀𐀀ÀႠiႠႠႠႠÀiiÀႠ𐀀À𐀀𐀀À|
  iÀ𐀀ÀႠႠÀiÀi𐀀Ài𐀀ÀiႠႠÀ𐀀iႠÀ𐀀i𐀀ÀiiÀÀÀႠÀÀႠ𐀀À𐀀À𐀀ÀÀÀÀႠi𐀀iႠÀ𐀀𐀀ÀႠiÀiႠႠiÀ𐀀ႠႠÀ𐀀𐀀Ⴀ𐀀ÀÀ𐀀ႠႠÀÀiÀi𐀀𐀀𐀀À𐀀ÀႠ𐀀iႠႠ𐀀𐀀𐀀i𐀀ႠÀ𐀀Ⴀ|
  Ⴀi𐀀ÀÀ𐀀ႠÀiÀi𐀀i𐀀ÀႠ𐀀Ⴀ𐀀ÀႠ𐀀ႠÀႠႠႠ𐀀𐀀ÀiiiiႠႠi𐀀ႠÀႠÀ𐀀Ⴀ𐀀i𐀀À𐀀𐀀𐀀Ⴀ𐀀ÀiÀÀႠႠiiႠiÀiႠႠÀiÀÀႠႠÀÀႠÀ𐀀ႠiႠ𐀀𐀀i𐀀i𐀀𐀀ÀႠÀႠႠႠÀÀiiÀ𐀀|
  ႠႠႠiiÀႠႠiÀႠ𐀀ÀiႠႠÀႠiÀႠႠÀÀi𐀀ÀÀiÀ𐀀𐀀i𐀀i𐀀iiÀÀiႠ𐀀Ⴀ𐀀𐀀𐀀ÀiiႠ𐀀Ài𐀀iiiiÀiႠႠii𐀀Ⴀi𐀀iႠႠ𐀀ÀÀႠ𐀀iÀႠႠႠiÀ𐀀𐀀iÀႠiႠÀ𐀀ÀႠÀiႠ𐀀À|
  𐀀ႠႠႠiႠႠiiii𐀀𐀀i𐀀Àiiii𐀀À𐀀Ⴀi𐀀iႠ𐀀ႠiÀiÀႠi𐀀𐀀ÀiÀiiÀÀÀ𐀀𐀀i𐀀À𐀀ÀႠÀiiÀႠ𐀀ႠႠ𐀀𐀀Ⴀ𐀀ÀÀiÀ𐀀iႠ𐀀𐀀iÀÀႠi𐀀iႠiÀ𐀀ႠႠ𐀀ÀÀႠiÀ𐀀ÀႠႠÀႠ|
  Ⴀii𐀀𐀀ႠÀiႠႠÀÀ𐀀ÀÀÀÀÀÀÀႠiႠႠÀÀi𐀀ÀiႠÀ𐀀𐀀i𐀀ႠÀii𐀀Ⴀ𐀀𐀀À𐀀𐀀ÀiÀ𐀀i𐀀𐀀ႠÀiÀÀႠiiႠႠiႠÀiÀႠÀi𐀀iÀ𐀀À𐀀𐀀ႠႠi𐀀ႠÀiÀÀÀႠÀiÀÀႠiႠ𐀀iÀ|
  𐀀ÀႠiÀႠႠႠÀÀႠÀႠ𐀀iiiiÀiÀÀႠ𐀀Ⴀiii𐀀𐀀iiႠiÀ𐀀𐀀i𐀀ÀiiÀႠ𐀀𐀀Ⴀ𐀀Ⴀ𐀀Ⴀii𐀀ႠiႠÀiႠႠÀÀÀႠÀ𐀀Ⴀ𐀀𐀀𐀀À𐀀Ⴀ𐀀Ⴀ𐀀ႠÀ𐀀ႠႠiႠ𐀀𐀀ÀiiiÀ𐀀ÀiÀiႠÀ𐀀À|
  i𐀀ႠiႠi𐀀ii𐀀𐀀iiiႠႠÀÀiiii𐀀ÀiႠႠÀi𐀀ÀÀÀÀiÀiiႠ𐀀ÀႠiႠႠiÀႠ𐀀ÀႠႠ𐀀ÀÀÀ𐀀ႠÀ𐀀À𐀀iႠi𐀀iÀÀi𐀀iÀÀiႠႠ𐀀ႠiÀÀiÀ𐀀iႠ𐀀ႠÀႠÀii𐀀𐀀ႠႠi𐀀|
  iႠ𐀀À𐀀𐀀Ài𐀀ÀႠ𐀀Ⴀ𐀀𐀀ႠÀ𐀀ႠႠႠiÀ𐀀ÀiႠႠႠÀႠÀႠiÀႠi𐀀ÀÀÀႠÀiÀႠÀÀÀiii𐀀𐀀ÀiiႠÀi𐀀iÀ𐀀À𐀀ÀiiÀÀÀiÀiÀÀi𐀀iiiiÀ𐀀ÀႠႠiiႠi𐀀iiႠ𐀀À𐀀𐀀|
  ႠႠÀÀiႠ𐀀iႠiÀÀႠႠi𐀀ႠÀÀiႠ𐀀ႠႠÀÀÀii𐀀𐀀iiႠ𐀀iႠ𐀀iႠႠ𐀀Ài𐀀iiÀÀႠႠ𐀀Ⴀ𐀀𐀀𐀀i𐀀ÀÀi𐀀𐀀ႠiÀi𐀀iÀiiႠႠÀႠႠiႠÀiႠႠႠÀÀÀ𐀀ႠÀ𐀀ႠÀႠႠiÀÀႠ𐀀|
  Àii𐀀i𐀀iႠÀÀႠႠÀii𐀀ႠႠiÀiÀiႠÀiႠ𐀀Ⴀi𐀀𐀀𐀀À𐀀𐀀𐀀𐀀𐀀iႠ𐀀ႠႠi𐀀i𐀀iႠ𐀀ႠႠÀႠ𐀀iႠႠႠiႠႠ𐀀ႠႠႠႠ𐀀ႠÀÀႠႠႠႠÀ𐀀ႠÀႠÀiiÀiÀiÀႠi𐀀𐀀𐀀𐀀À𐀀𐀀𐀀À|
  ႠiÀiႠi𐀀𐀀ÀiႠiႠÀ𐀀iÀii𐀀ႠÀ𐀀𐀀ႠÀiÀÀ𐀀ႠÀÀႠ𐀀iÀiႠ𐀀𐀀Ⴀ𐀀ႠႠႠÀ𐀀iÀႠiႠÀÀ𐀀ႠÀႠႠႠႠÀ𐀀𐀀À𐀀Ⴀ𐀀À𐀀iႠi𐀀i𐀀Ⴀi𐀀Ⴀ𐀀𐀀iiiႠiႠ𐀀À𐀀ႠÀ𐀀𐀀iÀÀi|
  Ⴀi𐀀ÀÀiÀi𐀀iႠÀ𐀀𐀀ႠiႠÀႠÀ𐀀iÀÀÀႠ𐀀𐀀iÀÀiႠ𐀀ii𐀀i𐀀𐀀iiiႠႠႠÀÀiႠÀ𐀀i𐀀ÀiႠÀÀႠႠi𐀀ႠÀ𐀀À𐀀iiႠႠ𐀀𐀀iÀႠÀi𐀀À𐀀𐀀iÀ𐀀ii𐀀𐀀À𐀀iÀ𐀀𐀀iÀi𐀀|
  iႠÀiiiႠ𐀀ႠiÀႠႠႠႠ𐀀À𐀀ႠႠ𐀀ႠႠi𐀀𐀀𐀀ႠÀÀ𐀀𐀀Ⴀ𐀀iÀ𐀀ႠiႠÀ𐀀ႠႠiÀi𐀀ÀiÀႠႠÀ𐀀𐀀iiÀႠ𐀀ႠႠi𐀀𐀀ÀႠÀiႠႠiÀÀ𐀀iÀÀÀ𐀀𐀀ÀႠii𐀀ÀiiÀႠÀႠÀi𐀀𐀀iႠ|
  iÀ𐀀ႠÀi𐀀iႠႠii𐀀ႠÀ𐀀Ài𐀀𐀀iႠ𐀀iÀi𐀀À𐀀iÀÀiÀ𐀀ÀÀiiiÀႠႠi𐀀ႠiiiႠi𐀀iÀÀ𐀀𐀀ႠႠႠÀiiႠÀႠÀႠiႠi𐀀ႠÀÀ𐀀Ⴀ𐀀i𐀀ႠÀÀ𐀀iÀ𐀀Ⴀ𐀀iÀ𐀀Ⴀ𐀀ႠÀႠÀÀ𐀀|
  ႠÀ𐀀𐀀ÀiÀiႠiႠႠi𐀀𐀀𐀀ÀႠႠi𐀀À𐀀i𐀀𐀀𐀀𐀀iiÀÀÀÀ𐀀Ⴀ𐀀ii𐀀i𐀀iÀi𐀀ႠႠ𐀀iÀ𐀀𐀀𐀀ႠႠႠ𐀀𐀀𐀀𐀀i𐀀𐀀ႠiႠ𐀀i𐀀iႠi𐀀i𐀀ÀႠ𐀀iႠႠႠ𐀀À𐀀𐀀iiႠi𐀀ÀÀÀiii^𐀀 |
                                                                                                      |
      ]=],
      value = { col = 100, curscol = 100, endcol = 100, row = 50 },
    },
  },
  {
    ascii_results,
    two_byte_results,
    { -- random
      screen = [=[
  Ⴀ𐀀ii𐀀ႠÀ𐀀i𐀀𐀀iÀÀÀiÀ𐀀Ⴀ𐀀ႠiiႠ𐀀iii𐀀ÀႠÀႠႠÀiiÀႠÀiႠi𐀀ÀÀ𐀀𐀀Ⴀ𐀀𐀀Ⴀ𐀀iÀႠ𐀀i𐀀ÀÀႠiiÀ𐀀Ⴀ𐀀À𐀀ii𐀀ÀÀ𐀀ÀႠႠ𐀀𐀀𐀀𐀀ii𐀀ႠႠiႠႠ𐀀ႠÀ𐀀ÀÀiiႠ|
  𐀀𐀀ÀႠÀ𐀀𐀀iႠÀ𐀀𐀀i𐀀𐀀𐀀𐀀ႠႠႠiiiiÀÀ𐀀ႠÀႠÀi𐀀i𐀀ႠႠÀiÀႠi𐀀𐀀À𐀀iÀ𐀀ÀÀÀ𐀀𐀀iÀႠ𐀀𐀀Ⴀ𐀀𐀀ÀiႠiiႠႠÀÀÀÀi𐀀ÀÀႠ𐀀Àiii𐀀iႠႠႠi𐀀ႠÀi𐀀iႠ𐀀ႠiႠ|
  iiႠ𐀀iÀÀiႠႠÀi𐀀ႠႠÀ𐀀𐀀ÀiiiiÀiႠ𐀀iႠÀiႠiႠႠÀiÀ𐀀ႠiiႠႠÀ𐀀Àii𐀀ႠÀႠiႠÀႠÀႠii𐀀Ài𐀀ႠႠ𐀀ÀÀÀi𐀀ÀÀÀ𐀀iႠ𐀀iႠÀ𐀀iႠi𐀀ÀiÀ𐀀ႠႠiÀ𐀀𐀀Ⴀi|
  À𐀀𐀀iÀiÀÀÀÀႠႠႠ𐀀iÀÀiႠ𐀀À𐀀ႠÀiiႠ𐀀iiႠႠ𐀀iÀiႠႠÀႠÀ𐀀Ài𐀀iႠ𐀀𐀀iiႠÀႠiÀÀÀiÀiiÀ𐀀i𐀀ÀÀႠ𐀀𐀀𐀀i𐀀𐀀ႠႠi𐀀À𐀀iႠi𐀀ႠႠiiiÀႠ𐀀ႠÀiÀiႠႠ|
  iÀiiiႠÀÀ𐀀ႠႠႠi𐀀À𐀀𐀀iiiÀÀiiÀႠÀ𐀀À𐀀ႠႠ𐀀𐀀ႠႠႠi𐀀iiÀႠ𐀀ႠႠႠÀiႠiႠiÀÀÀi𐀀iႠ𐀀ÀÀiႠ𐀀iÀÀi𐀀i𐀀𐀀ÀiÀႠ𐀀𐀀iႠ𐀀ÀÀiÀÀႠ𐀀𐀀ႠႠ𐀀𐀀𐀀𐀀Ⴀ𐀀𐀀|
  𐀀ÀÀႠÀ𐀀ÀÀiÀÀÀႠiiႠiiÀႠÀiႠÀiÀiႠႠ𐀀ÀÀÀႠiiÀႠ𐀀iÀi𐀀ႠႠ𐀀𐀀ÀÀ𐀀ÀiÀÀႠi𐀀iÀႠ𐀀À𐀀ႠႠÀ𐀀Ⴀiii𐀀ႠiiႠiÀႠႠiႠÀႠ𐀀ႠÀÀႠ𐀀À𐀀ÀiÀÀႠႠÀÀ|
  ÀႠiႠiÀ𐀀i𐀀ႠႠiႠႠÀ𐀀ÀÀÀÀ𐀀𐀀ÀႠႠ𐀀ႠÀÀiႠ𐀀i𐀀Ⴀ𐀀ÀႠi𐀀ႠÀႠÀ𐀀ႠႠ𐀀i𐀀iႠÀi𐀀i𐀀𐀀À𐀀iÀiႠႠႠ𐀀ÀiÀႠÀ𐀀ÀÀÀi𐀀𐀀𐀀ႠÀi𐀀𐀀À𐀀À𐀀𐀀iiႠiÀi𐀀i𐀀Ⴀ|
  𐀀𐀀i𐀀ÀႠႠ𐀀𐀀𐀀iႠႠ𐀀À𐀀ÀႠiÀ𐀀𐀀ႠÀi𐀀𐀀iiiႠ𐀀𐀀iႠÀÀ𐀀ႠiiÀႠႠÀ𐀀𐀀ႠÀႠႠÀiႠႠÀႠÀႠiႠႠ𐀀𐀀𐀀iႠႠႠiႠႠii𐀀ÀႠi𐀀ÀÀႠႠi𐀀À𐀀Ⴀ𐀀ÀÀ𐀀Ⴀ𐀀iႠiiႠႠ|
  Ⴀ𐀀i𐀀𐀀ÀiÀႠႠႠႠႠÀÀႠႠÀႠ𐀀ii𐀀ÀႠiႠiii𐀀i𐀀i𐀀𐀀𐀀À𐀀ii𐀀iÀiiiÀÀႠiiiႠiiႠÀ𐀀À𐀀𐀀ÀႠ𐀀iÀÀiiÀiÀ𐀀iႠi𐀀𐀀À𐀀ÀiiႠ𐀀iÀ𐀀𐀀iႠႠÀÀႠႠiiÀ|
  i𐀀𐀀𐀀ÀÀi𐀀ႠႠႠႠႠÀiiÀ𐀀𐀀ii𐀀Ⴀ𐀀Ài𐀀iႠiÀÀႠÀ𐀀ÀႠiႠÀi𐀀𐀀iiႠ𐀀i𐀀ႠÀiႠii𐀀𐀀À𐀀𐀀ႠႠÀႠiÀiႠÀÀi𐀀i𐀀ႠÀiႠႠႠ𐀀𐀀ÀiႠႠႠÀÀi𐀀ÀႠႠÀiႠ𐀀ႠÀ|
  𐀀ÀiႠႠÀ𐀀𐀀𐀀i𐀀i𐀀i𐀀ႠÀ𐀀ÀiiÀႠ𐀀ÀÀÀi𐀀ႠÀiÀႠi𐀀ႠÀiiÀÀÀiiiÀiႠႠiÀ𐀀ႠႠ𐀀iÀႠÀႠႠiÀÀႠÀႠÀÀii𐀀Ⴀi𐀀iiÀÀÀiႠ𐀀i𐀀𐀀i𐀀iiÀ𐀀𐀀𐀀ႠÀiႠ𐀀|
  À𐀀ႠႠႠႠ𐀀ÀiႠႠiÀ𐀀i𐀀ÀႠÀႠiiÀiÀÀiႠ𐀀𐀀𐀀Ⴀ𐀀ÀႠi𐀀𐀀iႠႠႠiiႠÀi𐀀𐀀𐀀iႠÀÀÀႠi𐀀À𐀀iiiႠÀႠiÀ𐀀iႠ𐀀ii𐀀𐀀𐀀ÀႠႠÀÀႠႠႠႠiÀi𐀀Àiii𐀀ii𐀀𐀀À|
  i𐀀ÀႠiႠi𐀀ႠiႠ𐀀Ⴀi𐀀ႠÀ𐀀𐀀𐀀ႠÀiiiii𐀀Ⴀ𐀀iiiÀiiÀ𐀀𐀀𐀀À𐀀𐀀Ⴀ𐀀ႠÀ𐀀ႠႠႠiÀÀÀÀii𐀀i𐀀ÀiiႠÀiÀ𐀀iႠႠiÀႠii𐀀i𐀀Ⴀ𐀀𐀀iႠႠÀ𐀀ႠiiiႠႠÀÀ𐀀iÀႠ|
  𐀀iii𐀀ÀႠiႠÀ𐀀𐀀i𐀀ÀႠ𐀀𐀀ႠႠÀiႠ𐀀𐀀iႠ𐀀ႠiiႠiiႠÀ𐀀𐀀ႠiÀÀႠÀiÀႠ𐀀ÀႠ𐀀ႠÀi𐀀Ⴀi𐀀𐀀𐀀𐀀𐀀À𐀀𐀀𐀀i𐀀iÀ𐀀À𐀀ÀÀÀ𐀀ႠႠ𐀀iiÀ𐀀ÀÀÀႠÀ𐀀ႠÀႠÀiÀiiÀႠ|
  Ⴀ𐀀𐀀ႠႠ𐀀À𐀀ÀႠ𐀀ÀႠÀ𐀀𐀀iႠႠÀÀiÀႠ𐀀ÀiÀႠi𐀀ႠÀ𐀀𐀀𐀀𐀀Ⴀ𐀀iႠÀ𐀀iÀ𐀀iÀ𐀀iÀÀႠi𐀀iÀႠi𐀀ႠiiႠÀ𐀀À𐀀ႠႠÀÀi𐀀ႠႠ𐀀iiႠÀiႠ𐀀𐀀𐀀𐀀ႠႠႠÀႠiÀႠiÀÀ𐀀À|
  ÀႠ𐀀iiiÀÀ𐀀ÀႠiႠ𐀀ႠႠႠ𐀀iÀ𐀀ႠiႠ𐀀i𐀀ÀÀiႠ𐀀ÀiiႠႠiÀÀ𐀀ÀiႠiÀ𐀀i𐀀ÀiÀ𐀀ÀႠiÀiႠႠi𐀀iႠÀiÀÀႠႠiÀiႠÀႠi𐀀𐀀ႠiÀႠii𐀀ႠiiႠi𐀀Ⴀi𐀀ÀiÀÀ𐀀|
  ÀႠÀÀ𐀀i𐀀iႠÀÀÀႠ𐀀𐀀ÀႠÀÀiii𐀀𐀀iiÀiiႠÀÀႠiÀiÀÀ𐀀i𐀀i𐀀ႠiႠႠiႠÀiiÀႠ𐀀ႠႠÀiÀႠ𐀀𐀀iÀ𐀀Ⴀ𐀀iÀ𐀀ႠÀÀႠÀÀÀ𐀀𐀀i𐀀𐀀À𐀀𐀀ii𐀀À𐀀𐀀ႠÀ𐀀ႠႠႠ𐀀𐀀|
  Ⴀ𐀀i𐀀𐀀i𐀀𐀀Ⴀ𐀀iÀ𐀀ÀiႠiiÀÀiÀÀÀiÀiiႠႠ𐀀iႠiÀi𐀀Ⴀ𐀀ႠÀ𐀀Ⴀ𐀀𐀀𐀀ႠÀႠ𐀀ႠiiႠiiiႠÀÀiÀ𐀀ÀÀ𐀀ÀႠÀ𐀀iiÀÀiÀiÀÀÀႠႠÀÀii𐀀ႠÀÀiႠiÀÀ𐀀iiiÀ|
  ÀÀÀÀiႠiႠႠႠiႠ𐀀ႠÀÀÀ𐀀ÀÀiႠÀ𐀀ÀiႠÀႠÀႠႠÀÀႠiÀႠႠiiႠÀ𐀀ႠႠÀiႠ𐀀iÀႠ𐀀Ⴀ𐀀Ⴀ𐀀iႠÀႠi𐀀𐀀Ⴀ𐀀iÀ𐀀ÀႠ𐀀ÀÀႠ𐀀Ⴀi𐀀iႠÀ𐀀𐀀𐀀𐀀i𐀀i𐀀𐀀𐀀ÀႠiÀÀ𐀀i|
  i𐀀iÀ𐀀i𐀀iႠႠႠÀÀiiiႠi𐀀iÀÀ𐀀iႠÀÀ𐀀ii𐀀i𐀀𐀀ÀÀÀÀiÀiiÀiiiÀiÀi𐀀𐀀ႠႠÀႠႠÀiÀÀႠiႠႠiÀႠÀiႠႠ𐀀ႠႠႠÀႠÀႠ𐀀iiႠႠႠ𐀀iÀ𐀀iႠ𐀀iÀiÀiÀi|
  𐀀𐀀iiÀ𐀀ÀႠ𐀀𐀀𐀀𐀀𐀀Àiii𐀀𐀀𐀀Ⴀ𐀀𐀀i𐀀ÀÀ𐀀iiÀiiiiÀ𐀀iႠiႠiÀႠÀႠÀiႠႠႠႠႠႠႠႠႠÀiiႠiÀႠÀ𐀀iiႠÀႠiႠႠÀiႠ𐀀iႠ𐀀iiႠÀ𐀀𐀀Àii𐀀i𐀀ÀႠÀÀiÀÀ|
  Ⴀ𐀀iÀiÀÀÀÀႠi𐀀ႠႠi𐀀ႠႠႠ𐀀ႠႠ𐀀iÀÀÀiÀi𐀀Ài𐀀𐀀𐀀ႠÀiႠiႠ𐀀𐀀Àiii𐀀ÀÀiႠÀiႠ𐀀𐀀i𐀀ÀÀiiÀiႠႠi𐀀À𐀀ÀႠÀႠiiiiii𐀀Ⴀ𐀀ÀႠ𐀀ႠႠႠ𐀀𐀀iႠႠႠႠiÀ|
  𐀀𐀀𐀀i𐀀iÀ𐀀𐀀iÀ𐀀Ài𐀀𐀀ႠႠ𐀀ႠÀi𐀀𐀀ÀÀiiiႠiႠ𐀀iႠÀႠÀ𐀀ႠÀ𐀀ႠiiiiÀiႠÀiiiႠႠÀ𐀀Ⴀ𐀀𐀀𐀀ÀႠiÀႠiiiiႠiႠ𐀀Ⴀ𐀀ÀႠÀii𐀀i𐀀Ⴀ𐀀À𐀀iႠႠ𐀀iႠiiii𐀀|
  ÀÀÀႠႠÀ𐀀À𐀀À𐀀iႠ𐀀𐀀𐀀À𐀀ႠႠ𐀀ÀiÀiÀi𐀀Ⴀ𐀀iiႠiiÀႠÀႠ𐀀ႠÀi𐀀𐀀iÀiÀႠi𐀀À𐀀𐀀ÀႠ𐀀𐀀iႠÀ𐀀Ⴀ𐀀ÀiÀÀႠÀiÀ𐀀ႠႠႠiiÀi𐀀ÀႠiÀÀÀiႠႠiÀÀiÀႠÀႠÀ|
  iႠÀÀႠÀÀ𐀀𐀀𐀀iiiÀ𐀀À𐀀iÀÀi𐀀À𐀀ÀႠÀiÀii𐀀ႠႠii𐀀ႠႠ𐀀𐀀ÀႠ𐀀ÀÀ𐀀ÀÀÀÀi𐀀ÀႠ𐀀À𐀀ÀiiႠ𐀀ÀÀႠiႠ𐀀Ⴀ𐀀ÀÀ𐀀ႠႠ𐀀ႠႠÀ𐀀ႠႠႠ𐀀iiÀႠÀႠiႠi𐀀ii𐀀Ài|
  ÀiÀႠ𐀀À𐀀𐀀ii𐀀𐀀ႠႠiiiiႠiÀiႠiÀiÀ𐀀ÀiႠÀiiÀÀÀ𐀀𐀀Ⴀ𐀀ႠႠ𐀀iÀiႠ𐀀ii𐀀ႠÀ𐀀ႠiႠÀiiႠÀႠ𐀀Ài𐀀Àii𐀀iiÀiႠÀiႠႠÀiÀ𐀀i𐀀ႠÀ𐀀iÀÀႠii𐀀iÀ𐀀|
  Ⴀ𐀀ႠÀ𐀀Ⴀi𐀀iÀ𐀀Ⴀ𐀀𐀀iÀiÀ𐀀iႠi𐀀ႠÀiႠႠiÀ𐀀iႠiÀႠi𐀀𐀀iႠiႠႠ𐀀ÀÀi𐀀iÀႠႠ𐀀ႠÀ𐀀𐀀𐀀ႠႠiÀÀiႠႠႠ𐀀𐀀ႠႠႠႠÀiႠ𐀀Ài𐀀iÀႠii𐀀ÀႠii𐀀Ⴀ𐀀ÀႠÀ𐀀Ⴀi|
  À𐀀iႠႠiႠi𐀀iႠii𐀀Ⴀi𐀀ii𐀀iႠÀ𐀀ႠÀÀi𐀀iÀ𐀀iÀ𐀀ႠÀႠiႠÀႠi𐀀Ⴀ𐀀ÀႠႠiႠ𐀀iႠiÀ𐀀À𐀀ÀႠi𐀀𐀀iÀi𐀀À𐀀Ⴀ𐀀ႠႠi𐀀𐀀𐀀iႠÀ𐀀ÀႠÀ𐀀i𐀀i𐀀iÀႠÀÀÀ𐀀iႠ𐀀|
  𐀀ႠႠႠႠႠ𐀀Ⴀ𐀀ÀÀ𐀀𐀀iÀÀႠiÀiiႠÀiႠ𐀀𐀀ÀÀiÀႠ𐀀ÀÀႠ𐀀À𐀀À𐀀iႠႠÀiႠÀiiiႠÀiÀÀÀ𐀀iႠႠႠÀÀiႠႠႠ𐀀ii𐀀ii𐀀iႠႠii𐀀iႠÀi𐀀𐀀𐀀ii𐀀ÀႠႠiႠÀ𐀀ႠႠ|
  𐀀iiႠi𐀀ÀႠ𐀀ÀiႠÀÀiÀÀÀÀႠ𐀀ÀiiႠi𐀀iႠi𐀀ÀႠÀ𐀀𐀀𐀀iÀiÀ𐀀ႠiÀ𐀀ႠႠÀÀi𐀀Ⴀ𐀀i𐀀ႠÀႠiႠiႠiii𐀀ÀႠႠ𐀀𐀀ÀႠ𐀀𐀀ii𐀀ÀiiÀÀႠiÀ𐀀ÀÀÀiÀႠÀ𐀀Ài𐀀Ⴀ|
  𐀀iႠ𐀀ႠႠႠÀÀ𐀀iiiÀÀႠii𐀀i𐀀ÀÀႠ𐀀ႠႠiႠႠႠiႠ𐀀i𐀀À𐀀ႠႠႠi𐀀Ài𐀀ႠÀ𐀀ÀႠiiiiႠiiႠႠi𐀀𐀀ÀႠ𐀀ႠiÀÀ𐀀iiiႠÀiႠi𐀀À𐀀𐀀i𐀀𐀀iiႠ𐀀À𐀀iiႠႠÀ𐀀iႠ|
  ÀႠ𐀀ႠႠႠÀii𐀀iiႠႠ𐀀iႠ𐀀iiႠii𐀀𐀀𐀀iiႠiÀ𐀀ႠႠÀÀÀiႠႠ𐀀À𐀀ႠႠႠ𐀀ÀiႠ𐀀ÀiႠ𐀀i𐀀ÀÀ𐀀Ⴀ𐀀Ⴀ𐀀iÀ𐀀iiiÀႠiÀႠiÀႠႠÀႠii𐀀ႠႠႠÀii𐀀i𐀀iiႠiÀ𐀀𐀀|
  ႠႠÀÀႠႠ𐀀iÀႠ𐀀iႠႠÀÀ𐀀ÀiႠ𐀀iÀႠႠႠ𐀀𐀀À𐀀ii𐀀𐀀À𐀀𐀀ÀႠႠႠÀႠiiႠ𐀀𐀀ii𐀀ႠႠÀႠiႠi𐀀ႠႠ𐀀i𐀀𐀀𐀀𐀀Ⴀ𐀀iÀiႠႠ𐀀À𐀀ÀႠႠႠÀÀ𐀀𐀀iÀႠi𐀀𐀀ÀiႠႠÀÀiÀÀ|
  ÀiႠii𐀀ÀÀႠi𐀀ÀႠi𐀀À𐀀ii𐀀iႠi𐀀ÀႠ𐀀À𐀀ÀÀႠႠ𐀀i𐀀ႠiiႠ𐀀ÀÀ𐀀À𐀀i𐀀𐀀i𐀀Ⴀ𐀀Ⴀi𐀀𐀀𐀀i𐀀Ài𐀀𐀀ÀႠႠi𐀀ÀiÀႠÀiiiÀÀႠႠi𐀀ÀiÀiႠÀÀiÀ𐀀𐀀ÀiiiiÀ|
  𐀀ႠÀiÀ𐀀ႠႠ𐀀i𐀀ႠႠ𐀀𐀀𐀀𐀀𐀀𐀀iႠÀႠႠiiÀႠ𐀀𐀀i𐀀ႠႠ𐀀ႠႠႠ𐀀𐀀iÀiÀႠ𐀀À𐀀À𐀀𐀀ႠiiiႠiiiႠiႠ𐀀ÀiiiႠ𐀀À𐀀ÀႠႠÀ𐀀À𐀀𐀀𐀀ႠiႠi𐀀ႠÀÀႠiiႠႠႠႠ𐀀ÀႠ𐀀𐀀|
  Ⴀ𐀀ႠႠÀ𐀀iႠ𐀀ႠiiႠi𐀀ÀႠႠ𐀀iÀiÀÀiႠi𐀀iiÀ𐀀ႠႠႠiÀႠ𐀀ႠႠႠÀ𐀀ႠiႠ𐀀𐀀ÀႠÀÀ𐀀ÀႠႠiႠ𐀀𐀀iiÀÀ𐀀À𐀀iႠiÀ𐀀iÀ𐀀𐀀iiiiii𐀀ÀiႠ𐀀𐀀i𐀀Ài𐀀À𐀀𐀀i𐀀Ⴀ|
  Ⴀ𐀀iÀÀႠ𐀀ႠႠÀႠÀ𐀀ႠႠÀiiÀÀÀႠ𐀀i𐀀Ⴀ𐀀ႠÀ𐀀𐀀iႠႠႠႠiiႠႠႠÀiႠÀiiႠÀ𐀀Ⴀ𐀀Ⴀi𐀀𐀀ႠÀ𐀀ÀႠႠ𐀀ÀႠÀႠ𐀀Ⴀ𐀀iႠi𐀀ÀႠႠii𐀀ÀႠÀ𐀀Ⴀ𐀀Ài𐀀À𐀀ÀÀႠiႠႠii𐀀|
  ႠÀႠႠႠiႠ𐀀Ⴀ𐀀Ⴀ𐀀ႠiiႠÀ𐀀ÀiiÀi𐀀iÀÀiiiiÀႠÀႠÀႠiiႠ𐀀𐀀ႠÀÀ𐀀𐀀À𐀀ÀႠႠ𐀀𐀀iii𐀀iiÀ𐀀ႠiႠႠÀ𐀀ÀÀii𐀀ႠÀႠi𐀀𐀀Ⴀi𐀀ÀႠႠ𐀀ÀÀÀ𐀀iÀႠႠ𐀀ÀÀi𐀀i|
  ÀႠႠႠÀႠႠii𐀀Ài𐀀Ⴀi𐀀i𐀀i𐀀Ⴀ𐀀ÀÀÀiÀÀi𐀀ÀÀÀ𐀀i𐀀iÀ𐀀𐀀ႠiÀi𐀀𐀀𐀀ႠÀiÀ𐀀𐀀iÀÀႠႠ𐀀ႠႠႠႠÀÀÀÀiiÀ𐀀iiႠႠႠi𐀀ႠÀi𐀀ÀႠႠÀ𐀀ႠiiႠ𐀀𐀀i𐀀Ⴀi𐀀𐀀À|
  𐀀À𐀀Ⴀ𐀀𐀀iÀÀiႠiiÀႠÀiÀႠÀႠႠ𐀀iႠႠÀiႠႠႠႠ𐀀iႠÀÀႠႠiႠ𐀀ÀiႠႠi𐀀𐀀ႠiÀ𐀀ÀiÀi𐀀i𐀀Ⴀi𐀀ႠÀiiÀႠÀi𐀀Ài𐀀ÀÀÀi𐀀𐀀ÀႠi𐀀ႠiႠÀiÀiႠ𐀀ii𐀀𐀀𐀀À|
  ÀႠiiÀi𐀀ႠÀÀiÀႠi𐀀ÀႠႠ𐀀ႠiÀiiႠiiႠႠ𐀀ii𐀀i𐀀𐀀𐀀𐀀i𐀀ႠႠÀႠÀÀiÀÀÀႠÀႠႠÀÀႠ𐀀ÀÀ𐀀ÀÀႠÀ𐀀𐀀ÀiႠ𐀀ႠႠ𐀀iÀ𐀀Ⴀ𐀀iÀႠႠ𐀀iÀiiii𐀀ii𐀀𐀀ႠႠႠ𐀀Ⴀ|
  ႠÀ𐀀ႠႠÀÀiႠႠ𐀀iႠႠႠÀႠ𐀀ႠႠ𐀀iႠ𐀀𐀀𐀀𐀀ႠiÀ𐀀ႠႠÀ𐀀Ⴀ𐀀ÀÀii𐀀Ⴀ𐀀ÀÀ𐀀ÀÀႠ𐀀ႠÀiÀ𐀀𐀀À𐀀À𐀀𐀀iႠi𐀀ÀႠႠႠႠ𐀀ႠႠÀÀ𐀀𐀀𐀀ÀÀiiႠÀÀ𐀀ႠႠႠiÀႠÀႠႠiÀႠ𐀀|
  𐀀ÀiÀႠÀiiÀÀiiႠႠႠi𐀀ÀÀiႠ𐀀iႠႠÀ𐀀𐀀𐀀ÀႠႠÀ𐀀ႠÀÀႠ𐀀ÀÀ𐀀𐀀Ⴀ𐀀ÀÀ𐀀ÀႠ𐀀ႠÀiÀ𐀀iႠ𐀀ႠႠ𐀀𐀀À𐀀iii𐀀iiႠÀႠiႠÀႠ𐀀Ⴀ𐀀i𐀀𐀀ÀႠႠi𐀀𐀀ႠႠ𐀀𐀀𐀀𐀀À𐀀Ⴀ𐀀|
  Àiiiii𐀀iႠÀÀÀiiႠiii𐀀𐀀ÀiÀႠÀÀiႠႠ𐀀iiÀÀႠ𐀀ႠiÀႠ𐀀𐀀ii𐀀iႠÀ𐀀iiႠ𐀀Ⴀ𐀀𐀀i𐀀Ⴀ𐀀i𐀀𐀀𐀀ÀႠiႠiႠi𐀀iiiÀii𐀀𐀀Àii𐀀À𐀀Ⴀ𐀀𐀀Ⴀ𐀀i𐀀ႠÀႠii𐀀Ⴀ|
  𐀀iiÀႠiႠiÀႠ𐀀i𐀀iii𐀀Ⴀ𐀀i𐀀iÀÀi𐀀Ⴀii𐀀ÀiÀiiiÀႠÀ𐀀ÀÀႠ𐀀Ⴀ𐀀iiÀi𐀀i𐀀𐀀i𐀀ႠiiiÀႠႠႠiiÀ𐀀À𐀀𐀀iÀ𐀀iႠÀႠÀÀi𐀀ႠiÀႠÀ𐀀𐀀iÀÀ𐀀i𐀀𐀀ÀÀႠ𐀀|
  𐀀iႠႠÀ𐀀ÀႠÀ𐀀iႠ𐀀Àii𐀀i𐀀𐀀ÀÀi𐀀𐀀𐀀iiႠÀ𐀀ii𐀀Ⴀ𐀀𐀀iႠi𐀀iÀ𐀀À𐀀ႠႠ𐀀À𐀀i𐀀𐀀iႠiiÀÀႠႠႠiÀÀiÀÀ𐀀𐀀𐀀À𐀀𐀀𐀀ႠÀႠ𐀀iÀ𐀀𐀀Ⴀ𐀀ႠႠii𐀀𐀀ÀÀႠÀi𐀀𐀀i|
  ÀiÀႠႠႠႠii𐀀ÀÀ𐀀𐀀𐀀Ⴀi𐀀À𐀀ÀႠiiÀi𐀀Ⴀii𐀀iÀÀ𐀀ႠiႠ𐀀ႠiiiႠÀÀiÀÀÀÀ𐀀ႠႠii𐀀À𐀀ÀiÀi𐀀ÀÀi𐀀iႠiÀi𐀀ÀiÀi𐀀ÀiÀႠ𐀀i𐀀Ⴀi𐀀𐀀𐀀ႠႠ𐀀ႠÀႠÀႠi|
  À𐀀𐀀i𐀀Ài𐀀𐀀ႠiႠÀႠiiႠiႠÀ𐀀𐀀ÀiÀ𐀀𐀀ÀÀႠႠႠ𐀀ႠiÀႠႠÀ𐀀Ⴀi𐀀𐀀ÀiÀ𐀀À𐀀iႠi𐀀𐀀ÀÀ𐀀iႠiႠႠ𐀀ÀÀ𐀀𐀀ÀiÀÀ𐀀ÀÀ𐀀i𐀀ÀÀ𐀀𐀀ÀÀႠii𐀀Ⴀ𐀀Ⴀ𐀀iiÀÀÀi𐀀À|
  i𐀀ႠiÀႠႠÀÀ𐀀𐀀ii𐀀ÀÀ𐀀iÀiÀႠÀiiii𐀀ÀiÀႠi𐀀i𐀀𐀀i𐀀𐀀iႠ𐀀iÀi𐀀ÀÀÀÀiႠiÀႠÀÀႠiiÀÀႠႠi𐀀iႠiiႠi𐀀Ⴀ𐀀𐀀ÀႠႠÀႠiႠႠÀ𐀀iiÀႠႠႠ𐀀𐀀Ⴀi𐀀Ⴀi|
  ႠÀႠ𐀀ÀႠ𐀀iႠÀ𐀀ႠiႠii𐀀ÀႠÀÀ𐀀i𐀀Ⴀi𐀀ႠiÀ𐀀ႠÀÀÀiÀÀÀႠ𐀀𐀀ႠiiႠ𐀀ÀႠiiÀiiႠႠi𐀀ÀiiႠ𐀀iÀႠÀi𐀀À𐀀ÀiÀÀÀi𐀀ÀÀႠႠiÀiႠ𐀀ii𐀀ႠÀiႠÀႠႠi^i |
                                                                                                      |
      ]=],
      value = { col = 100, curscol = 100, endcol = 100, row = 50 },
    },
  },
})
