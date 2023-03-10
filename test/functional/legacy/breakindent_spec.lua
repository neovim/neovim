local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local exec = helpers.exec
local feed = helpers.feed

before_each(clear)

describe('breakindent', function()
  -- oldtest: Test_cursor_position_with_showbreak()
  it('cursor shown at correct position with showbreak', function()
    local screen = Screen.new(75, 6)
    screen:set_default_attr_ids({
      [0] = {bold = true, foreground = Screen.colors.Blue},  -- NonText
      [1] = {background = Screen.colors.Grey, foreground = Screen.colors.DarkBlue},  -- SignColumn
      [2] = {bold = true},  -- ModeMsg
    })
    screen:attach()
    exec([[
      let &signcolumn = 'yes'
      let &showbreak = '+'
      let leftcol = win_getid()->getwininfo()->get(0, {})->get('textoff')
      eval repeat('x', &columns - leftcol - 1)->setline(1)
      eval 'second line'->setline(2)
    ]])
    screen:expect([[
      {1:  }^xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx |
      {1:  }second line                                                              |
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
                                                                                 |
    ]])
    feed('AX')
    screen:expect([[
      {1:  }xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxX|
      {1:  }^second line                                                              |
      {0:~                                                                          }|
      {0:~                                                                          }|
      {0:~                                                                          }|
      {2:-- INSERT --}                                                               |
    ]])
  end)
end)
