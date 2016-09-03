local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local feed = helpers.feed
local clear = helpers.clear
local command = helpers.command

local screen

before_each(function()
  clear()
  screen = Screen.new(25, 5)
  screen:attach()
end)

describe('input()', function()
  it('works correctly with multiline prompts', function()
    feed([[:call input("Test\nFoo")<CR>]])
    screen:expect([[
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      Test                     |
      Foo^                      |
    ]], {{bold=true, foreground=Screen.colors.Blue}})
  end)
  it('works correctly with multiline prompts and :echohl', function()
    command('hi Test ctermfg=Red guifg=Red term=bold')
    feed([[:echohl Test | call input("Test\nFoo")<CR>]])
    screen:expect([[
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {2:Test}                     |
      {2:Foo}^                      |
    ]], {{bold=true, foreground=Screen.colors.Blue}, {foreground=Screen.colors.Red}})
  end)
end)
