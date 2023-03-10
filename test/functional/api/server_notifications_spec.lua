local helpers = require('test.functional.helpers')(after_each)
local assert_log = helpers.assert_log
local eq, clear, eval, command, nvim, next_msg =
  helpers.eq, helpers.clear, helpers.eval, helpers.command, helpers.nvim,
  helpers.next_msg
local meths = helpers.meths
local exec_lua = helpers.exec_lua
local retry = helpers.retry
local is_ci = helpers.is_ci
local assert_alive = helpers.assert_alive
local skip = helpers.skip

local testlog = 'Xtest-server-notify-log'

describe('notify', function()
  local channel

  before_each(function()
    clear()
    channel = nvim('get_api_info')[1]
  end)

  after_each(function()
    os.remove(testlog)
  end)

  describe('passing a valid channel id', function()
    it('sends the notification/args to the corresponding channel', function()
      eval('rpcnotify('..channel..', "test-event", 1, 2, 3)')
      eq({'notification', 'test-event', {1, 2, 3}}, next_msg())
      command('au FileType lua call rpcnotify('..channel..', "lua!")')
      command('set filetype=lua')
      eq({'notification', 'lua!', {}}, next_msg())
    end)
  end)

  describe('passing 0 as the channel id', function()
    it('sends the notification/args to all subscribed channels', function()
      nvim('subscribe', 'event2')
      eval('rpcnotify(0, "event1", 1, 2, 3)')
      eval('rpcnotify(0, "event2", 4, 5, 6)')
      eval('rpcnotify(0, "event2", 7, 8, 9)')
      eq({'notification', 'event2', {4, 5, 6}}, next_msg())
      eq({'notification', 'event2', {7, 8, 9}}, next_msg())
      nvim('unsubscribe', 'event2')
      nvim('subscribe', 'event1')
      eval('rpcnotify(0, "event2", 10, 11, 12)')
      eval('rpcnotify(0, "event1", 13, 14, 15)')
      eq({'notification', 'event1', {13, 14, 15}}, next_msg())
    end)

    it('does not crash for deeply nested variable', function()
      meths.set_var('l', {})
      local nest_level = 1000
      meths.command(('call map(range(%u), "extend(g:, {\'l\': [g:l]})")'):format(nest_level - 1))
      eval('rpcnotify('..channel..', "event", g:l)')
      local msg = next_msg()
      eq('notification', msg[1])
      eq('event', msg[2])
      local act_ret = msg[3]
      local act_nest_level = 0
      while act_ret do
        if type(act_ret) == 'table' then
          local cur_act_ret = nil
          for k, v in pairs(act_ret) do
            eq(1, k)
            cur_act_ret = v
          end
          if cur_act_ret then
            act_nest_level = act_nest_level + 1
          end
          act_ret = cur_act_ret
        else
          eq(nil, act_ret)
        end
      end
      eq(nest_level, act_nest_level)
    end)
  end)

  it('unsubscribe non-existing event #8745', function()
    clear{env={
      NVIM_LOG_FILE=testlog,
    }}
    nvim('subscribe', 'event1')
    nvim('unsubscribe', 'doesnotexist')
    assert_log("tried to unsubscribe unknown event 'doesnotexist'", testlog, 10)
    nvim('unsubscribe', 'event1')
    assert_alive()
  end)

  it('cancels stale events on channel close', function()
    skip(is_ci(), 'hangs on CI #14083 #15251')
    local catchan = eval("jobstart(['cat'], {'rpc': v:true})")
    local catpath = eval('exepath("cat")')
    eq({id=catchan, argv={catpath}, stream='job', mode='rpc', client = {}}, exec_lua ([[
      vim.rpcnotify(..., "nvim_call_function", 'chanclose', {..., 'rpc'})
      vim.rpcnotify(..., "nvim_subscribe", "daily_rant")
      return vim.api.nvim_get_chan_info(...)
    ]], catchan))
    assert_alive()
    eq({false, 'Invalid channel: '..catchan},
      exec_lua ([[ return {pcall(vim.rpcrequest, ..., 'nvim_eval', '1+1')}]], catchan))
    retry(nil, 3000, function() eq({}, meths.get_chan_info(catchan)) end) -- cat be dead :(
  end)
end)
