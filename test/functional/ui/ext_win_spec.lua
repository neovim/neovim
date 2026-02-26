local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local feed, command = n.feed, n.command
local eq = t.eq
local api = n.api
local curwin = api.nvim_get_current_win

describe('ext_windows', function()
  local screen

  before_each(function()
    clear {
      args_rm = { '--headless' },
      args = {
        '--cmd',
        'set shortmess+=I background=light noswapfile belloff= noshowcmd noruler',
      },
    }
    screen = Screen.new(15, 5, { ext_windows = true })
    screen:set_default_attr_ids({
      [1] = { bold = true, reverse = true },
      [2] = { bold = true, foreground = Screen.colors.Blue1 },
      [3] = { reverse = true },
      [4] = { bold = true },
      [5] = { background = Screen.colors.LightGrey, underline = true },
      [6] = { bold = true, foreground = Screen.colors.Magenta },
    })
    screen:set_on_event_handler(function(name, data)
      if name == 'win_split' then
        local win1, grid1, win2, grid2, flags = unpack(data)
        screen.split = {
          old_win = { win1, grid1 },
          new_win = { win2, grid2 },
          flags = flags,
        }
        screen:_handle_win_pos(grid2, win2, 0, 0, 0, 0)
      elseif name == 'win_rotate' then
        local win, grid, direction, count = unpack(data)
        screen.rotate = {
          win = win,
          grid = grid,
          direction = direction,
          count = count,
        }
      elseif name == 'win_exchange' then
        local win, grid, count = unpack(data)
        screen.exchange = {
          win = win,
          grid = grid,
          count = count,
        }
      elseif name == 'win_move' then
        local win, grid, flags = unpack(data)
        screen.win_move = {
          win = win,
          grid = grid,
          flags = flags,
        }
      elseif name == 'win_resize_equal' then
        screen.got_resize_equal = true
      elseif name == 'win_resize' then
        local win, grid, width, height = unpack(data)
        screen.resize_set = {
          win = win,
          grid = grid,
          width = width,
          height = height,
        }
      elseif name == 'win_close' then
        local grid = unpack(data)
        screen.win_close = {
          grid = grid,
        }
      end
    end)
  end)

  after_each(function()
    screen:detach()
  end)

  it('default initial screen is correct', function()
    screen:expect {
      grid = [[
      ## grid 1
                       |*4
        [3:---------------]|
      ## grid 2 (hidden)
        ^               |
        {2:~              }|*3
      ## grid 3
                       |
      ]],
    }
  end)

  describe(':(v)split', function()
    it('creates empty grids', function()
      local old_win = curwin()
      command('split')
      local new_win = curwin()
      screen:expect {
        grid = [[
        ## grid 1
          [2:---------------]|*4
          [3:---------------]|
        ## grid 2
                         |
          {2:~              }|*3
        ## grid 3
                         |
        ## grid 4
        ]],
        condition = function()
          eq(0, screen.split.flags)
          -- verify old_win/new_win win handles
          eq(old_win, screen.split.old_win[1])
          eq(new_win, screen.split.new_win[1])
          -- verify grid handles (grid 2 = old, grid 4 = new)
          eq(2, screen.split.old_win[2])
          eq(4, screen.split.new_win[2])
        end,
      }
    end)
  end)

  describe(':resize', function()
    it('sends win_resize event', function()
      local win = curwin()
      command('resize 5')
      screen:expect {
        grid = [[
        ## grid 1
                         |*4
          [3:---------------]|
        ## grid 2 (hidden)
          ^               |
          {2:~              }|*3
        ## grid 3
                         |
        ]],
        condition = function()
          eq(win, screen.resize_set.win)
          eq(2, screen.resize_set.grid)
          eq(5, screen.resize_set.height)
        end,
      }
    end)
  end)

  describe('CTRL_W-r', function()
    it('sends rotate event', function()
      command('split')
      local win = curwin()
      feed('<C-W>r')
      screen:expect {
        grid = [[
        ## grid 1
          [2:---------------]|*4
          [3:---------------]|
        ## grid 2
                         |
          {2:~              }|*3
        ## grid 3
                         |
        ## grid 4
        ]],
        condition = function()
          eq(win, screen.rotate.win)
          eq(4, screen.rotate.grid)
          eq(1, screen.rotate.count)
          eq(0, screen.rotate.direction)
        end,
      }
    end)
  end)

  describe('CTRL_W-x', function()
    it('sends exchange event', function()
      command('split')
      local win = curwin()
      feed('<C-W>x')
      screen:expect {
        grid = [[
        ## grid 1
          [2:---------------]|*4
          [3:---------------]|
        ## grid 2
                         |
          {2:~              }|*3
        ## grid 3
                         |
        ## grid 4
        ]],
        condition = function()
          eq(win, screen.exchange.win)
          eq(4, screen.exchange.grid)
          eq(0, screen.exchange.count)
        end,
      }
    end)
  end)

  describe('CTRL_W =', function()
    it('sends resize_equal event', function()
      command('split')
      feed('<C-W>=')
      screen:expect {
        grid = [[
        ## grid 1
          [2:---------------]|*4
          [3:---------------]|
        ## grid 2
                         |
          {2:~              }|*3
        ## grid 3
                         |
        ## grid 4
        ]],
        condition = function()
          eq(true, screen.got_resize_equal)
        end,
      }
    end)
  end)

  describe('CTRL_W-j', function()
    it('sends win_move_cursor sync request', function()
      -- request_cb yields across C-call boundary; PUC Lua cannot do this.
      if t.skip(not package.loaded['jit'], 'requires LuaJIT') then
        return
      end
      local old_win = curwin()
      command('split')
      -- Request move down and return the target window handle.
      screen.move_cursor = nil
      feed('<C-W>j')
      screen:expect {
        grid = [[
        ## grid 1
          [2:---------------]|*4
          [3:---------------]|
        ## grid 2
          ^               |
          {2:~              }|*3
        ## grid 3
                         |
        ## grid 4
        ]],
        request_cb = function(method, args)
          if method == 'win_move_cursor' then
            screen.move_cursor = {
              direction = args[1],
              count = args[2],
            }
            return old_win
          end
        end,
        condition = function()
          -- direction=0 means down, count=1
          eq(0, screen.move_cursor.direction)
          eq(1, screen.move_cursor.count)
          -- cursor should have moved to the old window
          eq(old_win, curwin())
        end,
      }
    end)
  end)
end)
