local helpers = require('test.functional.helpers')
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local execute = helpers.execute
local insert = helpers.insert
local eq = helpers.eq
local eval = helpers.eval

describe('Syntax', function()
  local screen
  local colors = Screen.colors

  before_each(function()
    clear()
    screen = Screen.new(25,5)
    screen:attach()
    screen:set_default_attr_ignore( {{bold=true, foreground = Screen.colors.Blue}} )
    execute('syntax on')
    execute('syntax keyword Type integer')
  end)

  after_each(function()
    screen:detach()
  end)

  it('keyword item matches keyword', function()
    insert('integer a;\n')
    screen:expect([[
      {1:integer} a;               |
      ^                         |
      ~                        |
      ~                        |
                               |
    ]], {[1] = {bold = true, foreground = Screen.colors.SeaGreen}})
  end)

  it('keyword item does not match \'iskeyword\' characters extended string', function()
    insert('integer_type a;\n')
    screen:expect([[
      integer_type a;          |
      ^                         |
      ~                        |
      ~                        |
                               |
    ]])
  end)

end)
