local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear, feed = n.clear, n.feed
local eval = n.eval
local eq = t.eq
local neq = t.neq
local command = n.command
local set_method_error = n.set_method_error
local api = n.api
local async_meths = n.async_meths
local test_build_dir = t.paths.test_build_dir
local nvim_prog = n.nvim_prog
local testprg = n.testprg
local exec = n.exec
local exec_capture = n.exec_capture
local exc_exec = n.exc_exec
local exec_lua = n.exec_lua
local poke_eventloop = n.poke_eventloop
local assert_alive = n.assert_alive
local retry = t.retry
local is_os = t.is_os
local fn = n.fn
local skip = t.skip

describe('ui/ext_messages', function()
  local screen
  local fname = 'Xtest_functional_ui_messages_spec'

  before_each(function()
    clear()
    screen = Screen.new(25, 5, { rgb = true, ext_messages = true, ext_popupmenu = true })
    screen:add_extra_attr_ids {
      [100] = { undercurl = true, special = Screen.colors.Red },
      [101] = { foreground = Screen.colors.Magenta1, bold = true },
    }
  end)
  after_each(function()
    os.remove(fname)
  end)

  it('msg_clear follows msg_show kind of confirm', function()
    feed('iline 1<esc>')
    feed(':call confirm("test")<cr>')
    local s1 = [[
      line ^1                   |
      {1:~                        }|*4
    ]]
    screen:expect({
      grid = s1,
      cmdline = {
        {
          content = { { '' } },
          hl_id = 10,
          pos = 0,
          prompt = '[O]k: ',
        },
      },
      messages = {
        {
          content = { { '\ntest\n', 6, 10 } },
          history = false,
          kind = 'confirm',
        },
      },
    })
    feed('<cr>')
    screen:expect({ grid = s1, cmdline = { { abort = false } } })
  end)

  it('msg_show kinds', function()
    feed('iline 1\nline 2<esc>')

    -- confirm is now cmdline prompt
    feed(':echo confirm("test")<cr>')
    local s1 = [[
      line 1                   |
      line ^2                   |
      {1:~                        }|*3
    ]]
    screen:expect({
      grid = s1,
      cmdline = {
        {
          content = { { '' } },
          hl_id = 10,
          pos = 0,
          prompt = '[O]k: ',
        },
      },
      messages = {
        {
          content = { { '\ntest\n', 6, 10 } },
          history = false,
          kind = 'confirm',
        },
      },
    })
    feed('<cr>')
    screen:expect({
      grid = s1,
      cmdline = { { abort = false } },
      messages = {
        {
          content = { { '\ntest\n', 6, 10 } },
          history = false,
          kind = 'confirm',
        },
        {
          content = { { '1' } },
          history = false,
          kind = 'echo',
        },
        {
          content = { { 'Press ENTER or type command to continue', 6, 18 } },
          history = false,
          kind = 'return_prompt',
        },
      },
    })
    feed('<cr>')

    -- :substitute confirm is now cmdline prompt
    feed(':%s/i/X/gc<cr>')
    screen:expect({
      grid = [[
        l{2:^i}ne 1                   |
        l{10:i}ne 2                   |
        {1:~                        }|*3
      ]],
      cmdline = {
        {
          content = { { '' } },
          hl_id = 18,
          pos = 0,
          prompt = 'replace with X? (y)es/(n)o/(a)ll/(q)uit/(l)ast/scroll up(^E)/down(^Y)',
        },
      },
    })
    feed('nq')

    -- kind=wmsg (editing readonly file)
    command('write ' .. fname)
    command('set readonly nohls')
    feed('G$x')
    screen:expect({
      grid = [[
        line 1                   |
        line^                     |
        {1:~                        }|*3
      ]],
      cmdline = { { abort = false } },
      messages = {
        {
          content = { { 'W10: Warning: Changing a readonly file', 19, 26 } },
          history = true,
          kind = 'wmsg',
        },
      },
    })

    -- kind=wmsg ('wrapscan' after search reaches EOF)
    feed('uG$/i<CR>G$')
    screen:expect {
      grid = s1,
      cmdline = { { abort = false } },
      messages = {
        {
          content = { { 'search hit BOTTOM, continuing at TOP', 19, 26 } },
          history = true,
          kind = 'wmsg',
        },
      },
    }

    -- kind=emsg after :throw
    feed(':throw "foo"<cr>')
    screen:expect {
      grid = s1,
      cmdline = { { abort = false } },
      messages = {
        {
          content = {
            { 'Error detected while processing :\nE605: Exception not caught: foo', 9, 6 },
          },
          history = true,
          kind = 'emsg',
        },
      },
    }

    -- kind=quickfix after :cnext
    feed('<c-c>')
    command("caddexpr [expand('%').':1:line1',expand('%').':2:line2']")
    feed(':cnext<CR>$')
    screen:expect {
      grid = s1,
      cmdline = { { abort = false } },
      messages = {
        {
          content = { { '(2 of 2): line2' } },
          history = true,
          kind = 'quickfix',
        },
      },
    }

    -- search_cmd
    feed('?line<CR>G$')
    screen:expect({
      grid = s1,
      cmdline = { { abort = false } },
      messages = {
        {
          content = { { '?line ' } },
          history = false,
          kind = 'search_cmd',
        },
      },
    })

    -- highlight
    feed('G$:filter character highlight<CR>')
    screen:expect({
      grid = s1,
      cmdline = { { abort = false } },
      messages = {
        {
          content = {
            { '\n@character     ' },
            { 'xxx', 26, 156 },
            { ' ' },
            { 'links to', 18, 5 },
            { ' Character\n@character.special ' },
            { 'xxx', 16, 157 },
            { ' ' },
            { 'links to', 18, 5 },
            { ' SpecialChar' },
          },
          history = false,
          kind = 'list_cmd',
        },
      },
    })

    -- undo
    feed('uu')
    screen:expect({
      grid = [[
        ^                         |
        {1:~                        }|*4
      ]],
      messages = {
        {
          content = { { 'Already at oldest change' } },
          history = true,
          kind = 'undo',
        },
      },
    })

    feed('<C-r><C-r><C-r>')
    local s2 = [[
      line 1                   |
      line^                     |
      {1:~                        }|*3
    ]]
    screen:expect({
      grid = s2,
      messages = {
        {
          content = { { 'Already at newest change' } },
          history = true,
          kind = 'undo',
        },
      },
    })

    -- kind=completion
    command('set noshowmode')
    feed('i<C-n>')
    screen:expect({
      grid = s2,
      messages = {
        {
          content = { { 'The only match' } },
          history = false,
          kind = 'completion',
        },
      },
    })
    feed('<Esc>l')
    command('set showmode')

    -- kind=echoerr for nvim_echo() err
    feed(':call nvim_echo([["Error"], ["Message", "Special"]], 1, #{ err:1 })<CR>')
    screen:expect({
      grid = s2,
      cmdline = { { abort = false } },
      messages = {
        {
          content = { { 'Error', 9, 6 }, { 'Message', 16, 100 } },
          history = true,
          kind = 'echoerr',
        },
      },
    })

    -- kind=verbose for nvim_echo() verbose
    feed(':call nvim_echo([["Verbose Message"]], 1, #{ verbose:1 })<CR>')
    screen:expect({
      grid = s2,
      cmdline = { { abort = false } },
      messages = {
        {
          content = { { 'Verbose Message' } },
          history = true,
          kind = 'verbose',
        },
      },
    })

    -- kind=verbose for :verbose messages
    feed(':1verbose filter Diff[AC] hi<CR>')
    screen:expect({
      grid = s2,
      cmdline = { { abort = false } },
      messages = {
        {
          content = {
            { '\nDiffAdd        ' },
            { 'xxx', 22, 30 },
            { ' ' },
            { 'ctermbg=', 18, 5 },
            { '81 ' },
            { 'guibg=', 18, 5 },
            { 'LightBlue' },
          },
          history = false,
          kind = 'list_cmd',
        },
        {
          content = { { '\n\tLast set from Lua (run Nvim with -V1 for more details)' } },
          history = false,
          kind = 'verbose',
        },
        {
          content = {
            { '\nDiffChange     ' },
            { 'xxx', 4, 31 },
            { ' ' },
            { 'ctermbg=', 18, 5 },
            { '225 ' },
            { 'guibg=', 18, 5 },
            { 'LightMagenta' },
          },
          history = false,
          kind = 'list_cmd',
        },
        {
          content = { { '\n\tLast set from Lua (run Nvim with -V1 for more details)' } },
          history = false,
          kind = 'verbose',
        },
        {
          content = { { 'Press ENTER or type command to continue', 6, 18 } },
          history = false,
          kind = 'return_prompt',
        },
      },
    })

    feed('<CR>')
    exec([[
      set verbose=9
      augroup verbose
        autocmd BufEnter * echoh "BufEnter"
        autocmd BufWinEnter * bdelete
      augroup END
    ]])
    feed(':edit! foo<CR>')
    screen:expect({
      grid = s2,
      cmdline = { { abort = false } },
      messages = {
        {
          content = { { 'Executing BufEnter Autocommands for "*"' } },
          history = true,
          kind = 'verbose',
        },
        {
          content = { { 'autocommand echoh "BufEnter"\n' } },
          history = true,
          kind = 'verbose',
        },
        {
          content = { { 'Executing BufWinEnter Autocommands for "*"' } },
          history = true,
          kind = 'verbose',
        },
        {
          content = { { 'autocommand bdelete\n' } },
          history = true,
          kind = 'verbose',
        },
        {
          content = { { 'Press ENTER or type command to continue', 6, 18 } },
          history = false,
          kind = 'return_prompt',
        },
      },
    })
    feed('<CR>')
    command('autocmd! verbose')
    command('augroup! verbose')
    command('set verbose=0')

    n.add_builddir_to_rtp()
    feed(':help<CR>:tselect<CR>')
    screen:expect({
      grid = [[
        ^*help.txt*      Nvim     |
                                 |
        {3:help.txt [Help][-][RO]   }|
        line                     |
        {2:<i_messages_spec [+][RO] }|
      ]],
      cmdline = {
        {
          content = { { '' } },
          hl_id = 0,
          pos = 0,
          prompt = 'Type number and <Enter> (q or empty cancels): ',
        },
      },
      -- Message depends on runtimepath, only test the static text...
      condition = function()
        for _, msg in ipairs(screen.messages) do
          eq(false, msg.history)
          eq('confirm', msg.kind)
          eq({ 150, '  # pri kind tag', 23 }, msg.content[1])
          eq({ 0, '\n                        ', 0 }, msg.content[2])
          eq({ 150, 'file\n', 23 }, msg.content[3])
          eq({ 0, '> 1 F        ', 0 }, msg.content[4])
          eq({ 150, 'help.txt', 23 }, msg.content[5])
          eq({ 0, ' \n                        ', 0 }, msg.content[6])
          eq({ 0, '\n               *help.txt*', 0 }, msg.content[#msg.content])
        end
        screen.messages = {}
      end,
    })
    feed('<CR>:bdelete<CR>$')

    -- kind=shell for :!cmd messages
    local cmd = t.is_os('win') and 'echo stdout& echo stderr>&2& exit 3'
      or '{ echo stdout; echo stderr >&2; exit 3; }'
    feed((':!%s<CR>'):format(cmd))
    screen:expect({
      grid = s2,
      cmdline = { { abort = false } },
      messages = {
        {
          content = { { (':!%s\r\n[No write since last change]\n'):format(cmd) } },
          history = false,
          kind = '',
        },
        {
          content = { { ('stdout%s\n'):format(t.is_os('win') and '\r' or '') } },
          history = false,
          kind = 'shell_out',
        },
        {
          content = { { ('stderr%s\n'):format(t.is_os('win') and '\r' or ''), 9, 6 } },
          history = false,
          kind = 'shell_err',
        },
        {
          content = { { '\nshell returned 3\n\n' } },
          history = false,
          kind = 'shell_ret',
        },
        {
          content = { { 'Press ENTER or type command to continue', 6, 18 } },
          history = false,
          kind = 'return_prompt',
        },
      },
    })

    feed('<CR>:registers .<CR>')
    screen:expect({
      grid = s2,
      cmdline = { {
        abort = false,
      } },
      messages = {
        {
          content = { { '\nType Name Content', 101, 23 }, { '\n  c  ".   ' } },
          history = false,
          kind = 'list_cmd',
        },
      },
    })

    feed(':au ChanInfo * foo<CR>:au ChanInfo<CR>')
    screen:expect({
      grid = s2,
      cmdline = { {
        abort = false,
      } },
      messages = {
        {
          content = {
            { '\n--- Autocommands ---', 101, 23 },
            { '\n' },
            { 'ChanInfo', 101, 23 },
            { '\n*foo' },
          },
          history = false,
          kind = 'list_cmd',
        },
      },
    })
  end)

  it(':echoerr', function()
    feed(':echoerr "raa"<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      cmdline = { { abort = false } },
      messages = {
        {
          content = { { 'raa', 9, 6 } },
          history = true,
          kind = 'echoerr',
        },
      },
    }

    -- cmdline in a later input cycle clears error message
    feed(':')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      cmdline = { {
        firstc = ':',
        content = { { '' } },
        pos = 0,
      } },
    }

    feed('echoerr "bork" | echoerr "fail"<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      cmdline = { { abort = false } },
      messages = {
        {
          content = { { 'bork', 9, 6 } },
          history = true,
          kind = 'echoerr',
        },
        {
          content = { { 'fail', 9, 6 } },
          history = true,
          kind = 'echoerr',
        },
        {
          content = { { 'Press ENTER or type command to continue', 6, 18 } },
          history = false,
          kind = 'return_prompt',
        },
      },
    }

    feed(':echoerr "extrafail"<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      cmdline = { { abort = false } },
      messages = {
        {
          content = { { 'bork', 9, 6 } },
          history = true,
          kind = 'echoerr',
        },
        {
          content = { { 'fail', 9, 6 } },
          history = true,
          kind = 'echoerr',
        },
        {
          content = { { 'extrafail', 9, 6 } },
          history = true,
          kind = 'echoerr',
        },
        {
          content = { { 'Press ENTER or type command to continue', 6, 18 } },
          history = false,
          kind = 'return_prompt',
        },
      },
    }

    feed('<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
    }

    -- cmdline without interleaving wait/display keeps the error message
    feed(':echoerr "problem" | let x = input("foo> ")<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      messages = {
        {
          content = { { 'problem', 9, 6 } },
          history = true,
          kind = 'echoerr',
        },
      },
      cmdline = {
        {
          prompt = 'foo> ',
          hl_id = 0,
          content = { { '' } },
          pos = 0,
        },
      },
    }

    feed('solution<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      cmdline = { { abort = false } },
    }
    eq('solution', eval('x'))

    feed(':messages<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      cmdline = { { abort = false } },
      msg_history = {
        { kind = 'echoerr', content = { { 'raa', 9, 6 } } },
        { kind = 'echoerr', content = { { 'bork', 9, 6 } } },
        { kind = 'echoerr', content = { { 'fail', 9, 6 } } },
        { kind = 'echoerr', content = { { 'extrafail', 9, 6 } } },
        { kind = 'echoerr', content = { { 'problem', 9, 6 } } },
      },
      messages = {
        {
          content = { { 'Press ENTER or type command to continue', 6, 18 } },
          history = false,
          kind = 'return_prompt',
        },
      },
    }

    feed '<cr>'
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
    }
  end)

  it(':echoerr multiline', function()
    exec_lua([[vim.g.multi = table.concat({ "bork", "fail" }, "\n")]])
    feed(':echoerr g:multi<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      cmdline = { { abort = false } },
      messages = {
        {
          content = { { 'bork\nfail', 9, 6 } },
          history = true,
          kind = 'echoerr',
        },
      },
    }

    feed(':messages<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      cmdline = { { abort = false } },
      messages = {
        {
          content = { { 'Press ENTER or type command to continue', 6, 18 } },
          history = false,
          kind = 'return_prompt',
        },
      },
      msg_history = {
        {
          content = { { 'bork\nfail', 9, 6 } },
          kind = 'echoerr',
        },
      },
    }
  end)

  it('shortmess-=S', function()
    command('set shortmess-=S')
    feed('iline 1\nline 2<esc>')

    feed('/line<cr>')
    screen:expect {
      grid = [[
      {10:^line} 1                   |
      {10:line} 2                   |
      {1:~                        }|*3
    ]],
      cmdline = { { abort = false } },
      messages = {
        { content = { { '/line      W [1/2]' } }, kind = 'search_count', history = false },
      },
    }

    feed('n')
    screen:expect {
      grid = [[
      {10:line} 1                   |
      {10:^line} 2                   |
      {1:~                        }|*3
    ]],
      messages = {
        { content = { { '/line        [2/2]' } }, kind = 'search_count', history = false },
      },
    }
  end)

  it("doesn't crash with column adjustment #10069", function()
    feed(':let [x,y] = [1,2]<cr>')
    feed(':let x y<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      cmdline = { { abort = false } },
      messages = {
        { content = { { 'x                     #1' } }, kind = 'list_cmd', history = false },
        { content = { { 'y                     #2' } }, kind = 'list_cmd', history = false },
        {
          content = { { 'Press ENTER or type command to continue', 6, 18 } },
          history = false,
          kind = 'return_prompt',
        },
      },
    }
  end)

  it('&showmode', function()
    command('imap <f2> <cmd>echomsg "stuff"<cr>')
    feed('i')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      showmode = { { '-- INSERT --', 5, 11 } },
    }

    feed('alphpabet<cr>alphanum<cr>')
    screen:expect {
      grid = [[
      alphpabet                |
      alphanum                 |
      ^                         |
      {1:~                        }|*2
    ]],
      showmode = { { '-- INSERT --', 5, 11 } },
    }

    feed('<c-x>')
    screen:expect {
      grid = [[
      alphpabet                |
      alphanum                 |
      ^                         |
      {1:~                        }|*2
    ]],
      showmode = { { '-- ^X mode (^]^D^E^F^I^K^L^N^O^Ps^U^V^Y)', 5, 11 } },
    }

    feed('<c-p>')
    screen:expect {
      grid = [[
      alphpabet                |
      alphanum                 |
      alphanum^                 |
      {1:~                        }|*2
    ]],
      popupmenu = {
        anchor = { 1, 2, 0 },
        items = { { 'alphpabet', '', '', '' }, { 'alphanum', '', '', '' } },
        pos = 1,
      },
      showmode = { { '-- Keyword Local completion (^N^P) ', 5, 11 }, { 'match 1 of 2', 6, 18 } },
    }

    -- echomsg and showmode don't overwrite each other, this is the same
    -- as the TUI behavior with cmdheight=2 or larger.
    feed('<f2>')
    screen:expect {
      grid = [[
      alphpabet                |
      alphanum                 |
      alphanum^                 |
      {1:~                        }|*2
    ]],
      popupmenu = {
        anchor = { 1, 2, 0 },
        items = { { 'alphpabet', '', '', '' }, { 'alphanum', '', '', '' } },
        pos = 1,
      },
      messages = {
        {
          content = { { 'stuff' } },
          history = true,
          kind = 'echomsg',
        },
      },
      showmode = { { '-- Keyword Local completion (^N^P) ', 5, 11 }, { 'match 1 of 2', 6, 18 } },
    }

    feed('<c-p>')
    screen:expect {
      grid = [[
      alphpabet                |
      alphanum                 |
      alphpabet^                |
      {1:~                        }|*2
    ]],
      popupmenu = {
        anchor = { 1, 2, 0 },
        items = { { 'alphpabet', '', '', '' }, { 'alphanum', '', '', '' } },
        pos = 0,
      },
      messages = {
        {
          content = { { 'stuff' } },
          history = true,
          kind = 'echomsg',
        },
      },
      showmode = { { '-- Keyword Local completion (^N^P) ', 5, 11 }, { 'match 2 of 2', 6, 18 } },
    }

    feed('<esc>:messages<cr>')
    screen:expect {
      grid = [[
      alphpabet                |
      alphanum                 |
      alphpabe^t                |
      {1:~                        }|*2
    ]],
      cmdline = { { abort = false } },
      msg_history = { {
        content = { { 'stuff' } },
        kind = 'echomsg',
      } },
      messages = {
        {
          content = { { 'Press ENTER or type command to continue', 6, 18 } },
          history = false,
          kind = 'return_prompt',
        },
      },
    }
  end)

  it('&showmode with macro-recording message', function()
    feed('qq')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      showmode = { { 'recording @q', 5, 11 } },
    }

    feed('i')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      showmode = { { '-- INSERT --recording @q', 5, 11 } },
    }

    feed('<esc>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      showmode = { { 'recording @q', 5, 11 } },
    }

    feed('q')
    screen:expect([[
      ^                         |
      {1:~                        }|*4
    ]])
  end)

  it('shows macro-recording message with &noshowmode', function()
    command('set noshowmode')
    feed('qq')
    -- also check mode to avoid immediate success
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      showmode = { { 'recording @q', 5, 11 } },
      mode = 'normal',
    }

    feed('i')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      showmode = { { 'recording @q', 5, 11 } },
      mode = 'insert',
    }

    feed('<esc>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      showmode = { { 'recording @q', 5, 11 } },
      mode = 'normal',
    }

    feed('q')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      mode = 'normal',
    }
  end)

  it('supports &showcmd and &ruler', function()
    command('set showcmd ruler')
    command('hi link MsgArea ErrorMsg')
    screen:expect({
      grid = [[
        ^                         |
        {1:~                        }|*4
      ]],
      ruler = { { '0,0-1   All', 9, 62 } },
    })
    command('hi clear MsgArea')
    feed('i')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      showmode = { { '-- INSERT --', 5, 11 } },
      ruler = { { '0,1     All' } },
    }
    feed('abcde<cr>12345<esc>')
    screen:expect {
      grid = [[
      abcde                    |
      1234^5                    |
      {1:~                        }|*3
    ]],
      ruler = { { '2,5     All' } },
    }
    feed('d')
    screen:expect {
      grid = [[
      abcde                    |
      1234^5                    |
      {1:~                        }|*3
    ]],
      showcmd = { { 'd' } },
      ruler = { { '2,5     All' } },
    }
    feed('<esc>^')
    screen:expect {
      grid = [[
      abcde                    |
      ^12345                    |
      {1:~                        }|*3
    ]],
      ruler = { { '2,1     All' } },
    }
    feed('<c-v>k2l')
    screen:expect({
      grid = [[
        {17:ab}^cde                    |
        {17:123}45                    |
        {1:~                        }|*3
      ]],
      showmode = { { '-- VISUAL BLOCK --', 5, 11 } },
      showcmd = { { '2x3' } },
      ruler = { { '1,3     All' } },
    })
    feed('o<esc>d')
    screen:expect {
      grid = [[
      abcde                    |
      ^12345                    |
      {1:~                        }|*3
    ]],
      showcmd = { { 'd' } },
      ruler = { { '2,1     All' } },
    }
    feed('i')
    screen:expect {
      grid = [[
      abcde                    |
      ^12345                    |
      {1:~                        }|*3
    ]],
      showcmd = { { 'di' } },
      ruler = { { '2,1     All' } },
    }
    feed('w')
    screen:expect {
      grid = [[
      abcde                    |
      ^                         |
      {1:~                        }|*3
    ]],
      ruler = { { '2,0-1   All' } },
    }

    -- when ruler is part of statusline it is not externalized.
    -- this will be added as part of future ext_statusline support
    command('set laststatus=2')
    screen:expect({
      grid = [[
        abcde                    |
        ^                         |
        {1:~                        }|*2
        {3:<] [+] 2,0-1          All}|
      ]],
      ruler = { { '2,0-1   All' } },
    })
  end)

  it('keeps history of message of different kinds', function()
    feed(':echomsg "howdy"<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      cmdline = { { abort = false } },
      messages = {
        {
          content = { { 'howdy' } },
          history = true,
          kind = 'echomsg',
        },
      },
    }

    -- always test a message without kind. If this one gets promoted to a
    -- category, add a new message without kind.
    feed('<c-c>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      messages = {
        {
          content = { { 'Type  :qa  and press <Enter> to exit Nvim' } },
          history = true,
          kind = '',
        },
      },
    }

    feed(':echoerr "bork"<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      cmdline = { { abort = false } },
      messages = {
        {
          content = { { 'bork', 9, 6 } },
          history = true,
          kind = 'echoerr',
        },
      },
    }

    feed(':echo "xyz"<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      cmdline = { { abort = false } },
      messages = {
        {
          content = { { 'xyz' } },
          history = false,
          kind = 'echo',
        },
      },
    }

    feed(':call nosuchfunction()<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      cmdline = { { abort = false } },
      messages = {
        {
          content = { { 'E117: Unknown function: nosuchfunction', 9, 6 } },
          history = true,
          kind = 'emsg',
        },
      },
    }

    feed(':messages<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      cmdline = { { abort = false } },
      msg_history = {
        { kind = 'echomsg', content = { { 'howdy' } } },
        { kind = '', content = { { 'Type  :qa  and press <Enter> to exit Nvim' } } },
        { kind = 'echoerr', content = { { 'bork', 9, 6 } } },
        { kind = 'emsg', content = { { 'E117: Unknown function: nosuchfunction', 9, 6 } } },
      },
      messages = {
        {
          content = { { 'Press ENTER or type command to continue', 6, 18 } },
          history = false,
          kind = 'return_prompt',
        },
      },
    }
  end)

  it("implies ext_cmdline but allows changing 'cmdheight'", function()
    eq(0, eval('&cmdheight'))
    feed(':set cmdheight=1')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      cmdline = {
        {
          content = { { 'set cmdheight=1' } },
          firstc = ':',
          pos = 15,
        },
      },
    }

    feed('<cr>')
    screen:expect({
      grid = [[
        ^                         |
        {1:~                        }|*3
                                 |
      ]],
      cmdline = { { abort = false } },
    })
    eq(1, eval('&cmdheight'))

    feed(':set cmdheight=0')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*3
                               |
    ]],
      cmdline = {
        {
          content = { { 'set cmdheight=0' } },
          firstc = ':',
          pos = 15,
        },
      },
    }
    feed('<cr>')
    screen:expect({
      grid = [[
        ^                         |
        {1:~                        }|*4
      ]],
      cmdline = { { abort = false } },
    })
    eq(0, eval('&cmdheight'))
  end)

  it('supports multiline messages from lua', function()
    feed(':lua error("such\\nmultiline\\nerror")<cr>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      cmdline = { { abort = false } },
      messages = {
        {
          content = {
            {
              [[E5108: Error executing lua [string ":lua"]:1: such
multiline
error
stack traceback:
	[C]: in function 'error'
	[string ":lua"]:1: in main chunk]],
              9,
              6,
            },
          },
          history = true,
          kind = 'lua_error',
        },
      },
    }
  end)

  it('supports multiline messages from rpc', function()
    feed(':call rpcrequest(1, "test_method")<cr>')

    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      cmdline = { { abort = false } },
      messages = {
        {
          content = {
            { "Error invoking 'test_method' on channel 1:\ncomplete\nerror\n\nmessage", 9, 6 },
          },
          history = true,
          kind = 'rpc_error',
        },
      },
      request_cb = function(name)
        if name == 'test_method' then
          set_method_error('complete\nerror\n\nmessage')
        end
      end,
    }
  end)

  it('supports multiline messages for :map', function()
    command('mapclear')
    command('nmap Y y$')
    command('nmap Q @@')
    command('nnoremap j k')
    feed(':map<cr>')

    screen:expect {
      cmdline = { { abort = false } },
      messages = {
        {
          content = {
            { '\nn  Q             @@\nn  Y             y$\nn  j           ' },
            { '*', 18, 1 },
            { ' k' },
          },
          history = false,
          kind = 'list_cmd',
        },
      },
    }
  end)

  it('wildmode=list', function()
    screen:try_resize(25, 7)
    screen:set_option('ext_popupmenu', false)

    command('set wildmenu wildmode=list')
    feed(':set wildm<tab>')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*6
    ]],
      messages = {
        {
          content = { { 'wildmenu  wildmode\n' } },
          history = false,
          kind = 'wildlist',
        },
      },
      cmdline = {
        {
          firstc = ':',
          content = { { 'set wildm' } },
          pos = 9,
        },
      },
    }
  end)

  it('hides prompt_for_number messages', function()
    command('set spell')
    feed('ihelllo<esc>')

    feed('z=')
    screen:expect({
      grid = [[
        {100:^helllo}                   |
        {1:~                        }|*4
      ]],
      cmdline = {
        {
          content = { { '' } },
          hl_id = 0,
          pos = 0,
          prompt = 'Type number and <Enter> or click with the mouse (q or empty cancels): ',
        },
      },
      messages = {
        {
          content = { { 'Change "helllo" to:\n 1 "Hello"\n 2 "Hallo"\n 3 "Hullo"' } },
          history = false,
          kind = 'confirm',
        },
      },
    })

    feed('1')
    screen:expect({
      grid = [[
        {100:^helllo}                   |
        {1:~                        }|*4
      ]],
      cmdline = {
        {
          content = { { '1' } },
          hl_id = 0,
          pos = 1,
          prompt = 'Type number and <Enter> or click with the mouse (q or empty cancels): ',
        },
      },
      messages = {
        {
          content = { { 'Change "helllo" to:\n 1 "Hello"\n 2 "Hallo"\n 3 "Hullo"' } },
          history = false,
          kind = 'confirm',
        },
      },
    })

    feed('<cr>')
    screen:expect({
      grid = [[
        ^Hello                    |
        {1:~                        }|*4
      ]],
      cmdline = { { abort = false } },
    })

    async_meths.nvim_command("let g:n = inputlist(['input0', 'input1'])")
    screen:expect({
      grid = [[
        ^Hello                    |
        {1:~                        }|*4
      ]],
      cmdline = {
        {
          content = { { '' } },
          hl_id = 0,
          pos = 0,
          prompt = 'Type number and <Enter> or click with the mouse (q or empty cancels): ',
        },
      },
      messages = {
        {
          content = { { 'input0\ninput1' } },
          history = false,
          kind = 'confirm',
        },
      },
    })

    feed('42<CR>')
    screen:expect({
      grid = [[
        ^Hello                    |
        {1:~                        }|*4
      ]],
      cmdline = { {
        abort = false,
      } },
    })
    eq(42, eval('g:n'))
  end)

  it('supports nvim_echo messages with multiple attrs', function()
    async_meths.nvim_echo(
      { { 'wow, ', 'Search' }, { 'such\n\nvery ', 'ErrorMsg' }, { 'color', 'LineNr' } },
      true,
      {}
    )
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      messages = {
        {
          content = { { 'wow, ', 10, 8 }, { 'such\n\nvery ', 9, 6 }, { 'color', 8, 12 } },
          history = true,
          kind = 'echomsg',
        },
      },
    }

    feed ':ls<cr>'
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      cmdline = { { abort = false } },
      messages = {
        {
          content = { { '\n  1 %a   "[No Name]"                    line 1' } },
          kind = 'list_cmd',
          history = false,
        },
      },
    }

    feed ':messages<cr>'
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
      cmdline = { { abort = false } },
      messages = {
        {
          content = { { 'Press ENTER or type command to continue', 6, 18 } },
          history = false,
          kind = 'return_prompt',
        },
      },
      msg_history = {
        {
          content = { { 'wow, ', 10, 8 }, { 'such\n\nvery ', 9, 6 }, { 'color', 8, 12 } },
          kind = 'echomsg',
        },
      },
    }

    feed '<cr>'
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*4
    ]],
    }
  end)

  it('does not truncate messages', function()
    command('write ' .. fname)
    screen:expect({
      messages = {
        {
          content = { { string.format('"%s" [New] 0L, 0B written', fname) } },
          kind = 'bufwrite',
          history = true,
        },
      },
    })
  end)

  it('does not do showmode unnecessarily #29086', function()
    local screen_showmode = screen._handle_msg_showmode
    local showmode = 0
    screen._handle_msg_showmode = function(...)
      screen_showmode(...)
      showmode = showmode + 1
    end
    local s1 = [[
      ^                         |
      {1:~                        }|*4
    ]]
    screen:expect(s1)
    eq(showmode, 0)
    feed('i')
    screen:expect({
      grid = s1,
      showmode = { { '-- INSERT --', 5, 11 } },
    })
    eq(showmode, 2)
    command('set noshowmode')
    feed('<Esc>')
    screen:expect(s1)
    eq(showmode, 3)
    feed('i')
    screen:expect_unchanged()
    eq(showmode, 3)
  end)

  it('emits single message for multiline print())', function()
    exec_lua([[print("foo\nbar\nbaz")]])
    screen:expect({
      messages = {
        {
          content = { { 'foo\nbar\nbaz' } },
          history = true,
          kind = 'lua_print',
        },
      },
    })
    exec_lua([[print(vim.inspect({ foo = "bar" }))]])
    screen:expect({
      grid = [[
        ^                         |
        {1:~                        }|*4
      ]],
      messages = {
        {
          content = { { '{\n  foo = "bar"\n}' } },
          history = true,
          kind = 'lua_print',
        },
      },
    })
    exec_lua([[vim.print({ foo = "bar" })]])
    screen:expect_unchanged()
  end)

  it('ruler redraw does not crash due to double grid_line_start()', function()
    exec_lua([[
      local ns = vim.api.nvim_create_namespace('')
      vim.ui_attach(ns, { ext_messages = true }, function(event, ...)
        if event == 'msg_ruler' then
          vim.api.nvim__redraw({ flush = true })
        end
      end)
      vim.o.ruler = true
      vim.o.laststatus = 0
    ]])
    feed('i')
    n.assert_alive()
  end)

  it(':digraph contains newlines', function()
    command('digraph')
    screen:expect({
      condition = function()
        local nl = 0
        eq('list_cmd', screen.messages[1].kind)
        for _, chunk in ipairs(screen.messages[1].content) do
          nl = nl + (chunk[2]:find('\n') and 1 or 0)
        end
        eq(682, nl)
        screen.messages = {}
      end,
    })
  end)

  it('g< mapping shows recent messages', function()
    command('echo "foo" | echo "bar"')
    screen:expect({
      grid = [[
        ^                         |
        {1:~                        }|*4
      ]],
      messages = {
        {
          content = { { 'bar' } },
          history = false,
          kind = 'echo',
        },
      },
    })
    feed(':messages<CR>g<lt>')
    screen:expect({
      grid = [[
        ^                         |
        {1:~                        }|*4
      ]],
      messages = {
        {
          content = { { 'Press ENTER or type command to continue', 6, 18 } },
          history = false,
          kind = 'return_prompt',
        },
      },
      msg_history = {
        {
          content = { { 'foo' } },
          kind = 'echo',
        },
        {
          content = { { 'bar' } },
          kind = 'echo',
        },
      },
    })
  end)

  it('single event for multiple :set options', function()
    command('set sw ts sts')
    screen:expect({
      grid = [[
        ^                         |
        {1:~                        }|*4
      ]],
      messages = {
        {
          content = { { '  shiftwidth=8\n  tabstop=8\n  softtabstop=0' } },
          history = false,
          kind = 'list_cmd',
        },
      },
    })
  end)

  it('clears showmode after insert_expand mode', function()
    feed('i<C-N>')
    screen:expect({
      grid = [[
        ^                         |
        {1:~                        }|*4
      ]],
      showmode = { { '-- Keyword completion (^N^P) ', 5, 11 }, { 'Pattern not found', 9, 6 } },
    })
    feed('<Esc>')
    screen:expect([[
      ^                         |
      {1:~                        }|*4
    ]])
  end)
