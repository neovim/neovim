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
  end)
end)
