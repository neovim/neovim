local _h = require('test.functional.helpers')
local Screen = require('test.functional.ui.screen')
local clear, feed, execute = _h.clear, _h.feed, _h.execute
local insert = _h.insert

describe('echomsg', function()
  local screen

  local function is_in_messages(msg)
    -- XXX: Without this dummy call to :messages, the vim_command_output("messages")
    --      call below prints the truncated ("foo...bar") messages instead of the
    --      full messages. This doesn't happen in normal usage, nor with an explicit
    --      "redir => g:foo|messages|redir END|echo g:foo" command sequence, so it
    --      is presumably related to do_cmdline_cmd() in vim_command_output().
    -- execute('silent messages')

    print(_h.nvim('command_output', 'echom "foo 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560 1422971560"'))
    -- ok(_h.nvim('command_output', 'messages'))
  end

  before_each(function()
    clear()
    screen = Screen.new()
    screen:attach()
    --Some tests will exercise other 'cmdheight' values.
    _h.nvim('set_option', 'cmdheight', 1)
    --Hide the "+N :messages" notification.
    _h.nvim('set_option', 'showcmd', false)
  end)

  after_each(function()
    screen:detach()
  end)

  describe(':echomsg', function()
    it('one line does not cause scroll', function()
      execute('echom "line1, normal message"')
      screen:expect([[
      ^                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      line1, normal message                                |
      ]])
    end)

    it('2x causes 1-line scroll', function()
      execute('echom "line1 line1 line1 line1" | echom "line2 line2 line2 line2"')
      screen:expect([[
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      line1 line1 line1 line1                              |
      line2 line2 line2 line2                              |
      Press ENTER or type command to continue^             |
      ]])
    end)

    it('one very long line causes a scroll', function()
      execute('echom "line1.a line1.b line1.c line1.d line1.e line1.f line1.g line1.h line1.i line1.j line1.k line1.l line1.m line1.o line1.p line1.q line1.r line1.s "')
      screen:expect([[
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      line1.a line1.b line1.c line1.d line1.e line1.f line1|
      .g line1.h line1.i line1.j line1.k line1.l line1.m li|
      ne1.o line1.p line1.q line1.r line1.s                |
      Press ENTER or type command to continue^             |
      ]])
      is_in_messages(testline)
    end)
  end)

  describe(':echomsg!', function()
    it('one line does NOT cause scroll', function()
      execute('echom! "line1, normal message"')
      screen:expect([[
      ^                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      line1, normal message                                |
      ]])
    end)

    it('2x does NOT cause a scroll', function()
      execute('echom! "line1 line1 line1 line1" | echom! "line2 line2 line2 line2"')
      screen:expect([[
      ^                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      line2 line2 line2 line2                              |
      ]])
    end)

    it('very long line does NOT cause a scroll', function()
      local testline = 'line1.a line1.b line1.c line1.d line1.e line1.f line1.g line1.h line1.i line1.j line1.k line1.l line1.m line1.o line1.p line1.q line1.r line1.s'
      execute('echom! "'..testline..'"')
      screen:expect([[
      ^                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      line1.a line1.b line1.c....p line1.q line1.r line1.s |
      ]])
      -- execute('messages')
      is_in_messages(testline)
    end)

    it('very long line fills available cmdline space', function()
      _h.nvim('set_option', 'cmdheight', 2)
      execute('echom! "line1.a line1.b line1.c line1.d line1.e line1.f line1.g line1.h line1.i line1.j line1.k line1.l line1.m line1.o line1.p line1.q line1.r line1.s"')
      screen:expect([[
      ^                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      line1.a line1.b line1.c line1.d line1.e line1.f li...|
      e1.l line1.m line1.o line1.p line1.q line1.r line1.s |
      ]])
    end)

    it('called from a function ', function()
      _h.nvim('set_option', 'cmdheight', 2)
      execute('echom! "line1.a line1.b line1.c line1.d line1.e line1.f line1.g line1.h line1.i line1.j line1.k line1.l line1.m line1.o line1.p line1.q line1.r line1.s"')
      screen:expect([[
      ^                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      line1.a line1.b line1.c line1.d line1.e line1.f li...|
      e1.l line1.m line1.o line1.p line1.q line1.r line1.s |
      ]])
    end)
  end)
end)
