local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq = helpers.eq

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

