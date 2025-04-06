local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local assert_alive = n.assert_alive
local clear = n.clear
local feed = n.feed
local eq = t.eq
local exec_lua = n.exec_lua
local next_msg = n.next_msg
local NIL = vim.NIL
local pcall_err = t.pcall_err

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
      {9:Error in luv thread:}                              |
      {9:[NULL]}                                            |
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
      {9:Error in luv thread:}                              |
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
      {9:Error in luv callback, thread:}                    |
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

  describe('vim.*', function()
    before_each(function()
      clear()
      exec_lua [[
        Thread_Test = {}

        Thread_Test.entry_func = function(async, entry_str, args)
          local decoded_args = vim.mpack.decode(args)
          assert(loadstring(entry_str))(async, decoded_args)
        end

        function Thread_Test:do_test()
          local async
          local on_async = self.on_async
          async = vim.uv.new_async(function(ret)
            on_async(ret)
            async:close()
          end)
          local thread =
            vim.uv.new_thread(self.entry_func, async, self.entry_str, self.args)
          vim.uv.thread_join(thread)
        end

        Thread_Test.new = function(entry, on_async, ...)
          self = {}
          setmetatable(self, {__index = Thread_Test})
          self.args = vim.mpack.encode({...})
          self.entry_str = string.dump(entry)
          self.on_async = on_async
          return self
        end
      ]]
    end)

    it('is_thread', function()
      exec_lua [[
        local entry = function(async)
          async:send(vim.is_thread())
        end
        local on_async = function(ret)
          vim.rpcnotify(1, 'result', ret)
        end
        local thread_test = Thread_Test.new(entry, on_async)
        thread_test:do_test()
      ]]

      eq({ 'notification', 'result', { true } }, next_msg())
    end)

    it('uv', function()
      exec_lua [[
        local entry = function(async)
          async:send(vim.uv.version())
        end
        local on_async = function(ret)
          vim.rpcnotify(1, ret)
        end
        local thread_test = Thread_Test.new(entry, on_async)
        thread_test:do_test()
      ]]

      local msg = next_msg()
      eq('notification', msg[1])
      assert(tonumber(msg[2]) >= 72961)
    end)

    it('mpack', function()
      exec_lua [[
        local entry = function(async)
          async:send(vim.mpack.encode({33, vim.NIL, 'text'}))
        end
        local on_async = function(ret)
          vim.rpcnotify(1, 'result', vim.mpack.decode(ret))
        end
        local thread_test = Thread_Test.new(entry, on_async)
        thread_test:do_test()
      ]]

      eq({ 'notification', 'result', { { 33, NIL, 'text' } } }, next_msg())
    end)

    it('json', function()
      exec_lua [[
        local entry = function(async)
        async:send(vim.json.encode({33, vim.NIL, 'text'}))
        end
        local on_async = function(ret)
        vim.rpcnotify(1, 'result', vim.json.decode(ret))
        end
        local thread_test = Thread_Test.new(entry, on_async)
        thread_test:do_test()
      ]]

      eq({ 'notification', 'result', { { 33, NIL, 'text' } } }, next_msg())
    end)

    it('diff', function()
      exec_lua [[
        local entry = function(async)
          async:send(vim.diff('Hello\n', 'Helli\n'))
        end
        local on_async = function(ret)
          vim.rpcnotify(1, 'result', ret)
        end
        local thread_test = Thread_Test.new(entry, on_async)
        thread_test:do_test()
      ]]

      eq({
        'notification',
        'result',
        {
          table.concat({
            '@@ -1 +1 @@',
            '-Hello',
            '+Helli',
            '',
          }, '\n'),
        },
      }, next_msg())
    end)
  end)
end)

describe('threadpool', function()
  before_each(clear)

  it('is_thread', function()
    eq(false, exec_lua [[return vim.is_thread()]])

    exec_lua [[
      local work_fn = function()
        return vim.is_thread()
      end
      local after_work_fn = function(ret)
        vim.rpcnotify(1, 'result', ret)
      end
      local work = vim.uv.new_work(work_fn, after_work_fn)
      work:queue()
    ]]

    eq({ 'notification', 'result', { true } }, next_msg())
  end)

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
      {9:Error in luv thread:}                              |
      {9:Error: thread arg not support type 'table' at 1}   |
      {6:Press ENTER or type command to continue}^           |
    ]])
  end)

  describe('vim.*', function()
    before_each(function()
      clear()
      exec_lua [[
        Threadpool_Test = {}

        Threadpool_Test.work_fn = function(work_fn_str, args)
          local decoded_args = vim.mpack.decode(args)
          return assert(loadstring(work_fn_str))(decoded_args)
        end

        function Threadpool_Test:do_test()
          local work =
            vim.uv.new_work(self.work_fn, self.after_work)
          work:queue(self.work_fn_str, self.args)
        end

        Threadpool_Test.new = function(work_fn, after_work, ...)
          self = {}
          setmetatable(self, {__index = Threadpool_Test})
          self.args = vim.mpack.encode({...})
          self.work_fn_str = string.dump(work_fn)
          self.after_work = after_work
          return self
        end
      ]]
    end)

    it('uv', function()
      exec_lua [[
        local work_fn = function()
          return vim.uv.version()
        end
        local after_work_fn = function(ret)
          vim.rpcnotify(1, ret)
        end
        local threadpool_test = Threadpool_Test.new(work_fn, after_work_fn)
        threadpool_test:do_test()
      ]]

      local msg = next_msg()
      eq('notification', msg[1])
      assert(tonumber(msg[2]) >= 72961)
    end)

    it('mpack', function()
      exec_lua [[
        local work_fn = function()
          local var = vim.mpack.encode({33, vim.NIL, 'text'})
          return var
        end
        local after_work_fn = function(ret)
          vim.rpcnotify(1, 'result', vim.mpack.decode(ret))
        end
        local threadpool_test = Threadpool_Test.new(work_fn, after_work_fn)
        threadpool_test:do_test()
      ]]

      eq({ 'notification', 'result', { { 33, NIL, 'text' } } }, next_msg())
    end)

    it('json', function()
      exec_lua [[
        local work_fn = function()
          local var = vim.json.encode({33, vim.NIL, 'text'})
          return var
        end
        local after_work_fn = function(ret)
          vim.rpcnotify(1, 'result', vim.json.decode(ret))
        end
        local threadpool_test = Threadpool_Test.new(work_fn, after_work_fn)
        threadpool_test:do_test()
      ]]

      eq({ 'notification', 'result', { { 33, NIL, 'text' } } }, next_msg())
    end)

    it('work', function()
      exec_lua [[
        local work_fn = function()
          return vim.diff('Hello\n', 'Helli\n')
        end
        local after_work_fn = function(ret)
          vim.rpcnotify(1, 'result', ret)
        end
        local threadpool_test = Threadpool_Test.new(work_fn, after_work_fn)
        threadpool_test:do_test()
      ]]

      eq({
        'notification',
        'result',
        {
          table.concat({
            '@@ -1 +1 @@',
            '-Hello',
            '+Helli',
            '',
          }, '\n'),
        },
      }, next_msg())
    end)
  end)
end)
