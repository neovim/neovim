local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local pcall_err = helpers.pcall_err

describe('search (/)', function()
  before_each(clear)

  it('fails with huge column (%c) value #9930', function()
    eq([[Vim:E951: \% value too large]],
      pcall_err(command, "/\\v%18446744071562067968c"))
    eq([[Vim:E951: \% value too large]],
      pcall_err(command, "/\\v%2147483648c"))
  end)
end)

