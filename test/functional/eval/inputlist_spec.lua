local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local eq = helpers.eq
local feed = helpers.feed
local meths = helpers.meths
local clear = helpers.clear
local source = helpers.source
local command = helpers.command
local exc_exec = helpers.exc_exec

local screen

before_each(function()
  clear()
  screen = Screen.new(25, 5)
  screen:attach()
  screen:set_default_attr_ids({
    EOB={bold = true, foreground = Screen.colors.Blue1},
    SEP={bold = true, reverse = true},
  })
end)

describe('inputlist()', function()
  it('works with zero options', function()
    feed([[:call inputlist([])<CR>]])
    screen:expect([[
                               |
      {SEP:                         }|
      Type number and <Enter> o|
      r click with mouse (empty|
       cancels): ^              |
    ]])
    feed([[<CR>]])
    screen:expect([[
      ^                         |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
                               |
    ]])
  end)
  it('works with multiple options', function()
    feed([[:call inputlist(["foo", "bar"])<CR>]])
    screen:expect([[
      foo                      |
      bar                      |
      Type number and <Enter> o|
      r click with mouse (empty|
       cancels): ^              |
    ]])
    feed([[<CR>]])
    screen:expect([[
      ^                         |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
                               |
    ]])
  end)
  it('returns the number entered', function()
    feed(':let var = inputlist(["foo", "bar"])<CR>')
    feed('1<CR>')
    eq(1, meths.get_var('var'))
  end)
  it('returns 0 on empty value', function()
    feed(':let var = inputlist(["foo", "bar"])<CR>')
    feed('<CR>')
    eq(0, meths.get_var('var'))
  end)
  it('returns 0 on empty value and ESC', function()
    feed(':let var = inputlist(["foo", "bar"])<CR>')
    feed('<ESC>')
    eq(0, meths.get_var('var'))
  end)
  it('returns 0 on number typed and ESC', function()
    feed(':let var = inputlist(["foo", "bar"])<CR>')
    feed('1<ESC>')
    eq(0, meths.get_var('var'))
  end)
  it('errors out on invalid inputs', function()
    eq('Vim(call):E686: Argument of inputlist() must be a List',
       exc_exec('call inputlist({})'))
    eq('Vim(call):E686: Argument of inputlist() must be a List',
       exc_exec('call inputlist("string")'))
    eq('Vim(call):E686: Argument of inputlist() must be a List',
       exc_exec('call inputlist(99)'))
    eq('Vim(call):E118: Too many arguments for function: inputlist',
       exc_exec('call inputlist("", [])'))
  end)
  it('displays the number typed', function()
    feed([[:call inputlist(["foo", "bar"])<CR>]])
    feed([[123]])
    screen:expect([[
      foo                      |
      bar                      |
      Type number and <Enter> o|
      r click with mouse (empty|
       cancels): 123^           |
    ]])
    feed([[<CR>]])
  end)
  it('works with backspace as expected', function()
    feed([[:call inputlist(["foo", "bar"])<CR>]])
    feed([[123]])
    feed([[<BS><BS>0]])
    screen:expect([[
      foo                      |
      bar                      |
      Type number and <Enter> o|
      r click with mouse (empty|
       cancels): 10^            |
    ]])
    feed([[<CR>]])
    screen:expect([[
      ^                         |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
                               |
    ]])
  end)
  it('ignores alphabetical characters', function()
    feed([[:call inputlist(["foo", "bar"])<CR>]])
    feed([[az1b]])
    screen:expect([[
      foo                      |
      bar                      |
      Type number and <Enter> o|
      r click with mouse (empty|
       cancels): 1^             |
    ]])
    feed([[<CR>]])
    screen:expect([[
      ^                         |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
                               |
    ]])
  end)
  it('ignores special characters', function()
    feed([[:call inputlist(["foo", "bar"])<CR>]])
    feed([[!@#$1%^&*()]])
    screen:expect([[
      foo                      |
      bar                      |
      Type number and <Enter> o|
      r click with mouse (empty|
       cancels): 1^             |
    ]])
    feed([[<CR>]])
    screen:expect([[
      ^                         |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
                               |
    ]])
  end)
  it('is hidden by :silent', function()
    feed([[:silent call inputlist(["foo", "bar"])<CR>]])
    screen:expect([[
      ^                         |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
                               |
    ]])
  end)
  it('returns 0 on clicking first item', function()
    command('set mouse=a')
    feed(':let var = inputlist(["foo", "bar"])<CR>')
    feed('<LeftMouse><0,0>')
    eq(0, meths.get_var('var'))
  end)
  it('returns number of items + 1 on clicking prompt', function()
    command('set mouse=a')
    feed(':let var = inputlist(["foo", "bar"])<CR>')
    feed('<LeftMouse><0,3>')
    eq(3, meths.get_var('var'))
    feed('<CR>')
  end)
  it('returns negative number on clicking above first option', function()
    command('set mouse=a')
    feed(':let var = inputlist(["foo"])<CR>')
    feed('<LeftMouse><0,0>')
    eq(-1, meths.get_var('var'))
  end)
end)
