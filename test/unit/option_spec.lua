local helpers = require("test.unit.helpers")

local to_cstr = helpers.to_cstr
local eq      = helpers.eq

local option = helpers.cimport("./src/nvim/option.h")
local globals = helpers.cimport("./src/nvim/globals.h")

local check_ff_value = function(ff)
  return option.check_ff_value(to_cstr(ff))
end

describe('check_ff_value', function()

  it('views empty string as valid', function()
    eq(1, check_ff_value(""))
  end)

  it('views "unix", "dos" and "mac" as valid', function()
    eq(1, check_ff_value("unix"))
    eq(1, check_ff_value("dos"))
    eq(1, check_ff_value("mac"))
  end)

  it('views "foo" as invalid', function()
    eq(0, check_ff_value("foo"))
  end)
end)

describe('get_sts_value', function()
  it([[returns 'softtabstop' when it is non-negative]], function()
    globals.curbuf.b_p_sts = 5
    eq(5, option.get_sts_value())

    globals.curbuf.b_p_sts = 0
    eq(0, option.get_sts_value())
  end)

  it([[returns "effective shiftwidth" when 'softtabstop' is negative]], function()
    local shiftwidth = 2
    globals.curbuf.b_p_sw = shiftwidth
    local tabstop = 5
    globals.curbuf.b_p_ts = tabstop
    globals.curbuf.b_p_sts = -2
    eq(shiftwidth, option.get_sts_value())

    shiftwidth = 0
    globals.curbuf.b_p_sw = shiftwidth
    eq(tabstop, option.get_sts_value())
  end)
end)
