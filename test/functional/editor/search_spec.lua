local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local command = n.command
local eq = t.eq
local pcall_err = t.pcall_err

describe('search (/)', function()
  before_each(clear)

  it('fails with huge column (%c) value #9930', function()
    eq([[Vim:E951: \% value too large]], pcall_err(command, '/\\v%18446744071562067968c'))
    eq([[Vim:E951: \% value too large]], pcall_err(command, '/\\v%2147483648c'))
  end)
end)
