local t = require('test.functional.testutil')(after_each)
local clear = t.clear

describe(':qa', function()
  before_each(function()
    clear('--cmd', 'qa')
  end)

  it('verify #3334', function()
    -- just testing if 'qa' passed as a program argument won't result in memory
    -- errors
  end)
end)
