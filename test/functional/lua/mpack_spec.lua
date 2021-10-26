-- Test suite for testing interactions with API bindings
local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local eq = helpers.eq
local exec_lua = helpers.exec_lua

describe('lua vim.mpack', function()
  before_each(clear)
  it('can pack vim.NIL', function()
    eq({true, true, true, true}, exec_lua [[
      local var = vim.mpack.unpack(vim.mpack.pack({33, vim.NIL, 77}))
      return {var[1]==33, var[2]==vim.NIL, var[3]==77, var[4]==nil}
    ]])
  end)

  it('can pack vim.empty_dict()', function()
    eq({{{}, "foo", {}}, true, false}, exec_lua [[
      local var = vim.mpack.unpack(vim.mpack.pack({{}, "foo", vim.empty_dict()}))
      return {var, vim.tbl_islist(var[1]), vim.tbl_islist(var[3])}
    ]])
  end)
end)
