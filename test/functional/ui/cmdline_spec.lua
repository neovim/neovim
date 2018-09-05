local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed = helpers.clear, helpers.feed
local source = helpers.source
local command = helpers.command

local function test_cmdline(newgrid)
  local screen

  before_each(function()
    clear()
    screen = Screen.new(25, 5)
    screen:attach({rgb=true, ext_cmdline=true, ext_newgrid=newgrid})
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue1},
      [2] = {reverse = true},
      [3] = {bold = true, reverse = true},
      [4] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
      [5] = {bold = true, foreground = Screen.colors.SeaGreen4},
    })
  end)

  after_each(function()
    screen:detach()
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

    it('but not with scrolled messages', function()
      screen:try_resize(50,10)
      feed(':echoerr doesnotexist<cr>')
      screen:expect{grid=[[
                                                          |
        {1:~                                                 }|
        {1:~                                                 }|
        {1:~                                                 }|
        {1:~                                                 }|
        {1:~                                                 }|
        {3:                                                  }|
        {4:E121: Undefined variable: doesnotexist}            |
        {4:E15: Invalid expression: doesnotexist}             |
        {5:Press ENTER or type command to continue}^           |
      ]]}
      feed(':echoerr doesnotexist<cr>')
      screen:expect{grid=[[
                                                          |
        {1:~                                                 }|
        {1:~                                                 }|
        {1:~                                                 }|
        {3:                                                  }|
        {4:E121: Undefined variable: doesnotexist}            |
        {4:E15: Invalid expression: doesnotexist}             |
        {4:E121: Undefined variable: doesnotexist}            |
        {4:E15: Invalid expression: doesnotexist}             |
        {5:Press ENTER or type command to continue}^           |
      ]]}

      feed(':echoerr doesnotexist<cr>')
      screen:expect{grid=[[
                                                          |
        {1:~                                                 }|
        {3:                                                  }|
        {4:E121: Undefined variable: doesnotexist}            |
        {4:E15: Invalid expression: doesnotexist}             |
        {4:E121: Undefined variable: doesnotexist}            |
        {4:E15: Invalid expression: doesnotexist}             |
        {4:E121: Undefined variable: doesnotexist}            |
        {4:E15: Invalid expression: doesnotexist}             |
        {5:Press ENTER or type command to continue}^           |
      ]]}

      feed('<cr>')
      screen:expect{grid=[[
        ^                                                  |
        {1:~                                                 }|
        {1:~                                                 }|
        {1:~                                                 }|
        {1:~                                                 }|
        {1:~                                                 }|
        {1:~                                                 }|
        {1:~                                                 }|
        {3:n                                                 }|
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
    -- TODO(bfredl): when we add a flag to screen:expect{}
    -- to explicitly check redraw!, it should also do this
    screen.cmdline = {}
    command("redraw!")
    screen:expect{grid=[[
      ^                         |
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
                               |
    ]], cmdline=expectation}


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

    screen.cmdline_block = {}
    command("redraw!")
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

    screen.cmdline = {}
    command("redraw!")
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
                               |
      {2:[No Name]                }|
      {1::}make^                    |
      {3:[Command Line]           }|
                               |
    ]], cmdline={{
      firstc = ":",
      content = {{"make"}},
      pos = 4,
    }}}

    screen.cmdline = {}
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
end

-- the representation of cmdline and cmdline_block contents changed with ext_newgrid
-- (which uses indexed highlights) so make sure to test both
describe('ui/ext_cmdline', function() test_cmdline(true) end)
describe('ui/ext_cmdline (legacy highlights)', function() test_cmdline(false) end)
