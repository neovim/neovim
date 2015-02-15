local helpers = require('test.functional.helpers')
local Screen = require('test.functional.ui.screen')
local clear, feed, execute = helpers.clear, helpers.feed, helpers.execute

describe("'wildmode'", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(25, 5)
    screen:attach()
  end)

  after_each(function()
    screen:detach()
  end)

  describe("'wildmenu'", function()
    it(':sign <tab> shows wildmenu completions', function()
      execute('set wildmode')
      execute('set wildmenu')
      feed(':sign <tab>')
      screen:expect([[
                                 |
        ~                        |
        ~                        |
        define  jump  list  >    |
        :sign define^            |
      ]])
    end)
  end)
end)
