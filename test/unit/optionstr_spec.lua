local helpers = require("test.unit.helpers")(after_each)
local itp = helpers.gen_itp(it)

local to_cstr = helpers.to_cstr
local eq      = helpers.eq

local optionstr = helpers.cimport("./src/nvim/optionstr.h")

local check_ff_value = function(ff)
  return optionstr.check_ff_value(to_cstr(ff))
end

describe('check_ff_value', function()

  itp('views empty string as valid', function()
    eq(1, check_ff_value(""))
  end)

  itp('views "unix", "dos" and "mac" as valid', function()
    eq(1, check_ff_value("unix"))
    eq(1, check_ff_value("dos"))
    eq(1, check_ff_value("mac"))
  end)

  itp('views "foo" as invalid', function()
    eq(0, check_ff_value("foo"))
  end)
end)
