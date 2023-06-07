local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local spawn, set_session, clear = helpers.spawn, helpers.set_session, helpers.clear
local feed, command = helpers.feed, helpers.command
local insert = helpers.insert
local eq = helpers.eq
local eval = helpers.eval
local funcs, meths = helpers.funcs, helpers.meths

describe('screen', function()
  local screen
  local nvim_argv = {helpers.nvim_prog, '-u', 'NONE', '-i', 'NONE', '-N',
                     '--cmd', 'set shortmess+=I background=light noswapfile belloff= noshowcmd noruler',
                     '--embed'}

  before_each(function()
    local screen_nvim = spawn(nvim_argv)
    set_session(screen_nvim)
    screen = Screen.new()
    screen:attach()
    screen:set_default_attr_ids( {
      [0] = {bold=true, foreground=255},
      [1] = {bold=true, reverse=true},
    } )
  end)

  it('default initial screen', function()
      screen:expect([[
      ^                                                     |
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {1:[No Name]                                            }|
                                                           |
    ]])
  end)
end)

local function screen_tests(linegrid)
  local screen

  before_each(function()
    clear()
    screen = Screen.new()
    screen:attach({rgb=true,ext_linegrid=linegrid})
    screen:set_default_attr_ids( {
      [0] = {bold=true, foreground=255},
      [1] = {bold=true, reverse=true},
      [2] = {bold=true},
      [3] = {reverse=true},
      [4] = {background = Screen.colors.LightGrey, underline = true},
      [5] = {background = Screen.colors.LightGrey, underline = true, bold = true, foreground = Screen.colors.Fuchsia},
      [6] = {bold = true, foreground = Screen.colors.Fuchsia},
      [7] = {bold = true, foreground = Screen.colors.SeaGreen},
      [8] = {foreground = Screen.colors.White, background = Screen.colors.Red},
    } )
  end)

  describe(':suspend', function()
    it('is forwarded to the UI', function()
      local function check()
        eq(true, screen.suspended)
      end

      command('let g:ev = []')
      command('autocmd VimResume  * :call add(g:ev, "r")')
      command('autocmd VimSuspend * :call add(g:ev, "s")')

      eq(false, screen.suspended)
      command('suspend')
      eq({ 's', 'r' }, eval('g:ev'))

      screen:expect(check)
      screen.suspended = false

      feed('<c-z>')
      eq({ 's', 'r', 's', 'r' }, eval('g:ev'))

      screen:expect(check)
      screen.suspended = false

      command('suspend')
      eq({ 's', 'r', 's', 'r', 's', 'r' }, eval('g:ev'))
    end)
  end)

  describe('bell/visual bell', function()
    it('is forwarded to the UI', function()
      feed('<left>')
      screen:expect(function()
        eq(true, screen.bell)
        eq(false, screen.visual_bell)
      end)
      screen.bell = false
      command('set visualbell')
      feed('<left>')
      screen:expect(function()
        eq(true, screen.visual_bell)
        eq(false, screen.bell)
      end)
    end)
  end)

  describe(':set title', function()
    it('is forwarded to the UI', function()
      local expected = 'test-title'
      command('set titlestring='..expected)
      command('set title')
      screen:expect(function()
        eq(expected, screen.title)
      end)
      screen:detach()
      screen.title = nil
      screen:attach()
      screen:expect(function()
        eq(expected, screen.title)
      end)
    end)
  end)

  describe(':set icon', function()
    it('is forwarded to the UI', function()
      local expected = 'test-icon'
      command('set iconstring='..expected)
      command('set icon')
      screen:expect(function()
        eq(expected, screen.icon)
      end)
      screen:detach()
      screen.icon = nil
      screen:attach()
      screen:expect(function()
        eq(expected, screen.icon)
      end)
    end)
  end)

  describe('statusline', function()
    it('is redrawn after <c-l>', function()
      command('set laststatus=2')
      screen:expect([[
        ^                                                     |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {1:[No Name]                                            }|
                                                             |
      ]])

      feed('<c-l>')
      screen:expect{grid=[[
        ^                                                     |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {1:[No Name]                                            }|
                                                             |
      ]], reset=true}

      command('split')
      screen:expect([[
        ^                                                     |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {1:[No Name]                                            }|
                                                             |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {3:[No Name]                                            }|
                                                             |
      ]])

      feed('<c-l>')
      screen:expect{grid=[[
        ^                                                     |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {1:[No Name]                                            }|
                                                             |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {3:[No Name]                                            }|
                                                             |
      ]], reset=true}
    end)
  end)

  describe('window', function()
    describe('split', function()
      it('horizontal', function()
        command('sp')
        screen:expect([[
          ^                                                     |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {1:[No Name]                                            }|
                                                               |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {3:[No Name]                                            }|
                                                               |
        ]])
      end)

      it('horizontal and resize', function()
        command('sp')
        command('resize 8')
        screen:expect([[
          ^                                                     |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {1:[No Name]                                            }|
                                                               |
          {0:~                                                    }|
          {0:~                                                    }|
          {3:[No Name]                                            }|
                                                               |
        ]])
      end)

      it('horizontal and vertical', function()
        command('sp')
        command('vsp')
        command('vsp')
        screen:expect([[
          ^                    │                │               |
          {0:~                   }│{0:~               }│{0:~              }|
          {0:~                   }│{0:~               }│{0:~              }|
          {0:~                   }│{0:~               }│{0:~              }|
          {0:~                   }│{0:~               }│{0:~              }|
          {0:~                   }│{0:~               }│{0:~              }|
          {1:[No Name]            }{3:[No Name]        [No Name]      }|
                                                               |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {3:[No Name]                                            }|
                                                               |
        ]])
        insert('hello')
        screen:expect([[
          hell^o               │hello           │hello          |
          {0:~                   }│{0:~               }│{0:~              }|
          {0:~                   }│{0:~               }│{0:~              }|
          {0:~                   }│{0:~               }│{0:~              }|
          {0:~                   }│{0:~               }│{0:~              }|
          {0:~                   }│{0:~               }│{0:~              }|
          {1:[No Name] [+]        }{3:[No Name] [+]    [No Name] [+]  }|
          hello                                                |
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {0:~                                                    }|
          {3:[No Name] [+]                                        }|
                                                               |
        ]])
      end)
    end)
  end)

  describe('tabs', function()
    it('tabnew creates a new buffer', function()
      command('sp')
      command('vsp')
      command('vsp')
      insert('hello')
      screen:expect([[
        hell^o               │hello           │hello          |
        {0:~                   }│{0:~               }│{0:~              }|
        {0:~                   }│{0:~               }│{0:~              }|
        {0:~                   }│{0:~               }│{0:~              }|
        {0:~                   }│{0:~               }│{0:~              }|
        {0:~                   }│{0:~               }│{0:~              }|
        {1:[No Name] [+]        }{3:[No Name] [+]    [No Name] [+]  }|
        hello                                                |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {3:[No Name] [+]                                        }|
                                                             |
      ]])
      command('tabnew')
      insert('hello2')
      feed('h')
      screen:expect([[
        {4: }{5:4}{4:+ [No Name] }{2: + [No Name] }{3:                         }{4:X}|
        hell^o2                                               |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
                                                             |
      ]])
      command('tabprevious')
      screen:expect([[
        {2: }{6:4}{2:+ [No Name] }{4: + [No Name] }{3:                         }{4:X}|
        hell^o               │hello           │hello          |
        {0:~                   }│{0:~               }│{0:~              }|
        {0:~                   }│{0:~               }│{0:~              }|
        {0:~                   }│{0:~               }│{0:~              }|
        {0:~                   }│{0:~               }│{0:~              }|
        {0:~                   }│{0:~               }│{0:~              }|
        {1:[No Name] [+]        }{3:[No Name] [+]    [No Name] [+]  }|
        hello                                                |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {3:[No Name] [+]                                        }|
                                                             |
      ]])
    end)

    it('tabline is redrawn after messages', function()
      command('tabnew')
      screen:expect([[
        {4: [No Name] }{2: [No Name] }{3:                              }{4:X}|
        ^                                                     |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
                                                             |
      ]])

      feed(':echo "'..string.rep('x\\n', 11)..'"<cr>')
      screen:expect([[
        {1:                                                     }|
        x                                                    |
        x                                                    |
        x                                                    |
        x                                                    |
        x                                                    |
        x                                                    |
        x                                                    |
        x                                                    |
        x                                                    |
        x                                                    |
        x                                                    |
                                                             |
        {7:Press ENTER or type command to continue}^              |
      ]])

      feed('<cr>')
      screen:expect([[
        {4: [No Name] }{2: [No Name] }{3:                              }{4:X}|
        ^                                                     |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
                                                             |
      ]])

      feed(':echo "'..string.rep('x\\n', 12)..'"<cr>')
      screen:expect([[
        x                                                    |
        x                                                    |
        x                                                    |
        x                                                    |
        x                                                    |
        x                                                    |
        x                                                    |
        x                                                    |
        x                                                    |
        x                                                    |
        x                                                    |
        x                                                    |
                                                             |
        {7:Press ENTER or type command to continue}^              |
      ]])

      feed('<cr>')
      screen:expect([[
        {4: [No Name] }{2: [No Name] }{3:                              }{4:X}|
        ^                                                     |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
                                                             |
      ]])

    end)

    it('redraws properly with :tab split right after scroll', function()
      feed('15Ofoo<esc>15Obar<esc>gg')

      command('vsplit')
      screen:expect([[
        ^foo                       │foo                       |
        foo                       │foo                       |
        foo                       │foo                       |
        foo                       │foo                       |
        foo                       │foo                       |
        foo                       │foo                       |
        foo                       │foo                       |
        foo                       │foo                       |
        foo                       │foo                       |
        foo                       │foo                       |
        foo                       │foo                       |
        foo                       │foo                       |
        {1:[No Name] [+]              }{3:[No Name] [+]             }|
                                                             |
      ]])

      feed('<PageDown>')
      screen:expect([[
        ^foo                       │foo                       |
        foo                       │foo                       |
        foo                       │foo                       |
        foo                       │foo                       |
        bar                       │foo                       |
        bar                       │foo                       |
        bar                       │foo                       |
        bar                       │foo                       |
        bar                       │foo                       |
        bar                       │foo                       |
        bar                       │foo                       |
        bar                       │foo                       |
        {1:[No Name] [+]              }{3:[No Name] [+]             }|
                                                             |
      ]])
      command('tab split')
      screen:expect([[
        {4: }{5:2}{4:+ [No Name] }{2: + [No Name] }{3:                         }{4:X}|
        ^foo                                                  |
        foo                                                  |
        foo                                                  |
        foo                                                  |
        bar                                                  |
        bar                                                  |
        bar                                                  |
        bar                                                  |
        bar                                                  |
        bar                                                  |
        bar                                                  |
        bar                                                  |
                                                             |
      ]])
    end)

    it('redraws unvisited tab #9152', function()
      insert('hello')
      -- create a tab without visiting it
      command('tabnew|tabnext')
      screen:expect([[
        {2: + [No Name] }{4: [No Name] }{3:                            }{4:X}|
        hell^o                                                |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
                                                             |
      ]])

      feed('gT')
      screen:expect([[
        {4: + [No Name] }{2: [No Name] }{3:                            }{4:X}|
        ^                                                     |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
                                                             |
      ]])
    end)
  end)

  describe('insert mode', function()
    it('move to next line with <cr>', function()
      feed('iline 1<cr>line 2<cr>')
      screen:expect([[
        line 1                                               |
        line 2                                               |
        ^                                                     |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {2:-- INSERT --}                                         |
      ]])
    end)
  end)

  describe('normal mode', function()
    -- https://code.google.com/p/vim/issues/detail?id=339
    it("setting 'ruler' doesn't reset the preferred column", function()
      command('set virtualedit=')
      feed('i0123456<cr>789<esc>kllj')
      command('set ruler')
      feed('k')
      screen:expect([[
        0123^456                                              |
        789                                                  |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
                                           1,5           All |
      ]])
    end)
  end)

  describe('command mode', function()
    it('typing commands', function()
      feed(':ls')
      screen:expect([[
                                                             |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        :ls^                                                  |
      ]])
    end)

    it('execute command with multi-line output', function()
      feed(':ls<cr>')
      screen:expect([[
                                                             |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {1:                                                     }|
        :ls                                                  |
          1 %a   "[No Name]"                    line 1       |
        {7:Press ENTER or type command to continue}^              |
      ]])
      feed('<cr>') --  skip the "Press ENTER..." state or tests will hang
    end)
  end)

  describe('scrolling and clearing', function()
    before_each(function()
      insert([[
      Inserting
      text
      with
      many
      lines
      to
      test
      scrolling
      and
      clearing
      in
      split
      windows
      ]])
      command('sp')
      command('vsp')
      command('vsp')
      screen:expect([[
        and                 │and             │and            |
        clearing            │clearing        │clearing       |
        in                  │in              │in             |
        split               │split           │split          |
        windows             │windows         │windows        |
        ^                    │                │               |
        {1:[No Name] [+]        }{3:[No Name] [+]    [No Name] [+]  }|
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        {3:[No Name] [+]                                        }|
                                                             |
      ]])
    end)

    it('only affects the current scroll region', function()
      feed('6k')
      screen:expect([[
        ^scrolling           │and             │and            |
        and                 │clearing        │clearing       |
        clearing            │in              │in             |
        in                  │split           │split          |
        split               │windows         │windows        |
        windows             │                │               |
        {1:[No Name] [+]        }{3:[No Name] [+]    [No Name] [+]  }|
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        {3:[No Name] [+]                                        }|
                                                             |
      ]])
      feed('<c-w>l')
      screen:expect([[
        scrolling           │and                 │and        |
        and                 │clearing            │clearing   |
        clearing            │in                  │in         |
        in                  │split               │split      |
        split               │windows             │windows    |
        windows             │^                    │           |
        {3:[No Name] [+]        }{1:[No Name] [+]        }{3:<Name] [+] }|
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        {3:[No Name] [+]                                        }|
                                                             |
      ]])
      feed('gg')
      screen:expect([[
        scrolling           │^Inserting           │and        |
        and                 │text                │clearing   |
        clearing            │with                │in         |
        in                  │many                │split      |
        split               │lines               │windows    |
        windows             │to                  │           |
        {3:[No Name] [+]        }{1:[No Name] [+]        }{3:<Name] [+] }|
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        {3:[No Name] [+]                                        }|
                                                             |
      ]])
      feed('7j')
      screen:expect([[
        scrolling           │with                │and        |
        and                 │many                │clearing   |
        clearing            │lines               │in         |
        in                  │to                  │split      |
        split               │test                │windows    |
        windows             │^scrolling           │           |
        {3:[No Name] [+]        }{1:[No Name] [+]        }{3:<Name] [+] }|
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        {3:[No Name] [+]                                        }|
                                                             |
      ]])
      feed('2j')
      screen:expect([[
        scrolling           │lines               │and        |
        and                 │to                  │clearing   |
        clearing            │test                │in         |
        in                  │scrolling           │split      |
        split               │and                 │windows    |
        windows             │^clearing            │           |
        {3:[No Name] [+]        }{1:[No Name] [+]        }{3:<Name] [+] }|
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        {3:[No Name] [+]                                        }|
                                                             |
      ]])
      feed('5k')
      screen:expect([[
        scrolling           │^lines               │and        |
        and                 │to                  │clearing   |
        clearing            │test                │in         |
        in                  │scrolling           │split      |
        split               │and                 │windows    |
        windows             │clearing            │           |
        {3:[No Name] [+]        }{1:[No Name] [+]        }{3:<Name] [+] }|
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        {3:[No Name] [+]                                        }|
                                                             |
      ]])
      feed('k')
      screen:expect([[
        scrolling           │^many                │and        |
        and                 │lines               │clearing   |
        clearing            │to                  │in         |
        in                  │test                │split      |
        split               │scrolling           │windows    |
        windows             │and                 │           |
        {3:[No Name] [+]        }{1:[No Name] [+]        }{3:<Name] [+] }|
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        {3:[No Name] [+]                                        }|
                                                             |
      ]])
    end)
  end)

  describe('resize', function()
    it('rebuilds the whole screen', function()
      screen:try_resize(25, 5)
      feed('iresize')
      screen:expect([[
        resize^                   |
        {0:~                        }|
        {0:~                        }|
        {0:~                        }|
        {2:-- INSERT --}             |
      ]])
    end)

    it('has minimum width/height values', function()
      feed('iresize')
      screen:try_resize(1, 1)
      screen:expect([[
        resize^      |
        {2:-- INSERT -} |
      ]])

      feed('<esc>:ls')
      screen:expect([[
        resize      |
        :ls^         |
      ]])
    end)

    it('VimResized autocommand does not cause invalid UI events #20692 #20759', function()
      screen:try_resize(25, 5)
      feed('iresize<Esc>')
      command([[autocmd VimResized * redrawtabline]])
      command([[autocmd VimResized * lua vim.api.nvim_echo({ { 'Hello' } }, false, {})]])
      command([[autocmd VimResized * let g:echospace = v:echospace]])
      meths.set_option_value('showtabline', 2, {})
      screen:expect([[
        {2: + [No Name] }{3:            }|
        resiz^e                   |
        {0:~                        }|
        {0:~                        }|
                                 |
      ]])
      screen:try_resize(30, 6)
      screen:expect([[
        {2: + [No Name] }{3:                 }|
        resiz^e                        |
        {0:~                             }|
        {0:~                             }|
        {0:~                             }|
                                      |
      ]])
      eq(29, meths.get_var('echospace'))
    end)

    it('messages from the same Ex command as resize are visible #22225', function()
      feed(':set columns=20 | call<CR>')
      screen:expect([[
                            |
                            |
                            |
                            |
                            |
                            |
                            |
                            |
                            |
        {1:                    }|
        {8:E471: Argument requi}|
        {8:red}                 |
        {7:Press ENTER or type }|
        {7:command to continue}^ |
      ]])
      feed('<CR>')
      screen:expect([[
        ^                    |
        {0:~                   }|
        {0:~                   }|
        {0:~                   }|
        {0:~                   }|
        {0:~                   }|
        {0:~                   }|
        {0:~                   }|
        {0:~                   }|
        {0:~                   }|
        {0:~                   }|
        {0:~                   }|
        {0:~                   }|
                            |
      ]])
      feed(':set columns=0<CR>')
      screen:expect([[
                    |
                    |
                    |
                    |
                    |
        {1:            }|
        {8:E594: Need a}|
        {8:t least 12 c}|
        {8:olumns: colu}|
        {8:mns=0}       |
        {7:Press ENTER }|
        {7:or type comm}|
        {7:and to conti}|
        {7:nue}^         |
      ]])
      feed('<CR>')
      screen:expect([[
        ^            |
        {0:~           }|
        {0:~           }|
        {0:~           }|
        {0:~           }|
        {0:~           }|
        {0:~           }|
        {0:~           }|
        {0:~           }|
        {0:~           }|
        {0:~           }|
        {0:~           }|
        {0:~           }|
                    |
      ]])
    end)
  end)

  describe('press enter', function()
    it('does not crash on <F1> at “Press ENTER”', function()
      command('nnoremap <F1> :echo "TEST"<CR>')
      feed(':ls<CR>')
      screen:expect([[
                                                             |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {1:                                                     }|
        :ls                                                  |
          1 %a   "[No Name]"                    line 1       |
        {7:Press ENTER or type command to continue}^              |
      ]])
      feed('<F1>')
      screen:expect([[
        ^                                                     |
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        {0:~                                                    }|
        TEST                                                 |
      ]])
    end)
  end)

  -- Regression test for #8357
  it('does not have artifacts after temporary chars in insert mode', function()
    command('set timeoutlen=10000')
    command('inoremap jk <esc>')
    feed('ifooj')
    screen:expect([[
      foo^j                                                 |
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {2:-- INSERT --}                                         |
    ]])
    feed('k')
    screen:expect([[
      fo^o                                                  |
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
      {0:~                                                    }|
                                                           |
    ]])
  end)
