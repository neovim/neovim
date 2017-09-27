local helpers = require('test.functional.helpers')(after_each)
local command, clear = helpers.command, helpers.clear
local source, expect = helpers.source, helpers.expect

describe('options', function()
  setup(clear)

  it('should not throw any exception', function()
    command('options')
  end)
end)

describe('set', function()
  setup(clear)

  it("should keep two comma when 'path' is changed", function()
    source([[
      set path=foo,,bar
      set path-=bar
      set path+=bar
      $put =&path]])

    expect([[

      foo,,bar]])
  end)
end)
