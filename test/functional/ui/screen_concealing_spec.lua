local helpers = require('test.functional.helpers')
local Screen = require('test.functional.ui.screen')
local clear, feed, execute = helpers.clear, helpers.feed, helpers.execute
local insert = helpers.insert

describe('Screen', function()
  local screen
  
  before_each(function()
    clear()
    screen = Screen.new()
    screen:attach()
    screen:set_default_attr_ignore( {{}, {bold=true, foreground=255}} ) 
  end)

  after_each(function()
    screen:detach()
  end)

  describe('', function()
    it('wadup test 1', function()

    end)
  end)
end)