end)

describe('ui/builtin messages', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(60, 7, { rgb = true, ext_popupmenu = true })
    screen:add_extra_attr_ids {
      [100] = { background = Screen.colors.LightRed },
      [101] = { background = Screen.colors.Grey20 },
      [102] = { foreground = Screen.colors.Magenta1, bold = true },
    }
  end)

  it('supports multiline messages from rpc', function()
    feed(':call rpcrequest(1, "test_method")<cr>')

    screen:expect {
      grid = [[
      {3:                                                            }|
      {9:Error invoking 'test_method' on channel 1:}                  |
      {9:complete}                                                    |
      {9:error}                                                       |
                                                                  |
      {9:message}                                                     |
      {6:Press ENTER or type command to continue}^                     |
    ]],
      request_cb = function(name)
        if name == 'test_method' then
          set_method_error('complete\nerror\n\nmessage')
        end
      end,
    }
  end)

  it(':hi Group output', function()
    screen:try_resize(70, 7)
    feed(':hi ErrorMsg<cr>')
    screen:expect([[
                                                                            |
      {1:~                                                                     }|*2
      {3:                                                                      }|
      :hi ErrorMsg                                                          |
      ErrorMsg       {9:xxx} {18:ctermfg=}15 {18:ctermbg=}1 {18:guifg=}White {18:guibg=}Red         |
      {6:Press ENTER or type command to continue}^                               |
    ]])

    feed('<cr>')
    screen:try_resize(30, 7)
    feed(':hi ErrorMsg<cr>')
    screen:expect([[
      :hi ErrorMsg                  |
      ErrorMsg       {9:xxx} {18:ctermfg=}15 |
                         {18:ctermbg=}1  |
                         {18:guifg=}White|
                         {18:guibg=}Red  |
      {6:Press ENTER or type command to}|
      {6: continue}^                     |
    ]])
    feed('<cr>')

    -- screen size doesn't affect internal output #10285
    eq('ErrorMsg       xxx ctermfg=15 ctermbg=1 guifg=White guibg=Red', exec_capture('hi ErrorMsg'))
  end)

  it(':syntax list langGroup output', function()
    command('syntax on')
    exec([[
      syn match	vimComment	excludenl +\s"[^\-:.%#=*].*$+lc=1	contains=@vimCommentGroup,vimCommentString
      syn match	vimComment	+\<endif\s\+".*$+lc=5	contains=@vimCommentGroup,vimCommentString
      syn match	vimComment	+\<else\s\+".*$+lc=4	contains=@vimCommentGroup,vimCommentString
      hi link vimComment Comment
    ]])
    screen:try_resize(110, 7)
    feed(':syntax list vimComment<cr>')
    screen:expect([[
      {102:--- Syntax items ---}                                                                                          |
      vimComment     {18:xxx} {18:match} /\s"[^\-:.%#=*].*$/ms=s+1,lc=1  {18:excludenl} {18:contains}=@vimCommentGroup,vimCommentString |
                                                                                                                    |
                         {18:match} /\<endif\s\+".*$/ms=s+5,lc=5  {18:contains}=@vimCommentGroup,vimCommentString             |
                         {18:match} /\<else\s\+".*$/ms=s+4,lc=4  {18:contains}=@vimCommentGroup,vimCommentString              |
                         {18:links to} Comment                                                                           |
      {6:Press ENTER or type command to continue}^                                                                       |
    ]])

    feed('<cr>')
    screen:try_resize(55, 7)
    feed(':syntax list vimComment<cr>')
    screen:expect([[
                                                             |
                         {18:match} /\<endif\s\+".*$/ms=s+5,lc=5  |
      {18:contains}=@vimCommentGroup,vimCommentString             |
                         {18:match} /\<else\s\+".*$/ms=s+4,lc=4  {18:c}|
      {18:ontains}=@vimCommentGroup,vimCommentString              |
                         {18:links to} Comment                    |
      {6:Press ENTER or type command to continue}^                |
    ]])
    feed('<cr>')

    -- ignore final whitespace inside string
    -- luacheck: push ignore
    eq(
      [[--- Syntax items ---
vimComment     xxx match /\s"[^\-:.%#=*].*$/ms=s+1,lc=1  excludenl contains=@vimCommentGroup,vimCommentString 
                   match /\<endif\s\+".*$/ms=s+5,lc=5  contains=@vimCommentGroup,vimCommentString 
                   match /\<else\s\+".*$/ms=s+4,lc=4  contains=@vimCommentGroup,vimCommentString 
                   links to Comment]],
      exec_capture('syntax list vimComment')
    )
    -- luacheck: pop
  end)

  it('no empty line after :silent #12099', function()
    exec([[
      func T1()
        silent !echo
        echo "message T1"
      endfunc
      func T2()
        silent lua print("lua message")
        echo "message T2"
      endfunc
      func T3()
        silent call nvim_out_write("api message\n")
        echo "message T3"
      endfunc
    ]])
    feed(':call T1()<CR>')
    screen:expect {
      grid = [[
      ^                                                            |
      {1:~                                                           }|*5
      message T1                                                  |
    ]],
    }
    feed(':call T2()<CR>')
    screen:expect {
      grid = [[
      ^                                                            |
      {1:~                                                           }|*5
      message T2                                                  |
    ]],
    }
    feed(':call T3()<CR>')
    screen:expect {
      grid = [[
      ^                                                            |
      {1:~                                                           }|*5
      message T3                                                  |
    ]],
    }
  end)

  it('supports ruler with laststatus=0', function()
    command('set ruler laststatus=0')
    screen:expect {
      grid = [[
      ^                                                            |
      {1:~                                                           }|*5
                                                0,0-1         All |
    ]],
    }

    command('hi MsgArea guibg=#333333')
    screen:expect {
      grid = [[
      ^                                                            |
      {1:~                                                           }|*5
      {101:                                          0,0-1         All }|
    ]],
    }

    command('set rulerformat=%15(%c%V\\ %p%%%)')
    screen:expect {
      grid = [[
      ^                                                            |
      {1:~                                                           }|*5
      {101:                                          0,0-1 100%        }|
    ]],
    }
  end)

  it('supports echo with CRLF line separators', function()
    feed(':echo "line 1\\r\\nline 2"<cr>')
    screen:expect {
      grid = [[
                                                                  |
      {1:~                                                           }|*2
      {3:                                                            }|
      line 1                                                      |
      line 2                                                      |
      {6:Press ENTER or type command to continue}^                     |
    ]],
    }

    feed('<cr>:echo "abc\\rz"<cr>')
    screen:expect {
      grid = [[
      ^                                                            |
      {1:~                                                           }|*5
      zbc                                                         |
    ]],
    }
  end)

  it('redraws UPD_NOT_VALID correctly after message', function()
    -- edge case: only one window was set UPD_NOT_VALID. Original report
    -- used :make, but fake it using one command to set the current
    -- window UPD_NOT_VALID and another to show a long message.
    command('set more')
    feed(':new<cr><c-w><c-w>')
    screen:expect {
      grid = [[
                                                                  |
      {1:~                                                           }|
      {2:[No Name]                                                   }|
      ^                                                            |
      {1:~                                                           }|
      {3:[No Name]                                                   }|
      :new                                                        |
    ]],
    }

    feed(':set colorcolumn=10 | digraphs<cr>')
    screen:expect {
      grid = [[
      :set colorcolumn=10 | digraphs                              |
      NU {18:^@}  10    SH {18:^A}   1    SX {18:^B}   2    EX {18:^C}   3            |
      ET {18:^D}   4    EQ {18:^E}   5    AK {18:^F}   6    BL {18:^G}   7            |
      BS {18:^H}   8    HT {18:^I}   9    LF {18:^@}  10    VT {18:^K}  11            |
      FF {18:^L}  12    CR {18:^M}  13    SO {18:^N}  14    SI {18:^O}  15            |
      DL {18:^P}  16    D1 {18:^Q}  17    D2 {18:^R}  18    D3 {18:^S}  19            |
      {6:-- More --}^                                                  |
    ]],
    }

    feed('q')
    screen:expect {
      grid = [[
                                                                  |
      {1:~                                                           }|
      {2:[No Name]                                                   }|
      ^         {100: }                                                  |
      {1:~                                                           }|
      {3:[No Name]                                                   }|
                                                                  |
    ]],
    }

    -- edge case: just covers statusline
    feed(':set colorcolumn=5 | lua error("x\\n\\nx")<cr>')
    screen:expect {
      grid = [[
      {9:E5108: Error executing lua [string ":lua"]:1: x}             |
                                                                  |
      {9:x}                                                           |
      {9:stack traceback:}                                            |
      {9:        [C]: in function 'error'}                            |
      {9:        [string ":lua"]:1: in main chunk}                    |
      {6:Press ENTER or type command to continue}^                     |
    ]],
    }

    feed('<cr>')
    screen:expect {
      grid = [[
                                                                  |
      {1:~                                                           }|
      {2:[No Name]                                                   }|
      ^    {100: }                                                       |
      {1:~                                                           }|
      {3:[No Name]                                                   }|
                                                                  |
    ]],
    }

    -- edge case: just covers lowest window line
    feed(':set colorcolumn=5 | lua error("x\\n\\n\\nx")<cr>')
    screen:expect {
      grid = [[
      {9:E5108: Error executing lua [string ":lua"]:1: x}             |
                                                                  |*2
      {9:x}                                                           |
      {9:stack traceback:}                                            |
      {9:        [C]: in function 'error'}                            |
      {6:-- More --}^                                                  |
    ]],
    }

    feed('<cr>')
    screen:expect {
      grid = [[
                                                                  |*2
      {9:x}                                                           |
      {9:stack traceback:}                                            |
      {9:        [C]: in function 'error'}                            |
      {9:        [string ":lua"]:1: in main chunk}                    |
      {6:Press ENTER or type command to continue}^                     |
    ]],
    }
  end)

  it('supports nvim_echo messages with multiple attrs', function()
    async_meths.nvim_echo(
      { { 'wow, ', 'Search' }, { 'such\n\nvery ', 'ErrorMsg' }, { 'color', 'LineNr' } },
      true,
      {}
    )
    screen:expect {
      grid = [[
                                                                  |
      {1:~                                                           }|
      {3:                                                            }|
      {10:wow, }{9:such}                                                   |
                                                                  |
      {9:very }{8:color}                                                  |
      {6:Press ENTER or type command to continue}^                     |
    ]],
    }

    feed '<cr>'
    screen:expect {
      grid = [[
      ^                                                            |
      {1:~                                                           }|*5
                                                                  |
    ]],
    }

    feed ':messages<cr>'
    screen:expect {
      grid = [[
                                                                  |
      {1:~                                                           }|
      {3:                                                            }|
      {10:wow, }{9:such}                                                   |
                                                                  |
      {9:very }{8:color}                                                  |
      {6:Press ENTER or type command to continue}^                     |
    ]],
    }
  end)

  it('supports nvim_echo messages with emoji', function()
    -- stylua: ignore
    async_meths.nvim_echo(
      { { 'wow, 🏳️‍⚧️🧑‍🌾❤️😂🏴‍☠️\nvariant ❤️ one\nvariant ❤ two' } }, true, {}
    )

    screen:expect([[
                                                                  |
      {1:~                                                           }|
      {3:                                                            }|
      wow, 🏳️‍⚧️🧑‍🌾❤️😂🏴‍☠️                                             |
      variant ❤️ one                                              |
      variant ❤ two                                               |
      {6:Press ENTER or type command to continue}^                     |
    ]])

    feed '<cr>'
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*5
                                                                  |
    ]])

    feed ':messages<cr>'
    screen:expect([[
                                                                  |
      {1:~                                                           }|
      {3:                                                            }|
      wow, 🏳️‍⚧️🧑‍🌾❤️😂🏴‍☠️                                             |
      variant ❤️ one                                              |
      variant ❤ two                                               |
      {6:Press ENTER or type command to continue}^                     |
    ]])
  end)

  it('prints lines in Ex mode correctly with a burst of carriage returns #19341', function()
    command('set number')
    api.nvim_buf_set_lines(0, 0, 0, true, { 'aaa', 'bbb', 'ccc' })
    feed('gggQ<CR><CR>1<CR><CR>vi')
    screen:expect([[
      Entering Ex mode.  Type "visual" to go to Normal mode.      |
      {8:  2 }bbb                                                     |
      {8:  3 }ccc                                                     |
      :1                                                          |
      {8:  1 }aaa                                                     |
      {8:  2 }bbb                                                     |
      :vi^                                                         |
    ]])
    feed('<CR>')
    screen:expect([[
      {8:  1 }aaa                                                     |
      {8:  2 }^bbb                                                     |
      {8:  3 }ccc                                                     |
      {8:  4 }                                                        |
      {1:~                                                           }|*2
                                                                  |
    ]])
  end)

  describe('echo messages are shown when immediately followed by', function()
    --- @param to_block  string           command to cause a blocking wait
    --- @param to_unblock  number|string  number: timeout for blocking screen
    ---                                   string: keys to stop the blocking wait
    local function test_flush_before_block(to_block, to_unblock)
      local timeout = type(to_unblock) == 'number' and to_unblock or nil
      exec(([[
        func PrintAndWait()
          echon "aaa\nbbb"
          %s
          echon "\nccc"
        endfunc
      ]]):format(to_block))
      feed(':call PrintAndWait()')
      screen:expect([[
                                                                    |
        {1:~                                                           }|*5
        :call PrintAndWait()^                                        |
      ]])
      feed('<CR>')
      screen:expect {
        grid = [[
                                                                    |
        {1:~                                                           }|*3
        {3:                                                            }|
        aaa                                                         |
        bbb^                                                         |
      ]],
        timeout = timeout,
      }
      if type(to_unblock) == 'string' then
        feed(to_unblock)
      end
      screen:expect {
        grid = [[
                                                                    |
        {1:~                                                           }|
        {3:                                                            }|
        aaa                                                         |
        bbb                                                         |
        ccc                                                         |
        {6:Press ENTER or type command to continue}^                     |
      ]],
      }
    end

    it('getchar()', function()
      test_flush_before_block([[call getchar()]], 'k')
    end)

    it('wait()', function()
      test_flush_before_block([[call wait(300, '0')]], 100)
    end)

    it('lua vim.wait()', function()
      test_flush_before_block([[lua vim.wait(300, function() end)]], 100)
    end)
  end)

  it('consecutive calls to win_move_statusline() work after multiline message #21014', function()
    async_meths.nvim_exec(
      [[
      echo "\n"
      call win_move_statusline(0, -4)
      call win_move_statusline(0, 4)
    ]],
      false
    )
    screen:expect([[
                                                                  |
      {1:~                                                           }|*3
      {3:                                                            }|
                                                                  |
      {6:Press ENTER or type command to continue}^                     |
    ]])
    feed('<CR>')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*5
                                                                  |
    ]])
    eq(1, api.nvim_get_option_value('cmdheight', {}))
  end)

  it('using nvim_echo in VimResized does not cause hit-enter prompt #26139', function()
    command([[au VimResized * lua vim.api.nvim_echo({ { '123456' } }, true, {})]])
    screen:try_resize(60, 5)
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*3
                                                                  |
    ]])
    eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
  end)

  it('bottom of screen is cleared after increasing &cmdheight #20360', function()
    command('set laststatus=2')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*4
      {3:[No Name]                                                   }|
                                                                  |
    ]])
    command('set cmdheight=4')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|
      {3:[No Name]                                                   }|
                                                                  |*4
    ]])
  end)

  it('supports :intro with cmdheight=0 #26505', function()
    screen:try_resize(80, 24)
    command('set cmdheight=0')
    feed(':intro<CR>')
    screen:expect([[
                                                                                      |*5
      {MATCH:.*}|
                                                                                      |
                        Nvim is open source and freely distributable                  |
                                  https://neovim.io/#chat                             |
                                                                                      |
                       type  :help nvim{18:<Enter>}       if you are new!                  |
                       type  :checkhealth{18:<Enter>}     to optimize Nvim                 |
                       type  :q{18:<Enter>}               to exit                          |
                       type  :help{18:<Enter>}            for help                         |
                                                                                      |
      {MATCH: +}type  :help news{18:<Enter>} to see changes in v{MATCH:%d+%.%d+ +}|
                                                                                      |
                               Help poor children in Uganda!                          |
                       type  :help iccf{18:<Enter>}       for information                  |
                                                                                      |*2
      {3:                                                                                }|
                                                                                      |
      {6:Press ENTER or type command to continue}^                                         |
    ]])
    feed('<CR>')
    assert_alive()
  end)
