-- Test server -> client RPC scenarios. Note: unlike `rpcnotify`, to evaluate
-- `rpcrequest` calls we need the client event loop to be running.
local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear, eval = n.clear, n.eval
local eq, neq, run, stop = t.eq, t.neq, n.run, n.stop
local nvim_prog, command, fn = n.nvim_prog, n.command, n.fn
local source, next_msg = n.source, n.next_msg
local ok = t.ok
local api = n.api
local spawn, merge_args = n.spawn, n.merge_args
local set_session = n.set_session
local pcall_err = t.pcall_err
local assert_alive = n.assert_alive

describe('server -> client', function()
  local cid

  before_each(function()
    clear()
    cid = api.nvim_get_chan_info(0).id
  end)

  it('handles unexpected closed stream while preparing RPC response', function()
    source([[
      let g:_nvim_args = [v:progpath, '--embed', '--headless', '-n', '-u', 'NONE', '-i', 'NONE', ]
      let ch1 = jobstart(g:_nvim_args, {'rpc': v:true})
      let child1_ch = rpcrequest(ch1, "nvim_get_chan_info", 0).id
      call rpcnotify(ch1, 'nvim_eval', 'rpcrequest('.child1_ch.', "nvim_get_api_info")')

      let ch2 = jobstart(g:_nvim_args, {'rpc': v:true})
      let child2_ch = rpcrequest(ch2, "nvim_get_chan_info", 0).id
      call rpcnotify(ch2, 'nvim_eval', 'rpcrequest('.child2_ch.', "nvim_get_api_info")')

      call jobstop(ch1)
    ]])
    assert_alive()
  end)

  describe('simple call', function()
    it('works', function()
      local function on_setup()
        eq({ 4, 5, 6 }, eval('rpcrequest(' .. cid .. ', "scall", 1, 2, 3)'))
        stop()
      end

      local function on_request(method, args)
        eq('scall', method)
        eq({ 1, 2, 3 }, args)
        command('let g:result = [4, 5, 6]')
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
        eq({ 1, 2, '', 3, 'asdf' }, eval('rpcrequest(' .. cid .. ', "nstring")'))
        stop()
      end

      local function on_request()
        -- No need to evaluate the args, we are only interested in
        -- a response that contains an array with an empty string.
        return { 1, 2, '', 3, 'asdf' }
      end
      run(on_request, nil, on_setup)
    end)
  end)

  describe('recursive call', function()
    it('works', function()
      local function on_setup()
        api.nvim_set_var('result1', 0)
        api.nvim_set_var('result2', 0)
        api.nvim_set_var('result3', 0)
        api.nvim_set_var('result4', 0)
        command('let g:result1 = rpcrequest(' .. cid .. ', "rcall", 2)')
        eq(4, api.nvim_get_var('result1'))
        eq(8, api.nvim_get_var('result2'))
        eq(16, api.nvim_get_var('result3'))
        eq(32, api.nvim_get_var('result4'))
        stop()
      end

      local function on_request(method, args)
        eq('rcall', method)
        local _n = unpack(args) * 2
        if _n <= 16 then
          local cmd
          if _n == 4 then
            cmd = 'let g:result2 = rpcrequest(' .. cid .. ', "rcall", ' .. _n .. ')'
          elseif _n == 8 then
            cmd = 'let g:result3 = rpcrequest(' .. cid .. ', "rcall", ' .. _n .. ')'
          elseif _n == 16 then
            cmd = 'let g:result4 = rpcrequest(' .. cid .. ', "rcall", ' .. _n .. ')'
          end
          command(cmd)
        end
        return _n
      end
      run(on_request, nil, on_setup)
    end)
  end)

  describe('requests and notifications interleaved', function()
    it('does not delay notifications during pending request', function()
      local received = false
      local function on_setup()
        eq('retval', fn.rpcrequest(cid, 'doit'))
        stop()
      end
      local function on_request(method)
        if method == 'doit' then
          fn.rpcnotify(cid, 'headsup')
          eq(true, received)
          return 'retval'
        end
      end
      local function on_notification(method)
        if method == 'headsup' then
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
        eq('notified!', eval('rpcrequest(' .. cid .. ', "notify")'))
      end

      local function on_request(method)
        if method == 'notify' then
          eq(1, eval('rpcnotify(' .. cid .. ', "notification")'))
          return 'notified!'
        elseif method == 'nested' then
          -- do some busywork, so the first request will return
          -- before this one
          for _ = 1, 5 do
            assert_alive()
          end
          eq(1, eval('rpcnotify(' .. cid .. ', "nested_done")'))
          return 'done!'
        end
      end

      local function on_notification(method)
        if method == 'notification' then
          eq('done!', eval('rpcrequest(' .. cid .. ', "nested")'))
        elseif method == 'nested_done' then
          ok(false, 'never sent', 'sent')
        end
      end

      run(on_request, on_notification, on_setup)
      -- ignore disconnect failure, otherwise detected by after_each
      clear()
    end)
  end)

  describe('recursive (child) nvim client', function()
    before_each(function()
      command(
        "let vim = rpcstart('"
          .. nvim_prog
          .. "', ['-u', 'NONE', '-i', 'NONE', '--cmd', 'set noswapfile', '--embed', '--headless'])"
      )
      neq(0, eval('vim'))
    end)

    after_each(function()
      command('call rpcstop(vim)')
    end)

    it('can send/receive notifications and make requests', function()
      command("call rpcnotify(vim, 'vim_set_current_line', 'SOME TEXT')")

      -- Wait for the notification to complete.
      command("call rpcrequest(vim, 'vim_eval', '0')")

      eq('SOME TEXT', eval("rpcrequest(vim, 'vim_get_current_line')"))
    end)

    it('can communicate buffers, tabpages, and windows', function()
      eq({ 1 }, eval("rpcrequest(vim, 'nvim_list_tabpages')"))
      -- Window IDs start at 1000 (LOWEST_WIN_ID in window.h)
      eq({ 1000 }, eval("rpcrequest(vim, 'nvim_list_wins')"))

      local buf = eval("rpcrequest(vim, 'nvim_list_bufs')")[1]
      eq(1, buf)

      eval("rpcnotify(vim, 'buffer_set_line', " .. buf .. ", 0, 'SOME TEXT')")
      command("call rpcrequest(vim, 'vim_eval', '0')") -- wait

      eq('SOME TEXT', eval("rpcrequest(vim, 'buffer_get_line', " .. buf .. ', 0)'))

      -- Call get_lines(buf, range [0,0], strict_indexing)
      eq({ 'SOME TEXT' }, eval("rpcrequest(vim, 'buffer_get_lines', " .. buf .. ', 0, 1, 1)'))
    end)

    it('returns an error if the request failed', function()
      eq(
        "Vim:Error invoking 'does-not-exist' on channel 3:\nInvalid method: does-not-exist",
        pcall_err(eval, "rpcrequest(vim, 'does-not-exist')")
      )
    end)
  end)

  describe('jobstart()', function()
    local jobid
    before_each(function()
      local channel = api.nvim_get_chan_info(0).id
      api.nvim_set_var('channel', channel)
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
      api.nvim_set_var('args', {
        nvim_prog,
        '-ll',
        'test/functional/api/rpc_fixture.lua',
        package.path,
        package.cpath,
      })
      jobid = eval('jobstart(g:args, g:job_opts)')
      neq(0, jobid)
    end)

    after_each(function()
      pcall(fn.jobstop, jobid)
    end)

    if t.skip(t.is_os('win')) then
      return
    end

    it('rpc and text stderr can be combined', function()
      local status, rv = pcall(fn.rpcrequest, jobid, 'poll')
      if not status then
        error(string.format('missing nvim Lua module? (%s)', rv))
      end
      eq('ok', rv)
      fn.rpcnotify(jobid, 'ping')
      eq({ 'notification', 'pong', {} }, next_msg())
      eq('done!', fn.rpcrequest(jobid, 'write_stderr', 'fluff\n'))
      eq({ 'notification', 'stderr', { 0, { 'fluff', '' } } }, next_msg())
      pcall(fn.rpcrequest, jobid, 'exit')
      eq({ 'notification', 'stderr', { 0, { '' } } }, next_msg())
      eq({ 'notification', 'exit', { 0, 0 } }, next_msg())
    end)
  end)

  describe('connecting to another (peer) nvim', function()
    local nvim_argv = merge_args(n.nvim_argv, { '--headless' })
    local function connect_test(server, mode, address)
      local serverpid = fn.getpid()
      local client = spawn(nvim_argv, false, nil, true)
      set_session(client)

      local clientpid = fn.getpid()
      neq(serverpid, clientpid)
      local id = fn.sockconnect(mode, address, { rpc = true })
      ok(id > 0)

      fn.rpcrequest(id, 'nvim_set_current_line', 'hello')
      local client_id = fn.rpcrequest(id, 'nvim_get_chan_info', 0).id

      set_session(server)
      eq(serverpid, fn.getpid())
      eq('hello', api.nvim_get_current_line())

      -- method calls work both ways
      fn.rpcrequest(client_id, 'nvim_set_current_line', 'howdy!')
      eq(id, fn.rpcrequest(client_id, 'nvim_get_chan_info', 0).id)

      set_session(client)
      eq(clientpid, fn.getpid())
      eq('howdy!', api.nvim_get_current_line())

      server:close()
      client:close()
    end

    it('via named pipe', function()
      local server = spawn(nvim_argv)
      set_session(server)
      local address = fn.serverlist()[1]
      local first = string.sub(address, 1, 1)
      ok(first == '/' or first == '\\')
      connect_test(server, 'pipe', address)
    end)

    it('via ipv4 address', function()
      local server = spawn(nvim_argv)
      set_session(server)
      local status, address = pcall(fn.serverstart, '127.0.0.1:')
      if not status then
        pending('no ipv4 stack')
      end
      eq('127.0.0.1:', string.sub(address, 1, 10))
      connect_test(server, 'tcp', address)
    end)

    it('via ipv6 address', function()
      local server = spawn(nvim_argv)
      set_session(server)
      local status, address = pcall(fn.serverstart, '::1:')
      if not status then
        pending('no ipv6 stack')
      end
      eq('::1:', string.sub(address, 1, 4))
      connect_test(server, 'tcp', address)
    end)

    it('via hostname', function()
      local server = spawn(nvim_argv)
      set_session(server)
      local address = fn.serverstart('localhost:')
      eq('localhost:', string.sub(address, 1, 10))
      connect_test(server, 'tcp', address)
    end)

    it('does not crash on receiving UI events', function()
      local server = spawn(nvim_argv)
      set_session(server)
      local address = fn.serverlist()[1]
      local client = spawn(nvim_argv, false, nil, true)
      set_session(client)

      local id = fn.sockconnect('pipe', address, { rpc = true })
      fn.rpcrequest(id, 'nvim_ui_attach', 80, 24, {})
      assert_alive()

      server:close()
      client:close()
    end)

    it('via stdio, with many small flushes does not crash #23781', function()
      source([[
      let chan = jobstart([v:progpath, '--embed', '--headless', '-n', '-u', 'NONE', '-i', 'NONE'], { 'rpc':v:false })
      call chansend(chan, 0Z94)
      sleep 50m
      call chansend(chan, 0Z00)
      call chansend(chan, 0Z01)
      call chansend(chan, 0ZAC)
      call chansend(chan, 0Z6E76696D5F636F6D6D616E64)
      call chansend(chan, 0Z91)
      call chansend(chan, 0ZA5)
      call chansend(chan, 0Z71616C6C21)
      let g:statuses = jobwait([chan])
      ]])
      eq(eval('g:statuses'), { 0 })
      assert_alive()
    end)
  end)

  describe('connecting to its own pipe address', function()
    it('does not deadlock', function()
      local address = fn.serverlist()[1]
      local first = string.sub(address, 1, 1)
      ok(first == '/' or first == '\\')
      local serverpid = fn.getpid()

      local id = fn.sockconnect('pipe', address, { rpc = true })

      fn.rpcrequest(id, 'nvim_set_current_line', 'hello')
      eq('hello', api.nvim_get_current_line())
      eq(serverpid, fn.rpcrequest(id, 'nvim_eval', 'getpid()'))

      eq(id, fn.rpcrequest(id, 'nvim_get_chan_info', 0).id)
    end)
  end)
end)
