local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local clear, feed, insert = helpers.clear, helpers.feed, helpers.insert
local command, eval = helpers.command, helpers.eval
local eq = helpers.eq

describe('ui mode_change event', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(25, 4)
    screen:attach({rgb= true})
    screen:set_default_attr_ids( {
      [0] = {bold=true, foreground=255},
      [1] = {bold=true, reverse=true},
      [2] = {bold=true},
      [3] = {reverse=true},
    })
  end)

  it('works in normal mode', function()
    screen:expect([[
      ^                         |
      {0:~                        }|
      {0:~                        }|
                               |
    ]],nil,nil,function ()
      eq("normal", screen.mode)
    end)

    feed('d')
    screen:expect([[
      ^                         |
      {0:~                        }|
      {0:~                        }|
                               |
    ]],nil,nil,function ()
      eq("operator", screen.mode)
    end)

    feed('<esc>')
    screen:expect([[
      ^                         |
      {0:~                        }|
      {0:~                        }|
                               |
    ]],nil,nil,function ()
      eq("normal", screen.mode)
    end)
  end)

  it('works in insert mode', function()
    feed('i')
    screen:expect([[
      ^                         |
      {0:~                        }|
      {0:~                        }|
      {2:-- INSERT --}             |
    ]],nil,nil,function ()
      eq("insert", screen.mode)
    end)

    feed('word<esc>')
    screen:expect([[
      wor^d                     |
      {0:~                        }|
      {0:~                        }|
                               |
    ]], nil, nil, function ()
      eq("normal", screen.mode)
    end)

    command("set showmatch")
    eq(eval('&matchtime'), 5) -- tenths of seconds
    feed('a(stuff')
    screen:expect([[
      word(stuff^               |
      {0:~                        }|
      {0:~                        }|
      {2:-- INSERT --}             |
    ]], nil, nil, function ()
      eq("insert", screen.mode)
    end)

    feed(')')
    screen:expect([[
      word^(stuff)              |
      {0:~                        }|
      {0:~                        }|
      {2:-- INSERT --}             |
    ]], nil, nil, function ()
      eq("showmatch", screen.mode)
    end)

    screen:sleep(400)
    screen:expect([[
      word(stuff)^              |
      {0:~                        }|
      {0:~                        }|
      {2:-- INSERT --}             |
    ]], nil, nil, function ()
      eq("insert", screen.mode)
    end)
  end)

  it('works in replace mode', function()
    feed('R')
    screen:expect([[
      ^                         |
      {0:~                        }|
      {0:~                        }|
      {2:-- REPLACE --}            |
    ]], nil, nil, function ()
      eq("replace", screen.mode)
    end)

    feed('word<esc>')
    screen:expect([[
      wor^d                     |
      {0:~                        }|
      {0:~                        }|
                               |
    ]], nil, nil, function ()
      eq("normal", screen.mode)
    end)
  end)

  it('works in cmdline mode', function()
    feed(':')
    screen:expect([[
                               |
      {0:~                        }|
      {0:~                        }|
      :^                        |
    ]],nil,nil,function ()
      eq("cmdline_normal", screen.mode)
    end)

    feed('x<left>')
    screen:expect([[
                               |
      {0:~                        }|
      {0:~                        }|
      :^x                       |
    ]],nil,nil,function ()
      eq("cmdline_insert", screen.mode)
    end)

    feed('<insert>')
    screen:expect([[
                               |
      {0:~                        }|
      {0:~                        }|
      :^x                       |
    ]],nil,nil,function ()
      eq("cmdline_replace", screen.mode)
    end)


    feed('<right>')
    screen:expect([[
                               |
      {0:~                        }|
      {0:~                        }|
      :x^                       |
    ]],nil,nil,function ()
      eq("cmdline_normal", screen.mode)
    end)

    feed('<esc>')
    screen:expect([[
      ^                         |
      {0:~                        }|
      {0:~                        }|
                               |
    ]],nil,nil,function ()
      eq("normal", screen.mode)
    end)
  end)

  it('works in visal mode', function()
    insert("text")
    feed('v')
    screen:expect([[
      tex^t                     |
      {0:~                        }|
      {0:~                        }|
      {2:-- VISUAL --}             |
    ]],nil,nil,function ()
      eq("visual", screen.mode)
    end)

    feed('<esc>')
    screen:expect([[
      tex^t                     |
      {0:~                        }|
      {0:~                        }|
                               |
    ]],nil,nil,function ()
      eq("normal", screen.mode)
    end)

    command('set selection=exclusive')
    feed('v')
    screen:expect([[
      tex^t                     |
      {0:~                        }|
      {0:~                        }|
      {2:-- VISUAL --}             |
    ]],nil,nil,function ()
      eq("visual_select", screen.mode)
    end)

    feed('<esc>')
    screen:expect([[
      tex^t                     |
      {0:~                        }|
      {0:~                        }|
                               |
    ]],nil,nil,function ()
      eq("normal", screen.mode)
    end)
  end)
end)

