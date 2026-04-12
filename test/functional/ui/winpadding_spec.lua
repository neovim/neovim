local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')
local command, clear = n.command, n.clear
local pcall_err, eq = t.pcall_err, t.eq
local api = n.api

describe('"winpadding" option', function()
  local screen ---@type test.functional.ui.screen

  before_each(function()
    clear()
    screen = Screen.new()
    screen:add_extra_attr_ids({
      [101] = { background = Screen.colors.Blue1 },
    })
    command('hi WinPadding guibg=red ctermbg=1')
    command('hi WinPaddingNC guibg=blue ctermbg=4')
  end)

  it('works', function()
    command('set winpadding=2,2,2,2')
    screen:expect([[
      {30:                                                     }|*2
      {30:  }^                                                 {30:  }|
      {30:  }{1:~                                                }{30:  }|*8
      {30:                                                     }|*2
                                                           |
    ]])
    command('set winpadding&')
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|*12
                                                           |
    ]])
    command('set winpadding=1,0,1,2')
    screen:expect([[
      {30:                                                     }|
      {30:  }^                                                   |
      {30:  }{1:~                                                  }|*10
      {30:                                                     }|
                                                           |
    ]])
    command('vsplit foo | set winpadding=2,2,2,2')
    screen:expect([[
      {30:                          }│{101:                          }|
      {30:                          }│{101:  }                        |
      {30:  }^                      {30:  }│{101:  }{1:~                       }|
      {30:  }{1:~                     }{30:  }│{101:  }{1:~                       }|*7
      {30:                          }│{101:  }{1:~                       }|
      {30:                          }│{101:                          }|
      {3:foo                        }{2:[No Name]                 }|
                                                           |
    ]])
    command('wincmd w')
    screen:expect([[
      {101:                          }│{30:                          }|
      {101:                          }│{30:  }^                        |
      {101:  }                      {101:  }│{30:  }{1:~                       }|
      {101:  }{1:~                     }{101:  }│{30:  }{1:~                       }|*7
      {101:                          }│{30:  }{1:~                       }|
      {101:                          }│{30:                          }|
      {2:foo                        }{3:[No Name]                 }|
                                                           |
    ]])
  end)

  it('works on floating window', function()
    local buf = api.nvim_create_buf(false, false)
    api.nvim_open_win(
      buf,
      true,
      { relative = 'editor', row = 2, col = 2, height = 5, width = 5, border = 'single' }
    )
    command('set winpadding=2,2,2,2')
    screen:expect([[
                                                           |
      {1:~                                                    }|
      {1:~ }┌─────┐{1:                                            }|
      {1:~ }│{30:     }│{1:                                            }|*2
      {1:~ }│{30:  }{4:^ }{30:  }│{1:                                            }|
      {1:~ }│{30:     }│{1:                                            }|*2
      {1:~ }└─────┘{1:                                            }|
      {1:~                                                    }|*4
                                                           |
    ]])
    command('set winpadding&')
    screen:expect([[
                                                           |
      {1:~                                                    }|
      {1:~ }┌─────┐{1:                                            }|
      {1:~ }│{4:^     }│{1:                                            }|
      {1:~ }│{11:~    }│{1:                                            }|*4
      {1:~ }└─────┘{1:                                            }|
      {1:~                                                    }|*4
                                                           |
    ]])
  end)

  it('wraps lines inside winpadding and truncates with nowrap', function()
    screen:try_resize(12, 10)
    local s = {} --- @type table<integer, string>
    for i = 1, 15 do
      s[#s + 1] = string.format('%X', i)
    end
    api.nvim_buf_set_lines(0, 0, -1, false, { table.concat(s, '') })
    command('set winpadding=1,1,1,1')
    screen:expect([[
      {30:            }|
      {30: }^123456789A{30: }|
      {30: }BCDEF     {30: }|
      {30: }{1:~         }{30: }|*5
      {30:            }|
                  |
    ]])
    command('set nowrap')
    screen:expect([[
      {30:            }|
      {30: }^123456789A{30: }|
      {30: }{1:~         }{30: }|*6
      {30:            }|
                  |
    ]])
  end)

  it('works with winbar and statusline', function()
    screen:try_resize(50, 10)
    api.nvim_buf_set_lines(0, 0, -1, false, { 'one', 'two', 'three', 'four', 'five' })
    command('hi WinPadding guibg=red ctermbg=1 | set winbar=%F | set winpadding=2,2,2,2')
    screen:expect([[
      {5:[No Name]                                         }|
      {30:                                                  }|*2
      {30:  }^one                                           {30:  }|
      {30:  }two                                           {30:  }|
      {30:  }three                                         {30:  }|
      {30:  }four                                          {30:  }|
      {30:                                                  }|*2
                                                        |
    ]])
    command('set laststatus=2')
    screen:expect([[
      {5:[No Name]                                         }|
      {30:                                                  }|*2
      {30:  }^one                                           {30:  }|
      {30:  }two                                           {30:  }|
      {30:  }three                                         {30:  }|
      {30:                                                  }|*2
      {3:[No Name] [+]                                     }|
                                                        |
    ]])

    command('set winbar&')
    screen:expect([[
      {30:                                                  }|*2
      {30:  }^one                                           {30:  }|
      {30:  }two                                           {30:  }|
      {30:  }three                                         {30:  }|
      {30:  }four                                          {30:  }|
      {30:                                                  }|*2
      {3:[No Name] [+]                                     }|
                                                        |
    ]])

    command('set laststatus=0')
    screen:expect([[
      {30:                                                  }|*2
      {30:  }^one                                           {30:  }|
      {30:  }two                                           {30:  }|
      {30:  }three                                         {30:  }|
      {30:  }four                                          {30:  }|
      {30:  }five                                          {30:  }|
      {30:                                                  }|*2
                                                        |
    ]])
  end)

  it('invalid winpadding format', function()
    eq('Vim(set):E474: Invalid argument: winpadding=1', pcall_err(command, 'set winpadding=1'))
    eq('Vim(set):E474: Invalid argument: winpadding=1,2', pcall_err(command, 'set winpadding=1,2'))
    eq(
      'Vim(set):E474: Invalid argument: winpadding=1,3,3',
      pcall_err(command, 'set winpadding=1,3,3')
    )
    eq(
      'Vim(set):E474: Invalid argument: winpadding=1,a,3,4',
      pcall_err(command, 'set winpadding=1,a,3,4')
    )
  end)
end)
