local t = require('test.functional.testutil')(after_each)
local clear = t.clear
local eq = t.eq
local fn = t.fn
local command = t.command

it(':wincmd accepts a count', function()
  clear()
  command('vsplit')
  eq(1, fn.winnr())
  command('wincmd 2 w')
  eq(2, fn.winnr())
end)
