local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local eq = helpers.eq
local wait = helpers.wait
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
  source([[
    hi Test ctermfg=Red guifg=Red term=bold
    function CustomCompl(...)
      return 'TEST'
    endfunction
    function CustomListCompl(...)
      return ['FOO']
    endfunction
  ]])
  screen:set_default_attr_ids({
    EOB={bold = true, foreground = Screen.colors.Blue1},
    T={foreground=Screen.colors.Red},
  })
end)

describe('input()', function()
  it('works correctly with multiline prompts', function()
    feed([[:call input("Test\nFoo")<CR>]])
    screen:expect([[
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      Test                     |
      Foo^                      |
    ]])
  end)
  it('works correctly with multiline prompts and :echohl', function()
    feed([[:echohl Test | call input("Test\nFoo")<CR>]])
    screen:expect([[
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:Test}                     |
      {T:Foo}^                      |
    ]])
    wait()
    command('redraw!')
    wait()
    screen:expect([[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:Foo}^                      |
    ]])
  end)
  it('works correctly with multiple numeric arguments (many args)', function()
    command('hi Test ctermfg=Red guifg=Red term=bold')
    feed([[:echohl Test | call input(1, 2)<CR>]])
    wait()  -- Without wait() it first shows `12` line and then empty line.
    command('redraw!')  -- Without this it shows two `12` lines.
    wait()
    -- None of the above problems happen when testing manually.
    screen:expect([[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:1}2^                       |
    ]])
    feed('<BS>')
    wait()
    screen:expect([[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:1}^                        |
    ]])
  end)
  it('works correctly with multiple numeric arguments (dict arg)', function()
    feed([[:echohl Test | echo input({"prompt": 1, "default": 2, "cancelreturn": 3})<CR>]])
    wait()  -- Without wait() it first shows `12` line and then empty line.
    command('redraw!')  -- Without this it shows two `12` lines.
    -- None of the above problems happen when testing manually.
    screen:expect([[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:1}2^                       |
    ]])
    feed('<BS>')
    wait()
    screen:expect([[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:1}^                        |
    ]])
    feed('<Esc>')
    wait()
    screen:expect([[
      ^                         |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:3}                        |
    ]])
  end)
  it('allows omitting everything with dictionary argument', function()
    feed(':echohl Test | echo input({})<CR>')
    wait()
    command('redraw!')
    screen:expect([[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      ^                         |
    ]])
  end)
  it('supports completion', function()
    feed(':let var = input("", "", "custom,CustomCompl")<CR>')
    wait()
    feed('<Tab><CR>')
    eq('TEST', meths.get_var('var'))

    feed(':let var = input({"completion": "customlist,CustomListCompl"})<CR>')
    wait()
    feed('<Tab><CR>')
    wait()
    eq('FOO', meths.get_var('var'))
  end)
  it('supports cancelreturn', function()
    feed(':let var = input({"cancelreturn": "BAR"})<CR>')
    wait()
    feed('<Esc>')
    wait()
    eq('BAR', meths.get_var('var'))
  end)
  it('supports default string', function()
    feed(':let var = input("", "DEF1")<CR>')
    wait()
    feed('<CR>')
    eq('DEF1', meths.get_var('var'))

    feed(':let var = input({"default": "DEF2"})<CR>')
    wait()
    feed('<CR>')
    wait()
    eq('DEF2', meths.get_var('var'))
  end)
  it('errors out on invalid inputs', function()
    eq('Vim(call):E730: using List as a String',
       exc_exec('call input([])'))
    eq('Vim(call):E730: using List as a String',
       exc_exec('call input("", [])'))
    eq('Vim(call):E730: using List as a String',
       exc_exec('call input("", "", [])'))
    eq('Vim(call):E730: using List as a String',
       exc_exec('call input({"prompt": []})'))
    eq('Vim(call):E730: using List as a String',
       exc_exec('call input({"cancelreturn": []})'))
    eq('Vim(call):E730: using List as a String',
       exc_exec('call input({"default": []})'))
    eq('Vim(call):E730: using List as a String',
       exc_exec('call input({"completion": []})'))
  end)
