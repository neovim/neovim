local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local eq = helpers.eq
local exec_lua = helpers.exec_lua
local clear = helpers.clear
local feed = helpers.feed
local fn = helpers.fn
local assert_log = helpers.assert_log
local check_close = helpers.check_close

local testlog = 'Xtest_lua_ui_event_log'

describe('vim.ui_attach', function()
  local screen
  before_each(function()
    clear()
    exec_lua [[
      ns = vim.api.nvim_create_namespace 'testspace'
      events = {}
      function on_event(event, ...)
        events[#events+1] = {event, ...}
        return true
      end

      function get_events()
        local ret_events = events
        events = {}
        return ret_events
      end
    ]]

    screen = Screen.new(40, 5)
    screen:set_default_attr_ids({
      [1] = { bold = true, foreground = Screen.colors.Blue1 },
      [2] = { bold = true },
      [3] = { background = Screen.colors.Grey },
      [4] = { background = Screen.colors.LightMagenta },
    })
    screen:attach()
  end)

  local function expect_events(expected)
    local evs = exec_lua 'return get_events(...)'
    eq(expected, evs, vim.inspect(evs))
  end

  it('can receive popupmenu events', function()
    exec_lua [[ vim.ui_attach(ns, {ext_popupmenu=true}, on_event) ]]
    feed('ifo')
    screen:expect {
      grid = [[
      fo^                                      |
      {1:~                                       }|*3
      {2:-- INSERT --}                            |
    ]],
    }

    fn.complete(1, { 'food', 'foobar', 'foo' })
    screen:expect {
      grid = [[
      food^                                    |
      {1:~                                       }|*3
      {2:-- INSERT --}                            |
    ]],
    }
    expect_events {
      {
        'popupmenu_show',
        { { 'food', '', '', '' }, { 'foobar', '', '', '' }, { 'foo', '', '', '' } },
        0,
        0,
        0,
        1,
      },
    }

    feed '<c-n>'
    screen:expect {
      grid = [[
      foobar^                                  |
      {1:~                                       }|*3
      {2:-- INSERT --}                            |
    ]],
    }
    expect_events {
      { 'popupmenu_select', 1 },
    }

    feed '<c-y>'
    screen:expect_unchanged()
    expect_events {
      { 'popupmenu_hide' },
    }

    -- vim.ui_detach() stops events, and reenables builtin pum immediately
    exec_lua [[
      vim.ui_detach(ns)
      vim.fn.complete(1, {'food', 'foobar', 'foo'})
    ]]

    screen:expect {
      grid = [[
      food^                                    |
      {3:food           }{1:                         }|
      {4:foobar         }{1:                         }|
      {4:foo            }{1:                         }|
      {2:-- INSERT --}                            |
    ]],
    }
    expect_events {}
  end)

  it('does not crash on exit', function()
    fn.system({
      helpers.nvim_prog,
      '-u',
      'NONE',
      '-i',
      'NONE',
      '--cmd',
      [[ lua ns = vim.api.nvim_create_namespace 'testspace' ]],
      '--cmd',
      [[ lua vim.ui_attach(ns, {ext_popupmenu=true}, function() end) ]],
      '--cmd',
      'quitall!',
    })
    eq(0, helpers.eval('v:shell_error'))
  end)

  it('can receive accurate message kinds even if they are history', function()
    exec_lua([[
    vim.cmd.echomsg("'message1'")
    print('message2')
    vim.ui_attach(ns, { ext_messages = true }, on_event)
    vim.cmd.echomsg("'message3'")
    ]])
    feed(':messages<cr>')
    feed('<cr>')

    local actual = exec_lua([[
    return vim.tbl_filter(function (event)
      return event[1] == "msg_history_show"
    end, events)
    ]])
    eq({
      {
        'msg_history_show',
        {
          { 'echomsg', { { 0, 'message1' } } },
          { '', { { 0, 'message2' } } },
          { 'echomsg', { { 0, 'message3' } } },
        },
      },
    }, actual, vim.inspect(actual))
  end)
end)

describe('vim.ui_attach', function()
  after_each(function()
    check_close()
    os.remove(testlog)
  end)

  it('error in callback is logged', function()
    clear({ env = { NVIM_LOG_FILE = testlog } })
    local screen = Screen.new()
    screen:attach()
    exec_lua([[
      local ns = vim.api.nvim_create_namespace('testspace')
      vim.ui_attach(ns, { ext_popupmenu = true }, function() error(42) end)
    ]])
    feed('ifoo<CR>foobar<CR>fo<C-X><C-N>')
    assert_log('Error executing UI event callback: Error executing lua: .*: 42', testlog, 100)
  end)
end)
