local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed = helpers.clear, helpers.feed
local source = helpers.source

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
      [5] = {bold = true, foreground = Screen.colors.SeaGreen}
    })
  end)

  it('works', function()
    source([[
      function! TestComplete() abort
        call complete(1, ['foo', 'bar', 'spam'])
        return ''
      endfunction
    ]])
    local expected = {
      {'foo', '', '', ''},
      {'bar', '', '', ''},
      {'spam', '', '', ''},
    }
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

  it('positions corectly', function()
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
end)
