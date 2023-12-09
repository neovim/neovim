local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local feed = helpers.feed
local write_file = helpers.write_file

before_each(clear)

describe(':source!', function()
  -- oldtest: Test_nested_script()
  it('gives E22 when scripts nested too deep', function()
    write_file('Xscript.vim', [[
    :source! Xscript.vim
    ]])
    local screen = Screen.new(75, 6)
    screen:set_default_attr_ids({
      [0] = {bold = true, foreground = Screen.colors.Blue},  -- NonText
      [1] = {background = Screen.colors.Red, foreground = Screen.colors.White},  -- ErrorMsg
    })
    screen:attach()
    feed(':source! Xscript.vim\n')
    screen:expect([[
      ^                                                                           |
      {0:~                                                                          }|*4
      {1:E22: Scripts nested too deep}                                               |
    ]])
    os.remove('Xscript.vim')
  end)
end)
