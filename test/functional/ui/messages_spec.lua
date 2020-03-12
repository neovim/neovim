local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed = helpers.clear, helpers.feed
local eval = helpers.eval
local eq = helpers.eq
local command = helpers.command
local set_method_error = helpers.set_method_error
local meths = helpers.meths
local async_meths = helpers.async_meths
local test_build_dir = helpers.test_build_dir
local nvim_prog = helpers.nvim_prog
local iswin = helpers.iswin
local exc_exec = helpers.exc_exec
local exec_lua = helpers.exec_lua

describe('ui/ext_messages', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(25, 5)
    screen:attach({rgb=true, ext_messages=true, ext_popupmenu=true})
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue1},
      [2] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
      [3] = {bold = true},
      [4] = {bold = true, foreground = Screen.colors.SeaGreen4},
      [5] = {foreground = Screen.colors.Blue1},
      [6] = {bold = true, reverse = true},
      [7] = {background = Screen.colors.Yellow},
      [8] = {foreground = Screen.colors.Red},
    })
  end)
  after_each(function()
    os.remove('Xtest')
  end)

  it('msg_clear follows msg_show kind of confirm', function()
    feed('iline 1<esc>')
    feed(':call confirm("test")<cr>')
    screen:expect{grid=[[
      line ^1                   |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], messages={ {
      content = {{"\ntest\n[O]k: ", 4}},
      kind = 'confirm',
    }}}

    feed('<cr>')
    screen:expect{grid=[[
      line ^1                   |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]]}
  end)

  it('msg_show kind=confirm,confirm_sub,emsg,wmsg,quickfix', function()
    feed('iline 1\nline 2<esc>')

    -- kind=confirm
    feed(':echo confirm("test")<cr>')
    screen:expect{grid=[[
      line 1                   |
      line ^2                   |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], messages={ {
      content = {{"\ntest\n[O]k: ", 4}},
      kind = 'confirm',
    }}}
    feed('<cr><cr>')
    screen:expect{grid=[[
      line 1                   |
      line ^2                   |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], messages={ {
        content = { { "\ntest\n[O]k: ", 4 } },
        kind = "confirm"
      }, {
        content = { { "1" } },
        kind = "echo"
      }, {
        content = { { "Press ENTER or type command to continue", 4 } },
        kind = "return_prompt"
    } }}
    feed('<cr><cr>')

    -- kind=confirm_sub
    feed(':%s/i/X/gc<cr>')
    screen:expect{grid=[[
      l{7:i}ne 1                   |
      l{8:i}ne ^2                   |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], attr_ids={
      [1] = {bold = true, foreground = Screen.colors.Blue1},
      [2] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
      [3] = {bold = true},
      [4] = {bold = true, foreground = Screen.colors.SeaGreen4},
      [5] = {foreground = Screen.colors.Blue1},
      [6] = {bold = true, reverse = true},
      [7] = {reverse = true},
      [8] = {background = Screen.colors.Yellow},
    }, messages={ {
        content = { { "replace with X (y/n/a/q/l/^E/^Y)?", 4 } },
        kind = "confirm_sub"
      } }}
    feed('nq')

    -- kind=wmsg (editing readonly file)
    command('write Xtest')
    command('set readonly nohls')
    feed('G$x')
    screen:expect{grid=[[
        line 1                   |
        {MATCH:.*}|
        {1:~                        }|
        {1:~                        }|
        {1:~                        }|
      ]], attr_ids={
      [1] = {bold = true, foreground = Screen.colors.Blue1},
      [7] = {foreground = Screen.colors.Red},
      }, messages={ {
        content = { { "W10: Warning: Changing a readonly file", 7 } },
        kind = "wmsg"
      }
    }}

    -- kind=wmsg ('wrapscan' after search reaches EOF)
    feed('uG$/i<cr>')
    screen:expect{grid=[[
      l^ine 1                   |
      line 2                   |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], attr_ids={
      [1] = {bold = true, foreground = Screen.colors.Blue1},
      [2] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
      [3] = {bold = true},
      [4] = {bold = true, foreground = Screen.colors.SeaGreen4},
      [5] = {foreground = Screen.colors.Blue1},
      [6] = {bold = true, reverse = true},
      [7] = {foreground = Screen.colors.Red},
    }, messages={ {
        content = { { "search hit BOTTOM, continuing at TOP", 7 } },
        kind = "wmsg"
      } }}

    -- kind=emsg after :throw
    feed(':throw "foo"<cr>')
    screen:expect{grid=[[
      l^ine 1                   |
      line 2                   |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], messages={ {
        content = { { "Error detected while processing :", 2 } },
        kind = "emsg"
      }, {
        content = { { "E605: Exception not caught: foo", 2 } },
        kind = ""
      }, {
        content = { { "Press ENTER or type command to continue", 4 } },
        kind = "return_prompt"
      } }
    }

    -- kind=quickfix after :cnext
    feed('<c-c>')
    command("caddexpr [expand('%').':1:line1',expand('%').':2:line2']")
    feed(':cnext<cr>')
    screen:expect{grid=[[
      line 1                   |
      ^line 2                   |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], messages={ {
        content = { { "(2 of 2): line2" } },
        kind = "quickfix"
      } }}
  end)

  it(':echoerr', function()
    feed(':echoerr "raa"<cr>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], messages={{
      content = {{"raa", 2}},
      kind = "echoerr",
    }}}

    -- cmdline in a later input cycle clears error message
    feed(':')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], cmdline={{
      firstc = ":",
      content = {{ "" }},
      pos = 0,
    }}}


    feed('echoerr "bork" | echoerr "fail"<cr>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], messages={{
        content = {{ "bork", 2 }},
        kind = "echoerr"
      }, {
        content = {{ "fail", 2 }},
        kind = "echoerr"
      }, {
        content = {{ "Press ENTER or type command to continue", 4 }},
        kind = "return_prompt"
    }}}

    feed(':echoerr "extrafail"<cr>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], messages={{
        content = { { "bork", 2 } },
        kind = "echoerr"
      }, {
        content = { { "fail", 2 } },
        kind = "echoerr"
      }, {
        content = { { "extrafail", 2 } },
        kind = "echoerr"
      }, {
        content = { { "Press ENTER or type command to continue", 4 } },
        kind = "return_prompt"
    }}}

    feed('<cr>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]]}

    -- cmdline without interleaving wait/display keeps the error message
    feed(':echoerr "problem" | let x = input("foo> ")<cr>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], messages={{
      content = {{ "problem", 2 }},
      kind = "echoerr"
    }}, cmdline={{
      prompt = "foo> ",
      content = {{ "" }},
      pos = 0,
    }}}

    feed('solution<cr>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]]}
    eq('solution', eval('x'))

    feed(":messages<cr>")
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], messages={
      {kind="echoerr", content={{"raa", 2}}},
      {kind="echoerr", content={{"bork", 2}}},
      {kind="echoerr", content={{"fail", 2}}},
      {kind="echoerr", content={{"extrafail", 2}}},
      {kind="echoerr", content={{"problem", 2}}}
    }}
  end)

  it('shortmess-=S', function()
    command('set shortmess-=S')
    feed('iline 1\nline 2<esc>')

    feed('/line<cr>')
    screen:expect{grid=[[
      {7:^line} 1                   |
      {7:line} 2                   |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], messages={
      {content = {{"/line      [1/2] W"}}, kind = "search_count"}
    }}

    feed('n')
    screen:expect{grid=[[
      {7:line} 1                   |
      {7:^line} 2                   |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], messages={
      {content = {{"/line        [2/2]"}}, kind = "search_count"}
    }}
  end)

  it(':hi Group output', function()
    feed(':hi ErrorMsg<cr>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], messages={
      {content = {{"\nErrorMsg      " }, {"xxx", 2}, {" "},
                  {"ctermfg=", 5 }, { "15 " }, { "ctermbg=", 5 }, { "1 " },
                  {"guifg=", 5 }, { "White " }, { "guibg=", 5 }, { "Red" }},
       kind = ""}
    }}
  end)

  it("doesn't crash with column adjustment #10069", function()
    feed(':let [x,y] = [1,2]<cr>')
    feed(':let x y<cr>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], messages={
      {content = {{ "x                     #1" }}, kind = ""},
      {content = {{ "y                     #2" }}, kind = ""},
      {content = {{ "Press ENTER or type command to continue", 4 }}, kind = "return_prompt"}
    }}
  end)

  it('&showmode', function()
    command('imap <f2> <cmd>echomsg "stuff"<cr>')
    feed('i')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], showmode={{"-- INSERT --", 3}}}

    feed('alphpabet<cr>alphanum<cr>')
    screen:expect{grid=[[
      alphpabet                |
      alphanum                 |
      ^                         |
      {1:~                        }|
      {1:~                        }|
    ]], showmode={ { "-- INSERT --", 3 } }}

    feed('<c-x>')
    screen:expect{grid=[[
      alphpabet                |
      alphanum                 |
      ^                         |
      {1:~                        }|
      {1:~                        }|
    ]], showmode={ { "-- ^X mode (^]^D^E^F^I^K^L^N^O^Ps^U^V^Y)", 3 } }}

    feed('<c-p>')
    screen:expect{grid=[[
      alphpabet                |
      alphanum                 |
      alphanum^                 |
      {1:~                        }|
      {1:~                        }|
    ]], popupmenu={
      anchor = { 1, 2, 0 },
      items = { { "alphpabet", "", "", "" }, { "alphanum", "", "", "" } },
      pos = 1
    }, showmode={ { "-- Keyword Local completion (^N^P) ", 3 }, { "match 1 of 2", 4 } }}

    -- echomsg and showmode don't overwrite each other, this is the same
    -- as the TUI behavior with cmdheight=2 or larger.
    feed('<f2>')
    screen:expect{grid=[[
      alphpabet                |
      alphanum                 |
      alphanum^                 |
      {1:~                        }|
      {1:~                        }|
    ]], popupmenu={
      anchor = { 1, 2, 0 },
      items = { { "alphpabet", "", "", "" }, { "alphanum", "", "", "" } },
      pos = 1
    }, messages={ {
        content = { { "stuff" } },
        kind = "echomsg"
      } }, showmode={ { "-- Keyword Local completion (^N^P) ", 3 }, { "match 1 of 2", 4 } }}

    feed('<c-p>')
    screen:expect{grid=[[
      alphpabet                |
      alphanum                 |
      alphpabet^                |
      {1:~                        }|
      {1:~                        }|
    ]], popupmenu={
      anchor = { 1, 2, 0 },
      items = { { "alphpabet", "", "", "" }, { "alphanum", "", "", "" } },
      pos = 0
    }, messages={ {
        content = { { "stuff" } },
        kind = "echomsg"
      } }, showmode={ { "-- Keyword Local completion (^N^P) ", 3 }, { "match 2 of 2", 4 } }}

    feed("<esc>:messages<cr>")
    screen:expect{grid=[[
      alphpabet                |
      alphanum                 |
      alphpabe^t                |
      {1:~                        }|
      {1:~                        }|
    ]], messages={
      {kind="echomsg", content={{"stuff"}}},
    }}
  end)

  it('&showmode with macro-recording message', function()
    feed('qq')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], showmode={ { "recording @q", 3 } }}

    feed('i')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], showmode={ { "-- INSERT --recording @q", 3 } }}

    feed('<esc>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], showmode={ { "recording @q", 3 } }}

    feed('q')
    screen:expect([[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]])
  end)

  it('shows macro-recording message with &noshowmode', function()
    command("set noshowmode")
    feed('qq')
    -- also check mode to avoid immediate success
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], showmode={ { "recording @q", 3 } }, mode="normal"}

    feed('i')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], showmode={ { "recording @q", 3 } }, mode="insert"}

    feed('<esc>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], showmode={ { "recording @q", 3 } }, mode="normal"}

    feed('q')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], mode="normal"}
  end)

  it('supports &showcmd and &ruler', function()
    command('set showcmd ruler')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], ruler={ { "0,0-1   All" } }}
    feed('i')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], showmode={ { "-- INSERT --", 3 } }, ruler={ { "0,1     All" } }}
    feed('abcde<cr>12345<esc>')
    screen:expect{grid=[[
      abcde                    |
      1234^5                    |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], ruler={ { "2,5     All" } }}
    feed('d')
    screen:expect{grid=[[
      abcde                    |
      1234^5                    |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], showcmd={ { "d" } }, ruler={ { "2,5     All" } }}
    feed('<esc>^')
    screen:expect{grid=[[
      abcde                    |
      ^12345                    |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], ruler={ { "2,1     All" } }}
    feed('d')
    screen:expect{grid=[[
      abcde                    |
      ^12345                    |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], showcmd={ { "d" } }, ruler={ { "2,1     All" } }}
    feed('i')
    screen:expect{grid=[[
      abcde                    |
      ^12345                    |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], showcmd={ { "di" } }, ruler={ { "2,1     All" } }}
    feed('w')
    screen:expect{grid=[[
      abcde                    |
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], ruler={ { "2,0-1   All" } }}

    -- when ruler is part of statusline it is not externalized.
    -- this will be added as part of future ext_statusline support
    command("set laststatus=2")
    screen:expect([[
      abcde                    |
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {6:<o Name] [+] 2,0-1    All}|
    ]])
  end)

  it('keeps history of message of different kinds', function()
    feed(':echomsg "howdy"<cr>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], messages={{
      content = {{ "howdy" }}, kind = "echomsg"}
    }}

    -- always test a message without kind. If this one gets promoted to a
    -- category, add a new message without kind.
    feed('<c-c>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], messages={{
      content = {{ "Type  :qa  and press <Enter> to exit Nvim" }},
      kind = ""}
    }}

    feed(':echoerr "bork"<cr>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], messages={{
      content = {{ "bork", 2 }}, kind = "echoerr"}
    }}

    feed(':echo "xyz"<cr>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], messages={{
      content = {{ "xyz" }}, kind = "echo"}
    }}

    feed(':call nosuchfunction()<cr>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], messages={{
      content = {{ "E117: Unknown function: nosuchfunction", 2 }},
      kind = "emsg"}
    }}

    feed(':messages<cr>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], messages={
      {kind="echomsg", content={{"howdy"}}},
      {kind="", content={{"Type  :qa  and press <Enter> to exit Nvim"}}},
      {kind="echoerr", content={{"bork", 2}}},
      {kind="emsg", content={{"E117: Unknown function: nosuchfunction", 2}}}
    }}
  end)

  it('implies ext_cmdline and ignores cmdheight', function()
    eq(0, eval('&cmdheight'))
    feed(':set cmdheight=1')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], cmdline={{
      content = { { "set cmdheight=1" } },
      firstc = ":",
      pos = 15 }
    }}

    feed('<cr>')
    screen:expect([[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]])
    eq(0, eval('&cmdheight'))

    -- normally this would be an error
    feed(':set cmdheight=0')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], cmdline={{
        content = { { "set cmdheight=0" } },
        firstc = ":",
        pos = 15 }
    }}
    feed('<cr>')
    screen:expect([[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]])
    eq(0, eval('&cmdheight'))
  end)

  it('supports multiline messages from lua', function()
    feed(':lua error("such\\nmultiline\\nerror")<cr>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], messages={{
        content = {{'E5108: Error executing lua [string ":lua"]:1: such\nmultiline\nerror', 2}},
        kind = "lua_error"
     }}}
  end)

  it('supports multiline messages from rpc', function()
    feed(':call rpcrequest(1, "test_method")<cr>')

    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], messages={{
      content = {{"Error invoking 'test_method' on channel 1:\ncomplete\nerror\n\nmessage", 2}},
      kind = "rpc_error"
    }}, request_cb=function (name)
      if name == "test_method" then
        set_method_error("complete\nerror\n\nmessage")
      end
    end}
  end)

  it('wildmode=list', function()
    screen:try_resize(25, 7)
    screen:set_option('ext_popupmenu', false)

    command('set wildmenu wildmode=list')
    feed(':set wildm<tab>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], messages={{
        content = {{'wildmenu  wildmode'}},
        kind = '',
     }},
    cmdline={{
      firstc = ':',
      content = {{ 'set wildm' }},
      pos = 9,
    }}}
  end)
