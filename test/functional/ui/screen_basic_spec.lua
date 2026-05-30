local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local set_session, clear, assert_alive = n.set_session, n.clear, n.assert_alive
local feed, command = n.feed, n.command
local exec, exec_lua = n.exec, n.exec_lua
local insert = n.insert
local eq = t.eq
local fn, api = n.fn, n.api

describe('screen', function()
  local screen
  local nvim_argv = {
    n.nvim_prog,
    '-u',
    'NONE',
    '-i',
    'NONE',
    '-n',
    '--cmd',
    'set shortmess+=I background=light noswapfile belloff= noshowcmd noruler',
    '--cmd',
    'colorscheme vim',
    '--embed',
  }

  before_each(function()
    local screen_nvim = n.new_session(false, { args = nvim_argv, merge = false })
    set_session(screen_nvim)
    screen = Screen.new()
  end)

  it('default initial screen', function()
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*11
      {3:[No Name]                                            }|
                                                           |
    ]])
  end)
end)

local function screen_tests(linegrid)
  local screen

  before_each(function()
    clear()
    screen = Screen.new(53, 14, { rgb = true, ext_linegrid = linegrid })
    screen:add_extra_attr_ids({
      [100] = {
        background = Screen.colors.LightGrey,
        underline = true,
        bold = true,
        foreground = Screen.colors.Fuchsia,
      },
      [101] = { bold = true, foreground = Screen.colors.Magenta1 },
    })
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
      command('set titlestring=' .. expected)
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
      command('set iconstring=' .. expected)
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
        {1:~                                                    }|*11
        {3:[No Name]                                            }|
                                                             |
      ]])

      feed('<c-l>')
      screen:expect {
        grid = [[
        ^                                                     |
        {1:~                                                    }|*11
        {3:[No Name]                                            }|
                                                             |
      ]],
        reset = true,
      }

      command('split')
      screen:expect([[
        ^                                                     |
        {1:~                                                    }|*5
        {3:[No Name]                                            }|
                                                             |
        {1:~                                                    }|*4
        {2:[No Name]                                            }|
                                                             |
      ]])

      feed('<c-l>')
      screen:expect {
        grid = [[
        ^                                                     |
        {1:~                                                    }|*5
        {3:[No Name]                                            }|
                                                             |
        {1:~                                                    }|*4
        {2:[No Name]                                            }|
                                                             |
      ]],
        reset = true,
      }
    end)
  end)

  describe('window', function()
    describe('split', function()
      it('horizontal', function()
        command('sp')
        screen:expect([[
          ^                                                     |
          {1:~                                                    }|*5
          {3:[No Name]                                            }|
                                                               |
          {1:~                                                    }|*4
          {2:[No Name]                                            }|
                                                               |
        ]])
      end)

      it('horizontal and resize', function()
        command('sp')
        command('resize 8')
        screen:expect([[
          ^                                                     |
          {1:~                                                    }|*7
          {3:[No Name]                                            }|
                                                               |
          {1:~                                                    }|*2
          {2:[No Name]                                            }|
                                                               |
        ]])
      end)

      it('horizontal and vertical', function()
        command('sp')
        command('vsp')
        command('vsp')
        screen:expect([[
          ^                    │                │               |
          {1:~                   }│{1:~               }│{1:~              }|*5
          {3:[No Name]            }{2:[No Name]        [No Name]      }|
                                                               |
          {1:~                                                    }|*4
          {2:[No Name]                                            }|
                                                               |
        ]])
        insert('hello')
        screen:expect([[
          hell^o               │hello           │hello          |
          {1:~                   }│{1:~               }│{1:~              }|*5
          {3:[No Name] [+]        }{2:[No Name] [+]    [No Name] [+]  }|
          hello                                                |
          {1:~                                                    }|*4
          {2:[No Name] [+]                                        }|
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
        {1:~                   }│{1:~               }│{1:~              }|*5
        {3:[No Name] [+]        }{2:[No Name] [+]    [No Name] [+]  }|
        hello                                                |
        {1:~                                                    }|*4
        {2:[No Name] [+]                                        }|
                                                             |
      ]])
      command('tabnew')
      insert('hello2')
      feed('h')
      screen:expect([[
        {24: }{100:4}{24:+ [No Name] }{5: + [No Name] }{2:                         }{24:X}|
        hell^o2                                               |
        {1:~                                                    }|*11
                                                             |
      ]])
      command('tabprevious')
      screen:expect([[
        {5: }{101:4}{5:+ [No Name] }{24: + [No Name] }{2:                         }{24:X}|
        hell^o               │hello           │hello          |
        {1:~                   }│{1:~               }│{1:~              }|*5
        {3:[No Name] [+]        }{2:[No Name] [+]    [No Name] [+]  }|
        hello                                                |
        {1:~                                                    }|*3
        {2:[No Name] [+]                                        }|
                                                             |
      ]])
    end)

    it('tabline is redrawn after messages', function()
      command('tabnew')
      screen:expect([[
        {24: [No Name] }{5: [No Name] }{2:                              }{24:X}|
        ^                                                     |
        {1:~                                                    }|*11
                                                             |
      ]])

      feed(':echo "' .. string.rep('x\\n', 11) .. '"<cr>')
      screen:expect([[
        {3:                                                     }|
        x                                                    |*11
                                                             |
        {6:Press ENTER or type command to continue}^              |
      ]])

      feed('<cr>')
      screen:expect([[
        {24: [No Name] }{5: [No Name] }{2:                              }{24:X}|
        ^                                                     |
        {1:~                                                    }|*11
                                                             |
      ]])

      feed(':echo "' .. string.rep('x\\n', 12) .. '"<cr>')
      screen:expect([[
        x                                                    |*12
                                                             |
        {6:Press ENTER or type command to continue}^              |
      ]])

      feed('<cr>')
      screen:expect([[
        {24: [No Name] }{5: [No Name] }{2:                              }{24:X}|
        ^                                                     |
        {1:~                                                    }|*11
                                                             |
      ]])
    end)

    it('redraws properly with :tab split right after scroll', function()
      feed('15Ofoo<esc>15Obar<esc>gg')

      command('vsplit')
      screen:expect([[
        ^foo                       │foo                       |
        foo                       │foo                       |*11
        {3:[No Name] [+]              }{2:[No Name] [+]             }|
                                                             |
      ]])

      feed('<PageDown>')
      screen:expect([[
        ^foo                       │foo                       |
        foo                       │foo                       |*3
        bar                       │foo                       |*8
        {3:[No Name] [+]              }{2:[No Name] [+]             }|
                                                             |
      ]])
      command('tab split')
      screen:expect([[
        {24: }{100:2}{24:+ [No Name] }{5: + [No Name] }{2:                         }{24:X}|
        ^foo                                                  |
        foo                                                  |*3
        bar                                                  |*8
                                                             |
      ]])
    end)

    it('redraws unvisited tab #9152', function()
      insert('hello')
      -- create a tab without visiting it
      command('tabnew|tabnext')
      screen:expect([[
        {5: + [No Name] }{24: [No Name] }{2:                            }{24:X}|
        hell^o                                                |
        {1:~                                                    }|*11
                                                             |
      ]])

      feed('gT')
      screen:expect([[
        {24: + [No Name] }{5: [No Name] }{2:                            }{24:X}|
        ^                                                     |
        {1:~                                                    }|*11
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
        {1:~                                                    }|*10
        {5:-- INSERT --}                                         |
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
        {1:~                                                    }|*11
                                           1,5           All |
      ]])
    end)
  end)

  describe('command mode', function()
    it('typing commands', function()
      feed(':ls')
      screen:expect([[
                                                             |
        {1:~                                                    }|*12
        :ls^                                                  |
      ]])
    end)

    it('execute command with multi-line output', function()
      feed(':ls<cr>')
      screen:expect([[
                                                             |
        {1:~                                                    }|*9
        {3:                                                     }|
        :ls                                                  |
          1 %a   "[No Name]"                    line 1       |
        {6:Press ENTER or type command to continue}^              |
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
        {3:[No Name] [+]        }{2:[No Name] [+]    [No Name] [+]  }|
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        {2:[No Name] [+]                                        }|
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
        {3:[No Name] [+]        }{2:[No Name] [+]    [No Name] [+]  }|
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        {2:[No Name] [+]                                        }|
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
        {2:[No Name] [+]        }{3:[No Name] [+]        }{2:<Name] [+] }|
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        {2:[No Name] [+]                                        }|
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
        {2:[No Name] [+]        }{3:[No Name] [+]        }{2:<Name] [+] }|
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        {2:[No Name] [+]                                        }|
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
        {2:[No Name] [+]        }{3:[No Name] [+]        }{2:<Name] [+] }|
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        {2:[No Name] [+]                                        }|
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
        {2:[No Name] [+]        }{3:[No Name] [+]        }{2:<Name] [+] }|
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        {2:[No Name] [+]                                        }|
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
        {2:[No Name] [+]        }{3:[No Name] [+]        }{2:<Name] [+] }|
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        {2:[No Name] [+]                                        }|
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
        {2:[No Name] [+]        }{3:[No Name] [+]        }{2:<Name] [+] }|
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        {2:[No Name] [+]                                        }|
                                                             |
      ]])
    end)

    it('recomposes lines when floating window is positioned over scroll region', function()
      local scroll_events = 0
      local original = screen._handle_grid_scroll
      screen._handle_grid_scroll = function(...)
        scroll_events = scroll_events + 1
        return original(...)
      end

      local buf = api.nvim_create_buf(false, false)
      api.nvim_open_win(
        buf,
        false,
        { relative = 'editor', width = 10, height = 2, row = 3, col = 0 }
      )

      screen:expect([[
        and                 │and             │and            |
        clearing            │clearing        │clearing       |
        in                  │in              │in             |
        {4:          }          │split           │split          |
        {11:~         }          │windows         │windows        |
        ^                    │                │               |
        {3:[No Name] [+]        }{2:[No Name] [+]    [No Name] [+]  }|
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        {2:[No Name] [+]                                        }|
                                                             |
      ]])
      feed('gg')
      screen:expect([[
        ^Inserting           │and             │and            |
        text                │clearing        │clearing       |
        with                │in              │in             |
        {4:          }          │split           │split          |
        {11:~         }          │windows         │windows        |
        to                  │                │               |
        {3:[No Name] [+]        }{2:[No Name] [+]    [No Name] [+]  }|
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        {2:[No Name] [+]                                        }|
                                                             |
      ]])
      eq(0, scroll_events)
      feed('<c-f>')
      screen:expect([[
        ^lines               │and             │and            |
        to                  │clearing        │clearing       |
        test                │in              │in             |
        {4:          }          │split           │split          |
        {11:~         }          │windows         │windows        |
        clearing            │                │               |
        {3:[No Name] [+]        }{2:[No Name] [+]    [No Name] [+]  }|
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
                                                             |
        {2:[No Name] [+]                                        }|
                                                             |
      ]])
      eq(0, scroll_events)
      feed('<c-w>jHk')
      screen:expect([[
        lines               │and             │and            |
        to                  │clearing        │clearing       |
        test                │in              │in             |
        {4:          }          │split           │split          |
        {11:~         }          │windows         │windows        |
        clearing            │                │               |
        {2:[No Name] [+]        [No Name] [+]    [No Name] [+]  }|
        ^and                                                  |
        clearing                                             |
        in                                                   |
        split                                                |
        windows                                              |
        {3:[No Name] [+]                                        }|
                                                             |
      ]])
      eq(1, scroll_events)
    end)
  end)

  describe('resize', function()
    it('rebuilds the whole screen', function()
      screen:try_resize(25, 5)
      feed('iresize')
      screen:expect([[
        resize^                   |
        {1:~                        }|*3
        {5:-- INSERT --}             |
      ]])
    end)

    it('has minimum width/height values', function()
      feed('iresize')
      screen:try_resize(1, 1)
      screen:expect([[
        resize^      |
        {5:-- INSERT --}|
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
      api.nvim_set_option_value('showtabline', 2, {})
      screen:expect([[
        {5: + [No Name] }{2:            }|
        resiz^e                   |
        {1:~                        }|*2
                                 |
      ]])
      screen:try_resize(30, 6)
      screen:expect([[
        {5: + [No Name] }{2:                 }|
        resiz^e                        |
        {1:~                             }|*3
                                      |
      ]])
      eq(29, api.nvim_get_var('echospace'))
    end)

    it('messages from the same Ex command as resize are visible #22225', function()
      feed(':set columns=20 | call<CR>')
      screen:expect([[
                            |*9
        {3:                    }|
        {9:E471: Argument requi}|
        {9:red}                 |
        {6:Press ENTER or type }|
        {6:command to continue}^ |
      ]])
      feed('<CR>')
      screen:expect([[
        ^                    |
        {1:~                   }|*12
                            |
      ]])
      feed(':set columns=0<CR>')
      screen:expect([[
                            |
        {1:~                   }|*7
        {3:                    }|
        {9:E594: Need at least }|
        {9:12 columns: columns=}|
        {9:0}                   |
        {6:Press ENTER or type }|
        {6:command to continue}^ |
      ]])
      feed('<CR>')
      screen:expect([[
        ^                    |
        {1:~                   }|*12
                            |
      ]])
    end)

    it('does not crash when windows fill the screen #33883', function()
      screen:try_resize(80, 20)
      while true do
        local ok = pcall(command, 'wincmd v')
        if not ok then
          break
        end
      end

      screen:try_resize(60, 20)

      assert_alive()
    end)

    it('clamps &cmdheight for current tabpage', function()
      command('set cmdheight=10 laststatus=2')
      screen:expect([[
        ^                                                     |
        {1:~                                                    }|*2
        {3:[No Name]                                            }|
                                                             |*10
      ]])
      screen:try_resize(53, 8)
      screen:expect([[
        ^                                                     |
        {3:[No Name]                                            }|
                                                             |*6
      ]])
      eq(6, api.nvim_get_option_value('cmdheight', {}))
    end)

    it('clamps &cmdheight for another tabpage #31380', function()
      command('tabnew')
      command('set cmdheight=9 laststatus=2')
      screen:expect([[
        {24: [No Name] }{5: [No Name] }{2:                              }{24:X}|
        ^                                                     |
        {1:~                                                    }|*2
        {3:[No Name]                                            }|
                                                             |*9
      ]])
      command('tabprev')
      screen:expect([[
        {5: [No Name] }{24: [No Name] }{2:                              }{24:X}|
        ^                                                     |
        {1:~                                                    }|*10
        {3:[No Name]                                            }|
                                                             |
      ]])
      screen:try_resize(53, 8)
      screen:expect([[
        {5: [No Name] }{24: [No Name] }{2:                              }{24:X}|
        ^                                                     |
        {1:~                                                    }|*4
        {3:[No Name]                                            }|
                                                             |
      ]])
      command('tabnext')
      screen:expect([[
        {24: [No Name] }{5: [No Name] }{2:                              }{24:X}|
        ^                                                     |
        {3:[No Name]                                            }|
                                                             |*5
      ]])
      eq(5, api.nvim_get_option_value('cmdheight', {}))
    end)
  end)

  describe('press enter', function()
    it('does not crash on <F1> at “Press ENTER”', function()
      command('nnoremap <F1> :echo "TEST"<CR>')
      feed(':ls<CR>')
      screen:expect([[
                                                             |
        {1:~                                                    }|*9
        {3:                                                     }|
        :ls                                                  |
          1 %a   "[No Name]"                    line 1       |
        {6:Press ENTER or type command to continue}^              |
      ]])
      feed('<F1>')
      screen:expect([[
        ^                                                     |
        {1:~                                                    }|*12
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
      {1:~                                                    }|*12
      {5:-- INSERT --}                                         |
    ]])
    feed('k')
    screen:expect([[
      fo^o                                                  |
      {1:~                                                    }|*12
                                                           |
    ]])
  end)
end

describe('Screen (char-based)', function()
  screen_tests(false)
end)

describe('Screen (line-based)', function()
  screen_tests(true)
end)

describe('Screen default colors', function()
  local screen
  local function startup(light, termcolors)
    local extra = (light and ' background=light') or ''

    local nvim_argv = {
      n.nvim_prog,
      '-u',
      'NONE',
      '-i',
      'NONE',
      '-N',
      '--cmd',
      'set shortmess+=I noswapfile belloff= noshowcmd noruler' .. extra,
      '--cmd',
      'colorscheme vim',
      '--embed',
    }
    local screen_nvim = n.new_session(false, { args = nvim_argv, merge = false })
    set_session(screen_nvim)
    screen = Screen.new(53, 14, { rgb = true, ext_termcolors = termcolors or nil })
  end

  it('are dark per default', function()
    startup(false, false)
    screen:expect(function()
      eq({
        rgb_bg = 0,
        rgb_fg = Screen.colors.White,
        rgb_sp = Screen.colors.Red,
        cterm_bg = 0,
        cterm_fg = 0,
      }, screen.default_colors)
    end)
  end)

  it('can be set to light', function()
    startup(true, false)
    screen:expect(function()
      eq({
        rgb_bg = Screen.colors.White,
        rgb_fg = 0,
        rgb_sp = Screen.colors.Red,
        cterm_bg = 0,
        cterm_fg = 0,
      }, screen.default_colors)
    end)
  end)

  it('can be handled by external terminal', function()
    local colors = { rgb_bg = -1, rgb_fg = -1, rgb_sp = -1, cterm_bg = 0, cterm_fg = 0 }
    startup(false, true)
    screen:expect(function()
      eq(colors, screen.default_colors)
    end)

    startup(true, true)
    screen:expect(function()
      eq(colors, screen.default_colors)
    end)
  end)
end)

local screen
before_each(function()
  clear()
  screen = Screen.new()
end)

it('CTRL-F or CTRL-B scrolls a page after UI attach/resize #20605', function()
  screen:try_resize(100, 100)
  eq(100, api.nvim_get_option_value('lines', {}))
  eq(99, api.nvim_get_option_value('window', {}))
  eq(99, api.nvim_win_get_height(0))
  feed('1000o<Esc>')
  eq(903, fn.line('w0'))
  feed('<C-B>')
  eq(806, fn.line('w0'))
  feed('<C-B>')
  eq(709, fn.line('w0'))
  feed('<C-F>')
  eq(806, fn.line('w0'))
  feed('<C-F>')
  eq(903, fn.line('w0'))
  feed('G')
  screen:try_resize(50, 50)
  eq(50, api.nvim_get_option_value('lines', {}))
  eq(49, api.nvim_get_option_value('window', {}))
  eq(49, api.nvim_win_get_height(0))
  eq(953, fn.line('w0'))
  feed('<C-B>')
  eq(906, fn.line('w0'))
  feed('<C-B>')
  eq(859, fn.line('w0'))
  feed('<C-F>')
  eq(906, fn.line('w0'))
  feed('<C-F>')
  eq(953, fn.line('w0'))
end)

it("showcmd doesn't cause empty grid_line with redrawdebug=compositor #22593", function()
  command('set showcmd redrawdebug=compositor')
  feed('d')
  screen:expect([[
    ^                                                     |
    {1:~                                                    }|*12
                                              d          |
  ]])
end)

it("scrolling in narrow window doesn't draw over separator #29033", function()
  screen:try_resize(60, 8)
  feed('100Oa<Esc>gg')
  exec([[
    set number nowrap
    vsplit
    set scrollbind
    wincmd l
    set scrollbind
    wincmd |
  ]])
  screen:expect([[
    {8: }│{8:  1 }^a                                                     |
    {8: }│{8:  2 }a                                                     |
    {8: }│{8:  3 }a                                                     |
    {8: }│{8:  4 }a                                                     |
    {8: }│{8:  5 }a                                                     |
    {8: }│{8:  6 }a                                                     |
    {2:< }{3:[No Name] [+]                                             }|
                                                                |
  ]])
  feed('<C-F>')
  screen:expect([[
    {8: }│{8:  5 }^a                                                     |
    {8: }│{8:  6 }a                                                     |
    {8: }│{8:  7 }a                                                     |
    {8: }│{8:  8 }a                                                     |
    {8: }│{8:  9 }a                                                     |
    {8: }│{8: 10 }a                                                     |
    {2:< }{3:[No Name] [+]                                             }|
                                                                |
  ]])
end)

it('hidden windows are not redrawn', function()
  clear()
  local screen = Screen.new()
  local opts = { width = 5, height = 5, bufpos = { 0, 0 }, relative = 'win', hide = true }
  local win = api.nvim_open_win(0, false, opts)
  local no_redraw = function()
    vim.o.laststatus = 3
    local on_win = function(_, winid)
      _G.did_win = (_G.did_win or 0) + (winid == win and 1 or 0)
    end
    vim.api.nvim_set_decoration_provider(1, { on_win = on_win })
    vim.api.nvim__redraw({ flush = true })
    return _G.did_win
  end
  eq(0, exec_lua(no_redraw))
  screen:expect([[
    ^                                                     |
    {1:~                                                    }|*11
    {3:[No Name]                                            }|
                                                         |
  ]])
  -- Redrawn properly after unhiding
  api.nvim_win_set_config(win, { hide = false })
  screen:expect([[
    ^                                                     |
    {4:     }{1:                                                }|
    {11:~    }{1:                                                }|*4
    {1:~                                                    }|*6
    {3:[No Name]                                            }|
                                                         |
  ]])
end)
