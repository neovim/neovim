local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local command = helpers.command
local insert = helpers.insert
local meths = helpers.meths
local eq = helpers.eq
local poke_eventloop = helpers.poke_eventloop
local feed = helpers.feed
local funcs = helpers.funcs
local curwin = helpers.curwin
local pcall_err = helpers.pcall_err

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
      [8] = {background = Screen.colors.LightMagenta},
      [9] = {bold = true, foreground = Screen.colors.Blue, background = Screen.colors.LightMagenta},
      [10] = {background = Screen.colors.LightGrey, underline = true},
      [11] = {background = Screen.colors.LightGrey, underline = true, bold = true, foreground = Screen.colors.Magenta},
    })
    meths.set_option_value('winbar', 'Set Up The Bars', {})
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
    -- winbar is excluded from the heights returned by winheight() and getwininfo()
    eq(11, funcs.winheight(0))
    local win_info = funcs.getwininfo(curwin().id)[1]
    eq(11, win_info.height)
    eq(1, win_info.winbar)
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
    -- 'showcmdloc' "statusline" should not interfere with winbar redrawing #23030
    command('set showcmd showcmdloc=statusline')
    feed('<C-W>w')
    feed('<C-W>')
    screen:expect([[
      {6:Set Up The Bars              }│{6:Set Up The Bars               }|
                                   │                              |
      {3:~                            }│{3:~                             }|
      {3:~                            }│{2:[No Name]                     }|
      {3:~                            }│{5:Set Up The Bars               }|
      {3:~                            }│^                              |
      {3:~                            }│{3:~                             }|
      {3:~                            }│{4:[No Name]          ^W         }|
      {3:~                            }│{6:Set Up The Bars               }|
      {3:~                            }│                              |
      {3:~                            }│{3:~                             }|
      {2:[No Name]                     [No Name]                     }|
                                                                  |
    ]])
    feed('w<C-W>W')
    screen:expect([[
      {6:Set Up The Bars              }│{6:Set Up The Bars               }|
                                   │                              |
      {3:~                            }│{3:~                             }|
      {3:~                            }│{2:[No Name]                     }|
      {3:~                            }│{5:Set Up The Bars               }|
      {3:~                            }│^                              |
      {3:~                            }│{3:~                             }|
      {3:~                            }│{4:[No Name]                     }|
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
    meths.set_option_value('winbar', 'Hello, I am a ruler: %l,%c', {})
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
    -- Test for issue #18791
    command('tabnew')
    screen:expect([[
      {10: }{11:4}{10: [No Name] }{1: [No Name] }{2:                                   }{10:X}|
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
    eq(3, meths.get_option_value('cmdheight', {}))

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
    eq(1, meths.get_option_value('cmdheight', {}))
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

  it('requires window-local value for floating windows', function()
    local win = meths.open_win(0, false, { relative = 'editor', row = 2, col = 10, height = 7,
                                           width = 30 })
    meths.set_option_value('winbar', 'bar', {})
    screen:expect{grid=[[
      {1:bar                                                         }|
      ^                                                            |
      {3:~         }{8:                              }{3:                    }|
      {3:~         }{9:~                             }{3:                    }|
      {3:~         }{9:~                             }{3:                    }|
      {3:~         }{9:~                             }{3:                    }|
      {3:~         }{9:~                             }{3:                    }|
      {3:~         }{9:~                             }{3:                    }|
      {3:~         }{9:~                             }{3:                    }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
                                                                  |
    ]]}
    meths.set_option_value('winbar', 'floaty bar', { scope = 'local', win = win.id })
    screen:expect{grid=[[
      {1:bar                                                         }|
      ^                                                            |
      {3:~         }{1:floaty bar                    }{3:                    }|
      {3:~         }{8:                              }{3:                    }|
      {3:~         }{9:~                             }{3:                    }|
      {3:~         }{9:~                             }{3:                    }|
      {3:~         }{9:~                             }{3:                    }|
      {3:~         }{9:~                             }{3:                    }|
      {3:~         }{9:~                             }{3:                    }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
                                                                  |
    ]]}
  end)

  it('works correctly when moving a split', function()
    screen:try_resize(45, 6)
    command('set winbar=')
    command('vsplit')
    command('setlocal winbar=foo')
    screen:expect([[
      {1:foo                   }│                      |
      ^                      │{3:~                     }|
      {3:~                     }│{3:~                     }|
      {3:~                     }│{3:~                     }|
      {4:[No Name]              }{2:[No Name]             }|
                                                   |
    ]])

    command('wincmd L')
    screen:expect([[
                            │{1:foo                   }|
      {3:~                     }│^                      |
      {3:~                     }│{3:~                     }|
      {3:~                     }│{3:~                     }|
      {2:[No Name]              }{4:[No Name]             }|
                                                   |
    ]])

    command('wincmd w')
    command('wincmd L')
    screen:expect([[
      {1:foo                   }│^                      |
                            │{3:~                     }|
      {3:~                     }│{3:~                     }|
      {3:~                     }│{3:~                     }|
      {2:[No Name]              }{4:[No Name]             }|
                                                   |
    ]])
  end)

  it('properly resizes window when there is no space in it', function()
    command('set winbar= | 1split')
    screen:expect([[
      ^                                                            |
      {4:[No Name]                                                   }|
                                                                  |
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {2:[No Name]                                                   }|
                                                                  |
    ]])
    command('set winbar=a')
    screen:expect([[
      {1:a                                                           }|
      ^                                                            |
      {4:[No Name]                                                   }|
      {1:a                                                           }|
                                                                  |
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {2:[No Name]                                                   }|
                                                                  |
    ]])
  end)

  it('cannot be added unless there is room', function()
    command('set winbar= | split | split | split | split | split')
    screen:expect([[
      ^                                                            |
      {4:[No Name]                                                   }|
                                                                  |
      {2:[No Name]                                                   }|
                                                                  |
      {2:[No Name]                                                   }|
                                                                  |
      {2:[No Name]                                                   }|
                                                                  |
      {2:[No Name]                                                   }|
                                                                  |
      {2:[No Name]                                                   }|
                                                                  |
    ]])
    eq('Vim(set):E36: Not enough room', pcall_err(command, 'set winbar=test'))
  end)
end)

describe('local winbar with tabs', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(60, 10)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = {bold = true},
      [2] = {reverse = true},
      [3] = {bold = true, foreground = Screen.colors.Blue},
      [4] = {underline = true, background = Screen.colors.LightGray}
    })
    meths.set_option_value('winbar', 'foo', { scope = 'local', win = 0 })
  end)

  it('works', function()
    command('tabnew')
    screen:expect([[
      {4: [No Name] }{1: [No Name] }{2:                                     }{4:X}|
      ^                                                            |
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
                                                                  |
    ]])
    command('tabnext')
    screen:expect{grid=[[
      {1: [No Name] }{4: [No Name] }{2:                                     }{4:X}|
      {1:foo                                                         }|
      ^                                                            |
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
                                                                  |
    ]]}
  end)

  it('can edit new empty buffer #19458', function()
    insert [[
      some
      goofy
      text]]
    screen:expect{grid=[[
      {1:foo                                                         }|
      some                                                        |
      goofy                                                       |
      tex^t                                                        |
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
                                                                  |
    ]]}

    -- this used to throw an E315 ml_get error
    command 'tabedit'
    screen:expect{grid=[[
      {4: + [No Name] }{1: [No Name] }{2:                                   }{4:X}|
      ^                                                            |
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
                                                                  |
    ]]}

    command 'tabprev'
    screen:expect{grid=[[
      {1: + [No Name] }{4: [No Name] }{2:                                   }{4:X}|
      {1:foo                                                         }|
      some                                                        |
      goofy                                                       |
      tex^t                                                        |
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
      {3:~                                                           }|
                                                                  |
    ]]}
  end)
end)

it('winbar works properly when redrawing is postponed #23534', function()
  clear({args = {
    '-c', 'set laststatus=2 lazyredraw',
    '-c', 'setlocal statusline=(statusline) winbar=(winbar)',
    '-c', 'call nvim_input(":<Esc>")',
  }})
  local screen = Screen.new(60, 6)
  screen:attach()
  screen:set_default_attr_ids({
    [0] = {foreground = Screen.colors.Blue, bold = true},
    [1] = {bold = true},
    [2] = {bold = true, reverse = true},
  })
  screen:expect([[
    {1:(winbar)                                                    }|
    ^                                                            |
    {0:~                                                           }|
    {0:~                                                           }|
    {2:(statusline)                                                }|
                                                                |
  ]])
end)
