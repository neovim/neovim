local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local command = helpers.command
local insert = helpers.insert
local meths = helpers.meths
local eq = helpers.eq

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
    })
    command('set winbar=Set\\ Up\\ The\\ Bars')
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
  it('sets correct position on mouse click', function()
    insert[[
      line 1
      line 2
      line 3
      line 4
      line -42
      line i
      line sin(theta)
      line 8
    ]]
    meths.input_mouse('left', 'press', '', 0, 5, 1)
    eq({5, 1}, meths.win_get_cursor(0))
  end)
end)
