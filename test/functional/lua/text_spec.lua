local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local eq = t.eq

describe('vim.text', function()
  before_each(clear)

  describe('hexencode() and hexdecode()', function()
    it('works', function()
      local cases = {
        { 'Hello world!', '48656C6C6F20776F726C6421' },
        { '😂', 'F09F9882' },
      }

      for _, v in ipairs(cases) do
        local input, output = unpack(v)
        eq(output, vim.text.hexencode(input))
        eq(input, vim.text.hexdecode(output))
      end
    end)

    it('works with very large strings', function()
      local input, output = string.rep('😂', 2 ^ 16), string.rep('F09F9882', 2 ^ 16)
      eq(output, vim.text.hexencode(input))
      eq(input, vim.text.hexdecode(output))
    end)

    it('errors on invalid input', function()
      -- Odd number of hex characters
      do
        local res, err = vim.text.hexdecode('ABC')
        eq(nil, res)
        eq('string must have an even number of hex characters', err)
      end

      -- Non-hexadecimal input
      do
        local res, err = vim.text.hexdecode('nothex')
        eq(nil, res)
        eq('string must contain only hex characters', err)
      end
    end)
  end)
end)
