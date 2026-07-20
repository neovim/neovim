local n = require('test.functional.testnvim')()
local t = require('test.testutil')

local describe, it, before_each = t.describe, t.it, t.before_each
local clear = n.clear

describe(':qa', function()
  before_each(function()
    clear('--cmd', 'qa')
  end)

  it('verify #3334', function()
    -- just testing if 'qa' passed as a program argument won't result in memory
    -- errors
  end)
end)
