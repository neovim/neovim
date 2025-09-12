local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear, feed = n.clear, n.feed
local exec_lua = n.exec_lua
local command = n.command

describe("'scrollbar'", function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(30, 10)
    command('set scrollbar')
    command('hi Scrollbar guibg=blue')
    command('hi ScrollbarThumb guibg=red')
    screen:add_extra_attr_ids({
      [101] = { background = Screen.colors.Blue },
      [102] = { foreground = Screen.colors.Blue },
      [103] = { foreground = Screen.colors.Yellow },
    })
  end)

  it('toggle scrollbar in the window with page scrolling', function()
    exec_lua([[
      local buf = vim.api.nvim_create_buf(true, true)
      vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        row = 1,
        col = 1,
        width = 10,
        height = 5,
      })
      vim.cmd.edit(vim.fs.joinpath(vim.uv.cwd(), 'README.md'))
    ]])

    screen:expect([[
                                    |
      {1:~}{4:^<h1 align}{30: }{1:                   }|
      {1:~}{4:="center"}{101: }{1:                   }|
      {1:~}{4:>        }{101: }{1:                   }|
      {1:~}{4:  <img sr}{101: }{1:                   }|
      {1:~}{4:c="htt}{11:@@@}{101: }{1:                   }|
      {1:~                             }|*3
                                    |
    ]])
    feed(('<C-f>'):rep(30))
    screen:expect([[
                                    |
      {1:~}{4:^         }{101: }{1:                   }|
      {1:~}{4:See [`:he}{30: }{1:                   }|
      {1:~}{4:lp nvim-f}{101: }{1:                   }|
      {1:~}{4:eatures`]}{101: }{1:                   }|
      {1:~}{4:[nvim-}{11:@@@}{101: }{1:                   }|
      {1:~                             }|*3
                                    |
    ]])

    command('setlocal noscrollbar')
    screen:expect([[
                                    |
      {1:~}{4:^          }{1:                   }|
      {1:~}{4:See [`:hel}{1:                   }|
      {1:~}{4:p nvim-fea}{1:                   }|
      {1:~}{4:tures`][nv}{1:                   }|
      {1:~}{4:im-feat}{11:@@@}{1:                   }|
      {1:~                             }|*3
                                    |
    ]])

    command('fclose | bnext')
    feed(('<C-b>'):rep(15))
    screen:expect([[
      <h1 align="center">          {30: }|
        <img src="https://raw.githu{101: }|
      busercontent.com/neovim/neovi{101: }|
      m.github.io/master/logos/neov{101: }|
      im-logo-300x87.png" alt="Neov{101: }|
      im">                         {101: }|
                                   {101: }|
        ^<a href="https://neovim.io/{101: }|
      doc/">Documentation</a> |    {101: }|
                                    |
    ]])

    command('set noscrollbar')
    screen:expect([[
      <h1 align="center">           |
        <img src="https://raw.github|
      usercontent.com/neovim/neovim.|
      github.io/master/logos/neovim-|
      logo-300x87.png" alt="Neovim">|
                                    |
        ^<a href="https://neovim.io/d|
      oc/">Documentation</a> |      |
        <a href="https://app.elem{1:@@@}|
                                    |
    ]])
  end)

  it('works after resize', function()
    exec_lua([[
      vim.opt.laststatus = 0
      vim.cmd.vsplit('another')
      vim.cmd.edit(vim.fs.joinpath(vim.uv.cwd(), 'README.md'))
    ]])
    screen:expect([[
      ^<h1 align="center">{30: }│         |
        <img src="https:/{101: }│{1:~        }|
      /raw.githubusercont{101: }│{1:~        }|
      ent.com/neovim/neov{101: }│{1:~        }|
      im.github.io/master{101: }│{1:~        }|
      /logos/neovim-logo-{101: }│{1:~        }|
      300x87.png" alt="Ne{101: }│{1:~        }|
      ovim">             {101: }│{1:~        }|
                         {101: }│{1:~        }|
                                    |
    ]])
    command('vertical resize +5')
    screen:expect([[
      ^<h1 align="center">     {30: }     |
        <img src="https://raw.{101: }{1:~    }|
      githubusercontent.com/ne{101: }{1:~    }|
      ovim/neovim.github.io/ma{101: }{1:~    }|
      ster/logos/neovim-logo-3{101: }{1:~    }|
      00x87.png" alt="Neovim">{101: }{1:~    }|
                              {101: }{1:~    }|
        <a href="https://neovi{101: }{1:~    }|
      m.io/doc/">Documentat{1:@@@}{101: }{1:~    }|
                                    |
    ]])
  end)

  it('mouse click and drag on scrollbar', function()
    exec_lua([[
      local buf = vim.api.nvim_create_buf(true, true)
      local content = {}
      for i = 1, 50 do
        content[#content + 1] =  ('line %d'):format(i)
      end
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
      vim.api.nvim_open_win(buf, true, { relative = "editor", row = 2, col = 2, width = 10, height = 5 })
    ]])
    screen:expect([[
                                    |
      {1:~                             }|
      {1:~ }{4:^line 1   }{30: }{1:                  }|
      {1:~ }{4:line 2   }{101: }{1:                  }|
      {1:~ }{4:line 3   }{101: }{1:                  }|
      {1:~ }{4:line 4   }{101: }{1:                  }|
      {1:~ }{4:line 5   }{101: }{1:                  }|
      {1:~                             }|*2
                                    |
    ]])

    feed('<LeftMouse><11,4>')
    feed('<LeftDrag><11,6>')
    screen:expect([[
                                    |
      {1:~                             }|
      {1:~ }{4:^line 46  }{101: }{1:                  }|
      {1:~ }{4:line 47  }{101: }{1:                  }|
      {1:~ }{4:line 48  }{101: }{1:                  }|
      {1:~ }{4:line 49  }{101: }{1:                  }|
      {1:~ }{4:line 50  }{30: }{1:                  }|
      {1:~                             }|*2
                                    |
    ]])
    feed('<LeftRelease><0,0>')

    command('fclose | bnext')
    feed('<LeftMouse><29,4>')
    screen:expect([[
      ^line 21                      {101: }|
      line 22                      {101: }|
      line 23                      {101: }|
      line 24                      {30: }|
      line 25                      {101: }|
      line 26                      {101: }|
      line 27                      {101: }|
      line 28                      {101: }|
      line 29                      {101: }|
                                    |
    ]])
    feed('<LeftMouse><29,7>')
    screen:expect([[
      ^line 36                      {101: }|
      line 37                      {101: }|
      line 38                      {101: }|
      line 39                      {101: }|
      line 40                      {101: }|
      line 41                      {101: }|
      line 42                      {30: }|
      line 43                      {101: }|
      line 44                      {101: }|
                                    |
    ]])
  end)
end)
