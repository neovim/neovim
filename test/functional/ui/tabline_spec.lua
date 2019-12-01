local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, command, eq = helpers.clear, helpers.command, helpers.eq

describe('ui/ext_tabline', function()
  local screen
  local event_tabs, event_curtab

  before_each(function()
    clear()
    screen = Screen.new(25, 5)
    screen:attach({rgb=true, ext_tabline=true})
    function screen:_handle_tabline_update(curtab, tabs)
      event_curtab, event_tabs = curtab, tabs
    end
  end)

  it('publishes UI events', function()
    command("tabedit another-tab")

    local expected_tabs = {
      {tab = { id = 1 }, name = '[No Name]'},
      {tab = { id = 2 }, name = 'another-tab'},
    }
    screen:expect{grid=[[
      ^                         |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]], condition=function()
      eq({ id = 2 }, event_curtab)
      eq(expected_tabs, event_tabs)
    end}

    command("tabNext")
    screen:expect{grid=[[
      ^                         |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]], condition=function()
      eq({ id = 1 }, event_curtab)
      eq(expected_tabs, event_tabs)
    end}
  end)
end)
