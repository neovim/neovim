-- TUI acceptance tests.
-- Uses :terminal as a way to send keys and assert screen state.
--
-- "bracketed paste" terminal feature:
-- http://invisible-island.net/xterm/ctlseqs/ctlseqs.html#h2-Bracketed-Paste-Mode

local helpers = require('test.functional.helpers')(after_each)
local uname = helpers.uname
local thelpers = require('test.functional.terminal.helpers')
local Screen = require('test.functional.ui.screen')
local eq = helpers.eq
local feed_command = helpers.feed_command
local feed_data = thelpers.feed_data
local clear = helpers.clear
local command = helpers.command
local eval = helpers.eval
local nvim_dir = helpers.nvim_dir
local retry = helpers.retry
local nvim_prog = helpers.nvim_prog
local nvim_set = helpers.nvim_set
local ok = helpers.ok
local read_file = helpers.read_file

if helpers.pending_win32(pending) then return end

describe('TUI', function()
  local screen
  local child_session

  before_each(function()
    clear()
    local child_server = helpers.new_pipename()
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
  end)

  after_each(function()
    screen:detach()
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
    feed_data(":edit test/functional/fixtures/bigfile.txt:")
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
    eq(2, eval("1+1"))  -- Still alive?
  end)

  it('accepts resize while pager is active', function()
    child_session:request("nvim_command", [[
    set more
    func! ManyErr()
      for i in range(10)
        echoerr "FAIL ".i
      endfor
    endfunc
    ]])
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
      {8:FAIL 1}                                            |
      {8:FAIL 2}                                            |
      {8:FAIL 3}                                            |
      {10:-- More -- SPACE/d/j: screen/page/line down, b/u/}{12:k}|
      {3:-- TERMINAL --}                                    |
    ]]}

    -- TODO(bfredl): messes up the output (just like vim does).
    feed_data('g')
    screen:expect{grid=[[
      {8:FAIL 1}        )                                   |
      {8:Error detected while processing function ManyErr:} |
      {11:line    2:}                                        |
      {10:-- More --}{1: }                                       |
      {3:-- TERMINAL --}                                    |
    ]]}

    screen:try_resize(50,10)
    screen:expect{grid=[[
      {8:FAIL 1}        )                                   |
      {8:Error detected while processing function ManyErr:} |
      {11:line    2:}                                        |
      {10:-- More --}                                        |
      {10:                                                  }|
      {10:                                                  }|
      {10:                                                  }|
      {10:                                                  }|
      {10:-- More -- SPACE/d/j: screen/page/line down, b/u/}{12:k}|
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

  it('interprets ESC+key as ALT chord', function()
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
    feed_data('\027\000')   -- ESC: go to Normal mode.
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
    expect_child_buf_lines({''})
  end)

  it('paste: normal-mode (+CRLF #10872)', function()
    feed_data(':set ruler')
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
    feed_data('\027[200~line 1\nline 2\n\027[201~')
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
    feed_data('\027\000')
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
    child_session:request('nvim_execute_lua', [[
      _G.save_paste_fn = vim.paste
      vim.paste = function(lines, phase) error("fake fail") end
    ]], {})
    -- Prepare something for dot-repeat/redo.
    feed_data('ifoo\n\027\000')
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
      {8:paste: Error executing lua: [string "<nvim>"]:2: f}|
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
    feed_data('ityped input...\027\000')
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
    child_session:request('nvim_execute_lua', [[
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
    child_session:request('nvim_execute_lua', [[
      vim.paste = function(lines, phase) return false end
    ]], {})
    feed_data('\027[200~line A\nline B\n\027[201~')
    feed_data('ifoo\n\027\000')
    expect_child_buf_lines({'foo',''})
  end)

  it("paste: 'nomodifiable' buffer", function()
    child_session:request('nvim_command', 'set nomodifiable')
    feed_data('\027[200~fail 1\nfail 2\n\027[201~')
    screen:expect{grid=[[
                                                        |
      {4:~                                                 }|
      {5:                                                  }|
      {8:paste: Error executing lua: vim.lua:196: Vim:E21: }|
      {8:Cannot make changes, 'modifiable' is off}          |
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
    feed_data(' end')
    expected = expected..' end'
    expect_child_buf_lines({expected})
    screen:expect([[
      zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz|
      zzzzzzzzzzzzzz end{1: }                               |
      {4:~                                                 }|
      {4:~                                                 }|
      {5:[No Name] [+]                                     }|
      {3:-- INSERT --}                                      |
      {3:-- TERMINAL --}                                    |
    ]])
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
    feed_data('\027\000')  -- ESC: go to Normal mode.
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

  it('allows termguicolors to be set at runtime', function()
    screen:set_option('rgb', true)
    screen:set_default_attr_ids({
      [1] = {reverse = true},
      [2] = {foreground = 13},
      [3] = {bold = true, reverse = true},
      [4] = {bold = true},
      [5] = {reverse = true, foreground = 4},
      [6] = {foreground = 4},
      [7] = {reverse = true, foreground = Screen.colors.SeaGreen4},
      [8] = {foreground = Screen.colors.SeaGreen4},
      [9] = {bold = true, foreground = Screen.colors.Blue1},
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
      {9:~                                                 }|
      {9:~                                                 }|
      {9:~                                                 }|
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

  it('is included in nvim_list_uis()', function()
    feed_data(':echo map(nvim_list_uis(), {k,v -> sort(items(filter(v, {k,v -> k[:3] !=# "ext_" })))})\r')
    screen:expect([=[
                                                        |
      {4:~                                                 }|
      {5:                                                  }|
      [[['height', 6], ['override', v:false], ['rgb', v:|
      false], ['width', 50]]]                           |
      {10:Press ENTER or type command to continue}{1: }          |
      {3:-- TERMINAL --}                                    |
    ]=])
  end)
end)

describe('TUI', function()
  before_each(clear)
  after_each(function()
    os.remove('testF')
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

describe('TUI FocusGained/FocusLost', function()
  local screen

  before_each(function()
    helpers.clear()
    screen = thelpers.screen_setup(0, '["'..nvim_prog
      ..'", "-u", "NONE", "-i", "NONE", "--cmd", "set noswapfile noshowcmd noruler"]')
    feed_data(":autocmd FocusGained * echo 'gained'\n")
    feed_data(":autocmd FocusLost * echo 'lost'\n")
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
    feed_data(":autocmd!\n")
    feed_data(":autocmd FocusLost * call append(line('$'), 'lost')\n")
    feed_data(":autocmd FocusGained * call append(line('$'), 'gained')\n")
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
    feed_data(':set shell='..nvim_dir..'/shell-test\n')
    feed_data(':set noshowmode laststatus=0\n')

    retry(2, 3 * screen.timeout, function()
      feed_data(':terminal\n')
      screen:sleep(1)
      feed_data('\027[I')
      screen:expect([[
        {1:r}eady $                                           |
        [Process exited 0]                                |
                                                          |
                                                          |
                                                          |
        gained                                            |
        {3:-- TERMINAL --}                                    |
      ]])
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

      -- If retry is needed...
      feed_data("\034\016")  -- CTRL-\ CTRL-N
      feed_data(':bwipeout!\n')
    end)
  end)

  it('in press-enter prompt', function()
    feed_data(":echom 'msg1'|echom 'msg2'|echom 'msg3'|echom 'msg4'|echom 'msg5'\n")
    -- Execute :messages to provoke the press-enter prompt.
    feed_data(":messages\n")
    feed_data('\027[I')
    feed_data('\027[I')
    screen:expect([[
      msg1                                              |
      msg2                                              |
      msg3                                              |
      msg4                                              |
      msg5                                              |
      {10:Press ENTER or type command to continue}{1: }          |
      {3:-- TERMINAL --}                                    |
    ]])
  end)
end)

-- These tests require `thelpers` because --headless/--embed
-- does not initialize the TUI.
describe("TUI 't_Co' (terminal colors)", function()
  local screen
  local is_freebsd = (string.lower(uname()) == 'freebsd')

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
    if is_freebsd then
      assert_term_colors("screen", nil, 256)
    else
      assert_term_colors("screen", nil, 8)
    end
  end)

  it("TERM=screen COLORTERM=screen uses 16/256 colors", function()
    if is_freebsd then
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
  local is_bsd = not not string.find(string.lower(uname()), 'bsd')
  local is_macos = not not string.find(string.lower(uname()), 'darwin')

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
    if is_bsd then  -- BSD lacks terminfo, builtin is always used.
      assert_term("xterm", "builtin_xterm")
    elseif is_macos then
      local status, _ = pcall(assert_term, "xterm", "xterm")
      if not status then
        pending("macOS: unibilium could not find terminfo", function() end)
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
      eq('--- Terminal info --- {{{\n', string.match(log, '--- Terminal.-\n'))
      ok(#log > 50)
    end)
  end)

end)

describe('TUI background color', function()
  local screen

  before_each(function()
    clear()
    screen = thelpers.screen_setup(0, '["'..nvim_prog
      ..'", "-u", "NONE", "-i", "NONE", "--cmd", "set noswapfile"]')
  end)

  it("triggers OptionSet event on terminal-response", function()
    feed_data('\027:autocmd OptionSet background echo "did OptionSet, yay!"\n')

    -- Wait for the child Nvim to register the OptionSet handler.
    feed_data('\027:autocmd OptionSet\n')
    screen:expect({any='--- Autocommands ---'})

    feed_data('\012')  -- CTRL-L: clear the screen
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
  end)

  it("handles deferred background color", function()
    local last_bg = 'dark'
    local function wait_for_bg(bg)
      -- Retry until the terminal response is handled.
      retry(100, nil, function()
        feed_data(':echo &background\n')
        screen:expect({
          timeout=40,
          grid=string.format([[
            {1: }                                                 |
            {4:~                                                 }|
            {4:~                                                 }|
            {4:~                                                 }|
            {5:[No Name]                       0,0-1          All}|
            %-5s                                             |
            {3:-- TERMINAL --}                                    |
          ]], bg)
        })
      end)
      last_bg = bg
    end

    local function assert_bg(colorspace, color, bg)
      -- Ensure the opposite of the expected bg is active.
      local other_bg = (bg == 'dark' and 'light' or 'dark')
      if last_bg ~= other_bg then
        feed_data(other_bg == 'light' and '\027]11;rgb:f/f/f\007'
                                      or  '\027]11;rgb:0/0/0\007')
        wait_for_bg(other_bg)
      end

      feed_data('\027]11;'..colorspace..':'..color..'\007')
      wait_for_bg(bg)
    end

    assert_bg('rgb', '0000/0000/0000', 'dark')
    assert_bg('rgb', 'ffff/ffff/ffff', 'light')
    assert_bg('rgb', '000/000/000', 'dark')
    assert_bg('rgb', 'fff/fff/fff', 'light')
    assert_bg('rgb', '00/00/00', 'dark')
    assert_bg('rgb', 'ff/ff/ff', 'light')
    assert_bg('rgb', '0/0/0', 'dark')
    assert_bg('rgb', 'f/f/f', 'light')

    assert_bg('rgb', 'f/0/0', 'dark')
    assert_bg('rgb', '0/f/0', 'light')
    assert_bg('rgb', '0/0/f', 'dark')

    assert_bg('rgb', '1/1/1', 'dark')
    assert_bg('rgb', '2/2/2', 'dark')
    assert_bg('rgb', '3/3/3', 'dark')
    assert_bg('rgb', '4/4/4', 'dark')
    assert_bg('rgb', '5/5/5', 'dark')
    assert_bg('rgb', '6/6/6', 'dark')
    assert_bg('rgb', '7/7/7', 'dark')
    assert_bg('rgb', '8/8/8', 'light')
    assert_bg('rgb', '9/9/9', 'light')
    assert_bg('rgb', 'a/a/a', 'light')
    assert_bg('rgb', 'b/b/b', 'light')
    assert_bg('rgb', 'c/c/c', 'light')
    assert_bg('rgb', 'd/d/d', 'light')
    assert_bg('rgb', 'e/e/e', 'light')

    assert_bg('rgb', '0/e/0', 'light')
    assert_bg('rgb', '0/d/0', 'light')
    assert_bg('rgb', '0/c/0', 'dark')
    assert_bg('rgb', '0/b/0', 'dark')

    assert_bg('rgb', 'f/0/f', 'dark')
    assert_bg('rgb', 'f/1/f', 'dark')
    assert_bg('rgb', 'f/2/f', 'dark')
    assert_bg('rgb', 'f/3/f', 'light')
    assert_bg('rgb', 'f/4/f', 'light')

    assert_bg('rgba', '0000/0000/0000/0000', 'dark')
    assert_bg('rgba', '0000/0000/0000/ffff', 'dark')
    assert_bg('rgba', 'ffff/ffff/ffff/0000', 'light')
    assert_bg('rgba', 'ffff/ffff/ffff/ffff', 'light')
    assert_bg('rgba', '000/000/000/000', 'dark')
    assert_bg('rgba', '000/000/000/fff', 'dark')
    assert_bg('rgba', 'fff/fff/fff/000', 'light')
    assert_bg('rgba', 'fff/fff/fff/fff', 'light')
    assert_bg('rgba', '00/00/00/00', 'dark')
    assert_bg('rgba', '00/00/00/ff', 'dark')
    assert_bg('rgba', 'ff/ff/ff/00', 'light')
    assert_bg('rgba', 'ff/ff/ff/ff', 'light')
    assert_bg('rgba', '0/0/0/0', 'dark')
    assert_bg('rgba', '0/0/0/f', 'dark')
    assert_bg('rgba', 'f/f/f/0', 'light')
    assert_bg('rgba', 'f/f/f/f', 'light')
  end)
end)
