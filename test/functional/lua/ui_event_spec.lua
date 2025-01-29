local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local eq = t.eq
local exec_lua = n.exec_lua
local clear = n.clear
local feed = n.feed
local fn = n.fn
local assert_log = t.assert_log
local check_close = n.check_close

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
      {5:-- INSERT --}                            |
    ]],
    }

    fn.complete(1, { 'food', 'foobar', 'foo' })
    screen:expect {
      grid = [[
      food^                                    |
      {1:~                                       }|*3
      {5:-- INSERT --}                            |
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
      {5:-- INSERT --}                            |
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
      {12:food           }{1:                         }|
      {4:foobar         }{1:                         }|
      {4:foo            }{1:                         }|
      {5:-- INSERT --}                            |
    ]],
    }
    expect_events {}
  end)

  it('does not crash on exit', function()
    local p = n.spawn_wait(
      '--cmd',
      [[ lua ns = vim.api.nvim_create_namespace 'testspace' ]],
      '--cmd',
      [[ lua vim.ui_attach(ns, {ext_popupmenu=true}, function() end) ]],
      '--cmd',
      'quitall!'
    )
    eq(0, p.status)
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
          { 'echomsg', { { 0, 'message1', 0 } } },
          { 'lua_print', { { 0, 'message2', 0 } } },
          { 'echomsg', { { 0, 'message3', 0 } } },
        },
      },
    }, actual, vim.inspect(actual))
  end)

  it('ui_refresh() activates correct capabilities without remote UI', function()
    screen:detach()
    exec_lua('vim.ui_attach(ns, { ext_cmdline = true }, on_event)')
    eq(1, n.api.nvim_get_option_value('cmdheight', {}))
    exec_lua('vim.ui_detach(ns)')
    exec_lua('vim.ui_attach(ns, { ext_messages = true }, on_event)')
    n.api.nvim_set_option_value('cmdheight', 1, {})
    screen:attach()
    eq(1, n.api.nvim_get_option_value('cmdheight', {}))
  end)

  it("ui_refresh() sets 'cmdheight' for all open tabpages with ext_messages", function()
    exec_lua('vim.cmd.tabnew()')
    exec_lua('vim.ui_attach(ns, { ext_messages = true }, on_event)')
    exec_lua('vim.cmd.tabnext()')
    eq(0, n.api.nvim_get_option_value('cmdheight', {}))
  end)

  it('avoids recursive flushing and invalid memory access with :redraw', function()
    exec_lua([[
      _G.cmdline = 0
      vim.ui_attach(ns, { ext_messages = true }, function(ev)
        if ev == 'msg_show' then
          vim.schedule(function() vim.cmd.redraw() end)
        elseif ev:find('cmdline') then
          _G.cmdline = _G.cmdline + (ev == 'cmdline_show' and 1 or 0)
          vim.api.nvim_buf_set_lines(0, 0, -1, false, { tostring(_G.cmdline) })
          vim.cmd('redraw')
        end
      end
    )]])
    screen:expect([[
      ^                                        |
      {1:~                                       }|*4
    ]])
    feed(':')
    screen:expect({
      grid = [[
        ^1                                       |
        {1:~                                       }|*4
      ]],
      cmdline = { {
        content = { { '' } },
        firstc = ':',
        pos = 0,
      } },
    })
    feed('version<CR><CR>v<Esc>')
    screen:expect({
      grid = [[
        ^2                                       |
        {1:~                                       }|*4
      ]],
      cmdline = { { abort = false } },
    })
    feed([[:call confirm("Save changes?", "&Yes\n&No\n&Cancel")<CR>]])
    screen:expect({
      grid = [[
        ^4                                       |
        {1:~                                       }|*4
      ]],
      cmdline = {
        {
          content = { { '' } },
          hl_id = 10,
          pos = 0,
          prompt = '[Y]es, (N)o, (C)ancel: ',
        },
      },
      messages = {
        {
          content = { { '\nSave changes?\n', 6, 10 } },
          history = false,
          kind = 'confirm',
        },
      },
    })
    feed('n')
    screen:expect({
      grid = [[
        ^4                                       |
        {1:~                                       }|*4
      ]],
      cmdline = { { abort = false } },
    })
  end)

  it("preserved 'incsearch/command' screen state after :redraw from ext_cmdline", function()
    exec_lua([[
      vim.cmd.norm('ifoobar')
      vim.cmd('1split cmdline')
      local buf = vim.api.nvim_get_current_buf()
      vim.cmd.wincmd('p')
      vim.ui_attach(ns, { ext_cmdline = true }, function(event, ...)
        if event == 'cmdline_show' then
          local content = select(1, ...)
          vim.api.nvim_buf_set_lines(buf, -2, -1, false, {content[1][2]})
          vim.cmd('redraw')
        end
        return true
      end)
    ]])
    -- Updates a cmdline window
    feed(':cmdline')
    screen:expect({
      grid = [[
        cmdline                                 |
        {2:cmdline [+]                             }|
        fooba^r                                  |
        {3:[No Name] [+]                           }|
                                                |
      ]],
    })
    -- Does not clear 'incsearch' highlighting
    feed('<Esc>/foo')
    screen:expect({
      grid = [[
        foo                                     |
        {2:cmdline [+]                             }|
        {2:foo}ba^r                                  |
        {3:[No Name] [+]                           }|
                                                |
      ]],
    })
    -- Shows new cmdline state during 'inccommand'
    feed('<Esc>:%s/bar/baz')
    screen:expect({
      grid = [[
        %s/bar/baz                              |
        {2:cmdline [+]                             }|
        foo{10:ba^z}                                  |
        {3:[No Name] [+]                           }|
                                                |
      ]],
    })
  end)

  it('msg_show in fast context', function()
    exec_lua([[
    vim.ui_attach(ns, { ext_messages = true }, function(event, _, content)
      if event == "msg_show" then
        vim.api.nvim_get_runtime_file("foo", false)
        -- non-"fast-api" is not allowed in msg_show callback and should be scheduled
        local _, err = pcall(vim.api.nvim_buf_set_lines, 0, -2, -1, false, { content[1][2] })
        pcall(vim.api.nvim__redraw, { flush = true })
        vim.schedule(function()
          vim.api.nvim_buf_set_lines(0, -2, -1, false, { content[1][2], err })
        end)
      end
    end)
    ]])
    -- "fast-api" does not prevent aborting :function
    feed(':func Foo()<cr>bar<cr>endf<cr>:func Foo()<cr>')
    screen:expect({
      grid = [[
        ^E122: Function Foo already exists, add !|
         to replace it                          |
        E5560: nvim_buf_set_lines must not be ca|
        lled in a fast event context            |
        {1:~                                       }|
      ]],
      cmdline = { { abort = false } },
      messages = {
        {
          content = { { 'E122: Function Foo already exists, add ! to replace it', 9, 6 } },
          history = true,
          kind = 'emsg',
        },
      },
    })
  end)
