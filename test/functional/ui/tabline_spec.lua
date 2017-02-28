local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, eq = helpers.clear, helpers.feed, helpers.eq

if helpers.pending_win32(pending) then return end

describe('External tab line', function()
  local screen
  local tabs, curtab

  before_each(function()
    clear()
    screen = Screen.new(25, 5)
    screen:attach({rgb=true, tabline_external=true})
    screen:set_on_event_handler(function(name, data)
      if name == "tabline_update" then
        curtab, tabs = unpack(data)
      end
    end)
  end)

  after_each(function()
    screen:detach()
  end)

  describe("'tabline'", function()
    it('tabline', function()
      local expected = {
        {1, '[No Name]'},
        {2, '[No Name]'},
      }
      feed(":tabnew<CR>")
      screen:expect([[
        ^                         |
        ~                        |
        ~                        |
        ~                        |
                                 |
      ]], nil, nil, function()
        eq(2, curtab)
        eq(expected, tabs)
      end)

      feed(":tabNext<CR>")
      screen:expect([[
        ^                         |
        ~                        |
        ~                        |
        ~                        |
                                 |
      ]], nil, nil, function()
        eq(1, curtab)
        eq(expected, tabs)
      end)

    end)
  end)
end)
