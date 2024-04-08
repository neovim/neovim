local t = require('test.functional.testutil')(after_each)
local clear = t.clear
local command = t.command
local eq = t.eq
local pcall_err = t.pcall_err

describe('search (/)', function()
  before_each(clear)

  it('fails with huge column (%c) value #9930', function()
    eq([[Vim:E951: \% value too large]], pcall_err(command, '/\\v%18446744071562067968c'))
    eq([[Vim:E951: \% value too large]], pcall_err(command, '/\\v%2147483648c'))
  end)
end)
