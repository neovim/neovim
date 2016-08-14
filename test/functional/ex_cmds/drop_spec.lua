local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed, execute = helpers.clear, helpers.feed, helpers.execute

describe(":drop", function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(35, 10)
    screen:attach()
    screen:set_default_attr_ids({
      [0] = {bold=true, foreground=Screen.colors.Blue},
      [1] = {bold = true, reverse = true},
      [2] = {reverse = true},
      [3] = {bold = true},
    })
    execute("set laststatus=2")
  end)

  after_each(function()
    screen:detach()
  end)

  it("works like :e when called with only one window open", function()
    execute("drop tmp1.vim")
    screen:expect([[
      ^                                   |
      {0:~                                  }|
      {0:~                                  }|
      {0:~                                  }|
      {0:~                                  }|
      {0:~                                  }|
      {0:~                                  }|
      {0:~                                  }|
      {1:tmp1.vim                           }|
      "tmp1.vim" [New File]              |
    ]])
  end)

  it("switches to an open window showing the buffer", function()
    execute("edit tmp1")
    execute("vsplit")
    execute("edit tmp2")
    execute("drop tmp1")
    screen:expect([[
                    {2:|}^                    |
      {0:~             }{2:|}{0:~                   }|
      {0:~             }{2:|}{0:~                   }|
      {0:~             }{2:|}{0:~                   }|
      {0:~             }{2:|}{0:~                   }|
      {0:~             }{2:|}{0:~                   }|
      {0:~             }{2:|}{0:~                   }|
      {0:~             }{2:|}{0:~                   }|
      {2:tmp2           }{1:tmp1                }|
      :drop tmp1                         |
    ]])
  end)

  it("splits off a new window when a buffer can't be abandoned", function()
    execute("edit tmp1")
    execute("vsplit")
    execute("edit tmp2")
    feed("iABC<esc>")
    execute("drop tmp3")
    screen:expect([[
      ^                    {2:|}              |
      {0:~                   }{2:|}{0:~             }|
      {0:~                   }{2:|}{0:~             }|
      {0:~                   }{2:|}{0:~             }|
      {1:tmp3                }{2:|}{0:~             }|
      ABC                 {2:|}{0:~             }|
      {0:~                   }{2:|}{0:~             }|
      {0:~                   }{2:|}{0:~             }|
      {2:tmp2 [+]             tmp1          }|
      "tmp3" [New File]                  |
    ]])
  end)

end)
