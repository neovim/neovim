local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local tt = require('test.functional.testterm')

local assert_log = t.assert_log
local clear = n.clear
local command = n.command
local eq = t.eq
local exec_lua = n.exec_lua
local expect_exit = n.expect_exit
local request = n.request

describe('log', function()
  local testlog = 'Xtest_logging'

  after_each(function()
    expect_exit(command, 'qa!')
    os.remove(testlog)
  end)

  it('skipped before log_init', function()
    -- This test is for _visibility_: adjust as needed, after checking for regression.
    --
    -- During startup some components may try to log before logging is setup.
    -- That should be uncommon (ideally never)--and if there are MANY such
    -- calls, that needs investigation.
    clear()
    eq(0, request('nvim__stats').log_skip)
    clear { env = { CDPATH = '~doesnotexist' } }
    assert(request('nvim__stats').log_skip <= 13)
  end)

  it('TUI client name is "ui"', function()
    local function setup(env)
      clear()
      -- Start Nvim with builtin UI.
      local screen = tt.setup_child_nvim({
        '-u',
        'NONE',
        '-i',
        'NONE',
        '--cmd',
        n.nvim_set,
      }, {
        env = env,
      })
      screen:expect([[
        {1: }                                                 |
        ~                                                 |*4
                                                          |
        {3:-- TERMINAL --}                                    |
      ]])
    end

    -- Without $NVIM parent.
    setup({
      NVIM = '',
      NVIM_LISTEN_ADDRESS = '',
      NVIM_LOG_FILE = testlog,
      __NVIM_TEST_LOG = '1',
    })
    -- Example:
    --    ERR 2024-09-11T16:40:02.421 ui.47056   ui_client_run:165: test log message
    assert_log(' ui%.%d+% +ui_client_run:%d+: test log message', testlog, 100)

    -- With $NVIM parent.
    setup({
      NVIM_LOG_FILE = testlog,
      __NVIM_TEST_LOG = '1',
    })
    -- Example:
    --    ERR 2024-09-11T16:41:17.539 ui/c/T2.47826.0 ui_client_run:165: test log message
    local tid = _G._nvim_test_id
    assert_log(' ui/c/' .. tid .. '%.%d+%.%d +ui_client_run:%d+: test log message', testlog, 100)
  end)

  it('formats messages with session name or test id', function()
    -- Examples:
    --    ERR 2024-09-11T16:44:33.794 T3.49429.0 server_init:58: test log message
    --    ERR 2024-09-11T16:44:33.823 c/T3.49429.0 server_init:58: test log message

    clear({
      env = {
        NVIM_LOG_FILE = testlog,
        -- TODO: remove this after nvim_log #7062 is merged.
        __NVIM_TEST_LOG = '1',
      },
    })

    local tid = _G._nvim_test_id
    assert_log(tid .. '%.%d+%.%d +server_init:%d+: test log message', testlog, 100)

    exec_lua([[
      local j1 = vim.fn.jobstart({ vim.v.progpath, '-es', '-V1', '+foochild', '+qa!' }, vim.empty_dict())
      vim.fn.jobwait({ j1 }, 5000)
    ]])

    -- Child Nvim spawned by jobstart() prepends "c/" to parent name.
    assert_log('c/' .. tid .. '%.%d+%.%d +server_init:%d+: test log message', testlog, 100)
  end)
end)