end)
describe('inputdialog()', function()
  it('works correctly with multiline prompts', function()
    feed([[:call inputdialog("Test\nFoo")<CR>]])
    screen:expect([[
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      Test                     |
      Foo^                      |
    ]])
  end)
  it('works correctly with multiline prompts and :echohl', function()
    feed([[:echohl Test | call inputdialog("Test\nFoo")<CR>]])
    screen:expect([[
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:Test}                     |
      {T:Foo}^                      |
    ]])
    wait()
    command('redraw!')
    wait()
    screen:expect([[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:Foo}^                      |
    ]])
  end)
  it('works correctly with multiple numeric arguments (many args)', function()
    command('hi Test ctermfg=Red guifg=Red term=bold')
    feed([[:echohl Test | call inputdialog(1, 2)<CR>]])
    wait()  -- Without wait() it first shows `12` line and then empty line.
    command('redraw!')  -- Without this it shows two `12` lines.
    wait()
    -- None of the above problems happen when testing manually.
    screen:expect([[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:1}2^                       |
    ]])
    feed('<BS>')
    wait()
    screen:expect([[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:1}^                        |
    ]])
  end)
  it('works correctly with multiple numeric arguments (dict arg)', function()
    feed([[:echohl Test | echo inputdialog({"prompt": 1, "default": 2, "cancelreturn": 3})<CR>]])
    wait()  -- Without wait() it first shows `12` line and then empty line.
    command('redraw!')  -- Without this it shows two `12` lines.
    -- None of the above problems happen when testing manually.
    screen:expect([[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:1}2^                       |
    ]])
    feed('<BS>')
    wait()
    screen:expect([[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:1}^                        |
    ]])
    feed('<Esc>')
    wait()
    screen:expect([[
      ^                         |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      {T:3}                        |
    ]])
  end)
  it('allows omitting everything with dictionary argument', function()
    feed(':echohl Test | echo inputdialog({})<CR>')
    wait()
    command('redraw!')
    screen:expect([[
                               |
      {EOB:~                        }|
      {EOB:~                        }|
      {EOB:~                        }|
      ^                         |
    ]])
  end)
  it('supports completion', function()
    feed(':let var = inputdialog({"completion": "customlist,CustomListCompl"})<CR>')
    wait()
    feed('<Tab><CR>')
    wait()
    eq('FOO', meths.get_var('var'))
  end)
  it('supports cancelreturn', function()
    feed(':let var = inputdialog("", "", "CR1")<CR>')
    wait()
    feed('<Esc>')
    wait()
    eq('CR1', meths.get_var('var'))

    feed(':let var = inputdialog({"cancelreturn": "BAR"})<CR>')
    wait()
    feed('<Esc>')
    wait()
    eq('BAR', meths.get_var('var'))
  end)
  it('supports default string', function()
    feed(':let var = inputdialog("", "DEF1")<CR>')
    wait()
    feed('<CR>')
    eq('DEF1', meths.get_var('var'))

    feed(':let var = inputdialog({"default": "DEF2"})<CR>')
    wait()
    feed('<CR>')
    wait()
    eq('DEF2', meths.get_var('var'))
  end)
  it('errors out on invalid inputs', function()
    eq('Vim(call):E730: using List as a String',
       exc_exec('call inputdialog([])'))
    eq('Vim(call):E730: using List as a String',
       exc_exec('call inputdialog("", [])'))
    eq('Vim(call):E730: using List as a String',
       exc_exec('call inputdialog("", "", [])'))
    eq('Vim(call):E730: using List as a String',
       exc_exec('call inputdialog({"prompt": []})'))
    eq('Vim(call):E730: using List as a String',
       exc_exec('call inputdialog({"cancelreturn": []})'))
    eq('Vim(call):E730: using List as a String',
       exc_exec('call inputdialog({"default": []})'))
    eq('Vim(call):E730: using List as a String',
       exc_exec('call inputdialog({"completion": []})'))
  end)
end)
