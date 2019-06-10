-- Test suite for testing interactions with API bindings
local helpers = require('test.functional.helpers')(after_each)
local funcs = helpers.funcs
local meths = helpers.meths
local clear = helpers.clear
local sleep = helpers.sleep
local eq = helpers.eq
local matches = helpers.matches

before_each(clear)

describe('vim.loop', function()

  it('version', function()
    assert(funcs.luaeval('vim.loop.version()')>=72961, "libuv version too old")
    matches("(%d+)%.(%d+)%.(%d+)", funcs.luaeval('vim.loop.version_string()'))
  end)

  it('timer', function()
    meths.execute_lua('vim.api.nvim_set_var("coroutine_cnt", 0)', {})

    local code=[[
      local loop = vim.loop

      local touch = 0
      local function wait(ms)
        local this = coroutine.running()
        assert(this)
        local timer = loop.new_timer()
        timer:start(ms, 0, function ()
          timer:close()
          touch = touch + 1
          coroutine.resume(this)
          touch = touch + 1
          assert(touch==3)
          vim.api.nvim_set_var("coroutine_cnt_1", touch)
        end)
        coroutine.yield()
        touch = touch + 1
        return touch
      end
      coroutine.wrap(function()
        local touched = wait(10)
        assert(touched==touch)
        vim.api.nvim_set_var("coroutine_cnt", touched)
      end)()
    ]]

    eq(0, meths.get_var('coroutine_cnt'))
    meths.execute_lua(code, {})
    sleep(20)
    eq(2, meths.get_var('coroutine_cnt'))
    eq(3, meths.get_var('coroutine_cnt_1'))
  end)
end)
