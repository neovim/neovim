-- TUI acceptance tests.
-- Uses :terminal as a way to send keys and assert screen state.
--
-- "bracketed paste" terminal feature:
-- http://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h2-Bracketed-Paste-Mode

local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local tt = require('test.functional.testterm')

local eq = t.eq
local feed_data = tt.feed_data
local clear = n.clear
local command = n.command
local exec = n.exec
local exec_lua = n.exec_lua
local testprg = n.testprg
local retry = t.retry
local nvim_prog = n.nvim_prog
local nvim_set = n.nvim_set
local ok = t.ok
local read_file = t.read_file
local fn = n.fn
local api = n.api
local is_ci = t.is_ci
local is_os = t.is_os
local new_pipename = n.new_pipename
local set_session = n.set_session
local write_file = t.write_file
local eval = n.eval
local assert_log = t.assert_log

local testlog = 'Xtest-tui-log'

describe('TUI :detach', function()
  before_each(function()
    os.remove(testlog)
  end)
  teardown(function()
    os.remove(testlog)
  end)

  it('does not stop server', function()
    local job_opts = {
      env = {
        NVIM_LOG_FILE = testlog,
      },
    }

    if is_os('win') then
      -- TODO(justinmk): on Windows,
      --    - tt.setup_child_nvim() is broken.
      --    - session.lua is broken after the pipe closes.
      -- So this test currently just exercises __NVIM_DETACH + :detach, without asserting anything.

      -- TODO(justinmk): temporary hack for Windows.
      job_opts.env['__NVIM_DETACH'] = '1'
      n.clear(job_opts)

      local screen = Screen.new(50, 10)
      n.feed('iHello, World')
      screen:expect([[
        Hello, World^                                      |
        {1:~                                                 }|*8
        {5:-- INSERT --}                                      |
      ]])

      -- local addr = api.nvim_get_vvar('servername')
      eq(1, #n.api.nvim_list_uis())

      -- TODO(justinmk): test util should not freak out when the pipe closes.
      n.expect_exit(n.command, 'detach')

      -- n.get_session():close() -- XXX: hangs
      -- n.set_session(n.connect(addr)) -- XXX: hangs
      -- eq(0, #n.api.nvim_list_uis()) -- XXX: hangs

      -- Avoid a dangling process.
      n.get_session():close('kill')
      -- n.expect_exit(n.command, 'qall!')

      return
    end

    local server_super = n.clear()
    local client_super = n.new_session(true)
    finally(function()
      server_super:close()
      client_super:close()
    end)

    local child_server = new_pipename()
    local screen = tt.setup_child_nvim({
      '--listen',
      child_server,
      '-u',
      'NONE',
      '-i',
      'NONE',
      '--cmd',
      'colorscheme vim',
      '--cmd',
      nvim_set .. ' notermguicolors laststatus=2 background=dark',
    }, job_opts)

    tt.feed_data('iHello, World')
    screen:expect {
      grid = [[
      Hello, World^                                      |
      {4:~                                                 }|*3
      {MATCH:No Name}
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]],
    }

    local child_session = n.connect(child_server)
    finally(function()
      child_session:request('nvim_command', 'qall!')
    end)
    local status, child_uis = child_session:request('nvim_list_uis')
    assert(status)
    eq(1, #child_uis)

    tt.feed_data('\027\027:detach\013')
    -- Note: "Process exited" message is misleading; tt.setup_child_nvim() sees the foreground
    -- process (client) exited, and doesn't know the server is still running?
    screen:expect {
      any = [[Process exited 0]],
    }

    child_uis --[[@type any[] ]] = ({ child_session:request('nvim_list_uis') })[2]
    eq(0, #child_uis)

    -- NOTE: The tt.setup_child_nvim() screen just wraps :terminal, it's not connected to the child.
    -- To use it again, we need to detach the old one.
    screen:detach()

    -- Edit some text on the headless server.
    status = (child_session:request('nvim_input', 'ddiWe did it, pooky.<Esc><Esc>'))
    assert(status)

    -- Test reattach by connecting a new TUI.
    local screen_reattached = tt.setup_child_nvim({
      '--remote-ui',
      '--server',
      child_server,
    }, job_opts)

    screen_reattached:expect {
      grid = [[
      We did it, pooky^.                                 |
      {4:~                                                 }|*3
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]],
    }
  end)
end)

if t.skip(is_os('win')) then
  return
end

describe('TUI', function()
  local screen --[[@type test.functional.ui.screen]]
  local child_session --[[@type test.Session]]
  local child_exec_lua

  before_each(function()
    clear()
    local child_server = new_pipename()
    screen = tt.setup_child_nvim({
      '--listen',
      child_server,
      '--clean',
      '--cmd',
      nvim_set .. ' notermguicolors laststatus=2 background=dark',
      '--cmd',
      'colorscheme vim',
    })
    screen:expect([[
      ^                                                  |
      {4:~                                                 }|*3
      {5:[No Name]                                         }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    child_session = n.connect(child_server)
    child_exec_lua = tt.make_lua_executor(child_session)
  end)

  -- Wait for mode in the child Nvim (avoid "typeahead race" #10826).
  local function wait_for_mode(mode)
    retry(nil, nil, function()
      local _, m = child_session:request('nvim_get_mode')
      eq(mode, m.mode)
    end)
  end

  -- Assert buffer contents in the child Nvim.
  local function expect_child_buf_lines(expected)
    assert(type({}) == type(expected))
    retry(nil, nil, function()
      local _, buflines = child_session:request('nvim_buf_get_lines', 0, 0, -1, false)
      eq(expected, buflines)
    end)
  end

  -- Ensure both child client and child server have processed pending events.
  local function poke_both_eventloop()
    child_exec_lua([[
      _G.termresponse = nil
      vim.api.nvim_create_autocmd('TermResponse', {
        once = true,
        callback = function(ev) _G.termresponse = ev.data.sequence end,
      })
    ]])
    feed_data('\027P0$r\027\\')
    retry(nil, nil, function()
      eq('\027P0$r', child_exec_lua('return _G.termresponse'))
    end)
  end

  it('rapid resize #7572 #7628', function()
    -- Need buffer rows to provoke the behavior.
    feed_data(':edit test/functional/fixtures/bigfile.txt\n')
    screen:expect([[
      ^0000;<control>;Cc;0;BN;;;;;N;NULL;;;;             |
      0001;<control>;Cc;0;BN;;;;;N;START OF HEADING;;;; |
      0002;<control>;Cc;0;BN;;;;;N;START OF TEXT;;;;    |
      0003;<control>;Cc;0;BN;;;;;N;END OF TEXT;;;;      |
      {5:test/functional/fixtures/bigfile.txt              }|
      :edit test/functional/fixtures/bigfile.txt        |
      {3:-- TERMINAL --}                                    |
    ]])
    command('call jobresize(b:terminal_job_id, 58, 9)')
    command('call jobresize(b:terminal_job_id, 62, 13)')
    command('call jobresize(b:terminal_job_id, 100, 42)')
    command('call jobresize(b:terminal_job_id, 37, 1000)')
    -- Resize to <5 columns.
    screen:try_resize(4, 44)
    command('call jobresize(b:terminal_job_id, 4, 1000)')
    -- Resize to 1 row, then to 1 column, then increase rows to 4.
    screen:try_resize(44, 1)
    command('call jobresize(b:terminal_job_id, 44, 1)')
    screen:try_resize(1, 1)
    command('call jobresize(b:terminal_job_id, 1, 1)')
    screen:try_resize(1, 4)
    command('call jobresize(b:terminal_job_id, 1, 4)')
    screen:try_resize(57, 17)
    command('call jobresize(b:terminal_job_id, 57, 17)')
    retry(nil, nil, function()
      eq({ true, 57 }, { child_session:request('nvim_win_get_width', 0) })
    end)
  end)

  it('accepts resize while pager is active', function()
    child_session:request(
      'nvim_exec2',
      [[
      set more
      func! ManyErr()
        for i in range(20)
          echoerr "FAIL ".i
        endfor
      endfunc
    ]],
      {}
    )
    feed_data(':call ManyErr()\r')
    screen:expect {
      grid = [[
      {8:Error detected while processing function ManyErr:} |
      {11:line    2:}                                        |
      {8:FAIL 0}                                            |
      {8:FAIL 1}                                            |
      {8:FAIL 2}                                            |
      {10:-- More --}^                                        |
      {3:-- TERMINAL --}                                    |
    ]],
    }

    screen:try_resize(50, 10)
    screen:expect {
      grid = [[
      :call ManyErr()                                   |
      {8:Error detected while processing function ManyErr:} |
      {11:line    2:}                                        |
      {8:FAIL 0}                                            |
      {8:FAIL 1}                                            |
      {8:FAIL 2}                                            |
                                                        |*2
      {10:-- More --}^                                        |
      {3:-- TERMINAL --}                                    |
    ]],
    }

    feed_data('j')
    screen:expect {
      grid = [[
      {8:Error detected while processing function ManyErr:} |
      {11:line    2:}                                        |
      {8:FAIL 0}                                            |
      {8:FAIL 1}                                            |
      {8:FAIL 2}                                            |
      {8:FAIL 3}                                            |
      {8:FAIL 4}                                            |
      {8:FAIL 5}                                            |
      {10:-- More --}^                                        |
      {3:-- TERMINAL --}                                    |
    ]],
    }

    screen:try_resize(50, 7)
    screen:expect {
      grid = [[
      {8:FAIL 1}                                            |
      {8:FAIL 2}                                            |
      {8:FAIL 3}                                            |
      {8:FAIL 4}                                            |
      {8:FAIL 5}                                            |
      {10:-- More --}^                                        |
      {3:-- TERMINAL --}                                    |
    ]],
    }

    screen:try_resize(50, 5)
    screen:expect {
      grid = [[
      {8:FAIL 3}                                            |
      {8:FAIL 4}                                            |
      {8:FAIL 5}                                            |
      {10:-- More --}^                                        |
      {3:-- TERMINAL --}                                    |
    ]],
    }

    feed_data('g')
    screen:expect {
      grid = [[
      :call ManyErr()                                   |
      {8:Error detected while processing function ManyErr:} |
      {11:line    2:}                                        |
      {10:-- More --}^                                        |
      {3:-- TERMINAL --}                                    |
    ]],
    }

    screen:try_resize(50, 10)
    screen:expect {
      grid = [[
      :call ManyErr()                                   |
      {8:Error detected while processing function ManyErr:} |
      {11:line    2:}                                        |
      {8:FAIL 0}                                            |
      {8:FAIL 1}                                            |
      {8:FAIL 2}                                            |
      {8:FAIL 3}                                            |
      {8:FAIL 4}                                            |
      {10:-- More --}^                                        |
      {3:-- TERMINAL --}                                    |
    ]],
    }

    feed_data('\003')
    screen:expect {
      grid = [[
      ^                                                  |
      {4:~                                                 }|*6
      {5:[No Name]                                         }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]],
    }
  end)

  it('accepts basic utf-8 input', function()
    feed_data('iabc\ntest1\ntest2')
    screen:expect([[
      abc                                               |
      test1                                             |
      test2^                                             |
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data('\027')
    screen:expect([[
      abc                                               |
      test1                                             |
      test^2                                             |
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('interprets leading <Esc> byte as ALT modifier in normal-mode', function()
    local keys = 'dfghjkl'
    for c in keys:gmatch('.') do
      feed_data(':nnoremap <a-' .. c .. '> ialt-' .. c .. '<cr><esc>\r')
      feed_data('\027' .. c)
    end
    screen:expect([[
      alt-j                                             |
      alt-k                                             |
      alt-l                                             |
      ^                                                  |
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data('gg')
    screen:expect([[
      ^alt-d                                             |
      alt-f                                             |
      alt-g                                             |
      alt-h                                             |
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('interprets ESC+key as ALT chord in i_CTRL-V', function()
    -- Vim represents ALT/META by setting the "high bit" of the modified key:
    -- ALT+j inserts "ê". Nvim does not (#3982).
    feed_data('i\022\027j')
    screen:expect([[
      <M-j>^                                             |
      {4:~                                                 }|*3
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('interprets <Esc>[27u as <Esc>', function()
    child_session:request(
      'nvim_exec2',
      [[
      nnoremap <M-;> <Nop>
      nnoremap <Esc> AESC<Esc>
      nnoremap ; Asemicolon<Esc>
    ]],
      {}
    )
    feed_data('\027[27u;')
    screen:expect([[
      ESCsemicolo^n                                      |
      {4:~                                                 }|*3
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <Esc>; should be recognized as <M-;> when <M-;> is mapped
    feed_data('\027;')
    screen:expect_unchanged()
  end)

  it('interprets <Esc><Nul> as <M-C-Space> #17198', function()
    feed_data('i\022\027\000')
    screen:expect([[
      <M-C-Space>^                                       |
      {4:~                                                 }|*3
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('accepts ASCII control sequences', function()
    feed_data('i')
    feed_data('\022\007') -- ctrl+g
    feed_data('\022\022') -- ctrl+v
    feed_data('\022\013') -- ctrl+m
    screen:expect([[
      {6:^G^V^M}^                                            |
      {4:~                                                 }|*3
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  local function test_mouse_wheel(esc)
    child_session:request(
      'nvim_exec2',
      [[
      set number nostartofline nowrap mousescroll=hor:1,ver:1
      call setline(1, repeat([join(range(10), '----')], 10))
      vsplit
    ]],
      {}
    )
    screen:expect([[
      {11:  1 }^0----1----2----3----4│{11:  1 }0----1----2----3----|
      {11:  2 }0----1----2----3----4│{11:  2 }0----1----2----3----|
      {11:  3 }0----1----2----3----4│{11:  3 }0----1----2----3----|
      {11:  4 }0----1----2----3----4│{11:  4 }0----1----2----3----|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <ScrollWheelDown> in active window
    if esc then
      feed_data('\027[<65;8;1M')
    else
      api.nvim_input_mouse('wheel', 'down', '', 0, 0, 7)
    end
    screen:expect([[
      {11:  2 }^0----1----2----3----4│{11:  1 }0----1----2----3----|
      {11:  3 }0----1----2----3----4│{11:  2 }0----1----2----3----|
      {11:  4 }0----1----2----3----4│{11:  3 }0----1----2----3----|
      {11:  5 }0----1----2----3----4│{11:  4 }0----1----2----3----|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <ScrollWheelDown> in inactive window
    if esc then
      feed_data('\027[<65;48;1M')
    else
      api.nvim_input_mouse('wheel', 'down', '', 0, 0, 47)
    end
    screen:expect([[
      {11:  2 }^0----1----2----3----4│{11:  2 }0----1----2----3----|
      {11:  3 }0----1----2----3----4│{11:  3 }0----1----2----3----|
      {11:  4 }0----1----2----3----4│{11:  4 }0----1----2----3----|
      {11:  5 }0----1----2----3----4│{11:  5 }0----1----2----3----|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <ScrollWheelRight> in active window
    if esc then
      feed_data('\027[<67;8;1M')
    else
      api.nvim_input_mouse('wheel', 'right', '', 0, 0, 7)
    end
    screen:expect([[
      {11:  2 }^----1----2----3----4-│{11:  2 }0----1----2----3----|
      {11:  3 }----1----2----3----4-│{11:  3 }0----1----2----3----|
      {11:  4 }----1----2----3----4-│{11:  4 }0----1----2----3----|
      {11:  5 }----1----2----3----4-│{11:  5 }0----1----2----3----|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <ScrollWheelRight> in inactive window
    if esc then
      feed_data('\027[<67;48;1M')
    else
      api.nvim_input_mouse('wheel', 'right', '', 0, 0, 47)
    end
    screen:expect([[
      {11:  2 }^----1----2----3----4-│{11:  2 }----1----2----3----4|
      {11:  3 }----1----2----3----4-│{11:  3 }----1----2----3----4|
      {11:  4 }----1----2----3----4-│{11:  4 }----1----2----3----4|
      {11:  5 }----1----2----3----4-│{11:  5 }----1----2----3----4|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <S-ScrollWheelDown> in active window
    if esc then
      feed_data('\027[<69;8;1M')
    else
      api.nvim_input_mouse('wheel', 'down', 'S', 0, 0, 7)
    end
    screen:expect([[
      {11:  5 }^----1----2----3----4-│{11:  2 }----1----2----3----4|
      {11:  6 }----1----2----3----4-│{11:  3 }----1----2----3----4|
      {11:  7 }----1----2----3----4-│{11:  4 }----1----2----3----4|
      {11:  8 }----1----2----3----4-│{11:  5 }----1----2----3----4|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <S-ScrollWheelDown> in inactive window
    if esc then
      feed_data('\027[<69;48;1M')
    else
      api.nvim_input_mouse('wheel', 'down', 'S', 0, 0, 47)
    end
    screen:expect([[
      {11:  5 }^----1----2----3----4-│{11:  5 }----1----2----3----4|
      {11:  6 }----1----2----3----4-│{11:  6 }----1----2----3----4|
      {11:  7 }----1----2----3----4-│{11:  7 }----1----2----3----4|
      {11:  8 }----1----2----3----4-│{11:  8 }----1----2----3----4|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <S-ScrollWheelRight> in active window
    if esc then
      feed_data('\027[<71;8;1M')
    else
      api.nvim_input_mouse('wheel', 'right', 'S', 0, 0, 7)
    end
    screen:expect([[
      {11:  5 }^----6----7----8----9 │{11:  5 }----1----2----3----4|
      {11:  6 }----6----7----8----9 │{11:  6 }----1----2----3----4|
      {11:  7 }----6----7----8----9 │{11:  7 }----1----2----3----4|
      {11:  8 }----6----7----8----9 │{11:  8 }----1----2----3----4|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <S-ScrollWheelRight> in inactive window
    if esc then
      feed_data('\027[<71;48;1M')
    else
      api.nvim_input_mouse('wheel', 'right', 'S', 0, 0, 47)
    end
    screen:expect([[
      {11:  5 }^----6----7----8----9 │{11:  5 }5----6----7----8----|
      {11:  6 }----6----7----8----9 │{11:  6 }5----6----7----8----|
      {11:  7 }----6----7----8----9 │{11:  7 }5----6----7----8----|
      {11:  8 }----6----7----8----9 │{11:  8 }5----6----7----8----|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <ScrollWheelUp> in active window
    if esc then
      feed_data('\027[<64;8;1M')
    else
      api.nvim_input_mouse('wheel', 'up', '', 0, 0, 7)
    end
    screen:expect([[
      {11:  4 }----6----7----8----9 │{11:  5 }5----6----7----8----|
      {11:  5 }^----6----7----8----9 │{11:  6 }5----6----7----8----|
      {11:  6 }----6----7----8----9 │{11:  7 }5----6----7----8----|
      {11:  7 }----6----7----8----9 │{11:  8 }5----6----7----8----|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <ScrollWheelUp> in inactive window
    if esc then
      feed_data('\027[<64;48;1M')
    else
      api.nvim_input_mouse('wheel', 'up', '', 0, 0, 47)
    end
    screen:expect([[
      {11:  4 }----6----7----8----9 │{11:  4 }5----6----7----8----|
      {11:  5 }^----6----7----8----9 │{11:  5 }5----6----7----8----|
      {11:  6 }----6----7----8----9 │{11:  6 }5----6----7----8----|
      {11:  7 }----6----7----8----9 │{11:  7 }5----6----7----8----|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <ScrollWheelLeft> in active window
    if esc then
      feed_data('\027[<66;8;1M')
    else
      api.nvim_input_mouse('wheel', 'left', '', 0, 0, 7)
    end
    screen:expect([[
      {11:  4 }5----6----7----8----9│{11:  4 }5----6----7----8----|
      {11:  5 }5^----6----7----8----9│{11:  5 }5----6----7----8----|
      {11:  6 }5----6----7----8----9│{11:  6 }5----6----7----8----|
      {11:  7 }5----6----7----8----9│{11:  7 }5----6----7----8----|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <ScrollWheelLeft> in inactive window
    if esc then
      feed_data('\027[<66;48;1M')
    else
      api.nvim_input_mouse('wheel', 'left', '', 0, 0, 47)
    end
    screen:expect([[
      {11:  4 }5----6----7----8----9│{11:  4 }-5----6----7----8---|
      {11:  5 }5^----6----7----8----9│{11:  5 }-5----6----7----8---|
      {11:  6 }5----6----7----8----9│{11:  6 }-5----6----7----8---|
      {11:  7 }5----6----7----8----9│{11:  7 }-5----6----7----8---|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <S-ScrollWheelUp> in active window
    if esc then
      feed_data('\027[<68;8;1M')
    else
      api.nvim_input_mouse('wheel', 'up', 'S', 0, 0, 7)
    end
    screen:expect([[
      {11:  1 }5----6----7----8----9│{11:  4 }-5----6----7----8---|
      {11:  2 }5----6----7----8----9│{11:  5 }-5----6----7----8---|
      {11:  3 }5----6----7----8----9│{11:  6 }-5----6----7----8---|
      {11:  4 }5^----6----7----8----9│{11:  7 }-5----6----7----8---|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <S-ScrollWheelUp> in inactive window
    if esc then
      feed_data('\027[<68;48;1M')
    else
      api.nvim_input_mouse('wheel', 'up', 'S', 0, 0, 47)
    end
    screen:expect([[
      {11:  1 }5----6----7----8----9│{11:  1 }-5----6----7----8---|
      {11:  2 }5----6----7----8----9│{11:  2 }-5----6----7----8---|
      {11:  3 }5----6----7----8----9│{11:  3 }-5----6----7----8---|
      {11:  4 }5^----6----7----8----9│{11:  4 }-5----6----7----8---|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <S-ScrollWheelLeft> in active window
    if esc then
      feed_data('\027[<70;8;1M')
    else
      api.nvim_input_mouse('wheel', 'left', 'S', 0, 0, 7)
    end
    screen:expect([[
      {11:  1 }0----1----2----3----4│{11:  1 }-5----6----7----8---|
      {11:  2 }0----1----2----3----4│{11:  2 }-5----6----7----8---|
      {11:  3 }0----1----2----3----4│{11:  3 }-5----6----7----8---|
      {11:  4 }0----1----2----3----^4│{11:  4 }-5----6----7----8---|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <S-ScrollWheelLeft> in inactive window
    if esc then
      feed_data('\027[<70;48;1M')
    else
      api.nvim_input_mouse('wheel', 'left', 'S', 0, 0, 47)
    end
    screen:expect([[
      {11:  1 }0----1----2----3----4│{11:  1 }0----1----2----3----|
      {11:  2 }0----1----2----3----4│{11:  2 }0----1----2----3----|
      {11:  3 }0----1----2----3----4│{11:  3 }0----1----2----3----|
      {11:  4 }0----1----2----3----^4│{11:  4 }0----1----2----3----|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
  end

  describe('accepts mouse wheel events', function()
    it('(mouse events sent to host)', function()
      test_mouse_wheel(false)
    end)

    it('(escape sequences sent to child)', function()
      test_mouse_wheel(true)
    end)
  end)

  local function test_mouse_popup(esc)
    child_session:request(
      'nvim_exec2',
      [[
      call setline(1, 'popup menu test')
      set mouse=a mousemodel=popup

      aunmenu PopUp
      " Delete the default MenuPopup event handler.
      autocmd! nvim.popupmenu
      menu PopUp.foo :let g:menustr = 'foo'<CR>
      menu PopUp.bar :let g:menustr = 'bar'<CR>
      menu PopUp.baz :let g:menustr = 'baz'<CR>
      highlight Pmenu ctermbg=NONE ctermfg=NONE cterm=underline,reverse
      highlight PmenuSel ctermbg=NONE ctermfg=NONE cterm=underline,reverse,bold
    ]],
      {}
    )
    if esc then
      feed_data('\027[<2;5;1M')
    else
      api.nvim_input_mouse('right', 'press', '', 0, 0, 4)
    end
    screen:expect([[
      ^popup menu test                                   |
      {4:~  }{13: foo }{4:                                          }|
      {4:~  }{13: bar }{4:                                          }|
      {4:~  }{13: baz }{4:                                          }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    if esc then
      feed_data('\027[<2;5;1m')
    else
      api.nvim_input_mouse('right', 'release', '', 0, 0, 4)
    end
    screen:expect_unchanged()
    if esc then
      feed_data('\027[<64;5;1M')
    else
      api.nvim_input_mouse('wheel', 'up', '', 0, 0, 4)
    end
    screen:expect([[
      ^popup menu test                                   |
      {4:~  }{14: foo }{4:                                          }|
      {4:~  }{13: bar }{4:                                          }|
      {4:~  }{13: baz }{4:                                          }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    if esc then
      feed_data('\027[<35;7;4M')
    else
      api.nvim_input_mouse('move', '', '', 0, 3, 6)
    end
    screen:expect([[
      ^popup menu test                                   |
      {4:~  }{13: foo }{4:                                          }|
      {4:~  }{13: bar }{4:                                          }|
      {4:~  }{14: baz }{4:                                          }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    if esc then
      feed_data('\027[<65;7;4M')
    else
      api.nvim_input_mouse('wheel', 'down', '', 0, 3, 6)
    end
    screen:expect([[
      ^popup menu test                                   |
      {4:~  }{13: foo }{4:                                          }|
      {4:~  }{14: bar }{4:                                          }|
      {4:~  }{13: baz }{4:                                          }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    if esc then
      feed_data('\027[<0;7;3M')
    else
      api.nvim_input_mouse('left', 'press', '', 0, 2, 6)
    end
    screen:expect([[
      ^popup menu test                                   |
      {4:~                                                 }|*3
      {5:[No Name] [+]                                     }|
      :let g:menustr = 'bar'                            |
      {3:-- TERMINAL --}                                    |
    ]])
    if esc then
      feed_data('\027[<0;7;3m')
    else
      api.nvim_input_mouse('left', 'release', '', 0, 2, 6)
    end
    screen:expect_unchanged()
    if esc then
      feed_data('\027[<2;45;3M')
    else
      api.nvim_input_mouse('right', 'press', '', 0, 2, 44)
    end
    screen:expect([[
      ^popup menu test                                   |
      {4:~                                                 }|*2
      {4:~                                          }{13: foo }{4:  }|
      {5:[No Name] [+]                              }{13: bar }{5:  }|
      :let g:menustr = 'bar'                     {13: baz }  |
      {3:-- TERMINAL --}                                    |
    ]])
    if esc then
      feed_data('\027[<34;48;6M')
    else
      api.nvim_input_mouse('right', 'drag', '', 0, 5, 47)
    end
    screen:expect([[
      ^popup menu test                                   |
      {4:~                                                 }|*2
      {4:~                                          }{13: foo }{4:  }|
      {5:[No Name] [+]                              }{13: bar }{5:  }|
      :let g:menustr = 'bar'                     {14: baz }  |
      {3:-- TERMINAL --}                                    |
    ]])
    if esc then
      feed_data('\027[<2;48;6m')
    else
      api.nvim_input_mouse('right', 'release', '', 0, 5, 47)
    end
    screen:expect([[
      ^popup menu test                                   |
      {4:~                                                 }|*3
      {5:[No Name] [+]                                     }|
      :let g:menustr = 'baz'                            |
      {3:-- TERMINAL --}                                    |
    ]])
  end

  describe('mouse events work with right-click menu', function()
    it('(mouse events sent to host)', function()
      test_mouse_popup(false)
    end)

    it('(escape sequences sent to child)', function()
      test_mouse_popup(true)
    end)
  end)

  it('accepts keypad keys from kitty keyboard protocol #19180', function()
    feed_data('i')
    feed_data(fn.nr2char(57399)) -- KP_0
    feed_data(fn.nr2char(57400)) -- KP_1
    feed_data(fn.nr2char(57401)) -- KP_2
    feed_data(fn.nr2char(57402)) -- KP_3
    feed_data(fn.nr2char(57403)) -- KP_4
    feed_data(fn.nr2char(57404)) -- KP_5
    feed_data(fn.nr2char(57405)) -- KP_6
    feed_data(fn.nr2char(57406)) -- KP_7
    feed_data(fn.nr2char(57407)) -- KP_8
    feed_data(fn.nr2char(57408)) -- KP_9
    feed_data(fn.nr2char(57409)) -- KP_DECIMAL
    feed_data(fn.nr2char(57410)) -- KP_DIVIDE
    feed_data(fn.nr2char(57411)) -- KP_MULTIPLY
    feed_data(fn.nr2char(57412)) -- KP_SUBTRACT
    feed_data(fn.nr2char(57413)) -- KP_ADD
    feed_data(fn.nr2char(57414)) -- KP_ENTER
    feed_data(fn.nr2char(57415)) -- KP_EQUAL
    screen:expect([[
      0123456789./*-+                                   |
      =^                                                 |
      {4:~                                                 }|*2
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data(fn.nr2char(57417)) -- KP_LEFT
    screen:expect([[
      0123456789./*-+                                   |
      ^=                                                 |
      {4:~                                                 }|*2
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data(fn.nr2char(57418)) -- KP_RIGHT
    screen:expect([[
      0123456789./*-+                                   |
      =^                                                 |
      {4:~                                                 }|*2
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data(fn.nr2char(57419)) -- KP_UP
    screen:expect([[
      0^123456789./*-+                                   |
      =                                                 |
      {4:~                                                 }|*2
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data(fn.nr2char(57420)) -- KP_DOWN
    screen:expect([[
      0123456789./*-+                                   |
      =^                                                 |
      {4:~                                                 }|*2
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data(fn.nr2char(57425)) -- KP_INSERT
    screen:expect([[
      0123456789./*-+                                   |
      =^                                                 |
      {4:~                                                 }|*2
      {5:[No Name] [+]                                     }|
      {3:-- REPLACE --}                                     |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data('\027[27u') -- ESC
    screen:expect([[
      0123456789./*-+                                   |
      ^=                                                 |
      {4:~                                                 }|*2
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data('\027[57417;5u') -- CTRL + KP_LEFT
    screen:expect([[
      ^0123456789./*-+                                   |
      =                                                 |
      {4:~                                                 }|*2
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data('\027[57418;2u') -- SHIFT + KP_RIGHT
    screen:expect([[
      0123456789^./*-+                                   |
      =                                                 |
      {4:~                                                 }|*2
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data(fn.nr2char(57426)) -- KP_DELETE
    screen:expect([[
      0123456789^/*-+                                    |
      =                                                 |
      {4:~                                                 }|*2
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data(fn.nr2char(57423)) -- KP_HOME
    screen:expect([[
      ^0123456789/*-+                                    |
      =                                                 |
      {4:~                                                 }|*2
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data(fn.nr2char(57424)) -- KP_END
    screen:expect([[
      0123456789/*-^+                                    |
      =                                                 |
      {4:~                                                 }|*2
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    child_session:request(
      'nvim_exec2',
      [[
      tab split
      tabnew
      highlight Tabline ctermbg=NONE ctermfg=NONE cterm=underline
    ]],
      {}
    )
    screen:expect([[
      {12: + [No Name]  + [No Name] }{3: [No Name] }{1:            }{12:X}|
      ^                                                  |
      {4:~                                                 }|*2
      {5:[No Name]                                         }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data('\027[57421;5u') -- CTRL + KP_PAGE_UP
    screen:expect([[
      {12: + [No Name] }{3: + [No Name] }{12: [No Name] }{1:            }{12:X}|
      0123456789/*-^+                                    |
      =                                                 |
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data('\027[57422;5u') -- CTRL + KP_PAGE_DOWN
    screen:expect([[
      {12: + [No Name]  + [No Name] }{3: [No Name] }{1:            }{12:X}|
      ^                                                  |
      {4:~                                                 }|*2
      {5:[No Name]                                         }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('supports Super and Meta modifiers', function()
    feed_data('i')
    feed_data('\022\027[106;9u') -- Super + j
    feed_data('\022\027[107;33u') -- Meta + k
    feed_data('\022\027[13;41u') -- Super + Meta + Enter
    feed_data('\022\027[127;48u') -- Shift + Alt + Ctrl + Super + Meta + Backspace
    feed_data('\n')
    feed_data('\022\027[57376;9u') -- Super + F13
    feed_data('\022\027[57377;33u') -- Meta + F14
    feed_data('\022\027[57378;41u') -- Super + Meta + F15
    feed_data('\022\027[57379;48u') -- Shift + Alt + Ctrl + Super + Meta + F16
    screen:expect([[
      <D-j><T-k><T-D-CR><M-T-C-S-D-BS>                  |
      <D-F13><T-F14><T-D-F15><M-T-C-S-D-F16>^            |
      {4:~                                                 }|*2
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('paste: Insert mode', function()
    -- "bracketed paste"
    feed_data('i""\027i\027[200~')
    screen:expect([[
      "^"                                                |
      {4:~                                                 }|*3
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data('pasted from terminal')
    expect_child_buf_lines({ '"pasted from terminal"' })
    screen:expect([[
      "pasted from terminal^"                            |
      {4:~                                                 }|*3
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data('\027[201~') -- End paste.
    poke_both_eventloop()
    screen:expect_unchanged()
    feed_data('\027[27u') -- ESC: go to Normal mode.
    wait_for_mode('n')
    screen:expect([[
      "pasted from termina^l"                            |
      {4:~                                                 }|*3
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- Dot-repeat/redo.
    feed_data('2.')
    expect_child_buf_lines({ '"pasted from terminapasted from terminalpasted from terminall"' })
    screen:expect([[
      "pasted from terminapasted from terminalpasted fro|
      m termina^ll"                                      |
      {4:~                                                 }|*2
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- Undo.
    feed_data('u')
    expect_child_buf_lines({ '"pasted from terminal"' })
    feed_data('u')
    expect_child_buf_lines({ '""' })
    feed_data('u')
    expect_child_buf_lines({ '' })
  end)

  it('paste: select-mode', function()
    feed_data('ithis is line 1\nthis is line 2\nline 3 is here\n\027')
    wait_for_mode('n')
    screen:expect([[
      this is line 1                                    |
      this is line 2                                    |
      line 3 is here                                    |
      ^                                                  |
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- Select-mode. Use <C-n> to move down.
    feed_data('gg04lgh\14\14')
    screen:expect([[
      this{16: is line 1}                                    |
      {16:this is line 2}                                    |
      {16:line}^ 3 is here                                    |
                                                        |
      {5:[No Name] [+]                                     }|
      {3:-- SELECT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data('\027[200~')
    feed_data('just paste it™')
    feed_data('\027[201~')
    screen:expect([[
      thisjust paste it^™3 is here                       |
                                                        |
      {4:~                                                 }|*2
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- Undo.
    feed_data('u')
    expect_child_buf_lines {
      'this is line 1',
      'this is line 2',
      'line 3 is here',
      '',
    }
    -- Redo.
    feed_data('\18') -- <C-r>
    expect_child_buf_lines {
      'thisjust paste it™3 is here',
      '',
    }
  end)

  it('paste: terminal mode', function()
    if is_ci('github') then
      pending('tty-test complains about not owning the terminal -- actions/runner#241')
    end
    screen:set_default_attr_ids({
      [1] = { reverse = true }, -- focused cursor
      [3] = { bold = true },
      [19] = { bold = true, background = 121, foreground = 0 }, -- StatusLineTerm
    })
    child_exec_lua('vim.o.statusline="^^^^^^^"')
    child_exec_lua('vim.cmd.terminal(...)', testprg('tty-test'))
    feed_data('i')
    screen:expect([[
      tty ready                                         |
      ^                                                  |
                                                        |*2
      {19:^^^^^^^                                           }|
      {3:-- TERMINAL --}                                    |*2
    ]])
    feed_data('\027[200~')
    feed_data('hallo')
    feed_data('\027[201~')
    screen:expect([[
      tty ready                                         |
      hallo^                                             |
                                                        |*2
      {19:^^^^^^^                                           }|
      {3:-- TERMINAL --}                                    |*2
    ]])
  end)

  it('paste: normal-mode (+CRLF #10872)', function()
    feed_data(':set ruler | echo')
    wait_for_mode('c')
    feed_data('\n')
    wait_for_mode('n')
    local expected_lf = { 'line 1', 'ESC:\027 / CR: \rx' }
    local expected_crlf = { 'line 1', 'ESC:\027 / CR: ', 'x' }
    local expected_grid1 = [[
      line 1                                            |
      ESC:{6:^[} / CR:                                      |
      ^x                                                 |
      {4:~                                                 }|
      {5:[No Name] [+]                   3,1            All}|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]]
    -- "bracketed paste"
    feed_data('\027[200~' .. table.concat(expected_lf, '\n') .. '\027[201~')
    screen:expect(expected_grid1)
    -- Dot-repeat/redo.
    feed_data('.')
    local expected_grid2 = [[
      ESC:{6:^[} / CR:                                      |
      xline 1                                           |
      ESC:{6:^[} / CR:                                      |
      ^x                                                 |
      {5:[No Name] [+]                   5,1            Bot}|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]]
    screen:expect(expected_grid2)
    -- Undo.
    feed_data('u')
    expect_child_buf_lines(expected_crlf)
    feed_data('u')
    expect_child_buf_lines({ '' })
    feed_data(':echo')
    wait_for_mode('c')
    feed_data('\n')
    wait_for_mode('n')
    -- CRLF input
    feed_data('\027[200~' .. table.concat(expected_lf, '\r\n') .. '\027[201~')
    screen:expect(expected_grid1)
    expect_child_buf_lines(expected_crlf)
    -- Dot-repeat/redo.
    feed_data('.')
    screen:expect(expected_grid2)
    -- Undo.
    feed_data('u')
    expect_child_buf_lines(expected_crlf)
    feed_data('u')
    expect_child_buf_lines({ '' })
  end)

  it('paste: cmdline-mode inserts 1 line', function()
    feed_data('ifoo\n') -- Insert some text (for dot-repeat later).
    feed_data('\027:""') -- Enter Cmdline-mode.
    feed_data('\027[D') -- <Left> to place cursor between quotes.
    wait_for_mode('c')
    screen:expect([[
      foo                                               |
                                                        |
      {4:~                                                 }|*2
      {5:[No Name] [+]                                     }|
      :"^"                                               |
      {3:-- TERMINAL --}                                    |
    ]])
    -- "bracketed paste"
    feed_data('\027[200~line 1\nline 2\n')
    wait_for_mode('c')
    feed_data('line 3\nline 4\n\027[201~')
    poke_both_eventloop()
    wait_for_mode('c')
    screen:expect([[
      foo                                               |
                                                        |
      {4:~                                                 }|*2
      {5:[No Name] [+]                                     }|
      :"line 1^"                                         |
      {3:-- TERMINAL --}                                    |
    ]])
    -- Dot-repeat/redo.
    feed_data('\027[27u')
    wait_for_mode('n')
    feed_data('.')
    screen:expect([[
      foo                                               |*2
      ^                                                  |
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('paste: cmdline-mode collects chunks of unfinished line', function()
    local function expect_cmdline(expected)
      retry(nil, nil, function()
        local _, cmdline = child_session:request('nvim_call_function', 'getcmdline', {})
        eq(expected, cmdline)
        local _, pos = child_session:request('nvim_call_function', 'getcmdpos', {})
        eq(#expected, pos) -- Cursor is just before the last char.
      end)
    end
    feed_data('\027:""') -- Enter Cmdline-mode.
    feed_data('\027[D') -- <Left> to place cursor between quotes.
    expect_cmdline('""')
    feed_data('\027[200~stuff 1 ')
    expect_cmdline('"stuff 1 "')
    -- Discards everything after the first line.
    feed_data('more\nstuff 2\nstuff 3\n')
    expect_cmdline('"stuff 1 more"')
    feed_data('stuff 3')
    expect_cmdline('"stuff 1 more"')
    -- End the paste sequence.
    feed_data('\027[201~')
    poke_both_eventloop()
    expect_cmdline('"stuff 1 more"')
    feed_data(' typed')
    expect_cmdline('"stuff 1 more typed"')
  end)

  it('paste: recovers from vim.paste() failure', function()
    child_exec_lua([[
      _G.save_paste_fn = vim.paste
      -- Stack traces for this test are non-deterministic, so disable them
      _G.debug.traceback = function(msg) return msg end
      vim.paste = function(lines, phase) error("fake fail") end
    ]])
    -- Prepare something for dot-repeat/redo.
    feed_data('ifoo\n\027[27u')
    wait_for_mode('n')
    screen:expect([[
      foo                                               |
      ^                                                  |
      {4:~                                                 }|*2
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- Start pasting...
    feed_data('\027[200~line 1\nline 2\n')
    screen:expect([[
      foo                                               |
                                                        |
      {5:                                                  }|
      {8:paste: Error executing lua: [string "<nvim>"]:4: f}|
      {8:ake fail}                                          |
      {10:Press ENTER or type command to continue}^           |
      {3:-- TERMINAL --}                                    |
    ]])
    -- Remaining chunks are discarded after vim.paste() failure.
    feed_data('line 3\nline 4\n')
    feed_data('line 5\nline 6\n')
    feed_data('line 7\nline 8\n')
    -- Stop paste.
    feed_data('\027[201~')
    screen:expect_unchanged()
    feed_data('\n') -- <CR> to dismiss hit-enter prompt
    expect_child_buf_lines({ 'foo', '' })
    -- Dot-repeat/redo is not modified by failed paste.
    feed_data('.')
    screen:expect([[
      foo                                               |*2
      ^                                                  |
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- Editor should still work after failed/drained paste.
    feed_data('ityped input...\027[27u')
    screen:expect([[
      foo                                               |*2
      typed input..^.                                    |
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- Paste works if vim.paste() succeeds.
    child_exec_lua([[vim.paste = _G.save_paste_fn]])
    feed_data('\027[200~line A\nline B\n\027[201~')
    screen:expect([[
      foo                                               |
      typed input...line A                              |
      line B                                            |
      ^                                                  |
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('paste: vim.paste() cancel (retval=false) #10865', function()
    -- This test only exercises the "cancel" case.  Use-case would be "dangling
    -- paste", but that is not implemented yet. #10865
    child_exec_lua([[
      vim.paste = function(lines, phase) return false end
    ]])
    feed_data('\027[200~line A\nline B\n\027[201~')
    expect_child_buf_lines({ '' })
    feed_data('ifoo\n\027[27u')
    expect_child_buf_lines({ 'foo', '' })
  end)

  it('paste: vim.paste() cancel (retval=false) with streaming #30462', function()
    child_exec_lua([[
      vim.paste = (function(overridden)
        return function(lines, phase)
          for i, line in ipairs(lines) do
            if line:find('!') then
              return false
            end
          end
          return overridden(lines, phase)
        end
      end)(vim.paste)
    ]])
    feed_data('A')
    wait_for_mode('i')
    feed_data('\027[200~aaa')
    expect_child_buf_lines({ 'aaa' })
    feed_data('bbb')
    expect_child_buf_lines({ 'aaabbb' })
    feed_data('ccc!') -- This chunk is cancelled.
    expect_child_buf_lines({ 'aaabbb' })
    feed_data('ddd\027[201~') -- This chunk is ignored.
    poke_both_eventloop()
    expect_child_buf_lines({ 'aaabbb' })
    feed_data('\027[27u')
    wait_for_mode('n')
    feed_data('.') -- Dot-repeat only includes chunks actually pasted.
    expect_child_buf_lines({ 'aaabbbaaabbb' })
    feed_data('$\027[200~eee\027[201~') -- A following paste works normally.
    expect_child_buf_lines({ 'aaabbbaaabbbeee' })
  end)

  it("paste: 'nomodifiable' buffer", function()
    child_exec_lua([[
      vim.bo.modifiable = false
      -- Truncate the error message to hide the line number
      _G.debug.traceback = function(msg) return msg:sub(-49) end
    ]])
    feed_data('\027[200~fail 1\nfail 2\n\027[201~')
    screen:expect([[
                                                        |
      {4:~                                                 }|
      {5:                                                  }|
      {8:paste: Error executing lua: Vim:E21: Cannot make c}|
      {8:hanges, 'modifiable' is off}                       |
      {10:Press ENTER or type command to continue}^           |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data('\n') -- <Enter> to dismiss hit-enter prompt
    child_exec_lua('vim.bo.modifiable = true')
    feed_data('\027[200~success 1\nsuccess 2\n\027[201~')
    screen:expect([[
      success 1                                         |
      success 2                                         |
      ^                                                  |
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('paste: exactly 64 bytes #10311', function()
    local expected = string.rep('z', 64)
    feed_data('i')
    wait_for_mode('i')
    -- "bracketed paste"
    feed_data('\027[200~' .. expected .. '\027[201~')
    expect_child_buf_lines({ expected })
    feed_data(' end')
    expected = expected .. ' end'
    screen:expect([[
      zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz|
      zzzzzzzzzzzzzz end^                                |
      {4:~                                                 }|*2
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
    expect_child_buf_lines({ expected })
  end)

  it('paste: less-than sign in cmdline  #11088', function()
    local expected = '<'
    feed_data(':')
    wait_for_mode('c')
    -- "bracketed paste"
    feed_data('\027[200~' .. expected .. '\027[201~')
    screen:expect([[
                                                        |
      {4:~                                                 }|*3
      {5:[No Name]                                         }|
      :<^                                                |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('paste: big burst of input', function()
    feed_data(':set ruler\n')
    local q = {}
    for i = 1, 3000 do
      q[i] = 'item ' .. tostring(i)
    end
    feed_data('i')
    wait_for_mode('i')
    -- "bracketed paste"
    feed_data('\027[200~' .. table.concat(q, '\n') .. '\027[201~')
    expect_child_buf_lines(q)
    feed_data(' end')
    screen:expect([[
      item 2997                                         |
      item 2998                                         |
      item 2999                                         |
      item 3000 end^                                     |
      {5:[No Name] [+]                   3000,14        Bot}|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data('\027[27u') -- ESC: go to Normal mode.
    wait_for_mode('n')
    -- Dot-repeat/redo.
    feed_data('.')
    screen:expect([[
      item 2997                                         |
      item 2998                                         |
      item 2999                                         |
      item 3000 en^dd                                    |
      {5:[No Name] [+]                   5999,13        Bot}|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('paste: forwards spurious "start paste" code', function()
    -- If multiple "start paste" sequences are sent without a corresponding
    -- "stop paste" sequence, only the first occurrence should be consumed.
    feed_data('i')
    wait_for_mode('i')
    -- Send the "start paste" sequence.
    feed_data('\027[200~')
    feed_data('\npasted from terminal (1)\n')
    -- Send spurious "start paste" sequence.
    feed_data('\027[200~')
    feed_data('\n')
    -- Send the "stop paste" sequence.
    feed_data('\027[201~')
    screen:expect([[
                                                        |
      pasted from terminal (1)                          |
      {6:^[}[200~                                           |
      ^                                                  |
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('paste: ignores spurious "stop paste" code', function()
    -- If "stop paste" sequence is received without a preceding "start paste"
    -- sequence, it should be ignored.
    feed_data('i')
    wait_for_mode('i')
    -- Send "stop paste" sequence.
    feed_data('\027[201~')
    screen:expect([[
      ^                                                  |
      {4:~                                                 }|*3
      {5:[No Name]                                         }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('paste: split "start paste" code', function()
    feed_data('i')
    wait_for_mode('i')
    -- Send split "start paste" sequence.
    feed_data('\027[2')
    feed_data('00~pasted from terminal\027[201~')
    screen:expect([[
      pasted from terminal^                              |
      {4:~                                                 }|*3
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('paste: split "stop paste" code', function()
    feed_data('i')
    wait_for_mode('i')
    -- Send split "stop paste" sequence.
    feed_data('\027[200~pasted from terminal\027[20')
    feed_data('1~')
    screen:expect([[
      pasted from terminal^                              |
      {4:~                                                 }|*3
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('paste: streamed paste with isolated "stop paste" code', function()
    child_exec_lua([[
      _G.paste_phases = {}
      vim.paste = (function(overridden)
        return function(lines, phase)
          table.insert(_G.paste_phases, phase)
          overridden(lines, phase)
        end
      end)(vim.paste)
    ]])
    feed_data('i')
    wait_for_mode('i')
    feed_data('\027[200~pasted') -- phase 1
    screen:expect([[
      pasted^                                            |
      {4:~                                                 }|*3
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data(' from terminal') -- phase 2
    screen:expect([[
      pasted from terminal^                              |
      {4:~                                                 }|*3
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
    -- Send isolated "stop paste" sequence.
    feed_data('\027[201~') -- phase 3
    poke_both_eventloop()
    screen:expect_unchanged()
    local rv = child_exec_lua('return _G.paste_phases')
    -- In rare cases there may be multiple chunks of phase 2 because of timing.
    eq({ 1, 2, 3 }, { rv[1], rv[2], rv[#rv] })
  end)

  it('allows termguicolors to be set at runtime', function()
    screen:set_option('rgb', true)
    screen:set_default_attr_ids({
      [1] = { reverse = true },
      [2] = { foreground = tonumber('0x4040ff'), fg_indexed = true },
      [3] = { bold = true, reverse = true },
      [4] = { bold = true },
      [5] = { reverse = true, foreground = tonumber('0xe0e000'), fg_indexed = true },
      [6] = { foreground = tonumber('0xe0e000'), fg_indexed = true },
      [7] = { reverse = true, foreground = Screen.colors.SeaGreen4 },
      [8] = { foreground = Screen.colors.SeaGreen4 },
      [9] = { bold = true, foreground = Screen.colors.Blue1 },
      [10] = { foreground = Screen.colors.Blue },
    })

    feed_data(':hi SpecialKey ctermfg=3 guifg=SeaGreen\n')
    feed_data('i')
    feed_data('\022\007') -- ctrl+g
    feed_data('\028\014') -- crtl+\ ctrl+N
    feed_data(':set termguicolors?\n')
    screen:expect([[
      {6:^^G}                                                |
      {2:~                                                 }|*3
      {3:[No Name] [+]                                     }|
      notermguicolors                                   |
      {4:-- TERMINAL --}                                    |
    ]])

    feed_data(':set termguicolors\n')
    screen:expect([[
      {8:^^G}                                                |
      {9:~}{10:                                                 }|*3
      {3:[No Name] [+]                                     }|
      :set termguicolors                                |
      {4:-- TERMINAL --}                                    |
    ]])

    feed_data(':set notermguicolors\n')
    screen:expect([[
      {6:^^G}                                                |
      {2:~                                                 }|*3
      {3:[No Name] [+]                                     }|
      :set notermguicolors                              |
      {4:-- TERMINAL --}                                    |
    ]])
  end)

  it('forwards :term palette colors with termguicolors', function()
    if is_ci('github') then
      pending('tty-test complains about not owning the terminal -- actions/runner#241')
    end
    screen:set_rgb_cterm(true)
    screen:set_default_attr_ids({
      [1] = { { reverse = true }, { reverse = true } },
      [2] = {
        { bold = true, background = Screen.colors.LightGreen, foreground = Screen.colors.Black },
        { bold = true },
      },
      [3] = { { bold = true }, { bold = true } },
      [4] = { { fg_indexed = true, foreground = tonumber('0xe0e000') }, { foreground = 3 } },
      [5] = { { foreground = tonumber('0xff8000') }, {} },
      [6] = {
        {
          fg_indexed = true,
          bg_indexed = true,
          bold = true,
          background = tonumber('0x66ff99'),
          foreground = Screen.colors.Black,
        },
        { bold = true, background = 121, foreground = 0 },
      },
      [7] = {
        {
          fg_indexed = true,
          bg_indexed = true,
          background = tonumber('0x66ff99'),
          foreground = Screen.colors.Black,
        },
        { background = 121, foreground = 0 },
      },
    })

    child_exec_lua('vim.o.statusline="^^^^^^^"')
    child_exec_lua('vim.o.termguicolors=true')
    child_exec_lua('vim.cmd.terminal(...)', testprg('tty-test'))
    screen:expect {
      grid = [[
      ^tty ready                                         |
                                                        |*3
      {2:^^^^^^^                                           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]],
    }
    feed_data(
      ':call chansend(&channel, "\\033[38;5;3mtext\\033[38:2:255:128:0mcolor\\033[0;10mtext")\n'
    )
    screen:expect {
      grid = [[
      ^tty ready                                         |
      {4:text}{5:color}text                                     |
                                                        |*2
      {2:^^^^^^^                                           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]],
    }

    feed_data(':set notermguicolors\n')
    screen:expect {
      grid = [[
      ^tty ready                                         |
      {4:text}colortext                                     |
                                                        |*2
      {6:^^^^^^^}{7:                                           }|
      :set notermguicolors                              |
      {3:-- TERMINAL --}                                    |
    ]],
    }
  end)

  -- Note: libvterm doesn't support colored underline or undercurl.
  it('supports undercurl and underdouble when run in :terminal', function()
    screen:set_default_attr_ids({
      [1] = { reverse = true },
      [2] = { bold = true, reverse = true },
      [3] = { bold = true },
      [4] = { foreground = 12 },
      [5] = { undercurl = true },
      [6] = { underdouble = true },
    })
    child_session:request('nvim_set_hl', 0, 'Visual', { undercurl = true })
    feed_data('ifoobar\027V')
    screen:expect([[
      {5:fooba}^r                                            |
      {4:~                                                 }|*3
      {2:[No Name] [+]                                     }|
      {3:-- VISUAL LINE --}                                 |
      {3:-- TERMINAL --}                                    |
    ]])
    child_session:request('nvim_set_hl', 0, 'Visual', { underdouble = true })
    screen:expect([[
      {6:fooba}^r                                            |
      {4:~                                                 }|*3
      {2:[No Name] [+]                                     }|
      {3:-- VISUAL LINE --}                                 |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('in nvim_list_uis(), sets nvim_set_client_info()', function()
    -- $TERM in :terminal.
    local exp_term = is_os('bsd') and 'builtin_xterm' or 'xterm-256color'
    local ui_chan = 1
    local expected = {
      {
        chan = ui_chan,
        ext_cmdline = false,
        ext_hlstate = false,
        ext_linegrid = true,
        ext_messages = false,
        ext_multigrid = false,
        ext_popupmenu = false,
        ext_tabline = false,
        ext_termcolors = true,
        ext_wildmenu = false,
        height = 6,
        override = false,
        rgb = false,
        stdin_tty = true,
        stdout_tty = true,
        term_background = '',
        term_colors = 256,
        term_name = exp_term,
        width = 50,
      },
    }
    local _, rv = child_session:request('nvim_list_uis')
    eq(expected, rv)

    ---@type table
    local expected_version = child_exec_lua('return vim.version()')
    -- vim.version() returns `prerelease` string. Coerce it to boolean.
    expected_version.prerelease = not not expected_version.prerelease

    local expected_chan_info = {
      client = {
        attributes = {
          license = 'Apache 2',
          -- pid = 5371,
          website = 'https://neovim.io',
        },
        methods = {},
        name = 'nvim-tui',
        type = 'ui',
        version = expected_version,
      },
      id = ui_chan,
      mode = 'rpc',
      stream = 'stdio',
    }

    local status, chan_info = child_session:request('nvim_get_chan_info', ui_chan)
    ok(status)
    local info = chan_info.client
    ok(info.attributes.pid and info.attributes.pid > 0, 'PID', info.attributes.pid or 'nil')
    ok(info.version.major >= 0)
    ok(info.version.minor >= 0)
    ok(info.version.patch >= 0)

    -- Delete variable fields so we can deep-compare.
    info.attributes.pid = nil

    eq(expected_chan_info, chan_info)
  end)

  it('allows grid to assume wider ambiwidth chars than host terminal', function()
    child_session:request(
      'nvim_buf_set_lines',
      0,
      0,
      -1,
      true,
      { ('℃'):rep(60), ('℃'):rep(60) }
    )
    child_session:request('nvim_set_option_value', 'cursorline', true, {})
    child_session:request('nvim_set_option_value', 'list', true, {})
    child_session:request('nvim_set_option_value', 'listchars', 'eol:$', { win = 0 })
    feed_data('gg')
    local singlewidth_screen = [[
      {12:^℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃}|
      {12:℃℃℃℃℃℃℃℃℃℃}{15:$}{12:                                       }|
      ℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃|
      ℃℃℃℃℃℃℃℃℃℃{4:$}                                       |
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]]
    -- When grid assumes "℃" to be double-width but host terminal assumes it to be single-width,
    -- the second cell of "℃" is a space and the attributes of the "℃" are applied to it.
    local doublewidth_screen = [[
      {12:^℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ }|
      {12:℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ }|
      {12:℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ }{15:$}{12:                             }|
      ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ {4:@@@@}|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]]
    screen:expect(singlewidth_screen)
    child_session:request('nvim_set_option_value', 'ambiwidth', 'double', {})
    screen:expect(doublewidth_screen)
    child_session:request('nvim_set_option_value', 'ambiwidth', 'single', {})
    screen:expect(singlewidth_screen)
    child_session:request('nvim_call_function', 'setcellwidths', { { { 0x2103, 0x2103, 2 } } })
    screen:expect(doublewidth_screen)
    child_session:request('nvim_call_function', 'setcellwidths', { { { 0x2103, 0x2103, 1 } } })
    screen:expect(singlewidth_screen)
  end)

  it('allows grid to assume wider non-ambiwidth chars than host terminal', function()
    child_session:request(
      'nvim_buf_set_lines',
      0,
      0,
      -1,
      true,
      { ('✓'):rep(60), ('✓'):rep(60) }
    )
    child_session:request('nvim_set_option_value', 'cursorline', true, {})
    child_session:request('nvim_set_option_value', 'list', true, {})
    child_session:request('nvim_set_option_value', 'listchars', 'eol:$', { win = 0 })
    feed_data('gg')
    local singlewidth_screen = [[
      {12:^✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓}|
      {12:✓✓✓✓✓✓✓✓✓✓}{15:$}{12:                                       }|
      ✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓✓|
      ✓✓✓✓✓✓✓✓✓✓{4:$}                                       |
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]]
    -- When grid assumes "✓" to be double-width but host terminal assumes it to be single-width,
    -- the second cell of "✓" is a space and the attributes of the "✓" are applied to it.
    local doublewidth_screen = [[
      {12:^✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ }|
      {12:✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ }|
      {12:✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ }{15:$}{12:                             }|
      ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ ✓ {4:@@@@}|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]]
    screen:expect(singlewidth_screen)
    child_session:request('nvim_set_option_value', 'ambiwidth', 'double', {})
    screen:expect_unchanged()
    child_session:request('nvim_call_function', 'setcellwidths', { { { 0x2713, 0x2713, 2 } } })
    screen:expect(doublewidth_screen)
    child_session:request('nvim_set_option_value', 'ambiwidth', 'single', {})
    screen:expect_unchanged()
    child_session:request('nvim_call_function', 'setcellwidths', { { { 0x2713, 0x2713, 1 } } })
    screen:expect(singlewidth_screen)
  end)

  it('draws correctly when cursor_address overflows #21643', function()
    screen:try_resize(70, 333)
    retry(nil, nil, function()
      eq({ true, 330 }, { child_session:request('nvim_win_get_height', 0) })
    end)
    child_session:request('nvim_set_option_value', 'cursorline', true, {})
    -- Use full screen message so that redrawing afterwards is more deterministic.
    child_session:notify('nvim_command', 'intro')
    screen:expect({ any = 'Nvim is open source and freely distributable' })
    -- Going to top-left corner needs 3 bytes.
    -- Setting underline attribute needs 9 bytes.
    -- A Ꝩ character takes 3 bytes.
    -- The whole line needs 3 + 9 + 3 * 21838 + 3 = 65529 bytes.
    -- The cursor_address that comes after will overflow the 65535-byte buffer.
    local line = ('Ꝩ'):rep(21838) .. '℃'
    child_session:notify('nvim_buf_set_lines', 0, 0, -1, true, { line, 'b' })
    -- Close the :intro message and redraw the lines.
    feed_data('\n')
    screen:expect([[
      {12:^ꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨ}|
      {12:ꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨ}|*310
      {12:ꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨ℃ }|
      b                                                                     |
      {4:~                                                                     }|*17
      {5:[No Name] [+]                                                         }|
                                                                            |
      {3:-- TERMINAL --}                                                        |
    ]])
  end)

  it('draws correctly when setting title overflows #30793', function()
    screen:try_resize(67, 327)
    retry(nil, nil, function()
      eq({ true, 324 }, { child_session:request('nvim_win_get_height', 0) })
    end)
    child_exec_lua([[
      vim.o.cmdheight = 0
      vim.o.laststatus = 0
      vim.o.ruler = false
      vim.o.showcmd = false
      vim.o.termsync = false
      vim.o.title = true
    ]])
    retry(nil, nil, function()
      eq('[No Name] - Nvim', api.nvim_buf_get_var(0, 'term_title'))
      eq({ true, 326 }, { child_session:request('nvim_win_get_height', 0) })
    end)
    -- Use full screen message so that redrawing afterwards is more deterministic.
    child_session:notify('nvim_command', 'intro')
    screen:expect({ any = 'Nvim is open source and freely distributable' })
    -- Going to top-left corner needs 3 bytes.
    -- A Ꝩ character takes 3 bytes.
    -- The whole line needs 3 + 3 * 21842 = 65529 bytes.
    -- The title will be updated because the buffer is now modified.
    -- The start of the OSC 0 sequence to set title can fit in the 65535-byte buffer,
    -- but the title string cannot.
    local line = ('Ꝩ'):rep(21842)
    child_session:notify('nvim_buf_set_lines', 0, 0, -1, true, { line })
    -- Close the :intro message and redraw the lines.
    feed_data('\n')
    screen:expect([[
      ^ꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨ|
      ꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨꝨ|*325
      {3:-- TERMINAL --}                                                     |
    ]])
    retry(nil, nil, function()
      eq('[No Name] + - Nvim', api.nvim_buf_get_var(0, 'term_title'))
    end)
  end)

  it('visual bell (padding) does not crash #21610', function()
    feed_data ':set visualbell\n'
    screen:expect {
      grid = [[
      ^                                                  |
      {4:~                                                 }|*3
      {5:[No Name]                                         }|
      :set visualbell                                   |
      {3:-- TERMINAL --}                                    |
    ]],
    }

    -- move left is enough to invoke the bell
    feed_data 'h'
    -- visual change to show we process events after this
    feed_data 'i'
    screen:expect {
      grid = [[
      ^                                                  |
      {4:~                                                 }|*3
      {5:[No Name]                                         }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]],
    }
  end)

  it('no assert failure on deadly signal #21896', function()
    exec_lua([[vim.uv.kill(vim.fn.jobpid(vim.bo.channel), 'sigterm')]])
    screen:expect {
      grid = [[
      Nvim: Caught deadly signal 'SIGTERM'              |
                                                        |
      [Process exited 1]^                                |
                                                        |*3
      {3:-- TERMINAL --}                                    |
    ]],
    }
  end)

  it('no stack-use-after-scope with cursor color #22432', function()
    screen:set_option('rgb', true)
    command('set termguicolors')
    child_session:request(
      'nvim_exec2',
      [[
      set tgc
      hi Cursor guifg=Red guibg=Green
      set guicursor=n:block-Cursor/lCursor
    ]],
      {}
    )
    screen:set_default_attr_ids({
      [1] = { reverse = true },
      [2] = { bold = true, foreground = Screen.colors.Blue },
      [3] = { foreground = Screen.colors.Blue },
      [4] = { reverse = true, bold = true },
      [5] = { bold = true },
    })
    screen:expect([[
      ^                                                  |
      {2:~}{3:                                                 }|*3
      {4:[No Name]                                         }|
                                                        |
      {5:-- TERMINAL --}                                    |
    ]])
    feed_data('i')
    screen:expect([[
      ^                                                  |
      {2:~}{3:                                                 }|*3
      {4:[No Name]                                         }|
      {5:-- INSERT --}                                      |
      {5:-- TERMINAL --}                                    |
    ]])
  end)

  it('redraws on SIGWINCH even if terminal size is unchanged #23411', function()
    child_session:request('nvim_echo', { { 'foo' } }, false, {})
    screen:expect([[
      ^                                                  |
      {4:~                                                 }|*3
      {5:[No Name]                                         }|
      foo                                               |
      {3:-- TERMINAL --}                                    |
    ]])
    exec_lua([[vim.uv.kill(vim.fn.jobpid(vim.bo.channel), 'sigwinch')]])
    screen:expect([[
      ^                                                  |
      {4:~                                                 }|*3
      {5:[No Name]                                         }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('supports hiding cursor', function()
    child_session:request(
      'nvim_command',
      "let g:id = jobstart([v:progpath, '--clean', '--headless'])"
    )
    feed_data(':call jobwait([g:id])\n')
    screen:expect([[
                                                        |
      {4:~                                                 }|*3
      {5:[No Name]                                         }|
      :call jobwait([g:id])                             |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data('\003')
    screen:expect([[
      ^                                                  |
      {4:~                                                 }|*3
      {5:[No Name]                                         }|
      Type  :qa  and press <Enter> to exit Nvim         |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('cursor is not hidden on incsearch with no match', function()
    feed_data('ifoo\027')
    feed_data('/foo')
    screen:expect([[
      {1:foo}                                               |
      {4:~                                                 }|*3
      {5:[No Name] [+]                                     }|
      /foo^                                              |
      {3:-- TERMINAL --}                                    |
    ]])
    screen:sleep(10)
    feed_data('b')
    screen:expect([[
      foo                                               |
      {4:~                                                 }|*3
      {5:[No Name] [+]                                     }|
      /foob^                                             |
      {3:-- TERMINAL --}                                    |
    ]])
    screen:sleep(10)
    feed_data('a')
    screen:expect([[
      foo                                               |
      {4:~                                                 }|*3
      {5:[No Name] [+]                                     }|
      /fooba^                                            |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('emits hyperlinks with OSC 8', function()
    exec_lua([[
      local buf = vim.api.nvim_get_current_buf()
      _G.urls = {}
      vim.api.nvim_create_autocmd('TermRequest', {
        buffer = buf,
        callback = function(args)
          local req = args.data.sequence
          if not req then
            return
          end
          local id, url = req:match('\027]8;id=(%d+);(.*)$')
          if id ~= nil and url ~= nil then
            table.insert(_G.urls, { id = tonumber(id), url = url })
          end
        end,
      })
    ]])
    child_exec_lua([[
      vim.api.nvim_buf_set_lines(0, 0, 0, true, {'Hello'})
      local ns = vim.api.nvim_create_namespace('test')
      vim.api.nvim_buf_set_extmark(0, ns, 0, 1, {
        end_col = 3,
        url = 'https://example.com',
      })
    ]])
    retry(nil, 1000, function()
      eq({ { id = 0xE1EA0000, url = 'https://example.com' } }, exec_lua([[return _G.urls]]))
    end)
  end)

  it('TermResponse works with vim.wait() from another autocommand #32706', function()
    child_exec_lua([[
      _G.termresponse = nil
      vim.api.nvim_create_autocmd('TermResponse', {
        callback = function(ev)
          _G.sequence = ev.data.sequence
          _G.v_termresponse = vim.v.termresponse
        end,
      })
      vim.api.nvim_create_autocmd('InsertEnter', {
        buffer = 0,
        callback = function()
          _G.result = vim.wait(3000, function()
            local expected = '\027P1+r5463'
            return _G.sequence == expected and _G.v_termresponse == expected
          end)
        end,
      })
    ]])
    feed_data('i')
    feed_data('\027P1+r5463\027\\')
    retry(nil, 4000, function()
      eq(true, child_exec_lua('return _G.result'))
    end)
  end)
end)

describe('TUI', function()
  before_each(clear)

  it('resize at startup #17285 #15044 #11330', function()
    local screen = Screen.new(50, 10)
    screen:set_default_attr_ids({
      [1] = { reverse = true },
      [2] = { bold = true, foreground = Screen.colors.Blue },
      [3] = { bold = true },
      [4] = { foreground = tonumber('0x4040ff'), fg_indexed = true },
      [5] = { bold = true, reverse = true },
      [6] = { foreground = Screen.colors.White, background = Screen.colors.DarkGreen },
    })
    fn.jobstart({
      nvim_prog,
      '--clean',
      '--cmd',
      'colorscheme vim',
      '--cmd',
      'set notermguicolors',
      '--cmd',
      'let start = reltime() | while v:true | if reltimefloat(reltime(start)) > 2 | break | endif | endwhile',
    }, {
      term = true,
      env = {
        VIMRUNTIME = os.getenv('VIMRUNTIME'),
      },
    })
    exec([[
      sleep 500m
      vs new
    ]])
    screen:expect([[
      ^                         │                        |
      {2:~                        }│{4:~                       }|*5
      {2:~                        }│{5:[No Name]   0,0-1    All}|
      {2:~                        }│                        |
      {5:new                       }{6:{MATCH:<.*[/\]nvim }}|
                                                        |
    ]])
  end)

  -- #28667, #28668
  for _, guicolors in ipairs({ 'notermguicolors', 'termguicolors' }) do
    it('has no black flicker when clearing regions during startup with ' .. guicolors, function()
      local screen = Screen.new(50, 10)
      fn.jobstart({
        nvim_prog,
        '--clean',
        '--cmd',
        'set ' .. guicolors,
        '--cmd',
        'sleep 10',
      }, {
        term = true,
        env = {
          VIMRUNTIME = os.getenv('VIMRUNTIME'),
        },
      })
      screen:expect({
        grid = [[
          ^                                                  |
                                                            |*9
        ]],
        intermediate = true,
      })
      screen:try_resize(51, 11)
      screen:expect({
        grid = [[
          ^                                                   |
                                                             |*10
        ]],
      })
    end)
  end

  it('argv[0] can be overridden #23953', function()
    if not exec_lua('return pcall(require, "ffi")') then
      pending('missing LuaJIT FFI')
    end
    local script_file = 'Xargv0.lua'
    write_file(
      script_file,
      [=[
      local ffi = require('ffi')
      ffi.cdef([[int execl(const char *, const char *, ...);]])
      ffi.C.execl(vim.v.progpath, 'Xargv0nvim', '--clean', nil)
    ]=]
    )
    finally(function()
      os.remove(script_file)
    end)
    local screen = tt.setup_child_nvim({ '--clean', '-l', script_file })
    screen:expect {
      grid = [[
      ^                                                  |
      ~                                                 |*3
      [No Name]                       0,0-1          All|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]],
    }
    feed_data(':put =v:argv + [v:progname]\n')
    screen:expect {
      grid = [[
      Xargv0nvim                                        |
      --embed                                           |
      --clean                                           |
      ^Xargv0nvim                                        |
      [No Name] [+]                   5,1            Bot|
      4 more lines                                      |
      {3:-- TERMINAL --}                                    |
    ]],
    }
  end)

  it('with non-tty (pipe) stdout/stderr', function()
    finally(function()
      os.remove('testF')
    end)
    local screen = tt.setup_screen(
      0,
      ('"%s" --clean --cmd "set noswapfile noshowcmd noruler" --cmd "normal iabc" > /dev/null 2>&1 && cat testF && rm testF'):format(
        nvim_prog
      ),
      nil,
      { VIMRUNTIME = os.getenv('VIMRUNTIME') }
    )
    feed_data(':w testF\n:q\n')
    screen:expect([[
      :w testF                                          |
      :q                                                |
      abc                                               |
                                                        |
      [Process exited 0]^                                |
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('<C-h> #10134', function()
    local screen = tt.setup_child_nvim({
      '--clean',
      '--cmd',
      'colorscheme vim',
      '--cmd',
      'set noruler notermguicolors',
      '--cmd',
      ':nnoremap <C-h> :echomsg "\\<C-h\\>"<CR>',
    })
    screen:expect {
      grid = [[
      ^                                                  |
      {4:~                                                 }|*3
      {5:[No Name]                                         }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]],
    }

    command([[call chansend(b:terminal_job_id, "\<C-h>")]])
    screen:expect([[
      ^                                                  |
      {4:~                                                 }|*3
      {5:[No Name]                                         }|
      <C-h>                                             |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('draws line with many trailing spaces correctly #24955', function()
    local screen = tt.setup_child_nvim({
      '--clean',
      '--cmd',
      'set notermguicolors',
      '--cmd',
      'colorscheme vim',
      '--cmd',
      'call setline(1, ["1st line" .. repeat(" ", 153), "2nd line"])',
    }, { cols = 80 })
    screen:expect {
      grid = [[
      ^1st line                                                                        |
                                                                                      |*2
      2nd line                                                                        |
      {5:[No Name] [+]                                                 1,1            All}|
                                                                                      |
      {3:-- TERMINAL --}                                                                  |
    ]],
    }
    feed_data('$')
    screen:expect {
      grid = [[
      1st line                                                                        |
                                                                                      |
      ^                                                                                |
      2nd line                                                                        |
      {5:[No Name] [+]                                                 1,161          All}|
                                                                                      |
      {3:-- TERMINAL --}                                                                  |
    ]],
    }
  end)

  it('draws screen lines with leading spaces correctly #29711', function()
    local screen = tt.setup_child_nvim({
      '--clean',
      '--cmd',
      'set foldcolumn=6 | call setline(1, ["", repeat("aabb", 1000)]) | echo 42',
    }, { extra_rows = 10, cols = 66 })
    screen:expect {
      grid = [[
            ^                                                            |
            aabbaabbaabbaabbaabbaabbaabbaabbaabbaabbaabbaabbaabbaabbaabb|*12
            aabbaabbaabbaabbaabbaabbaabbaabbaabbaabbaabbaabbaabbaabba@@@|
      [No Name] [+]                                   1,0-1          Top|
      42                                                                |
      -- TERMINAL --                                                    |
    ]],
      attr_ids = {},
    }
    feed_data('\12') -- Ctrl-L
    -- The first line counts as 3 cells.
    -- For the second line, 6 repeated spaces at the start counts as 2 cells,
    -- so each screen line of the second line counts as 62 cells.
    -- After drawing the first line and 8 screen lines of the second line,
    -- 3 + 8 * 62 = 499 cells have been counted.
    -- The 6 repeated spaces at the start of the next screen line exceeds the
    -- 500-cell limit, so the buffer is flushed after these spaces.
    screen:expect {
      grid = [[
            ^                                                            |
            aabbaabbaabbaabbaabbaabbaabbaabbaabbaabbaabbaabbaabbaabbaabb|*12
            aabbaabbaabbaabbaabbaabbaabbaabbaabbaabbaabbaabbaabbaabba@@@|
      [No Name] [+]                                   1,0-1          Top|
                                                                        |
      -- TERMINAL --                                                    |
    ]],
      attr_ids = {},
    }
  end)

  it('no heap-buffer-overflow when changing &columns', function()
    -- Set a different bg colour and change $TERM to something dumber so the `print_spaces()`
    -- codepath in `clear_region()` is hit.
    local screen = tt.setup_child_nvim({
      '--clean',
      '--cmd',
      'set notermguicolors | highlight Normal ctermbg=red',
      '--cmd',
      'call setline(1, ["a"->repeat(&columns)])',
    }, { env = { TERM = 'ansi' } })

    screen:expect {
      grid = [[
      ^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      ~                                                 |*3
      [No Name] [+]                   1,1            All|
                                                        |
      -- TERMINAL --                                    |
    ]],
      attr_ids = {},
    }

    feed_data(':set columns=12\n')
    screen:expect {
      grid = [[
      ^aaaaaaaaaaaa                                      |
      aaaaaaaaaaaa                                      |*3
      < [+] 1,1                                         |
                                                        |
      -- TERMINAL --                                    |
    ]],
      attr_ids = {},
    }

    -- Wider than TUI, so screen state will look weird.
    -- Wait for the statusline to redraw to confirm that the TUI lives and ASAN is happy.
    feed_data(':set columns=99|set stl=redrawn%m\n')
    screen:expect({ any = 'redrawn%[%+%]' })
  end)
end)

describe('TUI UIEnter/UILeave', function()
  it('fires exactly once, after VimEnter', function()
    clear()
    local screen = tt.setup_child_nvim({
      '--clean',
      '--cmd',
      'colorscheme vim',
      '--cmd',
      'set noswapfile noshowcmd noruler notermguicolors',
      '--cmd',
      'let g:evs = []',
      '--cmd',
      'autocmd UIEnter *  :call add(g:evs, "UIEnter")',
      '--cmd',
      'autocmd UILeave *  :call add(g:evs, "UILeave")',
      '--cmd',
      'autocmd VimEnter * :call add(g:evs, "VimEnter")',
    })
    screen:expect {
      grid = [[
      ^                                                  |
      {4:~                                                 }|*3
      {5:[No Name]                                         }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]],
    }
    feed_data(':echo g:evs\n')
    screen:expect {
      grid = [[
      ^                                                  |
      {4:~                                                 }|*3
      {5:[No Name]                                         }|
      ['VimEnter', 'UIEnter']                           |
      {3:-- TERMINAL --}                                    |
    ]],
    }
  end)
end)

describe('TUI FocusGained/FocusLost', function()
  local screen
  local child_session

  before_each(function()
    clear()
    local child_server = new_pipename()
    screen = tt.setup_child_nvim({
      '--listen',
      child_server,
      '-u',
      'NONE',
      '-i',
      'NONE',
      '--cmd',
      'colorscheme vim',
      '--cmd',
      'set noswapfile noshowcmd noruler notermguicolors background=dark',
    })

    screen:expect([[
      ^                                                  |
      {4:~                                                 }|*3
      {5:[No Name]                                         }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    child_session = n.connect(child_server)
    child_session:request(
      'nvim_exec2',
      [[
      autocmd FocusGained * echo 'gained'
      autocmd FocusLost * echo 'lost'
    ]],
      {}
    )
    feed_data('\034\016') -- CTRL-\ CTRL-N
  end)

  it('in normal-mode', function()
    retry(2, 3 * screen.timeout, function()
      feed_data('\027[I')
      screen:expect([[
        ^                                                  |
        {4:~                                                 }|*3
        {5:[No Name]                                         }|
        gained                                            |
        {3:-- TERMINAL --}                                    |
      ]])

      feed_data('\027[O')
      screen:expect([[
        ^                                                  |
        {4:~                                                 }|*3
        {5:[No Name]                                         }|
        lost                                              |
        {3:-- TERMINAL --}                                    |
      ]])
    end)
  end)

  it('in insert-mode', function()
    feed_data(':set noshowmode\r')
    feed_data('i')
    screen:expect {
      grid = [[
      ^                                                  |
      {4:~                                                 }|*3
      {5:[No Name]                                         }|
      :set noshowmode                                   |
      {3:-- TERMINAL --}                                    |
    ]],
    }
    retry(2, 3 * screen.timeout, function()
      feed_data('\027[I')
      screen:expect([[
        ^                                                  |
        {4:~                                                 }|*3
        {5:[No Name]                                         }|
        gained                                            |
        {3:-- TERMINAL --}                                    |
      ]])
      feed_data('\027[O')
      screen:expect([[
        ^                                                  |
        {4:~                                                 }|*3
        {5:[No Name]                                         }|
        lost                                              |
        {3:-- TERMINAL --}                                    |
      ]])
    end)
  end)

  -- During cmdline-mode we ignore :echo invoked by timers/events.
  -- See commit: 5cc87d4dabd02167117be7a978b5c8faaa975419.
  it('in cmdline-mode does NOT :echo', function()
    feed_data(':')
    feed_data('\027[I')
    screen:expect([[
                                                        |
      {4:~                                                 }|*3
      {5:[No Name]                                         }|
      :^                                                 |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data('\027[O')
    screen:expect {
      grid = [[
                                                        |
      {4:~                                                 }|*3
      {5:[No Name]                                         }|
      :^                                                 |
      {3:-- TERMINAL --}                                    |
    ]],
      unchanged = true,
    }
  end)

  it('in cmdline-mode', function()
    -- Set up autocmds that modify the buffer, instead of just calling :echo.
    -- This is how we can test handling of focus gained/lost during cmdline-mode.
    -- See commit: 5cc87d4dabd02167117be7a978b5c8faaa975419.
    child_session:request(
      'nvim_exec2',
      [[
      autocmd!
      autocmd FocusLost * call append(line('$'), 'lost')
      autocmd FocusGained * call append(line('$'), 'gained')
    ]],
      {}
    )
    retry(2, 3 * screen.timeout, function()
      -- Enter cmdline-mode.
      feed_data(':')
      screen:sleep(1)
      -- Send focus lost/gained termcodes.
      feed_data('\027[O')
      feed_data('\027[I')
      screen:sleep(1)
      -- Exit cmdline-mode. Redraws from timers/events are blocked during
      -- cmdline-mode, so the buffer won't be updated until we exit cmdline-mode.
      feed_data('\n')
      screen:expect { any = 'lost' .. (' '):rep(46) .. '|\ngained' }
    end)
  end)

  it('in terminal-mode', function()
    feed_data(':set shell=' .. testprg('shell-test') .. ' shellcmdflag=EXE\n')
    feed_data(':set noshowmode laststatus=0\n')

    feed_data(':terminal zia\n')
    -- Wait for terminal to be ready.
    screen:expect {
      grid = [[
      ^ready $ zia                                       |
                                                        |
      [Process exited 0]                                |
                                                        |*2
      :terminal zia                                     |
      {3:-- TERMINAL --}                                    |
    ]],
    }

    feed_data('\027[I')
    screen:expect {
      grid = [[
      ^ready $ zia                                       |
                                                        |
      [Process exited 0]                                |
                                                        |*2
      gained                                            |
      {3:-- TERMINAL --}                                    |
    ]],
      timeout = (4 * screen.timeout),
    }

    feed_data('\027[O')
    screen:expect([[
      ^ready $ zia                                       |
                                                        |
      [Process exited 0]                                |
                                                        |*2
      lost                                              |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('in press-enter prompt', function()
    feed_data(":echom 'msg1'|echom 'msg2'|echom 'msg3'|echom 'msg4'|echom 'msg5'\n")
    -- Execute :messages to provoke the press-enter prompt.
    feed_data(':messages\n')
    screen:expect {
      grid = [[
      msg1                                              |
      msg2                                              |
      msg3                                              |
      msg4                                              |
      msg5                                              |
      {10:Press ENTER or type command to continue}^           |
      {3:-- TERMINAL --}                                    |
    ]],
    }
    feed_data('\027[I')
    feed_data('\027[I')
    screen:expect {
      grid = [[
      msg1                                              |
      msg2                                              |
      msg3                                              |
      msg4                                              |
      msg5                                              |
      {10:Press ENTER or type command to continue}^           |
      {3:-- TERMINAL --}                                    |
    ]],
      unchanged = true,
    }
  end)
end)

-- These tests require `tt` because --headless/--embed
-- does not initialize the TUI.
describe("TUI 't_Co' (terminal colors)", function()
  local screen

  local function assert_term_colors(term, colorterm, maxcolors)
    clear({ env = { TERM = term }, args = {} })
    screen = tt.setup_child_nvim({
      '--clean',
      '--cmd',
      'colorscheme vim',
      '--cmd',
      nvim_set .. ' notermguicolors',
    }, {
      env = {
        LANG = 'C',
        TERM = term or '',
        COLORTERM = colorterm or '',
      },
    })

    local tline
    if maxcolors == 8 then
      tline = '{9:~                                                 }'
    elseif maxcolors == 16 then
      tline = '~                                                 '
    else
      tline = '{4:~                                                 }'
    end

    screen:expect(string.format(
      [[
      ^                                                  |
      %s|*4
                                                        |
      {3:-- TERMINAL --}                                    |
    ]],
      tline
    ))

    feed_data(':echo &t_Co\n')
    screen:expect(string.format(
      [[
      ^                                                  |
      %s|*4
      %-3s                                               |
      {3:-- TERMINAL --}                                    |
    ]],
      tline,
      tostring(maxcolors and maxcolors or '')
    ))
  end

  -- ansi and no terminal type at all:

  it('no TERM uses 8 colors', function()
    assert_term_colors(nil, nil, 8)
  end)

  it('TERM=ansi no COLORTERM uses 8 colors', function()
    assert_term_colors('ansi', nil, 8)
  end)

  it('TERM=ansi with COLORTERM=anything-no-number uses 16 colors', function()
    assert_term_colors('ansi', 'yet-another-term', 16)
  end)

  it('unknown TERM COLORTERM with 256 in name uses 256 colors', function()
    assert_term_colors('ansi', 'yet-another-term-256color', 256)
  end)

  it('TERM=ansi-256color sets 256 colours', function()
    assert_term_colors('ansi-256color', nil, 256)
  end)

  -- Unknown terminal types:

  it('unknown TERM no COLORTERM sets 8 colours', function()
    assert_term_colors('yet-another-term', nil, 8)
  end)

  it('unknown TERM with COLORTERM=anything-no-number uses 16 colors', function()
    assert_term_colors('yet-another-term', 'yet-another-term', 16)
  end)

  it('unknown TERM with 256 in name sets 256 colours', function()
    assert_term_colors('yet-another-term-256color', nil, 256)
  end)

  it('unknown TERM COLORTERM with 256 in name uses 256 colors', function()
    assert_term_colors('yet-another-term', 'yet-another-term-256color', 256)
  end)

  -- Linux kernel terminal emulator:

  it('TERM=linux uses 256 colors', function()
    assert_term_colors('linux', nil, 256)
  end)

  it('TERM=linux-16color uses 256 colors', function()
    assert_term_colors('linux-16color', nil, 256)
  end)

  it('TERM=linux-256color uses 256 colors', function()
    assert_term_colors('linux-256color', nil, 256)
  end)

  -- screen:
  --
  -- FreeBSD falls back to the built-in screen-256colour entry.
  -- Linux and MacOS have a screen entry in external terminfo with 8 colours,
  -- which is raised to 16 by COLORTERM.

  it('TERM=screen no COLORTERM uses 8/256 colors', function()
    if is_os('freebsd') then
      assert_term_colors('screen', nil, 256)
    else
      assert_term_colors('screen', nil, 8)
    end
  end)

  it('TERM=screen COLORTERM=screen uses 16/256 colors', function()
    if is_os('freebsd') then
      assert_term_colors('screen', 'screen', 256)
    else
      assert_term_colors('screen', 'screen', 16)
    end
  end)

  it('TERM=screen COLORTERM=screen-256color uses 256 colors', function()
    assert_term_colors('screen', 'screen-256color', 256)
  end)

  it('TERM=screen-256color no COLORTERM uses 256 colors', function()
    assert_term_colors('screen-256color', nil, 256)
  end)

  -- tmux:
  --
  -- FreeBSD and MacOS fall back to the built-in tmux-256colour entry.
  -- Linux has a tmux entry in external terminfo with 8 colours,
  -- which is raised to 256.

  it('TERM=tmux no COLORTERM uses 256 colors', function()
    assert_term_colors('tmux', nil, 256)
  end)

  it('TERM=tmux COLORTERM=tmux uses 256 colors', function()
    assert_term_colors('tmux', 'tmux', 256)
  end)

  it('TERM=tmux COLORTERM=tmux-256color uses 256 colors', function()
    assert_term_colors('tmux', 'tmux-256color', 256)
  end)

  it('TERM=tmux-256color no COLORTERM uses 256 colors', function()
    assert_term_colors('tmux-256color', nil, 256)
  end)

  -- xterm and imitators:

  it('TERM=xterm uses 256 colors', function()
    assert_term_colors('xterm', nil, 256)
  end)

  it('TERM=xterm COLORTERM=gnome-terminal uses 256 colors', function()
    assert_term_colors('xterm', 'gnome-terminal', 256)
  end)

  it('TERM=xterm COLORTERM=mate-terminal uses 256 colors', function()
    assert_term_colors('xterm', 'mate-terminal', 256)
  end)

  it('TERM=xterm-256color uses 256 colors', function()
    assert_term_colors('xterm-256color', nil, 256)
  end)

  -- rxvt and stterm:
  --
  -- FreeBSD and MacOS fall back to the built-in rxvt-256color and
  -- st-256colour entries.
  -- Linux has an rxvt, an st, and an st-16color entry in external terminfo
  -- with 8, 8, and 16 colours respectively, which are raised to 256.

  it('TERM=rxvt no COLORTERM uses 256 colors', function()
    assert_term_colors('rxvt', nil, 256)
  end)

  it('TERM=rxvt COLORTERM=rxvt uses 256 colors', function()
    assert_term_colors('rxvt', 'rxvt', 256)
  end)

  it('TERM=rxvt-256color uses 256 colors', function()
    assert_term_colors('rxvt-256color', nil, 256)
  end)

  it('TERM=st no COLORTERM uses 256 colors', function()
    assert_term_colors('st', nil, 256)
  end)

  it('TERM=st COLORTERM=st uses 256 colors', function()
    assert_term_colors('st', 'st', 256)
  end)

  it('TERM=st COLORTERM=st-256color uses 256 colors', function()
    assert_term_colors('st', 'st-256color', 256)
  end)

  it('TERM=st-16color no COLORTERM uses 8/256 colors', function()
    assert_term_colors('st', nil, 256)
  end)

  it('TERM=st-16color COLORTERM=st uses 16/256 colors', function()
    assert_term_colors('st', 'st', 256)
  end)

  it('TERM=st-16color COLORTERM=st-256color uses 256 colors', function()
    assert_term_colors('st', 'st-256color', 256)
  end)

  it('TERM=st-256color uses 256 colors', function()
    assert_term_colors('st-256color', nil, 256)
  end)

  -- gnome and vte:
  --
  -- FreeBSD and MacOS fall back to the built-in vte-256color entry.
  -- Linux has a gnome, a vte, a gnome-256color, and a vte-256color entry in
  -- external terminfo with 8, 8, 256, and 256 colours respectively, which are
  -- raised to 256.

  it('TERM=gnome no COLORTERM uses 256 colors', function()
    assert_term_colors('gnome', nil, 256)
  end)

  it('TERM=gnome COLORTERM=gnome uses 256 colors', function()
    assert_term_colors('gnome', 'gnome', 256)
  end)

  it('TERM=gnome COLORTERM=gnome-256color uses 256 colors', function()
    assert_term_colors('gnome', 'gnome-256color', 256)
  end)

  it('TERM=gnome-256color uses 256 colors', function()
    assert_term_colors('gnome-256color', nil, 256)
  end)

  it('TERM=vte no COLORTERM uses 256 colors', function()
    assert_term_colors('vte', nil, 256)
  end)

  it('TERM=vte COLORTERM=vte uses 256 colors', function()
    assert_term_colors('vte', 'vte', 256)
  end)

  it('TERM=vte COLORTERM=vte-256color uses 256 colors', function()
    assert_term_colors('vte', 'vte-256color', 256)
  end)

  it('TERM=vte-256color uses 256 colors', function()
    assert_term_colors('vte-256color', nil, 256)
  end)

  -- others:

  -- TODO(blueyed): this is made pending, since it causes failure + later hang
  --                when using non-compatible libvterm (#9494/#10179).
  pending('TERM=interix uses 8 colors', function()
    assert_term_colors('interix', nil, 8)
  end)

  it('TERM=iTerm.app uses 256 colors', function()
    assert_term_colors('iTerm.app', nil, 256)
  end)

  it('TERM=iterm uses 256 colors', function()
    assert_term_colors('iterm', nil, 256)
  end)
end)

-- These tests require `tt` because --headless/--embed
-- does not initialize the TUI.
describe("TUI 'term' option", function()
  local screen

  local function assert_term(term_envvar, term_expected)
    clear()
    screen = tt.setup_child_nvim({
      '--clean',
      '--cmd',
      nvim_set .. ' notermguicolors',
    }, {
      env = {
        LANG = 'C',
        TERM = term_envvar or '',
      },
    })

    local full_timeout = screen.timeout
    retry(nil, 2 * full_timeout, function() -- Wait for TUI thread to set 'term'.
      feed_data(":echo 'term='.(&term)\n")
      screen:expect { any = 'term=' .. term_expected, timeout = 250 }
    end)
  end

  it('gets builtin term if $TERM is invalid', function()
    assert_term('foo', 'builtin_ansi')
  end)

  it('gets system-provided term if $TERM is valid', function()
    if is_os('openbsd') then
      assert_term('xterm', 'xterm')
    elseif is_os('bsd') then -- BSD lacks terminfo, builtin is always used.
      assert_term('xterm', 'builtin_xterm')
    elseif is_os('mac') then
      local status, _ = pcall(assert_term, 'xterm', 'xterm')
      if not status then
        pending('macOS: unibilium could not find terminfo')
      end
    else
      assert_term('xterm', 'xterm')
    end
  end)

  it('builtin terms', function()
    -- These non-standard terminfos are always builtin.
    assert_term('win32con', 'builtin_win32con')
    assert_term('conemu', 'builtin_conemu')
    assert_term('vtpcon', 'builtin_vtpcon')
  end)
end)

-- These tests require `tt` because --headless/--embed
-- does not initialize the TUI.
describe('TUI', function()
  local screen
  local logfile = 'Xtest_tui_verbose_log'
  after_each(function()
    os.remove(logfile)
  end)

  -- Runs (child) `nvim` in a TTY (:terminal), to start the builtin TUI.
  local function nvim_tui(extra_args)
    clear()
    screen = tt.setup_child_nvim({
      '--clean',
      '--cmd',
      'colorscheme vim',
      '--cmd',
      nvim_set .. ' notermguicolors',
      extra_args,
    }, {
      env = {
        LANG = 'C',
      },
    })
  end

  it('-V3log logs terminfo values', function()
    nvim_tui('-V3' .. logfile)

    -- Wait for TUI to start.
    feed_data('Gitext')
    screen:expect([[
      text^                                              |
      {4:~                                                 }|*4
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])

    retry(nil, 3000, function() -- Wait for log file to be flushed.
      local log = read_file('Xtest_tui_verbose_log') or ''
      eq('--- Terminal info --- {{{\n', string.match(log, '%-%-%- Terminal.-\n')) -- }}}
      ok(#log > 50)
    end)
  end)

  it('does not crash on large inputs #26099', function()
    nvim_tui()

    screen:expect([[
      ^                                                  |
      {4:~                                                 }|*4
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])

    feed_data(string.format('\027]52;c;%s\027\\', string.rep('A', 8192)))

    screen:expect {
      grid = [[
      ^                                                  |
      {4:~                                                 }|*4
                                                        |
      {3:-- TERMINAL --}                                    |
    ]],
      unchanged = true,
    }
  end)

  it('queries the terminal for truecolor support', function()
    clear()
    exec_lua([[
      vim.api.nvim_create_autocmd('TermRequest', {
        callback = function(args)
          local req = args.data.sequence
          local sequence = req:match('^\027P%+q([%x;]+)$')
          if sequence then
            local t = {}
            for cap in vim.gsplit(sequence, ';') do
              local resp = string.format('\027P1+r%s\027\\', sequence)
              vim.api.nvim_chan_send(vim.bo[args.buf].channel, resp)
              t[vim.text.hexdecode(cap)] = true
            end
            vim.g.xtgettcap = t
            return true
          end
        end,
      })
    ]])

    local child_server = new_pipename()
    screen = tt.setup_child_nvim({
      '--clean',
      '--listen',
      child_server,
    }, {
      env = {
        VIMRUNTIME = os.getenv('VIMRUNTIME'),

        -- Force COLORTERM to be unset and use a TERM that does not contain Tc or RGB in terminfo.
        -- This will force the nested nvim instance to query with XTGETTCAP
        COLORTERM = '',
        TERM = 'xterm-256colors',
      },
    })

    screen:expect({ any = '%[No Name%]' })

    local child_session = n.connect(child_server)
    retry(nil, 1000, function()
      eq({
        Tc = true,
        RGB = true,
        setrgbf = true,
        setrgbb = true,
      }, eval("get(g:, 'xtgettcap', '')"))
      eq({ true, 1 }, { child_session:request('nvim_eval', '&termguicolors') })
    end)
  end)

  it('does not query the terminal for truecolor support if $COLORTERM is set', function()
    clear()
    exec_lua([[
      vim.api.nvim_create_autocmd('TermRequest', {
        callback = function(args)
          local req = args.data.sequence
          vim.g.termrequest = req
          local xtgettcap = req:match('^\027P%+q([%x;]+)$')
          if xtgettcap then
            local t = {}
            for cap in vim.gsplit(xtgettcap, ';') do
              local resp = string.format('\027P1+r%s\027\\', xtgettcap)
              vim.api.nvim_chan_send(vim.bo[args.buf].channel, resp)
              t[vim.text.hexdecode(cap)] = true
            end
            vim.g.xtgettcap = t
            return true
          elseif req:match('^\027P$qm\027\\$') then
            vim.g.decrqss = true
          end
        end,
      })
    ]])

    local child_server = new_pipename()
    screen = tt.setup_child_nvim({
      '--clean',
      '--listen',
      child_server,
    }, {
      env = {
        VIMRUNTIME = os.getenv('VIMRUNTIME'),
        -- With COLORTERM=256, Nvim should not query the terminal and should not set 'tgc'
        COLORTERM = '256',
        TERM = 'xterm-256colors',
      },
    })

    screen:expect({ any = '%[No Name%]' })

    local child_session = n.connect(child_server)
    retry(nil, 1000, function()
      local xtgettcap = eval("get(g:, 'xtgettcap', {})")
      eq(nil, xtgettcap['Tc'])
      eq(nil, xtgettcap['RGB'])
      eq(nil, xtgettcap['setrgbf'])
      eq(nil, xtgettcap['setrgbb'])
      eq(0, eval([[get(g:, 'decrqss')]]))
      eq({ true, 0 }, { child_session:request('nvim_eval', '&termguicolors') })
    end)
  end)

  it('queries the terminal for OSC 52 support', function()
    clear()
    exec_lua([[
      vim.api.nvim_create_autocmd('TermRequest', {
        callback = function(args)
          local req = args.data.sequence
          local sequence = req:match('^\027P%+q([%x;]+)$')
          if sequence and vim.text.hexdecode(sequence) == 'Ms' then
            local resp = string.format('\027P1+r%s=%s\027\\', sequence, vim.text.hexencode('\027]52;;\027\\'))
            vim.api.nvim_chan_send(vim.bo[args.buf].channel, resp)
            return true
          end
        end,
      })
    ]])

    local child_server = new_pipename()
    screen = tt.setup_child_nvim({
      '--listen',
      child_server,
      -- Use --clean instead of -u NONE to load the osc52 plugin
      '--clean',
    }, {
      env = {
        VIMRUNTIME = os.getenv('VIMRUNTIME'),
      },
    })

    screen:expect({ any = '%[No Name%]' })

    local child_session = n.connect(child_server)
    retry(nil, 1000, function()
      eq({ true, { osc52 = true } }, { child_session:request('nvim_eval', 'g:termfeatures') })
    end)

    -- Attach another (non-TUI) UI to the child instance
    local alt = Screen.new(nil, nil, nil, child_session)

    -- Detach the first (primary) client so only the second UI is attached
    feed_data(':detach\n')

    alt:expect({ any = '%[No Name%]' })

    -- osc52 should be cleared from termfeatures
    eq({ true, {} }, { child_session:request('nvim_eval', 'g:termfeatures') })

    alt:detach()
  end)

  it('does not query the terminal for OSC 52 support when disabled', function()
    clear()
    exec_lua([[
      _G.query = false
      vim.api.nvim_create_autocmd('TermRequest', {
        callback = function(args)
          local req = args.data.sequence
          local sequence = req:match('^\027P%+q([%x;]+)$')
          if sequence and vim.text.hexdecode(sequence) == 'Ms' then
            _G.query = true
          end
        end,
      })
    ]])

    local child_server = new_pipename()
    screen = tt.setup_child_nvim({
      '--listen',
      child_server,
      -- Use --clean instead of -u NONE to load the osc52 plugin
      '--clean',
      '--cmd',
      'let g:termfeatures = #{osc52: v:false}',
    }, {
      env = {
        VIMRUNTIME = os.getenv('VIMRUNTIME'),
      },
    })

    screen:expect({ any = '%[No Name%]' })

    local child_session = n.connect(child_server)
    eq({ true, { osc52 = false } }, { child_session:request('nvim_eval', 'g:termfeatures') })
    eq(false, exec_lua([[return _G.query]]))
  end)
end)

describe('TUI bg color', function()
  before_each(clear)

  it('is properly set in a nested Nvim instance when background=dark', function()
    command('highlight clear Normal')
    command('set background=dark') -- set outer Nvim background
    local child_server = new_pipename()
    local screen = tt.setup_child_nvim({
      '--clean',
      '--listen',
      child_server,
      '--cmd',
      'colorscheme vim',
      '--cmd',
      'set noswapfile',
    })
    screen:expect({ any = '%[No Name%]' })
    local child_session = n.connect(child_server)
    retry(nil, nil, function()
      eq({ true, 'dark' }, { child_session:request('nvim_eval', '&background') })
    end)
  end)

  it('is properly set in a nested Nvim instance when background=light', function()
    command('highlight clear Normal')
    command('set background=light') -- set outer Nvim background
    local child_server = new_pipename()
    local screen = tt.setup_child_nvim({
      '--clean',
      '--listen',
      child_server,
      '--cmd',
      'colorscheme vim',
      '--cmd',
      'set noswapfile',
    })
    screen:expect({ any = '%[No Name%]' })
    local child_session = n.connect(child_server)
    retry(nil, nil, function()
      eq({ true, 'light' }, { child_session:request('nvim_eval', '&background') })
    end)
  end)

  it('queries the terminal for background color', function()
    exec_lua([[
      vim.api.nvim_create_autocmd('TermRequest', {
        callback = function(args)
          local req = args.data.sequence
          if req == '\027]11;?' then
            vim.g.oscrequest = true
            return true
          end
        end,
      })
    ]])
    tt.setup_child_nvim({
      '--clean',
      '--cmd',
      'colorscheme vim',
      '--cmd',
      'set noswapfile',
    })
    retry(nil, 1000, function()
      eq(true, eval("get(g:, 'oscrequest', v:false)"))
    end)
  end)

  it('triggers OptionSet from automatic background processing', function()
    local screen = tt.setup_child_nvim({
      '--clean',
      '--cmd',
      'colorscheme vim',
      '--cmd',
      'set noswapfile',
      '-c',
      'autocmd OptionSet background echo "did OptionSet, yay!"',
    })
    screen:expect([[
      ^                                                  |
      {3:~}                                                 |*3
      {5:[No Name]                       0,0-1          All}|
      did OptionSet, yay!                               |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('sends theme update notifications when background changes #31652', function()
    command('set background=dark') -- set outer Nvim background
    local child_server = new_pipename()
    local screen = tt.setup_child_nvim({
      '--clean',
      '--listen',
      child_server,
      '--cmd',
      'colorscheme vim',
      '--cmd',
      'set noswapfile',
    })
    screen:expect({ any = '%[No Name%]' })
    local child_session = n.connect(child_server)
    retry(nil, nil, function()
      eq({ true, 'dark' }, { child_session:request('nvim_eval', '&background') })
    end)
    command('set background=light') -- set outer Nvim background
    retry(nil, nil, function()
      eq({ true, 'light' }, { child_session:request('nvim_eval', '&background') })
    end)
  end)
end)

describe('TUI client', function()
  after_each(function()
    os.remove(testlog)
  end)

  it('connects to remote instance (with its own TUI)', function()
    local server_super = n.new_session(false)
    local client_super = n.new_session(true)

    set_session(server_super)
    local server_pipe = new_pipename()
    local screen_server = tt.setup_child_nvim({
      '--clean',
      '--listen',
      server_pipe,
      '--cmd',
      'colorscheme vim',
      '--cmd',
      nvim_set .. ' notermguicolors laststatus=2 background=dark',
    })

    feed_data('iHello, World')
    screen_server:expect {
      grid = [[
      Hello, World^                                      |
      {4:~                                                 }|*3
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]],
    }
    feed_data('\027')
    screen_server:expect {
      grid = [[
      Hello, Worl^d                                      |
      {4:~                                                 }|*3
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]],
    }

    set_session(client_super)
    local screen_client = tt.setup_child_nvim({
      '--remote-ui',
      '--server',
      server_pipe,
    })

    screen_client:expect {
      grid = [[
      Hello, Worl^d                                      |
      {4:~                                                 }|*3
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]],
    }

    -- grid smaller than containing terminal window is cleared properly
    feed_data(":call setline(1,['a'->repeat(&columns)]->repeat(&lines))\n")
    feed_data('0:set lines=3\n')
    screen_server:expect {
      grid = [[
      ^aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      {5:[No Name] [+]                                     }|
                                                        |*4
      {3:-- TERMINAL --}                                    |
    ]],
    }

    feed_data(':q!\n')

    server_super:close()
    client_super:close()
  end)

  it('connects to remote instance (--headless)', function()
    local server = n.new_session(false)
    local client_super = n.new_session(true, { env = { NVIM_LOG_FILE = testlog } })

    set_session(server)
    local server_pipe = api.nvim_get_vvar('servername')
    server:request('nvim_input', 'iHalloj!<Esc>')
    server:request('nvim_command', 'set notermguicolors')

    set_session(client_super)
    local screen_client = tt.setup_child_nvim({
      '--remote-ui',
      '--server',
      server_pipe,
    })

    screen_client:expect {
      grid = [[
      Halloj^!                                           |
      {4:~                                                 }|*4
                                                        |
      {3:-- TERMINAL --}                                    |
    ]],
    }

    -- No heap-use-after-free when receiving UI events after deadly signal #22184
    server:request('nvim_input', ('a'):rep(1000))
    exec_lua([[vim.uv.kill(vim.fn.jobpid(vim.bo.channel), 'sigterm')]])
    screen_client:expect {
      grid = [[
      Nvim: Caught deadly signal 'SIGTERM'              |
                                                        |
      [Process exited 1]^                                |
                                                        |*3
      {3:-- TERMINAL --}                                    |
    ]],
    }

    eq(0, api.nvim_get_vvar('shell_error'))
    -- exits on input eof #22244
    fn.system({ nvim_prog, '--remote-ui', '--server', server_pipe })
    eq(1, api.nvim_get_vvar('shell_error'))

    client_super:close()
    server:close()
    if is_os('mac') then
      assert_log('uv_tty_set_mode failed: Unknown system error %-102', testlog)
    end
  end)

  it('throws error when no server exists', function()
    clear()
    local screen = tt.setup_child_nvim({
      '--remote-ui',
      '--server',
      '127.0.0.1:2436546',
    }, { cols = 60 })

    screen:expect([[
      Remote ui failed to start: {MATCH:.*}|
                                                                  |
      [Process exited 1]^                                          |
                                                                  |*3
      {3:-- TERMINAL --}                                              |
    ]])
  end)

  local function test_remote_tui_quit(status)
    local server_super = n.clear()
    local client_super = n.new_session(true)
    finally(function()
      server_super:close()
      client_super:close()
    end)

    local server_pipe = new_pipename()
    local screen_server = tt.setup_child_nvim({
      '--clean',
      '--listen',
      server_pipe,
      '--cmd',
      'colorscheme vim',
      '--cmd',
      nvim_set .. ' notermguicolors laststatus=2 background=dark',
    })
    screen_server:expect {
      grid = [[
      ^                                                  |
      {4:~                                                 }|*3
      {5:[No Name]                                         }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]],
    }

    feed_data('iHello, World')
    screen_server:expect {
      grid = [[
      Hello, World^                                      |
      {4:~                                                 }|*3
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]],
    }
    feed_data('\027')
    screen_server:expect {
      grid = [[
      Hello, Worl^d                                      |
      {4:~                                                 }|*3
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]],
    }

    set_session(client_super)
    local screen_client = tt.setup_child_nvim({
      '--remote-ui',
      '--server',
      server_pipe,
    })

    screen_client:expect {
      grid = [[
      Hello, Worl^d                                      |
      {4:~                                                 }|*3
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]],
    }

    -- quitting the server
    set_session(server_super)
    feed_data(status and ':' .. status .. 'cquit!\n' or ':quit!\n')
    status = status and status or 0
    screen_server:expect({ any = 'Process exited ' .. status })
    screen_client:expect({ any = 'Process exited ' .. status })
  end

  describe('exits when server quits', function()
    it('with :quit', function()
      test_remote_tui_quit()
    end)

    it('with :cquit', function()
      test_remote_tui_quit(42)
    end)
  end)
end)