end)

it('calling screenstring() after redrawing between messages without UI #20999', function()
  clear()
  exec([[
    echo repeat('a', 100)
    redraw
    echo "\n"
    call screenstring(1, 1)
  ]])
  assert_alive()
end)

describe('ui/ext_messages', function()
  local screen

  before_each(function()
    clear { args_rm = { '--headless' }, args = { '--cmd', 'set shortmess-=I' } }
    screen = Screen.new(80, 24, { rgb = true, ext_messages = true, ext_popupmenu = true })
  end)

  it('supports intro screen', function()
    -- intro message is not externalized. But check that it still works.
    -- Note parts of it depends on version or is indeterministic. We ignore those parts.
    local introscreen = [[
      ^                                                                                |
      {1:~                                                                               }|*4
      {MATCH:.*}|
      {1:~                                                                               }|
      {1:~                 }Nvim is open source and freely distributable{1:                  }|
      {1:~                           }https://neovim.io/#chat{1:                             }|
      {1:~                                                                               }|
      {1:~                }type  :help nvim{18:<Enter>}       if you are new! {1:                 }|
      {1:~                }type  :checkhealth{18:<Enter>}     to optimize Nvim{1:                 }|
      {1:~                }type  :q{18:<Enter>}               to exit         {1:                 }|
      {1:~                }type  :help{18:<Enter>}            for help        {1:                 }|
      {1:~                                                                               }|
      {1:~{MATCH: +}}type  :help news{18:<Enter>} to see changes in v{MATCH:%d+%.%d+}{1:{MATCH: +}}|
      {1:~                                                                               }|
      {1:~                        }Help poor children in Uganda!{1:                          }|
      {1:~                }type  :help iccf{18:<Enter>}       for information {1:                 }|
      {1:~                                                                               }|*5
    ]]
    local showmode = { { '-- INSERT --', 5, 11 } }
    screen:expect(introscreen)

    -- <c-l> (same as :mode) does _not_ clear intro message
    feed('<c-l>i')
    screen:expect { grid = introscreen, showmode = showmode }

    -- opening a float without focus also does not
    local win = api.nvim_open_win(api.nvim_create_buf(false, false), false, {
      relative = 'editor',
      height = 1,
      width = 5,
      row = 1,
      col = 5,
    })
    screen:expect {
      grid = [[
      ^                                                                                |
      {1:~    }{4:     }{1:                                                                      }|
      {1:~                                                                               }|*3
      {MATCH:.*}|
      {1:~                                                                               }|
      {1:~                 }Nvim is open source and freely distributable{1:                  }|
      {1:~                           }https://neovim.io/#chat{1:                             }|
      {1:~                                                                               }|
      {1:~                }type  :help nvim{18:<Enter>}       if you are new! {1:                 }|
      {1:~                }type  :checkhealth{18:<Enter>}     to optimize Nvim{1:                 }|
      {1:~                }type  :q{18:<Enter>}               to exit         {1:                 }|
      {1:~                }type  :help{18:<Enter>}            for help        {1:                 }|
      {1:~                                                                               }|
      {1:~{MATCH: +}}type  :help news{18:<Enter>} to see changes in v{MATCH:%d+%.%d+}{1:{MATCH: +}}|
      {1:~                                                                               }|
      {1:~                        }Help poor children in Uganda!{1:                          }|
      {1:~                }type  :help iccf{18:<Enter>}       for information {1:                 }|
      {1:~                                                                               }|*5
    ]],
      showmode = showmode,
    }

    api.nvim_win_close(win, true)
    screen:expect { grid = introscreen, showmode = showmode }

    -- but editing text does..
    feed('x')
    screen:expect {
      grid = [[
      x^                                                                               |
      {1:~                                                                               }|*23
    ]],
      showmode = showmode,
    }

    feed('<esc>:intro<cr>')
    screen:expect {
      grid = [[
      ^                                                                                |
                                                                                      |*4
      {MATCH:.*}|
                                                                                      |
                        Nvim is open source and freely distributable                  |
                                  https://neovim.io/#chat                             |
                                                                                      |
                       type  :help nvim{18:<Enter>}       if you are new!                  |
                       type  :checkhealth{18:<Enter>}     to optimize Nvim                 |
                       type  :q{18:<Enter>}               to exit                          |
                       type  :help{18:<Enter>}            for help                         |
                                                                                      |
      {MATCH: +}type  :help news{18:<Enter>} to see changes in v{MATCH:%d+%.%d+ +}|
                                                                                      |
                               Help poor children in Uganda!                          |
                       type  :help iccf{18:<Enter>}       for information                  |
                                                                                      |*5
    ]],
      cmdline = { { abort = false } },
      messages = {
        {
          content = { { 'Press ENTER or type command to continue', 6, 18 } },
          history = false,
          kind = 'return_prompt',
        },
      },
    }

    feed('<cr>')
    screen:expect {
      grid = [[
      ^x                                                                               |
      {1:~                                                                               }|*23
    ]],
    }
  end)

  it('clears intro screen when new buffer is active', function()
    api.nvim_set_current_buf(api.nvim_create_buf(true, false))
    screen:expect {
      grid = [[
      ^                                                                                |
      {1:~                                                                               }|*23
    ]],
    }
  end)

  it('clears intro screen when new buffer is active in floating window', function()
    local win_opts = { relative = 'editor', height = 1, width = 5, row = 1, col = 5 }
    api.nvim_open_win(api.nvim_create_buf(false, false), true, win_opts)
    screen:expect {
      grid = [[
                                                                                      |
      {1:~    }{4:^     }{1:                                                                      }|
      {1:~                                                                               }|*22
    ]],
    }
  end)

  it('clears intro screen when initial buffer is active in floating window', function()
    local win_opts = { relative = 'editor', height = 1, width = 5, row = 1, col = 5 }
    api.nvim_open_win(api.nvim_get_current_buf(), true, win_opts)
    screen:expect {
      grid = [[
                                                                                      |
      {1:~    }{4:^     }{1:                                                                      }|
      {1:~                                                                               }|*22
    ]],
    }
  end)

  it('clears intro screen when initial window is converted to be floating', function()
    exec_lua([[
      local init_win_id = vim.api.nvim_get_current_win()
      vim.cmd('split')
      local win_opts = { relative = 'editor', height = 1, width = 5, row = 1, col = 5 }
      vim.api.nvim_win_set_config(init_win_id, win_opts)
      vim.api.nvim_set_current_win(init_win_id)
    ]])
    screen:expect {
      grid = [[
                                                                                      |
      {1:~    }{4:^     }{1:                                                                      }|
      {1:~                                                                               }|*21
      {2:[No Name]                                                                       }|
    ]],
    }
  end)

  it('supports global statusline', function()
    feed(':set laststatus=3<cr>')
    feed(':sp<cr>')
    feed(':set cmdheight<cr>')
    screen:expect({
      grid = [[
      ^                                                                                |
      {1:~                                                                               }|*10
      ────────────────────────────────────────────────────────────────────────────────|
                                                                                      |
      {1:~                                                                               }|*10
      {3:[No Name]                                                                       }|
    ]],
      cmdline = { { abort = false } },
      messages = {
        { content = { { '  cmdheight=0' } }, kind = 'list_cmd', history = false },
      },
    })

    feed('<c-w>+')
    feed(':set laststatus<cr>')
    screen:expect({
      grid = [[
      ^                                                                                |
      {1:~                                                                               }|*11
      ────────────────────────────────────────────────────────────────────────────────|
                                                                                      |
      {1:~                                                                               }|*9
      {3:[No Name]                                                                       }|
    ]],
      cmdline = { { abort = false } },
      messages = {
        { content = { { '  laststatus=3' } }, kind = 'list_cmd', history = false },
      },
    })

    feed(':set mouse=a<cr>')
    api.nvim_input_mouse('left', 'press', '', 0, 12, 10)
    poke_eventloop()
    api.nvim_input_mouse('left', 'drag', '', 0, 11, 10)
    feed('<c-l>')
    feed(':set cmdheight<cr>')
    screen:expect({
      grid = [[
      ^                                                                                |
      {1:~                                                                               }|*10
      ────────────────────────────────────────────────────────────────────────────────|
                                                                                      |
      {1:~                                                                               }|*10
      {3:[No Name]                                                                       }|
    ]],
      cmdline = { { abort = false } },
      messages = {
        { content = { { '  cmdheight=0' } }, kind = 'list_cmd', history = false },
      },
    })
  end)
end)

