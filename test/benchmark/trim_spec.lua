local t = require('test.testutil')

describe('vim.trim()', function()
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
      t.bench(function()
        vim.trim(strings[name])
      end, { n = 100, label = name })
    end)
  end
end)
