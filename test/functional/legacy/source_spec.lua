local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local feed = n.feed
local write_file = t.write_file

before_each(clear)

describe(':source!', function()
  -- oldtest: Test_nested_script()
  it('gives E22 when scripts nested too deep', function()
    write_file(
      'Xscript.vim',
      [[
    :source! Xscript.vim
    ]]
    )
    local screen = Screen.new(75, 6)
    screen:attach()
    feed(':source! Xscript.vim\n')
    screen:expect([[
      ^                                                                           |
      {1:~                                                                          }|*4
      {9:E22: Scripts nested too deep}                                               |
    ]])
    os.remove('Xscript.vim')
  end)
end)
