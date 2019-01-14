local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed = helpers.clear, helpers.feed
local source = helpers.source
local insert = helpers.insert
local meths = helpers.meths
local command = helpers.command

describe('ui/ext_popupmenu', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(60, 8)
    screen:attach({rgb=true, ext_popupmenu=true})
    screen:set_default_attr_ids({
      [1] = {bold=true, foreground=Screen.colors.Blue},
      [2] = {bold = true},
      [3] = {reverse = true},
      [4] = {bold = true, reverse = true},
      [5] = {bold = true, foreground = Screen.colors.SeaGreen},
      [6] = {background = Screen.colors.WebGray},
      [7] = {background = Screen.colors.LightMagenta},
    })
    source([[
      function! TestComplete() abort
        call complete(1, [{'word':'foo', 'abbr':'fo', 'menu':'the foo', 'info':'foo-y', 'kind':'x'}, 'bar', 'spam'])
        return ''
      endfunction
    ]])
  end)

  local expected = {
    {'fo', 'x', 'the foo', 'foo-y'},
    {'bar', '', '', ''},
    {'spam', '', '', ''},
  }

  it('works', function()
    feed('o<C-r>=TestComplete()<CR>')
    screen:expect{grid=[[
                                                                  |
      foo^                                                         |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:-- INSERT --}                                                |
    ]], popupmenu={
      items=expected,
      pos=0,
      anchor={1,0},
    }}

    feed('<c-p>')
    screen:expect{grid=[[
                                                                  |
      ^                                                            |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:-- INSERT --}                                                |
    ]], popupmenu={
      items=expected,
      pos=-1,
      anchor={1,0},
    }}

    -- down moves the selection in the menu, but does not insert anything
    feed('<down><down>')
    screen:expect{grid=[[
                                                                  |
      ^                                                            |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:-- INSERT --}                                                |
    ]], popupmenu={
      items=expected,
      pos=1,
      anchor={1,0},
    }}

    feed('<cr>')
    screen:expect{grid=[[
                                                                  |
      bar^                                                         |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:-- INSERT --}                                                |
    ]]}
  end)

  it('can be controlled by API', function()
    feed('o<C-r>=TestComplete()<CR>')
    screen:expect{grid=[[
                                                                  |
      foo^                                                         |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:-- INSERT --}                                                |
    ]], popupmenu={
      items=expected,
      pos=0,
      anchor={1,0},
    }}

    meths.select_popupmenu_item(1,false,false,{})
    screen:expect{grid=[[
                                                                  |
      foo^                                                         |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:-- INSERT --}                                                |
    ]], popupmenu={
      items=expected,
      pos=1,
      anchor={1,0},
    }}

    meths.select_popupmenu_item(2,true,false,{})
    screen:expect{grid=[[
                                                                  |
      spam^                                                        |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:-- INSERT --}                                                |
    ]], popupmenu={
      items=expected,
      pos=2,
      anchor={1,0},
    }}

    meths.select_popupmenu_item(0,true,true,{})
    screen:expect([[
                                                                  |
      foo^                                                         |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:-- INSERT --}                                                |
    ]])


    feed('<c-w><C-r>=TestComplete()<CR>')
    screen:expect{grid=[[
                                                                  |
      foo^                                                         |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:-- INSERT --}                                                |
    ]], popupmenu={
      items=expected,
      pos=0,
      anchor={1,0},
    }}

    meths.select_popupmenu_item(-1,false,false,{})
    screen:expect{grid=[[
                                                                  |
      foo^                                                         |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:-- INSERT --}                                                |
    ]], popupmenu={
      items=expected,
      pos=-1,
      anchor={1,0},
    }}

    meths.select_popupmenu_item(1,true,false,{})
    screen:expect{grid=[[
                                                                  |
      bar^                                                         |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:-- INSERT --}                                                |
    ]], popupmenu={
      items=expected,
      pos=1,
      anchor={1,0},
    }}

    meths.select_popupmenu_item(-1,true,false,{})
    screen:expect{grid=[[
                                                                  |
      ^                                                            |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:-- INSERT --}                                                |
    ]], popupmenu={
      items=expected,
      pos=-1,
      anchor={1,0},
    }}

    meths.select_popupmenu_item(0,true,false,{})
    screen:expect{grid=[[
                                                                  |
      foo^                                                         |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:-- INSERT --}                                                |
    ]], popupmenu={
      items=expected,
      pos=0,
      anchor={1,0},
    }}

    meths.select_popupmenu_item(-1,true,true,{})
    screen:expect([[
                                                                  |
      ^                                                            |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:-- INSERT --}                                                |
    ]])

    command('imap <f1> <cmd>call nvim_select_popupmenu_item(2,v:true,v:false,{})<cr>')
    command('imap <f2> <cmd>call nvim_select_popupmenu_item(-1,v:false,v:false,{})<cr>')
    command('imap <f3> <cmd>call nvim_select_popupmenu_item(1,v:false,v:true,{})<cr>')
    feed('<C-r>=TestComplete()<CR>')
    screen:expect{grid=[[
                                                                  |
      foo^                                                         |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:-- INSERT --}                                                |
    ]], popupmenu={
      items=expected,
      pos=0,
      anchor={1,0},
    }}

    feed('<f1>')
    screen:expect{grid=[[
                                                                  |
      spam^                                                        |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:-- INSERT --}                                                |
    ]], popupmenu={
      items=expected,
      pos=2,
      anchor={1,0},
    }}

    feed('<f2>')
    screen:expect{grid=[[
                                                                  |
      spam^                                                        |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:-- INSERT --}                                                |
    ]], popupmenu={
      items=expected,
      pos=-1,
      anchor={1,0},
    }}

    feed('<f3>')
    screen:expect([[
                                                                  |
      bar^                                                         |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:-- INSERT --}                                                |
    ]])

    -- also should work for builtin popupmenu
    screen:set_option('ext_popupmenu', false)
    feed('<C-r>=TestComplete()<CR>')
    screen:expect([[
                                                                  |
      foo^                                                         |
      {6:fo   x the foo }{1:                                             }|
      {7:bar            }{1:                                             }|
      {7:spam           }{1:                                             }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:-- INSERT --}                                                |
    ]])

    feed('<f1>')
    screen:expect([[
                                                                  |
      spam^                                                        |
      {7:fo   x the foo }{1:                                             }|
      {7:bar            }{1:                                             }|
      {6:spam           }{1:                                             }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:-- INSERT --}                                                |
    ]])

    feed('<f2>')
    screen:expect([[
                                                                  |
      spam^                                                        |
      {7:fo   x the foo }{1:                                             }|
      {7:bar            }{1:                                             }|
      {7:spam           }{1:                                             }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:-- INSERT --}                                                |
    ]])

    feed('<f3>')
    screen:expect([[
                                                                  |
      bar^                                                         |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:-- INSERT --}                                                |
    ]])
  end)
