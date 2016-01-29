-- Test for the quickfix commands.

local helpers = require('test.functional.helpers')
local insert, source = helpers.insert, helpers.source
local clear, expect = helpers.clear, helpers.expect

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
