local helpers = require('test.functional.helpers')(after_each)
local eq = helpers.eq
local clear = helpers.clear
local funcs = helpers.funcs
local iswin = helpers.iswin

describe('has()', function()
  before_each(clear)

  it('"nvim-x.y.z"', function()
    eq(0, funcs.has("nvim-"))
    eq(0, funcs.has("nvim-  "))
    eq(0, funcs.has("nvim- \t "))
    eq(0, funcs.has("nvim-0. 1. 1"))
    eq(0, funcs.has("nvim-0. 1.1"))
    eq(0, funcs.has("nvim-0.1. 1"))
    eq(0, funcs.has("nvim-a"))
    eq(0, funcs.has("nvim-a.b.c"))
    eq(0, funcs.has("nvim-0.b.c"))
    eq(0, funcs.has("nvim-0.0.c"))
    eq(0, funcs.has("nvim-0.b.0"))
    eq(0, funcs.has("nvim-a.b.0"))
    eq(0, funcs.has("nvim-.0.0.0"))
    eq(0, funcs.has("nvim-.0"))
    eq(0, funcs.has("nvim-0."))
    eq(0, funcs.has("nvim-0.."))
    eq(0, funcs.has("nvim-."))
    eq(0, funcs.has("nvim-.."))
    eq(0, funcs.has("nvim-..."))
    eq(0, funcs.has("nvim-42"))
    eq(0, funcs.has("nvim-9999"))
    eq(0, funcs.has("nvim-99.001.05"))

    eq(1, funcs.has("nvim"))
    eq(1, funcs.has("nvim-0"))
    eq(1, funcs.has("nvim-0.1"))
    eq(1, funcs.has("nvim-0.0.0"))
    eq(1, funcs.has("nvim-0.1.1."))
    eq(1, funcs.has("nvim-0.1.1.abc"))
    eq(1, funcs.has("nvim-0.1.1.."))
    eq(1, funcs.has("nvim-0.1.1.. .."))
    eq(1, funcs.has("nvim-0.1.1.... "))
    eq(1, funcs.has("nvim-0.0.0"))
    eq(1, funcs.has("nvim-0.0.1"))
    eq(1, funcs.has("nvim-0.1.0"))
    eq(1, funcs.has("nvim-0.1.1"))
    eq(1, funcs.has("nvim-0.1.5"))
    eq(1, funcs.has("nvim-0000.001.05"))
    eq(1, funcs.has("nvim-0.01.005"))
    eq(1, funcs.has("nvim-00.001.05"))
  end)

  it('"unnamedplus"', function()
    if (not iswin()) and funcs.has("clipboard") == 1 then
      eq(1, funcs.has("unnamedplus"))
    else
      eq(0, funcs.has("unnamedplus"))
    end
  end)

  it('"wsl"', function()
    if 1 == funcs.has('win32') or 1 == funcs.has('mac') then
      eq(0, funcs.has('wsl'))
    end
  end)
end)
