local t = require('test.functional.testutil')()
local assert_log = t.assert_log
local clear = t.clear
local command = t.command
local eq = t.eq
local exec_lua = t.exec_lua
local expect_exit = t.expect_exit
local request = t.request

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

  it('messages are formatted with name or test id', function()
    -- Examples:
    --    ERR 2022-05-29T12:30:03.800 T2         log_init:110: test log message
    --    ERR 2022-05-29T12:30:03.814 T2/child   log_init:110: test log message

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
      vim.fn.jobwait({ j1 }, 10000)
    ]])

    -- Child Nvim spawned by jobstart() appends "/c" to parent name.
    assert_log('%.%d+%.%d/c +server_init:%d+: test log message', testlog, 100)
  end)
end)
