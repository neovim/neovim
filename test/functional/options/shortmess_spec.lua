local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local command = helpers.command
local clear, feed_command = helpers.clear, helpers.feed_command

if helpers.pending_win32(pending) then return end

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
      command("set shortmess-=F")
      feed_command('e test')
      screen:expect([[
        ^                         |
        ~                        |
        ~                        |
        ~                        |
        "test" is a directory    |
      ]])
      feed_command('set shortmess=F')
      feed_command('e test')
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
