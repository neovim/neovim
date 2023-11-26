-- Test suite for testing interactions with API bindings
local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local funcs = helpers.funcs
local meths = helpers.meths
local clear = helpers.clear
local sleep = helpers.sleep
local feed = helpers.feed
local eq = helpers.eq
local eval = helpers.eval
local matches = helpers.matches
local exec_lua = helpers.exec_lua
local retry = helpers.retry

before_each(clear)

describe('vim.uv', function()

  it('version', function()
    assert(funcs.luaeval('vim.uv.version()')>=72961, "libuv version too old")
    matches("(%d+)%.(%d+)%.(%d+)", funcs.luaeval('vim.uv.version_string()'))
  end)

  it('timer', function()
    exec_lua('vim.api.nvim_set_var("coroutine_cnt", 0)', {})

    local code=[[
      local uv = vim.uv

      local touch = 0
      local function wait(ms)
        local this = coroutine.running()
        assert(this)
        local timer = uv.new_timer()
        timer:start(ms, 0, vim.schedule_wrap(function ()
          timer:close()
          touch = touch + 1
          coroutine.resume(this)
          touch = touch + 1
          assert(touch==3)
          vim.api.nvim_set_var("coroutine_cnt_1", touch)
        end))
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
    exec_lua(code)
    retry(2, nil, function()
      sleep(50)
      eq(2, meths.get_var('coroutine_cnt'))
    end)
    eq(3, meths.get_var('coroutine_cnt_1'))
  end)

  it('is API safe', function()
    local screen = Screen.new(50,10)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue1},
      [2] = {bold = true, reverse = true},
      [3] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
      [4] = {bold = true, foreground = Screen.colors.SeaGreen4},
      [5] = {bold = true},
    })

    -- deferred API functions are disabled, as their safety can't be guaranteed
    exec_lua([[
      local timer = vim.uv.new_timer()
      timer:start(20, 0, function ()
        _G.is_fast = vim.in_fast_event()
        timer:close()
        vim.api.nvim_set_var("valid", true)
        vim.api.nvim_command("echomsg 'howdy'")
      end)
    ]])

    screen:expect([[
                                                        |
      {2:                                                  }|
      {3:Error executing luv callback:}                     |
      {3:[string "<nvim>"]:5: E5560: nvim_set_var must not }|
      {3:be called in a lua loop callback}                  |
      {3:stack traceback:}                                  |
      {3:        [C]: in function 'nvim_set_var'}           |
      {3:        [string "<nvim>"]:5: in function <[string }|
      {3:"<nvim>"]:2>}                                      |
      {4:Press ENTER or type command to continue}^           |
    ]])
    feed('<cr>')
    eq(false, eval("get(g:, 'valid', v:false)"))
    eq(true, exec_lua("return _G.is_fast"))

    -- callbacks can be scheduled to be executed in the main event loop
    -- where the entire API is available
    exec_lua([[
      local timer = vim.uv.new_timer()
      timer:start(20, 0, vim.schedule_wrap(function ()
        _G.is_fast = vim.in_fast_event()
        timer:close()
        vim.api.nvim_set_var("valid", true)
        vim.api.nvim_command("echomsg 'howdy'")
      end))
    ]])

    screen:expect([[
      ^                                                  |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      howdy                                             |
    ]])
    eq(true, eval("get(g:, 'valid', v:false)"))
    eq(false, exec_lua("return _G.is_fast"))

    -- fast (not deferred) API functions are allowed to be called directly
    exec_lua([[
      local timer = vim.uv.new_timer()
      timer:start(20, 0, function ()
        timer:close()
        -- input is queued for processing after the callback returns
        vim.api.nvim_input("isneaky")
        _G.mode = vim.api.nvim_get_mode()
      end)
    ]])
    screen:expect([[
      sneaky^                                            |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {5:-- INSERT --}                                      |
    ]])
    eq({blocking=false, mode='n'}, exec_lua("return _G.mode"))
  end)

  it("is equal to require('luv')", function()
    eq(true, exec_lua("return vim.uv == require('luv')"))
  end)
end)
