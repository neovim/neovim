local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local call = n.call
local clear = n.clear
local command = n.command
local eval = n.eval
local eq = t.eq
local feed = n.feed
local feed_command = n.feed_command
local next_msg = n.next_msg
local api = n.api
local source = n.source
local pcall_err = t.pcall_err

before_each(function()
  clear()
  local channel = api.nvim_get_chan_info(0).id
  api.nvim_set_var('channel', channel)
end)

describe('wait()', function()
  it('waits and returns 0 when condition is satisfied', function()
    source([[
    let g:_awake = 0
    call timer_start(100, { -> nvim_command('let g:_awake = 1') })
    ]])
    eq(0, eval('g:_awake'))
    eq(0, eval('wait(1500, { -> g:_awake })'))
    eq(1, eval('g:_awake'))

    eq(0, eval('wait(0, 1)'))
  end)

  it('returns -1 on timeout', function()
    eq(-1, eval('wait(0, 0)'))
    eq(-1, eval('wait(50, 0)'))
  end)

  -- Each pass returns in under 1 ms, so its elapsed time counts as 0 ms unless the
  -- sub-millisecond remainder is carried into the next pass. The conditions give up after 1 s so
  -- that a regression fails the test instead of hanging the suite. A wait that ends early also
  -- returns -1, so the elapsed time is checked as well.
  local function wait_and_time(timeout, pending)
    local elapsed = n.exec_lua(function()
      local start = vim.uv.hrtime()
      local waited = vim.fn.wait(timeout, function()
        if vim.uv.hrtime() - start > 1e9 then
          return 1
        end
        if pending == 'close' then
          local timer = vim.uv.new_timer()
          timer:start(60000, 0, function() end)
          timer:stop()
          timer:close()
        elseif pending == 'schedule' then
          vim.schedule(function() end)
        end
        return false
      end)
      assert(waited == -1)
      return vim.uv.hrtime() - start
    end, timeout, pending)
    assert(elapsed >= timeout * 0.8e6, ('ended after %.1f ms'):format(elapsed / 1e6))
    assert(elapsed < 1e9, ('hung for %.1f ms'):format(elapsed / 1e6))
  end

  it('times out when the condition closes a libuv handle', function()
    wait_and_time(500, 'close')
  end)

  it('times out when the condition schedules a callback', function()
    wait_and_time(500, 'schedule')
  end)

  it('returns -2 when interrupted', function()
    feed_command(
      'call rpcnotify(g:channel, "ready") | ' .. 'call rpcnotify(g:channel, "wait", wait(-1, 0))'
    )
    eq({ 'notification', 'ready', {} }, next_msg())
    feed('<c-c>')
    eq({ 'notification', 'wait', { -2 } }, next_msg())
  end)

  it('returns -3 on error', function()
    command('silent! let ret = wait(-1, "error")')
    eq(-3, eval('ret'))
    command('let ret = 0 | silent! let ret = wait(-1, { -> error })')
    eq(-3, eval('ret'))
  end)

  it('evaluates the condition on given interval', function()
    source([[
    function Count()
      let g:counter += 1
      return g:counter
    endfunction
    ]])

    -- XXX: flaky (#11137)
    t.retry(nil, nil, function()
      api.nvim_set_var('counter', 0)
      eq(-1, call('wait', 20, 'Count() >= 5', 99999))
    end)

    api.nvim_set_var('counter', 0)
    eq(0, call('wait', 10000, 'Count() >= 5', 5))
    eq(5, api.nvim_get_var('counter'))
  end)

  it('validates args', function()
    eq('Vim:E475: Invalid value for argument 1', pcall_err(call, 'wait', '', 1))
    eq('Vim:E475: Invalid value for argument 3', pcall_err(call, 'wait', 0, 1, -1))
    eq('Vim:E475: Invalid value for argument 3', pcall_err(call, 'wait', 0, 1, 0))
    eq('Vim:E475: Invalid value for argument 3', pcall_err(call, 'wait', 0, 1, ''))
  end)

  it('does not leak when Nvim exits while waiting', function()
    n.expect_exit(
      500,
      source,
      [[
        call timer_start(10, {-> execute('qall!')})
        call wait(10000, 0)
      ]]
    )
  end)
end)
