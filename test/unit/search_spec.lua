local helpers = require("test.unit.helpers")(after_each)
local itp = helpers.gen_itp(it)

local to_cstr = helpers.to_cstr
local eq      = helpers.eq

local search = helpers.cimport("./src/nvim/search.h")

itp('pat_has_uppercase', function()
  -- works on empty string
  eq(false, search.pat_has_uppercase(to_cstr("")))

  -- works with utf uppercase
  eq(false, search.pat_has_uppercase(to_cstr("ä")))
  eq(true, search.pat_has_uppercase(to_cstr("Ä")))
  eq(true, search.pat_has_uppercase(to_cstr("äaÅ")))

  -- works when pat ends with backslash
  eq(false, search.pat_has_uppercase(to_cstr("\\")))
  eq(false, search.pat_has_uppercase(to_cstr("ab$\\")))

  -- skips escaped characters
  eq(false, search.pat_has_uppercase(to_cstr("\\Ab")))
  eq(true, search.pat_has_uppercase(to_cstr("\\AU")))

  -- skips _X escaped characters
  eq(false, search.pat_has_uppercase(to_cstr("\\_Ab")))
  eq(true, search.pat_has_uppercase(to_cstr("\\_AU")))

  -- skips %X escaped characters
  eq(false, search.pat_has_uppercase(to_cstr("aa\\%Ab")))
  eq(true, search.pat_has_uppercase(to_cstr("aab\\%AU")))
end)
