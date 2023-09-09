local helpers = require('test.functional.helpers')(after_each)
local clear, eval, eq = helpers.clear, helpers.eval, helpers.eq
local command = helpers.command
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

