local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local exec_lua = n.exec_lua
local eq = t.eq

describe('deprecated lua code', function()
  before_each(clear)

  describe('vim.treesitter.get_parser()', function()
    it('returns nil for versions >= 0.12', function()
      local result = exec_lua(function()
        if vim.version.ge(vim.version(), '0.12') then
          return vim.treesitter.get_parser(0, 'borklang')
        end
        return nil
      end)
      eq(nil, result)
    end)
  end)
end)
