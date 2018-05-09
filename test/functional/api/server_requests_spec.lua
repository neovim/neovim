-- Test server -> client RPC scenarios. Note: unlike `rpcnotify`, to evaluate
-- `rpcrequest` calls we need the client event loop to be running.
local helpers = require('test.functional.helpers')(after_each)
local Paths = require('test.config.paths')

local clear, nvim, eval = helpers.clear, helpers.nvim, helpers.eval
local eq, neq, run, stop = helpers.eq, helpers.neq, helpers.run, helpers.stop
local nvim_prog, command, funcs = helpers.nvim_prog, helpers.command, helpers.funcs
local source, next_msg = helpers.source, helpers.next_msg
local ok = helpers.ok
local meths = helpers.meths
local spawn, nvim_argv = helpers.spawn, helpers.nvim_argv
local set_session = helpers.set_session
local expect_err = helpers.expect_err

describe('server -> client', function()
  local cid

  before_each(function()
    clear()
    cid = nvim('get_api_info')[1]
  end)

  it('handles unexpected closed stream while preparing RPC response', function()
    source([[
      let g:_nvim_args = [v:progpath, '--embed', '-n', '-u', 'NONE', '-i', 'NONE', ]
      let ch1 = jobstart(g:_nvim_args, {'rpc': v:true})
      let child1_ch = rpcrequest(ch1, "nvim_get_api_info")[0]
      call rpcnotify(ch1, 'nvim_eval', 'rpcrequest('.child1_ch.', "nvim_get_api_info")')

      let ch2 = jobstart(g:_nvim_args, {'rpc': v:true})
      let child2_ch = rpcrequest(ch2, "nvim_get_api_info")[0]
      call rpcnotify(ch2, 'nvim_eval', 'rpcrequest('.child2_ch.', "nvim_get_api_info")')

      call jobstop(ch1)
    ]])
    eq(2, eval("1+1"))  -- Still alive?
  end)

  describe('simple call', function()
    it('works', function()
      local function on_setup()
        eq({4, 5, 6}, eval('rpcrequest('..cid..', "scall", 1, 2, 3)'))
        stop()
      end

      local function on_request(method, args)
        eq('scall', method)
        eq({1, 2, 3}, args)
        nvim('command', 'let g:result = [4, 5, 6]')
        return eval('g:result')
      end
      run(on_request, nil, on_setup)
    end)
  end)

  describe('empty string handling in arrays', function()
    -- Because the msgpack encoding for an empty string was interpreted as an
    -- error, msgpack arrays with an empty string looked like
    -- [..., '', 0, ..., 0] after the conversion, regardless of the array
    -- elements following the empty string.
    it('works', function()
      local function on_setup()
        eq({1, 2, '', 3, 'asdf'}, eval('rpcrequest('..cid..', "nstring")'))
        stop()
      end

      local function on_request()
        -- No need to evaluate the args, we are only interested in
        -- a response that contains an array with an empty string.
        return {1, 2, '', 3, 'asdf'}
      end
      run(on_request, nil, on_setup)
    end)
  end)

  describe('recursive call', function()
    it('works', function()
      local function on_setup()
        nvim('set_var', 'result1', 0)
        nvim('set_var', 'result2', 0)
        nvim('set_var', 'result3', 0)
        nvim('set_var', 'result4', 0)
        nvim('command', 'let g:result1 = rpcrequest('..cid..', "rcall", 2)')
        eq(4, nvim('get_var', 'result1'))
        eq(8, nvim('get_var', 'result2'))
        eq(16, nvim('get_var', 'result3'))
        eq(32, nvim('get_var', 'result4'))
        stop()
      end

      local function on_request(method, args)
        eq('rcall', method)
        local n = unpack(args) * 2
        if n <= 16 then
          local cmd
          if n == 4 then
            cmd = 'let g:result2 = rpcrequest('..cid..', "rcall", '..n..')'
          elseif n == 8 then
            cmd = 'let g:result3 = rpcrequest('..cid..', "rcall", '..n..')'
          elseif n == 16 then
            cmd = 'let g:result4 = rpcrequest('..cid..', "rcall", '..n..')'
          end
          nvim('command', cmd)
        end
        return n
      end
      run(on_request, nil, on_setup)
    end)
  end)

  describe('requests and notifications interleaved', function()
    it('does not delay notifications during pending request', function()
      local received = false
      local function on_setup()
        eq("retval", funcs.rpcrequest(cid, "doit"))
        stop()
      end
      local function on_request(method)
        if method == "doit" then
          funcs.rpcnotify(cid, "headsup")
          eq(true,received)
          return "retval"
        end
      end
      local function on_notification(method)
        if method == "headsup" then
          received = true
        end
      end
      run(on_request, on_notification, on_setup)
    end)

    -- This tests the following scenario:
    --
    -- server->client [request     ] (1)
    -- client->server [request     ] (2) triggered by (1)
    -- server->client [notification] (3) triggered by (2)
    -- server->client [response    ] (4) response to (2)
    -- client->server [request     ] (4) triggered by (3)
    -- server->client [request     ] (5) triggered by (4)
    -- client->server [response    ] (6) response to (1)
    --
    -- If the above scenario ever happens, the client connection will be closed
    -- because (6) is returned after request (5) is sent, and nvim
    -- only deals with one server->client request at a time. (In other words,
    -- the client cannot send a response to a request that is not at the top
    -- of nvim's request stack).
    pending('will close connection if not properly synchronized', function()
      local function on_setup()
        eq('notified!', eval('rpcrequest('..cid..', "notify")'))
      end

      local function on_request(method)
        if method == "notify" then
          eq(1, eval('rpcnotify('..cid..', "notification")'))
          return 'notified!'
        elseif method == "nested" then
          -- do some busywork, so the first request will return
          -- before this one
          for _ = 1, 5 do
            eq(2, eval("1+1"))
          end
          eq(1, eval('rpcnotify('..cid..', "nested_done")'))
          return 'done!'
        end
      end

      local function on_notification(method)
        if method == "notification" then
          eq('done!', eval('rpcrequest('..cid..', "nested")'))
        elseif method == "nested_done" then
          -- this should never have been sent
          ok(false)
        end
      end

      run(on_request, on_notification, on_setup)
      -- ignore disconnect failure, otherwise detected by after_each
      clear()
    end)
  end)

  describe('recursive (child) nvim client', function()
    if os.getenv("TRAVIS") and helpers.os_name() == "osx" then
      -- XXX: Hangs Travis macOS since e9061117a5b8f195c3f26a5cb94e18ddd7752d86.
      pending("[Hangs on Travis macOS. #5002]", function() end)
      return
    end

    before_each(function()
      command("let vim = rpcstart('"..nvim_prog.."', ['-u', 'NONE', '-i', 'NONE', '--cmd', 'set noswapfile', '--embed'])")
      neq(0, eval('vim'))
    end)

    after_each(function() command('call rpcstop(vim)') end)

    it('can send/receive notifications and make requests', function()
      nvim('command', "call rpcnotify(vim, 'vim_set_current_line', 'SOME TEXT')")

      -- Wait for the notification to complete.
      nvim('command', "call rpcrequest(vim, 'vim_eval', '0')")

      eq('SOME TEXT', eval("rpcrequest(vim, 'vim_get_current_line')"))
    end)

    it('can communicate buffers, tabpages, and windows', function()
      eq({1}, eval("rpcrequest(vim, 'nvim_list_tabpages')"))
      -- Window IDs start at 1000 (LOWEST_WIN_ID in vim.h)
      eq({1000}, eval("rpcrequest(vim, 'nvim_list_wins')"))

      local buf = eval("rpcrequest(vim, 'nvim_list_bufs')")[1]
      eq(1, buf)

      eval("rpcnotify(vim, 'buffer_set_line', "..buf..", 0, 'SOME TEXT')")
      nvim('command', "call rpcrequest(vim, 'vim_eval', '0')")  -- wait

      eq('SOME TEXT', eval("rpcrequest(vim, 'buffer_get_line', "..buf..", 0)"))

      -- Call get_lines(buf, range [0,0], strict_indexing)
      eq({'SOME TEXT'}, eval("rpcrequest(vim, 'buffer_get_lines', "..buf..", 0, 1, 1)"))
    end)

    it('returns an error if the request failed', function()
      expect_err('Vim:Invalid method name',
                 eval, "rpcrequest(vim, 'does-not-exist')")
    end)
  end)

  describe('jobstart()', function()
    local jobid
    before_each(function()
      local channel = nvim('get_api_info')[1]
      nvim('set_var', 'channel', channel)
      source([[
        function! s:OnEvent(id, data, event)
          call rpcnotify(g:channel, a:event, 0, a:data)
        endfunction
        let g:job_opts = {
        \ 'on_stderr': function('s:OnEvent'),
        \ 'on_exit': function('s:OnEvent'),
        \ 'user': 0,
        \ 'rpc': v:true
        \ }
      ]])
      local lua_prog = Paths.test_lua_prg
      meths.set_var("args", {lua_prog, 'test/functional/api/rpc_fixture.lua'})
      jobid = eval("jobstart(g:args, g:job_opts)")
      neq(0, 'jobid')
    end)

    after_each(function()
      pcall(funcs.jobstop, jobid)
    end)

    if helpers.pending_win32(pending) then return end

    it('rpc and text stderr can be combined', function()
      eq("ok",funcs.rpcrequest(jobid, "poll"))
      funcs.rpcnotify(jobid, "ping")
      eq({'notification', 'pong', {}}, next_msg())
      eq("done!",funcs.rpcrequest(jobid, "write_stderr", "fluff\n"))
      eq({'notification', 'stderr', {0, {'fluff', ''}}}, next_msg())
      pcall(funcs.rpcrequest, jobid, "exit")
      eq({'notification', 'stderr', {0, {''}}}, next_msg())
      eq({'notification', 'exit', {0, 0}}, next_msg())
    end)
  end)

  describe('connecting to another (peer) nvim', function()
    local function connect_test(server, mode, address)
      local serverpid = funcs.getpid()
      local client = spawn(nvim_argv)
      set_session(client, true)
      local clientpid = funcs.getpid()
      neq(serverpid, clientpid)
      local id = funcs.sockconnect(mode, address, {rpc=true})
      ok(id > 0)

      funcs.rpcrequest(id, 'nvim_set_current_line', 'hello')
      local client_id = funcs.rpcrequest(id, 'nvim_get_api_info')[1]

      set_session(server, true)
      eq(serverpid, funcs.getpid())
      eq('hello', meths.get_current_line())

      -- method calls work both ways
      funcs.rpcrequest(client_id, 'nvim_set_current_line', 'howdy!')
      eq(id, funcs.rpcrequest(client_id, 'nvim_get_api_info')[1])

      set_session(client, true)
      eq(clientpid, funcs.getpid())
      eq('howdy!', meths.get_current_line())

      server:close()
      client:close()
    end

    it('via named pipe', function()
      local server = spawn(nvim_argv)
      set_session(server)
      local address = funcs.serverlist()[1]
      local first = string.sub(address,1,1)
      ok(first == '/' or first == '\\')
      connect_test(server, 'pipe', address)
    end)

    it('via ipv4 address', function()
      local server = spawn(nvim_argv)
      set_session(server)
      local status, address = pcall(funcs.serverstart, "127.0.0.1:")
      if not status then
        pending('no ipv4 stack', function() end)
        return
      end
      eq('127.0.0.1:', string.sub(address,1,10))
      connect_test(server, 'tcp', address)
    end)

    it('via ipv6 address', function()
      local server = spawn(nvim_argv)
      set_session(server)
      local status, address = pcall(funcs.serverstart, '::1:')
      if not status then
        pending('no ipv6 stack', function() end)
        return
      end
      eq('::1:', string.sub(address,1,4))
      connect_test(server, 'tcp', address)
    end)

    it('via hostname', function()
      local server = spawn(nvim_argv)
      set_session(server)
      local address = funcs.serverstart("localhost:")
      eq('localhost:', string.sub(address,1,10))
      connect_test(server, 'tcp', address)
    end)
  end)

  describe('connecting to its own pipe address', function()
    it('does not deadlock', function()
      if not os.getenv("TRAVIS") and helpers.os_name() == "osx" then
        -- It does, in fact, deadlock on QuickBuild. #6851
        pending("deadlocks on QuickBuild", function() end)
        return
      end
      local address = funcs.serverlist()[1]
      local first = string.sub(address,1,1)
      ok(first == '/' or first == '\\')
      local serverpid = funcs.getpid()

      local id = funcs.sockconnect('pipe', address, {rpc=true})

      funcs.rpcrequest(id, 'nvim_set_current_line', 'hello')
      eq('hello', meths.get_current_line())
      eq(serverpid, funcs.rpcrequest(id, "nvim_eval", "getpid()"))

      eq(id, funcs.rpcrequest(id, 'nvim_get_api_info')[1])
    end)
  end)
end)