end)

describe('vim.ui_attach', function()
  local screen
  before_each(function()
    clear({ env = { NVIM_LOG_FILE = testlog } })
    screen = Screen.new(40, 5)
  end)

  after_each(function()
    check_close()
    os.remove(testlog)
  end)

  it('error in callback is logged', function()
    exec_lua([[
      local ns = vim.api.nvim_create_namespace('testspace')
      vim.ui_attach(ns, { ext_popupmenu = true }, function() error(42) end)
    ]])
    feed('ifoo<CR>foobar<CR>fo<C-X><C-N>')
    assert_log('Error executing UI event callback: Error executing lua: .*: 42', testlog, 100)
  end)

  it('detaches after excessive errors', function()
    screen:add_extra_attr_ids({ [100] = { bold = true, foreground = Screen.colors.SeaGreen } })
    exec_lua([[
      vim.ui_attach(vim.api.nvim_create_namespace(''), { ext_messages = true }, function()
        vim.api.nvim_buf_set_lines(0, -2, -1, false, { err[1] })
      end)
    ]])
    local s1 = [[
      ^                                        |
      {1:~                                       }|*4
    ]]
    screen:expect(s1)
    feed('QQQQQQ<CR>')
    screen:expect({
      grid = [[
        {9:obal 'err' (a nil value)}                |
        {9:stack traceback:}                        |
        {9:        [string "<nvim>"]:2: in function}|
        {9: <[string "<nvim>"]:1>}                  |
        {100:Press ENTER or type command to continue}^ |
      ]],
      messages = {
        {
          content = { { 'Press ENTER or type command to continue', 100, 18 } },
          history = true,
          kind = 'return_prompt',
        },
      },
    })
    feed(':1mes clear<CR>:mes<CR>')
    screen:expect([[
                                              |
      {3:                                        }|
      {9:Excessive errors in vim.ui_attach() call}|
      {9:back from ns: 1.}                        |
      {100:Press ENTER or type command to continue}^ |
    ]])
    feed('<cr>')
    -- Also when scheduled
    exec_lua([[
      vim.ui_attach(vim.api.nvim_create_namespace(''), { ext_messages = true }, function()
        vim.schedule(function() vim.api.nvim_buf_set_lines(0, -2, -1, false, { err[1] }) end)
      end)
    ]])
    screen:expect({
      grid = s1,
      messages = {
        {
          content = {
            {
              'Error executing vim.schedule lua callback: [string "<nvim>"]:2: attempt to index global \'err\' (a nil value)\nstack traceback:\n\t[string "<nvim>"]:2: in function <[string "<nvim>"]:2>',
              9,
              6,
            },
          },
          history = true,
          kind = 'lua_error',
        },
        {
          content = {
            {
              'Error executing vim.schedule lua callback: [string "<nvim>"]:2: attempt to index global \'err\' (a nil value)\nstack traceback:\n\t[string "<nvim>"]:2: in function <[string "<nvim>"]:2>',
              9,
              6,
            },
          },
          history = true,
          kind = 'lua_error',
        },
        {
          content = { { 'Press ENTER or type command to continue', 100, 18 } },
          history = false,
          kind = 'return_prompt',
        },
      },
    })
    feed('<esc>:1mes clear<cr>:mes<cr>')
    screen:expect([[
                                              |
      {3:                                        }|
      {9:Excessive errors in vim.ui_attach() call}|
      {9:back from ns: 2.}                        |
      {100:Press ENTER or type command to continue}^ |
    ]])
  end)

  it('sourcing invalid file does not crash #32166', function()
    exec_lua([[
      local ns = vim.api.nvim_create_namespace("")
      vim.ui_attach(ns, { ext_messages = true }, function() end)
    ]])
    feed((':luafile %s<CR>'):format(testlog))
    n.assert_alive()
  end)
end)
