local helpers = require('test.functional.helpers')()
local eq = helpers.eq
local clear = helpers.clear
local funcs = helpers.funcs
local is_os = helpers.is_os

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
    if (not is_os('win')) and funcs.has("clipboard") == 1 then
      eq(1, funcs.has("unnamedplus"))
    else
      eq(0, funcs.has("unnamedplus"))
    end
  end)

  it('"wsl"', function()
    local luv = require('luv')
    local is_wsl =
      luv.os_uname()['release']:lower():match('microsoft') and true or false
    if is_wsl then
      eq(1, funcs.has('wsl'))
    else
      eq(0, funcs.has('wsl'))
    end
  end)

  it('does not change v:shell_error', function()
    local nvim_prog = helpers.nvim_prog
    funcs.system({nvim_prog, '-es', '+73cquit'})
    funcs.has('python3') -- use a call whose implementation shells out
    eq(73, funcs.eval('v:shell_error'))
  end)
end)
