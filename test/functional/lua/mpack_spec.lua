-- Test suite for testing interactions with API bindings
local t = require('test.functional.testutil')()

local clear = t.clear
local eq = t.eq
local exec_lua = t.exec_lua

describe('lua vim.mpack', function()
  before_each(clear)
  it('encodes vim.NIL', function()
    eq(
      { true, true, true, true },
      exec_lua [[
      local var = vim.mpack.decode(vim.mpack.encode({33, vim.NIL, 77}))
      return {var[1]==33, var[2]==vim.NIL, var[3]==77, var[4]==nil}
    ]]
    )
  end)

  it('encodes vim.empty_dict()', function()
    eq(
      { { {}, 'foo', {} }, true, false },
      exec_lua [[
      local var = vim.mpack.decode(vim.mpack.encode({{}, "foo", vim.empty_dict()}))
      return {var, vim.islist(var[1]), vim.islist(var[3])}
    ]]
    )
  end)
end)
