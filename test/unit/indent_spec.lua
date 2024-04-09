local t = require('test.unit.testutil')
local itp = t.gen_itp(it)

local to_cstr = t.to_cstr
local ffi = t.ffi
local eq = t.eq

local indent = t.cimport('./src/nvim/indent.h')
local globals = t.cimport('./src/nvim/globals.h')

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

describe('indent_size_ts()', function()
  itp('works for spaces', function()
    local line = to_cstr((' '):rep(7) .. 'a ')
    eq(7, indent.indent_size_ts(line, 100, nil))
  end)

  itp('works for tabs and spaces', function()
    local line = to_cstr('   \t  \t \t\t   a ')
    eq(19, indent.indent_size_ts(line, 4, nil))
  end)

  itp('works for tabs and spaces with empty vts', function()
    local vts = ffi.new('int[1]') -- zero initialized => first element (size) == 0
    local line = to_cstr('   \t  \t \t\t       a ')
    eq(23, indent.indent_size_ts(line, 4, vts))
  end)

  itp('works for tabs and spaces with vts', function()
    local vts = ffi.new('int[3]')
    vts[0] = 2 -- zero indexed
    vts[1] = 7
    vts[2] = 2

    local line = to_cstr('      \t  \t \t\t   a ')
    eq(18, indent.indent_size_ts(line, 4, vts))
  end)
end)
