local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, execute = helpers.clear, helpers.execute

describe("'shortmess'", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(25, 5)
    screen:attach()
  end)

  after_each(function()
    screen:detach()
  end)

  describe('"F" flag', function()
    it('hides messages about the files read', function()
      execute('e test')
      screen:expect([[
        ^                         |
        ~                        |
        ~                        |
        ~                        |
        "test" is a directory    |
      ]])
      execute('set shortmess=F')
      execute('e test')
      screen:expect([[
        ^                         |
        ~                        |
        ~                        |
        ~                        |
        :e test                  |
      ]])
    end)
  end)
end)
