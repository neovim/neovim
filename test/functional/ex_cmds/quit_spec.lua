local helpers = require('test.functional.helpers')
local execute, eq, clear = helpers.execute, helpers.eq, helpers.clear

describe(':qa', function()
  before_each(function() 
    clear('qa')
  end)

  it('verify #3334', function()
    -- just testing if 'qa' passed as a program argument wont result in memory
    -- errors
  end)
end)

