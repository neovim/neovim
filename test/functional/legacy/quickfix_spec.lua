-- Test for the quickfix commands.

local helpers = require('test.functional.helpers')
local source, clear = helpers.source, helpers.clear

describe('helpgrep', function()
  before_each(clear)

  it('works', function()
    source([[
      helpgrep quickfix
      copen
      " This wipes out the buffer, make sure that doesn't cause trouble.
      cclose
    ]])
  end)
end)
