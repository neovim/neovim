local session = require('test.functional.helpers')(after_each)
local child_session = require('test.functional.terminal.helpers')
local Screen = require('test.functional.ui.screen')

if session.pending_win32(pending) then return end

describe("shell command :!", function()
  local screen
  before_each(function()
    session.clear()
    screen = child_session.screen_setup(0, '["'..session.nvim_prog..
      '", "-u", "NONE", "-i", "NONE", "--cmd", "set noswapfile"]')
    screen:expect([[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  after_each(function()
    child_session.feed_data("\3") -- Ctrl-C
    screen:detach()
  end)

  it("displays output even without LF/EOF. #4646 #4569 #3772", function()
    -- NOTE: We use a child nvim (within a :term buffer)
    --       to avoid triggering a UI flush.
    child_session.feed_data(":!printf foo; sleep 200\n")
    screen:expect([[
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
      :!printf foo; sleep 200                           |
                                                        |
      foo                                               |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it("throttles shell-command output greater than ~20KB", function()
    child_session.feed_data(
      ":!for i in $(seq 2 3000); do echo XXXXXXXXXX; done\n")
    -- If a line with only a dot "." appears, then throttling was triggered.
    screen:expect("\n.", nil, nil, nil, true)
  end)
end)
