local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, source = helpers.clear, helpers.feed, helpers.source
local command = helpers.command

describe("CTRL-C (mapped)", function()
  before_each(function()
    clear()
  end)

  it("interrupts :global", function()
    -- Crashes luajit.
    if helpers.skip_fragile(pending,
      os.getenv("TRAVIS") or os.getenv("APPVEYOR")) then
      return
    end

    source([[
      set nomore nohlsearch undolevels=-1
      nnoremap <C-C> <NOP>
    ]])

    command("silent edit! test/functional/fixtures/bigfile.txt")
    local screen = Screen.new(52, 6)
    screen:attach()
    screen:set_default_attr_ids({
      [0] = {foreground = Screen.colors.White,
             background = Screen.colors.Red},
      [1] = {bold = true,
             foreground = Screen.colors.SeaGreen}
    })

    screen:expect([[
      ^0000;<control>;Cc;0;BN;;;;;N;NULL;;;;               |
      0001;<control>;Cc;0;BN;;;;;N;START OF HEADING;;;;   |
      0002;<control>;Cc;0;BN;;;;;N;START OF TEXT;;;;      |
      0003;<control>;Cc;0;BN;;;;;N;END OF TEXT;;;;        |
      0004;<control>;Cc;0;BN;;;;;N;END OF TRANSMISSION;;;;|
                                                          |
    ]])

    local function test_ctrl_c(ms)
      feed(":global/^/p<CR>")
      screen:sleep(ms)
      feed("<C-C>")
      screen:expect{any="Interrupt"}
    end

    -- The test is time-sensitive. Try different sleep values.
    local ms_values = {100, 1000, 10000}
    for i, ms in ipairs(ms_values) do
      if i < #ms_values then
        local status, _ = pcall(test_ctrl_c, ms)
        if status then break end
      else  -- Call the last attempt directly.
        test_ctrl_c(ms)
      end
    end
  end)
end)
