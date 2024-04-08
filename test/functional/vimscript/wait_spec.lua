local t = require('test.functional.testutil')(after_each)
local call = t.call
local clear = t.clear
local command = t.command
local eval = t.eval
local eq = t.eq
local feed = t.feed
local feed_command = t.feed_command
local next_msg = t.next_msg
local api = t.api
local source = t.source
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
end)
