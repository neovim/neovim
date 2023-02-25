-- TUI acceptance tests.
-- Uses :terminal as a way to send keys and assert screen state.
--
-- "bracketed paste" terminal feature:
-- http://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h2-Bracketed-Paste-Mode

local helpers = require('test.functional.helpers')(after_each)
local thelpers = require('test.functional.terminal.helpers')
local Screen = require('test.functional.ui.screen')
local eq = helpers.eq
local feed_command = helpers.feed_command
local feed_data = thelpers.feed_data
local clear = helpers.clear
local command = helpers.command
local dedent = helpers.dedent
local exec = helpers.exec
local exec_lua = helpers.exec_lua
local testprg = helpers.testprg
local retry = helpers.retry
local nvim_prog = helpers.nvim_prog
local nvim_set = helpers.nvim_set
local ok = helpers.ok
local read_file = helpers.read_file
local funcs = helpers.funcs
local meths = helpers.meths
local is_ci = helpers.is_ci
local is_os = helpers.is_os
local new_pipename = helpers.new_pipename
local spawn_argv = helpers.spawn_argv
local set_session = helpers.set_session
local feed = helpers.feed
local eval = helpers.eval

if helpers.skip(helpers.is_os('win')) then return end

describe('TUI', function()
  local screen
  local child_session
  local child_exec_lua

  before_each(function()
    clear()
    local child_server = new_pipename()
    screen = thelpers.screen_setup(0,
      string.format([=[["%s", "--listen", "%s", "-u", "NONE", "-i", "NONE", "--cmd", "%s laststatus=2 background=dark"]]=],
        nvim_prog, child_server, nvim_set))
    screen:expect([[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    child_session = helpers.connect(child_server)
    child_exec_lua = thelpers.make_lua_executor(child_session)
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
      local _, buflines = child_session:request(
        'nvim_buf_get_lines', 0, 0, -1, false)
      eq(expected, buflines)
    end)
  end

  it('rapid resize #7572 #7628', function()
    -- Need buffer rows to provoke the behavior.
    feed_data(":edit test/functional/fixtures/bigfile.txt\n")
    screen:expect([[
      {1:0}000;<control>;Cc;0;BN;;;;;N;NULL;;;;             |
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
      eq({true, 57}, {child_session:request('nvim_win_get_width', 0)})
    end)
  end)

  it('accepts resize while pager is active', function()
    child_session:request("nvim_exec", [[
    set more
    func! ManyErr()
      for i in range(10)
        echoerr "FAIL ".i
      endfor
    endfunc
    ]], false)
    feed_data(':call ManyErr()\r')
    screen:expect{grid=[[
      {8:Error detected while processing function ManyErr:} |
      {11:line    2:}                                        |
      {8:FAIL 0}                                            |
      {8:FAIL 1}                                            |
      {8:FAIL 2}                                            |
      {10:-- More --}{1: }                                       |
      {3:-- TERMINAL --}                                    |
    ]]}

    feed_data('d')
    screen:expect{grid=[[
      {8:FAIL 1}                                            |
      {8:FAIL 2}                                            |
      {8:FAIL 3}                                            |
      {8:FAIL 4}                                            |
      {8:FAIL 5}                                            |
      {10:-- More --}{1: }                                       |
      {3:-- TERMINAL --}                                    |
    ]]}

    screen:try_resize(50,5)
    screen:expect{grid=[[
      {8:FAIL 3}                                            |
      {8:FAIL 4}                                            |
      {8:FAIL 5}                                            |
      {10:-- More --}{1: }                                       |
      {3:-- TERMINAL --}                                    |
    ]]}

    feed_data('g')
    screen:expect{grid=[[
      :call ManyErr()                                   |
      {8:Error detected while processing function ManyErr:} |
      {11:line    2:}                                        |
      {10:-- More --}{1: }                                       |
      {3:-- TERMINAL --}                                    |
    ]]}

    screen:try_resize(50,10)
    screen:expect{grid=[[
      :call ManyErr()                                   |
      {8:Error detected while processing function ManyErr:} |
      {11:line    2:}                                        |
      {8:FAIL 0}                                            |
      {8:FAIL 1}                                            |
      {8:FAIL 2}                                            |
      {8:FAIL 3}                                            |
      {8:FAIL 4}                                            |
      {10:-- More --}{1: }                                       |
      {3:-- TERMINAL --}                                    |
    ]]}

    feed_data('\003')
    screen:expect{grid=[[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]]}
  end)

  it('accepts basic utf-8 input', function()
    feed_data('iabc\ntest1\ntest2')
    screen:expect([[
      abc                                               |
      test1                                             |
      test2{1: }                                            |
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data('\027')
    screen:expect([[
      abc                                               |
      test1                                             |
      test{1:2}                                             |
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('interprets leading <Esc> byte as ALT modifier in normal-mode', function()
    local keys = 'dfghjkl'
    for c in keys:gmatch('.') do
      feed_command('nnoremap <a-'..c..'> ialt-'..c..'<cr><esc>')
      feed_data('\027'..c)
    end
    screen:expect([[
      alt-j                                             |
      alt-k                                             |
      alt-l                                             |
      {1: }                                                 |
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data('gg')
    screen:expect([[
      {1:a}lt-d                                             |
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
      <M-j>{1: }                                            |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('interprets <Esc>[27u as <Esc>', function()
    feed_command('nnoremap <M-;> <Nop>')
    feed_command('nnoremap <Esc> AESC<Esc>')
    feed_command('nnoremap ; Asemicolon<Esc>')
    feed_data('\027[27u;')
    screen:expect([[
      ESCsemicolo{1:n}                                      |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
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
      <M-C-Space>{1: }                                      |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
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
    local attrs = screen:get_default_attr_ids()
    attrs[11] = {foreground = 81}
    screen:expect([[
    {11:^G^V^M}{1: }                                           |
    {4:~                                                 }|
    {4:~                                                 }|
    {4:~                                                 }|
    {5:[No Name] [+]                                     }|
    {3:-- INSERT --}                                      |
    {3:-- TERMINAL --}                                    |
    ]], attrs)
  end)

  it('accepts mouse wheel events #19992', function()
    child_session:request('nvim_exec', [[
      set number nostartofline nowrap mousescroll=hor:1,ver:1
      call setline(1, repeat([join(range(10), '----')], 10))
      vsplit
    ]], false)
    screen:expect([[
      {11:  1 }{1:0}----1----2----3----4│{11:  1 }0----1----2----3----|
      {11:  2 }0----1----2----3----4│{11:  2 }0----1----2----3----|
      {11:  3 }0----1----2----3----4│{11:  3 }0----1----2----3----|
      {11:  4 }0----1----2----3----4│{11:  4 }0----1----2----3----|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <ScrollWheelDown> in active window
    feed_data('\027[<65;8;1M')
    screen:expect([[
      {11:  2 }{1:0}----1----2----3----4│{11:  1 }0----1----2----3----|
      {11:  3 }0----1----2----3----4│{11:  2 }0----1----2----3----|
      {11:  4 }0----1----2----3----4│{11:  3 }0----1----2----3----|
      {11:  5 }0----1----2----3----4│{11:  4 }0----1----2----3----|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <ScrollWheelDown> in inactive window
    feed_data('\027[<65;48;1M')
    screen:expect([[
      {11:  2 }{1:0}----1----2----3----4│{11:  2 }0----1----2----3----|
      {11:  3 }0----1----2----3----4│{11:  3 }0----1----2----3----|
      {11:  4 }0----1----2----3----4│{11:  4 }0----1----2----3----|
      {11:  5 }0----1----2----3----4│{11:  5 }0----1----2----3----|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <ScrollWheelRight> in active window
    feed_data('\027[<67;8;1M')
    screen:expect([[
      {11:  2 }{1:-}---1----2----3----4-│{11:  2 }0----1----2----3----|
      {11:  3 }----1----2----3----4-│{11:  3 }0----1----2----3----|
      {11:  4 }----1----2----3----4-│{11:  4 }0----1----2----3----|
      {11:  5 }----1----2----3----4-│{11:  5 }0----1----2----3----|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <ScrollWheelRight> in inactive window
    feed_data('\027[<67;48;1M')
    screen:expect([[
      {11:  2 }{1:-}---1----2----3----4-│{11:  2 }----1----2----3----4|
      {11:  3 }----1----2----3----4-│{11:  3 }----1----2----3----4|
      {11:  4 }----1----2----3----4-│{11:  4 }----1----2----3----4|
      {11:  5 }----1----2----3----4-│{11:  5 }----1----2----3----4|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <S-ScrollWheelDown> in active window
    feed_data('\027[<69;8;1M')
    screen:expect([[
      {11:  5 }{1:-}---1----2----3----4-│{11:  2 }----1----2----3----4|
      {11:  6 }----1----2----3----4-│{11:  3 }----1----2----3----4|
      {11:  7 }----1----2----3----4-│{11:  4 }----1----2----3----4|
      {11:  8 }----1----2----3----4-│{11:  5 }----1----2----3----4|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <S-ScrollWheelDown> in inactive window
    feed_data('\027[<69;48;1M')
    screen:expect([[
      {11:  5 }{1:-}---1----2----3----4-│{11:  5 }----1----2----3----4|
      {11:  6 }----1----2----3----4-│{11:  6 }----1----2----3----4|
      {11:  7 }----1----2----3----4-│{11:  7 }----1----2----3----4|
      {11:  8 }----1----2----3----4-│{11:  8 }----1----2----3----4|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <S-ScrollWheelRight> in active window
    feed_data('\027[<71;8;1M')
    screen:expect([[
      {11:  5 }{1:-}---6----7----8----9 │{11:  5 }----1----2----3----4|
      {11:  6 }----6----7----8----9 │{11:  6 }----1----2----3----4|
      {11:  7 }----6----7----8----9 │{11:  7 }----1----2----3----4|
      {11:  8 }----6----7----8----9 │{11:  8 }----1----2----3----4|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <S-ScrollWheelRight> in inactive window
    feed_data('\027[<71;48;1M')
    screen:expect([[
      {11:  5 }{1:-}---6----7----8----9 │{11:  5 }5----6----7----8----|
      {11:  6 }----6----7----8----9 │{11:  6 }5----6----7----8----|
      {11:  7 }----6----7----8----9 │{11:  7 }5----6----7----8----|
      {11:  8 }----6----7----8----9 │{11:  8 }5----6----7----8----|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <ScrollWheelUp> in active window
    feed_data('\027[<64;8;1M')
    screen:expect([[
      {11:  4 }----6----7----8----9 │{11:  5 }5----6----7----8----|
      {11:  5 }{1:-}---6----7----8----9 │{11:  6 }5----6----7----8----|
      {11:  6 }----6----7----8----9 │{11:  7 }5----6----7----8----|
      {11:  7 }----6----7----8----9 │{11:  8 }5----6----7----8----|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <ScrollWheelUp> in inactive window
    feed_data('\027[<64;48;1M')
    screen:expect([[
      {11:  4 }----6----7----8----9 │{11:  4 }5----6----7----8----|
      {11:  5 }{1:-}---6----7----8----9 │{11:  5 }5----6----7----8----|
      {11:  6 }----6----7----8----9 │{11:  6 }5----6----7----8----|
      {11:  7 }----6----7----8----9 │{11:  7 }5----6----7----8----|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <ScrollWheelLeft> in active window
    feed_data('\027[<66;8;1M')
    screen:expect([[
      {11:  4 }5----6----7----8----9│{11:  4 }5----6----7----8----|
      {11:  5 }5{1:-}---6----7----8----9│{11:  5 }5----6----7----8----|
      {11:  6 }5----6----7----8----9│{11:  6 }5----6----7----8----|
      {11:  7 }5----6----7----8----9│{11:  7 }5----6----7----8----|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <ScrollWheelLeft> in inactive window
    feed_data('\027[<66;48;1M')
    screen:expect([[
      {11:  4 }5----6----7----8----9│{11:  4 }-5----6----7----8---|
      {11:  5 }5{1:-}---6----7----8----9│{11:  5 }-5----6----7----8---|
      {11:  6 }5----6----7----8----9│{11:  6 }-5----6----7----8---|
      {11:  7 }5----6----7----8----9│{11:  7 }-5----6----7----8---|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <S-ScrollWheelUp> in active window
    feed_data('\027[<68;8;1M')
    screen:expect([[
      {11:  1 }5----6----7----8----9│{11:  4 }-5----6----7----8---|
      {11:  2 }5----6----7----8----9│{11:  5 }-5----6----7----8---|
      {11:  3 }5----6----7----8----9│{11:  6 }-5----6----7----8---|
      {11:  4 }5{1:-}---6----7----8----9│{11:  7 }-5----6----7----8---|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <S-ScrollWheelUp> in inactive window
    feed_data('\027[<68;48;1M')
    screen:expect([[
      {11:  1 }5----6----7----8----9│{11:  1 }-5----6----7----8---|
      {11:  2 }5----6----7----8----9│{11:  2 }-5----6----7----8---|
      {11:  3 }5----6----7----8----9│{11:  3 }-5----6----7----8---|
      {11:  4 }5{1:-}---6----7----8----9│{11:  4 }-5----6----7----8---|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <S-ScrollWheelLeft> in active window
    feed_data('\027[<70;8;1M')
    screen:expect([[
      {11:  1 }0----1----2----3----4│{11:  1 }-5----6----7----8---|
      {11:  2 }0----1----2----3----4│{11:  2 }-5----6----7----8---|
      {11:  3 }0----1----2----3----4│{11:  3 }-5----6----7----8---|
      {11:  4 }0----1----2----3----{1:4}│{11:  4 }-5----6----7----8---|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- <S-ScrollWheelLeft> in inactive window
    feed_data('\027[<70;48;1M')
    screen:expect([[
      {11:  1 }0----1----2----3----4│{11:  1 }0----1----2----3----|
      {11:  2 }0----1----2----3----4│{11:  2 }0----1----2----3----|
      {11:  3 }0----1----2----3----4│{11:  3 }0----1----2----3----|
      {11:  4 }0----1----2----3----{1:4}│{11:  4 }0----1----2----3----|
      {5:[No Name] [+]             }{1:[No Name] [+]           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('accepts keypad keys from kitty keyboard protocol #19180', function()
    feed_data('i')
    feed_data(funcs.nr2char(57399)) -- KP_0
    feed_data(funcs.nr2char(57400)) -- KP_1
    feed_data(funcs.nr2char(57401)) -- KP_2
    feed_data(funcs.nr2char(57402)) -- KP_3
    feed_data(funcs.nr2char(57403)) -- KP_4
    feed_data(funcs.nr2char(57404)) -- KP_5
    feed_data(funcs.nr2char(57405)) -- KP_6
    feed_data(funcs.nr2char(57406)) -- KP_7
    feed_data(funcs.nr2char(57407)) -- KP_8
    feed_data(funcs.nr2char(57408)) -- KP_9
    feed_data(funcs.nr2char(57409)) -- KP_DECIMAL
    feed_data(funcs.nr2char(57410)) -- KP_DIVIDE
    feed_data(funcs.nr2char(57411)) -- KP_MULTIPLY
    feed_data(funcs.nr2char(57412)) -- KP_SUBTRACT
    feed_data(funcs.nr2char(57413)) -- KP_ADD
    feed_data(funcs.nr2char(57414)) -- KP_ENTER
    feed_data(funcs.nr2char(57415)) -- KP_EQUAL
    screen:expect([[
      0123456789./*-+                                   |
      ={1: }                                                |
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data(funcs.nr2char(57417)) -- KP_LEFT
    screen:expect([[
      0123456789./*-+                                   |
      {1:=}                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data(funcs.nr2char(57418)) -- KP_RIGHT
    screen:expect([[
      0123456789./*-+                                   |
      ={1: }                                                |
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data(funcs.nr2char(57419)) -- KP_UP
    screen:expect([[
      0{1:1}23456789./*-+                                   |
      =                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data(funcs.nr2char(57420)) -- KP_DOWN
    screen:expect([[
      0123456789./*-+                                   |
      ={1: }                                                |
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data(funcs.nr2char(57425)) -- KP_INSERT
    screen:expect([[
      0123456789./*-+                                   |
      ={1: }                                                |
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
      {3:-- REPLACE --}                                     |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data('\027[27u') -- ESC
    screen:expect([[
      0123456789./*-+                                   |
      {1:=}                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data('\027[57417;5u') -- CTRL + KP_LEFT
    screen:expect([[
      {1:0}123456789./*-+                                   |
      =                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data('\027[57418;2u') -- SHIFT + KP_RIGHT
    screen:expect([[
      0123456789{1:.}/*-+                                   |
      =                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data(funcs.nr2char(57426)) -- KP_DELETE
    screen:expect([[
      0123456789{1:/}*-+                                    |
      =                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data(funcs.nr2char(57423)) -- KP_HOME
    screen:expect([[
      {1:0}123456789/*-+                                    |
      =                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data(funcs.nr2char(57424)) -- KP_END
    screen:expect([[
      0123456789/*-{1:+}                                    |
      =                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    child_session:request('nvim_exec', [[
      tab split
      tabnew
      highlight Tabline ctermbg=NONE ctermfg=NONE cterm=underline
    ]], false)
    screen:expect([[
      {12: + [No Name]  + [No Name] }{3: [No Name] }{1:            }{12:X}|
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data('\027[57421;5u') -- CTRL + KP_PAGE_UP
    screen:expect([[
      {12: + [No Name] }{3: + [No Name] }{12: [No Name] }{1:            }{12:X}|
      0123456789/*-{1:+}                                    |
      =                                                 |
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data('\027[57422;5u') -- CTRL + KP_PAGE_DOWN
    screen:expect([[
      {12: + [No Name]  + [No Name] }{3: [No Name] }{1:            }{12:X}|
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('mouse events work with right-click menu', function()
    child_session:request('nvim_exec', [[
      call setline(1, 'popup menu test')
      set mouse=a mousemodel=popup

      aunmenu PopUp
      menu PopUp.foo :let g:menustr = 'foo'<CR>
      menu PopUp.bar :let g:menustr = 'bar'<CR>
      menu PopUp.baz :let g:menustr = 'baz'<CR>
      highlight Pmenu ctermbg=NONE ctermfg=NONE cterm=underline,reverse
      highlight PmenuSel ctermbg=NONE ctermfg=NONE cterm=underline,reverse,bold
    ]], false)
    meths.input_mouse('right', 'press', '', 0, 0, 4)
    screen:expect([[
      {1:p}opup menu test                                   |
      {4:~  }{13: foo }{4:                                          }|
      {4:~  }{13: bar }{4:                                          }|
      {4:~  }{13: baz }{4:                                          }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    meths.input_mouse('right', 'release', '', 0, 0, 4)
    screen:expect_unchanged()
    meths.input_mouse('move', '', '', 0, 3, 6)
    screen:expect([[
      {1:p}opup menu test                                   |
      {4:~  }{13: foo }{4:                                          }|
      {4:~  }{13: bar }{4:                                          }|
      {4:~  }{14: baz }{4:                                          }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    meths.input_mouse('left', 'press', '', 0, 2, 6)
    screen:expect([[
      {1:p}opup menu test                                   |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
      :let g:menustr = 'bar'                            |
      {3:-- TERMINAL --}                                    |
    ]])
    meths.input_mouse('left', 'release', '', 0, 2, 6)
    screen:expect_unchanged()
  end)

  it('paste: Insert mode', function()
    -- "bracketed paste"
    feed_data('i""\027i\027[200~')
    screen:expect([[
      "{1:"}                                                |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data('pasted from terminal')
    expect_child_buf_lines({'"pasted from terminal"'})
    screen:expect([[
      "pasted from terminal{1:"}                            |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data('\027[201~')  -- End paste.
    feed_data('\027[27u')   -- ESC: go to Normal mode.
    wait_for_mode('n')
    screen:expect([[
      "pasted from termina{1:l}"                            |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- Dot-repeat/redo.
    feed_data('2.')
    expect_child_buf_lines(
      {'"pasted from terminapasted from terminalpasted from terminall"'})
    screen:expect([[
      "pasted from terminapasted from terminalpasted fro|
      m termina{1:l}l"                                      |
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    -- Undo.
    feed_data('u')
    expect_child_buf_lines({'"pasted from terminal"'})
    feed_data('u')
    expect_child_buf_lines({'""'})
    feed_data('u')
    expect_child_buf_lines({''})
  end)

  it('paste: select-mode', function()
    feed_data('ithis is line 1\nthis is line 2\nline 3 is here\n\027')
    wait_for_mode('n')
    screen:expect{grid=[[
      this is line 1                                    |
      this is line 2                                    |
      line 3 is here                                    |
      {1: }                                                 |
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]]}
    -- Select-mode. Use <C-n> to move down.
    feed_data('gg04lgh\14\14')
    wait_for_mode('s')
    feed_data('\027[200~')
    feed_data('just paste it™')
    feed_data('\027[201~')
    screen:expect{grid=[[
      thisjust paste it{1:™}3 is here                       |
                                                        |
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]]}
    -- Undo.
    feed_data('u')
    expect_child_buf_lines{
      'this is line 1',
      'this is line 2',
      'line 3 is here',
      '',
      }
    -- Redo.
    feed_data('\18')  -- <C-r>
    expect_child_buf_lines{
      'thisjust paste it™3 is here',
      '',
      }
  end)

  it('paste: terminal mode', function()
    if is_ci('github') then
        pending("tty-test complains about not owning the terminal -- actions/runner#241")
    end
    child_exec_lua('vim.o.statusline="^^^^^^^"')
    child_exec_lua('vim.cmd.terminal(...)', testprg('tty-test'))
    feed_data('i')
    screen:expect{grid=[[
      tty ready                                         |
      {1: }                                                 |
                                                        |
                                                        |
      {5:^^^^^^^                                           }|
      {3:-- TERMINAL --}                                    |
      {3:-- TERMINAL --}                                    |
    ]]}
    feed_data('\027[200~')
    feed_data('hallo')
    feed_data('\027[201~')
    screen:expect{grid=[[
      tty ready                                         |
      hallo{1: }                                            |
                                                        |
                                                        |
      {5:^^^^^^^                                           }|
      {3:-- TERMINAL --}                                    |
      {3:-- TERMINAL --}                                    |
    ]]}
  end)

  it('paste: normal-mode (+CRLF #10872)', function()
    feed_data(':set ruler | echo')
    wait_for_mode('c')
    feed_data('\n')
    wait_for_mode('n')
    local expected_lf   = {'line 1', 'ESC:\027 / CR: \rx'}
    local expected_crlf = {'line 1', 'ESC:\027 / CR: ', 'x'}
    local expected_grid1 = [[
      line 1                                            |
      ESC:{11:^[} / CR:                                      |
      {1:x}                                                 |
      {4:~                                                 }|
      {5:[No Name] [+]                   3,1            All}|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]]
    local expected_attr = {
      [1] = {reverse = true},
      [3] = {bold = true},
      [4] = {foreground = tonumber('0x00000c')},
      [5] = {bold = true, reverse = true},
      [11] = {foreground = tonumber('0x000051')},
      [12] = {reverse = true, foreground = tonumber('0x000051')},
    }
    -- "bracketed paste"
    feed_data('\027[200~'..table.concat(expected_lf,'\n')..'\027[201~')
    screen:expect{grid=expected_grid1, attr_ids=expected_attr}
    -- Dot-repeat/redo.
    feed_data('.')
    screen:expect{
      grid=[[
        ESC:{11:^[} / CR:                                      |
        xline 1                                           |
        ESC:{11:^[} / CR:                                      |
        {1:x}                                                 |
        {5:[No Name] [+]                   5,1            Bot}|
                                                          |
        {3:-- TERMINAL --}                                    |
      ]],
      attr_ids=expected_attr}
    -- Undo.
    feed_data('u')
    expect_child_buf_lines(expected_crlf)
    feed_data('u')
    expect_child_buf_lines({''})
    feed_data(':echo')
    wait_for_mode('c')
    feed_data('\n')
    wait_for_mode('n')
    -- CRLF input
    feed_data('\027[200~'..table.concat(expected_lf,'\r\n')..'\027[201~')
    screen:expect{grid=expected_grid1, attr_ids=expected_attr}
    expect_child_buf_lines(expected_crlf)
  end)

  it('paste: cmdline-mode inserts 1 line', function()
    feed_data('ifoo\n')   -- Insert some text (for dot-repeat later).
    feed_data('\027:""')  -- Enter Cmdline-mode.
    feed_data('\027[D')   -- <Left> to place cursor between quotes.
    wait_for_mode('c')
    -- "bracketed paste"
    feed_data('\027[200~line 1\nline 2\n')
    wait_for_mode('c')
    feed_data('line 3\nline 4\n\027[201~')
    wait_for_mode('c')
    screen:expect{grid=[[
      foo                                               |
                                                        |
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
      :"line 1{1:"}                                         |
      {3:-- TERMINAL --}                                    |
    ]]}
    -- Dot-repeat/redo.
    feed_data('\027[27u')
    wait_for_mode('n')
    feed_data('.')
    screen:expect{grid=[[
      foo                                               |
      foo                                               |
      {1: }                                                 |
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]]}
  end)

  it('paste: cmdline-mode collects chunks of unfinished line', function()
    local function expect_cmdline(expected)
      retry(nil, nil, function()
        local _, cmdline = child_session:request(
          'nvim_call_function', 'getcmdline', {})
        eq(expected, cmdline)
      end)
    end
    feed_data('\027:""')  -- Enter Cmdline-mode.
    feed_data('\027[D')   -- <Left> to place cursor between quotes.
    wait_for_mode('c')
    feed_data('\027[200~stuff 1 ')
    expect_cmdline('"stuff 1 "')
    -- Discards everything after the first line.
    feed_data('more\nstuff 2\nstuff 3\n')
    expect_cmdline('"stuff 1 more"')
    feed_data('stuff 3')
    expect_cmdline('"stuff 1 more"')
    -- End the paste sequence.
    feed_data('\027[201~')
    feed_data(' typed')
    expect_cmdline('"stuff 1 more typed"')
  end)

  it('paste: recovers from vim.paste() failure', function()
    child_session:request('nvim_exec_lua', [[
      _G.save_paste_fn = vim.paste
      -- Stack traces for this test are non-deterministic, so disable them
      _G.debug.traceback = function(msg) return msg end
      vim.paste = function(lines, phase) error("fake fail") end
    ]], {})
    -- Prepare something for dot-repeat/redo.
    feed_data('ifoo\n\027[27u')
    wait_for_mode('n')
    screen:expect{grid=[[
      foo                                               |
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]]}
    -- Start pasting...
    feed_data('\027[200~line 1\nline 2\n')
    screen:expect{grid=[[
      foo                                               |
                                                        |
      {5:                                                  }|
      {8:paste: Error executing lua: [string "<nvim>"]:4: f}|
      {8:ake fail}                                          |
      {10:Press ENTER or type command to continue}{1: }          |
      {3:-- TERMINAL --}                                    |
    ]]}
    -- Remaining chunks are discarded after vim.paste() failure.
    feed_data('line 3\nline 4\n')
    feed_data('line 5\nline 6\n')
    feed_data('line 7\nline 8\n')
    -- Stop paste.
    feed_data('\027[201~')
    feed_data('\n')  -- <CR>
    expect_child_buf_lines({'foo',''})
    --Dot-repeat/redo is not modified by failed paste.
    feed_data('.')
    screen:expect{grid=[[
      foo                                               |
      foo                                               |
      {1: }                                                 |
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]]}
    -- Editor should still work after failed/drained paste.
    feed_data('ityped input...\027[27u')
    screen:expect{grid=[[
      foo                                               |
      foo                                               |
      typed input..{1:.}                                    |
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]]}
    -- Paste works if vim.paste() succeeds.
    child_session:request('nvim_exec_lua', [[
      vim.paste = _G.save_paste_fn
    ]], {})
    feed_data('\027[200~line A\nline B\n\027[201~')
    feed_data('\n')  -- <CR>
    screen:expect{grid=[[
      foo                                               |
      typed input...line A                              |
      line B                                            |
      {1: }                                                 |
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]]}
  end)

  it('paste: vim.paste() cancel (retval=false) #10865', function()
    -- This test only exercises the "cancel" case.  Use-case would be "dangling
    -- paste", but that is not implemented yet. #10865
    child_session:request('nvim_exec_lua', [[
      vim.paste = function(lines, phase) return false end
    ]], {})
    feed_data('\027[200~line A\nline B\n\027[201~')
    feed_data('ifoo\n\027[27u')
    expect_child_buf_lines({'foo',''})
  end)

  it("paste: 'nomodifiable' buffer", function()
    child_session:request('nvim_command', 'set nomodifiable')
    child_session:request('nvim_exec_lua', [[
      -- Truncate the error message to hide the line number
      _G.debug.traceback = function(msg) return msg:sub(-49) end
    ]], {})
    feed_data('\027[200~fail 1\nfail 2\n\027[201~')
    screen:expect{grid=[[
                                                        |
      {4:~                                                 }|
      {5:                                                  }|
      {8:paste: Error executing lua: Vim:E21: Cannot make c}|
      {8:hanges, 'modifiable' is off}                       |
      {10:Press ENTER or type command to continue}{1: }          |
      {3:-- TERMINAL --}                                    |
    ]]}
    feed_data('\n')  -- <Enter>
    child_session:request('nvim_command', 'set modifiable')
    feed_data('\027[200~success 1\nsuccess 2\n\027[201~')
    screen:expect{grid=[[
      success 1                                         |
      success 2                                         |
      {1: }                                                 |
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]]}
  end)

  it('paste: exactly 64 bytes #10311', function()
    local expected = string.rep('z', 64)
    feed_data('i')
    wait_for_mode('i')
    -- "bracketed paste"
    feed_data('\027[200~'..expected..'\027[201~')
    expect_child_buf_lines({expected})
    feed_data(' end')
    expected = expected..' end'
    screen:expect([[
      zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz|
      zzzzzzzzzzzzzz end{1: }                               |
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
    expect_child_buf_lines({expected})
  end)

  it('paste: less-than sign in cmdline  #11088', function()
    local expected = '<'
    feed_data(':')
    wait_for_mode('c')
    -- "bracketed paste"
    feed_data('\027[200~'..expected..'\027[201~')
    screen:expect{grid=[[
                                                        |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
      :<{1: }                                               |
      {3:-- TERMINAL --}                                    |
    ]]}
  end)

  it('paste: big burst of input', function()
    feed_data(':set ruler\n')
    local t = {}
    for i = 1, 3000 do
      t[i] = 'item ' .. tostring(i)
    end
    feed_data('i')
    wait_for_mode('i')
    -- "bracketed paste"
    feed_data('\027[200~'..table.concat(t, '\n')..'\027[201~')
    expect_child_buf_lines(t)
    feed_data(' end')
    screen:expect([[
      item 2997                                         |
      item 2998                                         |
      item 2999                                         |
      item 3000 end{1: }                                    |
      {5:[No Name] [+]                   3000,14        Bot}|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data('\027[27u')  -- ESC: go to Normal mode.
    wait_for_mode('n')
    -- Dot-repeat/redo.
    feed_data('.')
    screen:expect([[
      item 2997                                         |
      item 2998                                         |
      item 2999                                         |
      item 3000 en{1:d}d                                    |
      {5:[No Name] [+]                   5999,13        Bot}|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('paste: forwards spurious "start paste" code', function()
    -- If multiple "start paste" sequences are sent without a corresponding
    -- "stop paste" sequence, only the first occurrence should be consumed.

    -- Send the "start paste" sequence.
    feed_data('i\027[200~')
    feed_data('\npasted from terminal (1)\n')
    -- Send spurious "start paste" sequence.
    feed_data('\027[200~')
    feed_data('\n')
    -- Send the "stop paste" sequence.
    feed_data('\027[201~')

    screen:expect{grid=[[
                                                        |
      pasted from terminal (1)                          |
      {6:^[}[200~                                           |
      {1: }                                                 |
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]],
    attr_ids={
      [1] = {reverse = true},
      [2] = {background = tonumber('0x00000b')},
      [3] = {bold = true},
      [4] = {foreground = tonumber('0x00000c')},
      [5] = {bold = true, reverse = true},
      [6] = {foreground = tonumber('0x000051')},
    }}
  end)

  it('paste: ignores spurious "stop paste" code', function()
    -- If "stop paste" sequence is received without a preceding "start paste"
    -- sequence, it should be ignored.
    feed_data('i')
    -- Send "stop paste" sequence.
    feed_data('\027[201~')
    screen:expect([[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('paste: split "start paste" code', function()
    feed_data('i')
    screen:expect{grid=[[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]]}
    -- Send split "start paste" sequence.
    feed_data('\027[2')
    feed_data('00~pasted from terminal\027[201~')
    screen:expect([[
      pasted from terminal{1: }                             |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('paste: split "stop paste" code', function()
    feed_data('i')
    screen:expect{grid=[[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]]}
    -- Send split "stop paste" sequence.
    feed_data('\027[200~pasted from terminal\027[20')
    feed_data('1~')
    screen:expect([[
      pasted from terminal{1: }                             |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('paste: streamed paste with isolated "stop paste" code', function()
    child_session:request('nvim_exec_lua', [[
      _G.paste_phases = {}
      vim.paste = (function(overridden)
        return function(lines, phase)
          table.insert(_G.paste_phases, phase)
          overridden(lines, phase)
        end
      end)(vim.paste)
    ]], {})
    feed_data('i')
    screen:expect{grid=[[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]]}
    feed_data('\027[200~pasted')  -- phase 1
    screen:expect([[
      pasted{1: }                                           |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data(' from terminal')  -- phase 2
    screen:expect([[
      pasted from terminal{1: }                             |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
    -- Send isolated "stop paste" sequence.
    feed_data('\027[201~')  -- phase 3
    screen:expect_unchanged()
    local _, rv = child_session:request('nvim_exec_lua', [[return _G.paste_phases]], {})
    eq({1, 2, 3}, rv)
  end)

  it('allows termguicolors to be set at runtime', function()
    screen:set_option('rgb', true)
    screen:set_default_attr_ids({
      [1] = {reverse = true},
      [2] = {foreground = tonumber('0x4040ff'), fg_indexed=true},
      [3] = {bold = true, reverse = true},
      [4] = {bold = true},
      [5] = {reverse = true, foreground = tonumber('0xe0e000'), fg_indexed=true},
      [6] = {foreground = tonumber('0xe0e000'), fg_indexed=true},
      [7] = {reverse = true, foreground = Screen.colors.SeaGreen4},
      [8] = {foreground = Screen.colors.SeaGreen4},
      [9] = {bold = true, foreground = Screen.colors.Blue1},
      [10] = {foreground = Screen.colors.Blue},
    })

    feed_data(':hi SpecialKey ctermfg=3 guifg=SeaGreen\n')
    feed_data('i')
    feed_data('\022\007') -- ctrl+g
    feed_data('\028\014') -- crtl+\ ctrl+N
    feed_data(':set termguicolors?\n')
    screen:expect([[
      {5:^}{6:G}                                                |
      {2:~                                                 }|
      {2:~                                                 }|
      {2:~                                                 }|
      {3:[No Name] [+]                                     }|
      notermguicolors                                   |
      {4:-- TERMINAL --}                                    |
    ]])

    feed_data(':set termguicolors\n')
    screen:expect([[
      {7:^}{8:G}                                                |
      {9:~}{10:                                                 }|
      {9:~}{10:                                                 }|
      {9:~}{10:                                                 }|
      {3:[No Name] [+]                                     }|
      :set termguicolors                                |
      {4:-- TERMINAL --}                                    |
    ]])

    feed_data(':set notermguicolors\n')
    screen:expect([[
      {5:^}{6:G}                                                |
      {2:~                                                 }|
      {2:~                                                 }|
      {2:~                                                 }|
      {3:[No Name] [+]                                     }|
      :set notermguicolors                              |
      {4:-- TERMINAL --}                                    |
    ]])
  end)

  it('forwards :term palette colors with termguicolors', function()
    if is_ci('github') then
        pending("tty-test complains about not owning the terminal -- actions/runner#241")
    end
    screen:set_rgb_cterm(true)
    screen:set_default_attr_ids({
      [1] = {{reverse = true}, {reverse = true}},
      [2] = {{bold = true, reverse = true}, {bold = true, reverse = true}},
      [3] = {{bold = true}, {bold = true}},
      [4] = {{fg_indexed = true, foreground = tonumber('0xe0e000')}, {foreground = 3}},
      [5] = {{foreground = tonumber('0xff8000')}, {}},
    })

    child_exec_lua('vim.o.statusline="^^^^^^^"')
    child_exec_lua('vim.o.termguicolors=true')
    child_exec_lua('vim.cmd.terminal(...)', testprg('tty-test'))
    screen:expect{grid=[[
      {1:t}ty ready                                         |
                                                        |
                                                        |
                                                        |
      {2:^^^^^^^                                           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]]}
    feed_data(':call chansend(&channel, "\\033[38;5;3mtext\\033[38:2:255:128:0mcolor\\033[0;10mtext")\n')
    screen:expect{grid=[[
      {1:t}ty ready                                         |
      {4:text}{5:color}text                                     |
                                                        |
                                                        |
      {2:^^^^^^^                                           }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]]}

    feed_data(':set notermguicolors\n')
    screen:expect{grid=[[
      {1:t}ty ready                                         |
      {4:text}colortext                                     |
                                                        |
                                                        |
      {2:^^^^^^^                                           }|
      :set notermguicolors                              |
      {3:-- TERMINAL --}                                    |
    ]]}
  end)

  it('is included in nvim_list_uis()', function()
    feed_data(':echo map(nvim_list_uis(), {k,v -> sort(items(filter(v, {k,v -> k[:3] !=# "ext_" })))})\r')
    screen:expect([=[
                                                        |
      {4:~                                                 }|
      {5:                                                  }|
      [[['chan', 1], ['height', 6], ['override', v:false|
      ], ['rgb', v:false], ['width', 50]]]              |
      {10:Press ENTER or type command to continue}{1: }          |
      {3:-- TERMINAL --}                                    |
    ]=])
  end)

  it('allows grid to assume wider ambiguous-width characters than host terminal #19686', function()
    child_session:request('nvim_buf_set_lines', 0, 0, -1, true, { ('℃'):rep(60), ('℃'):rep(60) })
    child_session:request('nvim_win_set_option', 0, 'cursorline', true)
    child_session:request('nvim_win_set_option', 0, 'list', true)
    child_session:request('nvim_win_set_option', 0, 'listchars', 'eol:$')
    feed_data('gg')
    local singlewidth_screen = [[
      {13:℃}{12:℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃}|
      {12:℃℃℃℃℃℃℃℃℃℃}{15:$}{12:                                       }|
      ℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃℃|
      ℃℃℃℃℃℃℃℃℃℃{4:$}                                       |
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]]
    -- When grid assumes "℃" to be double-width but host terminal assumes it to be single-width, the
    -- second cell of "℃" is a space and the attributes of the "℃" are applied to it.
    local doublewidth_screen = [[
      {13:℃}{12: ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ }|
      {12:℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ }|
      {12:℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ }{15:$}{12:                             }|
      ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ ℃ >{4:@@@}|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]]
    screen:expect(singlewidth_screen)
    child_session:request('nvim_set_option', 'ambiwidth', 'double')
    screen:expect(doublewidth_screen)
    child_session:request('nvim_set_option', 'ambiwidth', 'single')
    screen:expect(singlewidth_screen)
    child_session:request('nvim_call_function', 'setcellwidths', {{{0x2103, 0x2103, 2}}})
    screen:expect(doublewidth_screen)
    child_session:request('nvim_call_function', 'setcellwidths', {{{0x2103, 0x2103, 1}}})
    screen:expect(singlewidth_screen)
  end)

  it('draws correctly when cursor_address overflows #21643', function()
    helpers.skip(helpers.is_os('mac'), 'FIXME: crashes/errors on macOS')
    screen:try_resize(77, 834)
    retry(nil, nil, function()
      eq({true, 831}, {child_session:request('nvim_win_get_height', 0)})
    end)
    -- Use full screen message so that redrawing afterwards is more deterministic.
    child_session:notify('nvim_command', 'intro')
    screen:expect({any = 'Nvim'})
    -- Going to top-left corner needs 3 bytes.
    -- Setting underline attribute needs 9 bytes.
    -- With screen width 77, 63857 characters need 829 full screen lines.
    -- Drawing each full screen line needs 77 + 2 = 79 bytes (2 bytes for CR LF).
    -- The incomplete screen line needs 24 + 3 = 27 bytes.
    -- The whole line needs 3 + 9 + 79 * 829 + 27 = 65530 bytes.
    -- The cursor_address that comes after will overflow the 65535-byte buffer.
    local line = ('a'):rep(63857) .. '℃'
    child_session:notify('nvim_exec_lua', [[
      vim.api.nvim_buf_set_lines(0, 0, -1, true, {...})
      vim.o.cursorline = true
    ]], {line, 'b'})
    -- Close the :intro message and redraw the lines.
    feed_data('\n')
    screen:expect(
      '{13:a}{12:' .. ('a'):rep(76) .. '}|\n'
      .. ('{12:' .. ('a'):rep(77) .. '}|\n'):rep(828)
      .. '{12:' .. ('a'):rep(24) .. '℃' .. (' '):rep(52) .. '}|\n' .. dedent([[
      b                                                                            |
      {5:[No Name] [+]                                                                }|
                                                                                   |
      {3:-- TERMINAL --}                                                               |]]))
  end)

  it('visual bell (padding) does not crash #21610', function()
    feed_data ':set visualbell\n'
    screen:expect{grid=[[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
      :set visualbell                                   |
      {3:-- TERMINAL --}                                    |
    ]]}

    -- move left is enough to invoke the bell
    feed_data 'h'
    -- visual change to show we process events after this
    feed_data 'i'
    screen:expect{grid=[[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]]}
  end)

  it('no assert failure on deadly signal #21896', function()
    exec_lua([[vim.loop.kill(vim.fn.jobpid(vim.bo.channel), 'sigterm')]])
    screen:expect({any = '%[Process exited 1%]'})
  end)
end)

describe('TUI', function()
  before_each(clear)
  after_each(function()
    os.remove('testF')
  end)

  it('resize at startup #17285 #15044 #11330', function()
    local screen = Screen.new(50, 10)
    screen:set_default_attr_ids({
      [1] = {reverse = true},
      [2] = {bold = true, foreground = Screen.colors.Blue},
      [3] = {bold = true},
      [4] = {foreground = tonumber('0x4040ff'), fg_indexed = true},
      [5] = {bold = true, reverse = true},
    })
    screen:attach()
    exec([[
      call termopen([v:progpath, '--clean', '--cmd', 'let start = reltime() | while v:true | if reltimefloat(reltime(start)) > 2 | break | endif | endwhile'])
      sleep 500m
      vs new
    ]])
    screen:expect([[
      ^                         │                        |
      {2:~                        }│{4:~                       }|
      {2:~                        }│{4:~                       }|
      {2:~                        }│{4:~                       }|
      {2:~                        }│{4:~                       }|
      {2:~                        }│{4:~                       }|
      {2:~                        }│{5:[No Name]   0,0-1    All}|
      {2:~                        }│                        |
      {5:new                       }{1:{MATCH:<.*[/\]nvim }}|
                                                        |
    ]])
  end)

  it('with non-tty (pipe) stdout/stderr', function()
    local screen = thelpers.screen_setup(0, '"'..nvim_prog
      ..' -u NONE -i NONE --cmd \'set noswapfile noshowcmd noruler\' --cmd \'normal iabc\' > /dev/null 2>&1 && cat testF && rm testF"')
    feed_data(':w testF\n:q\n')
    screen:expect([[
      :w testF                                          |
      :q                                                |
      abc                                               |
                                                        |
      [Process exited 0]{1: }                               |
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('<C-h> #10134', function()
    local screen = thelpers.screen_setup(0, '["'..nvim_prog
      ..[[", "-u", "NONE", "-i", "NONE", "--cmd", "set noruler", "--cmd", ':nnoremap <C-h> :echomsg "\<C-h\>"<CR>']]..']')
    screen:expect{grid=[[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]]}

    command([[call chansend(b:terminal_job_id, "\<C-h>")]])
    screen:expect([[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
      <C-h>                                             |
      {3:-- TERMINAL --}                                    |
    ]])
  end)
end)

describe('TUI UIEnter/UILeave', function()
  it('fires exactly once, after VimEnter', function()
    clear()
    local screen = thelpers.screen_setup(0,
      '["'..nvim_prog..'", "-u", "NONE", "-i", "NONE"'
      ..[[, "--cmd", "set noswapfile noshowcmd noruler"]]
      ..[[, "--cmd", "let g:evs = []"]]
      ..[[, "--cmd", "autocmd UIEnter  * :call add(g:evs, 'UIEnter')"]]
      ..[[, "--cmd", "autocmd UILeave  * :call add(g:evs, 'UILeave')"]]
      ..[[, "--cmd", "autocmd VimEnter * :call add(g:evs, 'VimEnter')"]]
      ..']'
    )
    screen:expect{grid=[[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]]}
    feed_data(":echo g:evs\n")
    screen:expect{grid=[[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
      ['VimEnter', 'UIEnter']                           |
      {3:-- TERMINAL --}                                    |
    ]]}
  end)
end)

describe('TUI FocusGained/FocusLost', function()
  local screen
  local child_session

  before_each(function()
    clear()
    local child_server = new_pipename()
    screen = thelpers.screen_setup(0,
      string.format(
        [=[["%s", "--listen", "%s", "-u", "NONE", "-i", "NONE", "--cmd", "set noswapfile noshowcmd noruler"]]=],
        nvim_prog, child_server))
    screen:expect([[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]])
    child_session = helpers.connect(child_server)
    child_session:request('nvim_exec', [[
      autocmd FocusGained * echo 'gained'
      autocmd FocusLost * echo 'lost'
    ]], false)
    feed_data("\034\016")  -- CTRL-\ CTRL-N
  end)

  it('in normal-mode', function()
    retry(2, 3 * screen.timeout, function()
      feed_data('\027[I')
      screen:expect([[
        {1: }                                                 |
        {4:~                                                 }|
        {4:~                                                 }|
        {4:~                                                 }|
        {5:[No Name]                                         }|
        gained                                            |
        {3:-- TERMINAL --}                                    |
      ]])

      feed_data('\027[O')
      screen:expect([[
        {1: }                                                 |
        {4:~                                                 }|
        {4:~                                                 }|
        {4:~                                                 }|
        {5:[No Name]                                         }|
        lost                                              |
        {3:-- TERMINAL --}                                    |
      ]])
    end)
  end)

  it('in insert-mode', function()
    feed_command('set noshowmode')
    feed_data('i')
    screen:expect{grid=[[
      {1: }                                                 |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
      :set noshowmode                                   |
      {3:-- TERMINAL --}                                    |
    ]]}
    retry(2, 3 * screen.timeout, function()
      feed_data('\027[I')
      screen:expect([[
        {1: }                                                 |
        {4:~                                                 }|
        {4:~                                                 }|
        {4:~                                                 }|
        {5:[No Name]                                         }|
        gained                                            |
        {3:-- TERMINAL --}                                    |
      ]])
      feed_data('\027[O')
      screen:expect([[
        {1: }                                                 |
        {4:~                                                 }|
        {4:~                                                 }|
        {4:~                                                 }|
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
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
      :{1: }                                                |
      {3:-- TERMINAL --}                                    |
    ]])
    feed_data('\027[O')
    screen:expect{grid=[[
                                                        |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name]                                         }|
      :{1: }                                                |
      {3:-- TERMINAL --}                                    |
    ]], unchanged=true}
  end)

  it('in cmdline-mode', function()
    -- Set up autocmds that modify the buffer, instead of just calling :echo.
    -- This is how we can test handling of focus gained/lost during cmdline-mode.
    -- See commit: 5cc87d4dabd02167117be7a978b5c8faaa975419.
    child_session:request('nvim_exec', [[
      autocmd!
      autocmd FocusLost * call append(line('$'), 'lost')
      autocmd FocusGained * call append(line('$'), 'gained')
    ]], false)
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
      screen:expect{any='lost'..(' '):rep(46)..'|\ngained'}
    end)
  end)

  it('in terminal-mode', function()
    feed_data(':set shell='..testprg('shell-test')..'\n')
    feed_data(':set noshowmode laststatus=0\n')

    feed_data(':terminal\n')
    -- Wait for terminal to be ready.
    screen:expect{grid=[[
      {1:r}eady $                                           |
      [Process exited 0]                                |
                                                        |
                                                        |
                                                        |
      :terminal                                         |
      {3:-- TERMINAL --}                                    |
    ]]}

    feed_data('\027[I')
    screen:expect{grid=[[
      {1:r}eady $                                           |
      [Process exited 0]                                |
                                                        |
                                                        |
                                                        |
      gained                                            |
      {3:-- TERMINAL --}                                    |
    ]], timeout=(4 * screen.timeout)}

    feed_data('\027[O')
    screen:expect([[
      {1:r}eady $                                           |
      [Process exited 0]                                |
                                                        |
                                                        |
                                                        |
      lost                                              |
      {3:-- TERMINAL --}                                    |
    ]])
  end)

  it('in press-enter prompt', function()
    feed_data(":echom 'msg1'|echom 'msg2'|echom 'msg3'|echom 'msg4'|echom 'msg5'\n")
    -- Execute :messages to provoke the press-enter prompt.
    feed_data(":messages\n")
    screen:expect{grid=[[
      msg1                                              |
      msg2                                              |
      msg3                                              |
      msg4                                              |
      msg5                                              |
      {10:Press ENTER or type command to continue}{1: }          |
      {3:-- TERMINAL --}                                    |
    ]]}
    feed_data('\027[I')
    feed_data('\027[I')
    screen:expect{grid=[[
      msg1                                              |
      msg2                                              |
      msg3                                              |
      msg4                                              |
      msg5                                              |
      {10:Press ENTER or type command to continue}{1: }          |
      {3:-- TERMINAL --}                                    |
    ]], unchanged=true}
  end)
end)

-- These tests require `thelpers` because --headless/--embed
-- does not initialize the TUI.
describe("TUI 't_Co' (terminal colors)", function()
  local screen

  local function assert_term_colors(term, colorterm, maxcolors)
    helpers.clear({env={TERM=term}, args={}})
    -- This is ugly because :term/termopen() forces TERM=xterm-256color.
    -- TODO: Revisit this after jobstart/termopen accept `env` dict.
    screen = thelpers.screen_setup(0, string.format(
      [=[['sh', '-c', 'LANG=C TERM=%s %s %s -u NONE -i NONE --cmd "%s"']]=],
      term or "",
      (colorterm ~= nil and "COLORTERM="..colorterm or ""),
      nvim_prog,
      nvim_set))

    local tline
    if maxcolors == 8 or maxcolors == 16 then
      tline = "~                                                 "
    else
      tline = "{4:~                                                 }"
    end

    screen:expect(string.format([[
      {1: }                                                 |
      %s|
      %s|
      %s|
      %s|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]], tline, tline, tline, tline))

    feed_data(":echo &t_Co\n")
    screen:expect(string.format([[
      {1: }                                                 |
      %s|
      %s|
      %s|
      %s|
      %-3s                                               |
      {3:-- TERMINAL --}                                    |
    ]], tline, tline, tline, tline, tostring(maxcolors and maxcolors or "")))
  end

  -- ansi and no terminal type at all:

  it("no TERM uses 8 colors", function()
    assert_term_colors(nil, nil, 8)
  end)

  it("TERM=ansi no COLORTERM uses 8 colors", function()
    assert_term_colors("ansi", nil, 8)
  end)

  it("TERM=ansi with COLORTERM=anything-no-number uses 16 colors", function()
    assert_term_colors("ansi", "yet-another-term", 16)
  end)

  it("unknown TERM COLORTERM with 256 in name uses 256 colors", function()
    assert_term_colors("ansi", "yet-another-term-256color", 256)
  end)

  it("TERM=ansi-256color sets 256 colours", function()
    assert_term_colors("ansi-256color", nil, 256)
  end)

  -- Unknown terminal types:

  it("unknown TERM no COLORTERM sets 8 colours", function()
    assert_term_colors("yet-another-term", nil, 8)
  end)

  it("unknown TERM with COLORTERM=anything-no-number uses 16 colors", function()
    assert_term_colors("yet-another-term", "yet-another-term", 16)
  end)

  it("unknown TERM with 256 in name sets 256 colours", function()
    assert_term_colors("yet-another-term-256color", nil, 256)
  end)

  it("unknown TERM COLORTERM with 256 in name uses 256 colors", function()
    assert_term_colors("yet-another-term", "yet-another-term-256color", 256)
  end)

  -- Linux kernel terminal emulator:

  it("TERM=linux uses 256 colors", function()
    assert_term_colors("linux", nil, 256)
  end)

  it("TERM=linux-16color uses 256 colors", function()
    assert_term_colors("linux-16color", nil, 256)
  end)

  it("TERM=linux-256color uses 256 colors", function()
    assert_term_colors("linux-256color", nil, 256)
  end)

  -- screen:
  --
  -- FreeBSD falls back to the built-in screen-256colour entry.
  -- Linux and MacOS have a screen entry in external terminfo with 8 colours,
  -- which is raised to 16 by COLORTERM.

  it("TERM=screen no COLORTERM uses 8/256 colors", function()
    if is_os('freebsd') then
      assert_term_colors("screen", nil, 256)
    else
      assert_term_colors("screen", nil, 8)
    end
  end)

  it("TERM=screen COLORTERM=screen uses 16/256 colors", function()
    if is_os('freebsd') then
      assert_term_colors("screen", "screen", 256)
    else
      assert_term_colors("screen", "screen", 16)
    end
  end)

  it("TERM=screen COLORTERM=screen-256color uses 256 colors", function()
    assert_term_colors("screen", "screen-256color", 256)
  end)

  it("TERM=screen-256color no COLORTERM uses 256 colors", function()
    assert_term_colors("screen-256color", nil, 256)
  end)

  -- tmux:
  --
  -- FreeBSD and MacOS fall back to the built-in tmux-256colour entry.
  -- Linux has a tmux entry in external terminfo with 8 colours,
  -- which is raised to 256.

  it("TERM=tmux no COLORTERM uses 256 colors", function()
    assert_term_colors("tmux", nil, 256)
  end)

  it("TERM=tmux COLORTERM=tmux uses 256 colors", function()
    assert_term_colors("tmux", "tmux", 256)
  end)

  it("TERM=tmux COLORTERM=tmux-256color uses 256 colors", function()
    assert_term_colors("tmux", "tmux-256color", 256)
  end)

  it("TERM=tmux-256color no COLORTERM uses 256 colors", function()
    assert_term_colors("tmux-256color", nil, 256)
  end)

  -- xterm and imitators:

  it("TERM=xterm uses 256 colors", function()
    assert_term_colors("xterm", nil, 256)
  end)

  it("TERM=xterm COLORTERM=gnome-terminal uses 256 colors", function()
    assert_term_colors("xterm", "gnome-terminal", 256)
  end)

  it("TERM=xterm COLORTERM=mate-terminal uses 256 colors", function()
    assert_term_colors("xterm", "mate-terminal", 256)
  end)

  it("TERM=xterm-256color uses 256 colors", function()
    assert_term_colors("xterm-256color", nil, 256)
  end)

  -- rxvt and stterm:
  --
  -- FreeBSD and MacOS fall back to the built-in rxvt-256color and
  -- st-256colour entries.
  -- Linux has an rxvt, an st, and an st-16color entry in external terminfo
  -- with 8, 8, and 16 colours respectively, which are raised to 256.

  it("TERM=rxvt no COLORTERM uses 256 colors", function()
    assert_term_colors("rxvt", nil, 256)
  end)

  it("TERM=rxvt COLORTERM=rxvt uses 256 colors", function()
    assert_term_colors("rxvt", "rxvt", 256)
  end)

  it("TERM=rxvt-256color uses 256 colors", function()
    assert_term_colors("rxvt-256color", nil, 256)
  end)

  it("TERM=st no COLORTERM uses 256 colors", function()
    assert_term_colors("st", nil, 256)
  end)

  it("TERM=st COLORTERM=st uses 256 colors", function()
    assert_term_colors("st", "st", 256)
  end)

  it("TERM=st COLORTERM=st-256color uses 256 colors", function()
    assert_term_colors("st", "st-256color", 256)
  end)

  it("TERM=st-16color no COLORTERM uses 8/256 colors", function()
    assert_term_colors("st", nil, 256)
  end)

  it("TERM=st-16color COLORTERM=st uses 16/256 colors", function()
    assert_term_colors("st", "st", 256)
  end)

  it("TERM=st-16color COLORTERM=st-256color uses 256 colors", function()
    assert_term_colors("st", "st-256color", 256)
  end)

  it("TERM=st-256color uses 256 colors", function()
    assert_term_colors("st-256color", nil, 256)
  end)

  -- gnome and vte:
  --
  -- FreeBSD and MacOS fall back to the built-in vte-256color entry.
  -- Linux has a gnome, a vte, a gnome-256color, and a vte-256color entry in
  -- external terminfo with 8, 8, 256, and 256 colours respectively, which are
  -- raised to 256.

  it("TERM=gnome no COLORTERM uses 256 colors", function()
    assert_term_colors("gnome", nil, 256)
  end)

  it("TERM=gnome COLORTERM=gnome uses 256 colors", function()
    assert_term_colors("gnome", "gnome", 256)
  end)

  it("TERM=gnome COLORTERM=gnome-256color uses 256 colors", function()
    assert_term_colors("gnome", "gnome-256color", 256)
  end)

  it("TERM=gnome-256color uses 256 colors", function()
    assert_term_colors("gnome-256color", nil, 256)
  end)

  it("TERM=vte no COLORTERM uses 256 colors", function()
    assert_term_colors("vte", nil, 256)
  end)

  it("TERM=vte COLORTERM=vte uses 256 colors", function()
    assert_term_colors("vte", "vte", 256)
  end)

  it("TERM=vte COLORTERM=vte-256color uses 256 colors", function()
    assert_term_colors("vte", "vte-256color", 256)
  end)

  it("TERM=vte-256color uses 256 colors", function()
    assert_term_colors("vte-256color", nil, 256)
  end)

  -- others:

  -- TODO(blueyed): this is made pending, since it causes failure + later hang
  --                when using non-compatible libvterm (#9494/#10179).
  pending("TERM=interix uses 8 colors", function()
    assert_term_colors("interix", nil, 8)
  end)

  it("TERM=iTerm.app uses 256 colors", function()
    assert_term_colors("iTerm.app", nil, 256)
  end)

  it("TERM=iterm uses 256 colors", function()
    assert_term_colors("iterm", nil, 256)
  end)

end)

-- These tests require `thelpers` because --headless/--embed
-- does not initialize the TUI.
describe("TUI 'term' option", function()
  local screen

  local function assert_term(term_envvar, term_expected)
    clear()
    -- This is ugly because :term/termopen() forces TERM=xterm-256color.
    -- TODO: Revisit this after jobstart/termopen accept `env` dict.
    local cmd = string.format(
      [=[['sh', '-c', 'LANG=C TERM=%s %s -u NONE -i NONE --cmd "%s"']]=],
      term_envvar or "",
      nvim_prog,
      nvim_set)
    screen = thelpers.screen_setup(0, cmd)

    local full_timeout = screen.timeout
    screen.timeout = 250  -- We want screen:expect() to fail quickly.
    retry(nil, 2 * full_timeout, function()  -- Wait for TUI thread to set 'term'.
      feed_data(":echo 'term='.(&term)\n")
      screen:expect{any='term='..term_expected}
    end)
  end

  it('gets builtin term if $TERM is invalid', function()
    assert_term("foo", "builtin_ansi")
  end)

  it('gets system-provided term if $TERM is valid', function()
    if is_os('openbsd') then
      assert_term("xterm", "xterm")
    elseif is_os('bsd') then  -- BSD lacks terminfo, builtin is always used.
      assert_term("xterm", "builtin_xterm")
    elseif is_os('mac') then
      local status, _ = pcall(assert_term, "xterm", "xterm")
      if not status then
        pending("macOS: unibilium could not find terminfo")
      end
    else
      assert_term("xterm", "xterm")
    end
  end)

  it('builtin terms', function()
    -- These non-standard terminfos are always builtin.
    assert_term('win32con', 'builtin_win32con')
    assert_term('conemu', 'builtin_conemu')
    assert_term('vtpcon', 'builtin_vtpcon')
  end)

end)

-- These tests require `thelpers` because --headless/--embed
-- does not initialize the TUI.
describe("TUI", function()
  local screen
  local logfile = 'Xtest_tui_verbose_log'
  after_each(function()
    os.remove(logfile)
  end)

  -- Runs (child) `nvim` in a TTY (:terminal), to start the builtin TUI.
  local function nvim_tui(extra_args)
    clear()
    -- This is ugly because :term/termopen() forces TERM=xterm-256color.
    -- TODO: Revisit this after jobstart/termopen accept `env` dict.
    local cmd = string.format(
      [=[['sh', '-c', 'LANG=C %s -u NONE -i NONE %s --cmd "%s"']]=],
      nvim_prog,
      extra_args or "",
      nvim_set)
    screen = thelpers.screen_setup(0, cmd)
  end

  it('-V3log logs terminfo values', function()
    nvim_tui('-V3'..logfile)

    -- Wait for TUI to start.
    feed_data('Gitext')
    screen:expect([[
      text{1: }                                             |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])

    retry(nil, 3000, function()  -- Wait for log file to be flushed.
      local log = read_file('Xtest_tui_verbose_log') or ''
      eq('--- Terminal info --- {{{\n', string.match(log, '%-%-%- Terminal.-\n')) -- }}}
      ok(#log > 50)
    end)
  end)

end)

describe('TUI bg color', function()
  local screen

  local function setup()
    -- Only single integration test.
    -- See test/unit/tui_spec.lua for unit tests.
    clear()
    screen = thelpers.screen_setup(0, '["'..nvim_prog
      ..'", "-u", "NONE", "-i", "NONE", "--cmd", "set noswapfile", '
      ..'"-c", "autocmd OptionSet background echo \\"did OptionSet, yay!\\""]')
  end

  before_each(setup)

  it('triggers OptionSet event on unsplit terminal-response', function()
    screen:expect([[
    {1: }                                                 |
    {4:~                                                 }|
    {4:~                                                 }|
    {4:~                                                 }|
    {5:[No Name]                       0,0-1          All}|
                                                      |
    {3:-- TERMINAL --}                                    |
    ]])
    feed_data('\027]11;rgb:ffff/ffff/ffff\007')
    screen:expect{any='did OptionSet, yay!'}

    feed_data(':echo "new_bg=".&background\n')
    screen:expect{any='new_bg=light'}

    setup()
    screen:expect([[
    {1: }                                                 |
    {4:~                                                 }|
    {4:~                                                 }|
    {4:~                                                 }|
    {5:[No Name]                       0,0-1          All}|
                                                      |
    {3:-- TERMINAL --}                                    |
    ]])
    feed_data('\027]11;rgba:ffff/ffff/ffff/8000\027\\')
    screen:expect{any='did OptionSet, yay!'}

    feed_data(':echo "new_bg=".&background\n')
    screen:expect{any='new_bg=light'}
  end)

  it('triggers OptionSet event with split terminal-response', function()
    screen:expect([[
    {1: }                                                 |
    {4:~                                                 }|
    {4:~                                                 }|
    {4:~                                                 }|
    {5:[No Name]                       0,0-1          All}|
                                                      |
    {3:-- TERMINAL --}                                    |
    ]])
    -- Send a background response with the OSC command part split.
    feed_data('\027]11;rgb')
    feed_data(':ffff/ffff/ffff\027\\')
    screen:expect{any='did OptionSet, yay!'}

    feed_data(':echo "new_bg=".&background\n')
    screen:expect{any='new_bg=light'}

    setup()
    screen:expect([[
    {1: }                                                 |
    {4:~                                                 }|
    {4:~                                                 }|
    {4:~                                                 }|
    {5:[No Name]                       0,0-1          All}|
                                                      |
    {3:-- TERMINAL --}                                    |
    ]])
    -- Send a background response with the Pt portion split.
    feed_data('\027]11;rgba:ffff/fff')
    feed_data('f/ffff/8000\007')
    screen:expect{any='did OptionSet, yay!'}

    feed_data(':echo "new_bg=".&background\n')
    screen:expect{any='new_bg=light'}
  end)

  it('not triggers OptionSet event with invalid terminal-response', function()
    screen:expect([[
    {1: }                                                 |
    {4:~                                                 }|
    {4:~                                                 }|
    {4:~                                                 }|
    {5:[No Name]                       0,0-1          All}|
                                                      |
    {3:-- TERMINAL --}                                    |
    ]])
    feed_data('\027]11;rgb:ffff/ffff/ffff/8000\027\\')
    screen:expect_unchanged()

    feed_data(':echo "new_bg=".&background\n')
    screen:expect{any='new_bg=dark'}

    setup()
    screen:expect([[
    {1: }                                                 |
    {4:~                                                 }|
    {4:~                                                 }|
    {4:~                                                 }|
    {5:[No Name]                       0,0-1          All}|
                                                      |
    {3:-- TERMINAL --}                                    |
    ]])
    feed_data('\027]11;rgba:ffff/foo/ffff/8000\007')
    screen:expect_unchanged()

    feed_data(':echo "new_bg=".&background\n')
    screen:expect{any='new_bg=dark'}
  end)
end)

-- These tests require `thelpers` because --headless/--embed
-- does not initialize the TUI.
describe("TUI as a client", function()

  it("connects to remote instance (with its own TUI)", function()
    local server_super = spawn_argv(false) -- equivalent to clear()
    local client_super = spawn_argv(true)

    set_session(server_super)
    local server_pipe = new_pipename()
    local screen_server = thelpers.screen_setup(0,
      string.format([=[["%s", "--listen", "%s", "-u", "NONE", "-i", "NONE", "--cmd", "%s laststatus=2 background=dark"]]=],
        nvim_prog, server_pipe, nvim_set))

    feed_data("iHello, World")
    screen_server:expect{grid=[[
      Hello, World{1: }                                     |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]]}
    feed_data("\027")
    screen_server:expect{grid=[[
      Hello, Worl{1:d}                                      |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]]}

    set_session(client_super)
    local screen_client = thelpers.screen_setup(0,
      string.format([=[["%s", "--server", "%s", "--remote-ui"]]=],
                    nvim_prog, server_pipe))

    screen_client:expect{grid=[[
      Hello, Worl{1:d}                                      |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]]}

    feed_data(":q!\n")

    server_super:close()
    client_super:close()
  end)

  it("connects to remote instance (--headless)", function()
    local server = helpers.spawn_argv(false) -- equivalent to clear()
    local client_super = spawn_argv(true)

    set_session(server)
    local server_pipe = eval'v:servername'
    feed'iHalloj!<esc>'

    set_session(client_super)
    local screen = thelpers.screen_setup(0,
      string.format([=[["%s", "--server", "%s", "--remote-ui"]]=],
                    nvim_prog, server_pipe))

    screen:expect{grid=[[
      Halloj{1:!}                                           |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]]}

    -- No heap-use-after-free when receiving UI events after deadly signal #22184
    server:request('nvim_input', ('a'):rep(1000))
    exec_lua([[vim.loop.kill(vim.fn.jobpid(vim.bo.channel), 'sigterm')]])
    screen:expect({any = '%[Process exited 1%]'})

    eq(0, meths.get_vvar('shell_error'))
    -- exits on input eof #22244
    funcs.system({nvim_prog, '--server', server_pipe, '--remote-ui'})
    eq(1, meths.get_vvar('shell_error'))

    client_super:close()
    server:close()
  end)

  it("throws error when no server exists", function()
    clear()
    local screen = thelpers.screen_setup(0,
      string.format([=[["%s", "--server", "127.0.0.1:2436546", "--remote-ui"]]=],
                    nvim_prog), 60)

    screen:expect([[
      Remote ui failed to start: {MATCH:.*}|
                                                                  |
      [Process exited 1]{1: }                                         |
                                                                  |
                                                                  |
                                                                  |
      {3:-- TERMINAL --}                                              |
    ]])
  end)

  it("exits when server quits", function()
    local server_super = spawn_argv(false) -- equivalent to clear()
    local client_super = spawn_argv(true)

    set_session(server_super)
    local server_pipe = new_pipename()
    local screen_server = thelpers.screen_setup(0,
      string.format([=[["%s", "--listen", "%s", "-u", "NONE", "-i", "NONE", "--cmd", "%s laststatus=2 background=dark"]]=],
        nvim_prog, server_pipe, nvim_set))

    feed_data("iHello, World")
    screen_server:expect{grid=[[
      Hello, World{1: }                                     |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]]}
    feed_data("\027")
    screen_server:expect{grid=[[
      Hello, Worl{1:d}                                      |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]]}

    set_session(client_super)
    local screen_client = thelpers.screen_setup(0,
      string.format([=[["%s", "--server", "%s", "--remote-ui"]]=],
                    nvim_prog, server_pipe))

    screen_client:expect{grid=[[
      Hello, Worl{1:d}                                      |
      {4:~                                                 }|
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
                                                        |
      {3:-- TERMINAL --}                                    |
    ]]}

    -- quitting the server
    set_session(server_super)
    feed_data(":q!\n")
    screen_server:expect({any="Process exited 0"})

    -- assert that client has exited
    screen_client:expect({any="Process exited 0"})

    server_super:close()
    client_super:close()
  end)
end)
