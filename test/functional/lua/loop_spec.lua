-- Test suite for testing interactions with API bindings
local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local fn = n.fn
local api = n.api
local clear = n.clear
local sleep = vim.uv.sleep
local feed = n.feed
local eq = t.eq
local eval = n.eval
local matches = t.matches
local exec_lua = n.exec_lua
local retry = t.retry

before_each(clear)

describe('vim.uv', function()
  it('version', function()
    assert(fn.luaeval('vim.uv.version()') >= 72961, 'libuv version too old')
    matches('(%d+)%.(%d+)%.(%d+)', fn.luaeval('vim.uv.version_string()'))
  end)

  it('timer', function()
    exec_lua('vim.api.nvim_set_var("coroutine_cnt", 0)', {})

    local code = function()
      local touch = 0
      local function wait(ms)
        local this = coroutine.running()
        assert(this)
        local timer = assert(vim.uv.new_timer())
        timer:start(
          ms,
          0,
          vim.schedule_wrap(function()
            timer:close()
            touch = touch + 1
            coroutine.resume(this)
            touch = touch + 1
            assert(touch == 3)
            vim.api.nvim_set_var('coroutine_cnt_1', touch)
          end)
        )
        coroutine.yield()
        touch = touch + 1
        return touch
      end
      coroutine.wrap(function()
        local touched = wait(10)
        assert(touched == touch)
        vim.api.nvim_set_var('coroutine_cnt', touched)
      end)()
    end

    eq(0, api.nvim_get_var('coroutine_cnt'))
    exec_lua(code)
    retry(2, nil, function()
      sleep(50)
      eq(2, api.nvim_get_var('coroutine_cnt'))
    end)
    eq(3, api.nvim_get_var('coroutine_cnt_1'))
  end)

  it('is API safe', function()
    local screen = Screen.new(50, 10)
    screen:set_default_attr_ids({
      [1] = { bold = true, foreground = Screen.colors.Blue1 },
      [2] = { bold = true, reverse = true },
      [3] = { foreground = Screen.colors.Grey100, background = Screen.colors.Red },
      [4] = { bold = true, foreground = Screen.colors.SeaGreen4 },
      [5] = { bold = true },
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
      {3:Error executing callback:}                         |
      {3:[string "<nvim>"]:5: E5560: nvim_set_var must not }|
      {3:be called in a fast event context}                 |
      {3:stack traceback:}                                  |
      {3:        [C]: in function 'nvim_set_var'}           |
      {3:        [string "<nvim>"]:5: in function <[string }|
      {3:"<nvim>"]:2>}                                      |
      {4:Press ENTER or type command to continue}^           |
    ]])
    feed('<cr>')
    eq(false, eval("get(g:, 'valid', v:false)"))
    eq(true, exec_lua('return _G.is_fast'))

    -- callbacks can be scheduled to be executed in the main event loop
    -- where the entire API is available
    exec_lua(function()
      local timer = assert(vim.uv.new_timer())
      timer:start(
        20,
        0,
        vim.schedule_wrap(function()
          _G.is_fast = vim.in_fast_event()
          timer:close()
          vim.api.nvim_set_var('valid', true)
          vim.api.nvim_command("echomsg 'howdy'")
        end)
      )
    end)

    screen:expect([[
      ^                                                  |
      {1:~                                                 }|*8
      howdy                                             |
    ]])
    eq(true, eval("get(g:, 'valid', v:false)"))
    eq(false, exec_lua('return _G.is_fast'))

    -- fast (not deferred) API functions are allowed to be called directly
    exec_lua(function()
      local timer = assert(vim.uv.new_timer())
      timer:start(20, 0, function()
        timer:close()
        -- input is queued for processing after the callback returns
        vim.api.nvim_input('isneaky')
        _G.mode = vim.api.nvim_get_mode()
      end)
    end)
    screen:expect([[
      sneaky^                                            |
      {1:~                                                 }|*8
      {5:-- INSERT --}                                      |
    ]])
    eq({ blocking = false, mode = 'n' }, exec_lua('return _G.mode'))

    exec_lua(function()
      local timer = assert(vim.uv.new_timer())
      timer:start(20, 0, function()
        _G.is_fast = vim.in_fast_event()
        timer:close()
        _G.value = vim.fn.has('nvim-0.5')
        _G.unvalue = vim.fn.has('python3')
      end)
    end)

    screen:expect({ any = [[{3:Vim:E5560: Vimscript function must not be called i}]] })
    feed('<cr>')
    eq({ 1, nil }, exec_lua('return {_G.value, _G.unvalue}'))
  end)

  it("is equal to require('luv')", function()
    eq(true, exec_lua("return vim.uv == require('luv')"))
  end)

  it('non-string error() #32595', function()
    local screen = Screen.new(50, 10)
    exec_lua(function()
      local timer = assert(vim.uv.new_timer())
      timer:start(0, 0, function()
        timer:close()
        error(nil)
      end)
    end)
    local s = [[
                                                        |
      {1:~                                                 }|*5
      {3:                                                  }|
      {9:Error executing callback:}                         |
      {9:[NULL]}                                            |
      {6:Press ENTER or type command to continue}^           |
    ]]
    screen:expect(s)
    feed('<cr>')
    n.assert_alive()
    screen:expect([[
      ^                                                  |
      {1:~                                                 }|*8
                                                        |
    ]])
    exec_lua(function()
      vim.uv.fs_stat('non-existent-file', function()
        error(nil)
      end)
    end)
    screen:expect(s)
    feed('<cr>')
    n.assert_alive()
  end)

  it("doesn't crash on async callbacks throwing nil error", function()
    local screen = Screen.new(50, 4)

    exec_lua(function()
      _G.idle = vim.uv.new_idle()
      _G.idle:start(function()
        _G.idle:stop()
        error()
      end)
    end)

    screen:expect([[
      {3:                                                  }|
      {9:Error executing callback:}                         |
      {9:[NULL]}                                            |
      {6:Press ENTER or type command to continue}^           |
    ]])
    feed('<cr>')

    exec_lua(function()
      _G.idle:close()
    end)
  end)

  it("doesn't crash on async callbacks throwing object as an error", function()
    local screen = Screen.new(50, 4)

    exec_lua(function()
      _G.idle = vim.uv.new_idle()
      _G.idle:start(function()
        _G.idle:stop()
        error(_G.idle) -- userdata with __tostring method
      end)
    end)

    screen:expect([[
      {3:                                                  }|
      {9:Error executing callback:}                         |
      {9:uv_idle_t: 0x{MATCH:%w+}}{MATCH: +}|
      {6:Press ENTER or type command to continue}^           |
    ]])
    feed('<cr>')

    exec_lua(function()
      _G.idle:close()
    end)
  end)
end)
