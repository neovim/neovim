-- Tests for some server->client RPC scenarios. Note that unlike with
-- `rpcnotify`, to evaluate `rpcrequest` calls we need the client event loop to
-- be running.
local helpers = require('test.functional.helpers')
local clear, nvim, eval = helpers.clear, helpers.nvim, helpers.eval
local eq, neq, run, stop = helpers.eq, helpers.neq, helpers.run, helpers.stop
local nvim_prog = helpers.nvim_prog


describe('server -> client', function()
  local cid

  before_each(function()
    clear()
    cid = nvim('get_api_info')[1]
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
    -- This tests that the following scenario won't happen:
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
    --
    -- But above scenario shoudn't happen by the way notifications are dealt in
    -- Nvim: they are only sent after there are no pending server->client
    -- request(the request stack fully unwinds). So (3) is only sent after the
    -- client returns (6).
    it('works', function()
      local expected = 300
      local notified = 0
      local function on_setup()
        eq('notified!', eval('rpcrequest('..cid..', "notify")'))
      end

      local function on_request(method)
        eq('notify', method)
        eq(1, eval('rpcnotify('..cid..', "notification")'))
        return 'notified!'
      end

      local function on_notification(method)
        eq('notification', method)
        if notified == expected then
          stop()
          return
        end
        notified = notified + 1
        eq('notified!', eval('rpcrequest('..cid..', "notify")'))
      end

      run(on_request, on_notification, on_setup)
      eq(expected, notified)
    end)
  end)

  describe('when the client is a recursive vim instance', function()
    before_each(function()
      nvim('command', "let vim = rpcstart('"..nvim_prog.."', ['-u', 'NONE', '-i', 'NONE', '--cmd', 'set noswapfile', '--embed'])")
      neq(0, eval('vim'))
    end)

    after_each(function() nvim('command', 'call rpcstop(vim)') end)

    it('can send/recieve notifications and make requests', function()
      nvim('command', "call rpcnotify(vim, 'vim_set_current_line', 'SOME TEXT')")

      -- Wait for the notification to complete.
      nvim('command', "call rpcrequest(vim, 'vim_eval', '0')")

      eq('SOME TEXT', eval("rpcrequest(vim, 'vim_get_current_line')"))
    end)

    it('can communicate buffers, tabpages, and windows', function()
      eq({3}, eval("rpcrequest(vim, 'vim_get_tabpages')"))
      eq({1}, eval("rpcrequest(vim, 'vim_get_windows')"))

      local buf = eval("rpcrequest(vim, 'vim_get_buffers')")[1]
      eq(2, buf)

      eval("rpcnotify(vim, 'buffer_set_line', "..buf..", 0, 'SOME TEXT')")
      nvim('command', "call rpcrequest(vim, 'vim_eval', '0')")  -- wait

      eq('SOME TEXT', eval("rpcrequest(vim, 'buffer_get_line', "..buf..", 0)"))

      -- Call get_line_slice(buf, range [0,0], includes start, includes end)
      eq({'SOME TEXT'}, eval("rpcrequest(vim, 'buffer_get_line_slice', "..buf..", 0, 0, 1, 1)"))
    end)

    it('returns an error if the request failed', function()
      local status, err = pcall(eval, "rpcrequest(vim, 'does-not-exist')")
      eq(false, status)
      eq(true, string.match(err, ': (.*)') == 'Failed to evaluate expression')
    end)
  end)
end)