end

describe("Screen (char-based)", function()
  screen_tests(false)
end)

describe("Screen (line-based)", function()
  screen_tests(true)
end)

describe('Screen default colors', function()
  local screen
  local function startup(light, termcolors)
    local extra = (light and ' background=light') or ''

    local nvim_argv = {helpers.nvim_prog, '-u', 'NONE', '-i', 'NONE', '-N',
                       '--cmd', 'set shortmess+=I noswapfile belloff= noshowcmd noruler'..extra,
                       '--embed'}
    local screen_nvim = spawn(nvim_argv)
    set_session(screen_nvim)
    screen = Screen.new()
    screen:attach(termcolors and {rgb=true,ext_termcolors=true} or {rgb=true})
  end

  it('are dark per default', function()
    startup(false, false)
    screen:expect{condition=function()
      eq({rgb_bg=0, rgb_fg=Screen.colors.White, rgb_sp=Screen.colors.Red,
          cterm_bg=0, cterm_fg=0}, screen.default_colors)
    end}
  end)

  it('can be set to light', function()
    startup(true, false)
    screen:expect{condition=function()
      eq({rgb_fg=Screen.colors.White, rgb_bg=0, rgb_sp=Screen.colors.Red,
          cterm_bg=0, cterm_fg=0}, screen.default_colors)
    end}
  end)

  it('can be handled by external terminal', function()
    startup(false, true)
    screen:expect{condition=function()
      eq({rgb_bg=-1, rgb_fg=-1, rgb_sp=-1, cterm_bg=0, cterm_fg=0}, screen.default_colors)
    end}

    startup(true, true)
    screen:expect{condition=function()
      eq({rgb_bg=-1, rgb_fg=-1, rgb_sp=-1, cterm_bg=0, cterm_fg=0}, screen.default_colors)
    end}
  end)
end)

