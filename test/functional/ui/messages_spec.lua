local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed = helpers.clear, helpers.feed
local eval = helpers.eval
local eq = helpers.eq
local command = helpers.command


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
    })
  end)

  it('supports :echoerr', function()
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

  it('supports showmode', function()
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

  it('supports showmode with recording message', function()
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

  it('shows recording message with noshowmode', function()
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

  it('supports showcmd and ruler', function()
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
      content = {{ "Type  :qa!  and press <Enter> to abandon all changes and exit Nvim" }},
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
      {kind="", content={{"Type  :qa!  and press <Enter> to abandon all changes and exit Nvim"}}},
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

  it('supports multiline messages', function()
    feed(':lua error("such\\nmultiline\\nerror")<cr>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
    ]], messages={{
        content = {{'E5105: Error while calling lua chunk: [string "<VimL compiled string>"]:1: such\nmultiline\nerror', 2}},
        kind = "emsg"
     }}}
  end)
end)

describe('ui/ext_messages', function()
  local screen

  before_each(function()
    clear{headless=false, args={"--cmd", "set shortmess-=I"}}
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
      {IGNORE}|
      {1:~                                                                               }|
      {1:~                 }Nvim is open source and freely distributable{1:                  }|
      {1:~                           }https://neovim.io/#chat{1:                             }|
      {1:~                                                                               }|
      {1:~                }type  :help nvim{5:<Enter>}       if you are new! {1:                 }|
      {1:~                }type  :checkhealth{5:<Enter>}     to optimize Nvim{1:                 }|
      {1:~                }type  :q{5:<Enter>}               to exit         {1:                 }|
      {1:~                }type  :help{5:<Enter>}            for help        {1:                 }|
      {1:~                                                                               }|
      {IGNORE}|
      {IGNORE}|
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
      {IGNORE}|
                                                                                      |
                        Nvim is open source and freely distributable                  |
                                  https://neovim.io/#chat                             |
                                                                                      |
                       type  :help nvim{5:<Enter>}       if you are new!                  |
                       type  :checkhealth{5:<Enter>}     to optimize Nvim                 |
                       type  :q{5:<Enter>}               to exit                          |
                       type  :help{5:<Enter>}            for help                         |
                                                                                      |
      {IGNORE}|
      {IGNORE}|
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
