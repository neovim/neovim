local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local os = require('os')
local clear, feed = helpers.clear, helpers.feed
local assert_alive = helpers.assert_alive
local command, feed_command = helpers.command, helpers.feed_command
local eval = helpers.eval
local eq = helpers.eq
local exec_lua = helpers.exec_lua
local insert = helpers.insert
local meths = helpers.meths
local curbufmeths = helpers.curbufmeths
local funcs = helpers.funcs
local run = helpers.run
local pcall_err = helpers.pcall_err

describe('floatwin', function()
  before_each(function()
    clear()
  end)
  local attrs = {
    [0] = {bold=true, foreground=Screen.colors.Blue},
    [1] = {background = Screen.colors.LightMagenta},
    [2] = {background = Screen.colors.LightMagenta, bold = true, foreground = Screen.colors.Blue1},
    [3] = {bold = true},
    [4] = {bold = true, reverse = true},
    [5] = {reverse = true},
    [6] = {background = Screen.colors.LightMagenta, bold = true, reverse = true},
    [7] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
    [8] = {bold = true, foreground = Screen.colors.SeaGreen4},
    [9] = {background = Screen.colors.LightGrey, underline = true},
    [10] = {background = Screen.colors.LightGrey, underline = true, bold = true, foreground = Screen.colors.Magenta},
    [11] = {bold = true, foreground = Screen.colors.Magenta},
    [12] = {background = Screen.colors.Red, bold = true, foreground = Screen.colors.Blue1},
    [13] = {background = Screen.colors.WebGray},
    [14] = {foreground = Screen.colors.Brown},
    [15] = {background = Screen.colors.Grey20},
    [16] = {background = Screen.colors.Grey20, bold = true, foreground = Screen.colors.Blue1},
    [17] = {background = Screen.colors.Yellow},
    [18] = {foreground = Screen.colors.Brown, background = Screen.colors.Grey20},
    [19] = {foreground = Screen.colors.DarkBlue, background = Screen.colors.WebGray},
    [20] = {bold = true, foreground = Screen.colors.Brown},
    [21] = {background = Screen.colors.Gray90},
    [22] = {background = Screen.colors.LightRed},
  }

  it('behavior', function()
    -- Create three windows and test that ":wincmd <direction>" changes to the
    -- first window, if the previous window is invalid.
    command('split')
    meths.open_win(0, true, {width=10, height=10, relative='editor', row=0, col=0})
    eq(1002, funcs.win_getid())
    eq('editor', meths.win_get_config(1002).relative)
    command([[
      call nvim_win_close(1001, v:false)
      wincmd j
    ]])
    eq(1000, funcs.win_getid())
  end)

  it('closed immediately by autocmd #11383', function()
    eq('Error executing lua: [string "<nvim>"]:0: Window was closed immediately',
      pcall_err(exec_lua, [[
        local a = vim.api
        local function crashes(contents)
          local buf = a.nvim_create_buf(false, true)
          local floatwin = a.nvim_open_win(buf, true, {
            relative = 'cursor';
            style = 'minimal';
            row = 0; col = 0;
            height = #contents;
            width = 10;
          })
          a.nvim_buf_set_lines(buf, 0, -1, true, contents)
          local winnr = vim.fn.win_id2win(floatwin)
          a.nvim_command('wincmd p')
          a.nvim_command('autocmd CursorMoved * ++once '..winnr..'wincmd c')
          return buf, floatwin
        end
        crashes{'foo'}
        crashes{'bar'}
    ]]))
    assert_alive()
  end)

  it('opened with correct height', function()
    local height = exec_lua([[
      vim.api.nvim_set_option("winheight", 20)
      local bufnr = vim.api.nvim_create_buf(false, true)

      local opts = {
        height = 10,
        col = 5,
        row = 1,
        relative = 'editor',
        style = 'minimal',
        width = 15
      }

      local win_id = vim.api.nvim_open_win(bufnr, true, opts)

      return vim.api.nvim_win_get_height(win_id)
    ]])

    eq(10, height)
  end)

  it('opened with correct width', function()
    local width = exec_lua([[
      vim.api.nvim_set_option("winwidth", 20)
      local bufnr = vim.api.nvim_create_buf(false, true)

      local opts = {
        height = 10,
        col = 5,
        row = 1,
        relative = 'editor',
        style = 'minimal',
        width = 10
      }

      local win_id = vim.api.nvim_open_win(bufnr, true, opts)

      return vim.api.nvim_win_get_width(win_id)
    ]])

    eq(10, width)
  end)

  local function with_ext_multigrid(multigrid)
    local screen
    before_each(function()
      screen = Screen.new(40,7)
      screen:attach({ext_multigrid=multigrid})
      screen:set_default_attr_ids(attrs)
    end)

    it('can be created and reconfigured', function()
      local buf = meths.create_buf(false,false)
      local win = meths.open_win(buf, false, {relative='editor', width=20, height=2, row=2, col=5})
      local expected_pos = {
          [4]={{id=1001}, 'NW', 1, 2, 5, true},
      }

      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 4
          {1:                    }|
          {2:~                   }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
          ^                                        |
          {0:~                                       }|
          {0:~    }{1:                    }{0:               }|
          {0:~    }{2:~                   }{0:               }|
          {0:~                                       }|
          {0:~                                       }|
                                                  |
          ]])
      end


      meths.win_set_config(win, {relative='editor', row=0, col=10})
      expected_pos[4][4] = 0
      expected_pos[4][5] = 10
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 4
          {1:                    }|
          {2:~                   }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
          ^          {1:                    }          |
          {0:~         }{2:~                   }{0:          }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
                                                  |
        ]])
      end

      meths.win_close(win, false)
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
        ## grid 3
                                                  |
        ]])
      else
        screen:expect([[
          ^                                        |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
                                                  |
        ]])
      end
    end)

    it('draws correctly with redrawdebug=compositor', function()
      -- NB: we do not test that it produces the "correct" debug info
      -- (as it is intermediate only, and is allowed to change by internal
      -- refactors). Only check that it doesn't cause permanent glitches,
      -- or something.
      command("set redrawdebug=compositor")
      command("set wd=1")
      local buf = meths.create_buf(false,false)
      local win = meths.open_win(buf, false, {relative='editor', width=20, height=2, row=2, col=5})
      local expected_pos = {
          [4]={{id=1001}, 'NW', 1, 2, 5, true},
      }

      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 4
          {1:                    }|
          {2:~                   }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
          ^                                        |
          {0:~                                       }|
          {0:~    }{1:                    }{0:               }|
          {0:~    }{2:~                   }{0:               }|
          {0:~                                       }|
          {0:~                                       }|
                                                  |
          ]])
      end


      meths.win_set_config(win, {relative='editor', row=0, col=10})
      expected_pos[4][4] = 0
      expected_pos[4][5] = 10
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 4
          {1:                    }|
          {2:~                   }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
          ^          {1:                    }          |
          {0:~         }{2:~                   }{0:          }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
                                                  |
        ]])
      end

      meths.win_close(win, false)
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
        ## grid 3
                                                  |
        ]])
      else
        screen:expect([[
          ^                                        |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
                                                  |
        ]])
      end
    end)

    it('return their configuration', function()
      local buf = meths.create_buf(false, false)
      local win = meths.open_win(buf, false, {relative='editor', width=20, height=2, row=3, col=5})
      local expected = {anchor='NW', col=5, external=false, focusable=true, height=2, relative='editor', row=3, width=20}
      eq(expected, meths.win_get_config(win))

      eq({relative='', external=false, focusable=true}, meths.win_get_config(0))

      if multigrid then
        meths.win_set_config(win, {external=true, width=10, height=1})
        eq({external=true,focusable=true,width=10,height=1,relative=''}, meths.win_get_config(win))
      end
    end)

    it('defaults to NormalFloat highlight and inherited options', function()
      command('set number')
      command('hi NormalFloat guibg=#333333')
      feed('ix<cr>y<cr><esc>gg')
      local win = meths.open_win(0, false, {relative='editor', width=20, height=4, row=4, col=10})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [3:----------------------------------------]|
        ## grid 2
          {14:  1 }^x                                   |
          {14:  2 }y                                   |
          {14:  3 }                                    |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 4
          {18:  1 }{15:x               }|
          {18:  2 }{15:y               }|
          {18:  3 }{15:                }|
          {16:~                   }|
        ]], float_pos={[4] = {{id = 1001}, "NW", 1, 4, 10, true}}}
      else
        screen:expect([[
          {14:  1 }^x                                   |
          {14:  2 }y                                   |
          {14:  3 }      {18:  1 }{15:x               }          |
          {0:~         }{18:  2 }{15:y               }{0:          }|
          {0:~         }{18:  3 }{15:                }{0:          }|
          {0:~         }{16:~                   }{0:          }|
                                                  |
        ]])
      end

      local buf = meths.create_buf(false, true)
      meths.win_set_buf(win, buf)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [3:----------------------------------------]|
        ## grid 2
          {14:  1 }^x                                   |
          {14:  2 }y                                   |
          {14:  3 }                                    |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 4
          {18:  1 }{15:                }|
          {16:~                   }|
          {16:~                   }|
          {16:~                   }|
        ]], float_pos={[4] = {{id = 1001}, "NW", 1, 4, 10, true}}}
      else
        screen:expect([[
          {14:  1 }^x                                   |
          {14:  2 }y                                   |
          {14:  3 }      {18:  1 }{15:                }          |
          {0:~         }{16:~                   }{0:          }|
          {0:~         }{16:~                   }{0:          }|
          {0:~         }{16:~                   }{0:          }|
                                                  |
        ]])
      end
    end)

    it("can use 'minimal' style", function()
      command('set number')
      command('set signcolumn=yes')
      command('set colorcolumn=1')
      command('set cursorline')
      command('set foldcolumn=1')
      command('hi NormalFloat guibg=#333333')
      feed('ix<cr>y<cr><esc>gg')
      local win = meths.open_win(0, false, {relative='editor', width=20, height=4, row=4, col=10, style='minimal'})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [3:----------------------------------------]|
        ## grid 2
          {19:   }{20:  1 }{22:^x}{21:                                }|
          {19:   }{14:  2 }{22:y}                                |
          {19:   }{14:  3 }{22: }                                |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 4
          {15:x                   }|
          {15:y                   }|
          {15:                    }|
          {15:                    }|
        ]], float_pos={[4] = {{id = 1001}, "NW", 1, 4, 10, true}}}
      else
        screen:expect{grid=[[
          {19:   }{20:  1 }{22:^x}{21:                                }|
          {19:   }{14:  2 }{22:y}                                |
          {19:   }{14:  3 }{22: }  {15:x                   }          |
          {0:~         }{15:y                   }{0:          }|
          {0:~         }{15:                    }{0:          }|
          {0:~         }{15:                    }{0:          }|
                                                  |
        ]]}
      end

      --  signcolumn=yes still works if there actually are signs
      command('sign define piet1 text=𐌢̀́̂̃̅̄𐌢̀́̂̃̅̄ texthl=Search')
      command('sign place 1 line=1 name=piet1 buffer=1')
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [3:----------------------------------------]|
        ## grid 2
          {19: }{17:𐌢̀́̂̃̅̄𐌢̀́̂̃̅̄}{20:  1 }{22:^x}{21:                                }|
          {19:   }{14:  2 }{22:y}                                |
          {19:   }{14:  3 }{22: }                                |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 4
          {17:𐌢̀́̂̃̅̄𐌢̀́̂̃̅̄}{15:x                 }|
          {19:  }{15:y                 }|
          {19:  }{15:                  }|
          {15:                    }|
        ]], float_pos={[4] = {{id = 1001}, "NW", 1, 4, 10, true}}}

      else
        screen:expect([[
          {19: }{17:𐌢̀́̂̃̅̄𐌢̀́̂̃̅̄}{20:  1 }{22:^x}{21:                                }|
          {19:   }{14:  2 }{22:y}                                |
          {19:   }{14:  3 }{22: }  {17:𐌢̀́̂̃̅̄𐌢̀́̂̃̅̄}{15:x                 }          |
          {0:~         }{19:  }{15:y                 }{0:          }|
          {0:~         }{19:  }{15:                  }{0:          }|
          {0:~         }{15:                    }{0:          }|
                                                  |
        ]])
      end
      command('sign unplace 1 buffer=1')

      local buf = meths.create_buf(false, true)
      meths.win_set_buf(win, buf)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [3:----------------------------------------]|
        ## grid 2
          {19:   }{20:  1 }{22:^x}{21:                                }|
          {19:   }{14:  2 }{22:y}                                |
          {19:   }{14:  3 }{22: }                                |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 4
          {15:                    }|
          {15:                    }|
          {15:                    }|
          {15:                    }|
        ]], float_pos={[4] = {{id = 1001}, "NW", 1, 4, 10, true}}}
      else
        screen:expect([[
          {19:   }{20:  1 }{22:^x}{21:                                }|
          {19:   }{14:  2 }{22:y}                                |
          {19:   }{14:  3 }{22: }  {15:                    }          |
          {0:~         }{15:                    }{0:          }|
          {0:~         }{15:                    }{0:          }|
          {0:~         }{15:                    }{0:          }|
                                                  |
        ]])
      end
    end)

    it('can have minimum size', function()
      insert("the background text")
      local buf = meths.create_buf(false, true)
      meths.buf_set_lines(buf, 0, -1, true, {'x'})
      local win = meths.open_win(buf, false, {relative='win', width=1, height=1, row=0, col=4, focusable=false})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [3:----------------------------------------]|
        ## grid 2
          the background tex^t                     |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 5
          {1:x}|
        ]], float_pos={
          [5] = {{id = 1002}, "NW", 2, 0, 4, false}
        }}
      else
        screen:expect([[
          the {1:x}ackground tex^t                     |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
                                                  |
        ]])
      end

      meths.win_set_config(win, {relative='win', row=0, col=15})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [3:----------------------------------------]|
        ## grid 2
          the background tex^t                     |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 5
          {1:x}|
        ]], float_pos={
          [5] = {{id = 1002}, "NW", 2, 0, 15, false}
        }}
      else
        screen:expect([[
          the background {1:x}ex^t                     |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
                                                  |
        ]])
      end

      meths.win_close(win,false)
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [3:----------------------------------------]|
        ## grid 2
          the background tex^t                     |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
        ## grid 3
                                                  |
        ]])
      else
        screen:expect([[
          the background tex^t                     |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
                                                  |
        ]])
      end
    end)

    it('API has proper error messages', function()
      local buf = meths.create_buf(false,false)
      eq("Invalid key 'bork'",
         pcall_err(meths.open_win,buf, false, {width=20,height=2,bork=true}))
      eq("'win' key is only valid with relative='win'",
         pcall_err(meths.open_win,buf, false, {width=20,height=2,relative='editor',row=0,col=0,win=0}))
      eq("Only one of 'relative' and 'external' must be used",
         pcall_err(meths.open_win,buf, false, {width=20,height=2,relative='editor',row=0,col=0,external=true}))
      eq("Invalid value of 'relative' key",
         pcall_err(meths.open_win,buf, false, {width=20,height=2,relative='shell',row=0,col=0}))
      eq("Invalid value of 'anchor' key",
         pcall_err(meths.open_win,buf, false, {width=20,height=2,relative='editor',row=0,col=0,anchor='bottom'}))
      eq("'relative' requires 'row'/'col' or 'bufpos'",
         pcall_err(meths.open_win,buf, false, {width=20,height=2,relative='editor'}))
      eq("'width' key must be a positive Integer",
         pcall_err(meths.open_win,buf, false, {width=-1,height=2,relative='editor'}))
      eq("'height' key must be a positive Integer",
         pcall_err(meths.open_win,buf, false, {width=20,height=-1,relative='editor'}))
      eq("'height' key must be a positive Integer",
         pcall_err(meths.open_win,buf, false, {width=20,height=0,relative='editor'}))
      eq("Must specify 'width' and 'height'",
         pcall_err(meths.open_win,buf, false, {relative='editor'}))
    end)

    it('can be placed relative window or cursor', function()
      screen:try_resize(40,9)
      meths.buf_set_lines(0, 0, -1, true, {'just some', 'example text'})
      feed('gge')
      local oldwin = meths.get_current_win()
      command('below split')
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          {5:[No Name] [+]                           }|
          [4:----------------------------------------]|
          [4:----------------------------------------]|
          [4:----------------------------------------]|
          {4:[No Name] [+]                           }|
          [3:----------------------------------------]|
        ## grid 2
          just some                               |
          example text                            |
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 4
          jus^t some                               |
          example text                            |
          {0:~                                       }|
        ]])
      else
        screen:expect([[
          just some                               |
          example text                            |
          {0:~                                       }|
          {5:[No Name] [+]                           }|
          jus^t some                               |
          example text                            |
          {0:~                                       }|
          {4:[No Name] [+]                           }|
                                                  |
        ]])
      end

      local buf = meths.create_buf(false,false)
      -- no 'win' arg, relative default window
      local win = meths.open_win(buf, false, {relative='win', width=20, height=2, row=0, col=10})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          {5:[No Name] [+]                           }|
          [4:----------------------------------------]|
          [4:----------------------------------------]|
          [4:----------------------------------------]|
          {4:[No Name] [+]                           }|
          [3:----------------------------------------]|
        ## grid 2
          just some                               |
          example text                            |
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 4
          jus^t some                               |
          example text                            |
          {0:~                                       }|
        ## grid 5
          {1:                    }|
          {2:~                   }|
        ]], float_pos={
          [5] = {{id = 1002}, "NW", 4, 0, 10, true}
        }}
      else
        screen:expect([[
          just some                               |
          example text                            |
          {0:~                                       }|
          {5:[No Name] [+]                           }|
          jus^t some {1:                    }          |
          example te{2:~                   }          |
          {0:~                                       }|
          {4:[No Name] [+]                           }|
                                                  |
        ]])
      end

      meths.win_set_config(win, {relative='cursor', row=1, col=-2})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          {5:[No Name] [+]                           }|
          [4:----------------------------------------]|
          [4:----------------------------------------]|
          [4:----------------------------------------]|
          {4:[No Name] [+]                           }|
          [3:----------------------------------------]|
        ## grid 2
          just some                               |
          example text                            |
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 4
          jus^t some                               |
          example text                            |
          {0:~                                       }|
        ## grid 5
          {1:                    }|
          {2:~                   }|
        ]], float_pos={
          [5] = {{id = 1002}, "NW", 4, 1, 1, true}
        }}
      else
        screen:expect([[
          just some                               |
          example text                            |
          {0:~                                       }|
          {5:[No Name] [+]                           }|
          jus^t some                               |
          e{1:                    }                   |
          {0:~}{2:~                   }{0:                   }|
          {4:[No Name] [+]                           }|
                                                  |
        ]])
      end

      meths.win_set_config(win, {relative='cursor', row=0, col=0, anchor='SW'})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          {5:[No Name] [+]                           }|
          [4:----------------------------------------]|
          [4:----------------------------------------]|
          [4:----------------------------------------]|
          {4:[No Name] [+]                           }|
          [3:----------------------------------------]|
        ## grid 2
          just some                               |
          example text                            |
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 4
          jus^t some                               |
          example text                            |
          {0:~                                       }|
        ## grid 5
          {1:                    }|
          {2:~                   }|
        ]], float_pos={
          [5] = {{id = 1002}, "SW", 4, 0, 3, true}
        }}
      else
        screen:expect([[
          just some                               |
          example text                            |
          {0:~  }{1:                    }{0:                 }|
          {5:[No}{2:~                   }{5:                 }|
          jus^t some                               |
          example text                            |
          {0:~                                       }|
          {4:[No Name] [+]                           }|
                                                  |
        ]])
      end


      meths.win_set_config(win, {relative='win', win=oldwin, row=1, col=10, anchor='NW'})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          {5:[No Name] [+]                           }|
          [4:----------------------------------------]|
          [4:----------------------------------------]|
          [4:----------------------------------------]|
          {4:[No Name] [+]                           }|
          [3:----------------------------------------]|
        ## grid 2
          just some                               |
          example text                            |
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 4
          jus^t some                               |
          example text                            |
          {0:~                                       }|
        ## grid 5
          {1:                    }|
          {2:~                   }|
        ]], float_pos={
          [5] = {{id = 1002}, "NW", 2, 1, 10, true}
        }}
      else
        screen:expect([[
          just some                               |
          example te{1:                    }          |
          {0:~         }{2:~                   }{0:          }|
          {5:[No Name] [+]                           }|
          jus^t some                               |
          example text                            |
          {0:~                                       }|
          {4:[No Name] [+]                           }|
                                                  |
        ]])
      end

      meths.win_set_config(win, {relative='win', win=oldwin, row=3, col=39, anchor='SE'})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          {5:[No Name] [+]                           }|
          [4:----------------------------------------]|
          [4:----------------------------------------]|
          [4:----------------------------------------]|
          {4:[No Name] [+]                           }|
          [3:----------------------------------------]|
        ## grid 2
          just some                               |
          example text                            |
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 4
          jus^t some                               |
          example text                            |
          {0:~                                       }|
        ## grid 5
          {1:                    }|
          {2:~                   }|
        ]], float_pos={
          [5] = {{id = 1002}, "SE", 2, 3, 39, true}
        }}
      else
        screen:expect([[
          just some                               |
          example text       {1:                    } |
          {0:~                  }{2:~                   }{0: }|
          {5:[No Name] [+]                           }|
          jus^t some                               |
          example text                            |
          {0:~                                       }|
          {4:[No Name] [+]                           }|
                                                  |
        ]])
      end

      meths.win_set_config(win, {relative='win', win=0, row=0, col=50, anchor='NE'})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          {5:[No Name] [+]                           }|
          [4:----------------------------------------]|
          [4:----------------------------------------]|
          [4:----------------------------------------]|
          {4:[No Name] [+]                           }|
          [3:----------------------------------------]|
        ## grid 2
          just some                               |
          example text                            |
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 4
          jus^t some                               |
          example text                            |
          {0:~                                       }|
        ## grid 5
          {1:                    }|
          {2:~                   }|
        ]], float_pos={
          [5] = {{id = 1002}, "NE", 4, 0, 50, true}
        }, win_viewport = {
          [2] = {
              topline = 0,
              botline = 3,
              curline = 0,
              curcol = 3,
              win = { id = 1000 }
          },
          [4] = {
              topline = 0,
              botline = 3,
              curline = 0,
              curcol = 3,
              win = { id = 1001 }
          },
          [5] = {
            topline = 0,
            botline = 2,
            curline = 0,
            curcol = 0,
            win = { id = 1002 }
          }
        }}
      else
        screen:expect([[
          just some                               |
          example text                            |
          {0:~                                       }|
          {5:[No Name] [+]                           }|
          jus^t some           {1:                    }|
          example text        {2:~                   }|
          {0:~                                       }|
          {4:[No Name] [+]                           }|
                                                  |
        ]])
      end
    end)

    it('can be placed relative text in a window', function()
      screen:try_resize(30,5)
      local firstwin = meths.get_current_win().id
      meths.buf_set_lines(0, 0, -1, true, {'just some', 'example text that is wider than the window', '', '', 'more text'})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:------------------------------]|
          [2:------------------------------]|
          [2:------------------------------]|
          [2:------------------------------]|
          [3:------------------------------]|
        ## grid 2
          ^just some                     |
          example text that is wider tha|
          n the window                  |
                                        |
        ## grid 3
                                        |
        ]]}
      else
        screen:expect{grid=[[
          ^just some                     |
          example text that is wider tha|
          n the window                  |
                                        |
                                        |
        ]]}
      end

      local buf = meths.create_buf(false,false)
      meths.buf_set_lines(buf, 0, -1, true, {'some info!'})

      local win = meths.open_win(buf, false, {relative='win', width=12, height=1, bufpos={1,32}})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:------------------------------]|
          [2:------------------------------]|
          [2:------------------------------]|
          [2:------------------------------]|
          [3:------------------------------]|
        ## grid 2
          ^just some                     |
          example text that is wider tha|
          n the window                  |
                                        |
        ## grid 3
                                        |
        ## grid 5
          {1:some info!  }|
        ]], float_pos={
          [5] = { {
              id = 1002
            }, "NW", 2, 3, 2, true }
        }}
      else
        screen:expect{grid=[[
          ^just some                     |
          example text that is wider tha|
          n the window                  |
            {1:some info!  }                |
                                        |
        ]]}
      end
      eq({relative='win', width=12, height=1, bufpos={1,32}, anchor='NW',
          external=false, col=0, row=1, win=firstwin, focusable=true}, meths.win_get_config(win))

      feed('<c-e>')
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:------------------------------]|
          [2:------------------------------]|
          [2:------------------------------]|
          [2:------------------------------]|
          [3:------------------------------]|
        ## grid 2
          ^example text that is wider tha|
          n the window                  |
                                        |
                                        |
        ## grid 3
                                        |
        ## grid 5
          {1:some info!  }|
        ]], float_pos={
          [5] = { {
              id = 1002
            }, "NW", 2, 2, 2, true }
        }}
      else
        screen:expect{grid=[[
          ^example text that is wider tha|
          n the window                  |
            {1:some info!  }                |
                                        |
                                        |
        ]]}
      end


      screen:try_resize(45,5)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [2:---------------------------------------------]|
          [3:---------------------------------------------]|
        ## grid 2
          ^example text that is wider than the window   |
                                                       |
                                                       |
          more text                                    |
        ## grid 3
                                                       |
        ## grid 5
          {1:some info!  }|
        ]], float_pos={
          [5] = { {
              id = 1002
            }, "NW", 2, 1, 32, true }
        }}
      else
        -- note: appears misalinged due to cursor
        screen:expect{grid=[[
          ^example text that is wider than the window   |
                                          {1:some info!  } |
                                                       |
          more text                                    |
                                                       |
        ]]}
      end

      screen:try_resize(25,10)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [3:-------------------------]|
        ## grid 2
          ^example text that is wide|
          r than the window        |
                                   |
                                   |
          more text                |
          {0:~                        }|
          {0:~                        }|
          {0:~                        }|
          {0:~                        }|
        ## grid 3
                                   |
        ## grid 5
          {1:some info!  }|
        ]], float_pos={
          [5] = { {
              id = 1002
            }, "NW", 2, 2, 7, true }
        }}
      else
        screen:expect{grid=[[
          ^example text that is wide|
          r than the window        |
                 {1:some info!  }      |
                                   |
          more text                |
          {0:~                        }|
          {0:~                        }|
          {0:~                        }|
          {0:~                        }|
                                   |
        ]]}
      end

      meths.win_set_config(win, {relative='win', bufpos={1,32}, anchor='SW'})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [3:-------------------------]|
        ## grid 2
          ^example text that is wide|
          r than the window        |
                                   |
                                   |
          more text                |
          {0:~                        }|
          {0:~                        }|
          {0:~                        }|
          {0:~                        }|
        ## grid 3
                                   |
        ## grid 5
          {1:some info!  }|
        ]], float_pos={
          [5] = { {
              id = 1002
            }, "SW", 2, 1, 7, true }
        }}
      else
        screen:expect{grid=[[
          ^example{1:some info!  }s wide|
          r than the window        |
                                   |
                                   |
          more text                |
          {0:~                        }|
          {0:~                        }|
          {0:~                        }|
          {0:~                        }|
                                   |
        ]]}
      end

      meths.win_set_config(win, {relative='win', bufpos={1,32}, anchor='NW', col=-2})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [3:-------------------------]|
        ## grid 2
          ^example text that is wide|
          r than the window        |
                                   |
                                   |
          more text                |
          {0:~                        }|
          {0:~                        }|
          {0:~                        }|
          {0:~                        }|
        ## grid 3
                                   |
        ## grid 5
          {1:some info!  }|
        ]], float_pos={
          [5] = { {
              id = 1002
            }, "NW", 2, 2, 5, true }
        }}
      else
        screen:expect{grid=[[
          ^example text that is wide|
          r than the window        |
               {1:some info!  }        |
                                   |
          more text                |
          {0:~                        }|
          {0:~                        }|
          {0:~                        }|
          {0:~                        }|
                                   |
        ]]}
      end

      meths.win_set_config(win, {relative='win', bufpos={1,32}, row=2})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [3:-------------------------]|
        ## grid 2
          ^example text that is wide|
          r than the window        |
                                   |
                                   |
          more text                |
          {0:~                        }|
          {0:~                        }|
          {0:~                        }|
          {0:~                        }|
        ## grid 3
                                   |
        ## grid 5
          {1:some info!  }|
        ]], float_pos={
          [5] = { {
              id = 1002
            }, "NW", 2, 3, 7, true }
        }}
      else
        screen:expect{grid=[[
          ^example text that is wide|
          r than the window        |
                                   |
                 {1:some info!  }      |
          more text                |
          {0:~                        }|
          {0:~                        }|
          {0:~                        }|
          {0:~                        }|
                                   |
        ]]}
      end
    end)

    it('validates cursor even when window is not entered', function()
      screen:try_resize(30,5)
      command("set nowrap")
      insert([[some text that is wider than the window]])
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:------------------------------]|
          [2:------------------------------]|
          [2:------------------------------]|
          [2:------------------------------]|
          [3:------------------------------]|
        ## grid 2
          that is wider than the windo^w |
          {0:~                             }|
          {0:~                             }|
          {0:~                             }|
        ## grid 3
                                        |
        ]])
      else
        screen:expect([[
          that is wider than the windo^w |
          {0:~                             }|
          {0:~                             }|
          {0:~                             }|
                                        |
        ]])
      end

      local buf = meths.create_buf(false,true)
      meths.buf_set_lines(buf, 0, -1, true, {'some floaty text'})
      meths.open_win(buf, false, {relative='editor', width=20, height=1, row=3, col=1})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:------------------------------]|
          [2:------------------------------]|
          [2:------------------------------]|
          [2:------------------------------]|
          [3:------------------------------]|
        ## grid 2
          that is wider than the windo^w |
          {0:~                             }|
          {0:~                             }|
          {0:~                             }|
        ## grid 3
                                        |
        ## grid 5
          {1:some floaty text    }|
        ]], float_pos={
          [5] = {{id = 1002}, "NW", 1, 3, 1, true}
        }}
      else
        screen:expect([[
          that is wider than the windo^w |
          {0:~                             }|
          {0:~                             }|
          {0:~}{1:some floaty text    }{0:         }|
                                        |
        ]])
      end
    end)

    if multigrid then
      pending("supports second UI without multigrid", function()
        local session2 = helpers.connect(eval('v:servername'))
        print(session2:request("nvim_eval", "2+2"))
        local screen2 = Screen.new(40,7)
        screen2:attach(nil, session2)
        screen2:set_default_attr_ids(attrs)
        local buf = meths.create_buf(false,false)
        meths.open_win(buf, true, {relative='editor', width=20, height=2, row=2, col=5})
        local expected_pos = {
          [2]={{id=1001}, 'NW', 1, 2, 5}
        }
        screen:expect{grid=[[
        ## grid 1
                                                  |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
                                                  |
        ## grid 2
          {1:^                    }|
          {2:~                   }|
        ]], float_pos=expected_pos}
        screen2:expect([[
                                                  |
          {0:~                                       }|
          {0:~    }{1:^                    }{0:               }|
          {0:~    }{2:~                   }{0:               }|
          {0:~                                       }|
          {0:~                                       }|
                                                  |
          ]])
      end)
    end


    it('handles resized screen', function()
      local buf = meths.create_buf(false,false)
      meths.buf_set_lines(buf, 0, -1, true, {'such', 'very', 'float'})
      local win = meths.open_win(buf, false, {relative='editor', width=15, height=4, row=2, col=10})
      local expected_pos = {
          [5]={{id=1002}, 'NW', 1, 2, 10, true},
      }
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 5
          {1:such           }|
          {1:very           }|
          {1:float          }|
          {2:~              }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
          ^                                        |
          {0:~                                       }|
          {0:~         }{1:such           }{0:               }|
          {0:~         }{1:very           }{0:               }|
          {0:~         }{1:float          }{0:               }|
          {0:~         }{2:~              }{0:               }|
                                                  |
        ]])
      end

      screen:try_resize(40,5)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 5
          {1:such           }|
          {1:very           }|
          {1:float          }|
          {2:~              }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
          ^          {1:such           }               |
          {0:~         }{1:very           }{0:               }|
          {0:~         }{1:float          }{0:               }|
          {0:~         }{2:~              }{0:               }|
                                                  |
        ]])
      end

      screen:try_resize(40,4)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 5
          {1:such           }|
          {1:very           }|
          {1:float          }|
          {2:~              }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
          ^          {1:such           }               |
          {0:~         }{1:very           }{0:               }|
          {0:~         }{1:float          }{0:               }|
                                                  |
        ]])
      end

      screen:try_resize(40,3)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [3:----------------------------------------]|
        ## grid 2
          ^                                        |
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 5
          {1:such           }|
          {1:very           }|
          {1:float          }|
          {2:~              }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
          ^          {1:such           }               |
          {0:~         }{1:very           }{0:               }|
                                                  |
        ]])
      end
      feed('<c-w>wjj')
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 5
          {1:such           }|
          {1:very           }|
          {1:^float          }|
          {2:~              }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                    {1:very           }               |
          {0:~         }{1:^float          }{0:               }|
                                                  |
        ]])
      end

      screen:try_resize(40,7)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 5
          {1:such           }|
          {1:very           }|
          {1:^float          }|
          {2:~              }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                                                  |
          {0:~                                       }|
          {0:~         }{1:such           }{0:               }|
          {0:~         }{1:very           }{0:               }|
          {0:~         }{1:^float          }{0:               }|
          {0:~         }{2:~              }{0:               }|
                                                  |
        ]])
      end

      meths.win_set_config(win, {height=3})
      feed('gg')
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 5
          {1:^such           }|
          {1:very           }|
          {1:float          }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                                                  |
          {0:~                                       }|
          {0:~         }{1:^such           }{0:               }|
          {0:~         }{1:very           }{0:               }|
          {0:~         }{1:float          }{0:               }|
          {0:~                                       }|
                                                  |
        ]])
      end

      screen:try_resize(26,7)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:--------------------------]|
          [2:--------------------------]|
          [2:--------------------------]|
          [2:--------------------------]|
          [2:--------------------------]|
          [2:--------------------------]|
          [3:--------------------------]|
        ## grid 2
                                    |
          {0:~                         }|
          {0:~                         }|
          {0:~                         }|
          {0:~                         }|
          {0:~                         }|
        ## grid 3
                                    |
        ## grid 5
          {1:^such           }|
          {1:very           }|
          {1:float          }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                                    |
          {0:~                         }|
          {0:~         }{1:^such           }{0: }|
          {0:~         }{1:very           }{0: }|
          {0:~         }{1:float          }{0: }|
          {0:~                         }|
                                    |
        ]])
      end

      screen:try_resize(25,7)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [2:-------------------------]|
          [3:-------------------------]|
        ## grid 2
                                   |
          {0:~                        }|
          {0:~                        }|
          {0:~                        }|
          {0:~                        }|
          {0:~                        }|
        ## grid 3
                                   |
        ## grid 5
          {1:^such           }|
          {1:very           }|
          {1:float          }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                                   |
          {0:~                        }|
          {0:~         }{1:^such           }|
          {0:~         }{1:very           }|
          {0:~         }{1:float          }|
          {0:~                        }|
                                   |
        ]])
      end

      screen:try_resize(24,7)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:------------------------]|
          [2:------------------------]|
          [2:------------------------]|
          [2:------------------------]|
          [2:------------------------]|
          [2:------------------------]|
          [3:------------------------]|
        ## grid 2
                                  |
          {0:~                       }|
          {0:~                       }|
          {0:~                       }|
          {0:~                       }|
          {0:~                       }|
        ## grid 3
                                  |
        ## grid 5
          {1:^such           }|
          {1:very           }|
          {1:float          }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                                  |
          {0:~                       }|
          {0:~        }{1:^such           }|
          {0:~        }{1:very           }|
          {0:~        }{1:float          }|
          {0:~                       }|
                                  |
        ]])
      end

      screen:try_resize(16,7)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------]|
          [2:----------------]|
          [2:----------------]|
          [2:----------------]|
          [2:----------------]|
          [2:----------------]|
          [3:----------------]|
        ## grid 2
                          |
          {0:~               }|
          {0:~               }|
          {0:~               }|
          {0:~               }|
          {0:~               }|
        ## grid 3
                          |
        ## grid 5
          {1:^such           }|
          {1:very           }|
          {1:float          }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                          |
          {0:~               }|
          {0:~}{1:^such           }|
          {0:~}{1:very           }|
          {0:~}{1:float          }|
          {0:~               }|
                          |
        ]])
      end

      screen:try_resize(15,7)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:---------------]|
          [2:---------------]|
          [2:---------------]|
          [2:---------------]|
          [2:---------------]|
          [2:---------------]|
          [3:---------------]|
        ## grid 2
                         |
          {0:~              }|
          {0:~              }|
          {0:~              }|
          {0:~              }|
          {0:~              }|
        ## grid 3
                         |
        ## grid 5
          {1:^such           }|
          {1:very           }|
          {1:float          }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                         |
          {0:~              }|
          {1:^such           }|
          {1:very           }|
          {1:float          }|
          {0:~              }|
                         |
        ]])
      end

      screen:try_resize(14,7)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:--------------]|
          [2:--------------]|
          [2:--------------]|
          [2:--------------]|
          [2:--------------]|
          [2:--------------]|
          [3:--------------]|
        ## grid 2
                        |
          {0:~             }|
          {0:~             }|
          {0:~             }|
          {0:~             }|
          {0:~             }|
        ## grid 3
                        |
        ## grid 5
          {1:^such           }|
          {1:very           }|
          {1:float          }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                        |
          {0:~             }|
          {1:^such          }|
          {1:very          }|
          {1:float         }|
          {0:~             }|
                        |
        ]])
      end

      screen:try_resize(12,7)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:------------]|
          [2:------------]|
          [2:------------]|
          [2:------------]|
          [2:------------]|
          [2:------------]|
          [3:------------]|
        ## grid 2
                      |
          {0:~           }|
          {0:~           }|
          {0:~           }|
          {0:~           }|
          {0:~           }|
        ## grid 3
                      |
        ## grid 5
          {1:^such           }|
          {1:very           }|
          {1:float          }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                      |
          {0:~           }|
          {1:^such        }|
          {1:very        }|
          {1:float       }|
          {0:~           }|
                      |
        ]])
      end

      -- Doesn't make much sense, but check nvim doesn't crash
      screen:try_resize(1,1)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:------------]|
          [3:------------]|
        ## grid 2
                      |
        ## grid 3
                      |
        ## grid 5
          {1:^such           }|
          {1:very           }|
          {1:float          }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
          {1:^such        }|
                      |
        ]])
      end

      screen:try_resize(40,7)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 5
          {1:^such           }|
          {1:very           }|
          {1:float          }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                                                  |
          {0:~                                       }|
          {0:~         }{1:^such           }{0:               }|
          {0:~         }{1:very           }{0:               }|
          {0:~         }{1:float          }{0:               }|
          {0:~                                       }|
                                                  |
        ]])
      end
    end)

    it('does not crash with inccommand #9379', function()
      local expected_pos = {
        [4]={{id=1001}, 'NW', 1, 2, 0, true},
      }

      command("set inccommand=split")
      command("set laststatus=2")

      local buf = meths.create_buf(false,false)
      meths.open_win(buf, true, {relative='editor', width=30, height=3, row=2, col=0})

      insert([[
      foo
      bar
      ]])

      if multigrid then
        screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {5:[No Name]                               }|
            [3:----------------------------------------]|
          ## grid 2
                                                    |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:foo                           }|
            {1:bar                           }|
            {1:^                              }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                                                  |
          {0:~                                       }|
          {1:foo                           }{0:          }|
          {1:bar                           }{0:          }|
          {1:^                              }{0:          }|
          {5:[No Name]                               }|
                                                  |
        ]])
      end

      feed(':%s/.')

      if multigrid then
        screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            {5:[No Name]                               }|
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            {5:[Preview]                               }|
            [3:----------------------------------------]|
          ## grid 2
                                                    |
          ## grid 3
            :%s/.^                                   |
          ## grid 4
            {17:f}{1:oo                           }|
            {17:b}{1:ar                           }|
            {1:                              }|
          ## grid 5
            |1| {17:f}oo                                 |
            |2| {17:b}ar                                 |
            {0:~                                       }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                                                  |
          {5:[No Name]                               }|
          {17:f}{1:oo                           }          |
          {17:b}{1:ar                           }          |
          {1:                              }{0:          }|
          {5:[Preview]                               }|
          :%s/.^                                   |
        ]])
      end

      feed('<Esc>')

      if multigrid then
        screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {5:[No Name]                               }|
            [3:----------------------------------------]|
          ## grid 2
                                                    |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:foo                           }|
            {1:bar                           }|
            {1:^                              }|
        ]], float_pos=expected_pos}
      else
        screen:expect([[
                                                  |
          {0:~                                       }|
          {1:foo                           }{0:          }|
          {1:bar                           }{0:          }|
          {1:^                              }{0:          }|
          {5:[No Name]                               }|
                                                  |
        ]])
      end
    end)

    it('does not crash when set cmdheight #9680', function()
      local buf = meths.create_buf(false,false)
      meths.open_win(buf, false, {relative='editor', width=20, height=2, row=2, col=5})
      command("set cmdheight=2")
      eq(1, meths.eval('1'))
    end)

    describe('and completion', function()
      before_each(function()
        local buf = meths.create_buf(false,false)
        local win = meths.open_win(buf, true, {relative='editor', width=12, height=4, row=2, col=5})
        meths.win_set_option(win , 'winhl', 'Normal:ErrorMsg')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
                                                    |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {7:^            }|
            {12:~           }|
            {12:~           }|
            {12:~           }|
          ]], float_pos={
            [4] = {{ id = 1001 }, "NW", 1, 2, 5, true},
          }}
        else
          screen:expect([[
                                                    |
            {0:~                                       }|
            {0:~    }{7:^            }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
                                                    |
          ]])
        end
      end)

      it('with builtin popupmenu', function()
        feed('ix ')
        funcs.complete(3, {'aa', 'word', 'longtext'})
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
                                                    |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {3:-- INSERT --}                            |
          ## grid 4
            {7:x aa^        }|
            {12:~           }|
            {12:~           }|
            {12:~           }|
          ## grid 5
            {13: aa             }|
            {1: word           }|
            {1: longtext       }|
          ]], float_pos={
            [4] = {{ id = 1001 }, "NW", 1, 2, 5, true},
            [5] = {{ id = -1 }, "NW", 4, 1, 1, false}
          }}
        else
          screen:expect([[
                                                    |
            {0:~                                       }|
            {0:~    }{7:x aa^        }{0:                       }|
            {0:~    }{12:~}{13: aa             }{0:                  }|
            {0:~    }{12:~}{1: word           }{0:                  }|
            {0:~    }{12:~}{1: longtext       }{0:                  }|
            {3:-- INSERT --}                            |
          ]])
        end

        feed('<esc>')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
                                                    |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {7:x a^a        }|
            {12:~           }|
            {12:~           }|
            {12:~           }|
          ]], float_pos={
            [4] = {{ id = 1001 }, "NW", 1, 2, 5, true},
          }}

        else
          screen:expect([[
                                                    |
            {0:~                                       }|
            {0:~    }{7:x a^a        }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
                                                    |
          ]])
        end

        feed('<c-w>wi')
        funcs.complete(1, {'xx', 'yy', 'zz'})
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            xx^                                      |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {3:-- INSERT --}                            |
          ## grid 4
            {7:x aa        }|
            {12:~           }|
            {12:~           }|
            {12:~           }|
          ## grid 5
            {13:xx             }|
            {1:yy             }|
            {1:zz             }|
          ]], float_pos={
            [4] = {{ id = 1001 }, "NW", 1, 2, 5, true},
            [5] = {{ id = -1 }, "NW", 2, 1, 0, false}
          }}
        else
          screen:expect([[
            xx^                                      |
            {13:xx             }{0:                         }|
            {1:yy             }{7:  }{0:                       }|
            {1:zz             }{12:  }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {3:-- INSERT --}                            |
          ]])
        end

        feed('<c-y>')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            xx^                                      |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {3:-- INSERT --}                            |
          ## grid 4
            {7:x aa        }|
            {12:~           }|
            {12:~           }|
            {12:~           }|
          ]], float_pos={
            [4] = {{ id = 1001 }, "NW", 1, 2, 5, true},
          }}
        else
          screen:expect([[
            xx^                                      |
            {0:~                                       }|
            {0:~    }{7:x aa        }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {3:-- INSERT --}                            |
          ]])
        end
      end)

      it('with ext_popupmenu', function()
        screen:set_option('ext_popupmenu', true)
        feed('ix ')
        funcs.complete(3, {'aa', 'word', 'longtext'})
        local items = {{"aa", "", "", ""}, {"word", "", "", ""}, {"longtext", "", "", ""}}
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
                                                    |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {3:-- INSERT --}                            |
          ## grid 4
            {7:x aa^        }|
            {12:~           }|
            {12:~           }|
            {12:~           }|
          ]], float_pos={
            [4] = {{ id = 1001 }, "NW", 1, 2, 5, true},
          }, popupmenu={
            anchor = {4, 0, 2}, items = items, pos = 0
          }}
        else
          screen:expect{grid=[[
                                                    |
            {0:~                                       }|
            {0:~    }{7:x aa^        }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {3:-- INSERT --}                            |
          ]], popupmenu={
            anchor = {1, 2, 7}, items = items, pos = 0
          }}
        end

        feed('<esc>')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
                                                    |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {7:x a^a        }|
            {12:~           }|
            {12:~           }|
            {12:~           }|
          ]], float_pos={
            [4] = {{ id = 1001 }, "NW", 1, 2, 5, true},
          }}
        else
          screen:expect([[
                                                    |
            {0:~                                       }|
            {0:~    }{7:x a^a        }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
                                                    |
          ]])
        end

        feed('<c-w>wi')
        funcs.complete(1, {'xx', 'yy', 'zz'})
        items = {{"xx", "", "", ""}, {"yy", "", "", ""}, {"zz", "", "", ""}}
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            xx^                                      |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {3:-- INSERT --}                            |
          ## grid 4
            {7:x aa        }|
            {12:~           }|
            {12:~           }|
            {12:~           }|
          ]], float_pos={
            [4] = {{ id = 1001 }, "NW", 1, 2, 5, true},
          }, popupmenu={
            anchor = {2, 0, 0}, items = items, pos = 0
          }}
        else
          screen:expect{grid=[[
            xx^                                      |
            {0:~                                       }|
            {0:~    }{7:x aa        }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {3:-- INSERT --}                            |
          ]], popupmenu={
            anchor = {1, 0, 0}, items = items, pos = 0
          }}
        end

        feed('<c-y>')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            xx^                                      |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {3:-- INSERT --}                            |
          ## grid 4
            {7:x aa        }|
            {12:~           }|
            {12:~           }|
            {12:~           }|
          ]], float_pos={
            [4] = {{ id = 1001 }, "NW", 1, 2, 5, true},
          }}
        else
          screen:expect([[
            xx^                                      |
            {0:~                                       }|
            {0:~    }{7:x aa        }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {0:~    }{12:~           }{0:                       }|
            {3:-- INSERT --}                            |
          ]])
        end
      end)
    end)

    describe('float shown after pum', function()
      local win
      before_each(function()
        command('hi NormalFloat guibg=#333333')
        feed('i')
        funcs.complete(1, {'aa', 'word', 'longtext'})
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            aa^                                      |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {3:-- INSERT --}                            |
          ## grid 4
            {13:aa             }|
            {1:word           }|
            {1:longtext       }|
          ]], float_pos={
            [4] = {{id = -1}, "NW", 2, 1, 0, false}}
          }
        else
          screen:expect([[
            aa^                                      |
            {13:aa             }{0:                         }|
            {1:word           }{0:                         }|
            {1:longtext       }{0:                         }|
            {0:~                                       }|
            {0:~                                       }|
            {3:-- INSERT --}                            |
          ]])
        end

        local buf = meths.create_buf(false,true)
        meths.buf_set_lines(buf,0,-1,true,{"some info", "about item"})
        win = meths.open_win(buf, false, {relative='cursor', width=12, height=2, row=1, col=10})
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            aa^                                      |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {3:-- INSERT --}                            |
          ## grid 4
            {13:aa             }|
            {1:word           }|
            {1:longtext       }|
          ## grid 6
            {15:some info   }|
            {15:about item  }|
          ]], float_pos={
            [4] = {{id = -1}, "NW", 2, 1, 0, false},
            [6] = {{id = 1002}, "NW", 2, 1, 12, true},
          }}
        else
          screen:expect([[
            aa^                                      |
            {13:aa             }{15:e info   }{0:                }|
            {1:word           }{15:ut item  }{0:                }|
            {1:longtext       }{0:                         }|
            {0:~                                       }|
            {0:~                                       }|
            {3:-- INSERT --}                            |
          ]])
        end
      end)

      it('and close pum first', function()
        feed('<c-y>')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            aa^                                      |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {3:-- INSERT --}                            |
          ## grid 6
            {15:some info   }|
            {15:about item  }|
          ]], float_pos={
            [6] = {{id = 1002}, "NW", 2, 1, 12, true},
          }}
        else
          screen:expect([[
            aa^                                      |
            {0:~           }{15:some info   }{0:                }|
            {0:~           }{15:about item  }{0:                }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {3:-- INSERT --}                            |
          ]])
        end

        meths.win_close(win, false)
        if multigrid then
          screen:expect([[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            aa^                                      |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {3:-- INSERT --}                            |
          ]])
        else
          screen:expect([[
            aa^                                      |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {3:-- INSERT --}                            |
          ]])
        end
      end)

      it('and close float first', function()
        meths.win_close(win, false)
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            aa^                                      |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {3:-- INSERT --}                            |
          ## grid 4
            {13:aa             }|
            {1:word           }|
            {1:longtext       }|
          ]], float_pos={
            [4] = {{id = -1}, "NW", 2, 1, 0, false},
          }}
        else
          screen:expect([[
            aa^                                      |
            {13:aa             }{0:                         }|
            {1:word           }{0:                         }|
            {1:longtext       }{0:                         }|
            {0:~                                       }|
            {0:~                                       }|
            {3:-- INSERT --}                            |
          ]])
        end

        feed('<c-y>')
        if multigrid then
          screen:expect([[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            aa^                                      |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {3:-- INSERT --}                            |
          ]])
        else
          screen:expect([[
            aa^                                      |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {3:-- INSERT --}                            |
          ]])
        end
      end)
    end)

    describe("handles :wincmd", function()
      local win
      local expected_pos
      before_each(function()
        -- the default, but be explicit:
        command("set laststatus=1")
        command("set hidden")
        meths.buf_set_lines(0,0,-1,true,{"x"})
        local buf = meths.create_buf(false,false)
        win = meths.open_win(buf, false, {relative='editor', width=20, height=2, row=2, col=5})
        meths.buf_set_lines(buf,0,-1,true,{"y"})
        expected_pos = {
          [4]={{id=1001}, 'NW', 1, 2, 5, true}
        }
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end
      end)

      it("w", function()
        feed("<c-w>w")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:^y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end

        feed("<c-w>w")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end
      end)

      it("w with focusable=false", function()
        meths.win_set_config(win, {focusable=false})
        expected_pos[4][6] = false
        feed("<c-w>wi") -- i to provoke redraw
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {3:-- INSERT --}                            |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
            {3:-- INSERT --}                            |
          ]])
        end

        feed("<esc><c-w>w")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end
      end)

      it("W", function()
        feed("<c-w>W")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:^y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end

        feed("<c-w>W")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end
      end)

      it("focus by mouse", function()
        if multigrid then
          meths.input_mouse('left', 'press', '', 4, 0, 0)
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:^y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          meths.input_mouse('left', 'press', '', 0, 2, 5)
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end

        if multigrid then
          meths.input_mouse('left', 'press', '', 1, 0, 0)
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          meths.input_mouse('left', 'press', '', 0, 0, 0)
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end
      end)

      it("focus by mouse (focusable=false)", function()
        meths.win_set_config(win, {focusable=false})
        meths.buf_set_lines(0, -1, -1, true, {"a"})
        expected_pos[4][6] = false
        if multigrid then
          meths.input_mouse('left', 'press', '', 4, 0, 0)
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            a                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          meths.input_mouse('left', 'press', '', 0, 2, 5)
          screen:expect([[
            x                                       |
            ^a                                       |
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end

        if multigrid then
          meths.input_mouse('left', 'press', '', 1, 0, 0)
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            a                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos, unchanged=true}
        else
          meths.input_mouse('left', 'press', '', 0, 0, 0)
          screen:expect([[
            ^x                                       |
            a                                       |
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end
      end)


      it("j", function()
        feed("<c-w>ji") -- INSERT to trigger screen change
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {3:-- INSERT --}                            |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
            {3:-- INSERT --}                            |
          ]])
        end

        feed("<esc><c-w>w")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:^y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end

        feed("<c-w>j")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end

      end)

      it("vertical resize + - _", function()
        feed('<c-w>w')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:^y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end

        feed('<c-w>+')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:^y                   }|
            {2:~                   }|
            {2:~                   }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
                                                    |
          ]])
        end

        feed('<c-w>2-')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:^y                   }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end

        feed('<c-w>4_')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:^y                   }|
            {2:~                   }|
            {2:~                   }|
            {2:~                   }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
                                                    |
          ]])
        end

        feed('<c-w>_')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:^y                   }|
            {2:~                   }|
            {2:~                   }|
            {2:~                   }|
            {2:~                   }|
            {2:~                   }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            x    {1:^y                   }               |
            {0:~    }{2:~                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
                                                    |
          ]])
        end
      end)

      it("horizontal resize > < |", function()
        feed('<c-w>w')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:^y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end

        feed('<c-w>>')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:^y                    }|
            {2:~                    }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y                    }{0:              }|
            {0:~    }{2:~                    }{0:              }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end

        feed('<c-w>10<lt>')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:^y          }|
            {2:~          }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y          }{0:                        }|
            {0:~    }{2:~          }{0:                        }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end

        feed('<c-w>15|')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:^y              }|
            {2:~              }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y              }{0:                    }|
            {0:~    }{2:~              }{0:                    }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end

        feed('<c-w>|')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:^y                                       }|
            {2:~                                       }|
          ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {1:^y                                       }|
            {2:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end
      end)

      it("s :split (non-float)", function()
        feed("<c-w>s")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            {4:[No Name] [+]                           }|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {5:[No Name] [+]                           }|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            ^x                                       |
            {0:~                                       }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {4:[No N}{1:y                   }{4:               }|
            x    {2:~                   }               |
            {0:~                                       }|
            {5:[No Name] [+]                           }|
                                                    |
          ]])
        end

        feed("<c-w>w")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            {5:[No Name] [+]                           }|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {4:[No Name] [+]                           }|
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            x                                       |
            {0:~                                       }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {5:[No N}{1:y                   }{5:               }|
            ^x    {2:~                   }               |
            {0:~                                       }|
            {4:[No Name] [+]                           }|
                                                    |
          ]])
        end

        feed("<c-w>w")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            {5:[No Name] [+]                           }|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {5:[No Name] [+]                           }|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:^y                   }|
            {2:~                   }|
          ## grid 5
            x                                       |
            {0:~                                       }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {5:[No N}{1:^y                   }{5:               }|
            x    {2:~                   }               |
            {0:~                                       }|
            {5:[No Name] [+]                           }|
                                                    |
          ]])
        end


        feed("<c-w>w")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            {4:[No Name] [+]                           }|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {5:[No Name] [+]                           }|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            ^x                                       |
            {0:~                                       }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {4:[No N}{1:y                   }{4:               }|
            x    {2:~                   }               |
            {0:~                                       }|
            {5:[No Name] [+]                           }|
                                                    |
          ]])
        end
      end)

      it("s :split (float)", function()
        feed("<c-w>w<c-w>s")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            {4:[No Name] [+]                           }|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {5:[No Name] [+]                           }|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            ^y                                       |
            {0:~                                       }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^y                                       |
            {0:~                                       }|
            {4:[No N}{1:y                   }{4:               }|
            x    {2:~                   }               |
            {0:~                                       }|
            {5:[No Name] [+]                           }|
                                                    |
          ]])
        end

        feed("<c-w>j")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            {5:[No Name] [+]                           }|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {4:[No Name] [+]                           }|
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            y                                       |
            {0:~                                       }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            y                                       |
            {0:~                                       }|
            {5:[No N}{1:y                   }{5:               }|
            ^x    {2:~                   }               |
            {0:~                                       }|
            {4:[No Name] [+]                           }|
                                                    |
          ]])
        end

        feed("<c-w>ji")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            {5:[No Name] [+]                           }|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {4:[No Name] [+]                           }|
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|
          ## grid 3
            {3:-- INSERT --}                            |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            y                                       |
            {0:~                                       }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            y                                       |
            {0:~                                       }|
            {5:[No N}{1:y                   }{5:               }|
            ^x    {2:~                   }               |
            {0:~                                       }|
            {4:[No Name] [+]                           }|
            {3:-- INSERT --}                            |
          ]])
        end
      end)

      it(":new (non-float)", function()
        feed(":new<cr>")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            {4:[No Name]                               }|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {5:[No Name] [+]                           }|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
            :new                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            ^                                        |
            {0:~                                       }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^                                        |
            {0:~                                       }|
            {4:[No N}{1:y                   }{4:               }|
            x    {2:~                   }               |
            {0:~                                       }|
            {5:[No Name] [+]                           }|
            :new                                    |
          ]])
        end
      end)

      it(":new (float)", function()
        feed("<c-w>w:new<cr>")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            {4:[No Name]                               }|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {5:[No Name] [+]                           }|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
            :new                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            ^                                        |
            {0:~                                       }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^                                        |
            {0:~                                       }|
            {4:[No N}{1:y                   }{4:               }|
            x    {2:~                   }               |
            {0:~                                       }|
            {5:[No Name] [+]                           }|
            :new                                    |
          ]])
        end
      end)

      it("v :vsplit (non-float)", function()
        feed("<c-w>v")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:--------------------]{5:│}[2:-------------------]|
            [5:--------------------]{5:│}[2:-------------------]|
            [5:--------------------]{5:│}[2:-------------------]|
            [5:--------------------]{5:│}[2:-------------------]|
            [5:--------------------]{5:│}[2:-------------------]|
            {4:[No Name] [+]        }{5:[No Name] [+]      }|
            [3:----------------------------------------]|
          ## grid 2
            x                  |
            {0:~                  }|
            {0:~                  }|
            {0:~                  }|
            {0:~                  }|
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            ^x                   |
            {0:~                   }|
            {0:~                   }|
            {0:~                   }|
            {0:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                   {5:│}x                  |
            {0:~                   }{5:│}{0:~                  }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                   }{5:│}{0:~                  }|
            {4:[No Name] [+]        }{5:[No Name] [+]      }|
                                                    |
          ]])
        end
      end)

      it(":vnew (non-float)", function()
        feed(":vnew<cr>")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:--------------------]{5:│}[2:-------------------]|
            [5:--------------------]{5:│}[2:-------------------]|
            [5:--------------------]{5:│}[2:-------------------]|
            [5:--------------------]{5:│}[2:-------------------]|
            [5:--------------------]{5:│}[2:-------------------]|
            {4:[No Name]            }{5:[No Name] [+]      }|
            [3:----------------------------------------]|
          ## grid 2
            x                  |
            {0:~                  }|
            {0:~                  }|
            {0:~                  }|
            {0:~                  }|
          ## grid 3
            :vnew                                   |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            ^                    |
            {0:~                   }|
            {0:~                   }|
            {0:~                   }|
            {0:~                   }|
        ]], float_pos=expected_pos}
        else
        screen:expect([[
          ^                    {5:│}x                  |
          {0:~                   }{5:│}{0:~                  }|
          {0:~    }{1:y                   }{0:               }|
          {0:~    }{2:~                   }{0:               }|
          {0:~                   }{5:│}{0:~                  }|
          {4:[No Name]            }{5:[No Name] [+]      }|
          :vnew                                   |
        ]])
        end
      end)

      it(":vnew (float)", function()
        feed("<c-w>w:vnew<cr>")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:--------------------]{5:│}[2:-------------------]|
            [5:--------------------]{5:│}[2:-------------------]|
            [5:--------------------]{5:│}[2:-------------------]|
            [5:--------------------]{5:│}[2:-------------------]|
            [5:--------------------]{5:│}[2:-------------------]|
            {4:[No Name]            }{5:[No Name] [+]      }|
            [3:----------------------------------------]|
          ## grid 2
            x                  |
            {0:~                  }|
            {0:~                  }|
            {0:~                  }|
            {0:~                  }|
          ## grid 3
            :vnew                                   |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            ^                    |
            {0:~                   }|
            {0:~                   }|
            {0:~                   }|
            {0:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^                    {5:│}x                  |
            {0:~                   }{5:│}{0:~                  }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                   }{5:│}{0:~                  }|
            {4:[No Name]            }{5:[No Name] [+]      }|
            :vnew                                   |
          ]])
        end
      end)

      it("q (:quit) last non-float exits nvim", function()
        command('autocmd VimLeave    * call rpcrequest(1, "exit")')
        -- avoid unsaved change in other buffer
        feed("<c-w><c-w>:w Xtest_written2<cr><c-w><c-w>")
        -- quit in last non-float
        feed(":wq Xtest_written<cr>")
        local exited = false
        local function on_request(name, args)
          eq("exit", name)
          eq({}, args)
          exited = true
          return 0
        end
        local function on_setup()
          feed(":wq Xtest_written<cr>")
        end
        run(on_request, nil, on_setup)
        os.remove('Xtest_written')
        os.remove('Xtest_written2')
        eq(exited, true)
      end)

      it(':quit two floats in a row', function()
        -- enter first float
        feed('<c-w><c-w>')
        -- enter second float
        meths.open_win(0, true, {relative='editor', width=20, height=2, row=4, col=8})
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            {1:^y                   }|
            {2:~                   }|
          ]], float_pos={
            [4] = {{id = 1001}, "NW", 1, 2, 5, true},
            [5] = {{id = 1002}, "NW", 1, 4, 8, true}
          }}
         else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~       }{1:^y                   }{0:            }|
            {0:~       }{2:~                   }{0:            }|
                                                    |
          ]])
        end

        feed(':quit<cr>')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {5:[No Name] [+]                           }|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            :quit                                   |
          ## grid 4
            {1:^y                   }|
            {2:~                   }|
          ]], float_pos={
            [4] = {{id = 1001}, "NW", 1, 2, 5, true},
          }}
         else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {5:[No Name] [+]                           }|
            :quit                                   |
          ]])
        end

        feed(':quit<cr>')
        if multigrid then
          screen:expect([[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            :quit                                   |
          ]])
         else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            :quit                                   |
          ]])
        end

        eq(2, eval('1+1'))
      end)

      it("o (:only) non-float", function()
        feed("<c-w>o")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
        ]]}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end
      end)

      it("o (:only) float fails", function()
        feed("<c-w>w<c-w>o")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
            [3:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            {7:E5601: Cannot close window, only floatin}|
            {7:g window would remain}                   |
            {8:Press ENTER or type command to continue}^ |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:y                   }{0:               }|
            {4:                                        }|
            {7:E5601: Cannot close window, only floatin}|
            {7:g window would remain}                   |
            {8:Press ENTER or type command to continue}^ |
          ]])
        end

        -- test message clear
        feed('<cr>')
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:^y                   }|
            {2:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {0:~    }{1:^y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end
      end)

      it("o (:only) non-float with split", function()
        feed("<c-w>s")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            {4:[No Name] [+]                           }|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {5:[No Name] [+]                           }|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            ^x                                       |
            {0:~                                       }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {4:[No N}{1:y                   }{4:               }|
            x    {2:~                   }               |
            {0:~                                       }|
            {5:[No Name] [+]                           }|
                                                    |
          ]])
        end

        feed("<c-w>o")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 3
                                                    |
          ## grid 5
            ^x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
        ]]}
        else
          screen:expect([[
            ^x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
                                                    |
          ]])
        end
      end)

      it("o (:only) float with split", function()
        feed("<c-w>s<c-w>W")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            {5:[No Name] [+]                           }|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {5:[No Name] [+]                           }|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            {1:^y                   }|
            {2:~                   }|
          ## grid 5
            x                                       |
            {0:~                                       }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {5:[No N}{1:^y                   }{5:               }|
            x    {2:~                   }               |
            {0:~                                       }|
            {5:[No Name] [+]                           }|
                                                    |
          ]])
        end

        feed("<c-w>o")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            {5:[No Name] [+]                           }|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
            [3:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
            {7:E5601: Cannot close window, only floatin}|
            {7:g window would remain}                   |
            {8:Press ENTER or type command to continue}^ |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            x                                       |
            {0:~                                       }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {5:[No N}{1:y                   }{5:               }|
            {4:                                        }|
            {7:E5601: Cannot close window, only floatin}|
            {7:g window would remain}                   |
            {8:Press ENTER or type command to continue}^ |
          ]])
        end
      end)

      it("J (float)", function()
        feed("<c-w>w<c-w>J")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {5:[No Name] [+]                           }|
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            {4:[No Name] [+]                           }|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            ^y                                       |
            {0:~                                       }|
        ]]}
        else
          screen:expect([[
            x                                       |
            {0:~                                       }|
            {5:[No Name] [+]                           }|
            ^y                                       |
            {0:~                                       }|
            {4:[No Name] [+]                           }|
                                                    |
          ]])
        end

        if multigrid then
          meths.win_set_config(0, {external=true, width=30, height=2})
          expected_pos = {[4]={external=true}}
          screen:expect{grid=[[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {5:[No Name] [+]                           }|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            ^y                             |
            {0:~                             }|
        ]], float_pos=expected_pos}
        else
          eq("UI doesn't support external windows",
             pcall_err(meths.win_set_config, 0, {external=true, width=30, height=2}))
          return
        end

        feed("<c-w>J")
        if multigrid then
          screen:expect([[
          ## grid 1
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            {5:[No Name] [+]                           }|
            [4:----------------------------------------]|
            [4:----------------------------------------]|
            {4:[No Name] [+]                           }|
            [3:----------------------------------------]|
          ## grid 2
            x                                       |
            {0:~                                       }|
          ## grid 3
                                                    |
          ## grid 4
            ^y                                       |
            {0:~                                       }|
          ]])
        end
      end)

      it('movements with nested split layout', function()
        command("set hidden")
        feed("<c-w>s<c-w>v<c-w>b<c-w>v")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [6:--------------------]{5:│}[5:-------------------]|
            [6:--------------------]{5:│}[5:-------------------]|
            {5:[No Name] [+]        [No Name] [+]      }|
            [7:--------------------]{5:│}[2:-------------------]|
            [7:--------------------]{5:│}[2:-------------------]|
            {4:[No Name] [+]        }{5:[No Name] [+]      }|
            [3:----------------------------------------]|
          ## grid 2
            x                  |
            {0:~                  }|
          ## grid 3
                                                    |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            x                  |
            {0:~                  }|
          ## grid 6
            x                   |
            {0:~                   }|
          ## grid 7
            ^x                   |
            {0:~                   }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            x                   {5:│}x                  |
            {0:~                   }{5:│}{0:~                  }|
            {5:[No N}{1:y                   }{5:Name] [+]      }|
            ^x    {2:~                   }               |
            {0:~                   }{5:│}{0:~                  }|
            {4:[No Name] [+]        }{5:[No Name] [+]      }|
                                                    |
          ]])
        end

        -- verify that N<c-w>w works
        for i = 1,5 do
          feed(i.."<c-w>w")
          feed_command("enew")
          curbufmeths.set_lines(0,-1,true,{tostring(i)})
        end

        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            [6:-------------------]{5:│}[5:--------------------]|
            [6:-------------------]{5:│}[5:--------------------]|
            {5:[No Name] [+]       [No Name] [+]       }|
            [7:-------------------]{5:│}[2:--------------------]|
            [7:-------------------]{5:│}[2:--------------------]|
            {5:[No Name] [+]       [No Name] [+]       }|
            [3:----------------------------------------]|
          ## grid 2
            4                   |
            {0:~                   }|
          ## grid 3
            :enew                                   |
          ## grid 4
            {1:^5                   }|
            {2:~                   }|
          ## grid 5
            2                   |
            {0:~                   }|
          ## grid 6
            1                  |
            {0:~                  }|
          ## grid 7
            3                  |
            {0:~                  }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            1                  {5:│}2                   |
            {0:~                  }{5:│}{0:~                   }|
            {5:[No N}{1:^5                   }{5:ame] [+]       }|
            3    {2:~                   }               |
            {0:~                  }{5:│}{0:~                   }|
            {5:[No Name] [+]       [No Name] [+]       }|
            :enew                                   |
          ]])
        end

        local movements = {
          w={2,3,4,5,1},
          W={5,1,2,3,4},
          h={1,1,3,3,3},
          j={3,3,3,4,4},
          k={1,2,1,1,1},
          l={2,2,4,4,4},
          t={1,1,1,1,1},
          b={4,4,4,4,4},
        }

        for k,v in pairs(movements) do
          for i = 1,5 do
            feed(i.."<c-w>w")
            feed('<c-w>'..k)
            local nr = funcs.winnr()
            eq(v[i],nr, "when using <c-w>"..k.." from window "..i)
          end
        end

        for i = 1,5 do
          feed(i.."<c-w>w")
          for j = 1,5 do
            if j ~= i then
              feed(j.."<c-w>w")
              feed('<c-w>p')
              local nr = funcs.winnr()
              eq(i,nr, "when using <c-w>p to window "..i.." from window "..j)
            end
          end
        end

      end)

      it(":tabnew and :tabnext", function()
        feed(":tabnew<cr>")
        if multigrid then
          -- grid is not freed, but float is marked as closed (should it rather be "invisible"?)
          screen:expect{grid=[[
          ## grid 1
            {9: }{10:2}{9:+ [No Name] }{3: [No Name] }{5:              }{9:X}|
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2 (hidden)
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            :tabnew                                 |
          ## grid 4 (hidden)
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            ^                                        |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ]]}
        else
          screen:expect([[
            {9: }{10:2}{9:+ [No Name] }{3: [No Name] }{5:              }{9:X}|
            ^                                        |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            :tabnew                                 |
          ]])
        end

        feed(":tabnext<cr>")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            {3: }{11:2}{3:+ [No Name] }{9: [No Name] }{5:              }{9:X}|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            :tabnext                                |
          ## grid 4
            {1:y                   }|
            {2:~                   }|
          ## grid 5 (hidden)
                                                    |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
        ]], float_pos=expected_pos}
        else
          screen:expect([[
            {3: }{11:2}{3:+ [No Name] }{9: [No Name] }{5:              }{9:X}|
            ^x                                       |
            {0:~    }{1:y                   }{0:               }|
            {0:~    }{2:~                   }{0:               }|
            {0:~                                       }|
            {0:~                                       }|
            :tabnext                                |
          ]])
        end

        feed(":tabnext<cr>")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            {9: }{10:2}{9:+ [No Name] }{3: [No Name] }{5:              }{9:X}|
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2 (hidden)
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            :tabnext                                |
          ## grid 4 (hidden)
            {1:y                   }|
            {2:~                   }|
          ## grid 5
            ^                                        |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
        ]]}
        else
          screen:expect([[
            {9: }{10:2}{9:+ [No Name] }{3: [No Name] }{5:              }{9:X}|
            ^                                        |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            :tabnext                                |
          ]])
        end
      end)

      it(":tabnew and :tabnext (external)", function()
        if multigrid then
          -- also test external window wider than main screen
          meths.win_set_config(win, {external=true, width=65, height=4})
          expected_pos = {[4]={external=true}}
          feed(":tabnew<cr>")
          screen:expect{grid=[[
          ## grid 1
            {9: + [No Name] }{3: }{11:2}{3:+ [No Name] }{5:            }{9:X}|
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2 (hidden)
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            :tabnew                                 |
          ## grid 4
            y                                                                |
            {0:~                                                                }|
            {0:~                                                                }|
            {0:~                                                                }|
          ## grid 5
            ^                                        |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
        ]], float_pos=expected_pos}
        else
          eq("UI doesn't support external windows",
             pcall_err(meths.win_set_config, 0, {external=true, width=65, height=4}))
        end

        feed(":tabnext<cr>")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            {3: }{11:2}{3:+ [No Name] }{9: [No Name] }{5:              }{9:X}|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [2:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2
            ^x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            :tabnext                                |
          ## grid 4
            y                                                                |
            {0:~                                                                }|
            {0:~                                                                }|
            {0:~                                                                }|
          ## grid 5 (hidden)
                                                    |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
        ]], float_pos=expected_pos}
        end

        feed(":tabnext<cr>")
        if multigrid then
          screen:expect{grid=[[
          ## grid 1
            {9: + [No Name] }{3: }{11:2}{3:+ [No Name] }{5:            }{9:X}|
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            [5:----------------------------------------]|
            [3:----------------------------------------]|
          ## grid 2 (hidden)
            x                                       |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
          ## grid 3
            :tabnext                                |
          ## grid 4
            y                                                                |
            {0:~                                                                }|
            {0:~                                                                }|
            {0:~                                                                }|
          ## grid 5
            ^                                        |
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
            {0:~                                       }|
        ]], float_pos=expected_pos}
        end
      end)
    end)

    it("'winblend' option", function()
      screen:try_resize(50,9)
      screen:set_default_attr_ids({
        [1] = {background = Screen.colors.LightMagenta},
        [2] = {foreground = Screen.colors.Grey0, background = tonumber('0xffcfff')},
        [3] = {foreground = tonumber('0xb282b2'), background = tonumber('0xffcfff')},
        [4] = {foreground = Screen.colors.Red, background = Screen.colors.LightMagenta},
        [5] = {foreground = tonumber('0x990000'), background = tonumber('0xfff1ff')},
        [6] = {foreground = tonumber('0x332533'), background = tonumber('0xfff1ff')},
        [7] = {background = tonumber('0xffcfff'), bold = true, foreground = tonumber('0x0000d8')},
        [8] = {background = Screen.colors.LightMagenta, bold = true, foreground = Screen.colors.Blue1},
        [9] = {background = Screen.colors.LightMagenta, blend=30},
        [10] = {foreground = Screen.colors.Red, background = Screen.colors.LightMagenta, blend=0},
        [11] = {foreground = Screen.colors.Red, background = Screen.colors.LightMagenta, blend=80},
        [12] = {background = Screen.colors.LightMagenta, bold = true, foreground = Screen.colors.Blue1, blend=30},
      })
      insert([[
        Lorem ipsum dolor sit amet, consectetur
        adipisicing elit, sed do eiusmod tempor
        incididunt ut labore et dolore magna aliqua.
        Ut enim ad minim veniam, quis nostrud
        exercitation ullamco laboris nisi ut aliquip ex
        ea commodo consequat. Duis aute irure dolor in
        reprehenderit in voluptate velit esse cillum
        dolore eu fugiat nulla pariatur. Excepteur sint
        occaecat cupidatat non proident, sunt in culpa
        qui officia deserunt mollit anim id est
        laborum.]])
      local buf = meths.create_buf(false,false)
      meths.buf_set_lines(buf, 0, -1, true, {"test", "", "popup    text"})
      local win = meths.open_win(buf, false, {relative='editor', width=15, height=3, row=2, col=5})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [3:--------------------------------------------------]|
        ## grid 2
          Ut enim ad minim veniam, quis nostrud             |
          exercitation ullamco laboris nisi ut aliquip ex   |
          ea commodo consequat. Duis aute irure dolor in    |
          reprehenderit in voluptate velit esse cillum      |
          dolore eu fugiat nulla pariatur. Excepteur sint   |
          occaecat cupidatat non proident, sunt in culpa    |
          qui officia deserunt mollit anim id est           |
          laborum^.                                          |
        ## grid 3
                                                            |
        ## grid 5
          {1:test           }|
          {1:               }|
          {1:popup    text  }|
        ]], float_pos={[5] = {{id = 1002}, "NW", 1, 2, 5, true}}}
      else
        screen:expect([[
          Ut enim ad minim veniam, quis nostrud             |
          exercitation ullamco laboris nisi ut aliquip ex   |
          ea co{1:test           }. Duis aute irure dolor in    |
          repre{1:               }uptate velit esse cillum      |
          dolor{1:popup    text  }la pariatur. Excepteur sint   |
          occaecat cupidatat non proident, sunt in culpa    |
          qui officia deserunt mollit anim id est           |
          laborum^.                                          |
                                                            |
        ]])
      end

      meths.win_set_option(win, "winblend", 30)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [3:--------------------------------------------------]|
        ## grid 2
          Ut enim ad minim veniam, quis nostrud             |
          exercitation ullamco laboris nisi ut aliquip ex   |
          ea commodo consequat. Duis aute irure dolor in    |
          reprehenderit in voluptate velit esse cillum      |
          dolore eu fugiat nulla pariatur. Excepteur sint   |
          occaecat cupidatat non proident, sunt in culpa    |
          qui officia deserunt mollit anim id est           |
          laborum^.                                          |
        ## grid 3
                                                            |
        ## grid 5
          {9:test           }|
          {9:               }|
          {9:popup    text  }|
        ]], float_pos={[5] = {{id = 1002}, "NW", 1, 2, 5, true}}, unchanged=true}
      else
        screen:expect([[
          Ut enim ad minim veniam, quis nostrud             |
          exercitation ullamco laboris nisi ut aliquip ex   |
          ea co{2:test}{3:o consequat}. Duis aute irure dolor in    |
          repre{3:henderit in vol}uptate velit esse cillum      |
          dolor{2:popup}{3:fugi}{2:text}{3:ul}la pariatur. Excepteur sint   |
          occaecat cupidatat non proident, sunt in culpa    |
          qui officia deserunt mollit anim id est           |
          laborum^.                                          |
                                                            |
        ]])
      end

      command('hi SpecialRegion guifg=Red blend=0')
      meths.buf_add_highlight(buf, -1, "SpecialRegion", 2, 0, -1)
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [3:--------------------------------------------------]|
        ## grid 2
          Ut enim ad minim veniam, quis nostrud             |
          exercitation ullamco laboris nisi ut aliquip ex   |
          ea commodo consequat. Duis aute irure dolor in    |
          reprehenderit in voluptate velit esse cillum      |
          dolore eu fugiat nulla pariatur. Excepteur sint   |
          occaecat cupidatat non proident, sunt in culpa    |
          qui officia deserunt mollit anim id est           |
          laborum^.                                          |
        ## grid 3
                                                            |
        ## grid 5
          {9:test           }|
          {9:               }|
          {10:popup    text}{9:  }|
        ]], float_pos={[5] = {{id = 1002}, "NW", 1, 2, 5, true}}}
      else
        screen:expect([[
          Ut enim ad minim veniam, quis nostrud             |
          exercitation ullamco laboris nisi ut aliquip ex   |
          ea co{2:test}{3:o consequat}. Duis aute irure dolor in    |
          repre{3:henderit in vol}uptate velit esse cillum      |
          dolor{10:popup    text}{3:ul}la pariatur. Excepteur sint   |
          occaecat cupidatat non proident, sunt in culpa    |
          qui officia deserunt mollit anim id est           |
          laborum^.                                          |
                                                            |
        ]])
      end

      command('hi SpecialRegion guifg=Red blend=80')
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [3:--------------------------------------------------]|
        ## grid 2
          Ut enim ad minim veniam, quis nostrud             |
          exercitation ullamco laboris nisi ut aliquip ex   |
          ea commodo consequat. Duis aute irure dolor in    |
          reprehenderit in voluptate velit esse cillum      |
          dolore eu fugiat nulla pariatur. Excepteur sint   |
          occaecat cupidatat non proident, sunt in culpa    |
          qui officia deserunt mollit anim id est           |
          laborum^.                                          |
        ## grid 3
                                                            |
        ## grid 5
          {9:test           }|
          {9:               }|
          {11:popup    text}{9:  }|
        ]], float_pos={[5] = {{id = 1002}, "NW", 1, 2, 5, true}}, unchanged=true}
      else
        screen:expect([[
          Ut enim ad minim veniam, quis nostrud             |
          exercitation ullamco laboris nisi ut aliquip ex   |
          ea co{2:test}{3:o consequat}. Duis aute irure dolor in    |
          repre{3:henderit in vol}uptate velit esse cillum      |
          dolor{5:popup}{6:fugi}{5:text}{3:ul}la pariatur. Excepteur sint   |
          occaecat cupidatat non proident, sunt in culpa    |
          qui officia deserunt mollit anim id est           |
          laborum^.                                          |
                                                            |
        ]])
      end

      -- Test scrolling by mouse
      if multigrid then
        meths.input_mouse('wheel', 'down', '', 5, 2, 2)
        screen:expect{grid=[[
        ## grid 1
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [2:--------------------------------------------------]|
          [3:--------------------------------------------------]|
        ## grid 2
          Ut enim ad minim veniam, quis nostrud             |
          exercitation ullamco laboris nisi ut aliquip ex   |
          ea commodo consequat. Duis aute irure dolor in    |
          reprehenderit in voluptate velit esse cillum      |
          dolore eu fugiat nulla pariatur. Excepteur sint   |
          occaecat cupidatat non proident, sunt in culpa    |
          qui officia deserunt mollit anim id est           |
          laborum^.                                          |
        ## grid 3
                                                            |
        ## grid 5
          {11:popup    text}{9:  }|
          {12:~              }|
          {12:~              }|
        ]], float_pos={[5] = {{id = 1002}, "NW", 1, 2, 5, true}}}
      else
        meths.input_mouse('wheel', 'down', '', 0, 4, 7)
        screen:expect([[
          Ut enim ad minim veniam, quis nostrud             |
          exercitation ullamco laboris nisi ut aliquip ex   |
          ea co{5:popup}{6: con}{5:text}{3:at}. Duis aute irure dolor in    |
          repre{7:~}{3:enderit in vol}uptate velit esse cillum      |
          dolor{7:~}{3: eu fugiat nul}la pariatur. Excepteur sint   |
          occaecat cupidatat non proident, sunt in culpa    |
          qui officia deserunt mollit anim id est           |
          laborum^.                                          |
                                                            |
        ]])
      end
    end)

    it('can overlap doublewidth chars', function()
      insert([[
        # TODO: 测试字典信息的准确性
        # FIXME: 测试字典信息的准确性]])
      local buf = meths.create_buf(false,false)
      local win = meths.open_win(buf, false, {relative='editor', width=5, height=3, row=0, col=11, style='minimal'})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [3:----------------------------------------]|
        ## grid 2
          # TODO: 测试字典信息的准确性            |
          # FIXME: 测试字典信息的准确^性           |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
        ## grid 3
                                                  |
        ## grid 4
          {1:     }|
          {1:     }|
          {1:     }|
        ]], float_pos={ [4] = { { id = 1001 }, "NW", 1, 0, 11, true } }}
      else
        screen:expect([[
          # TODO: 测 {1:     }信息的准确性            |
          # FIXME: 测{1:     } 信息的准确^性           |
          {0:~          }{1:     }{0:                        }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
                                                  |
        ]])
      end

      meths.win_close(win, false)
      if multigrid then
        screen:expect([[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [3:----------------------------------------]|
        ## grid 2
          # TODO: 测试字典信息的准确性            |
          # FIXME: 测试字典信息的准确^性           |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
        ## grid 3
                                                  |
        ]])
      else
        screen:expect([[
          # TODO: 测试字典信息的准确性            |
          # FIXME: 测试字典信息的准确^性           |
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
          {0:~                                       }|
                                                  |
        ]])
      end

      -- The interaction between 'winblend' and doublewidth chars in the background
      -- does not look very good. But check no chars get incorrectly placed
      -- at least. Also check invisible EndOfBuffer region blends correctly.
      meths.buf_set_lines(buf, 0, -1, true, {" x x  x   xx", "  x x  x   x"})
      win = meths.open_win(buf, false, {relative='editor', width=12, height=3, row=0, col=11, style='minimal'})
      meths.win_set_option(win, 'winblend', 30)
      screen:set_default_attr_ids({
        [1] = {foreground = tonumber('0xb282b2'), background = tonumber('0xffcfff')},
        [2] = {foreground = Screen.colors.Grey0, background = tonumber('0xffcfff')},
        [3] = {bold = true, foreground = Screen.colors.Blue1},
        [4] = {background = tonumber('0xffcfff'), bold = true, foreground = tonumber('0xb282ff')},
        [5] = {background = Screen.colors.LightMagenta, blend=30},
      })
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [3:----------------------------------------]|
        ## grid 2
          # TODO: 测试字典信息的准确性            |
          # FIXME: 测试字典信息的准确^性           |
          {3:~                                       }|
          {3:~                                       }|
          {3:~                                       }|
          {3:~                                       }|
        ## grid 3
                                                  |
        ## grid 6
          {5: x x  x   xx}|
          {5:  x x  x   x}|
          {5:            }|
        ]], float_pos={
          [6] = { {
              id = 1003
            }, "NW", 1, 0, 11, true }
        }}
      else
        screen:expect([[
          # TODO: 测 {2: x x  x}{1:息}{2: xx} 确性            |
          # FIXME: 测{1:试}{2:x x  x}{1:息}{2: x}准确^性           |
          {3:~          }{4:            }{3:                 }|
          {3:~                                       }|
          {3:~                                       }|
          {3:~                                       }|
                                                  |
        ]])
      end

      meths.win_set_config(win, {relative='editor', row=0, col=12})
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [3:----------------------------------------]|
        ## grid 2
          # TODO: 测试字典信息的准确性            |
          # FIXME: 测试字典信息的准确^性           |
          {3:~                                       }|
          {3:~                                       }|
          {3:~                                       }|
          {3:~                                       }|
        ## grid 3
                                                  |
        ## grid 6
          {5: x x  x   xx}|
          {5:  x x  x   x}|
          {5:            }|
        ]], float_pos={
          [6] = { {
              id = 1003
            }, "NW", 1, 0, 12, true }
        }}
      else
        screen:expect([[
          # TODO: 测试{2: x x}{1:信}{2:x }{1:的}{2:xx}确性            |
          # FIXME: 测 {2:  x x}{1:信}{2:x }{1:的}{2:x} 确^性           |
          {3:~           }{4:            }{3:                }|
          {3:~                                       }|
          {3:~                                       }|
          {3:~                                       }|
                                                  |
        ]])
      end
    end)

    it("correctly redraws when overlaid windows are resized #13991", function()
	  helpers.source([[
        let popup_config = {"relative" : "editor",
                    \ "width" : 7,
                    \ "height" : 3,
                    \ "row" : 1,
                    \ "col" : 1,
                    \ "style" : "minimal"}

        let border_config = {"relative" : "editor",
                    \ "width" : 9,
                    \ "height" : 5,
                    \ "row" : 0,
                    \ "col" : 0,
                    \ "style" : "minimal"}

        let popup_buffer = nvim_create_buf(v:false, v:true)
        let border_buffer = nvim_create_buf(v:false, v:true)
        let popup_win = nvim_open_win(popup_buffer, v:true, popup_config)
        let border_win = nvim_open_win(border_buffer, v:false, border_config)

        call nvim_buf_set_lines(popup_buffer, 0, -1, v:true,
                    \ ["long", "longer", "longest"])

        call nvim_buf_set_lines(border_buffer, 0, -1, v:true,
                    \ ["---------", "-       -", "-       -"])
      ]])

      if multigrid then
        screen:expect{grid=[[
		## grid 1
		  [2:----------------------------------------]|
		  [2:----------------------------------------]|
		  [2:----------------------------------------]|
		  [2:----------------------------------------]|
		  [2:----------------------------------------]|
		  [2:----------------------------------------]|
		  [3:----------------------------------------]|
		## grid 2
		                                          |
		  {1:~                                       }|
		  {1:~                                       }|
		  {1:~                                       }|
		  {1:~                                       }|
		  {1:~                                       }|
		## grid 3
		                                          |
		## grid 5
		  {2:^long   }|
		  {2:longer }|
		  {2:longest}|
		## grid 6
		  {2:---------}|
		  {2:-       -}|
		  {2:-       -}|
		  {2:         }|
		  {2:         }|
		]], attr_ids={
          [1] = {foreground = Screen.colors.Blue1, bold = true};
          [2] = {background = Screen.colors.LightMagenta};
        }, float_pos={
           [5] = { {
               id = 1002
             }, "NW", 1, 1, 1, true },
           [6] = { {
               id = 1003
             }, "NW", 1, 0, 0, true }
        }}
      else
        screen:expect([[
        {1:---------}                               |
        {1:-^long   -}{0:                               }|
        {1:-longer -}{0:                               }|
        {1: longest }{0:                               }|
        {1:         }{0:                               }|
        {0:~                                       }|
                                                |
        ]])
      end

      helpers.source([[
        let new_popup_config = {"width" : 1, "height" : 3}
        let new_border_config = {"width" : 3, "height" : 5}

        function! Resize()
            call nvim_win_set_config(g:popup_win, g:new_popup_config)
            call nvim_win_set_config(g:border_win, g:new_border_config)

            call nvim_buf_set_lines(g:border_buffer, 0, -1, v:true,
                        \ ["---", "- -", "- -"])
        endfunction

        nnoremap zz <cmd>call Resize()<cr>
      ]])

      helpers.feed("zz")
      if multigrid then
        screen:expect{grid=[[
        ## grid 1
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [2:----------------------------------------]|
          [3:----------------------------------------]|
        ## grid 2
                                                  |
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
          {1:~                                       }|
        ## grid 3
                                                  |
        ## grid 5
          {2:^l}|
          {2:o}|
          {2:n}|
        ## grid 6
          {2:---}|
          {2:- -}|
          {2:- -}|
          {2:   }|
          {2:   }|
        ]], attr_ids={
          [1] = {foreground = Screen.colors.Blue1, bold = true};
          [2] = {background = Screen.colors.LightMagenta};
        }, float_pos={
          [5] = { {
              id = 1002
            }, "NW", 1, 1, 1, true },
          [6] = { {
              id = 1003
            }, "NW", 1, 0, 0, true }
        }}
      else
        screen:expect([[
        {1:---}                                     |
        {1:-^l-}{0:                                     }|
        {1:-o-}{0:                                     }|
        {1: n }{0:                                     }|
        {1:   }{0:                                     }|
        {0:~                                       }|
                                                |
        ]])
      end
    end)
  end

  describe('with ext_multigrid', function()
    with_ext_multigrid(true)
  end)
  describe('without ext_multigrid', function()
    with_ext_multigrid(false)
  end)
end)

