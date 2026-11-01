local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local describe, it, before_each = t.describe, t.it, t.before_each
local assert_alive = n.assert_alive
local clear = n.clear
local feed = n.feed
local eq = t.eq
local exec_lua = n.exec_lua
local NIL = vim.NIL
local pcall_err = t.pcall_err

--- Calls `vim.*` functions in a thread. Returns the results as an mpack-encoded table.
local vim_fns = [[
  return vim.mpack.encode({
    diff = vim.diff('Hello\n', 'Helli\n'),
    is_thread = vim.is_thread(),
    json = vim.json.decode(vim.json.encode({ 33, vim.NIL, 'text' })),
    mpack = vim.mpack.decode(vim.mpack.encode({ 33, vim.NIL, 'text' })),
    path_is_url = vim._core.path_is_url('deno:/a'),
    uri = vim.uri.to_fname('file:///a') .. vim.uri_to_fname('file:///b'),
    uv = vim.uv.version() >= 72961,
  })
]]
local vim_fns_expected = {
  diff = '@@ -1 +1 @@\n-Hello\n+Helli\n',
  is_thread = true,
  json = { 33, NIL, 'text' },
  mpack = { 33, NIL, 'text' },
  path_is_url = true,
  uri = '/a/b',
  uv = true,
}

describe('thread', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(50, 10)
  end)

  it('non-string error()', function()
    exec_lua [[
      local thread = vim.uv.new_thread(function()
        error()
      end)
      vim.uv.thread_join(thread)
    ]]

    screen:expect([[
                                                        |
      {1:~                                                 }|*5
      {3:                                                  }|
      {9:Luv thread:}                                       |
      {9:nil}                                               |
      {6:Press ENTER or type command to continue}^           |
    ]])
    feed('<cr>')
    assert_alive()
  end)

  it('entry func is executed in protected mode', function()
    exec_lua [[
      local thread = vim.uv.new_thread(function()
        error('Error in thread entry func')
      end)
      vim.uv.thread_join(thread)
    ]]

    screen:expect([[
                                                        |
      {1:~                                                 }|*5
      {3:                                                  }|
      {9:Luv thread:}                                       |
      {9:[string "<nvim>"]:2: Error in thread entry func}   |
      {6:Press ENTER or type command to continue}^           |
    ]])
    feed('<cr>')
    assert_alive()
  end)

  it('callback is executed in protected mode', function()
    exec_lua [[
      local thread = vim.uv.new_thread(function()
        local timer = vim.uv.new_timer()
        local function ontimeout()
          timer:stop()
          timer:close()
          error('Error in thread callback')
        end
        timer:start(10, 0, ontimeout)
        vim.uv.run()
      end)
      vim.uv.thread_join(thread)
    ]]

    screen:expect([[
                                                        |
      {1:~                                                 }|*5
      {3:                                                  }|
      {9:Luv callback, thread:}                             |
      {9:[string "<nvim>"]:6: Error in thread callback}     |
      {6:Press ENTER or type command to continue}^           |
    ]])
    feed('<cr>')
    assert_alive()
  end)

  describe('print', function()
    it('works', function()
      exec_lua [[
        local thread = vim.uv.new_thread(function()
          print('print in thread')
        end)
        vim.uv.thread_join(thread)
      ]]

      screen:expect([[
        ^                                                  |
        {1:~                                                 }|*8
        print in thread                                   |
      ]])
    end)

    it('vim.inspect', function()
      exec_lua [[
        local thread = vim.uv.new_thread(function()
          print(vim.inspect({1,2}))
        end)
        vim.uv.thread_join(thread)
      ]]

      screen:expect([[
        ^                                                  |
        {1:~                                                 }|*8
        { 1, 2 }                                          |
      ]])
    end)
  end)

  it('vim.* functions', function()
    eq(
      vim_fns_expected,
      exec_lua(function()
        local result --- @type table?
        local async = assert(vim.uv.new_async(function(ret)
          result = vim.mpack.decode(ret)
        end))
        local thread = assert(vim.uv.new_thread(function(async_, code)
          async_:send(assert(loadstring(code))())
        end, async, vim_fns))
        vim.uv.thread_join(thread)
        vim.wait(2000, function()
          return result ~= nil
        end)
        async:close()
        return result
      end)
    )
  end)
end)

describe('threadpool', function()
  before_each(clear)

  it('with invalid argument', function()
    local status = pcall_err(
      exec_lua,
      [[
      local work = vim.uv.new_thread(function() end, function() end)
      work:queue({})
    ]]
    )

    eq([[Error: thread arg not support type 'function' at 1]], status)
  end)

  it('with invalid return value', function()
    local screen = Screen.new(50, 10)

    exec_lua [[
      local work = vim.uv.new_work(function() return {} end, function() end)
      work:queue()
    ]]

    screen:expect([[
                                                        |
      {1:~                                                 }|*5
      {3:                                                  }|
      {9:Luv thread:}                                       |
      {9:Error: thread arg not support type 'table' at 1}   |
      {6:Press ENTER or type command to continue}^           |
    ]])
  end)

  it('vim.* functions', function()
    eq(false, exec_lua('return vim.is_thread()'))
    eq(
      vim_fns_expected,
      exec_lua(function()
        local result --- @type table?
        local work = vim.uv.new_work(function(code)
          return assert(loadstring(code))()
        end, function(ret)
          result = vim.mpack.decode(ret)
        end)
        work:queue(vim_fns)
        vim.wait(2000, function()
          return result ~= nil
        end)
        return result
      end)
    )
  end)
end)
