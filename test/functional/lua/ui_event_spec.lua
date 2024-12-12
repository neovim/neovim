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
    fn.system({
      n.nvim_prog,
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
    eq(0, n.eval('v:shell_error'))
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
        else
          vim.cmd.redraw()
        end
        _G.cmdline = _G.cmdline + (ev == 'cmdline_show' and 1 or 0)
      end
    )]])
    feed(':')
    n.assert_alive()
    eq(2, exec_lua('return _G.cmdline'))
    n.assert_alive()
    feed('version<CR><CR>v<Esc>')
    n.assert_alive()
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
      messages = {
        {
          content = { { 'E122: Function Foo already exists, add ! to replace it', 9, 6 } },
          kind = 'emsg',
        },
      },
    })
    -- No fast context for prompt message kinds
    feed(':%s/Function/Replacement/c<cr>')
    screen:expect({
      grid = [[
        ^E122: {10:Function} Foo already exists, add !|
         to replace it                          |
        replace with Replacement (y/n/a/q/l/^E/^|
        Y)?                                     |
        {1:~                                       }|
      ]],
      messages = {
        {
          content = { { 'replace with Replacement (y/n/a/q/l/^E/^Y)?', 6, 18 } },
          kind = 'confirm_sub',
        },
      },
    })
    feed('<esc>:call inputlist(["Select:", "One", "Two"])<cr>')
    screen:expect({
      grid = [[
        E122: {10:Function} Foo already exists, add !|
         to replace it                          |
        Type number and <Enter> or click with th|
        e mouse (q or empty cancels):           |
        {1:^~                                       }|
      ]],
      messages = {
        {
          content = { { 'Select:\nOne\nTwo\n' } },
          kind = 'list_cmd',
        },
        {
          content = { { 'Type number and <Enter> or click with the mouse (q or empty cancels): ' } },
          kind = 'number_prompt',
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
    screen:expect({
      grid = [[
        ^                                        |
        {1:~                                       }|*4
      ]],
    })
    feed('ifoo')
    screen:expect({
      grid = [[
        foo^                                     |
        {1:~                                       }|*4
      ]],
      showmode = { { '-- INSERT --', 5, 11 } },
    })
    feed('<esc>:1mes clear<cr>:mes<cr>')
    screen:expect({
      grid = [[
        foo                                     |
        {3:                                        }|
        {9:Excessive errors in vim.ui_attach() call}|
        {9:back from ns: 1.}                        |
        {100:Press ENTER or type command to continue}^ |
      ]],
    })
    feed('<cr>')
    -- Also when scheduled
    exec_lua([[
      vim.ui_attach(vim.api.nvim_create_namespace(''), { ext_messages = true }, function()
        vim.schedule(function() vim.api.nvim_buf_set_lines(0, -2, -1, false, { err[1] }) end)
      end)
    ]])
    screen:expect({
      any = 'fo^o',
      messages = {
        {
          content = {
            {
              'Error executing vim.schedule lua callback: [string "<nvim>"]:2: attempt to index global \'err\' (a nil value)\nstack traceback:\n\t[string "<nvim>"]:2: in function <[string "<nvim>"]:2>',
              9,
              6,
            },
          },
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
          kind = 'lua_error',
        },
        {
          content = { { 'Press ENTER or type command to continue', 100, 18 } },
          kind = 'return_prompt',
        },
      },
    })
    feed('<esc>:1mes clear<cr>:mes<cr>')
    screen:expect({
      grid = [[
        foo                                     |
        {3:                                        }|
        {9:Excessive errors in vim.ui_attach() call}|
        {9:back from ns: 2.}                        |
        {100:Press ENTER or type command to continue}^ |
      ]],
    })
  end)
end)
