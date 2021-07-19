local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local spawn, set_session, clear = helpers.spawn, helpers.set_session, helpers.clear
local feed, command = helpers.feed, helpers.command
local eq, iswin = helpers.eq, helpers.iswin

describe('In ext-win mode', function()
  local screen
  local nvim_argv = {helpers.nvim_prog, '-u', 'NONE', '-i', 'NONE', '-N',
                     '--cmd', 'set shortmess+=I background=light noswapfile belloff= noshowcmd noruler',
                     '--embed'}

  before_each(function()
    local screen_nvim = spawn(nvim_argv)
    set_session(screen_nvim)
    screen = Screen.new(15, 5)
    -- TODO(utkarshme): should not have to set ext_multigrid
    screen:attach({ext_windows=true})
    screen:set_default_attr_ids({
      [1] = {bold = true, reverse = true},
      [2] = {bold = true, foreground = Screen.colors.Blue1},
      [3] = {reverse = true},
      [4] = {bold = true},
      [5] = {background = Screen.colors.LightGrey, underline = true},
      [6] = {bold = true, foreground = Screen.colors.Magenta}
    })
    screen:set_on_event_handler(function(name, data)
      if name == 'win_split' then
        local win1, grid1, win2, grid2, flags = unpack(data)
        screen.split = {
          old_win = {win1, grid1},
          new_win = {win2, grid2},
          flags = flags
          -- must call resize_grid for the split grid
          -- and set a dummy win_pos (locally) for the window
        }
        screen:_handle_win_pos(grid2, win2, 0, 0, 0, 0)
      elseif name == 'win_rotate' then
        local win, grid, direction, count = unpack(data)
        screen.rotate = {
          win = win,
          grid = grid,
          direction = direction,
          count = count
        }
      elseif name == 'win_exchange' then
        local win, grid, count = unpack(data)
        screen.exchange = {
          win = win,
          grid = grid,
          count = count
        }
      elseif name == 'win_move' then
        local win, grid, flags = unpack(data)
        screen.win_move = {
          win = win,
          grid = grid,
          flags = flags
        }
      elseif name == 'win_resize_equal' then
        screen.got_resize_equal = true
      elseif name == 'win_height_set' then
        local win, grid, height = unpack(data)
        screen.height_set = {
          win = win, grid = grid, height = height
        }
      elseif name == 'win_width_set' then
        local win, grid, width = unpack(data)
        screen.width_set = {
          win = win, grid = grid, width = width
        }
      elseif name == 'win_close' then
        local win, grid = unpack(data)
        screen.win_close = {
          win = win, grid = grid
        }
      end
    end)
    screen:set_on_request_handler(function(method, args)
      if method == 'win_move_cursor' then
        local direction, count = unpack(args)
        screen.move_cursor = {
          direction = direction,
          count = count
        }
      end
    end)
  end)

  after_each(function()
    screen:detach()
  end)

  it('default initial screen is correct', function()
      screen:expect([[
      ## grid 1
        [2:---------------]|
        [2:---------------]|
        [2:---------------]|
        {1:[No Name]      }|
                       |
      ## grid 2
        ^               |
        {2:~              }|
        {2:~              }|
      ]])
  end)

  describe(':(v)split', function()
    it('creates empty grids', function()
      command('split')
      screen:expect([[
      ## grid 1
        [2:---------------]|
        [2:---------------]|
        [2:---------------]|
        {3:[No Name]      }|
                       |
      ## grid 2
                       |
        {2:~              }|
        {2:~              }|
      ## grid 3
      ]], nil, nil, function()
        eq(0, screen.split.flags)
        eq(2, screen.split.old_win[2])
        eq(3, screen.split.new_win[2])
      end)
      screen:try_resize_grid(screen.split.old_win[2], 10, 5)
      screen:try_resize_grid(screen.split.new_win[2], 10, 5)
      screen:expect([[
      ## grid 1
        [2:---------------]|
        [2:---------------]|
        [2:---------------]|
        {3:[No Name]      }|
                       |
      ## grid 2
                  |
        {2:~         }|
        {2:~         }|
        {2:~         }|
        {2:~         }|
      ## grid 3
        ^          |
        {2:~         }|
        {2:~         }|
        {2:~         }|
        {2:~         }|
      ]])

      command('vsplit')
      screen:expect([[
      ## grid 1
        [2:---------------]|
        [2:---------------]|
        [2:---------------]|
        {3:[No Name]      }|
                       |
      ## grid 2
                  |
        {2:~         }|
        {2:~         }|
        {2:~         }|
        {2:~         }|
      ## grid 3
                  |
        {2:~         }|
        {2:~         }|
        {2:~         }|
        {2:~         }|
      ## grid 4
      ]], nil, nil, function()
        eq(2, screen.split.flags)
        iswin(screen.split.old_win[1])
        eq(3, screen.split.old_win[2])
        iswin(screen.split.new_win[1])
        eq(4, screen.split.new_win[2])
      end)
      screen:try_resize_grid(screen.split.old_win[2], 10, 10)
      screen:try_resize_grid(screen.split.new_win[2], 10, 10)
      screen:expect([[
      ## grid 1
        [2:---------------]|
        [2:---------------]|
        [2:---------------]|
        {3:[No Name]      }|
                       |
      ## grid 2
                  |
        {2:~         }|
        {2:~         }|
        {2:~         }|
        {2:~         }|
      ## grid 3
                  |
        {2:~         }|
        {2:~         }|
        {2:~         }|
        {2:~         }|
        {2:~         }|
        {2:~         }|
        {2:~         }|
        {2:~         }|
        {2:~         }|
      ## grid 4
        ^          |
        {2:~         }|
        {2:~         }|
        {2:~         }|
        {2:~         }|
        {2:~         }|
        {2:~         }|
        {2:~         }|
        {2:~         }|
        {2:~         }|
      ]])
    end)
  end)

  describe(':resize', function()
    it('sends height_set event', function()
      command('resize 5')
      screen:expect([[
      ## grid 1
        [2:---------------]|
        [2:---------------]|
        [2:---------------]|
        {1:[No Name]      }|
                       |
      ## grid 2
        ^               |
        {2:~              }|
        {2:~              }|
      ]], nil, nil, function()
        iswin(screen.height_set.win)
        eq(2, screen.height_set.grid)
        eq(5, screen.height_set.height)
      end)
    end)
  end)

  describe(':vertical resize', function()
    it('sends width_set event', function()
      command('vertical resize 5')
      screen:expect([[
      ## grid 1
        [2:---------------]|
        [2:---------------]|
        [2:---------------]|
        {1:[No Name]      }|
                       |
      ## grid 2
        ^               |
        {2:~              }|
        {2:~              }|
      ]], nil, nil, function()
        iswin(screen.width_set.win)
        eq(2, screen.width_set.grid)
        eq(5, screen.width_set.width)
      end)
    end)
  end)

  describe('CTRL_W-r', function()
    it('sends rotate event', function()
      command('split')
      feed('<C-W>r')
      screen:expect([[
      ## grid 1
        [2:---------------]|
        [2:---------------]|
        [2:---------------]|
        {3:[No Name]      }|
                       |
      ## grid 2
                       |
        {2:~              }|
        {2:~              }|
      ## grid 3
      ]], nil, nil, function()
        iswin(screen.rotate.win)
        eq(3, screen.rotate.grid)
        eq(1, screen.rotate.count)
        eq(0, screen.rotate.direction)
      end)
    end)
  end)

  describe('CTRL_W-x', function()
    it('sends exchange event', function()
      command('split')
      feed('<C-W>x')
      screen:expect([[
      ## grid 1
        [2:---------------]|
        [2:---------------]|
        [2:---------------]|
        {3:[No Name]      }|
                       |
      ## grid 2
                       |
        {2:~              }|
        {2:~              }|
      ## grid 3
      ]], nil, nil, function()
        iswin(screen.exchange.win)
        eq(3, screen.exchange.grid)
        eq(0, screen.exchange.count)
      end)
    end)
  end)

  describe('CTRL_W-J', function()
    it('sends win_move event', function()
      command('split')
      feed('<C-W>J')
      screen:expect([[
      ## grid 1
        [2:---------------]|
        [2:---------------]|
        [2:---------------]|
        {3:[No Name]      }|
                       |
      ## grid 2
                       |
        {2:~              }|
        {2:~              }|
      ## grid 3
      ]], nil, nil, function()
        iswin(screen.win_move.win)
        eq(3, screen.win_move.grid)
        eq(1, screen.win_move.flags)
      end)
    end)
  end)

  describe('CTRL_W T', function()
    it('sends win_close and creates a new grid', function()
      command('split')
      feed('<C-W>T')
      screen:expect([[
      ## grid 1
        {4: Name]  Name] }{5:X}|
        [4:---------------]|
        [4:---------------]|
        [4:---------------]|
                       |
      ## grid 2
                       |
        {2:~              }|
        {2:~              }|
      ## grid 4
        ^               |
        {2:~              }|
        {2:~              }|
      ]], nil, nil, function()
        iswin(screen.win_close.win)
        eq(3, screen.win_close.grid)
      end)
    end)
  end)

  describe('CTRL_W =', function()
    it('sends resize_equal event', function()
      command('split')
      feed('<C-W>=')
      screen:expect([[
      ## grid 1
        [2:---------------]|
        [2:---------------]|
        [2:---------------]|
        {3:[No Name]      }|
                       |
      ## grid 2
                       |
        {2:~              }|
        {2:~              }|
      ## grid 3
      ]], nil, nil, function()
        eq(true, screen.got_resize_equal)
      end)
    end)
  end)

  describe('CTRL_W-+', function()
    it('sends win_height_set event', function()
      feed('<C-W>+')
      screen:expect([[
      ## grid 1
        [2:---------------]|
        [2:---------------]|
        [2:---------------]|
        {1:[No Name]      }|
                       |
      ## grid 2
        ^               |
        {2:~              }|
        {2:~              }|
      ]], nil, nil, function()
        iswin(screen.height_set.win)
        eq(2, screen.height_set.grid)
        eq(4, screen.height_set.height)
      end)
    end)
  end)

  describe('CTRL_W-j', function()
    it('sends move_cursor event', function()
      command('split')
      feed('<C-W>j')
      screen:expect([[
      ## grid 1
        [2:---------------]|
        [2:---------------]|
        [2:---------------]|
        {3:[No Name]      }|
                       |
      ## grid 2
                       |
        {2:~              }|
        {2:~              }|
      ## grid 3
      ]], nil, nil, function()
        eq(0, screen.move_cursor.direction)
        eq(1, screen.move_cursor.count)
      end)
    end)
  end)

  describe('CTRL_W-c', function()
    it('sends close event', function()
      command('split')
      screen:expect([[
      ## grid 1
        [2:---------------]|
        [2:---------------]|
        [2:---------------]|
        {3:[No Name]      }|
                       |
      ## grid 2
                       |
        {2:~              }|
        {2:~              }|
      ## grid 3
      ]])
      feed('<C-W>c')
      screen:expect([[
      ## grid 1
        [2:---------------]|
        [2:---------------]|
        [2:---------------]|
        {1:[No Name]      }|
                       |
      ## grid 2
        ^               |
        {2:~              }|
        {2:~              }|
      ]], nil, nil, function()
        iswin(screen.win_close.win)
        eq(3, screen.win_close.grid)
      end)
    end)
  end)
end)
