local t = require('test.functional.testutil')()
local clear, eval, eq = t.clear, t.eval, t.eq
local command = t.command
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
