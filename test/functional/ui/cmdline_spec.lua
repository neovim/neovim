local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed = helpers.clear, helpers.feed
local source = helpers.source
local command = helpers.command

local function new_screen(opt)
  local screen = Screen.new(25, 5)
  screen:attach(opt)
  screen:set_default_attr_ids({
    [1] = {bold = true, foreground = Screen.colors.Blue1},
    [2] = {reverse = true},
    [3] = {bold = true, reverse = true},
    [4] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
    [5] = {bold = true, foreground = Screen.colors.SeaGreen4},
  })
  return screen
end

local function test_cmdline(linegrid)
  local screen

  before_each(function()
    clear()
    screen = new_screen({rgb=true, ext_cmdline=true, ext_linegrid=linegrid})
  end)

  it('works', function()
    feed(':')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]], cmdline={{
      firstc = ":",
      content = {{""}},
      pos = 0,
    }}}

    feed('sign')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]], cmdline={{
      firstc = ":",
      content = {{"sign"}},
      pos = 4,
    }}}

    feed('<Left>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]], cmdline={{
      firstc = ":",
      content = {{"sign"}},
      pos = 3,
    }}}

    feed('<bs>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]], cmdline={{
      firstc = ":",
      content = {{"sin"}},
      pos = 2,
    }}}

    feed('<Esc>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]]}
  end)

  describe("redraws statusline on entering", function()
    before_each(function()
      command('set laststatus=2')
      command('set statusline=%{mode()}')
    end)

    it('from normal mode', function()
      screen:expect{grid=[[
        ^                         |
        {1:~                        }|
        {1:~                        }|
        {3:n                        }|
                                 |
      ]]}

      feed(':')
      screen:expect{grid=[[
        ^                         |
        {1:~                        }|
        {1:~                        }|
        {3:c                        }|
                                 |
      ]], cmdline={{
        firstc = ":",
        content = {{""}},
        pos = 0,
      }}}
    end)

    it('from normal mode when : is mapped', function()
      command('nnoremap ; :')

      screen:expect{grid=[[
        ^                         |
        {1:~                        }|
        {1:~                        }|
        {3:n                        }|
                                 |
      ]]}

      feed(';')
      screen:expect{grid=[[
        ^                         |
        {1:~                        }|
        {1:~                        }|
        {3:c                        }|
                                 |
      ]], cmdline={{
        firstc = ":",
        content = {{""}},
        pos = 0,
      }}}
    end)

    it('but not with scrolled messages', function()
      screen:try_resize(35,10)
      feed(':echoerr doesnotexist<cr>')
      screen:expect{grid=[[
                                           |
        {1:~                                  }|
        {1:~                                  }|
        {1:~                                  }|
        {1:~                                  }|
        {3:                                   }|
        {4:E121: Undefined variable: doesnotex}|
        {4:ist}                                |
        {5:Press ENTER or type command to cont}|
        {5:inue}^                               |
      ]]}
      feed(':echoerr doesnotexist<cr>')
      screen:expect{grid=[[
                                           |
        {1:~                                  }|
        {3:                                   }|
        {4:E121: Undefined variable: doesnotex}|
        {4:ist}                                |
        {5:Press ENTER or type command to cont}|
        {4:E121: Undefined variable: doesnotex}|
        {4:ist}                                |
        {5:Press ENTER or type command to cont}|
        {5:inue}^                               |
      ]]}

      feed(':echoerr doesnotexist<cr>')
      screen:expect{grid=[[
        {4:E121: Undefined variable: doesnotex}|
        {4:ist}                                |
        {5:Press ENTER or type command to cont}|
        {4:E121: Undefined variable: doesnotex}|
        {4:ist}                                |
        {5:Press ENTER or type command to cont}|
        {4:E121: Undefined variable: doesnotex}|
        {4:ist}                                |
        {5:Press ENTER or type command to cont}|
        {5:inue}^                               |
      ]]}

      feed('<cr>')
      screen:expect{grid=[[
        ^                                   |
        {1:~                                  }|
        {1:~                                  }|
        {1:~                                  }|
        {1:~                                  }|
        {1:~                                  }|
        {1:~                                  }|
        {1:~                                  }|
        {3:n                                  }|
                                           |
      ]]}
    end)
  end)

  it("works with input()", function()
    feed(':call input("input", "default")<cr>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]], cmdline={{
      prompt = "input",
      content = {{"default"}},
      pos = 7,
    }}}

    feed('<cr>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]]}
  end)

  it("works with special chars and nested cmdline", function()
    feed(':xx<c-r>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]], cmdline={{
      firstc = ":",
      content = {{"xx"}},
      pos = 2,
      special = {'"', true},
    }}}

    feed('=')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]], cmdline={{
      firstc = ":",
      content = {{"xx"}},
      pos = 2,
      special = {'"', true},
    }, {
      firstc = "=",
      content = {{""}},
      pos = 0,
    }}}

    feed('1+2')
    local expectation = {{
      firstc = ":",
      content = {{"xx"}},
      pos = 2,
      special = {'"', true},
    }, {
      firstc = "=",
      content = {{"1"}, {"+"}, {"2"}},
      pos = 3,
    }}

    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]], cmdline=expectation}

    -- erase information, so we check if it is retransmitted
    command("mode")
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]], cmdline=expectation, reset=true}


    feed('<cr>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]], cmdline={{
      firstc = ":",
      content = {{"xx3"}},
      pos = 3,
    }}}

    feed('<esc>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]]}
  end)

  it("works with function definitions", function()
    feed(':function Foo()<cr>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]], cmdline={{
      indent = 2,
      firstc = ":",
      content = {{""}},
      pos = 0,
    }}, cmdline_block = {
      {{'function Foo()'}},
    }}

    feed('line1<cr>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]], cmdline={{
      indent = 2,
      firstc = ":",
      content = {{""}},
      pos = 0,
    }}, cmdline_block = {
      {{'function Foo()'}},
      {{'  line1'}},
    }}

    command("mode")
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]], cmdline={{
      indent = 2,
      firstc = ":",
      content = {{""}},
      pos = 0,
    }}, cmdline_block = {
      {{'function Foo()'}},
      {{'  line1'}},
    }, reset=true}

    feed('endfunction<cr>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]]}

    -- Try once more, to check buffer is reinitialized. #8007
    feed(':function Bar()<cr>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]], cmdline={{
      indent = 2,
      firstc = ":",
      content = {{""}},
      pos = 0,
    }}, cmdline_block = {
      {{'function Bar()'}},
    }}

    feed('endfunction<cr>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]]}

  end)

  it("works with cmdline window", function()
    feed(':make')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]], cmdline={{
      firstc = ":",
      content = {{"make"}},
      pos = 4,
    }}}

    feed('<c-f>')
    screen:expect{grid=[[
                               |
      {2:[No Name]                }|
      {1::}make^                    |
      {3:[Command Line]           }|
                               |
    ]]}

    -- nested cmdline
    feed(':yank')
    screen:expect{grid=[[
                               |
      {2:[No Name]                }|
      {1::}make^                    |
      {3:[Command Line]           }|
                               |
    ]], cmdline={nil, {
      firstc = ":",
      content = {{"yank"}},
      pos = 4,
    }}}

    command("mode")
    screen:expect{grid=[[
                               |
      {2:[No Name]                }|
      {1::}make^                    |
      {3:[Command Line]           }|
                               |
    ]], cmdline={nil, {
      firstc = ":",
      content = {{"yank"}},
      pos = 4,
    }}, reset=true}

    feed("<c-c>")
    screen:expect{grid=[[
                               |
      {2:[No Name]                }|
      {1::}make^                    |
      {3:[Command Line]           }|
                               |
    ]]}

    feed("<c-c>")
    screen:expect{grid=[[
      ^                         |
      {2:[No Name]                }|
      {1::}make                    |
      {3:[Command Line]           }|
                               |
    ]], cmdline={{
      firstc = ":",
      content = {{"make"}},
      pos = 4,
    }}}

    command("redraw!")
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]], cmdline={{
      firstc = ":",
      content = {{"make"}},
      pos = 4,
    }}}
  end)

  it('works with inputsecret()', function()
    feed(":call inputsecret('secret:')<cr>abc123")
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]], cmdline={{
      prompt = "secret:",
      content = {{"******"}},
      pos = 6,
    }}}
  end)

  it('works with highlighted cmdline', function()
    source([[
      highlight RBP1 guibg=Red
      highlight RBP2 guibg=Yellow
      highlight RBP3 guibg=Green
      highlight RBP4 guibg=Blue
      let g:NUM_LVLS = 4
      function RainBowParens(cmdline)
        let ret = []
        let i = 0
        let lvl = 0
        while i < len(a:cmdline)
          if a:cmdline[i] is# '('
            call add(ret, [i, i + 1, 'RBP' . ((lvl % g:NUM_LVLS) + 1)])
            let lvl += 1
          elseif a:cmdline[i] is# ')'
            let lvl -= 1
            call add(ret, [i, i + 1, 'RBP' . ((lvl % g:NUM_LVLS) + 1)])
          endif
          let i += 1
        endwhile
        return ret
      endfunction
      map <f5>  :let x = input({'prompt':'>','highlight':'RainBowParens'})<cr>
      "map <f5>  :let x = input({'prompt':'>'})<cr>
    ]])
    screen:set_default_attr_ids({
      RBP1={background = Screen.colors.Red},
      RBP2={background = Screen.colors.Yellow},
      EOB={bold = true, foreground = Screen.colors.Blue1},
    })
    feed('<f5>(a(b)a)')
    screen:expect{grid=[[
      ^                         |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
                               |
    ]], cmdline={{
      prompt = '>',
      content = {{'(', 'RBP1'}, {'a'}, {'(', 'RBP2'}, {'b'},
                 { ')', 'RBP2'}, {'a'}, {')', 'RBP1'}},
      pos = 7,
    }}}
  end)

  it('works together with ext_wildmenu', function()
    local expected = {
      'define',
      'jump',
      'list',
      'place',
      'undefine',
      'unplace',
    }

    command('set wildmode=full')
    command('set wildmenu')
    screen:set_option('ext_wildmenu', true)
    feed(':sign <tab>')

    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]], cmdline={{
      firstc = ":",
      content = {{"sign define"}},
      pos = 11,
    }}, wildmenu_items=expected, wildmenu_pos=0}

    feed('<tab>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]], cmdline={{
      firstc = ":",
      content = {{"sign jump"}},
      pos = 9,
    }}, wildmenu_items=expected, wildmenu_pos=1}

    feed('<left><left>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]], cmdline={{
      firstc = ":",
      content = {{"sign "}},
      pos = 5,
    }}, wildmenu_items=expected, wildmenu_pos=-1}

    feed('<right>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]], cmdline={{
      firstc = ":",
      content = {{"sign define"}},
      pos = 11,
    }}, wildmenu_items=expected, wildmenu_pos=0}

    feed('a')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]], cmdline={{
      firstc = ":",
      content = {{"sign definea"}},
      pos = 12,
    }}}
  end)

  it('works together with ext_popupmenu', function()
    local expected = {
        {'define', '', '', ''},
        {'jump', '', '', ''},
        {'list', '', '', ''},
        {'place', '', '', ''},
        {'undefine', '', '', ''},
        {'unplace', '', '', ''},
    }

    command('set wildmode=full')
    command('set wildmenu')
    screen:set_option('ext_popupmenu', true)
    feed(':sign <tab>')

    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]], cmdline={{
      firstc = ":",
      content = {{"sign define"}},
      pos = 11,
    }}, popupmenu={items=expected, pos=0, anchor={-1, 0, 5}}}

    feed('<tab>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]], cmdline={{
      firstc = ":",
      content = {{"sign jump"}},
      pos = 9,
    }}, popupmenu={items=expected, pos=1, anchor={-1, 0, 5}}}

    feed('<left><left>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]], cmdline={{
      firstc = ":",
      content = {{"sign "}},
      pos = 5,
    }}, popupmenu={items=expected, pos=-1, anchor={-1, 0, 5}}}

    feed('<right>')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]], cmdline={{
      firstc = ":",
      content = {{"sign define"}},
      pos = 11,
    }}, popupmenu={items=expected, pos=0, anchor={-1, 0, 5}}}

    feed('a')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]], cmdline={{
      firstc = ":",
      content = {{"sign definea"}},
      pos = 12,
    }}}
    feed('<esc>')

    -- check positioning with multibyte char in pattern
    command("e långfile1")
    command("sp långfile2")
    feed(':b lå<tab>')
    screen:expect{grid=[[
      ^                         |
      {3:långfile2                }|
                               |
      {2:långfile1                }|
                               |
    ]], popupmenu={
      anchor = { -1, 0, 2 },
      items = {{ "långfile1", "", "", "" }, { "långfile2", "", "", "" }},
      pos = 0
    }, cmdline={{
      content = {{ "b långfile1" }},
      firstc = ":",
      pos = 12
    }}}
  end)

  it('ext_wildmenu takes precedence over ext_popupmenu', function()
    local expected = {
      'define',
      'jump',
      'list',
      'place',
      'undefine',
      'unplace',
    }

    command('set wildmode=full')
    command('set wildmenu')
    screen:set_option('ext_wildmenu', true)
    screen:set_option('ext_popupmenu', true)
    feed(':sign <tab>')

    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]], cmdline={{
      firstc = ":",
      content = {{"sign define"}},
      pos = 11,
    }}, wildmenu_items=expected, wildmenu_pos=0}
  end)

  it("doesn't send invalid events when aborting mapping #10000", function()
    command('cnoremap ab c')

    feed(':xa')
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]], cmdline={{
      content = { { "x" } },
      firstc = ":",
      pos = 1,
      special = { "a", false }
    }}}

    -- This used to send an invalid event where pos where larger than the total
    -- length of content. Checked in _handle_cmdline_show.
    feed('<esc>')
    screen:expect([[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]])
  end)

