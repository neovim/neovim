local t = require('test.unit.testutil')
local itp = t.gen_itp(it)

local ffi = t.ffi
local cimport = t.cimport
local to_cstr = t.to_cstr
local eq = t.eq

-- Import terminfo headers
local terminfo = cimport('./src/nvim/tui/terminfo.h')

describe('terminfo_fmt', function()
  itp('stack overflow fails before producing output', function()
    -- Creates a buffer
    local buf = ffi.new('char[256]')
    local buf_end = buf + ffi.sizeof(buf) -- One past end

    -- Sets input parameters
    local params = ffi.new('TPVAR[9]')
    params[0].num = 65 -- 'A'
    params[0].string = nil

    -- 20 pushes (TPSTACK nums array limit) then prints one char
    local valid_fmt = string.rep('%p1', 20) .. '%c'
    local valid_n = terminfo.terminfo_fmt(buf, buf_end, to_cstr(valid_fmt), params)
    eq(1, valid_n)

    -- Overflows with 21 pushes and fails before print
    local overflow_fmt = string.rep('%p1', 21) .. '%c'
    local overflow_n = terminfo.terminfo_fmt(buf, buf_end, to_cstr(overflow_fmt), params)
    eq(0, overflow_n)
  end)
end)
