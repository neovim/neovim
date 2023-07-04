local helpers = require('test.unit.helpers')(after_each)
local itp = helpers.gen_itp(it)

local eq = helpers.eq

local indent = helpers.cimport('./src/nvim/indent.h')
local globals = helpers.cimport('./src/nvim/globals.h')

describe('get_sts_value', function()
  itp([[returns 'softtabstop' when it is non-negative]], function()
    globals.curbuf.b_p_sts = 5
    eq(5, indent.get_sts_value())

    globals.curbuf.b_p_sts = 0
    eq(0, indent.get_sts_value())
  end)

  itp([[returns "effective shiftwidth" when 'softtabstop' is negative]], function()
    local shiftwidth = 2
    globals.curbuf.b_p_sw = shiftwidth
    local tabstop = 5
    globals.curbuf.b_p_ts = tabstop
    globals.curbuf.b_p_sts = -2
    eq(shiftwidth, indent.get_sts_value())

    shiftwidth = 0
    globals.curbuf.b_p_sw = shiftwidth
    eq(tabstop, indent.get_sts_value())
  end)
end)
