local helpers = require('test.functional.helpers')(after_each)
local assert_log = helpers.assert_log
local clear = helpers.clear
local eq = helpers.eq
local exec_lua = helpers.exec_lua
local request = helpers.request
local retry = helpers.retry
local expect_exit = helpers.expect_exit

describe('log', function()
  local test_log_file = 'Xtest_logging'

  after_each(function()
    expect_exit('qa!')
    os.remove(test_log_file)
  end)

  it('skipped before log_init', function()
    -- This test is for _visibility_: adjust as needed, after checking for regression.
    --
    -- During startup some components may try to log before logging is setup.
    -- That should be uncommon (ideally never)--and if there are MANY such
    -- calls, that needs investigation.
    clear()
    eq(0, request('nvim__stats').log_skip)
    clear{env={CDPATH='~doesnotexist'}}
    assert(request('nvim__stats').log_skip <= 13)
  end)

  it('messages are formatted with name or test id', function()
    -- Examples:
    --    ERR 2022-05-29T12:30:03.800 T2         log_init:110: test log message
    --    ERR 2022-05-29T12:30:03.814 T2/child   log_init:110: test log message

    clear({env={
      NVIM_LOG_FILE=test_log_file,
      -- TODO: Can remove this after nvim_log #7062 is merged.
      __NVIM_TEST_LOG='1'
      }})

    retry(nil, nil, function()
      assert_log('T%d+\\.%d+\\.\\d +log_init:%d+: test log message', test_log_file, 100)
    end)

    exec_lua([[
      local j1 = vim.fn.jobstart({ vim.v.progpath, '-es', '-V1', '+foochild', '+qa!' }, vim.empty_dict())
      vim.fn.jobwait({ j1 }, 10000)
    ]])

    -- Child Nvim spawned by jobstart() appends "/child" to parent name.
    retry(nil, nil, function()
      assert_log('T%d+/child +log_init:%d+: test log message', test_log_file, 100)
    end)
  end)
end)
