local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear, feed = helpers.clear, helpers.feed
local source = helpers.source
local insert = helpers.insert
local meths = helpers.meths
local command = helpers.command
local funcs = helpers.funcs
local get_pathsep = helpers.get_pathsep
local eq = helpers.eq
local matches = helpers.matches

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
      anchor={1,1,0},
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
      anchor={1,1,0},
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
      anchor={1,1,0},
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
      anchor={1,1,0},
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
      anchor={1,1,0},
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
      anchor={1,1,0},
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
      anchor={1,1,0},
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
      anchor={1,1,0},
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
      anchor={1,1,0},
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
      anchor={1,1,0},
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
      anchor={1,1,0},
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
      anchor={1,1,0},
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
      anchor={1,1,0},
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
      anchor={1,1,0},
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

  local function source_complete_month()
    source([[
    function! TestCompleteMonth() abort
    call complete(1, ['January', 'February', 'March', 'April',
    \ 'May', 'June', 'July', 'August',
    \ 'September', 'October', 'November', 'December'])
    return ''
    endfunction
    ]])
  end

  describe('pum_set_height', function()
    it('can be set pum height', function()
      source_complete_month()
      local month_expected = {
        {'January', '', '', ''},
        {'February', '', '', ''},
        {'March', '', '', ''},
        {'April', '', '', ''},
        {'May', '', '', ''},
        {'June', '', '', ''},
        {'July', '', '', ''},
        {'August', '', '', ''},
        {'September', '', '', ''},
        {'October', '', '', ''},
        {'November', '', '', ''},
        {'December', '', '', ''},
      }
      local pum_height = 6
      feed('o<C-r>=TestCompleteMonth()<CR>')
      meths.ui_pum_set_height(pum_height)
      feed('<PageDown>')
      -- pos becomes pum_height-2 because it is subtracting 2 to keep some
      -- context in ins_compl_key2count()
      screen:expect{grid=[[
                                                                  |
      January^                                                     |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:-- INSERT --}                                                |
      ]], popupmenu={
        items=month_expected,
        pos=pum_height-2,
        anchor={1,1,0},
      }}
    end)

    it('an error occurs if set 0 or less', function()
      local ok, err, _
      ok, _ = pcall(meths.ui_pum_set_height, 1)
      eq(ok, true)
      ok, err = pcall(meths.ui_pum_set_height, 0)
      eq(ok, false)
      matches('.*: Expected pum height > 0', err)
    end)

    it('an error occurs when ext_popupmenu is false', function()
      local ok, err, _
      ok, _ = pcall(meths.ui_pum_set_height, 1)
      eq(ok, true)
      screen:set_option('ext_popupmenu', false)
      ok, err = pcall(meths.ui_pum_set_height, 1)
      eq(ok, false)
      matches('.*: It must support the ext_popupmenu option', err)
    end)
  end)

  it('<PageUP>, <PageDown> works without ui_pum_set_height', function()
    source_complete_month()
    local month_expected = {
      {'January', '', '', ''},
      {'February', '', '', ''},
      {'March', '', '', ''},
      {'April', '', '', ''},
      {'May', '', '', ''},
      {'June', '', '', ''},
      {'July', '', '', ''},
      {'August', '', '', ''},
      {'September', '', '', ''},
      {'October', '', '', ''},
      {'November', '', '', ''},
      {'December', '', '', ''},
    }
    feed('o<C-r>=TestCompleteMonth()<CR>')
    feed('<PageDown>')
    screen:expect{grid=[[
                                                                |
    January^                                                     |
    {1:~                                                           }|
    {1:~                                                           }|
    {1:~                                                           }|
    {1:~                                                           }|
    {1:~                                                           }|
    {2:-- INSERT --}                                                |
    ]], popupmenu={
      items=month_expected,
      pos=3,
      anchor={1,1,0},
    }}
    feed('<PageUp>')
    screen:expect{grid=[[
                                                                |
    January^                                                     |
    {1:~                                                           }|
    {1:~                                                           }|
    {1:~                                                           }|
    {1:~                                                           }|
    {1:~                                                           }|
    {2:-- INSERT --}                                                |
    ]], popupmenu={
      items=month_expected,
      pos=0,
      anchor={1,1,0},
    }}
  end)

  it('works with wildoptions=pum', function()
    screen:try_resize(32,10)
    command('set wildmenu')
    command('set wildoptions=pum')

    local wild_expected = {
        {'define', '', '', ''},
        {'jump', '', '', ''},
        {'list', '', '', ''},
        {'place', '', '', ''},
        {'undefine', '', '', ''},
        {'unplace', '', '', ''},
    }

    feed(':sign ')
    screen:expect([[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      :sign ^                          |
    ]])
    eq(0, funcs.wildmenumode())

    feed('<tab>')
    screen:expect{grid=[[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      :sign define^                    |
    ]], popupmenu={items=wild_expected, pos=0, anchor={1, 9, 6}}}
    eq(1, funcs.wildmenumode())

    feed('<left>')
    screen:expect{grid=[[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      :sign ^                          |
    ]], popupmenu={items=wild_expected, pos=-1, anchor={1, 9, 6}}}

    feed('<left>')
    screen:expect{grid=[[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      :sign unplace^                   |
    ]], popupmenu={items=wild_expected, pos=5, anchor={1, 9, 6}}}

    feed('x')
    screen:expect([[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      :sign unplacex^                  |
    ]])
    feed('<esc>')

    -- #10042: make sure shift-tab also triggers the pum
    feed(':sign <S-tab>')
    screen:expect{grid=[[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      :sign unplace^                   |
    ]], popupmenu={items=wild_expected, pos=5, anchor={1, 9, 6}}}
    feed('<esc>')
    eq(0, funcs.wildmenumode())

    -- check positioning with multibyte char in pattern
    command("e långfile1")
    command("sp långfile2")
    feed(':b lå<tab>')
    screen:expect{grid=[[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {4:långfile2                       }|
                                      |
      {1:~                               }|
      {1:~                               }|
      {3:långfile1                       }|
      :b långfile1^                    |
    ]], popupmenu={
      anchor = {1, 9, 3},
      items = {{"långfile1", "", "", "" }, {"långfile2", "", "", ""}},
      pos = 0,
    }}

  end)
