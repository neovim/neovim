local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear, command, eq = n.clear, n.command, t.eq
local insert = n.insert
local api = n.api
local assert_alive = n.assert_alive

describe('ui/ext_tabline', function()
  local screen
  local event_tabs, event_curtab, event_curbuf, event_buffers

  before_each(function()
    clear()
    screen = Screen.new(25, 5, { rgb = true, ext_tabline = true })
    function screen:_handle_tabline_update(curtab, tabs, curbuf, buffers)
      event_curtab = curtab
      event_tabs = tabs
      event_curbuf = curbuf
      event_buffers = buffers
    end
  end)

  it('publishes UI events', function()
    command('tabedit another-tab')

    local expected_tabs = {
      { tab = 1, name = '[No Name]' },
      { tab = 2, name = 'another-tab' },
    }
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*3
                               |
    ]],
      condition = function()
        eq(2, event_curtab)
        eq(expected_tabs, event_tabs)
      end,
    }

    command('tabNext')
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*3
                               |
    ]],
      condition = function()
        eq(1, event_curtab)
        eq(expected_tabs, event_tabs)
      end,
    }
  end)

  it('buffer UI events', function()
    local expected_buffers_initial = {
      { buffer = 1, name = '[No Name]' },
    }

    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*3
                               |
    ]],
      condition = function()
        eq(1, event_curbuf)
        eq(expected_buffers_initial, event_buffers)
      end,
    }

    command('badd another-buffer')
    command('bnext')

    local expected_buffers = {
      { buffer = 1, name = '[No Name]' },
      { buffer = 2, name = 'another-buffer' },
    }
    screen:expect {
      grid = [[
      ^                         |
      {1:~                        }|*3
                               |
    ]],
      condition = function()
        eq(2, event_curbuf)
        eq(expected_buffers, event_buffers)
      end,
    }
  end)
end)

describe('tabline', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(42, 5)
  end)

  it('redraws when tabline option is set', function()
    command('set tabline=asdf')
    command('set showtabline=2')
    screen:expect {
      grid = [[
      {2:asdf                                      }|
      ^                                          |
      {1:~                                         }|*2
                                                |
    ]],
    }
    command('set tabline=jkl')
    screen:expect {
      grid = [[
      {2:jkl                                       }|
      ^                                          |
      {1:~                                         }|*2
                                                |
    ]],
    }
  end)

  it('combines highlight attributes', function()
    screen:set_default_attr_ids({
      [1] = { foreground = Screen.colors.Blue1, bold = true }, -- StatusLine
      [2] = { bold = true, italic = true }, -- StatusLine
      [3] = { bold = true, italic = true, foreground = Screen.colors.Red }, -- NonText combined with StatusLine
    })
    command('hi TabLineFill gui=bold,italic')
    command('hi Identifier guifg=red')
    command('set tabline=Test%#Identifier#here')
    command('set showtabline=2')
    screen:expect {
      grid = [[
      {2:Test}{3:here                                  }|
      ^                                          |
      {1:~                                         }|*2
                                                |
    ]],
    }
  end)

  it('click definitions do not leak memory #21765', function()
    command('set tabline=%@MyClickFunc@MyClickText%T')
    command('set showtabline=2')
    command('redrawtabline')
  end)

  it('clicks work with truncated double-width label #24187', function()
    insert('tab1')
    command('tabnew')
    insert('tab2')
    command('tabprev')
    api.nvim_set_option_value('tabline', '%1T口口%2Ta' .. ('b'):rep(38) .. '%999Xc', {})
    screen:expect {
      grid = [[
      {2:<abbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbc }|
      tab^1                                      |
      {1:~                                         }|*2
                                                |
    ]],
    }
    assert_alive()
    api.nvim_input_mouse('left', 'press', '', 0, 0, 1)
    screen:expect {
      grid = [[
      {2:<abbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbc }|
      tab^2                                      |
      {1:~                                         }|*2
                                                |
    ]],
    }
    api.nvim_input_mouse('left', 'press', '', 0, 0, 0)
    screen:expect {
      grid = [[
      {2:<abbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbc }|
      tab^1                                      |
      {1:~                                         }|*2
                                                |
    ]],
    }
    api.nvim_input_mouse('left', 'press', '', 0, 0, 39)
    screen:expect {
      grid = [[
      {2:<abbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbc }|
      tab^2                                      |
      {1:~                                         }|*2
                                                |
    ]],
    }
    api.nvim_input_mouse('left', 'press', '', 0, 0, 40)
    screen:expect {
      grid = [[
      tab^1                                      |
      {1:~                                         }|*3
                                                |
    ]],
    }
  end)

  it('middle-click closes tab', function()
    command('tabnew')
    command('tabnew')
    command('tabnew')
    command('tabprev')
    eq({ 3, 4 }, api.nvim_eval('[tabpagenr(), tabpagenr("$")]'))
    api.nvim_input_mouse('middle', 'press', '', 0, 0, 1)
    eq({ 2, 3 }, api.nvim_eval('[tabpagenr(), tabpagenr("$")]'))
    api.nvim_input_mouse('middle', 'press', '', 0, 0, 20)
    eq({ 2, 2 }, api.nvim_eval('[tabpagenr(), tabpagenr("$")]'))
    api.nvim_input_mouse('middle', 'press', '', 0, 0, 1)
    eq({ 1, 1 }, api.nvim_eval('[tabpagenr(), tabpagenr("$")]'))
  end)

  it('does not show floats with focusable=false', function()
    screen:set_default_attr_ids({
      [1] = { background = Screen.colors.Plum1 },
      [2] = { underline = true, background = Screen.colors.LightGrey },
      [3] = { bold = true },
      [4] = { reverse = true },
      [5] = { bold = true, foreground = Screen.colors.Blue1 },
      [6] = { foreground = Screen.colors.Fuchsia, bold = true },
      [7] = { foreground = Screen.colors.SeaGreen, bold = true },
    })
    command('tabnew')
    api.nvim_open_win(0, false, {
      focusable = false,
      relative = 'editor',
      height = 1,
      width = 1,
      row = 0,
      col = 0,
    })
    screen:expect {
      grid = [[
      {1: }{2:[No Name] }{3: [No Name] }{4:                   }{2:X}|
      ^                                          |
      {5:~                                         }|*2
                                                |
    ]],
    }
    command('tabs')
    screen:expect {
      grid = [[
      {6:Tab page 1}                                |
      #   [No Name]                             |
      {6:Tab page 2}                                |
      >   [No Name]                             |
      {7:Press ENTER or type command to continue}^   |
    ]],
    }
  end)
end)
