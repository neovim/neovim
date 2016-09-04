local ffi = require("ffi")
local helpers = require("test.unit.helpers")

local to_cstr = helpers.to_cstr
local eq      = helpers.eq
local NULL    = helpers.NULL

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

describe('set_option_value mps', function()
  local get_matchpairs = function ()
    local value = ffi.new("char *[1]")
    option.get_option_value (to_cstr("mps"), NULL, value, 0)
    return ffi.string(value[0])
  end

  local set_matchpairs = function(value)
    option.set_option_value(to_cstr("mps"), 0, to_cstr(value), 0)
  end

  it('keeps old value given invalid matchpair', function()
    local invalid_mps = { "(-)", "(:", "(-)-", "(:),(-)", "(:),(:" }
    local default_mps = "(:),{:},[:]"
    eq(default_mps, get_matchpairs())

    for i=1, #invalid_mps do
      set_matchpairs(invalid_mps[i])
      eq(default_mps, get_matchpairs())
    end
  end)

  it('accepts valid matchpairs', function()
    local valid_mps = { "", "(:)", "(:]", "(:),", "(:),[:]"  }
    for i=1, #valid_mps do
      set_matchpairs(valid_mps[i])
      eq(valid_mps[i], get_matchpairs())
    end
  end)
end)

describe('find_mps_values', function()
  --take input parameters and return output parameters
  local find_mps_values = function(to_match, switchit)
    --TODO mbyte handling with utf8.codepoints
    local initc = ffi.new("int[1]", string.byte(to_match)) 
    local findc = ffi.new("int[1]", 2)
    local backwards = ffi.new("int[1]", 3)
    option.find_mps_values(initc, findc, backwards, switchit)
    --TODO mbyte handling with utf8.char
    return string.char(initc[0]), string.char(findc[0]), backwards[0] 
  end

  it("finds pairs of searched character", function()
    globals.curbuf.b_p_mps = to_cstr("(:),[:]")
    local match, pair, backwards = find_mps_values("(", false)
    eq("(", match)
    eq(")", pair)
    eq(0, backwards)

    match, pair, backwards = find_mps_values("[", false)
    eq("[", match)
    eq("]", pair)
    eq(0, backwards)
  end)

  it("sets backwards when match is found after its pair", function()
    local match, pair, backwards = find_mps_values(")", false)
    eq(")", match)
    eq("(", pair)
    eq(1, backwards)
  end)

  it("swaps match and pair when switchit=true", function()
    globals.curbuf.b_p_mps = to_cstr("(:),[:]")
    local match, pair, backwards = find_mps_values("(", true)
    eq(")", match)
    eq("(", pair)
    eq(1, backwards)

    match, pair, backwards = find_mps_values(")", true)
    eq("(", match)
    eq(")", pair)
    eq(0, backwards)

    match, pair, backwards = find_mps_values("(", true)
    eq(")", match)
    eq("(", pair)
    eq(1, backwards)

    match, pair, backwards = find_mps_values(")", true)
    eq("(", match)
    eq(")", pair)
    eq(0, backwards)
  end)
end)
