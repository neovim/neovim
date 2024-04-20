local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local eq = t.eq
local fn = n.fn
local command = n.command

it(':wincmd accepts a count', function()
  clear()
  command('vsplit')
  eq(1, fn.winnr())
  command('wincmd 2 w')
  eq(2, fn.winnr())
end)