end)


describe('builtin popupmenu', function()
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
      [5] = {bold = true, foreground = Screen.colors.SeaGreen},
      [6] = {foreground = Screen.colors.Grey100, background = Screen.colors.Red},
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

  it('works with split and scroll', function()
    screen:try_resize(60,14)
    command("split")
    command("set completeopt+=noinsert")
    command("set mouse=a")
    insert([[
      Lorem ipsum dolor sit amet, consectetur
      adipisicing elit, sed do eiusmod tempor
      incididunt ut labore et dolore magna aliqua.
      Ut enim ad minim veniam, quis nostrud
      exercitation ullamco laboris nisi ut aliquip ex
      ea commodo consequat. Duis aute irure dolor in
      reprehenderit in voluptate velit esse cillum
      dolore eu fugiat nulla pariatur. Excepteur sint
      occaecat cupidatat non proident, sunt in culpa
      qui officia deserunt mollit anim id est
      laborum.
    ]])

    screen:expect([[
        reprehenderit in voluptate velit esse cillum              |
        dolore eu fugiat nulla pariatur. Excepteur sint           |
        occaecat cupidatat non proident, sunt in culpa            |
        qui officia deserunt mollit anim id est                   |
        laborum.                                                  |
      ^                                                            |
      {4:[No Name] [+]                                               }|
        Lorem ipsum dolor sit amet, consectetur                   |
        adipisicing elit, sed do eiusmod tempor                   |
        incididunt ut labore et dolore magna aliqua.              |
        Ut enim ad minim veniam, quis nostrud                     |
        exercitation ullamco laboris nisi ut aliquip ex           |
      {3:[No Name] [+]                                               }|
                                                                  |
    ]])

    feed('ggOEst <c-x><c-p>')
    screen:expect([[
      Est ^                                                        |
        L{n: sunt           }{s: }sit amet, consectetur                   |
        a{n: in             }{s: }sed do eiusmod tempor                   |
        i{n: culpa          }{s: }re et dolore magna aliqua.              |
        U{n: qui            }{s: }eniam, quis nostrud                     |
        e{n: officia        }{s: }co laboris nisi ut aliquip ex           |
      {4:[No}{n: deserunt       }{s: }{4:                                        }|
        L{n: mollit         }{s: }sit amet, consectetur                   |
        a{n: anim           }{s: }sed do eiusmod tempor                   |
        i{n: id             }{s: }re et dolore magna aliqua.              |
        U{n: est            }{s: }eniam, quis nostrud                     |
        e{n: laborum        }{c: }co laboris nisi ut aliquip ex           |
      {3:[No}{s: Est            }{c: }{3:                                        }|
      {2:-- Keyword Local completion (^N^P) }{5:match 1 of 65}            |
    ]])

    meths.input_mouse('wheel', 'down', '', 0, 9, 40)
    screen:expect([[
      Est ^                                                        |
        L{n: sunt           }{s: }sit amet, consectetur                   |
        a{n: in             }{s: }sed do eiusmod tempor                   |
        i{n: culpa          }{s: }re et dolore magna aliqua.              |
        U{n: qui            }{s: }eniam, quis nostrud                     |
        e{n: officia        }{s: }co laboris nisi ut aliquip ex           |
      {4:[No}{n: deserunt       }{s: }{4:                                        }|
        U{n: mollit         }{s: }eniam, quis nostrud                     |
        e{n: anim           }{s: }co laboris nisi ut aliquip ex           |
        e{n: id             }{s: }at. Duis aute irure dolor in            |
        r{n: est            }{s: }oluptate velit esse cillum              |
        d{n: laborum        }{c: }ulla pariatur. Excepteur sint           |
      {3:[No}{s: Est            }{c: }{3:                                        }|
      {2:-- Keyword Local completion (^N^P) }{5:match 1 of 65}            |
    ]])

    feed('e')
    screen:expect([[
      Est e^                                                       |
        L{n: elit           } sit amet, consectetur                   |
        a{n: eiusmod        } sed do eiusmod tempor                   |
        i{n: et             }ore et dolore magna aliqua.              |
        U{n: enim           }veniam, quis nostrud                     |
        e{n: exercitation   }mco laboris nisi ut aliquip ex           |
      {4:[No}{n: ex             }{4:                                         }|
        U{n: ea             }veniam, quis nostrud                     |
        e{n: esse           }mco laboris nisi ut aliquip ex           |
        e{n: eu             }uat. Duis aute irure dolor in            |
        r{s: est            }voluptate velit esse cillum              |
        dolore eu fugiat nulla pariatur. Excepteur sint           |
      {3:[No Name] [+]                                               }|
      {2:-- Keyword Local completion (^N^P) }{5:match 1 of 65}            |
    ]])

    meths.input_mouse('wheel', 'up', '', 0, 9, 40)
    screen:expect([[
      Est e^                                                       |
        L{n: elit           } sit amet, consectetur                   |
        a{n: eiusmod        } sed do eiusmod tempor                   |
        i{n: et             }ore et dolore magna aliqua.              |
        U{n: enim           }veniam, quis nostrud                     |
        e{n: exercitation   }mco laboris nisi ut aliquip ex           |
      {4:[No}{n: ex             }{4:                                         }|
        L{n: ea             } sit amet, consectetur                   |
        a{n: esse           } sed do eiusmod tempor                   |
        i{n: eu             }ore et dolore magna aliqua.              |
        U{s: est            }veniam, quis nostrud                     |
        exercitation ullamco laboris nisi ut aliquip ex           |
      {3:[No Name] [+]                                               }|
      {2:-- Keyword Local completion (^N^P) }{5:match 1 of 65}            |
    ]])

    feed('s')
    screen:expect([[
      Est es^                                                      |
        L{n: esse           } sit amet, consectetur                   |
        a{s: est            } sed do eiusmod tempor                   |
        incididunt ut labore et dolore magna aliqua.              |
        Ut enim ad minim veniam, quis nostrud                     |
        exercitation ullamco laboris nisi ut aliquip ex           |
      {4:[No Name] [+]                                               }|
        Lorem ipsum dolor sit amet, consectetur                   |
        adipisicing elit, sed do eiusmod tempor                   |
        incididunt ut labore et dolore magna aliqua.              |
        Ut enim ad minim veniam, quis nostrud                     |
        exercitation ullamco laboris nisi ut aliquip ex           |
      {3:[No Name] [+]                                               }|
      {2:-- Keyword Local completion (^N^P) }{5:match 1 of 65}            |
    ]])

    meths.input_mouse('wheel', 'down', '', 0, 9, 40)
    screen:expect([[
      Est es^                                                      |
        L{n: esse           } sit amet, consectetur                   |
        a{s: est            } sed do eiusmod tempor                   |
        incididunt ut labore et dolore magna aliqua.              |
        Ut enim ad minim veniam, quis nostrud                     |
        exercitation ullamco laboris nisi ut aliquip ex           |
      {4:[No Name] [+]                                               }|
        Ut enim ad minim veniam, quis nostrud                     |
        exercitation ullamco laboris nisi ut aliquip ex           |
        ea commodo consequat. Duis aute irure dolor in            |
        reprehenderit in voluptate velit esse cillum              |
        dolore eu fugiat nulla pariatur. Excepteur sint           |
      {3:[No Name] [+]                                               }|
      {2:-- Keyword Local completion (^N^P) }{5:match 1 of 65}            |
    ]])

    feed('<bs>')
    screen:expect([[
      Est e^                                                       |
        L{n: elit           } sit amet, consectetur                   |
        a{n: eiusmod        } sed do eiusmod tempor                   |
        i{n: et             }ore et dolore magna aliqua.              |
        U{n: enim           }veniam, quis nostrud                     |
        e{n: exercitation   }mco laboris nisi ut aliquip ex           |
      {4:[No}{n: ex             }{4:                                         }|
        U{n: ea             }veniam, quis nostrud                     |
        e{n: esse           }mco laboris nisi ut aliquip ex           |
        e{n: eu             }uat. Duis aute irure dolor in            |
        r{s: est            }voluptate velit esse cillum              |
        dolore eu fugiat nulla pariatur. Excepteur sint           |
      {3:[No Name] [+]                                               }|
      {2:-- Keyword Local completion (^N^P) }{5:match 1 of 65}            |
    ]])

    feed('<c-p>')
    screen:expect([[
      Est eu^                                                      |
        L{n: elit           } sit amet, consectetur                   |
        a{n: eiusmod        } sed do eiusmod tempor                   |
        i{n: et             }ore et dolore magna aliqua.              |
        U{n: enim           }veniam, quis nostrud                     |
        e{n: exercitation   }mco laboris nisi ut aliquip ex           |
      {4:[No}{n: ex             }{4:                                         }|
        U{n: ea             }veniam, quis nostrud                     |
        e{n: esse           }mco laboris nisi ut aliquip ex           |
        e{s: eu             }uat. Duis aute irure dolor in            |
        r{n: est            }voluptate velit esse cillum              |
        dolore eu fugiat nulla pariatur. Excepteur sint           |
      {3:[No Name] [+]                                               }|
      {2:-- Keyword Local completion (^N^P) }{5:match 22 of 65}           |
    ]])

    meths.input_mouse('wheel', 'down', '', 0, 9, 40)
    screen:expect([[
      Est eu^                                                      |
        L{n: elit           } sit amet, consectetur                   |
        a{n: eiusmod        } sed do eiusmod tempor                   |
        i{n: et             }ore et dolore magna aliqua.              |
        U{n: enim           }veniam, quis nostrud                     |
        e{n: exercitation   }mco laboris nisi ut aliquip ex           |
      {4:[No}{n: ex             }{4:                                         }|
        r{n: ea             }voluptate velit esse cillum              |
        d{n: esse           }nulla pariatur. Excepteur sint           |
        o{s: eu             }t non proident, sunt in culpa            |
        q{n: est            }unt mollit anim id est                   |
        laborum.                                                  |
      {3:[No Name] [+]                                               }|
      {2:-- Keyword Local completion (^N^P) }{5:match 22 of 65}           |
    ]])


    funcs.complete(4, {'ea', 'eeeeeeeeeeeeeeeeee', 'ei', 'eo', 'eu', 'ey', 'eå', 'eä', 'eö'})
    screen:expect([[
      Est eu^                                                      |
        {s: ea                 }t amet, consectetur                   |
        {n: eeeeeeeeeeeeeeeeee }d do eiusmod tempor                   |
        {n: ei                 } et dolore magna aliqua.              |
        {n: eo                 }iam, quis nostrud                     |
        {n: eu                 } laboris nisi ut aliquip ex           |
      {4:[N}{n: ey                 }{4:                                      }|
        {n: eå                 }uptate velit esse cillum              |
        {n: eä                 }la pariatur. Excepteur sint           |
        {n: eö                 }on proident, sunt in culpa            |
        qui officia deserunt mollit anim id est                   |
        laborum.                                                  |
      {3:[No Name] [+]                                               }|
      {2:-- Keyword Local completion (^N^P) }{5:match 1 of 9}             |
    ]])

    funcs.complete(4, {'ea', 'eee', 'ei', 'eo', 'eu', 'ey', 'eå', 'eä', 'eö'})
    screen:expect([[
      Est eu^                                                      |
        {s: ea             }r sit amet, consectetur                   |
        {n: eee            }, sed do eiusmod tempor                   |
        {n: ei             }bore et dolore magna aliqua.              |
        {n: eo             } veniam, quis nostrud                     |
        {n: eu             }amco laboris nisi ut aliquip ex           |
      {4:[N}{n: ey             }{4:                                          }|
        {n: eå             } voluptate velit esse cillum              |
        {n: eä             } nulla pariatur. Excepteur sint           |
        {n: eö             }at non proident, sunt in culpa            |
        qui officia deserunt mollit anim id est                   |
        laborum.                                                  |
      {3:[No Name] [+]                                               }|
      {2:-- INSERT --}                                                |
    ]])

    feed('<c-n>')
    screen:expect([[
      Esteee^                                                      |
        {n: ea             }r sit amet, consectetur                   |
        {s: eee            }, sed do eiusmod tempor                   |
        {n: ei             }bore et dolore magna aliqua.              |
        {n: eo             } veniam, quis nostrud                     |
        {n: eu             }amco laboris nisi ut aliquip ex           |
      {4:[N}{n: ey             }{4:                                          }|
        {n: eå             } voluptate velit esse cillum              |
        {n: eä             } nulla pariatur. Excepteur sint           |
        {n: eö             }at non proident, sunt in culpa            |
        qui officia deserunt mollit anim id est                   |
        laborum.                                                  |
      {3:[No Name] [+]                                               }|
      {2:-- INSERT --}                                                |
    ]])

    funcs.complete(6, {'foo', 'bar'})
    screen:expect([[
      Esteee^                                                      |
        Lo{s: foo            }sit amet, consectetur                   |
        ad{n: bar            }sed do eiusmod tempor                   |
        incididunt ut labore et dolore magna aliqua.              |
        Ut enim ad minim veniam, quis nostrud                     |
        exercitation ullamco laboris nisi ut aliquip ex           |
      {4:[No Name] [+]                                               }|
        reprehenderit in voluptate velit esse cillum              |
        dolore eu fugiat nulla pariatur. Excepteur sint           |
        occaecat cupidatat non proident, sunt in culpa            |
        qui officia deserunt mollit anim id est                   |
        laborum.                                                  |
      {3:[No Name] [+]                                               }|
      {2:-- INSERT --}                                                |
    ]])

    feed('<c-y>')
    screen:expect([[
      Esteefoo^                                                    |
        Lorem ipsum dolor sit amet, consectetur                   |
        adipisicing elit, sed do eiusmod tempor                   |
        incididunt ut labore et dolore magna aliqua.              |
        Ut enim ad minim veniam, quis nostrud                     |
        exercitation ullamco laboris nisi ut aliquip ex           |
      {4:[No Name] [+]                                               }|
        reprehenderit in voluptate velit esse cillum              |
        dolore eu fugiat nulla pariatur. Excepteur sint           |
        occaecat cupidatat non proident, sunt in culpa            |
        qui officia deserunt mollit anim id est                   |
        laborum.                                                  |
      {3:[No Name] [+]                                               }|
      {2:-- INSERT --}                                                |
    ]])
  end)

  it('can be moved due to wrap or resize', function()
    feed('isome long prefix before the ')
    command("set completeopt+=noinsert,noselect")
    command("set linebreak")
    funcs.complete(29, {'word', 'choice', 'text', 'thing'})
    screen:expect([[
      some long prefix before the ^    |
      {1:~                        }{n: word  }|
      {1:~                        }{n: choice}|
      {1:~                        }{n: text  }|
      {1:~                        }{n: thing }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {2:-- INSERT --}                    |
    ]])

    feed('<c-p>')
    screen:expect([[
      some long prefix before the     |
      thing^                           |
      {n:word           }{1:                 }|
      {n:choice         }{1:                 }|
      {n:text           }{1:                 }|
      {s:thing          }{1:                 }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {2:-- INSERT --}                    |
    ]])

    feed('<c-p>')
    screen:expect([[
      some long prefix before the text|
      {1:^~                        }{n: word  }|
      {1:~                        }{n: choice}|
      {1:~                        }{s: text  }|
      {1:~                        }{n: thing }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {2:-- INSERT --}                    |
    ]])

    screen:try_resize(30,8)
    screen:expect([[
      some long prefix before the   |
      text^                          |
      {n:word           }{1:               }|
      {n:choice         }{1:               }|
      {s:text           }{1:               }|
      {n:thing          }{1:               }|
      {1:~                             }|
      {2:-- INSERT --}                  |
    ]])

    screen:try_resize(50,8)
    screen:expect([[
      some long prefix before the text^                  |
      {1:~                          }{n: word           }{1:       }|
      {1:~                          }{n: choice         }{1:       }|
      {1:~                          }{s: text           }{1:       }|
      {1:~                          }{n: thing          }{1:       }|
      {1:~                                                 }|
      {1:~                                                 }|
      {2:-- INSERT --}                                      |
    ]])

    screen:try_resize(25,10)
    screen:expect([[
      some long prefix before  |
      the text^                 |
      {1:~  }{n: word           }{1:      }|
      {1:~  }{n: choice         }{1:      }|
      {1:~  }{s: text           }{1:      }|
      {1:~  }{n: thing          }{1:      }|
      {1:~                        }|
      {1:~                        }|
      {1:~                        }|
      {2:-- INSERT --}             |
    ]])

    screen:try_resize(12,5)
    screen:expect([[
      some long   |
      prefix      |
      bef{n: word  }  |
      tex{n: }^        |
      {2:-- INSERT -} |
    ]])

    -- can't draw the pum, but check we don't crash
    screen:try_resize(12,2)
    screen:expect([[
      text^        |
      {2:-- INSERT -} |
    ]])

    -- but state is preserved, pum reappears
    screen:try_resize(20,8)
    screen:expect([[
      some long prefix    |
      before the text^     |
      {1:~         }{n: word     }|
      {1:~         }{n: choice   }|
      {1:~         }{s: text     }|
      {1:~         }{n: thing    }|
      {1:~                   }|
      {2:-- INSERT --}        |
    ]])
  end)

  it('behaves correcty with VimResized autocmd', function()
    feed('isome long prefix before the ')
    command("set completeopt+=noinsert,noselect")
    command("autocmd VimResized * redraw!")
    command("set linebreak")
    funcs.complete(29, {'word', 'choice', 'text', 'thing'})
    screen:expect([[
      some long prefix before the ^    |
      {1:~                        }{n: word  }|
      {1:~                        }{n: choice}|
      {1:~                        }{n: text  }|
      {1:~                        }{n: thing }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {2:-- INSERT --}                    |
    ]])

    screen:try_resize(16,10)
    screen:expect([[
      some long       |
      prefix before   |
      the ^            |
      {1:~  }{n: word        }|
      {1:~  }{n: choice      }|
      {1:~  }{n: text        }|
      {1:~  }{n: thing       }|
      {1:~               }|
      {1:~               }|
      {2:-- INSERT --}    |
    ]])
  end)

  it('works with rightleft window', function()
    command("set rl")
    feed('isome rightleft ')
    screen:expect([[
                      ^  tfelthgir emos|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {2:-- INSERT --}                    |
    ]])

    command("set completeopt+=noinsert,noselect")
    funcs.complete(16, {'word', 'choice', 'text', 'thing'})
    screen:expect([[
                      ^  tfelthgir emos|
      {1:  }{n:           drow}{1:              ~}|
      {1:  }{n:         eciohc}{1:              ~}|
      {1:  }{n:           txet}{1:              ~}|
      {1:  }{n:          gniht}{1:              ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {2:-- INSERT --}                    |
    ]])

    feed('<c-n>')
    screen:expect([[
                  ^ drow tfelthgir emos|
      {1:  }{s:           drow}{1:              ~}|
      {1:  }{n:         eciohc}{1:              ~}|
      {1:  }{n:           txet}{1:              ~}|
      {1:  }{n:          gniht}{1:              ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {2:-- INSERT --}                    |
    ]])

    feed('<c-y>')
    screen:expect([[
                  ^ drow tfelthgir emos|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {1:                               ~}|
      {2:-- INSERT --}                    |
    ]])
  end)

  it('works with multiline messages', function()
    screen:try_resize(40,8)
    feed('ixx<cr>')
    command('imap <f2> <cmd>echoerr "very"\\|echoerr "much"\\|echoerr "error"<cr>')
    funcs.complete(1, {'word', 'choice', 'text', 'thing'})
    screen:expect([[
      xx                                      |
      word^                                    |
      {s:word           }{1:                         }|
      {n:choice         }{1:                         }|
      {n:text           }{1:                         }|
      {n:thing          }{1:                         }|
      {1:~                                       }|
      {2:-- INSERT --}                            |
    ]])

    feed('<f2>')
    screen:expect([[
      xx                                      |
      word                                    |
      {s:word           }{1:                         }|
      {4:                                        }|
      {6:very}                                    |
      {6:much}                                    |
      {6:error}                                   |
      {5:Press ENTER or type command to continue}^ |
    ]])

    feed('<cr>')
    screen:expect([[
      xx                                      |
      word^                                    |
      {s:word           }{1:                         }|
      {n:choice         }{1:                         }|
      {n:text           }{1:                         }|
      {n:thing          }{1:                         }|
      {1:~                                       }|
      {2:-- INSERT --}                            |
    ]])

    feed('<c-n>')
    screen:expect([[
      xx                                      |
      choice^                                  |
      {n:word           }{1:                         }|
      {s:choice         }{1:                         }|
      {n:text           }{1:                         }|
      {n:thing          }{1:                         }|
      {1:~                                       }|
      {2:-- INSERT --}                            |
    ]])

    command("split")
    screen:expect([[
      xx                                      |
      choice^                                  |
      {n:word           }{1:                         }|
      {s:choice         }{4:                         }|
      {n:text           }                         |
      {n:thing          }                         |
      {3:[No Name] [+]                           }|
      {2:-- INSERT --}                            |
    ]])

    meths.input_mouse('wheel', 'down', '', 0, 6, 15)
    screen:expect{grid=[[
      xx                                      |
      choice^                                  |
      {n:word           }{1:                         }|
      {s:choice         }{4:                         }|
      {n:text           }                         |
      {n:thing          }{1:                         }|
      {3:[No Name] [+]                           }|
      {2:-- INSERT --}                            |
    ]], unchanged=true}
  end)

  it('works with kind, menu and abbr attributes', function()
    screen:try_resize(40,8)
    feed('ixx ')
    funcs.complete(4, {{word='wordey', kind= 'x', menu='extrainfo'}, 'thing', {word='secret', abbr='sneaky', menu='bar'}})
    screen:expect([[
      xx wordey^                               |
      {1:~ }{s: wordey x extrainfo }{1:                  }|
      {1:~ }{n: thing              }{1:                  }|
      {1:~ }{n: sneaky   bar       }{1:                  }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {2:-- INSERT --}                            |
    ]])

    feed('<c-p>')
    screen:expect([[
      xx ^                                     |
      {1:~ }{n: wordey x extrainfo }{1:                  }|
      {1:~ }{n: thing              }{1:                  }|
      {1:~ }{n: sneaky   bar       }{1:                  }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {2:-- INSERT --}                            |
    ]])

    feed('<c-p>')
    screen:expect([[
      xx secret^                               |
      {1:~ }{n: wordey x extrainfo }{1:                  }|
      {1:~ }{n: thing              }{1:                  }|
      {1:~ }{s: sneaky   bar       }{1:                  }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {2:-- INSERT --}                            |
    ]])

    feed('<esc>')
    screen:expect([[
      xx secre^t                               |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]])
  end)

  it('works with wildoptions=pum', function()
    screen:try_resize(32,10)
    command('set wildmenu')
    command('set wildoptions=pum')

    feed(':sign ')
    screen:expect([[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      :sign ^                          |
    ]])

    feed('<tab>')
    screen:expect([[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~    }{s: define         }{1:           }|
      {1:~    }{n: jump           }{1:           }|
      {1:~    }{n: list           }{1:           }|
      {1:~    }{n: place          }{1:           }|
      {1:~    }{n: undefine       }{1:           }|
      {1:~    }{n: unplace        }{1:           }|
      :sign define^                    |
    ]])

    feed('<left>')
    screen:expect([[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~    }{n: define         }{1:           }|
      {1:~    }{n: jump           }{1:           }|
      {1:~    }{n: list           }{1:           }|
      {1:~    }{n: place          }{1:           }|
      {1:~    }{n: undefine       }{1:           }|
      {1:~    }{n: unplace        }{1:           }|
      :sign ^                          |
    ]])

    feed('<left>')
    screen:expect([[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~    }{n: define         }{1:           }|
      {1:~    }{n: jump           }{1:           }|
      {1:~    }{n: list           }{1:           }|
      {1:~    }{n: place          }{1:           }|
      {1:~    }{n: undefine       }{1:           }|
      {1:~    }{s: unplace        }{1:           }|
      :sign unplace^                   |
    ]])

    feed('x')
    screen:expect([[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      :sign unplacex^                  |
    ]])

    feed('<esc>')

    -- check positioning with multibyte char in pattern
    command("e långfile1")
    command("sp långfile2")
    feed(':b lå<tab>')
    screen:expect([[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {4:långfile2                       }|
                                      |
      {1:~                               }|
      {1:~ }{s: långfile1      }{1:              }|
      {3:lå}{n: långfile2      }{3:              }|
      :b långfile1^                    |
    ]])

    -- check doesn't crash on screen resize
    screen:try_resize(20,6)
    screen:expect([[
                          |
      {1:~                   }|
      {4:långfile2           }|
        {s: långfile1      }  |
      {3:lå}{n: långfile2      }{3:  }|
      :b långfile1^        |
    ]])

    screen:try_resize(50,15)
    screen:expect([[
                                                        |
      {1:~                                                 }|
      {4:långfile2                                         }|
                                                        |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~ }{s: långfile1      }{1:                                }|
      {3:lå}{n: långfile2      }{3:                                }|
      :b långfile1^                                      |
    ]])

    -- position is calculated correctly with "longest"
    feed('<esc>')
    command('set wildmode=longest:full,full')
    feed(':b lå<tab>')
    screen:expect([[
                                                        |
      {1:~                                                 }|
      {4:långfile2                                         }|
                                                        |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~ }{n: långfile1      }{1:                                }|
      {3:lå}{n: långfile2      }{3:                                }|
      :b långfile^                                       |
    ]])

    -- special case: when patterns ends with "/", show menu items aligned
    -- after the "/"
    feed('<esc>')
    command("close")
    command('set wildmode=full')
    command("cd test/functional/fixtures/")
    feed(':e compdir/<tab>')
    screen:expect([[
                                                        |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~         }{s: file1          }{1:                        }|
      {1:~         }{n: file2          }{1:                        }|
      :e compdir]]..get_pathsep()..[[file1^                                  |
    ]])
  end)

  it('works with wildoptions=pum with scrolled mesages ', function()
    screen:try_resize(40,10)
    command('set wildmenu')
    command('set wildoptions=pum')

    feed(':echoerr "fail"|echoerr "error"<cr>')
    screen:expect{grid=[[
                                              |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {4:                                        }|
      {6:fail}                                    |
      {6:error}                                   |
      {5:Press ENTER or type command to continue}^ |
    ]]}

    feed(':sign <tab>')
    screen:expect{grid=[[
                                              |
      {1:~                                       }|
      {1:~                                       }|
      {1:~    }{s: define         }{1:                   }|
      {1:~    }{n: jump           }{1:                   }|
      {1:~    }{n: list           }{1:                   }|
      {4:     }{n: place          }{4:                   }|
      {6:fail} {n: undefine       }                   |
      {6:error}{n: unplace        }                   |
      :sign define^                            |
    ]]}

    feed('d')
    screen:expect{grid=[[
                                              |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {4:                                        }|
      {6:fail}                                    |
      {6:error}                                   |
      :sign defined^                           |
    ]]}
  end)

  it("'pumblend' RGB-color", function()
    screen:try_resize(60,14)
    screen:set_default_attr_ids({
      [1] = {background = Screen.colors.Yellow},
      [2] = {bold = true, reverse = true},
      [3] = {bold = true, foreground = Screen.colors.Brown},
      [4] = {foreground = Screen.colors.Blue1},
      [5] = {reverse = true},
      [6] = {background = Screen.colors.Gray55, foreground = Screen.colors.Grey45},
      [7] = {background = Screen.colors.Gray55, foreground = Screen.colors.Grey0},
      [8] = {background = tonumber('0x191919'), foreground = Screen.colors.Grey0},
      [9] = {background = tonumber('0xffc1ff'), foreground = tonumber('0xe5a8e5')},
      [10] = {background = tonumber('0xffc1ff'), foreground = Screen.colors.Grey0},
      [11] = {foreground = tonumber('0xffc1ff'), background = tonumber('0xe5a8e5'), bold = true},
      [12] = {foreground = Screen.colors.Grey55, background = Screen.colors.Gray45, bold = true},
      [13] = {background = tonumber('0xffc1e5'), foreground = Screen.colors.Grey0},
      [14] = {background = tonumber('0xffc1e5'), foreground = tonumber('0xe5a8e5')},
      [15] = {background = tonumber('0xffc1ff'), foreground = tonumber('0x080202')},
      [16] = {background = tonumber('0xffc1ff'), bold = true, foreground = tonumber('0xf6ace9')},
      [17] = {background = tonumber('0xffc1ff'), foreground = tonumber('0xe5a8ff')},
      [18] = {background = tonumber('0xe5a8e5'), foreground = tonumber('0xffc1ff')},
      [19] = {background = Screen.colors.Gray45, foreground = Screen.colors.Grey55},
      [20] = {bold = true},
      [21] = {bold = true, foreground = Screen.colors.SeaGreen4},
      [22] = {background = Screen.colors.WebGray},
      [23] = {background = Screen.colors.Grey0},
      [24] = {background = Screen.colors.LightMagenta},
      [25] = {background = Screen.colors.Gray75, foreground = Screen.colors.Grey25},
      [26] = {background = Screen.colors.Gray75, foreground = Screen.colors.Grey0},
      [27] = {background = Screen.colors.Gray50, foreground = Screen.colors.Grey0},
      [28] = {background = tonumber('0xffddff'), foreground = tonumber('0x7f5d7f')},
      [29] = {background = tonumber('0xffddff'), foreground = Screen.colors.Grey0},
      [30] = {foreground = tonumber('0xffddff'), background = tonumber('0x7f5d7f'), bold = true},
      [31] = {foreground = tonumber('0xffddff'), background = Screen.colors.Grey0, bold = true},
      [32] = {foreground = Screen.colors.Gray75, background = Screen.colors.Grey25, bold = true},
      [33] = {background = tonumber('0xffdd7f'), foreground = Screen.colors.Grey0},
      [34] = {background = tonumber('0xffdd7f'), foreground = tonumber('0x7f5d7f')},
      [35] = {background = tonumber('0xffddff'), bold = true, foreground = tonumber('0x290a0a')},
      [36] = {background = tonumber('0xffddff'), bold = true, foreground = tonumber('0xd27294')},
      [37] = {background = tonumber('0xffddff'), foreground = tonumber('0x7f5dff')},
      [38] = {background = tonumber('0x7f5d7f'), foreground = tonumber('0xffddff')},
      [39] = {background = Screen.colors.Grey0, foreground = tonumber('0xffddff')},
      [40] = {background = Screen.colors.Gray25, foreground = Screen.colors.Grey75},
      [41] = {background = tonumber('0xffddff'), foreground = tonumber('0x00003f')},
      [42] = {foreground = tonumber('0x0c0c0c'), background = tonumber('0xe5a8e5')},
      [43] = {background = tonumber('0x7f5d7f'), bold = true, foreground = tonumber('0x3f3f3f')},
      [44] = {foreground = tonumber('0x3f3f3f'), background = tonumber('0x7f5d7f')},
      [45] = {background = Screen.colors.WebGray, blend=0},
    })
    command('syntax on')
    command('set mouse=a')
    command('set pumblend=10')
    insert([[
      Lorem ipsum dolor sit amet, consectetur
      adipisicing elit, sed do eiusmod tempor
      incididunt ut labore et dolore magna aliqua.
      Ut enim ad minim veniam, quis nostrud
      exercitation ullamco laboris nisi ut aliquip ex
      ea commodo consequat. Duis aute irure dolor in
      reprehenderit in voluptate velit esse cillum
      dolore eu fugiat nulla pariatur. Excepteur sint
      occaecat cupidatat non proident, sunt in culpa
      qui officia deserunt mollit anim id est
      laborum.]])
    command('match Statement /el/')
    command('2match Comment /ut/')
    command('1')
    command('split')
    command('/ol')
    screen:expect([[
      Lorem ipsum d{1:ol}or sit amet, consectetur                     |
      adipisicing elit, sed do eiusmod tempor                     |
      ^incididunt ut labore et d{1:ol}ore magna aliqua.                |
      Ut enim ad minim veniam, quis nostrud                       |
      exercitation ullamco laboris nisi ut aliquip ex             |
      ea commodo consequat. Duis aute irure d{1:ol}or in              |
      {2:[No Name] [+]                                               }|
      Lorem ipsum d{1:ol}or sit amet, consectetur                     |
      adipisicing {3:el}it, sed do eiusmod tempor                     |
      incididunt {4:ut} labore et d{1:ol}ore magna aliqua.                |
      Ut enim ad minim veniam, quis nostrud                       |
      exercitation ullamco laboris nisi {4:ut} aliquip ex             |
      {5:[No Name] [+]                                               }|
                                                                  |
    ]])

    feed('Obla bla <c-x><c-n>')
    screen:expect([[
      Lorem ipsum d{1:ol}or sit amet, consectetur                     |
      adipisicing elit, sed do eiusmod tempor                     |
      bla bla incididunt^                                          |
      incidid{6:u}{7:incididunt}{6:re et}{8: }d{1:ol}ore magna aliqua.                |
      Ut enim{9: }{10:ut}{9: minim veniam}{6:,} quis nostrud                       |
      exercit{9:a}{10:labore}{9:llamco la}{6:b}oris nisi ut aliquip ex             |
      {2:[No Nam}{11:e}{42:et}{11:[+]          }{12: }{2:                                    }|
      Lorem i{9:p}{10:dolor}{13:e}{14:l}{9:or sit a}{6:m}et, consectetur                     |
      adipisi{9:c}{10:magn}{15:a}{16:l}{9:it, sed d}{6:o} eiusmod tempor                     |
      bla bla{9: }{10:aliqua}{9:dunt     }{6: }                                    |
      incidid{9:u}{10:Ut}{9: }{17:ut}{9: labore et}{6: }d{1:ol}ore magna aliqua.                |
      Ut enim{9: }{10:enim}{9:inim veniam}{6:,} quis nostrud                       |
      {5:[No Nam}{18:e}{42:ad}{18:[+]          }{19: }{5:                                    }|
      {20:-- Keyword Local completion (^N^P) }{21:match 1 of 65}            |
    ]])

    command('set pumblend=0')
    screen:expect([[
      Lorem ipsum d{1:ol}or sit amet, consectetur                     |
      adipisicing elit, sed do eiusmod tempor                     |
      bla bla incididunt^                                          |
      incidid{22: incididunt     }{23: }d{1:ol}ore magna aliqua.                |
      Ut enim{24: ut             }{22: } quis nostrud                       |
      exercit{24: labore         }{22: }oris nisi ut aliquip ex             |
      {2:[No Nam}{24: et             }{22: }{2:                                    }|
      Lorem i{24: dolore         }{22: }et, consectetur                     |
      adipisi{24: magna          }{22: } eiusmod tempor                     |
      bla bla{24: aliqua         }{22: }                                    |
      incidid{24: Ut             }{22: }d{1:ol}ore magna aliqua.                |
      Ut enim{24: enim           }{22: } quis nostrud                       |
      {5:[No Nam}{24: ad             }{22: }{5:                                    }|
      {20:-- Keyword Local completion (^N^P) }{21:match 1 of 65}            |
    ]])

    command('set pumblend=50')
    screen:expect([[
      Lorem ipsum d{1:ol}or sit amet, consectetur                     |
      adipisicing elit, sed do eiusmod tempor                     |
      bla bla incididunt^                                          |
      incidid{25:u}{26:incididunt}{25:re et}{27: }d{1:ol}ore magna aliqua.                |
      Ut enim{28: }{29:ut}{28: minim veniam}{25:,} quis nostrud                       |
      exercit{28:a}{29:labore}{28:llamco la}{25:b}oris nisi ut aliquip ex             |
      {2:[No Nam}{30:e}{43:et}{30:[+]          }{32: }{2:                                    }|
      Lorem i{28:p}{29:dolor}{33:e}{34:l}{28:or sit a}{25:m}et, consectetur                     |
      adipisi{28:c}{29:magn}{35:a}{36:l}{28:it, sed d}{25:o} eiusmod tempor                     |
      bla bla{28: }{29:aliqua}{28:dunt     }{25: }                                    |
      incidid{28:u}{29:Ut}{28: }{37:ut}{28: labore et}{25: }d{1:ol}ore magna aliqua.                |
      Ut enim{28: }{29:enim}{28:inim veniam}{25:,} quis nostrud                       |
      {5:[No Nam}{38:e}{44:ad}{38:[+]          }{40: }{5:                                    }|
      {20:-- Keyword Local completion (^N^P) }{21:match 1 of 65}            |
    ]])

    meths.input_mouse('wheel', 'down', '', 0, 9, 40)
    screen:expect([[
      Lorem ipsum d{1:ol}or sit amet, consectetur                     |
      adipisicing elit, sed do eiusmod tempor                     |
      bla bla incididunt^                                          |
      incidid{25:u}{26:incididunt}{25:re et}{27: }d{1:ol}ore magna aliqua.                |
      Ut enim{28: }{29:ut}{28: minim veniam}{25:,} quis nostrud                       |
      exercit{28:a}{29:labore}{28:llamco la}{25:b}oris nisi ut aliquip ex             |
      {2:[No Nam}{30:e}{43:et}{30:[+]          }{32: }{2:                                    }|
      incidid{28:u}{29:dol}{41:or}{29:e}{28:labore et}{25: }d{1:ol}ore magna aliqua.                |
      Ut enim{28: }{29:magna}{28:nim veniam}{25:,} quis nostrud                       |
      exercit{28:a}{29:aliqua}{28:llamco la}{25:b}oris nisi {4:ut} aliquip ex             |
      ea comm{28:o}{29:Ut}{28: consequat. D}{25:u}is a{4:ut}e irure d{1:ol}or in              |
      reprehe{28:n}{29:enim}{28:t in v}{34:ol}{28:upt}{25:a}te v{3:el}it esse cillum                |
      {5:[No Nam}{38:e}{44:ad}{38:[+]          }{40: }{5:                                    }|
      {20:-- Keyword Local completion (^N^P) }{21:match 1 of 65}            |
    ]])

    -- can disable blending for indiviual attribute. For instance current
    -- selected item. (also tests that `hi Pmenu*` take immediate effect)
    command('hi PMenuSel blend=0')
    screen:expect([[
      Lorem ipsum d{1:ol}or sit amet, consectetur                     |
      adipisicing elit, sed do eiusmod tempor                     |
      bla bla incididunt^                                          |
      incidid{45: incididunt     }{27: }d{1:ol}ore magna aliqua.                |
      Ut enim{28: }{29:ut}{28: minim veniam}{25:,} quis nostrud                       |
      exercit{28:a}{29:labore}{28:llamco la}{25:b}oris nisi ut aliquip ex             |
      {2:[No Nam}{30:e}{43:et}{30:[+]          }{32: }{2:                                    }|
      incidid{28:u}{29:dol}{41:or}{29:e}{28:labore et}{25: }d{1:ol}ore magna aliqua.                |
      Ut enim{28: }{29:magna}{28:nim veniam}{25:,} quis nostrud                       |
      exercit{28:a}{29:aliqua}{28:llamco la}{25:b}oris nisi {4:ut} aliquip ex             |
      ea comm{28:o}{29:Ut}{28: consequat. D}{25:u}is a{4:ut}e irure d{1:ol}or in              |
      reprehe{28:n}{29:enim}{28:t in v}{34:ol}{28:upt}{25:a}te v{3:el}it esse cillum                |
      {5:[No Nam}{38:e}{44:ad}{38:[+]          }{40: }{5:                                    }|
      {20:-- Keyword Local completion (^N^P) }{21:match 1 of 65}            |
    ]])

    feed('<c-e>')
    screen:expect([[
      Lorem ipsum d{1:ol}or sit amet, consectetur                     |
      adipisicing elit, sed do eiusmod tempor                     |
      bla bla ^                                                    |
      incididunt ut labore et d{1:ol}ore magna aliqua.                |
      Ut enim ad minim veniam, quis nostrud                       |
      exercitation ullamco laboris nisi ut aliquip ex             |
      {2:[No Name] [+]                                               }|
      incididunt {4:ut} labore et d{1:ol}ore magna aliqua.                |
      Ut enim ad minim veniam, quis nostrud                       |
      exercitation ullamco laboris nisi {4:ut} aliquip ex             |
      ea commodo consequat. Duis a{4:ut}e irure d{1:ol}or in              |
      reprehenderit in v{1:ol}uptate v{3:el}it esse cillum                |
      {5:[No Name] [+]                                               }|
      {20:-- INSERT --}                                                |
    ]])
  end)

  it("'pumblend' 256-color (non-RGB)", function()
    screen:detach()
    screen = Screen.new(60, 8)
    screen:attach({rgb=false, ext_popupmenu=false})
    screen:set_default_attr_ids({
      [1] = {foreground = Screen.colors.Grey0, background = tonumber('0x000007')},
      [2] = {foreground = tonumber('0x000055'), background = tonumber('0x000007')},
      [3] = {foreground = tonumber('0x00008f'), background = Screen.colors.Grey0},
      [4] = {foreground = Screen.colors.Grey0, background = tonumber('0x0000e1')},
      [5] = {foreground = tonumber('0x0000d1'), background = tonumber('0x0000e1')},
      [6] = {foreground = Screen.colors.NavyBlue, background = tonumber('0x0000f8')},
      [7] = {foreground = tonumber('0x0000a5'), background = tonumber('0x0000f8')},
      [8] = {foreground = tonumber('0x00000c')},
      [9] = {bold = true},
      [10] = {foreground = tonumber('0x000002')},
    })
    command('set notermguicolors pumblend=10')
    insert([[
      Lorem ipsum dolor sit amet, consectetur
      adipisicing elit, sed do eiusmod tempor
      incididunt ut labore et dolore magna aliqua.
      Ut enim ad minim veniam, quis nostrud
      laborum.]])

    feed('ggOdo<c-x><c-n>')
    screen:expect([[
      dolor^                                                       |
      {1:dolor}{2: ipsum dol}or sit amet, consectetur                     |
      {4:do}{5:ipisicing eli}t, sed do eiusmod tempor                     |
      {4:dolore}{5:dunt ut l}abore et dolore magna aliqua.                |
      Ut enim ad minim veniam, quis nostrud                       |
      laborum.                                                    |
      {8:~                                                           }|
      {9:-- Keyword Local completion (^N^P) }{10:match 1 of 3}             |
    ]])
  end)
end)
