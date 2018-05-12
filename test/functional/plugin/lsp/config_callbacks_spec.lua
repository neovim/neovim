local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
-- local eq = helpers.eq
-- local funcs = helpers.funcs

describe('LSP Callback Configuration', function()
  before_each(clear)

  it('should have some default configurations', function()
  end)

  it('should handle generic configurations', function()
  end)

  it('should handle filetype configurations', function()
  end)

  it('should handle overriding default configuration', function()
  end)

  it('should handle running default callback even after adding configuration', function()
  end)

  it('should not run filetype configuration in other filetypes', function()
  end)

  it('should allow complete disabling of default configuration', function()
  end)

  it('should handle adding callbacks for new/custom methods', function()
  end)

  it('should be able to determine whether default configuration exists for a method', function()
  end)
end)
