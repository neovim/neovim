local helpers = require('test.functional.helpers')(after_each)
local eq, clear, call, iswin =
  helpers.eq, helpers.clear, helpers.call, helpers.iswin

describe('exepath() (Windows)', function()
  if not iswin() then return end  -- N/A for Unix.

  it('append extension if omitted', function()
    local filename = 'cmd'
    local pathext = '.exe'
    clear({env={PATHEXT=pathext}})
    eq(call('exepath', filename..pathext), call('exepath', filename))
  end)
end)
