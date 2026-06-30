local t = require('test.testutil')

describe('vim.text', function()
  local input, output = string.rep('😂', 2 ^ 16), string.rep('F09F9882', 2 ^ 16)

  it('hexencode', function()
    t.bench(function()
      vim.text.hexencode(input)
    end, { n = 100, label = 'hexencode' })
  end)

  it('hexdecode', function()
    t.bench(function()
      vim.text.hexdecode(output)
    end, { n = 100, label = 'hexdecode' })
  end)
end)
