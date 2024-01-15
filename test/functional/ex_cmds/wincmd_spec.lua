local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear
local eq = helpers.eq
local fn = helpers.fn
local command = helpers.command

it(':wincmd accepts a count', function()
  clear()
  command('vsplit')
  eq(1, fn.winnr())
  command('wincmd 2 w')
  eq(2, fn.winnr())
end)
