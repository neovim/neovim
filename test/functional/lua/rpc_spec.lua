local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local describe, it, before_each = t.describe, t.it, t.before_each
local api = n.api
local assert_alive = n.assert_alive
local clear = n.clear
local command = n.command
local eq = t.eq
local eval = n.eval
local exec_lua = n.exec_lua
local feed = n.feed
local matches = t.matches
local pcall_err = t.pcall_err
local retry = t.retry
local NIL = vim.NIL

describe('lua rpc', function()
  before_each(clear)

  it('vim.rpcrequest and vim.rpcnotify', function()
    exec_lua([[
      chan = vim.fn.jobstart({'cat'}, {rpc=true})
      vim.rpcrequest(chan, 'nvim_set_current_line', 'meow')
    ]])
    eq('meow', api.nvim_get_current_line())
    command("let x = [3, 'aa', v:true, v:null]")
    eq(
      true,
      exec_lua([[
      ret = vim.rpcrequest(chan, 'nvim_get_var', 'x')
      return #ret == 4 and ret[1] == 3 and ret[2] == 'aa' and ret[3] == true and ret[4] == vim.NIL
    ]])
    )
    eq({ 3, 'aa', true, NIL }, exec_lua([[return ret]]))

    eq(
      { {}, {}, false, true },
      exec_lua([[
      vim.rpcrequest(chan, 'nvim_exec', 'let xx = {}\nlet yy = []', false)
      local dict = vim.rpcrequest(chan, 'nvim_eval', 'xx')
      local list = vim.rpcrequest(chan, 'nvim_eval', 'yy')
      return {dict, list, vim.islist(dict), vim.islist(list)}
     ]])
    )

    exec_lua([[
       vim.rpcrequest(chan, 'nvim_set_var', 'aa', {})
       vim.rpcrequest(chan, 'nvim_set_var', 'bb', vim.empty_dict())
     ]])
    eq({ 1, 1 }, eval('[type(g:aa) == type([]), type(g:bb) == type({})]'))

    -- error handling
    eq({ false, 'Invalid channel: 23' }, exec_lua([[return {pcall(vim.rpcrequest, 23, 'foo')}]]))
    eq({ false, 'Invalid channel: 23' }, exec_lua([[return {pcall(vim.rpcnotify, 23, 'foo')}]]))

    eq(
      { false, 'Vim:E121: Undefined variable: foobar' },
      exec_lua([[return {pcall(vim.rpcrequest, chan, 'nvim_eval', "foobar")}]])
    )

    -- rpcnotify doesn't wait on request
    eq(
      'meow',
      exec_lua([[
      vim.rpcnotify(chan, 'nvim_set_current_line', 'foo')
      return vim.api.nvim_get_current_line()
    ]])
    )
    retry(10, nil, function()
      eq('foo', api.nvim_get_current_line())
    end)

    local screen = Screen.new(50, 7)
    exec_lua([[
      timer = vim.uv.new_timer()
      timer:start(20, 0, function ()
        -- notify ok (executed later when safe)
        vim.rpcnotify(chan, 'nvim_set_var', 'yy', {3, vim.NIL})
        -- rpcrequest an error
        vim.rpcrequest(chan, 'nvim_set_current_line', 'bork')
      end)
    ]])
    screen:expect {
      grid = [[
      {9:[string "<nvim>"]:6: E5560: rpcrequest must not be}|
      {9: called in a fast event context}                   |
      {9:stack traceback:}                                  |
      {9:        [C]: in function 'rpcrequest'}             |
      {9:        [string "<nvim>"]:6: in function <[string }|
      {9:"<nvim>"]:2>}                                      |
      {6:Press ENTER or type command to continue}^           |
    ]],
    }
    retry(10, nil, function()
      eq({ 3, NIL }, api.nvim_get_var('yy'))
    end)

    exec_lua([[timer:close()]])
  end)

  it('vim.rpcrequest timeout', function()
    -- Peer that responds to "echo" after {delay} ms with {delay}.
    exec_lua(function(addr)
      _G.responses = 0
      local server = assert(vim.uv.new_pipe())
      local client = assert(vim.uv.new_pipe())
      _G.pipes = { server, client }
      server:bind(addr)
      server:listen(1, function()
        server:accept(client)
        local function respond(id, result)
          client:write(vim.mpack.encode({ 1, id, vim.NIL, result }))
          _G.responses = _G.responses + 1
        end
        respond(0, vim.NIL) -- Unsolicited.
        client:read_start(function(_, data)
          if data then
            local req = vim.mpack.decode(data) -- [0, id, method, args]
            local delay = req[4][1]
            local timer = assert(vim.uv.new_timer())
            timer:start(delay, 0, function()
              timer:close() -- Avoid unreleased resources.
              respond(req[2], delay)
            end)
          end
        end)
      end)
      _G.chan = vim.fn.sockconnect('pipe', addr, { rpc = true })
    end, n.new_pipename())

    -- Unexpected responses (unsolicited, or after a timeout) are discarded while no request is
    -- pending, and the channel stays usable.
    local function wait_responses(count)
      exec_lua(function()
        vim.wait(1000, function()
          return _G.responses == count
        end)
      end)
      assert_alive()
    end
    wait_responses(1)
    eq(
      { false, 'Request timed out after 10 ms: echo' },
      exec_lua(function()
        return { pcall(vim.rpcrequest, _G.chan, { timeout = 10 }, 'echo', 100) }
      end)
    )
    wait_responses(2)
    eq(
      { 0, 7 },
      exec_lua(function()
        return {
          vim.rpcrequest(_G.chan, nil, 'echo', 0),
          vim.rpcrequest(_G.chan, { timeout = 1000 }, 'echo', 7),
        }
      end)
    )
    matches(
      'timeout: expected integer',
      pcall_err(exec_lua, function()
        vim.rpcrequest(_G.chan, { timeout = '1' }, 'echo', 0)
      end)
    )

    -- Release handles, else uv_loop_close() logs an error at exit (EXITFREE builds).
    exec_lua(function()
      vim.fn.chanclose(_G.chan)
      for _, pipe in ipairs(_G.pipes) do
        pipe:close()
      end
    end)
  end)
end)
