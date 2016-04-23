local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, execute = helpers.clear, helpers.feed, helpers.execute

describe('matchparen', function() 
  local screen

  before_each(function()
    clear()
    screen = Screen.new(20,5)
    screen:attach()
    screen:set_default_attr_ignore( {{bold=true, foreground=Screen.colors.Blue}} )
  end)

  it('uses correct column after i_<Up>. Vim patch 7.4.1296', function()
    execute('set noai nosi nocin')
    execute('runtime plugin/matchparen.vim')
    feed('ivoid f_test()<cr>')
    feed('{<cr>')
    feed('}')

    -- critical part: up + cr should result in an empty line inbetween the
    -- brackets... if the bug is there, the empty line will be before the '{'
    feed('<up>')
    feed('<cr>')

    screen:expect([[
      void f_test()       |
      {                   |
      ^                    |
      }                   |
      {1:-- INSERT --}        |
    ]], {[1] = {bold = true}})    

  end)
end)
