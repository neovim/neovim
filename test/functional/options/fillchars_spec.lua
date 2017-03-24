local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, execute = helpers.clear, helpers.execute

describe("'fillchars'", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(25, 5)
    screen:attach()
  end)

  after_each(function()
    screen:detach()
  end)

  describe('"eob" flag', function()
    it('renders empty lines at the end of the buffer with eob', function()
      screen:expect([[
        ^                         |
        ~                        |
        ~                        |
        ~                        |
                                 |
      ]])
      execute('set fillchars+=eob:\\ ')
      screen:expect([[
        ^                         |
                                 |
                                 |
                                 |
        :set fillchars+=eob:\    |
      ]])
      execute('set fillchars+=eob:ñ')
      screen:expect([[
        ^                         |
        ñ                        |
        ñ                        |
        ñ                        |
        :set fillchars+=eob:ñ    |
      ]])
    end)
  end)
end)