end)

describe('ui/builtin messages', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(60, 7)
    screen:attach({rgb=true, ext_popupmenu=true})
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue1},
      [2] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
      [3] = {bold = true, reverse = true},
      [4] = {bold = true, foreground = Screen.colors.SeaGreen4},
      [5] = {foreground = Screen.colors.Blue1},
      [6] = {bold = true, foreground = Screen.colors.Magenta},
      [7] = {background = Screen.colors.Grey20},
      [8] = {reverse = true},
      [9] = {background = Screen.colors.LightRed}
    })
  end)

  it('supports multiline messages from rpc', function()
    feed(':call rpcrequest(1, "test_method")<cr>')

    screen:expect{grid=[[
      {3:                                                            }|
      {2:Error invoking 'test_method' on channel 1:}                  |
      {2:complete}                                                    |
      {2:error}                                                       |
                                                                  |
      {2:message}                                                     |
      {4:Press ENTER or type command to continue}^                     |
    ]], request_cb=function (name)
      if name == "test_method" then
        set_method_error("complete\nerror\n\nmessage")
      end
    end}
  end)

  it(':hi Group output', function()
    screen:try_resize(70,7)
    feed(':hi ErrorMsg<cr>')
    screen:expect([[
                                                                            |
      {1:~                                                                     }|
      {1:~                                                                     }|
      {3:                                                                      }|
      :hi ErrorMsg                                                          |
      ErrorMsg       {2:xxx} {5:ctermfg=}15 {5:ctermbg=}1 {5:guifg=}White {5:guibg=}Red         |
      {4:Press ENTER or type command to continue}^                               |
    ]])

    feed('<cr>')
    screen:try_resize(30,7)
    feed(':hi ErrorMsg<cr>')
    screen:expect([[
      :hi ErrorMsg                  |
      ErrorMsg       {2:xxx} {5:ctermfg=}15 |
                         {5:ctermbg=}1  |
                         {5:guifg=}White|
                         {5:guibg=}Red  |
      {4:Press ENTER or type command to}|
      {4: continue}^                     |
    ]])
    feed('<cr>')

    -- screen size doesn't affect internal output #10285
    eq('ErrorMsg       xxx ctermfg=15 ctermbg=1 guifg=White guibg=Red',
       meths.exec("hi ErrorMsg", true))
  end)

  it(':syntax list langGroup output', function()
    command("syntax on")
    command("set syntax=vim")
    screen:try_resize(110,7)
    feed(':syntax list vimComment<cr>')
    screen:expect([[
      {6:--- Syntax items ---}                                                                                          |
      vimComment     {5:xxx} {5:match} /\s"[^\-:.%#=*].*$/ms=s+1,lc=1  {5:excludenl} {5:contains}=@vimCommentGroup,vimCommentString |
                                                                                                                    |
                         {5:match} /\<endif\s\+".*$/ms=s+5,lc=5  {5:contains}=@vimCommentGroup,vimCommentString             |
                         {5:match} /\<else\s\+".*$/ms=s+4,lc=4  {5:contains}=@vimCommentGroup,vimCommentString              |
                         {5:links to} Comment                                                                           |
      {4:Press ENTER or type command to continue}^                                                                       |
    ]])

    feed('<cr>')
    screen:try_resize(55,7)
    feed(':syntax list vimComment<cr>')
    screen:expect([[
                                                             |
                         {5:match} /\<endif\s\+".*$/ms=s+5,lc=5  |
      {5:contains}=@vimCommentGroup,vimCommentString             |
                         {5:match} /\<else\s\+".*$/ms=s+4,lc=4  {5:c}|
      {5:ontains}=@vimCommentGroup,vimCommentString              |
                         {5:links to} Comment                    |
      {4:Press ENTER or type command to continue}^                |
    ]])
    feed('<cr>')

    -- ignore final whitespace inside string
    -- luacheck: push ignore
    eq([[--- Syntax items ---
vimComment     xxx match /\s"[^\-:.%#=*].*$/ms=s+1,lc=1  excludenl contains=@vimCommentGroup,vimCommentString 
                   match /\<endif\s\+".*$/ms=s+5,lc=5  contains=@vimCommentGroup,vimCommentString 
                   match /\<else\s\+".*$/ms=s+4,lc=4  contains=@vimCommentGroup,vimCommentString 
                   links to Comment]],
       meths.exec('syntax list vimComment', true))
    -- luacheck: pop
  end)

  it('supports ruler with laststatus=0', function()
    command("set ruler laststatus=0")
    screen:expect{grid=[[
      ^                                                            |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
                                                0,0-1         All |
    ]]}

    command("hi MsgArea guibg=#333333")
    screen:expect{grid=[[
      ^                                                            |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {7:                                          0,0-1         All }|
    ]]}

    command("set rulerformat=%15(%c%V\\ %p%%%)")
    screen:expect{grid=[[
      ^                                                            |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {7:                                          0,0-1 100%        }|
    ]]}
  end)

  it('supports echo with CRLF line separators', function()
    feed(':echo "line 1\\r\\nline 2"<cr>')
    screen:expect{grid=[[
                                                                  |
      {1:~                                                           }|
      {1:~                                                           }|
      {3:                                                            }|
      line 1                                                      |
      line 2                                                      |
      {4:Press ENTER or type command to continue}^                     |
    ]]}

    feed('<cr>:echo "abc\\rz"<cr>')
    screen:expect{grid=[[
      ^                                                            |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      zbc                                                         |
    ]]}
  end)

  it('redraws NOT_VALID correctly after message', function()
    -- edge case: only one window was set NOT_VALID. Orginal report
    -- used :make, but fake it using one command to set the current
    -- window NOT_VALID and another to show a long message.
    command("set more")
    feed(':new<cr><c-w><c-w>')
    screen:expect{grid=[[
                                                                  |
      {1:~                                                           }|
      {8:[No Name]                                                   }|
      ^                                                            |
      {1:~                                                           }|
      {3:[No Name]                                                   }|
      :new                                                        |
    ]]}

    feed(':set colorcolumn=10 | digraphs<cr>')
    screen:expect{grid=[[
      :set colorcolumn=10 | digraphs                              |
      NU {5:^@}  10    SH {5:^A}   1    SX {5:^B}   2    EX {5:^C}   3            |
      ET {5:^D}   4    EQ {5:^E}   5    AK {5:^F}   6    BL {5:^G}   7            |
      BS {5:^H}   8    HT {5:^I}   9    LF {5:^@}  10    VT {5:^K}  11            |
      FF {5:^L}  12    CR {5:^M}  13    SO {5:^N}  14    SI {5:^O}  15            |
      DL {5:^P}  16    D1 {5:^Q}  17    D2 {5:^R}  18    D3 {5:^S}  19            |
      {4:-- More --}^                                                  |
    ]]}

    feed('q')
    screen:expect{grid=[[
                                                                  |
      {1:~                                                           }|
      {8:[No Name]                                                   }|
      ^         {9: }                                                  |
      {1:~                                                           }|
      {3:[No Name]                                                   }|
                                                                  |
    ]]}

    -- edge case: just covers statusline
    feed(':set colorcolumn=5 | lua error("x\\n\\nx")<cr>')
    screen:expect{grid=[[
                                                                  |
      {1:~                                                           }|
      {3:                                                            }|
      {2:E5108: Error executing lua [string ":lua"]:1: x}             |
                                                                  |
      {2:x}                                                           |
      {4:Press ENTER or type command to continue}^                     |
    ]]}

    feed('<cr>')
    screen:expect{grid=[[
                                                                  |
      {1:~                                                           }|
      {8:[No Name]                                                   }|
      ^    {9: }                                                       |
      {1:~                                                           }|
      {3:[No Name]                                                   }|
                                                                  |
    ]]}

    -- edge case: just covers lowest window line
    feed(':set colorcolumn=5 | lua error("x\\n\\n\\nx")<cr>')
    screen:expect{grid=[[
                                                                  |
      {3:                                                            }|
      {2:E5108: Error executing lua [string ":lua"]:1: x}             |
                                                                  |
                                                                  |
      {2:x}                                                           |
      {4:Press ENTER or type command to continue}^                     |
    ]]}

    feed('<cr>')
    screen:expect{grid=[[
                                                                  |
      {1:~                                                           }|
      {8:[No Name]                                                   }|
      ^    {9: }                                                       |
      {1:~                                                           }|
      {3:[No Name]                                                   }|
                                                                  |
    ]]}
  end)
