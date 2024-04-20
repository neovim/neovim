local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear, eval, eq = n.clear, n.eval, t.eq
local command = n.command
describe('v:event', function()
  before_each(clear)
  it('is empty before any autocommand', function()
    eq({}, eval('v:event'))
  end)

  it('is immutable', function()
    eq(false, pcall(command, 'let v:event = {}'))
    eq(false, pcall(command, 'let v:event.mykey = {}'))
  end)
end)