end

-- the representation of cmdline and cmdline_block contents changed with ext_linegrid
-- (which uses indexed highlights) so make sure to test both
describe('ui/ext_cmdline', function() test_cmdline(true) end)
describe('ui/ext_cmdline (legacy highlights)', function() test_cmdline(false) end)

describe('cmdline redraw', function()
  local screen
  before_each(function()
    clear()
    screen = new_screen({rgb=true})
  end)

  it('with timer', function()
    feed(':012345678901234567890123456789')
    screen:expect{grid=[[
                             |
    {1:~                        }|
    {3:                         }|
    :012345678901234567890123|
    456789^                   |
    ]]}
    command('call timer_start(0, {-> 1})')
    screen:expect{grid=[[
                             |
    {1:~                        }|
    {3:                         }|
    :012345678901234567890123|
    456789^                   |
    ]], unchanged=true, timeout=100}
  end)

  it('with <Cmd>', function()
    if 'openbsd' == helpers.uname() then
      pending('FIXME #10804')
    end
    command('cmap a <Cmd>call sin(0)<CR>')  -- no-op
    feed(':012345678901234567890123456789')
    screen:expect{grid=[[
                             |
    {1:~                        }|
    {3:                         }|
    :012345678901234567890123|
    456789^                   |
    ]]}
    feed('a')
    screen:expect{grid=[[
                             |
    {1:~                        }|
    {3:                         }|
    :012345678901234567890123|
    456789^                   |
    ]], unchanged=true}
  end)
end)
