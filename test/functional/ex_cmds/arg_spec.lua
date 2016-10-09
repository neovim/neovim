local helpers = require("test.functional.helpers")(after_each)
local eq, execute, funcs = helpers.eq, helpers.execute, helpers.funcs
local ok = helpers.ok
local clear = helpers.clear

describe(":argument", function()
  before_each(function() 
    clear()
  end)

  it("does not restart :terminal buffer", function()
      execute("terminal")
      helpers.feed([[<C-\><C-N>]])
      execute("argadd")
      helpers.feed([[<C-\><C-N>]])
      local bufname_before = funcs.bufname("%")
      local bufnr_before = funcs.bufnr("%")
      helpers.ok(nil ~= string.find(bufname_before, "^term://"))  -- sanity

      execute("argument 1")
      helpers.feed([[<C-\><C-N>]])

      local bufname_after = funcs.bufname("%")
      local bufnr_after = funcs.bufnr("%")
      eq("\n["..bufname_before.."] ", helpers.eval('execute("args")'))
      ok(funcs.line('$') > 1)
      eq(bufname_before, bufname_after)
      eq(bufnr_before, bufnr_after)
  end)
end)