end)


describe('popup placement', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(32, 20)
    screen:attach()
    screen:set_default_attr_ids({
      -- popup selected item / scrollbar track
      ['s'] = {background = Screen.colors.WebGray},
      -- popup non-selected item
      ['n'] = {background = Screen.colors.LightMagenta},
      -- popup scrollbar knob
      ['c'] = {background = Screen.colors.Grey0},
      [1] = {bold = true, foreground = Screen.colors.Blue},
      [2] = {bold = true},
      [3] = {reverse = true},
      [4] = {bold = true, reverse = true},
      [5] = {bold = true, foreground = Screen.colors.SeaGreen}
    })
  end)

  it('works with preview-window above', function()
    feed(':ped<CR><c-w>4+')
    feed('iaa bb cc dd ee ff gg hh ii jj<cr>')
    feed('<c-x><c-n>')
    screen:expect([[
      aa bb cc dd ee ff gg hh ii jj   |
      aa                              |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {3:[No Name] [Preview][+]          }|
      aa bb cc dd ee ff gg hh ii jj   |
      aa^                              |
      {s:aa             }{c: }{1:                }|
      {n:bb             }{c: }{1:                }|
      {n:cc             }{c: }{1:                }|
      {n:dd             }{c: }{1:                }|
      {n:ee             }{c: }{1:                }|
      {n:ff             }{c: }{1:                }|
      {n:gg             }{s: }{1:                }|
      {n:hh             }{s: }{4:                }|
      {2:-- }{5:match 1 of 10}                |
    ]])
  end)

  it('works with preview-window below', function()
    feed(':ped<CR><c-w>4+<c-w>r')
    feed('iaa bb cc dd ee ff gg hh ii jj<cr>')
    feed('<c-x><c-n>')
    screen:expect([[
      aa bb cc dd ee ff gg hh ii jj   |
      aa^                              |
      {s:aa             }{c: }{1:                }|
      {n:bb             }{c: }{1:                }|
      {n:cc             }{c: }{1:                }|
      {n:dd             }{c: }{1:                }|
      {n:ee             }{c: }{1:                }|
      {n:ff             }{c: }{1:                }|
      {n:gg             }{s: }{1:                }|
      {n:hh             }{s: }{4:                }|
      aa bb cc dd ee ff gg hh ii jj   |
      aa                              |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {3:[No Name] [Preview][+]          }|
      {2:-- }{5:match 1 of 10}                |
      ]])
  end)

  it('works with preview-window above and tall and inverted', function()
    feed(':ped<CR><c-w>8+')
    feed('iaa<cr>bb<cr>cc<cr>dd<cr>ee<cr>')
    feed('ff<cr>gg<cr>hh<cr>ii<cr>jj<cr>')
    feed('kk<cr>ll<cr>mm<cr>nn<cr>oo<cr>')
    feed('<c-x><c-n>')
    screen:expect([[
      aa                              |
      bb                              |
      cc                              |
      dd                              |
      {s:aa             }{c: }{3:ew][+]          }|
      {n:bb             }{c: }                |
      {n:cc             }{c: }                |
      {n:dd             }{c: }                |
      {n:ee             }{c: }                |
      {n:ff             }{c: }                |
      {n:gg             }{c: }                |
      {n:hh             }{c: }                |
      {n:ii             }{c: }                |
      {n:jj             }{c: }                |
      {n:kk             }{c: }                |
      {n:ll             }{s: }                |
      {n:mm             }{s: }                |
      aa^                              |
      {4:[No Name] [+]                   }|
      {2:-- }{5:match 1 of 15}                |
    ]])
  end)

  it('works with preview-window above and short and inverted', function()
    feed(':ped<CR><c-w>4+')
    feed('iaa<cr>bb<cr>cc<cr>dd<cr>ee<cr>')
    feed('ff<cr>gg<cr>hh<cr>ii<cr>jj<cr>')
    feed('<c-x><c-n>')
    screen:expect([[
      aa                              |
      bb                              |
      cc                              |
      dd                              |
      ee                              |
      ff                              |
      gg                              |
      {s:aa             }                 |
      {n:bb             }{3:iew][+]          }|
      {n:cc             }                 |
      {n:dd             }                 |
      {n:ee             }                 |
      {n:ff             }                 |
      {n:gg             }                 |
      {n:hh             }                 |
      {n:ii             }                 |
      {n:jj             }                 |
      aa^                              |
      {4:[No Name] [+]                   }|
      {2:-- }{5:match 1 of 10}                |
    ]])
  end)

  it('works with preview-window below and inverted', function()
    feed(':ped<CR><c-w>4+<c-w>r')
    feed('iaa<cr>bb<cr>cc<cr>dd<cr>ee<cr>')
    feed('ff<cr>gg<cr>hh<cr>ii<cr>jj<cr>')
    feed('<c-x><c-n>')
    screen:expect([[
      {s:aa             }{c: }                |
      {n:bb             }{c: }                |
      {n:cc             }{c: }                |
      {n:dd             }{c: }                |
      {n:ee             }{c: }                |
      {n:ff             }{c: }                |
      {n:gg             }{s: }                |
      {n:hh             }{s: }                |
      aa^                              |
      {4:[No Name] [+]                   }|
      aa                              |
      bb                              |
      cc                              |
      dd                              |
      ee                              |
      ff                              |
      gg                              |
      hh                              |
      {3:[No Name] [Preview][+]          }|
      {2:-- }{5:match 1 of 10}                |
    ]])
  end)

  it('works with vsplits', function()
    insert('aaa aab aac\n')
    feed(':vsplit<cr>')
    screen:expect([[
      aaa aab aac         {3:│}aaa aab aac|
      ^                    {3:│}           |
      {1:~                   }{3:│}{1:~          }|
      {1:~                   }{3:│}{1:~          }|
      {1:~                   }{3:│}{1:~          }|
      {1:~                   }{3:│}{1:~          }|
      {1:~                   }{3:│}{1:~          }|
      {1:~                   }{3:│}{1:~          }|
      {1:~                   }{3:│}{1:~          }|
      {1:~                   }{3:│}{1:~          }|
      {1:~                   }{3:│}{1:~          }|
      {1:~                   }{3:│}{1:~          }|
      {1:~                   }{3:│}{1:~          }|
      {1:~                   }{3:│}{1:~          }|
      {1:~                   }{3:│}{1:~          }|
      {1:~                   }{3:│}{1:~          }|
      {1:~                   }{3:│}{1:~          }|
      {1:~                   }{3:│}{1:~          }|
      {4:[No Name] [+]        }{3:<Name] [+] }|
      :vsplit                         |
    ]])

    feed('ibbb a<c-x><c-n>')
    screen:expect([[
      aaa aab aac         {3:│}aaa aab aac|
      bbb aaa^             {3:│}bbb aaa    |
      {1:~  }{s: aaa            }{1: }{3:│}{1:~          }|
      {1:~  }{n: aab            }{1: }{3:│}{1:~          }|
      {1:~  }{n: aac            }{1: }{3:│}{1:~          }|
      {1:~                   }{3:│}{1:~          }|
      {1:~                   }{3:│}{1:~          }|
      {1:~                   }{3:│}{1:~          }|
      {1:~                   }{3:│}{1:~          }|
      {1:~                   }{3:│}{1:~          }|
      {1:~                   }{3:│}{1:~          }|
      {1:~                   }{3:│}{1:~          }|
      {1:~                   }{3:│}{1:~          }|
      {1:~                   }{3:│}{1:~          }|
      {1:~                   }{3:│}{1:~          }|
      {1:~                   }{3:│}{1:~          }|
      {1:~                   }{3:│}{1:~          }|
      {1:~                   }{3:│}{1:~          }|
      {4:[No Name] [+]        }{3:<Name] [+] }|
      {2:-- }{5:match 1 of 3}                 |
    ]])

    feed('<esc><c-w><c-w>oc a<c-x><c-n>')
    screen:expect([[
      aaa aab aac{3:│}aaa aab aac         |
      bbb aaa    {3:│}bbb aaa             |
      c aaa      {3:│}c aaa^               |
      {1:~          }{3:│}{1:~}{s: aaa            }{1:   }|
      {1:~          }{3:│}{1:~}{n: aab            }{1:   }|
      {1:~          }{3:│}{1:~}{n: aac            }{1:   }|
      {1:~          }{3:│}{1:~                   }|
      {1:~          }{3:│}{1:~                   }|
      {1:~          }{3:│}{1:~                   }|
      {1:~          }{3:│}{1:~                   }|
      {1:~          }{3:│}{1:~                   }|
      {1:~          }{3:│}{1:~                   }|
      {1:~          }{3:│}{1:~                   }|
      {1:~          }{3:│}{1:~                   }|
      {1:~          }{3:│}{1:~                   }|
      {1:~          }{3:│}{1:~                   }|
      {1:~          }{3:│}{1:~                   }|
      {1:~          }{3:│}{1:~                   }|
      {3:<Name] [+]  }{4:[No Name] [+]       }|
      {2:-- }{5:match 1 of 3}                 |
    ]])
  end)
end)
