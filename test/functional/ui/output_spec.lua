local Screen = require('test.functional.ui.screen')
local session = require('test.functional.helpers')(after_each)
local child_session = require('test.functional.terminal.helpers')
local eq = session.eq
local eval = session.eval
local feed = session.feed
local iswin = session.iswin

describe("shell command :!", function()
  if session.pending_win32(pending) then return end

  local screen
  before_each(function()
    session.clear()
    screen = child_session.screen_setup(0, '["'..session.nvim_prog..
      '", "-u", "NONE", "-i", "NONE", "--cmd", "'..session.nvim_set..'"]')
    screen:expect([[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  after_each(function()
    child_session.feed_data("\3") -- Ctrl-C
    screen:detach()
  end)

  it("displays output without LF/EOF. #4646 #4569 #3772", function()
    -- NOTE: We use a child nvim (within a :term buffer)
    --       to avoid triggering a UI flush.
    child_session.feed_data(":!printf foo; sleep 200\n")
    screen:expect([[
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      :!printf foo; sleep 200                           |
      foo                                               |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it("throttles shell-command output greater than ~10KB", function()
    if os.getenv("TRAVIS") and session.os_name() == "osx" then
      pending("[Unreliable on Travis macOS.]", function() end)
      return
    end

    screen.timeout = 20000  -- Avoid false failure on slow systems.
    child_session.feed_data(
      ":!for i in $(seq 2 3000); do echo XXXXXXXXXX $i; done\n")

    -- If we observe any line starting with a dot, then throttling occurred.
    screen:expect("\n.", nil, nil, nil, true)

    -- Final chunk of output should always be displayed, never skipped.
    -- (Throttling is non-deterministic, this test is merely a sanity check.)
    screen:expect([[
      XXXXXXXXXX 2997                                   |
      XXXXXXXXXX 2998                                   |
      XXXXXXXXXX 2999                                   |
      XXXXXXXXXX 3000                                   |
                                                        |
      {10:Press ENTER or type command to continue}{1: }          |
      {3:-- TERMINAL --}                                    |
    ]])
  end)
end)

describe("shell command :!", function()
  before_each(function()
    session.clear()
  end)

  it("cat a binary file #4142", function()
    feed(":exe 'silent !cat '.shellescape(v:progpath)<CR>")
    eq(2, eval('1+1'))  -- Still alive?
  end)

  it([[display \x08 char #4142]], function()
    feed(":silent !echo \08<CR>")
    eq(2, eval('1+1'))  -- Still alive?
  end)

  it([[handles control codes]], function()
    if iswin() then
      pending('missing printf', function() end)
      return
    end
    local screen = Screen.new(50, 4)
    screen:attach()
    -- Print TAB chars. #2958
    feed([[:!printf '1\t2\t3'<CR>]])
    screen:expect([[
      ~                                                 |
      :!printf '1\t2\t3'                                |
      1       2       3                                 |
      Press ENTER or type command to continue^           |
    ]])
    feed([[<CR>]])
    -- Print BELL control code. #4338
    feed([[:!printf '\x07\x07\x07\x07text'<CR>]])
    screen:expect([[
      ~                                                 |
      :!printf '\x07\x07\x07\x07text'                   |
      ^G^G^G^Gtext                                      |
      Press ENTER or type command to continue^           |
    ]])
    feed([[<CR>]])
    -- Print BS control code.
    feed([[:echo system('printf ''\x08\n''')<CR>]])
    screen:expect([[
      ~                                                 |
      ^H                                                |
                                                        |
      Press ENTER or type command to continue^           |
    ]])
    feed([[<CR>]])
    -- Print LF control code.
    feed([[:!printf '\n'<CR>]])
    screen:expect([[
      :!printf '\n'                                     |
                                                        |
                                                        |
      Press ENTER or type command to continue^           |
    ]])
    feed([[<CR>]])
  end)
end)