it('ui/ext_multigrid supports intro screen', function()
  clear { args_rm = { '--headless' }, args = { '--cmd', 'set shortmess-=I' } }
  local screen = Screen.new(80, 24, { rgb = true, ext_multigrid = true })

  screen:expect {
    grid = [[
    ## grid 1
      [2:--------------------------------------------------------------------------------]|*23
      [3:--------------------------------------------------------------------------------]|
    ## grid 2
      ^                                                                                |
      {1:~                                                                               }|*4
      {MATCH:.*}|
      {1:~                                                                               }|
      {1:~                 }Nvim is open source and freely distributable{1:                  }|
      {1:~                           }https://neovim.io/#chat{1:                             }|
      {1:~                                                                               }|
      {1:~                }type  :help nvim{18:<Enter>}       if you are new! {1:                 }|
      {1:~                }type  :checkhealth{18:<Enter>}     to optimize Nvim{1:                 }|
      {1:~                }type  :q{18:<Enter>}               to exit         {1:                 }|
      {1:~                }type  :help{18:<Enter>}            for help        {1:                 }|
      {1:~                                                                               }|
      {1:~{MATCH: +}}type  :help news{18:<Enter>} to see changes in v{MATCH:%d+%.%d+}{1:{MATCH: +}}|
      {1:~                                                                               }|
      {1:~                        }Help poor children in Uganda!{1:                          }|
      {1:~                }type  :help iccf{18:<Enter>}       for information {1:                 }|
      {1:~                                                                               }|*4
    ## grid 3
                                                                                      |
    ]],
    win_viewport = {
      [2] = {
        win = 1000,
        topline = 0,
        botline = 2,
        curline = 0,
        curcol = 0,
        linecount = 1,
        sum_scroll_delta = 0,
      },
    },
  }

  feed 'ix'
  screen:expect {
    grid = [[
    ## grid 1
      [2:--------------------------------------------------------------------------------]|*23
      [3:--------------------------------------------------------------------------------]|
    ## grid 2
      x^                                                                               |
      {1:~                                                                               }|*22
    ## grid 3
      {5:-- INSERT --}                                                                    |
    ]],
    win_viewport = {
      [2] = {
        win = 1000,
        topline = 0,
        botline = 2,
        curline = 0,
        curcol = 1,
        linecount = 1,
        sum_scroll_delta = 0,
      },
    },
  }
end)

