local helpers = require("test.unit.helpers")

local to_cstr = helpers.to_cstr
local eq      = helpers.eq

local search = helpers.cimport("./src/nvim/search.h")

describe('pat_has_uppercase', function()
  it('works on empty string', function()
    eq(0, search.pat_has_uppercase(to_cstr("")))
  end)

  it('works with utf uppercase', function()
    eq(0, search.pat_has_uppercase(to_cstr("ä")))
    eq(1, search.pat_has_uppercase(to_cstr("Ä")))
    eq(1, search.pat_has_uppercase(to_cstr("äaÅ")))
  end)

  it('works when pat ends with backslash', function()
    eq(0, search.pat_has_uppercase(to_cstr("\\")))
    eq(0, search.pat_has_uppercase(to_cstr("ab$\\")))
  end)

  it('skips escaped characters', function()
    eq(0, search.pat_has_uppercase(to_cstr("\\Ab")))
    eq(1, search.pat_has_uppercase(to_cstr("\\AU")))
  end)

  it('skips _X escaped characters', function()
    eq(0, search.pat_has_uppercase(to_cstr("\\_Ab")))
    eq(1, search.pat_has_uppercase(to_cstr("\\_AU")))
  end)

  it('skips %X escaped characters', function()
    eq(0, search.pat_has_uppercase(to_cstr("aa\\%Ab")))
    eq(1, search.pat_has_uppercase(to_cstr("aab\\%AU")))
  end)
end)
