-- Specs for
-- :wundo

local helpers = require('test.functional.helpers')
local execute, eq, clear, eval, feed =
  helpers.execute, helpers.eq, helpers.clear, helpers.eval, helpers.feed


describe(':wundo', function()
  before_each(clear)

  it('safely fails on new, non-empty buffer', function()
    feed('iabc<esc>')
    execute('wundo foo') -- This should not segfault. #1027
    --TODO: check messages for error message

    os.remove(eval('getcwd()') .. '/foo') --cleanup
  end)

end)
