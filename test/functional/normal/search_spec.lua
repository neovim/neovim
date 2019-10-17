local Screen = require('test.functional.ui.screen')
local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local eval = helpers.eval
local feed = helpers.feed
local pcall_err = helpers.pcall_err

describe('search (/)', function()
  before_each(clear)

  it('fails with huge column (%c) value #9930', function()
    eq([[Vim:E951: \% value too large]],
      pcall_err(command, "/\\v%18446744071562067968c"))
    eq([[Vim:E951: \% value too large]],
      pcall_err(command, "/\\v%2147483648c"))
  end)
end)

it('nv_next does not unnecessarily re-search (n/N)', function()
  clear()
  helpers.insert('foobar')
  local screen = Screen.new(40, 5)
  screen:set_default_attr_ids({
    [1] = {background = Screen.colors.Yellow},
    [2] = {bold = true, foreground = Screen.colors.Blue1},
    [3] = {foreground = Screen.colors.Red},
  })
  screen:attach()
  command('set shm= wrapscan')

  feed('gg0/bar<cr>')
  screen:expect{grid=[[
    foo{1:^bar}                                  |
    {2:~                                       }|
    {2:~                                       }|
    {2:~                                       }|
    /bar                             [1/1]  |
  ]]}
  eq('/bar                             [1/1]', eval('trim(execute(":messages"))'))

  command(':messages clear')
  feed('n')
  screen:expect{grid=[[
    foo{1:^bar}                                  |
    {2:~                                       }|
    {2:~                                       }|
    {2:~                                       }|
    {3:search hit BOTTOM, continuing at TOP}    |
  ]]}

  -- Check that normal_search was not called again in nv_next by checking for a
  -- single bot_top_msg (would be 3 otherwise).
  eq('search hit BOTTOM, continuing at TOP',
    eval('trim(execute(":messages"))'))
end)
