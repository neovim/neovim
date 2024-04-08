local t = require('test.functional.testutil')(after_each)
local tt = require('test.functional.terminal.testutil')
local ok = t.ok

if t.skip(t.is_os('win')) then
  return
end

describe('api', function()
  local screen
  local socket_name = './Xtest_functional_api.sock'

  before_each(function()
    t.clear()
    os.remove(socket_name)
    screen = tt.setup_child_nvim({
      '-u',
      'NONE',
      '-i',
      'NONE',
      '--cmd',
      'colorscheme vim',
      '--cmd',
      t.nvim_set .. ' notermguicolors',
    })
  end)
  after_each(function()
    os.remove(socket_name)
  end)

  it('qa! RPC request during insert-mode', function()
    screen:expect {
      grid = [[
      {1: }                                                 |
      {4:~                                                 }|*4
                                                        |
      {3:-- TERMINAL --}                                    |
    ]],
    }

    -- Start the socket from the child nvim.
    tt.feed_data(":echo serverstart('" .. socket_name .. "')\n")

    -- Wait for socket creation.
    screen:expect([[
      {1: }                                                 |
      {4:~                                                 }|*4
      ]] .. socket_name .. [[                       |
      {3:-- TERMINAL --}                                    |
    ]])

    local socket_session1 = t.connect(socket_name)
    local socket_session2 = t.connect(socket_name)

    tt.feed_data('i[tui] insert-mode')
    -- Wait for stdin to be processed.
    screen:expect([[
      [tui] insert-mode{1: }                                |
      {4:~                                                 }|*4
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])

    ok((socket_session1:request('nvim_ui_attach', 42, 6, { rgb = true })))
    ok((socket_session2:request('nvim_ui_attach', 25, 30, { rgb = true })))

    socket_session1:notify('nvim_input', '\n[socket 1] this is more than 25 columns')
    socket_session2:notify('nvim_input', '\n[socket 2] input')

    screen:expect([[
      [tui] insert-mode                                 |
      [socket 1] this is more t                         |
      han 25 columns                                    |
      [socket 2] input{1: }                                 |
      {4:~                        }                         |
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])

    socket_session1:request('nvim_command', 'qa!')
  end)
end)
