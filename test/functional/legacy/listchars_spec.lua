-- Tests for 'listchars' display with 'list' and :list.

local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local feed, insert, exec = helpers.feed, helpers.insert, helpers.exec
local clear, feed_command, expect = helpers.clear, helpers.feed_command, helpers.expect

-- luacheck: ignore 621 (Indentation)
describe("'listchars'", function()
  before_each(function()
    clear()
    feed_command('set listchars=eol:$')
  end)

  -- luacheck: ignore 613 (Trailing whitespace in a string)
  it("works with 'list'", function()
    exec([[
      function GetScreenCharsForLine(lnum)
        return join(map(range(1, virtcol('$')), 'nr2char(screenchar(a:lnum, v:val))'), '')
      endfunction
      nnoremap <expr> GG ":call add(g:lines, GetScreenCharsForLine(".screenrow()."))\<CR>"
    ]])

    insert([[
      start:
      	aa	
        bb	  
         cccc	 
      dd        ee  	
       ]])

    feed_command('let g:lines = []')

    -- Set up 'listchars', switch on 'list', and use the "GG" mapping to record
    -- what the buffer lines look like.
    feed_command('set listchars+=tab:>-,space:.,trail:<')
    feed_command('set list')
    feed_command('/^start:/')
    feed_command('normal! jzt')
    feed('GG<cr>')
    feed('GG<cr>')
    feed('GG<cr>')
    feed('GG<cr>')
    feed('GGH')

    -- Repeat without displaying "trail" spaces.
    feed_command('set listchars-=trail:<')
    feed('GG<cr>')
    feed('GG<cr>')
    feed('GG<cr>')
    feed('GG<cr>')
    feed('GG')

    -- Delete the buffer contents and :put the collected lines.
    feed_command('%d')
    feed_command('put =g:lines', '1d')

    -- Assert buffer contents.
    expect([[
      >-------aa>-----$
      ..bb>---<<$
      ...cccc><$
      dd........ee<<>-$
      <$
      >-------aa>-----$
      ..bb>---..$
      ...cccc>.$
      dd........ee..>-$
      .$]])
  end)

  it('works with :list', function()
    insert([[
      start:
        fff	  
      	gg	
           h	
      iii    	  ]])

    -- Set up 'listchars', switch 'list' *off* (:list must show the 'listchars'
    -- even when 'list' is off), then run :list and collect the output.
    feed_command('set listchars+=tab:>-,space:.,trail:<')
    feed_command('set nolist')
    feed_command('/^start:/')
    feed_command('redir! => g:lines')
    feed_command('+1,$list')
    feed_command('redir END')

    -- Delete the buffer contents and :put the collected lines.
    feed_command('%d')
    feed_command('put =g:lines', '1d')

    -- Assert buffer contents.
    expect([[


      ..fff>--<<$
      >-------gg>-----$
      .....h>-$
      iii<<<<><<$]])
  end)

  it('"exceeds" character does not appear in foldcolumn vim-patch:8.2.3121', function()
    local screen = Screen.new(60, 10)
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue},  -- NonText
      [2] = {bold = true, reverse = true},  -- StatusLine
      [3] = {reverse = true},  -- StatusLineNC
      [4] = {background = Screen.colors.Grey, foreground = Screen.colors.DarkBlue},  -- FoldColumn, SignColumn
    })
    screen:attach()
    exec([[
      call setline(1, ['aaa', '', 'a', 'aaaaaa'])
      vsplit
      vsplit
      windo set signcolumn=yes foldcolumn=1 winminwidth=0 nowrap list listchars=extends:>,precedes:<
    ]])
    feed('13<C-W>>')
    screen:expect([[
      {4:   }aaa              │{4:   }a{1:>}│{4:   }^aaa                           |
      {4:   }                 │{4:   }  │{4:   }                              |
      {4:   }a                │{4:   }a │{4:   }a                             |
      {4:   }aaaaaa           │{4:   }a{1:>}│{4:   }aaaaaa                        |
      {1:~                   }│{1:~    }│{1:~                                }|
      {1:~                   }│{1:~    }│{1:~                                }|
      {1:~                   }│{1:~    }│{1:~                                }|
      {1:~                   }│{1:~    }│{1:~                                }|
      {3:[No Name] [+]        <[+]  }{2:[No Name] [+]                    }|
                                                                  |
    ]])
    feed('<C-W>>')
    screen:expect([[
      {4:   }aaa              │{4:   }{1:>}│{4:   }^aaa                            |
      {4:   }                 │{4:   } │{4:   }                               |
      {4:   }a                │{4:   }a│{4:   }a                              |
      {4:   }aaaaaa           │{4:   }{1:>}│{4:   }aaaaaa                         |
      {1:~                   }│{1:~   }│{1:~                                 }|
      {1:~                   }│{1:~   }│{1:~                                 }|
      {1:~                   }│{1:~   }│{1:~                                 }|
      {1:~                   }│{1:~   }│{1:~                                 }|
      {3:[No Name] [+]        <+]  }{2:[No Name] [+]                     }|
                                                                  |
    ]])
    feed('<C-W>>')
    screen:expect([[
      {4:   }aaa              │{4:   }│{4:   }^aaa                             |
      {4:   }                 │{4:   }│{4:   }                                |
      {4:   }a                │{4:   }│{4:   }a                               |
      {4:   }aaaaaa           │{4:   }│{4:   }aaaaaa                          |
      {1:~                   }│{1:~  }│{1:~                                  }|
      {1:~                   }│{1:~  }│{1:~                                  }|
      {1:~                   }│{1:~  }│{1:~                                  }|
      {1:~                   }│{1:~  }│{1:~                                  }|
      {3:[No Name] [+]        <]  }{2:[No Name] [+]                      }|
                                                                  |
    ]])
    feed('<C-W>>')
    screen:expect([[
      {4:   }aaa              │{4:  }│{4:   }^aaa                              |
      {4:   }                 │{4:  }│{4:   }                                 |
      {4:   }a                │{4:  }│{4:   }a                                |
      {4:   }aaaaaa           │{4:  }│{4:   }aaaaaa                           |
      {1:~                   }│{1:~ }│{1:~                                   }|
      {1:~                   }│{1:~ }│{1:~                                   }|
      {1:~                   }│{1:~ }│{1:~                                   }|
      {1:~                   }│{1:~ }│{1:~                                   }|
      {3:[No Name] [+]        <  }{2:[No Name] [+]                       }|
                                                                  |
    ]])
    feed('<C-W>>')
    screen:expect([[
      {4:   }aaa              │{4: }│{4:   }^aaa                               |
      {4:   }                 │{4: }│{4:   }                                  |
      {4:   }a                │{4: }│{4:   }a                                 |
      {4:   }aaaaaa           │{4: }│{4:   }aaaaaa                            |
      {1:~                   }│{1:~}│{1:~                                    }|
      {1:~                   }│{1:~}│{1:~                                    }|
      {1:~                   }│{1:~}│{1:~                                    }|
      {1:~                   }│{1:~}│{1:~                                    }|
      {3:[No Name] [+]        < }{2:[No Name] [+]                        }|
                                                                  |
    ]])
    feed('<C-W>h')
    feed_command('set nowrap foldcolumn=4')
    screen:expect([[
      {4:   }aaa              │{4:      }^aaa           │{4:   }aaa            |
      {4:   }                 │{4:      }              │{4:   }               |
      {4:   }a                │{4:      }a             │{4:   }a              |
      {4:   }aaaaaa           │{4:      }aaaaaa        │{4:   }aaaaaa         |
      {1:~                   }│{1:~                   }│{1:~                 }|
      {1:~                   }│{1:~                   }│{1:~                 }|
      {1:~                   }│{1:~                   }│{1:~                 }|
      {1:~                   }│{1:~                   }│{1:~                 }|
      {3:[No Name] [+]        }{2:[No Name] [+]        }{3:[No Name] [+]     }|
      :set nowrap foldcolumn=4                                    |
    ]])
    feed('15<C-W><lt>')
    screen:expect([[
      {4:   }aaa              │{4:     }│{4:   }aaa                           |
      {4:   }                 │{4:     }│{4:   }                              |
      {4:   }a                │{4:     }│{4:   }a                             |
      {4:   }aaaaaa           │{4:    ^ }│{4:   }aaaaaa                        |
      {1:~                   }│{1:~    }│{1:~                                }|
      {1:~                   }│{1:~    }│{1:~                                }|
      {1:~                   }│{1:~    }│{1:~                                }|
      {1:~                   }│{1:~    }│{1:~                                }|
      {3:[No Name] [+]        }{2:<[+]  }{3:[No Name] [+]                    }|
      :set nowrap foldcolumn=4                                    |
    ]])
    feed('4<C-W><lt>')
    screen:expect([[
      {4:   }aaa              │{4: }│{4:   }aaa                               |
      {4:   }                 │{4: }│{4:   }                                  |
      {4:   }a                │{4: }│{4:   }a                                 |
      {4:   }aaaaaa           │{4:^ }│{4:   }aaaaaa                            |
      {1:~                   }│{1:~}│{1:~                                    }|
      {1:~                   }│{1:~}│{1:~                                    }|
      {1:~                   }│{1:~}│{1:~                                    }|
      {1:~                   }│{1:~}│{1:~                                    }|
      {3:[No Name] [+]        }{2:< }{3:[No Name] [+]                        }|
      :set nowrap foldcolumn=4                                    |
    ]])
  end)
end)
