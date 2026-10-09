local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local describe, it, before_each = t.describe, t.it, t.before_each

local assert_alive = n.assert_alive
local clear, eq, neq = n.clear, t.eq, t.neq
local command = n.command
local eval = n.eval
local exec_lua = n.exec_lua
local feed = n.feed
local fn = n.fn
local api = n.api
local is_os = t.is_os
local matches = t.matches
local pcall_err = t.pcall_err

describe('API', function()
  before_each(clear)

  local testinfo = {
    stream = 'stdio',
    id = 1,
    mode = 'rpc',
    client = {},
    detach = false,
  }
  local stderr = {
    stream = 'stderr',
    id = 2,
    mode = 'bytes',
  }

  describe('nvim_chan_set', function()
    before_each(function()
      command('autocmd ChanOpen * let g:opened_event = deepcopy(v:event)')
      command('autocmd ChanInfo * let g:info_event = deepcopy(v:event)')
    end)

    it('validation', function()
      eq("Invalid 'detach': expected boolean", pcall_err(api.nvim_chan_set, 0, { detach = 'foo' }))
      eq("Invalid 'chan': 99", pcall_err(api.nvim_chan_set, 99, {}))
      eq("Invalid 'chan': 0", pcall_err(n.exec_lua, 'vim.api.nvim_chan_set(0, {})'))
    end)

    it('works', function()
      api.nvim_chan_set(0, { detach = true })
      local info = vim.tbl_extend('force', testinfo, { detach = true })
      eq({ info = info }, api.nvim_get_var('info_event'))
      eq(info, api.nvim_get_chan_info(1))
      api.nvim_chan_set(1, { detach = false })
      eq(false, api.nvim_get_chan_info(1).detach)
    end)
  end)

  describe('channel', function()
    before_each(function()
      command('autocmd ChanOpen * let g:opened_event = deepcopy(v:event)')
      command('autocmd ChanInfo * let g:info_event = deepcopy(v:event)')
    end)

    it('nvim_get_chan_info validation', function()
      eq({}, api.nvim_get_chan_info(-1)) -- Returns {} for invalid channel.
      -- more preallocated numbers might be added, try something high
      eq({}, api.nvim_get_chan_info(10))
    end)

    it('stream=stdio channel', function()
      eq({ [1] = testinfo, [2] = stderr }, api.nvim_list_chans())
      -- 0 should return current channel
      eq(testinfo, api.nvim_get_chan_info(0))
      eq(testinfo, api.nvim_get_chan_info(1))
      eq(stderr, api.nvim_get_chan_info(2))

      api.nvim_set_client_info(
        'functionaltests',
        { major = 0, minor = 3, patch = 17 },
        'ui',
        { do_stuff = { n_args = { 2, 3 } } },
        { license = 'Apache2' }
      )
      local info = {
        stream = 'stdio',
        id = 1,
        mode = 'rpc',
        detach = false,
        client = {
          name = 'functionaltests',
          version = { major = 0, minor = 3, patch = 17 },
          type = 'ui',
          methods = { do_stuff = { n_args = { 2, 3 } } },
          attributes = { license = 'Apache2' },
        },
      }
      eq({ info = info }, api.nvim_get_var('info_event'))
      eq({ [1] = info, [2] = stderr }, api.nvim_list_chans())
      eq(info, api.nvim_get_chan_info(1))
    end)

    it('stream=job channel', function()
      eq(3, eval("jobstart(['cat'], {'rpc': v:true})"))
      local catpath = vim.fs.normalize(eval('exepath("cat")'))
      local info = {
        stream = 'job',
        id = 3,
        argv = { catpath },
        mode = 'rpc',
        client = {},
        detach = true,
      }
      eq({ info = info }, api.nvim_get_var('opened_event'))
      eq({ [1] = testinfo, [2] = stderr, [3] = info }, api.nvim_list_chans())
      eq(info, api.nvim_get_chan_info(3))
      eval(
        'rpcrequest(3, "nvim_set_client_info", "amazing-cat", {}, "remote",'
          .. '{"nvim_command":{"n_args":1}},' -- and so on
          .. '{"description":"The Amazing Cat"})'
      )
      info = {
        stream = 'job',
        id = 3,
        argv = { catpath },
        mode = 'rpc',
        detach = true,
        client = {
          name = 'amazing-cat',
          version = { major = 0 },
          type = 'remote',
          methods = { nvim_command = { n_args = 1 } },
          attributes = { description = 'The Amazing Cat' },
        },
      }
      eq({ info = info }, api.nvim_get_var('info_event'))
      eq({ [1] = testinfo, [2] = stderr, [3] = info }, api.nvim_list_chans())

      eq(
        "Vim:Invoking 'nvim_set_current_buf' on channel 3 (amazing-cat):\nWrong type for argument 1 when calling nvim_set_current_buf, expecting Buffer",
        pcall_err(eval, 'rpcrequest(3, "nvim_set_current_buf", -1)')
      )
      eq(info, eval('rpcrequest(3, "nvim_get_chan_info", 0)'))
    end)

    local function term_channel_info(id, buffer, argv)
      return {
        stream = 'job',
        id = id,
        argv = argv,
        mode = 'terminal',
        buf = buffer,
        buffer = buffer, -- deprecated
        pty = '?',
        exitcode = -1,
      }
    end

    it('stream=job :terminal channel', function()
      Screen.new(80, 24)

      command(':terminal')
      eq(1, api.nvim_get_current_buf())
      eq(3, api.nvim_get_option_value('channel', { buf = 1 }))

      local info = term_channel_info(3, 1, { vim.fs.normalize(eval('exepath(&shell)')) })
      local event = api.nvim_get_var('opened_event')
      if not is_os('win') then
        info.pty = event.info.pty
        neq(nil, string.match(info.pty, '^/dev/'))
      end
      eq({ info = info }, event)
      info.buf = 1
      info.buffer = 1 -- deprecated
      eq({ [1] = testinfo, [2] = stderr, [3] = info }, api.nvim_list_chans())
      eq(info, api.nvim_get_chan_info(3))

      -- :terminal with args + running process (Nvim TUI).
      -- Don't use a shell here, so that SIGHUP handling doesn't depend on the shell.
      command('enew')
      local argv = { n.nvim_prog, '-u', 'NONE', '-i', 'NONE' }
      fn.jobstart(argv, {
        term = true,
        env = { VIMRUNTIME = os.getenv('VIMRUNTIME') },
      })
      eq(-1, eval('jobwait([&channel], 0)[0]')) -- Running?
      local expected2 = term_channel_info(4, 2, argv)
      local actual2 = eval('nvim_get_chan_info(&channel)')
      expected2.pty = actual2.pty
      eq(expected2, actual2)

      -- Make sure Nvim TUI is started (which is after registering SIGHUP handler).
      t.retry(nil, nil, function()
        matches('Nvim is open source and freely distributable', n.curbuf_contents())
      end)

      -- :terminal with args + stopped process (Nvim TUI).
      eq(1, eval('jobstop(&channel)'))
      eval('jobwait([&channel], 1000)') -- Wait.
      expected2.pty = (is_os('win') and '?' or '') -- pty stream was closed.
      -- On Unix, SIGHUP is handled by Nvim TUI, so exit code is 1.
      -- On Windows, even though Nvim TUI handles SIGHUP, it's not possible for the
      -- parent process to know that, so exit code reflects SIGHUP.
      expected2.exitcode = (is_os('win') and 129 or 1)
      eq(expected2, eval('nvim_get_chan_info(&channel)'))

      -- :terminal with args + stopped process (shell-test).
      command('enew')
      -- Use a process that doesn't read stdin, so PTY EOF can't race SIGHUP.
      argv = { n.testprg('shell-test'), 'HOLD' }
      fn.jobstart(argv, { term = true })
      t.retry(nil, nil, function()
        matches('holding %$', n.curbuf_contents())
      end)
      eq(1, eval('jobstop(&channel)'))
      eval('jobwait([&channel], 1000)') -- Wait.
      local expected3 = term_channel_info(5, 3, argv)
      expected3.pty = (is_os('win') and '?' or '') -- pty stream was closed.
      -- Exit code should reflect SIGHUP as shell-test doesn't handle it.
      expected3.exitcode = 129
      eq(expected3, eval('nvim_get_chan_info(&channel)'))
    end)
  end)

  describe('nvim_list_uis', function()
    it('returns empty if --headless', function()
      -- Test runner defaults to --headless.
      eq({}, api.nvim_list_uis())
    end)
    it('returns attached UIs', function()
      local screen = Screen.new(20, 4, { override = true })
      local expected = {
        {
          chan = 1,
          ext_cmdline = false,
          ext_hlstate = false,
          ext_linegrid = screen._options.ext_linegrid or false,
          ext_messages = false,
          ext_multigrid = false,
          ext_popupmenu = false,
          ext_tabline = false,
          ext_termcolors = false,
          ext_wildmenu = false,
          height = 4,
          override = true,
          rgb = true,
          stdin_tty = false,
          stdout_tty = false,
          term_background = '',
          term_colors = 0,
          term_name = '',
          width = 20,
        },
      }

      eq(expected, api.nvim_list_uis())

      screen:detach()
      screen = Screen.new(44, 99, { rgb = false }) -- luacheck: ignore
      expected[1].rgb = false
      expected[1].override = false
      expected[1].width = 44
      expected[1].height = 99
      eq(expected, api.nvim_list_uis())
    end)
  end)

  describe('nvim_open_term', function()
    local screen

    before_each(function()
      screen = Screen.new(100, 35)
      screen:add_extra_attr_ids {
        [100] = { background = tonumber('0xffff40'), bg_indexed = true },
        [101] = {
          background = Screen.colors.LightMagenta,
          foreground = tonumber('0x00e000'),
          fg_indexed = true,
        },
        [102] = { background = Screen.colors.LightMagenta, reverse = true },
        [103] = { background = Screen.colors.LightMagenta, bold = true, reverse = true },
        [104] = { fg_indexed = true, foreground = tonumber('0xe00000') },
        [105] = { fg_indexed = true, foreground = tonumber('0xe0e000') },
      }
    end)

    it('can batch process sequences', function()
      local b = api.nvim_create_buf(true, true)
      api.nvim_open_win(
        b,
        false,
        { width = 79, height = 31, row = 1, col = 1, relative = 'editor' }
      )
      local term = api.nvim_open_term(b, {})

      api.nvim_chan_send(term, io.open('test/functional/fixtures/smile2.cat', 'r'):read('*a'))
      screen:expect {
        grid = [[
        ^                                                                                                    |
        {1:~}{4::smile                                                                         }{1:                    }|
        {1:~}{4:                            }{100:oooo$$$$$$$$$$$$oooo}{4:                               }{1:                    }|
        {1:~}{4:                        }{100:oo$$$$$$$$$$$$$$$$$$$$$$$$o}{4:                            }{1:                    }|
        {1:~}{4:                     }{100:oo$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$o}{4:         }{100:o$}{4:   }{100:$$}{4: }{100:o$}{4:      }{1:                    }|
        {1:~}{4:     }{100:o}{4: }{100:$}{4: }{100:oo}{4:        }{100:o$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$o}{4:       }{100:$$}{4: }{100:$$}{4: }{100:$$o$}{4:     }{1:                    }|
        {1:~}{4:  }{100:oo}{4: }{100:$}{4: }{100:$}{4: "}{100:$}{4:      }{100:o$$$$$$$$$}{4:    }{100:$$$$$$$$$$$$$}{4:    }{100:$$$$$$$$$o}{4:       }{100:$$$o$$o$}{4:      }{1:                    }|
        {1:~}{4:  "}{100:$$$$$$o$}{4:     }{100:o$$$$$$$$$}{4:      }{100:$$$$$$$$$$$}{4:      }{100:$$$$$$$$$$o}{4:    }{100:$$$$$$$$}{4:       }{1:                    }|
        {1:~}{4:    }{100:$$$$$$$}{4:    }{100:$$$$$$$$$$$}{4:      }{100:$$$$$$$$$$$}{4:      }{100:$$$$$$$$$$$$$$$$$$$$$$$}{4:       }{1:                    }|
        {1:~}{4:    }{100:$$$$$$$$$$$$$$$$$$$$$$$}{4:    }{100:$$$$$$$$$$$$$}{4:    }{100:$$$$$$$$$$$$$$}{4:  """}{100:$$$}{4:         }{1:                    }|
        {1:~}{4:     "}{100:$$$}{4:""""}{100:$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$}{4:     "}{100:$$$}{4:        }{1:                    }|
        {1:~}{4:      }{100:$$$}{4:   }{100:o$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$}{4:     "}{100:$$$o}{4:      }{1:                    }|
        {1:~}{4:     }{100:o$$}{4:"   }{100:$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$}{4:       }{100:$$$o}{4:     }{1:                    }|
        {1:~}{4:     }{100:$$$}{4:    }{100:$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$}{4:" "}{100:$$$$$$ooooo$$$$o}{4:   }{1:                    }|
        {1:~}{4:    }{100:o$$$oooo$$$$$}{4:  }{100:$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$}{4:   }{100:o$$$$$$$$$$$$$$$$$}{4:  }{1:                    }|
        {1:~}{4:    }{100:$$$$$$$$}{4:"}{100:$$$$}{4:   }{100:$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$}{4:     }{100:$$$$}{4:""""""""        }{1:                    }|
        {1:~}{4:   """"       }{100:$$$$}{4:    "}{100:$$$$$$$$$$$$$$$$$$$$$$$$$$$$}{4:"      }{100:o$$$}{4:                 }{1:                    }|
        {1:~}{4:              "}{100:$$$o}{4:     """}{100:$$$$$$$$$$$$$$$$$$}{4:"}{100:$$}{4:"         }{100:$$$}{4:                  }{1:                    }|
        {1:~}{4:                }{100:$$$o}{4:          "}{100:$$}{4:""}{100:$$$$$$}{4:""""           }{100:o$$$}{4:                   }{1:                    }|
        {1:~}{4:                 }{100:$$$$o}{4:                                }{100:o$$$}{4:"                    }{1:                    }|
        {1:~}{4:                  "}{100:$$$$o}{4:      }{100:o$$$$$$o}{4:"}{100:$$$$o}{4:        }{100:o$$$$}{4:                      }{1:                    }|
        {1:~}{4:                    "}{100:$$$$$oo}{4:     ""}{100:$$$$o$$$$$o}{4:   }{100:o$$$$}{4:""                       }{1:                    }|
        {1:~}{4:                       ""}{100:$$$$$oooo}{4:  "}{100:$$$o$$$$$$$$$}{4:"""                          }{1:                    }|
        {1:~}{4:                          ""}{100:$$$$$$$oo}{4: }{100:$$$$$$$$$$}{4:                               }{1:                    }|
        {1:~}{4:                                  """"}{100:$$$$$$$$$$$}{4:                              }{1:                    }|
        {1:~}{4:                                      }{100:$$$$$$$$$$$$}{4:                             }{1:                    }|
        {1:~}{4:                                       }{100:$$$$$$$$$$}{4:"                             }{1:                    }|
        {1:~}{4:                                        "}{100:$$$}{4:""""                               }{1:                    }|
        {1:~}{4:                                                                               }{1:                    }|
        {1:~}{101:Press ENTER or type command to continue}{4:                                        }{1:                    }|
        {1:~}{103:term://~/config2/docs/pres//32693:vim --clean +smile         29,39          All}{1:                    }|
        {1:~}{4::call nvim__screenshot("smile2.cat")                                           }{1:                    }|
        {1:~                                                                                                   }|*2
                                                                                                            |
      ]],
      }
    end)

    it('can handle input', function()
      screen:try_resize(50, 10)
      eq(
        { 3, 2 },
        exec_lua [[
        buf = vim.api.nvim_create_buf(1,1)

        stream = ''
        do_the_echo = false
        function input(_,t1,b1,data)
          stream = stream .. data
          _G.vals = {t1, b1}
          if do_the_echo then
            vim.api.nvim_chan_send(t1, data)
          end
        end

        term = vim.api.nvim_open_term(buf, {on_input=input})
        vim.api.nvim_open_win(buf, true, {width=40, height=5, row=1, col=1, relative='editor'})
        return {term, buf}
      ]]
      )

      screen:expect {
        grid = [[
                                                          |
        {1:~}{4:^                                        }{1:         }|
        {1:~}{4:                                        }{1:         }|*4
        {1:~                                                 }|*3
                                                          |
      ]],
      }

      feed 'iba<c-x>bla'
      screen:expect {
        grid = [[
                                                          |
        {1:~}{4:^                                        }{1:         }|
        {1:~}{4:                                        }{1:         }|*4
        {1:~                                                 }|*3
        {5:-- TERMINAL --}                                    |
      ]],
      }

      eq('ba\024bla', exec_lua [[ return stream ]])
      eq({ 3, 2 }, exec_lua [[ return vals ]])

      exec_lua [[ do_the_echo = true ]]
      feed 'herrejösses!'

      screen:expect {
        grid = [[
                                                          |
        {1:~}{4:herrejösses!^                            }{1:         }|
        {1:~}{4:                                        }{1:         }|*4
        {1:~                                                 }|*3
        {5:-- TERMINAL --}                                    |
      ]],
      }
      eq('ba\024blaherrejösses!', exec_lua [[ return stream ]])
    end)

    it('parses text from the current buffer', function()
      local b = api.nvim_create_buf(true, true)
      api.nvim_buf_set_lines(b, 0, -1, true, { '\027[31mHello\000\027[0m', '\027[33mworld\027[0m' })
      api.nvim_set_current_buf(b)
      screen:expect([[
        {18:^^[}[31mHello{18:^@^[}[0m                                                                                  |
        {18:^[}[33mworld{18:^[}[0m                                                                                    |
        {1:~                                                                                                   }|*32
                                                                                                            |
      ]])
      api.nvim_open_term(b, {})
      screen:expect([[
        {104:^Hello}                                                                                               |
        {105:world}                                                                                               |
                                                                                                            |*33
      ]])
    end)

    it('in a zero-size window #42232', function()
      n.exec_lua(function()
        -- 'cmdheight' takes all rows, so the bordered float gets no text rows.
        vim.o.cmdheight = vim.o.lines
        vim.api.nvim_open_win(0, true, {
          relative = 'editor',
          row = 10,
          col = 10,
          width = 10,
          height = 10,
          hide = true,
          border = 'rounded',
        })
        assert(vim.fn.winheight(0) == 0)
        vim.api.nvim_open_term(0, {})
      end)
      assert_alive()
    end)
  end)
end)
