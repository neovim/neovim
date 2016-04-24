-- Tests for nvim notifications
local helpers = require('test.functional.helpers')(after_each)
local eq, clear, eval, execute, nvim, next_message =
  helpers.eq, helpers.clear, helpers.eval, helpers.execute, helpers.nvim,
  helpers.next_message
local meths = helpers.meths

describe('notify', function()
  local channel

  before_each(function()
    clear()
    channel = nvim('get_api_info')[1]
  end)

  describe('passing a valid channel id', function()
    it('sends the notification/args to the corresponding channel', function()
      eval('rpcnotify('..channel..', "test-event", 1, 2, 3)')
      eq({'notification', 'test-event', {1, 2, 3}}, next_message())
      execute('au FileType lua call rpcnotify('..channel..', "lua!")')
      execute('set filetype=lua')
      eq({'notification', 'lua!', {}}, next_message())
    end)
  end)

  describe('passing 0 as the channel id', function()
    it('sends the notification/args to all subscribed channels', function()
      nvim('subscribe', 'event2')
      eval('rpcnotify(0, "event1", 1, 2, 3)')
      eval('rpcnotify(0, "event2", 4, 5, 6)')
      eval('rpcnotify(0, "event2", 7, 8, 9)')
      eq({'notification', 'event2', {4, 5, 6}}, next_message())
      eq({'notification', 'event2', {7, 8, 9}}, next_message())
      nvim('unsubscribe', 'event2')
      nvim('subscribe', 'event1')
      eval('rpcnotify(0, "event2", 10, 11, 12)')
      eval('rpcnotify(0, "event1", 13, 14, 15)')
      eq({'notification', 'event1', {13, 14, 15}}, next_message())
    end)

    it('does not crash for deeply nested variable', function()
      meths.set_var('l', {})
      local nest_level = 1000
      meths.command(('call map(range(%u), "extend(g:, {\'l\': [g:l]})")'):format(nest_level))
      local ret = {}
      for i = 1, nest_level do
        ret = {ret}
      end
      eval('rpcnotify('..channel..', "event", g:l)')
      -- eq({'notification', 'event', ret}, next_message())
    end)
  end)
end)
