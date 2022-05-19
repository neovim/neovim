local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local command = helpers.command
local insert = helpers.insert
local meths = helpers.meths
local eq = helpers.eq
local poke_eventloop = helpers.poke_eventloop
local feed = helpers.feed

describe('winbar', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(60, 13)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = {bold = true},
      [2] = {reverse = true},
      [3] = {bold = true, foreground = Screen.colors.Blue},
      [4] = {bold = true, reverse = true},
      [5] = {bold = true, foreground = Screen.colors.Red},
      [6] = {foreground = Screen.colors.Blue},
      [7] = {background = Screen.colors.LightGrey},
    })
    meths.set_option('winbar', 'Set Up The Bars')
  end)
  it('works', function()
    screen:expect([[
      {1:Set Up The Bars                                             }|
      ^                                                            |
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
                                                                  |
    ]])
  end)
  it('works with custom \'fillchars\' value', function()
    command('set fillchars=wbr:+')
    screen:expect([[
      {1:Set Up The Bars+++++++++++++++++++++++++++++++++++++++++++++}|
      ^                                                            |
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
                                                                  |
    ]])
  end)
  it('works with custom highlight', function()
    command('hi WinBar guifg=red')
    screen:expect([[
      {5:Set Up The Bars                                             }|
      ^                                                            |
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
                                                                  |
    ]])
  end)
  it('works with splits', function()
    command('hi WinBar guifg=red')
    command('hi WinBarNC guifg=blue')
    command('belowright vsplit | split | split')
    screen:expect([[
      {6:Set Up The Bars              }│{5:Set Up The Bars               }|
                                   │^                              |
      {3:~                            }│{3:~                             }|
      {3:~                            }│{4:[No Name]                     }|
      {3:~                            }│{6:Set Up The Bars               }|
      {3:~                            }│                              |
      {3:~                            }│{3:~                             }|
      {3:~                            }│{2:[No Name]                     }|
      {3:~                            }│{6:Set Up The Bars               }|
      {3:~                            }│                              |
      {3:~                            }│{3:~                             }|
      {2:[No Name]                     [No Name]                     }|
                                                                  |
    ]])
  end)
  it('works when switching value of \'winbar\'', function()
    command('belowright vsplit | split | split | set winbar=')
    screen:expect([[
                                   │^                              |
      {3:~                            }│{3:~                             }|
      {3:~                            }│{3:~                             }|
      {3:~                            }│{4:[No Name]                     }|
      {3:~                            }│                              |
      {3:~                            }│{3:~                             }|
      {3:~                            }│{3:~                             }|
      {3:~                            }│{2:[No Name]                     }|
      {3:~                            }│                              |
      {3:~                            }│{3:~                             }|
      {3:~                            }│{3:~                             }|
      {2:[No Name]                     [No Name]                     }|
                                                                  |
    ]])
    command('set winbar=All\\ Your\\ Bar\\ Are\\ Belong\\ To\\ Us')
    screen:expect([[
      {1:All Your Bar Are Belong To Us}│{1:All Your Bar Are Belong To Us }|
                                   │^                              |
      {3:~                            }│{3:~                             }|
      {3:~                            }│{4:[No Name]                     }|
      {3:~                            }│{1:All Your Bar Are Belong To Us }|
      {3:~                            }│                              |
      {3:~                            }│{3:~                             }|
      {3:~                            }│{2:[No Name]                     }|
      {3:~                            }│{1:All Your Bar Are Belong To Us }|
      {3:~                            }│                              |
      {3:~                            }│{3:~                             }|
      {2:[No Name]                     [No Name]                     }|
                                                                  |
    ]])
    command('set winbar=Changed\\ winbar')
    screen:expect([[
      {1:Changed winbar               }│{1:Changed winbar                }|
                                   │^                              |
      {3:~                            }│{3:~                             }|
      {3:~                            }│{4:[No Name]                     }|
      {3:~                            }│{1:Changed winbar                }|
      {3:~                            }│                              |
      {3:~                            }│{3:~                             }|
      {3:~                            }│{2:[No Name]                     }|
      {3:~                            }│{1:Changed winbar                }|
      {3:~                            }│                              |
      {3:~                            }│{3:~                             }|
      {2:[No Name]                     [No Name]                     }|
                                                                  |
    ]])
  end)
  it('can be ruler', function()
    insert [[
      just some
      random text]]
    meths.set_option('winbar', 'Hello, I am a ruler: %l,%c')
    screen:expect{grid=[[
      {1:Hello, I am a ruler: 2,11                                   }|
      just some                                                   |
      random tex^t                                                 |
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
                                                                  |
    ]]}
    feed 'b'
    screen:expect{grid=[[
      {1:Hello, I am a ruler: 2,8                                    }|
      just some                                                   |
      random ^text                                                 |
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
                                                                  |
    ]]}
    feed 'k'
    screen:expect{grid=[[
      {1:Hello, I am a ruler: 1,8                                    }|
      just so^me                                                   |
      random text                                                 |
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
                                                                  |
    ]]}
  end)
  it('works with laststatus=3', function()
    command('set laststatus=3')
    screen:expect([[
      {1:Set Up The Bars                                             }|
      ^                                                            |
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {4:[No Name]                                                   }|
                                                                  |
    ]])
    command('belowright vsplit | split | split')
    screen:expect([[
      {1:Set Up The Bars              }│{1:Set Up The Bars               }|
                                   │^                              |
      {3:~                            }│{3:~                             }|
      {3:~                            }├──────────────────────────────|
      {3:~                            }│{1:Set Up The Bars               }|
      {3:~                            }│                              |
      {3:~                            }│{3:~                             }|
      {3:~                            }├──────────────────────────────|
      {3:~                            }│{1:Set Up The Bars               }|
      {3:~                            }│                              |
      {3:~                            }│{3:~                             }|
      {4:[No Name]                                                   }|
                                                                  |
    ]])
  end)

  it('mouse click and drag work correctly in buffer', function()
    insert([[
      line 1
      line 2
      line 3
      line 4
      line -42
      line i
      line sin(theta)
      line 8]])

    meths.input_mouse('left', 'press', '', 0, 5, 1)
    screen:expect([[
      {1:Set Up The Bars                                             }|
      line 1                                                      |
      line 2                                                      |
      line 3                                                      |
      line 4                                                      |
      l^ine -42                                                    |
      line i                                                      |
      line sin(theta)                                             |
      line 8                                                      |
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
                                                                  |
    ]])
    eq({5, 1}, meths.win_get_cursor(0))

    meths.input_mouse('left', 'drag', '', 0, 6, 2)
    screen:expect([[
      {1:Set Up The Bars                                             }|
      line 1                                                      |
      line 2                                                      |
      line 3                                                      |
      line 4                                                      |
      l{7:ine -42}                                                    |
      {7:li}^ne i                                                      |
      line sin(theta)                                             |
      line 8                                                      |
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {1:-- VISUAL --}                                                |
    ]])
    eq({6, 2}, meths.win_get_cursor(0))

    meths.input_mouse('left', 'drag', '', 0, 1, 2)
    screen:expect([[
      {1:Set Up The Bars                                             }|
      li^n{7:e 1}                                                      |
      {7:line 2}                                                      |
      {7:line 3}                                                      |
      {7:line 4}                                                      |
      {7:li}ne -42                                                    |
      line i                                                      |
      line sin(theta)                                             |
      line 8                                                      |
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {1:-- VISUAL --}                                                |
    ]])
    eq({1, 2}, meths.win_get_cursor(0))

    meths.input_mouse('left', 'drag', '', 0, 0, 2)
    screen:expect_unchanged()
    eq({1, 2}, meths.win_get_cursor(0))
  end)

  it('dragging statusline with mouse works correctly', function()
    command('split')
    screen:expect([[
      {1:Set Up The Bars                                             }|
      ^                                                            |
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {4:[No Name]                                                   }|
      {1:Set Up The Bars                                             }|
                                                                  |
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {2:[No Name]                                                   }|
                                                                  |
    ]])

    meths.input_mouse('left', 'press', '', 1, 5, 10)
    poke_eventloop()
    meths.input_mouse('left', 'drag', '', 1, 6, 10)
    screen:expect([[
      {1:Set Up The Bars                                             }|
      ^                                                            |
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {4:[No Name]                                                   }|
      {1:Set Up The Bars                                             }|
                                                                  |
      {3:~                                                           }|
      {3:~                                                           }|
      {2:[No Name]                                                   }|
                                                                  |
    ]])

    meths.input_mouse('left', 'drag', '', 1, 4, 10)
    screen:expect([[
      {1:Set Up The Bars                                             }|
      ^                                                            |
      {3:~                                                           }|
      {3:~                                                           }|
      {4:[No Name]                                                   }|
      {1:Set Up The Bars                                             }|
                                                                  |
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {2:[No Name]                                                   }|
                                                                  |
    ]])

    meths.input_mouse('left', 'press', '', 1, 11, 10)
    poke_eventloop()
    meths.input_mouse('left', 'drag', '', 1, 9, 10)
    screen:expect([[
      {1:Set Up The Bars                                             }|
      ^                                                            |
      {3:~                                                           }|
      {3:~                                                           }|
      {4:[No Name]                                                   }|
      {1:Set Up The Bars                                             }|
                                                                  |
      {3:~                                                           }|
      {3:~                                                           }|
      {2:[No Name]                                                   }|
                                                                  |
                                                                  |
                                                                  |
    ]])
    eq(3, meths.get_option('cmdheight'))

    meths.input_mouse('left', 'drag', '', 1, 11, 10)
    screen:expect([[
      {1:Set Up The Bars                                             }|
      ^                                                            |
      {3:~                                                           }|
      {3:~                                                           }|
      {4:[No Name]                                                   }|
      {1:Set Up The Bars                                             }|
                                                                  |
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {2:[No Name]                                                   }|
                                                                  |
    ]])
    eq(1, meths.get_option('cmdheight'))
  end)
  it('properly equalizes window height for window-local value', function()
    command('set equalalways | set winbar= | setlocal winbar=a | split')
    command('setlocal winbar= | split')
    command('setlocal winbar=b | split')
    screen:expect([[
      {1:b                                                           }|
      ^                                                            |
      {4:[No Name]                                                   }|
      {1:b                                                           }|
                                                                  |
      {2:[No Name]                                                   }|
                                                                  |
      {3:~                                                           }|
      {2:[No Name]                                                   }|
      {1:a                                                           }|
                                                                  |
      {2:[No Name]                                                   }|
                                                                  |
    ]])
  end)
end)
