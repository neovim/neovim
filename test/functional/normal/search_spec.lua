local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local command = helpers.command
local expect_err = helpers.expect_err

describe('search (/)', function()
  before_each(clear)

  it('fails with huge column (%c) value #9930', function()
    expect_err("Vim:E951: \\%% value too large",
      command, "/\\v%18446744071562067968c")
    expect_err("Vim:E951: \\%% value too large",
      command, "/\\v%2147483648c")
  end)
end)

