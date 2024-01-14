local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, command, eq = helpers.clear, helpers.command, helpers.eq
local insert = helpers.insert
local meths = helpers.meths
local assert_alive = helpers.assert_alive

describe('ui/ext_tabline', function()
  local screen
  local event_tabs, event_curtab, event_curbuf, event_buffers

  before_each(function()
    clear()
    screen = Screen.new(25, 5)
    screen:attach({rgb=true, ext_tabline=true})
    function screen:_handle_tabline_update(curtab, tabs, curbuf, buffers)
      event_curtab = curtab
      event_tabs = tabs
      event_curbuf = curbuf
      event_buffers = buffers
    end
  end)

  it('publishes UI events', function()
    command("tabedit another-tab")

    local expected_tabs = {
      {tab = { id = 1 }, name = '[No Name]'},
      {tab = { id = 2 }, name = 'another-tab'},
    }
    screen:expect{grid=[[
      ^                         |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]], condition=function()
      eq({ id = 2 }, event_curtab)
      eq(expected_tabs, event_tabs)
    end}

    command("tabNext")
    screen:expect{grid=[[
      ^                         |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]], condition=function()
      eq({ id = 1 }, event_curtab)
      eq(expected_tabs, event_tabs)
    end}
  end)

  it('buffer UI events', function()
    local expected_buffers_initial= {
      {buffer = { id = 1 }, name = '[No Name]'},
    }

    screen:expect{grid=[[
      ^                         |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]], condition=function()
      eq({ id = 1}, event_curbuf)
      eq(expected_buffers_initial, event_buffers)
    end}

    command("badd another-buffer")
    command("bnext")

    local expected_buffers = {
      {buffer = { id = 1 }, name = '[No Name]'},
      {buffer = { id = 2 }, name = 'another-buffer'},
    }
    screen:expect{grid=[[
      ^                         |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]], condition=function()
      eq({ id = 2 }, event_curbuf)
      eq(expected_buffers, event_buffers)
    end}
  end)
end)

describe("tabline", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(42, 5)
    screen:attach()
    screen:set_default_attr_ids({
      [0] = {bold = true, foreground = Screen.colors.Blue};  -- NonText
      [1] = {reverse = true};  -- TabLineFill
    })
  end)

  it('redraws when tabline option is set', function()
    command('set tabline=asdf')
    command('set showtabline=2')
    screen:expect{grid=[[
      {1:asdf                                      }|
      ^                                          |
      {0:~                                         }|
      {0:~                                         }|
                                                |
    ]]}
    command('set tabline=jkl')
    screen:expect{grid=[[
      {1:jkl                                       }|
      ^                                          |
      {0:~                                         }|
      {0:~                                         }|
                                                |
    ]]}
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
    meths.set_option_value('tabline', '%1T口口%2Ta' .. ('b'):rep(38) .. '%999Xc', {})
    screen:expect{grid=[[
      {1:<abbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbc }|
      tab^1                                      |
      {0:~                                         }|
      {0:~                                         }|
                                                |
    ]]}
    assert_alive()
    meths.input_mouse('left', 'press', '', 0, 0, 1)
    screen:expect{grid=[[
      {1:<abbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbc }|
      tab^2                                      |
      {0:~                                         }|
      {0:~                                         }|
                                                |
    ]]}
    meths.input_mouse('left', 'press', '', 0, 0, 0)
    screen:expect{grid=[[
      {1:<abbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbc }|
      tab^1                                      |
      {0:~                                         }|
      {0:~                                         }|
                                                |
    ]]}
    meths.input_mouse('left', 'press', '', 0, 0, 39)
    screen:expect{grid=[[
      {1:<abbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbc }|
      tab^2                                      |
      {0:~                                         }|
      {0:~                                         }|
                                                |
    ]]}
    meths.input_mouse('left', 'press', '', 0, 0, 40)
    screen:expect{grid=[[
      tab^1                                      |
      {0:~                                         }|
      {0:~                                         }|
      {0:~                                         }|
                                                |
    ]]}
  end)
end)
