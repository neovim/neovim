local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local execute = helpers.execute


describe('Screen rendering', function()
  local screen
  local colors = Screen.colors
  local hl_colors = {
    NonText = colors.Blue,
    Search = colors.Yellow,
    Message = colors.Red,
  }

  before_each(function()
    clear()
    screen = Screen.new(40, 7)
    screen:attach()
    --ignore highligting of ~-lines
    screen:set_default_attr_ids( {
      [1] = {foreground = Screen.colors.Brown},
      [2] = {bold = true, foreground = Screen.colors.Brown},
      [3] = {foreground = hl_colors.Message},
    })
    screen:set_default_attr_ignore( {{bold=true, foreground=hl_colors.NonText}} )
    insert("line 1\n")
    insert("line 2\n")
    insert("line 3\n")
    insert("line 4\n")
    insert("line 5\n")
    insert("line 6")
    feed("gg")
  end)

  it('works with line number', function()
    execute('set number')
    screen:expect([[
      {1:  1 }^line 1                              |
      {1:  2 }line 2                              |
      {1:  3 }line 3                              |
      {1:  4 }line 4                              |
      {1:  5 }line 5                              |
      {1:  6 }line 6                              |
      :set number                             |
    ]])
  end)

  it('works with relative line number', function()
    execute('set relativenumber')
    feed("4gg")
    screen:expect([[
      {1:  3 }line 1                              |
      {1:  2 }line 2                              |
      {1:  1 }line 3                              |
      {2:  0 }^line 4                              |
      {1:  1 }line 5                              |
      {1:  2 }line 6                              |
      :set relativenumber                     |
    ]])
  end)

  it('works with number + relative line number', function()
    execute('set number')
    execute('set relativenumber')
    feed("4gg")
    screen:expect([[
      {1:  3 }line 1                              |
      {1:  2 }line 2                              |
      {1:  1 }line 3                              |
      {2:4   }^line 4                              |
      {1:  1 }line 5                              |
      {1:  2 }line 6                              |
      :set relativenumber                     |
    ]])
  end)

end)

