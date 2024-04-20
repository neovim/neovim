-- To run this test:
--    TEST_FILE=test/functional/example_spec.lua make functionaltest

local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local clear = n.clear
local command = n.command
local eq = t.eq
local feed = n.feed

describe('example', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(20, 5)
    screen:attach()
    screen:set_default_attr_ids({
      [0] = { bold = true, foreground = Screen.colors.Blue },
      [1] = { bold = true, foreground = Screen.colors.Brown },
    })
  end)

  it('screen test', function()
    -- Do some stuff.
    feed('iline1<cr>line2<esc>')

    -- For debugging only: prints the current screen.
    -- screen:snapshot_util()

    -- Assert the expected state.
    screen:expect([[
      line1               |
      line^2               |
      {0:~                   }|
      {0:~                   }|
                          |
    ]])
  end)

  it('override UI event-handler', function()
    -- Example: override the "tabline_update" UI event handler.
    --
    -- screen.lua defines default handlers for UI events, but tests
    -- may sometimes want to override a handler.

    -- The UI must declare that it wants to handle the UI events.
    -- For this example, we enable `ext_tabline`:
    screen:detach()
    screen = Screen.new(25, 5)
    screen:attach({ rgb = true, ext_tabline = true })

    -- From ":help ui" we find that `tabline_update` receives `curtab` and
    -- `tabs` objects. So we declare the UI handler like this:
    local event_tabs, event_curtab
    function screen:_handle_tabline_update(curtab, tabs)
      event_curtab, event_tabs = curtab, tabs
    end

    -- Create a tabpage...
    command('tabedit foo')

    -- Use screen:expect{condition=…} to check the result.
    screen:expect {
      condition = function()
        eq(2, event_curtab)
        eq({
          { tab = 1, name = '[No Name]' },
          { tab = 2, name = 'foo' },
        }, event_tabs)
      end,
    }
  end)
end)