end)

describe('ui/ext_messages', function()
  local screen

  before_each(function()
    clear{args_rm={'--headless'}, args={"--cmd", "set shortmess-=I"}}
    screen = Screen.new(80, 24)
    screen:attach({rgb=true, ext_messages=true, ext_popupmenu=true})
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue1},
      [2] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
      [3] = {bold = true},
      [4] = {bold = true, foreground = Screen.colors.SeaGreen4},
      [5] = {foreground = Screen.colors.Blue1},
    })
  end)

  it('supports intro screen', function()
    -- intro message is not externalized. But check that it still works.
    -- Note parts of it depends on version or is indeterministic. We ignore those parts.
    screen:expect([[
      ^                                                                                |
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {MATCH:.*}|
      {1:~                                                                               }|
      {1:~                 }Nvim is open source and freely distributable{1:                  }|
      {1:~                           }https://neovim.io/#chat{1:                             }|
      {1:~                                                                               }|
      {1:~                }type  :help nvim{5:<Enter>}       if you are new! {1:                 }|
      {1:~                }type  :checkhealth{5:<Enter>}     to optimize Nvim{1:                 }|
      {1:~                }type  :q{5:<Enter>}               to exit         {1:                 }|
      {1:~                }type  :help{5:<Enter>}            for help        {1:                 }|
      {1:~                                                                               }|
      {MATCH:.*}|
      {MATCH:.*}|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
    ]])

    feed("<c-l>")
    screen:expect([[
      ^                                                                                |
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
      {1:~                                                                               }|
    ]])

    feed(":intro<cr>")
    screen:expect{grid=[[
                                                                                      |
                                                                                      |
                                                                                      |
                                                                                      |
                                                                                      |
                                                                                      |
      {MATCH:.*}|
                                                                                      |
                        Nvim is open source and freely distributable                  |
                                  https://neovim.io/#chat                             |
                                                                                      |
                       type  :help nvim{5:<Enter>}       if you are new!                  |
                       type  :checkhealth{5:<Enter>}     to optimize Nvim                 |
                       type  :q{5:<Enter>}               to exit                          |
                       type  :help{5:<Enter>}            for help                         |
                                                                                      |
      {MATCH:.*}|
      {MATCH:.*}|
                                                                                      |
                                                                                      |
                                                                                      |
                                                                                      |
                                                                                      |
                                                                                      |
    ]], messages={
      {content = { { "Press ENTER or type command to continue", 4 } }, kind = "return_prompt" }
    }}
  end)
