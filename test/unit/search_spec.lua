local helpers = require("test.unit.helpers")

local cimport = helpers.cimport
local eq = helpers.eq
local ffi = helpers.ffi
local to_cstr = helpers.to_cstr

local search = cimport('./src/nvim/search.h', './src/nvim/regexp_defs.h')
local globals = cimport('./src/nvim/globals.h')

describe('search_regcomp', function()
  local search_regcomp = function(pat, pat_save, pat_use, options )
    local regmatch = ffi.new("regmmatch_T")
    local fail = search.search_regcomp(to_cstr(pat), pat_save, pat_use, options, 
                          regmatch)
    return fail, regmatch
  end

  local get_search_pat = function()
    return helpers.internalize(search.get_search_pat())
  end

  it("accepts regexp pattern with invalid utf", function()
    --crafted to call reverse_text with invalid utf
    globals.curwin.w_onebuf_opt.wo_rl = 1
    globals.curwin.w_onebuf_opt.wo_rlc = to_cstr('s')
    globals.cmdmod.keeppatterns = 1
    local fail = search_regcomp("a\192", 0,0,0)
    eq(1, fail)
    eq("\192a", get_search_pat())
  end)
end)