describe('ui/msg_puts_printf', function()
  it('output multibyte characters correctly', function()
    skip(not t.translations_enabled(), 'Nvim not built with ENABLE_TRANSLATIONS')
    local screen
    local cmd = ''
    local locale_dir = test_build_dir .. '/share/locale/ja/LC_MESSAGES'

    clear({ env = { LANG = 'ja_JP.UTF-8' } })
    screen = Screen.new(25, 5)

    if is_os('win') then
      if os.execute('chcp 932 > NUL 2>&1') ~= 0 then
        pending('missing japanese language features', function() end)
        return
      else
        cmd = 'chcp 932 > NUL & '
      end
    else
      if exc_exec('lang ja_JP.UTF-8') ~= 0 then
        pending('Locale ja_JP.UTF-8 not supported', function() end)
        return
      end
    end

    os.execute('cmake -E make_directory ' .. locale_dir)
    os.execute(
      'cmake -E copy ' .. test_build_dir .. '/src/nvim/po/ja.mo ' .. locale_dir .. '/nvim.mo'
    )

    cmd = cmd .. '"' .. nvim_prog .. '" -u NONE -i NONE -Es -V1'
    command([[call jobstart(']] .. cmd .. [[',{'term':v:true})]])
    screen:expect([[
    ^Exモードに入ります。ノー |
    マルモードに戻るには "vis|
    ual" と入力してください。|
    :                        |
                             |
    ]])

    os.execute('cmake -E remove_directory ' .. test_build_dir .. '/share')
  end)
end)

