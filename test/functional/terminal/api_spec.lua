local helpers = require('test.functional.helpers')(after_each)
local child_session = require('test.functional.terminal.helpers')
local ok = helpers.ok

if helpers.pending_win32(pending) then return end

describe('api', function()
  local screen
  local socket_name = "Xtest_functional_api.sock"

  before_each(function()
    helpers.clear()
    os.remove(socket_name)
    screen = child_session.screen_setup(0, '["'..helpers.nvim_prog
      ..'", "-u", "NONE", "-i", "NONE", "--cmd", "'..helpers.nvim_set..'"]')
  end)
  after_each(function()
    os.remove(socket_name)
  end)

  it("qa! RPC request during insert-mode", function()
    -- Start the socket from the child nvim.
    child_session.feed_data(":echo serverstart('"..socket_name.."')\n")

    -- Wait for socket creation.
    screen:expect([[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      ]]..socket_name..[[                         |
      {3:-- TERMINAL --}                                    |
    ]])

    local socket_session1 = helpers.connect(socket_name)
    local socket_session2 = helpers.connect(socket_name)

    child_session.feed_data("i[tui] insert-mode")
    -- Wait for stdin to be processed.
    screen:expect([[
      [tui] insert-mode{1: }                                |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])

    ok(socket_session1:request("nvim_ui_attach", 42, 6, {rgb=true}))
    ok(socket_session2:request("nvim_ui_attach", 25, 30, {rgb=true}))

    socket_session1:notify("nvim_input", "\n[socket 1] this is more than 25 columns")
    socket_session2:notify("nvim_input", "\n[socket 2] input")

    screen:expect([[
      [tui] insert-mode                                 |
      [socket 1] this is more t{4:                         }|
      han 25 columns           {4:                         }|
      [socket 2] input{1: }        {4:                         }|
      {4:~                                                 }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])

    socket_session1:request("nvim_command", "qa!")
  end)
end)

