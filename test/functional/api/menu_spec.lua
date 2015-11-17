local helpers = require('test.functional.helpers')
local Screen = require('test.functional.ui.screen')

local clear = helpers.clear
local command = helpers.command
local feed = helpers.feed

describe("update_menu notification", function()

  local screen

  before_each(function()
    clear()
    screen = Screen.new()
    screen:attach()
  end)

  after_each(function()
    screen:detach()
  end)

  local function expect_sent(expected)
    screen:wait(function()
      if screen.update_menu ~= expected then
        if expected then
          return 'update_menu was expected but not sent'
        else
          return 'update_menu was sent unexpectedly'
        end
      end
    end)
  end

  it("should be sent when adding a menu", function()
    command('menu Test.Test :')
    expect_sent(true)
  end)

  it("should be sent when deleting a menu", function()
    command('menu Test.Test :')
    screen.update_menu = false

    command('unmenu Test.Test')
    expect_sent(true)
  end)

  it("should not be sent unnecessarily", function()
    feed('i12345<ESC>:redraw<CR>')
    expect_sent(false)
  end)

end)