end)

describe('ui/msg_puts_printf', function()
  it('output multibyte characters correctly', function()
    local screen
    local cmd = ''
    local locale_dir = test_build_dir..'/share/locale/ja/LC_MESSAGES'

    clear({env={LANG='ja_JP.UTF-8'}})
    screen = Screen.new(25, 5)
    screen:attach()

    if iswin() then
      if os.execute('chcp 932 > NUL 2>&1') ~= 0 then
        pending('missing japanese language features', function() end)
        return
      else
        cmd = 'chcp 932 > NULL & '
      end
    else
      if (exc_exec('lang ja_JP.UTF-8') ~= 0) then
        pending('Locale ja_JP.UTF-8 not supported', function() end)
        return
      elseif helpers.isCI() then
        -- Fails non--Windows CI. Message catalog direcotry issue?
        pending('fails on unix CI', function() end)
        return
      end
    end

    os.execute('cmake -E make_directory '..locale_dir)
    os.execute('cmake -E copy '..test_build_dir..'/src/nvim/po/ja.mo '..locale_dir..'/nvim.mo')

    cmd = cmd..'"'..nvim_prog..'" -u NONE -i NONE -Es -V1'
    command([[call termopen(']]..cmd..[[')]])
    screen:expect([[
    ^Exモードに入ります. ノー |
    マルモードに戻るには"visu|
    al"と入力してください.   |
    :                        |
                             |
    ]])

    os.execute('cmake -E remove_directory '..test_build_dir..'/share')
  end)
end)

