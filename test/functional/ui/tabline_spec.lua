local t = require('test.functional.testutil')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, command, eq = t.clear, t.command, t.eq
local insert = t.insert
local api = t.api
local assert_alive = t.assert_alive

describe('ui/ext_tabline', function()
  local screen
  local event_tabs, event_curtab, event_curbuf, event_buffers

  before_each(function()
    clear()
    screen = Screen.new(25, 5)
    screen:attach({ rgb = true, ext_tabline = true })
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
    screen:attach()
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
end)
