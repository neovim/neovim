local helpers = require("test.functional.helpers")(after_each)
local clear = helpers.clear
local eq = helpers.eq
local funcs = helpers.funcs
local command = helpers.command

it(':wincmd accepts a count', function()
  clear()
  command('vsplit')
  eq(1, funcs.winnr())
  command('wincmd 2 w')
  eq(2, funcs.winnr())
end)
