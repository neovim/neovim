-- To run this test:
--    TEST_FILE=test/functional/example_spec.lua make functionaltest

local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed = helpers.clear, helpers.feed

describe('example', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(20,5)
    screen:attach()
    screen:set_default_attr_ids( {
      [0] = {bold=true, foreground=Screen.colors.Blue},
      [1] = {bold=true, foreground=Screen.colors.Brown}
    } )
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
end)
