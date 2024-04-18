local t = require('test.unit.testutil')
local itp = t.gen_itp(it)

local to_cstr = t.to_cstr
local eq = t.eq

local search = t.cimport('./src/nvim/search.h')
local globals = t.cimport('./src/nvim/globals.h')
local ffi = t.ffi

itp('pat_has_uppercase', function()
  -- works on empty string
  eq(false, search.pat_has_uppercase(to_cstr('')))

  -- works with utf uppercase
  eq(false, search.pat_has_uppercase(to_cstr('ä')))
  eq(true, search.pat_has_uppercase(to_cstr('Ä')))
  eq(true, search.pat_has_uppercase(to_cstr('äaÅ')))

  -- works when pat ends with backslash
  eq(false, search.pat_has_uppercase(to_cstr('\\')))
  eq(false, search.pat_has_uppercase(to_cstr('ab$\\')))

  -- skips escaped characters
  eq(false, search.pat_has_uppercase(to_cstr('\\Ab')))
  eq(true, search.pat_has_uppercase(to_cstr('\\AU')))

  -- skips _X escaped characters
  eq(false, search.pat_has_uppercase(to_cstr('\\_Ab')))
  eq(true, search.pat_has_uppercase(to_cstr('\\_AU')))

  -- skips %X escaped characters
  eq(false, search.pat_has_uppercase(to_cstr('aa\\%Ab')))
  eq(true, search.pat_has_uppercase(to_cstr('aab\\%AU')))
end)

describe('search_regcomp', function()
  local search_regcomp = function(pat, pat_save, pat_use, options)
    local regmatch = ffi.new('regmmatch_T')
    local fail = search.search_regcomp(to_cstr(pat), nil, pat_save, pat_use, options, regmatch)
    return fail, regmatch
  end

  local get_search_pat = function()
    return t.internalize(search.get_search_pat())
  end

  itp('accepts regexp pattern with invalid utf', function()
    --crafted to call reverse_text with invalid utf
    globals.curwin.w_onebuf_opt.wo_rl = 1
    globals.curwin.w_onebuf_opt.wo_rlc = to_cstr('s')
    globals.cmdmod.cmod_flags = globals.CMOD_KEEPPATTERNS
    local fail = search_regcomp('a\192', 0, 0, 0)
    eq(1, fail)
    eq('\192a', get_search_pat())
  end)
end)
