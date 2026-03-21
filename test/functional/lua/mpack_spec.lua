-- Test suite for testing interactions with API bindings
local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local eq = t.eq
local exec_lua = n.exec_lua

describe('lua vim.mpack', function()
  before_each(clear)
  it('encodes vim.NIL', function()
    eq(
      { true, true, true, true },
      exec_lua(function()
        local var = vim.mpack.decode(vim.mpack.encode({ 33, vim.NIL, 77 }))
        return { var[1] == 33, var[2] == vim.NIL, var[3] == 77, var[4] == nil }
      end)
    )
  end)

  it('encodes vim.empty_dict()', function()
    eq(
      { { {}, 'foo', {} }, true, false },
      exec_lua(function()
        local var = vim.mpack.decode(vim.mpack.encode({ {}, 'foo', vim.empty_dict() }))
        return { var, vim.islist(var[1]), vim.islist(var[3]) }
      end)
    )
  end)

  it('encodes dict keys of length 20-31 as fixstr #32784', function()
    -- MessagePack fixstr format: 0xa0 | length (for lengths 0-31)
    -- Before #36737, strings 20-31 bytes were incorrectly encoded as str8 (0xd9, len)
    for len = 20, 31 do
      local expected_header = string.char(0xa0 + len) -- fixstr header
      local result = exec_lua(function(keylen)
        local key = string.rep('x', keylen)
        return vim.mpack.encode({ [key] = 1 })
      end, len)
      -- Byte 1 is fixmap header (0x81), byte 2 should be fixstr header for the key
      eq(expected_header, result:sub(2, 2), 'dict key length ' .. len .. ' should use fixstr')
    end
  end)
end)
