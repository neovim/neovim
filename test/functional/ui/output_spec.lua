local session = require('test.functional.helpers')(after_each)
local child_session = require('test.functional.terminal.helpers')

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
    screen:detach()
  end)

  it("displays output even without LF/EOF. #4646 #4569 #3772", function()
    -- NOTE: We use a child nvim (within a :term buffer)
    --       to avoid triggering a UI flush.
    child_session.feed_data(":!printf foo; sleep 200\n")
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
end)
