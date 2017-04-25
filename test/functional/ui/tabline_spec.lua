local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, eq = helpers.clear, helpers.feed, helpers.eq

describe('ui/tabline', function()
  local screen
  local tabs, curtab

  before_each(function()
    clear()
    screen = Screen.new(25, 5)
    screen:attach({rgb=true, ui_ext={'tabline'}})
    screen:set_on_event_handler(function(name, data)
      if name == "tabline_update" then
        curtab, tabs = unpack(data)
      end
    end)
  end)

  after_each(function()
    screen:detach()
  end)

  describe('externalized', function()
    it('publishes UI events', function()
      local expected = {
        {1, {['name'] = '[No Name]'}},
        {2, {['name'] = '[No Name]'}},
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
