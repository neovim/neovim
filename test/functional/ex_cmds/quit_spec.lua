local helpers = require('test.functional.helpers')(after_each)
local clear = helpers.clear

describe(':qa', function()
  before_each(function()
    clear('--cmd', 'qa')
  end)

  it('verify #3334', function()
    -- just testing if 'qa' passed as a program argument wont result in memory
    -- errors
  end)
end)

