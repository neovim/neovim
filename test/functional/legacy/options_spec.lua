-- Test if ":options" throws any exception. The options window seems to mess
-- other tests, so restart nvim in the teardown hook

local helpers = require('test.functional.helpers')
local restart, command, clear = helpers.restart, helpers.command, helpers.clear

describe('options', function()
  setup(clear)
  teardown(restart)

  it('is working', function()
    command('options')
  end)
end)