it('CTRL-F or CTRL-B scrolls a page after UI attach/resize #20605', function()
  clear()
  local screen = Screen.new(100, 100)
  screen:attach()
  eq(100, meths.get_option_value('lines', {}))
  eq(99, meths.get_option_value('window', {}))
  eq(99, meths.win_get_height(0))
  feed('1000o<Esc>')
  eq(903, funcs.line('w0'))
  feed('<C-B>')
  eq(806, funcs.line('w0'))
  feed('<C-B>')
  eq(709, funcs.line('w0'))
  feed('<C-F>')
  eq(806, funcs.line('w0'))
  feed('<C-F>')
  eq(903, funcs.line('w0'))
  feed('G')
  screen:try_resize(50, 50)
  eq(50, meths.get_option_value('lines', {}))
  eq(49, meths.get_option_value('window', {}))
  eq(49, meths.win_get_height(0))
  eq(953, funcs.line('w0'))
  feed('<C-B>')
  eq(906, funcs.line('w0'))
  feed('<C-B>')
  eq(859, funcs.line('w0'))
  feed('<C-F>')
  eq(906, funcs.line('w0'))
  feed('<C-F>')
  eq(953, funcs.line('w0'))
end)

it("showcmd doesn't cause empty grid_line with redrawdebug=compositor #22593", function()
  clear()
  local screen = Screen.new(30, 2)
  screen:set_default_attr_ids({
    [0] = {bold = true, foreground = Screen.colors.Blue},
  })
  screen:attach()
  command('set showcmd redrawdebug=compositor')
  feed('d')
  screen:expect{grid=[[
    ^                              |
                       d          |
  ]]}
end)