describe('pager', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(35, 8)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue1},
      [2] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
      [3] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red, special=Screen.colors.Yellow},
      [4] = {bold = true, foreground = Screen.colors.SeaGreen4},
      [5] = {special = Screen.colors.Yellow},
      [6] = {special = Screen.colors.Yellow, bold = true, foreground = Screen.colors.SeaGreen4},
      [7] = {foreground = Screen.colors.Grey0, background = Screen.colors.Grey100},
      [8] = {foreground = Screen.colors.Gray90, background = Screen.colors.Grey100},
      [9] = {foreground = tonumber('0x00000c'), background = Screen.colors.Grey100},
      [10] = {background = Screen.colors.Grey100, bold = true, foreground = tonumber('0xe5e5ff')},
      [11] = {background = Screen.colors.Grey100, bold = true, foreground = tonumber ('0x2b8452')},
      [12] = {bold = true, reverse = true},
    })
    command("set more")

    exec_lua('_G.x = ...', [[
Lorem ipsum dolor sit amet, consectetur
adipisicing elit, sed do eiusmod tempor
incididunt ut labore et dolore magna aliqua.
Ut enim ad minim veniam, quis nostrud xercitation
ullamco laboris nisi ut
aliquip ex ea commodo consequat.]])
  end)

  it('can be quit', function()
    screen:try_resize(25,5)
    feed(':echon join(map(range(0, &lines*10), "v:val"), "\\n")<cr>')
    screen:expect{grid=[[
      0                        |
      1                        |
      2                        |
      3                        |
      {4:-- More --}^               |
    ]]}
    feed('q')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]]}
  end)

  it('handles wrapped lines with line scroll', function()
    feed(':lua error(_G.x)<cr>')
    screen:expect{grid=[[
      {2:E5108: Error executing lua [string }|
      {2:":lua"]:1: Lorem ipsum dolor sit am}|
      {2:et, consectetur}                    |
      {2:adipisicing elit, sed do eiusmod te}|
      {2:mpor}                               |
      {2:incididunt ut labore et dolore magn}|
      {2:a aliqua.}                          |
      {4:-- More --}^                         |
    ]]}

    feed('j')
    screen:expect{grid=[[
      {2:":lua"]:1: Lorem ipsum dolor sit am}|
      {2:et, consectetur}                    |
      {2:adipisicing elit, sed do eiusmod te}|
      {2:mpor}                               |
      {2:incididunt ut labore et dolore magn}|
      {2:a aliqua.}                          |
      {2:Ut enim ad minim veniam, quis nostr}|
      {4:-- More --}^                         |
    ]]}

    feed('k')
    screen:expect{grid=[[
      {2:E5108: Error executing lua [string }|
      {2:":lua"]:1: Lorem ipsum dolor sit am}|
      {2:et, consectetur}                    |
      {2:adipisicing elit, sed do eiusmod te}|
      {2:mpor}                               |
      {2:incididunt ut labore et dolore magn}|
      {2:a aliqua.}                          |
      {4:-- More --}^                         |
    ]]}

    feed('j')
    screen:expect{grid=[[
      {2:":lua"]:1: Lorem ipsum dolor sit am}|
      {2:et, consectetur}                    |
      {2:adipisicing elit, sed do eiusmod te}|
      {2:mpor}                               |
      {2:incididunt ut labore et dolore magn}|
      {2:a aliqua.}                          |
      {2:Ut enim ad minim veniam, quis nostr}|
      {4:-- More --}^                         |
    ]]}
  end)

  it('handles wrapped lines with page scroll', function()
    feed(':lua error(_G.x)<cr>')
    screen:expect{grid=[[
      {2:E5108: Error executing lua [string }|
      {2:":lua"]:1: Lorem ipsum dolor sit am}|
      {2:et, consectetur}                    |
      {2:adipisicing elit, sed do eiusmod te}|
      {2:mpor}                               |
      {2:incididunt ut labore et dolore magn}|
      {2:a aliqua.}                          |
      {4:-- More --}^                         |
    ]]}
    feed('d')
    screen:expect{grid=[[
      {2:incididunt ut labore et dolore magn}|
      {2:a aliqua.}                          |
      {2:Ut enim ad minim veniam, quis nostr}|
      {2:ud xercitation}                     |
      {2:ullamco laboris nisi ut}            |
      {2:aliquip ex ea commodo consequat.}   |
      {4:Press ENTER or type command to cont}|
      {4:inue}^                               |
    ]]}
    feed('u')
    screen:expect{grid=[[
      {2:E5108: Error executing lua [string }|
      {2:":lua"]:1: Lorem ipsum dolor sit am}|
      {2:et, consectetur}                    |
      {2:adipisicing elit, sed do eiusmod te}|
      {2:mpor}                               |
      {2:incididunt ut labore et dolore magn}|
      {2:a aliqua.}                          |
      {4:-- More --}^                         |
    ]]}
    feed('d')
    screen:expect{grid=[[
      {2:mpor}                               |
      {2:incididunt ut labore et dolore magn}|
      {2:a aliqua.}                          |
      {2:Ut enim ad minim veniam, quis nostr}|
      {2:ud xercitation}                     |
      {2:ullamco laboris nisi ut}            |
      {2:aliquip ex ea commodo consequat.}   |
      {4:-- More --}^                         |
    ]]}
  end)

  it('handles wrapped lines with line scroll and MsgArea highlight', function()
    command("hi MsgArea guisp=Yellow")

    feed(':lua error(_G.x)<cr>')
    screen:expect{grid=[[
      {3:E5108: Error executing lua [string }|
      {3:":lua"]:1: Lorem ipsum dolor sit am}|
      {3:et, consectetur}{5:                    }|
      {3:adipisicing elit, sed do eiusmod te}|
      {3:mpor}{5:                               }|
      {3:incididunt ut labore et dolore magn}|
      {3:a aliqua.}{5:                          }|
      {6:-- More --}{5:^                         }|
    ]]}

    feed('j')
    screen:expect{grid=[[
      {3:":lua"]:1: Lorem ipsum dolor sit am}|
      {3:et, consectetur}{5:                    }|
      {3:adipisicing elit, sed do eiusmod te}|
      {3:mpor}{5:                               }|
      {3:incididunt ut labore et dolore magn}|
      {3:a aliqua.}{5:                          }|
      {3:Ut enim ad minim veniam, quis nostr}|
      {6:-- More --}{5:^                         }|
    ]]}

    feed('k')
    screen:expect{grid=[[
      {3:E5108: Error executing lua [string }|
      {3:":lua"]:1: Lorem ipsum dolor sit am}|
      {3:et, consectetur}{5:                    }|
      {3:adipisicing elit, sed do eiusmod te}|
      {3:mpor}{5:                               }|
      {3:incididunt ut labore et dolore magn}|
      {3:a aliqua.}{5:                          }|
      {6:-- More --}{5:^                         }|
    ]]}

    feed('j')
    screen:expect{grid=[[
      {3:":lua"]:1: Lorem ipsum dolor sit am}|
      {3:et, consectetur}{5:                    }|
      {3:adipisicing elit, sed do eiusmod te}|
      {3:mpor}{5:                               }|
      {3:incididunt ut labore et dolore magn}|
      {3:a aliqua.}{5:                          }|
      {3:Ut enim ad minim veniam, quis nostr}|
      {6:-- More --}{5:^                         }|
    ]]}
  end)

  it('handles wrapped lines with page scroll and MsgArea highlight', function()
    command("hi MsgArea guisp=Yellow")
    feed(':lua error(_G.x)<cr>')
    screen:expect{grid=[[
      {3:E5108: Error executing lua [string }|
      {3:":lua"]:1: Lorem ipsum dolor sit am}|
      {3:et, consectetur}{5:                    }|
      {3:adipisicing elit, sed do eiusmod te}|
      {3:mpor}{5:                               }|
      {3:incididunt ut labore et dolore magn}|
      {3:a aliqua.}{5:                          }|
      {6:-- More --}{5:^                         }|
    ]]}
    feed('d')
    screen:expect{grid=[[
      {3:incididunt ut labore et dolore magn}|
      {3:a aliqua.}{5:                          }|
      {3:Ut enim ad minim veniam, quis nostr}|
      {3:ud xercitation}{5:                     }|
      {3:ullamco laboris nisi ut}{5:            }|
      {3:aliquip ex ea commodo consequat.}{5:   }|
      {6:Press ENTER or type command to cont}|
      {6:inue}{5:^                               }|
    ]]}
    feed('u')
    screen:expect{grid=[[
      {3:E5108: Error executing lua [string }|
      {3:":lua"]:1: Lorem ipsum dolor sit am}|
      {3:et, consectetur}{5:                    }|
      {3:adipisicing elit, sed do eiusmod te}|
      {3:mpor}{5:                               }|
      {3:incididunt ut labore et dolore magn}|
      {3:a aliqua.}{5:                          }|
      {6:-- More --}{5:^                         }|
    ]]}
    feed('d')
    screen:expect{grid=[[
      {3:mpor}{5:                               }|
      {3:incididunt ut labore et dolore magn}|
      {3:a aliqua.}{5:                          }|
      {3:Ut enim ad minim veniam, quis nostr}|
      {3:ud xercitation}{5:                     }|
      {3:ullamco laboris nisi ut}{5:            }|
      {3:aliquip ex ea commodo consequat.}{5:   }|
      {6:-- More --}{5:^                         }|
    ]]}
  end)

  it('preserves MsgArea highlighting after more prompt', function()
    screen:try_resize(70,6)
    command("hi MsgArea guisp=Yellow")
    command("map x Lorem ipsum labore et dolore magna aliqua")
    command("map y adipisicing elit")
    command("map z incididunt ut")
    command("map a labore et dolore")
    command("map b ex ea commodo")
    command("map xx yy")
    command("map xy yz")
    feed(':map<cr>')
    screen:expect{grid=[[
      {5:   a             labore et dolore                                     }|
      {5:   b             ex ea commodo                                        }|
      {5:   xy            yz                                                   }|
      {5:   xx            yy                                                   }|
      {5:   x             Lorem ipsum labore et dolore magna aliqua            }|
      {6:-- More --}{5:^                                                            }|
    ]]}
    feed('j')
    screen:expect{grid=[[
      {5:   b             ex ea commodo                                        }|
      {5:   xy            yz                                                   }|
      {5:   xx            yy                                                   }|
      {5:   x             Lorem ipsum labore et dolore magna aliqua            }|
      {5:   y             adipisicing elit                                     }|
      {6:-- More --}{5:^                                                            }|
    ]]}
    feed('j')
    screen:expect{grid=[[
      {5:   xy            yz                                                   }|
      {5:   xx            yy                                                   }|
      {5:   x             Lorem ipsum labore et dolore magna aliqua            }|
      {5:   y             adipisicing elit                                     }|
      {5:   z             incididunt ut                                        }|
      {6:Press ENTER or type command to continue}{5:^                               }|
    ]]}
  end)

  it('clears "-- more --" message', function()
    command("hi MsgArea guisp=Yellow blend=10")
    feed(':echon join(range(20), "\\n")<cr>')
    screen:expect{grid=[[
      {7:0}{8:                                  }|
      {9:1}{10:                                  }|
      {9:2}{10:                                  }|
      {9:3}{10:                                  }|
      {9:4}{10:                                  }|
      {9:5}{10:                                  }|
      {9:6}{10:                                  }|
      {11:--}{8: }{11:More}{8: }{11:--}{8:^                         }|
    ]]}

    feed('j')
    screen:expect{grid=[[
      {7:1}{8:                                  }|
      {9:2}{10:                                  }|
      {9:3}{10:                                  }|
      {9:4}{10:                                  }|
      {9:5}{10:                                  }|
      {9:6}{10:                                  }|
      {9:7}{10:                                  }|
      {11:--}{8: }{11:More}{8: }{11:--}{8:^                         }|
    ]]}

    feed('k')
    screen:expect{grid=[[
      {7:0}{8:                          }{7:)}{8:       }|
      {9:1}{10:                                  }|
      {9:2}{10:                                  }|
      {9:3}{10:                                  }|
      {9:4}{10:                                  }|
      {9:5}{10:                                  }|
      {9:6}{10:                                  }|
      {11:--}{8: }{11:More}{8: }{11:--}{8:^                         }|
    ]]}

    feed('j')
    screen:expect{grid=[[
      {7:1}{8:                                  }|
      {9:2}{10:                                  }|
      {9:3}{10:                                  }|
      {9:4}{10:                                  }|
      {9:5}{10:                                  }|
      {9:6}{10:                                  }|
      {9:7}{10:                                  }|
      {11:--}{8: }{11:More}{8: }{11:--}{8:^                         }|
    ]]}
  end)

  it('with :!cmd does not crash on resize', function()
    feed(':!sleep 1<cr>')
    screen:expect{grid=[[
                                         |
      {1:~                                  }|
      {1:~                                  }|
      {1:~                                  }|
      {1:~                                  }|
      {12:                                   }|
      :!sleep 1                          |
                                         |
    ]]}

    -- not processed while command is executing
    async_meths.ui_try_resize(35, 5)

    -- TODO(bfredl): ideally it should be processed just
    -- before the "press ENTER" prompt though
    screen:expect{grid=[[
                                         |
      {1:~                                  }|
      {1:~                                  }|
      {12:                                   }|
      :!sleep 1                          |
                                         |
      {4:Press ENTER or type command to cont}|
      {4:inue}^                               |
    ]]}

    feed('<cr>')
    screen:expect{grid=[[
      ^                                   |
      {1:~                                  }|
      {1:~                                  }|
      {1:~                                  }|
                                         |
    ]]}
  end)

  it('can be resized', function()
    feed(':lua error(_G.x)<cr>')
    screen:expect{grid=[[
      {2:E5108: Error executing lua [string }|
      {2:":lua"]:1: Lorem ipsum dolor sit am}|
      {2:et, consectetur}                    |
      {2:adipisicing elit, sed do eiusmod te}|
      {2:mpor}                               |
      {2:incididunt ut labore et dolore magn}|
      {2:a aliqua.}                          |
      {4:-- More --}^                         |
    ]]}

    -- responds to resize, but text is not reflown
    screen:try_resize(45, 5)
    screen:expect{grid=[[
      {2:adipisicing elit, sed do eiusmod te}          |
      {2:mpor}                                         |
      {2:incididunt ut labore et dolore magn}          |
      {2:a aliqua.}                                    |
      {4:-- More --}^                                   |
    ]]}

    -- can create empty space, as the command hasn't output the text below yet.
    -- text is not reflown; existing lines get cut
    screen:try_resize(30, 12)
    screen:expect{grid=[[
      {2:E5108: Error executing lua [st}|
      {2:":lua"]:1: Lorem ipsum dolor s}|
      {2:et, consectetur}               |
      {2:adipisicing elit, sed do eiusm}|
      {2:mpore}                         |
      {2:incididunt ut labore et dolore}|
      {2:a aliqua.}                     |
                                    |
                                    |
                                    |
                                    |
      {4:-- More --}^                    |
    ]]}

    -- continues in a mostly consistent state, but only new lines are
    -- wrapped at the new screen size.
    feed('<cr>')
    screen:expect{grid=[[
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
      {4:Press ENTER or type command to}|
      {4: continue}^                     |
    ]]}

    feed('q')
    screen:expect{grid=[[
      ^                              |
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
                                    |
    ]]}
  end)
end)