describe('pager', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(35, 8)
    screen:set_default_attr_ids({
      [1] = { bold = true, foreground = Screen.colors.Blue1 },
      [2] = { foreground = Screen.colors.Grey100, background = Screen.colors.Red },
      [3] = {
        foreground = Screen.colors.Grey100,
        background = Screen.colors.Red,
        special = Screen.colors.Yellow,
      },
      [4] = { bold = true, foreground = Screen.colors.SeaGreen4 },
      [5] = { special = Screen.colors.Yellow },
      [6] = { special = Screen.colors.Yellow, bold = true, foreground = Screen.colors.SeaGreen4 },
      [7] = { foreground = Screen.colors.Grey0, background = Screen.colors.Grey100 },
      [8] = { foreground = Screen.colors.Gray90, background = Screen.colors.Grey100 },
      [9] = { foreground = tonumber('0x00000c'), background = Screen.colors.Grey100 },
      [10] = { background = Screen.colors.Grey100, bold = true, foreground = tonumber('0xe5e5ff') },
      [11] = { background = Screen.colors.Grey100, bold = true, foreground = tonumber('0x2b8452') },
      [12] = { bold = true, reverse = true },
    })
    command('set more')

    exec_lua(
      '_G.x = ...',
      [[
Lorem ipsum dolor sit amet, consectetur
adipisicing elit, sed do eiusmod tempor
incididunt ut labore et dolore magna aliqua.
Ut enim ad minim veniam, quis nostrud xercitation
ullamco laboris nisi ut
aliquip ex ea commodo consequat.]]
    )
  end)

  it('can be quit with echon', function()
    screen:try_resize(25, 5)
    feed(':echon join(map(range(0, &lines*10), "v:val"), "\\n")<cr>')
    screen:expect {
      grid = [[
      0                        |
      1                        |
      2                        |
      3                        |
      {4:-- More --}^               |
    ]],
    }
    feed('q')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*3
                               |
    ]],
    }
  end)

  it('can be quit with Lua #11224 #16537', function()
    screen:try_resize(40, 5)
    feed(':lua for i=0,10 do print(i) end<cr>')
    screen:expect {
      grid = [[
      0                                       |
      1                                       |
      2                                       |
      3                                       |
      {4:-- More --}^                              |
    ]],
    }
    feed('q')
    screen:expect {
      grid = [[
      ^                                        |
      {1:~                                       }|*3
                                              |
    ]],
    }
    feed(':mess<cr>')
    screen:expect {
      grid = [[
      0                                       |
      1                                       |
      2                                       |
      3                                       |
      {4:-- More --}^                              |
    ]],
    }
    feed('G')
    screen:expect {
      grid = [[
      7                                       |
      8                                       |
      9                                       |
      10                                      |
      {4:Press ENTER or type command to continue}^ |
    ]],
    }
    feed('<cr>')
  end)

  it('handles wrapped lines with line scroll', function()
    feed(':lua error(_G.x)<cr>')
    screen:expect {
      grid = [[
      {2:E5108: Error executing lua [string }|
      {2:":lua"]:1: Lorem ipsum dolor sit am}|
      {2:et, consectetur}                    |
      {2:adipisicing elit, sed do eiusmod te}|
      {2:mpor}                               |
      {2:incididunt ut labore et dolore magn}|
      {2:a aliqua.}                          |
      {4:-- More --}^                         |
    ]],
    }

    feed('j')
    screen:expect {
      grid = [[
      {2:":lua"]:1: Lorem ipsum dolor sit am}|
      {2:et, consectetur}                    |
      {2:adipisicing elit, sed do eiusmod te}|
      {2:mpor}                               |
      {2:incididunt ut labore et dolore magn}|
      {2:a aliqua.}                          |
      {2:Ut enim ad minim veniam, quis nostr}|
      {4:-- More --}^                         |
    ]],
    }

    feed('k')
    screen:expect {
      grid = [[
      {2:E5108: Error executing lua [string }|
      {2:":lua"]:1: Lorem ipsum dolor sit am}|
      {2:et, consectetur}                    |
      {2:adipisicing elit, sed do eiusmod te}|
      {2:mpor}                               |
      {2:incididunt ut labore et dolore magn}|
      {2:a aliqua.}                          |
      {4:-- More --}^                         |
    ]],
    }

    feed('j')
    screen:expect {
      grid = [[
      {2:":lua"]:1: Lorem ipsum dolor sit am}|
      {2:et, consectetur}                    |
      {2:adipisicing elit, sed do eiusmod te}|
      {2:mpor}                               |
      {2:incididunt ut labore et dolore magn}|
      {2:a aliqua.}                          |
      {2:Ut enim ad minim veniam, quis nostr}|
      {4:-- More --}^                         |
    ]],
    }
  end)

  it('handles wrapped lines with page scroll', function()
    feed(':lua error(_G.x)<cr>')
    screen:expect {
      grid = [[
      {2:E5108: Error executing lua [string }|
      {2:":lua"]:1: Lorem ipsum dolor sit am}|
      {2:et, consectetur}                    |
      {2:adipisicing elit, sed do eiusmod te}|
      {2:mpor}                               |
      {2:incididunt ut labore et dolore magn}|
      {2:a aliqua.}                          |
      {4:-- More --}^                         |
    ]],
    }
    feed('d')
    screen:expect {
      grid = [[
      {2:mpor}                               |
      {2:incididunt ut labore et dolore magn}|
      {2:a aliqua.}                          |
      {2:Ut enim ad minim veniam, quis nostr}|
      {2:ud xercitation}                     |
      {2:ullamco laboris nisi ut}            |
      {2:aliquip ex ea commodo consequat.}   |
      {4:-- More --}^                         |
    ]],
    }
    feed('u')
    screen:expect {
      grid = [[
      {2:E5108: Error executing lua [string }|
      {2:":lua"]:1: Lorem ipsum dolor sit am}|
      {2:et, consectetur}                    |
      {2:adipisicing elit, sed do eiusmod te}|
      {2:mpor}                               |
      {2:incididunt ut labore et dolore magn}|
      {2:a aliqua.}                          |
      {4:-- More --}^                         |
    ]],
    }
    feed('d')
    screen:expect {
      grid = [[
      {2:mpor}                               |
      {2:incididunt ut labore et dolore magn}|
      {2:a aliqua.}                          |
      {2:Ut enim ad minim veniam, quis nostr}|
      {2:ud xercitation}                     |
      {2:ullamco laboris nisi ut}            |
      {2:aliquip ex ea commodo consequat.}   |
      {4:-- More --}^                         |
    ]],
    }
  end)

  it('handles wrapped lines with line scroll and MsgArea highlight', function()
    command('hi MsgArea guisp=Yellow')

    feed(':lua error(_G.x)<cr>')
    screen:expect {
      grid = [[
      {3:E5108: Error executing lua [string }|
      {3:":lua"]:1: Lorem ipsum dolor sit am}|
      {3:et, consectetur}{5:                    }|
      {3:adipisicing elit, sed do eiusmod te}|
      {3:mpor}{5:                               }|
      {3:incididunt ut labore et dolore magn}|
      {3:a aliqua.}{5:                          }|
      {6:-- More --}{5:^                         }|
    ]],
    }

    feed('j')
    screen:expect {
      grid = [[
      {3:":lua"]:1: Lorem ipsum dolor sit am}|
      {3:et, consectetur}{5:                    }|
      {3:adipisicing elit, sed do eiusmod te}|
      {3:mpor}{5:                               }|
      {3:incididunt ut labore et dolore magn}|
      {3:a aliqua.}{5:                          }|
      {3:Ut enim ad minim veniam, quis nostr}|
      {6:-- More --}{5:^                         }|
    ]],
    }

    feed('k')
    screen:expect {
      grid = [[
      {3:E5108: Error executing lua [string }|
      {3:":lua"]:1: Lorem ipsum dolor sit am}|
      {3:et, consectetur}{5:                    }|
      {3:adipisicing elit, sed do eiusmod te}|
      {3:mpor}{5:                               }|
      {3:incididunt ut labore et dolore magn}|
      {3:a aliqua.}{5:                          }|
      {6:-- More --}{5:^                         }|
    ]],
    }

    feed('j')
    screen:expect {
      grid = [[
      {3:":lua"]:1: Lorem ipsum dolor sit am}|
      {3:et, consectetur}{5:                    }|
      {3:adipisicing elit, sed do eiusmod te}|
      {3:mpor}{5:                               }|
      {3:incididunt ut labore et dolore magn}|
      {3:a aliqua.}{5:                          }|
      {3:Ut enim ad minim veniam, quis nostr}|
      {6:-- More --}{5:^                         }|
    ]],
    }
  end)

  it('handles wrapped lines with page scroll and MsgArea highlight', function()
    command('hi MsgArea guisp=Yellow')
    feed(':lua error(_G.x)<cr>')
    screen:expect {
      grid = [[
      {3:E5108: Error executing lua [string }|
      {3:":lua"]:1: Lorem ipsum dolor sit am}|
      {3:et, consectetur}{5:                    }|
      {3:adipisicing elit, sed do eiusmod te}|
      {3:mpor}{5:                               }|
      {3:incididunt ut labore et dolore magn}|
      {3:a aliqua.}{5:                          }|
      {6:-- More --}{5:^                         }|
    ]],
    }
    feed('d')
    screen:expect {
      grid = [[
      {3:mpor}{5:                               }|
      {3:incididunt ut labore et dolore magn}|
      {3:a aliqua.}{5:                          }|
      {3:Ut enim ad minim veniam, quis nostr}|
      {3:ud xercitation}{5:                     }|
      {3:ullamco laboris nisi ut}{5:            }|
      {3:aliquip ex ea commodo consequat.}{5:   }|
      {6:-- More --}{5:^                         }|
    ]],
    }
    feed('u')
    screen:expect {
      grid = [[
      {3:E5108: Error executing lua [string }|
      {3:":lua"]:1: Lorem ipsum dolor sit am}|
      {3:et, consectetur}{5:                    }|
      {3:adipisicing elit, sed do eiusmod te}|
      {3:mpor}{5:                               }|
      {3:incididunt ut labore et dolore magn}|
      {3:a aliqua.}{5:                          }|
      {6:-- More --}{5:^                         }|
    ]],
    }
    feed('d')
    screen:expect {
      grid = [[
      {3:mpor}{5:                               }|
      {3:incididunt ut labore et dolore magn}|
      {3:a aliqua.}{5:                          }|
      {3:Ut enim ad minim veniam, quis nostr}|
      {3:ud xercitation}{5:                     }|
      {3:ullamco laboris nisi ut}{5:            }|
      {3:aliquip ex ea commodo consequat.}{5:   }|
      {6:-- More --}{5:^                         }|
    ]],
    }
  end)

  it('preserves MsgArea highlighting after more prompt', function()
    screen:try_resize(70, 6)
    command('hi MsgArea guisp=Yellow')
    command('map x Lorem ipsum labore et dolore magna aliqua')
    command('map y adipisicing elit')
    command('map z incididunt ut')
    command('map a labore et dolore')
    command('map b ex ea commodo')
    command('map xx yy')
    command('map xy yz')
    feed(':map<cr>')
    screen:expect {
      grid = [[
      {5:   a             labore et dolore                                     }|
      {5:   b             ex ea commodo                                        }|
      {5:   xy            yz                                                   }|
      {5:   xx            yy                                                   }|
      {5:   x             Lorem ipsum labore et dolore magna aliqua            }|
      {6:-- More --}{5:^                                                            }|
    ]],
    }
    feed('j')
    screen:expect {
      grid = [[
      {5:   b             ex ea commodo                                        }|
      {5:   xy            yz                                                   }|
      {5:   xx            yy                                                   }|
      {5:   x             Lorem ipsum labore et dolore magna aliqua            }|
      {5:   y             adipisicing elit                                     }|
      {6:-- More --}{5:^                                                            }|
    ]],
    }
    feed('j')
    screen:expect {
      grid = [[
      {5:   xy            yz                                                   }|
      {5:   xx            yy                                                   }|
      {5:   x             Lorem ipsum labore et dolore magna aliqua            }|
      {5:   y             adipisicing elit                                     }|
      {5:   z             incididunt ut                                        }|
      {6:Press ENTER or type command to continue}{5:^                               }|
    ]],
    }
  end)

  it('clears "-- more --" message', function()
    command('hi MsgArea guisp=Yellow blend=10')
    feed(':echon join(range(20), "\\n")<cr>')
    screen:expect {
      grid = [[
      {7:0}{8:                                  }|
      {9:1}{10:                                  }|
      {9:2}{10:                                  }|
      {9:3}{10:                                  }|
      {9:4}{10:                                  }|
      {9:5}{10:                                  }|
      {9:6}{10:                                  }|
      {11:--}{8: }{11:More}{8: }{11:--}{8:^                         }|
    ]],
    }

    feed('j')
    screen:expect {
      grid = [[
      {7:1}{8:                                  }|
      {9:2}{10:                                  }|
      {9:3}{10:                                  }|
      {9:4}{10:                                  }|
      {9:5}{10:                                  }|
      {9:6}{10:                                  }|
      {9:7}{10:                                  }|
      {11:--}{8: }{11:More}{8: }{11:--}{8:^                         }|
    ]],
    }

    feed('k')
    screen:expect {
      grid = [[
      {7:0}{8:                                  }|
      {9:1}{10:                                  }|
      {9:2}{10:                                  }|
      {9:3}{10:                                  }|
      {9:4}{10:                                  }|
      {9:5}{10:                                  }|
      {9:6}{10:                                  }|
      {11:--}{8: }{11:More}{8: }{11:--}{8:^                         }|
    ]],
    }

    feed('j')
    screen:expect {
      grid = [[
      {7:1}{8:                                  }|
      {9:2}{10:                                  }|
      {9:3}{10:                                  }|
      {9:4}{10:                                  }|
      {9:5}{10:                                  }|
      {9:6}{10:                                  }|
      {9:7}{10:                                  }|
      {11:--}{8: }{11:More}{8: }{11:--}{8:^                         }|
    ]],
    }
  end)

  it('with :!cmd does not crash on resize', function()
    skip(fn.executable('sleep') == 0, 'missing "sleep" command')
    feed(':!sleep 1<cr>')
    screen:expect {
      grid = [[
                                         |
      {1:~                                  }|*4
      {12:                                   }|
      :!sleep 1                          |
                                         |
    ]],
    }

    -- not processed while command is executing
    async_meths.nvim_ui_try_resize(35, 5)

    -- TODO(bfredl): ideally it should be processed just
    -- before the "press ENTER" prompt though
    screen:expect {
      grid = [[
                                         |
      {1:~                                  }|*2
      {12:                                   }|
      :!sleep 1                          |
                                         |
      {4:Press ENTER or type command to cont}|
      {4:inue}^                               |
    ]],
    }

    feed('<cr>')
    screen:expect {
      grid = [[
      ^                                   |
      {1:~                                  }|*3
                                         |
    ]],
    }
  end)

  it('can be resized', function()
    feed(':lua error(_G.x)<cr>')
    screen:expect {
      grid = [[
      {2:E5108: Error executing lua [string }|
      {2:":lua"]:1: Lorem ipsum dolor sit am}|
      {2:et, consectetur}                    |
      {2:adipisicing elit, sed do eiusmod te}|
      {2:mpor}                               |
      {2:incididunt ut labore et dolore magn}|
      {2:a aliqua.}                          |
      {4:-- More --}^                         |
    ]],
    }

    -- responds to resize, but text is not reflown
    screen:try_resize(45, 5)
    screen:expect {
      grid = [[
      {2:adipisicing elit, sed do eiusmod te}          |
      {2:mpor}                                         |
      {2:incididunt ut labore et dolore magn}          |
      {2:a aliqua.}                                    |
      {4:-- More --}^                                   |
    ]],
    }

    -- can create empty space, as the command hasn't output the text below yet.
    -- text is not reflown; existing lines get cut
    screen:try_resize(30, 12)
    screen:expect {
      grid = [[
      :lua error(_G.x)              |
      {2:E5108: Error executing lua [st}|
      {2:":lua"]:1: Lorem ipsum dolor s}|
      {2:et, consectetur}               |
      {2:adipisicing elit, sed do eiusm}|
      {2:mpore}                         |
      {2:incididunt ut labore et dolore}|
      {2:a aliqua.}                     |
                                    |*3
      {4:-- More --}^                    |
    ]],
    }

    -- continues in a mostly consistent state, but only new lines are
    -- wrapped at the new screen size.
    feed('<cr>')
    screen:expect {
      grid = [[
      {2:E5108: Error executing lua [st}|
      {2:":lua"]:1: Lorem ipsum dolor s}|
      {2:et, consectetur}               |
      {2:adipisicing elit, sed do eiusm}|
      {2:mpore}                         |
      {2:incididunt ut labore et dolore}|
      {2:a aliqua.}                     |
      {2:Ut enim ad minim veniam, quis }|
      {2:nostrud xercitation}           |
      {2:ullamco laboris nisi ut}       |
      {2:aliquip ex ea commodo consequa}|
      {4:-- More --}^                    |
    ]],
    }

    feed('<cr>')
    screen:expect {
      grid = [[
      {2:":lua"]:1: Lorem ipsum dolor s}|
      {2:et, consectetur}               |
      {2:adipisicing elit, sed do eiusm}|
      {2:mpore}                         |
      {2:incididunt ut labore et dolore}|
      {2:a aliqua.}                     |
      {2:Ut enim ad minim veniam, quis }|
      {2:nostrud xercitation}           |
      {2:ullamco laboris nisi ut}       |
      {2:aliquip ex ea commodo consequa}|
      {2:t.}                            |
      {4:-- More --}^                    |
    ]],
    }

    feed('q')
    screen:expect {
      grid = [[
      ^                              |
      {1:~                             }|*10
                                    |
    ]],
    }
  end)

  it('with cmdheight=0 does not crash with g<', function()
    command('set cmdheight=0')
    feed(':ls<cr>')
    screen:expect {
      grid = [[
                                         |
      {1:~                                  }|
      {12:                                   }|
      :ls                                |
        1 %a   "[No Name]"               |
           line 1                        |
      {4:Press ENTER or type command to cont}|
      {4:inue}^                               |
    ]],
    }

    feed('<cr>')
    screen:expect {
      grid = [[
      ^                                   |
      {1:~                                  }|*7
    ]],
    }

    feed('g<lt>')
    screen:expect {
      grid = [[
                                         |
      {1:~                                  }|
      {12:                                   }|
      :ls                                |
        1 %a   "[No Name]"               |
           line 1                        |
      {4:Press ENTER or type command to cont}|
      {4:inue}^                               |
    ]],
    }

    feed('<cr>')
    screen:expect {
      grid = [[
      ^                                   |
      {1:~                                  }|*7
    ]],
    }
  end)

  it('g< shows blank line from :echo properly', function()
    screen:try_resize(60, 8)
    feed([[:echo 1 | echo "\n" | echo 2<CR>]])
    screen:expect([[
                                                                  |
      {1:~                                                           }|*2
      {12:                                                            }|
      1                                                           |
                                                                  |
      2                                                           |
      {4:Press ENTER or type command to continue}^                     |
    ]])

    feed('<CR>')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*6
                                                                  |
    ]])

    feed('g<lt>')
    screen:expect([[
                                                                  |
      {1:~                                                           }|
      {12:                                                            }|
      :echo 1 | echo "\n" | echo 2                                |
      1                                                           |
                                                                  |
      2                                                           |
      {4:Press ENTER or type command to continue}^                     |
    ]])

    feed('<CR>')
    screen:expect([[
      ^                                                            |
      {1:~                                                           }|*6
                                                                  |
    ]])
  end)

  it('scrolling works properly when :echo output ends with newline', function()
    screen:try_resize(60, 6)
    feed([[:echo range(100)->join("\n") .. "\n"<CR>]])
    screen:expect([[
      0                                                           |
      1                                                           |
      2                                                           |
      3                                                           |
      4                                                           |
      {4:-- More --}^                                                  |
    ]])
    feed('G')
    screen:expect([[
      96                                                          |
      97                                                          |
      98                                                          |
      99                                                          |
                                                                  |
      {4:Press ENTER or type command to continue}^                     |
    ]])
    for _ = 1, 3 do
      feed('k')
      screen:expect([[
        95                                                          |
        96                                                          |
        97                                                          |
        98                                                          |
        99                                                          |
        {4:-- More --}^                                                  |
      ]])
      feed('k')
      screen:expect([[
        94                                                          |
        95                                                          |
        96                                                          |
        97                                                          |
        98                                                          |
        {4:-- More --}^                                                  |
      ]])
      feed('j')
      screen:expect([[
        95                                                          |
        96                                                          |
        97                                                          |
        98                                                          |
        99                                                          |
        {4:-- More --}^                                                  |
      ]])
      feed('j')
      screen:expect([[
        96                                                          |
        97                                                          |
        98                                                          |
        99                                                          |
                                                                    |
        {4:-- More --}^                                                  |
      ]])
      feed('j')
      screen:expect([[
        96                                                          |
        97                                                          |
        98                                                          |
        99                                                          |
                                                                    |
        {4:Press ENTER or type command to continue}^                     |
      ]])
    end
  end)

  it('scrolling works properly when :!cmd output ends with newline #27902', function()
    screen:try_resize(60, 6)
    api.nvim_set_option_value('shell', testprg('shell-test'), {})
    api.nvim_set_option_value('shellcmdflag', 'REP 100', {})
    api.nvim_set_option_value('shellxquote', '', {}) -- win: avoid extra quotes
    feed([[:!foo<CR>]])
    screen:expect([[
      96: foo                                                     |
      97: foo                                                     |
      98: foo                                                     |
      99: foo                                                     |
                                                                  |
      {4:Press ENTER or type command to continue}^                     |
    ]])
    for _ = 1, 3 do
      feed('k')
      screen:expect([[
        95: foo                                                     |
        96: foo                                                     |
        97: foo                                                     |
        98: foo                                                     |
        99: foo                                                     |
        {4:-- More --}^                                                  |
      ]])
      feed('k')
      screen:expect([[
        94: foo                                                     |
        95: foo                                                     |
        96: foo                                                     |
        97: foo                                                     |
        98: foo                                                     |
        {4:-- More --}^                                                  |
      ]])
      feed('j')
      screen:expect([[
        95: foo                                                     |
        96: foo                                                     |
        97: foo                                                     |
        98: foo                                                     |
        99: foo                                                     |
        {4:-- More --}^                                                  |
      ]])
      feed('j')
      screen:expect([[
        96: foo                                                     |
        97: foo                                                     |
        98: foo                                                     |
        99: foo                                                     |
                                                                    |
        {4:-- More --}^                                                  |
      ]])
      feed('j')
      screen:expect([[
        96: foo                                                     |
        97: foo                                                     |
        98: foo                                                     |
        99: foo                                                     |
                                                                    |
        {4:Press ENTER or type command to continue}^                     |
      ]])
    end
  end)
end)

it('pager works in headless mode with UI attached', function()
  skip(is_os('win'))
  clear()
  local child_server = assert(n.new_pipename())
  fn.jobstart({ nvim_prog, '--clean', '--headless', '--listen', child_server })
  retry(nil, nil, function()
    neq(nil, vim.uv.fs_stat(child_server))
  end)

  local child_session = n.connect(child_server)
  local child_screen = Screen.new(40, 6, nil, child_session)
  child_screen._default_attr_ids = nil -- TODO: unskip with new color scheme

  child_session:notify('nvim_command', [[echo range(100)->join("\n")]])
  child_screen:expect([[
    0                                       |
    1                                       |
    2                                       |
    3                                       |
    4                                       |
    -- More --^                              |
  ]])

  child_session:request('nvim_input', 'G')
  child_screen:expect([[
    95                                      |
    96                                      |
    97                                      |
    98                                      |
    99                                      |
    Press ENTER or type command to continue^ |
  ]])

  child_session:request('nvim_input', 'g')
  child_screen:expect([[
    0                                       |
    1                                       |
    2                                       |
    3                                       |
    4                                       |
    -- More --^                              |
  ]])
end)
