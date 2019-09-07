local helpers = require('test.functional.helpers')(after_each)
local call = helpers.call
local clear = helpers.clear
local command = helpers.command
local eval = helpers.eval
local eq = helpers.eq
local feed = helpers.feed
local feed_command = helpers.feed_command
local next_msg = helpers.next_msg
local nvim = helpers.nvim
local source = helpers.source
local pcall_err = helpers.pcall_err

before_each(function()
  clear()
  local channel = nvim('get_api_info')[1]
  nvim('set_var', 'channel', channel)
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
    feed_command('call rpcnotify(g:channel, "ready") | '..
                 'call rpcnotify(g:channel, "wait", wait(-1, 0))')
    eq({'notification', 'ready', {}}, next_msg())
    feed('<c-c>')
    eq({'notification', 'wait', {-2}}, next_msg())
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

    nvim('set_var', 'counter', 0)
    eq(-1, call('wait', 20, 'Count() >= 5'))

    nvim('set_var', 'counter', 0)
    eq(0, call('wait', 1000, 'Count() >= 5', 5))
    eq(5, nvim('get_var', 'counter'))
  end)

  it('validates args', function()
    eq('Vim:E475: Invalid value for argument 1', pcall_err(call, 'wait', '', 1))
    eq('Vim:E475: Invalid value for argument 3', pcall_err(call, 'wait', 0, 1, -1))
    eq('Vim:E475: Invalid value for argument 3', pcall_err(call, 'wait', 0, 1, 0))
    eq('Vim:E475: Invalid value for argument 3', pcall_err(call, 'wait', 0, 1, ''))
  end)
end)
