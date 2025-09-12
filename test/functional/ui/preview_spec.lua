local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local os = require('os')

local clear, command = n.clear, n.command
local eq, pcall_err = t.eq, t.pcall_err

describe('previewpopup option', function()
  before_each(function()
    clear()
  end)

  local function with_ext_multigrid(multigrid)
    local screen, attrs
    before_each(function()
      screen = Screen.new(40, 7, { ext_multigrid = multigrid })
      attrs = {
        [0] = { bold = true, foreground = Screen.colors.Blue },
        [1] = { background = Screen.colors.LightMagenta },
        [2] = {
          background = Screen.colors.LightMagenta,
          bold = true,
          foreground = Screen.colors.Blue1,
        },
        [3] = { bold = true },
        [4] = { bold = true, reverse = true },
        [5] = { reverse = true },
        [6] = { background = Screen.colors.LightMagenta, bold = true, reverse = true },
        [7] = { foreground = Screen.colors.White, background = Screen.colors.Red },
        [8] = { bold = true, foreground = Screen.colors.SeaGreen4 },
        [9] = { background = Screen.colors.LightGrey, underline = true },
        [10] = {
          background = Screen.colors.LightGrey,
          underline = true,
          bold = true,
          foreground = Screen.colors.Magenta,
        },
        [11] = { bold = true, foreground = Screen.colors.Magenta },
      }
      screen:set_default_attr_ids(attrs)
    end)

    it('#previewpopup option', function()
      command('call writefile(["bar"], "foo", "a")')
      finally(function()
        os.remove('foo')
      end)
      command('set winborder=single | set previewpopup=height:2,width:5 | pedit foo')
      if multigrid then
        screen:expect({
          grid = [[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            ^                                        |
            {0:~                                       }|*5
          ## grid 3
                                                    |
          ## grid 4
            ┌─{11:foo}─┐|
            │{1:bar  }│|
            │{1:     }│|
            └─────┘|
          ]],
          win_pos = { [2] = { height = 6, startcol = 0, startrow = 0, width = 40, win = 1000 } },
          float_pos = { [4] = { 1001, 'NW', 1, 1, 1, false, 50, 1, 1, 1 } },
          win_viewport = {
            [2] = {
              win = 1000,
              topline = 0,
              botline = 2,
              curline = 0,
              curcol = 0,
              linecount = 1,
              sum_scroll_delta = 0,
            },
            [4] = {
              win = 1001,
              topline = 0,
              botline = 2,
              curline = 0,
              curcol = 0,
              linecount = 1,
              sum_scroll_delta = 0,
            },
          },
          win_viewport_margins = {
            [2] = { bottom = 0, left = 0, right = 0, top = 0, win = 1000 },
            [4] = { bottom = 1, left = 1, right = 1, top = 1, win = 1001 },
          },
        })
      else
        screen:expect([[
          ^                                        |
          {0:~}┌─{11:foo}─┐{0:                                }|
          {0:~}│{1:bar  }│{0:                                }|
          {0:~}│{1:     }│{0:                                }|
          {0:~}└─────┘{0:                                }|
          {0:~                                       }|
                                                  |
        ]])
      end

      --refconfig it by using set
      command('set previewpopup=height:1,width:3')
      if multigrid then
        screen:expect({
          grid = [[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            ^                                        |
            {0:~                                       }|*5
          ## grid 3
                                                    |
          ## grid 4
            ┌{11:foo}┐|
            │{1:bar}│|
            └───┘|
          ]],
          win_pos = {
            [2] = { height = 6, startcol = 0, startrow = 0, width = 40, win = 1000 },
          },
          float_pos = { [4] = { 1001, 'NW', 1, 1, 1, false, 50, 1, 1, 1 } },
          win_viewport = {
            [2] = {
              win = 1000,
              topline = 0,
              botline = 2,
              curline = 0,
              curcol = 0,
              linecount = 1,
              sum_scroll_delta = 0,
            },
            [4] = {
              win = 1001,
              topline = 0,
              botline = 1,
              curline = 0,
              curcol = 0,
              linecount = 1,
              sum_scroll_delta = 0,
            },
          },
          win_viewport_margins = {
            [2] = { bottom = 0, left = 0, right = 0, top = 0, win = 1000 },
            [4] = { bottom = 1, left = 1, right = 1, top = 1, win = 1001 },
          },
        })
      else
        screen:expect([[
          ^                                        |
          {0:~}┌{11:foo}┐{0:                                  }|
          {0:~}│{1:bar}│{0:                                  }|
          {0:~}└───┘{0:                                  }|
          {0:~                                       }|*2
                                                  |
        ]])
      end

      -- can close by pclose command
      command('pclose')
      if multigrid then
        screen:expect({
          grid = [[
          ## grid 1
            [2:----------------------------------------]|*6
            [3:----------------------------------------]|
          ## grid 2
            ^                                        |
            {0:~                                       }|*5
          ## grid 3
                                                    |
          ]],
          win_pos = {
            [2] = { height = 6, startcol = 0, startrow = 0, width = 40, win = 1000 },
          },
          win_viewport = {
            [2] = {
              win = 1000,
              topline = 0,
              botline = 2,
              curline = 0,
              curcol = 0,
              linecount = 1,
              sum_scroll_delta = 0,
            },
          },
          win_viewport_margins = { [2] = { bottom = 0, left = 0, right = 0, top = 0, win = 1000 } },
        })
      else
        screen:expect([[
          ^                                        |
          {0:~                                       }|*5
                                                  |
        ]])
      end
    end)

    it('invalid argument in previewpopup', function()
      local err = pcall_err(n.exec_capture, 'set previewpopup=height:yes')
      eq('nvim_exec2(), line 1: Vim(set):E474: Invalid argument: previewpopup=height:yes', err)
    end)
  end

  describe('with ext_multigrid', function()
    with_ext_multigrid(true)
  end)

  describe('without ext_multigrid', function()
    with_ext_multigrid(false)
  end)
end)
