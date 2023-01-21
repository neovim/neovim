local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local assert_alive = helpers.assert_alive
local clear, feed = helpers.clear, helpers.feed
local source = helpers.source
local insert = helpers.insert
local meths = helpers.meths
local command = helpers.command
local funcs = helpers.funcs
local eq = helpers.eq
local pcall_err = helpers.pcall_err
local exec_lua = helpers.exec_lua
local exec = helpers.exec

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
      [8] = {foreground = Screen.colors.Red},
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

    command('set wildmenu')
    command('set wildoptions=pum')
    local expected_wildpum = {
      { "define", "", "", "" },
      { "jump", "", "", "" },
      { "list", "", "", "" },
      { "place", "", "", "" },
      { "undefine", "", "", "" },
      { "unplace", "", "", "" },
    }
    feed('<Esc>:sign <Tab>')
    screen:expect({grid = [[
                                                                  |
                                                                  |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      :sign define^                                                |
    ]], popupmenu = {
      items = expected_wildpum,
      pos = 0,
      anchor = { 1, 7, 6 },
    }})

    meths.select_popupmenu_item(-1, true, false, {})
    screen:expect({grid = [[
                                                                  |
                                                                  |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      :sign ^                                                      |
    ]], popupmenu = {
      items = expected_wildpum,
      pos = -1,
      anchor = { 1, 7, 6 },
    }})

    meths.select_popupmenu_item(5, true, false, {})
    screen:expect({grid = [[
                                                                  |
                                                                  |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      :sign unplace^                                               |
    ]], popupmenu = {
      items = expected_wildpum,
      pos = 5,
      anchor = { 1, 7, 6 },
    }})

    meths.select_popupmenu_item(-1, true, true, {})
    screen:expect({grid = [[
                                                                  |
                                                                  |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      :sign ^                                                      |
    ]]})

    feed('<Tab>')
    screen:expect({grid = [[
                                                                  |
                                                                  |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      :sign define^                                                |
    ]], popupmenu = {
      items = expected_wildpum,
      pos = 0,
      anchor = { 1, 7, 6 },
    }})

    meths.select_popupmenu_item(5, true, true, {})
    screen:expect({grid = [[
                                                                  |
                                                                  |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      :sign unplace^                                               |
    ]]})

    local function test_pum_select_mappings()
      screen:set_option('ext_popupmenu', true)
      feed('<Esc>A<C-r>=TestComplete()<CR>')
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

      feed('<Esc>:sign <Tab>')
      screen:expect({grid = [[
                                                                    |
        bar                                                         |
        {1:~                                                           }|
        {1:~                                                           }|
        {1:~                                                           }|
        {1:~                                                           }|
        {1:~                                                           }|
        :sign define^                                                |
      ]], popupmenu = {
        items = expected_wildpum,
        pos = 0,
        anchor = { 1, 7, 6 },
      }})

      feed('<f1>')
      screen:expect({grid = [[
                                                                    |
        bar                                                         |
        {1:~                                                           }|
        {1:~                                                           }|
        {1:~                                                           }|
        {1:~                                                           }|
        {1:~                                                           }|
        :sign list^                                                  |
      ]], popupmenu = {
        items = expected_wildpum,
        pos = 2,
        anchor = { 1, 7, 6 },
      }})

      feed('<f2>')
      screen:expect({grid = [[
                                                                    |
        bar                                                         |
        {1:~                                                           }|
        {1:~                                                           }|
        {1:~                                                           }|
        {1:~                                                           }|
        {1:~                                                           }|
        :sign ^                                                      |
      ]], popupmenu = {
        items = expected_wildpum,
        pos = -1,
        anchor = { 1, 7, 6 },
      }})

      feed('<f3>')
      screen:expect({grid = [[
                                                                    |
        bar                                                         |
        {1:~                                                           }|
        {1:~                                                           }|
        {1:~                                                           }|
        {1:~                                                           }|
        {1:~                                                           }|
        :sign jump^                                                  |
      ]]})

      -- also should work for builtin popupmenu
      screen:set_option('ext_popupmenu', false)
      feed('<Esc>A<C-r>=TestComplete()<CR>')
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

      feed('<Esc>:sign <Tab>')
      screen:expect([[
                                                                    |
        bar  {6: define         }                                       |
        {1:~    }{7: jump           }{1:                                       }|
        {1:~    }{7: list           }{1:                                       }|
        {1:~    }{7: place          }{1:                                       }|
        {1:~    }{7: undefine       }{1:                                       }|
        {1:~    }{7: unplace        }{1:                                       }|
        :sign define^                                                |
      ]])

      feed('<f1>')
      screen:expect([[
                                                                    |
        bar  {7: define         }                                       |
        {1:~    }{7: jump           }{1:                                       }|
        {1:~    }{6: list           }{1:                                       }|
        {1:~    }{7: place          }{1:                                       }|
        {1:~    }{7: undefine       }{1:                                       }|
        {1:~    }{7: unplace        }{1:                                       }|
        :sign list^                                                  |
      ]])

      feed('<f2>')
      screen:expect([[
                                                                    |
        bar  {7: define         }                                       |
        {1:~    }{7: jump           }{1:                                       }|
        {1:~    }{7: list           }{1:                                       }|
        {1:~    }{7: place          }{1:                                       }|
        {1:~    }{7: undefine       }{1:                                       }|
        {1:~    }{7: unplace        }{1:                                       }|
        :sign ^                                                      |
      ]])

      feed('<f3>')
      screen:expect([[
                                                                    |
        bar                                                         |
        {1:~                                                           }|
        {1:~                                                           }|
        {1:~                                                           }|
        {1:~                                                           }|
        {1:~                                                           }|
        :sign jump^                                                  |
      ]])
    end

    command('map! <f1> <cmd>call nvim_select_popupmenu_item(2,v:true,v:false,{})<cr>')
    command('map! <f2> <cmd>call nvim_select_popupmenu_item(-1,v:false,v:false,{})<cr>')
    command('map! <f3> <cmd>call nvim_select_popupmenu_item(1,v:false,v:true,{})<cr>')
    test_pum_select_mappings()

    command('unmap! <f1>')
    command('unmap! <f2>')
    command('unmap! <f3>')
    exec_lua([[
      vim.keymap.set('!', '<f1>', function() vim.api.nvim_select_popupmenu_item(2, true, false, {}) end)
      vim.keymap.set('!', '<f2>', function() vim.api.nvim_select_popupmenu_item(-1, false, false, {}) end)
      vim.keymap.set('!', '<f3>', function() vim.api.nvim_select_popupmenu_item(1, false, true, {}) end)
    ]])
    test_pum_select_mappings()

    feed('<esc>ddiaa bb cc<cr>')
    feed('<c-x><c-n>')
    screen:expect([[
      aa bb cc                                                    |
      aa^                                                          |
      {6:aa             }{1:                                             }|
      {7:bb             }{1:                                             }|
      {7:cc             }{1:                                             }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:-- Keyword Local completion (^N^P) }{5:match 1 of 3}             |
    ]])

    feed('<f1>')
    screen:expect([[
      aa bb cc                                                    |
      cc^                                                          |
      {7:aa             }{1:                                             }|
      {7:bb             }{1:                                             }|
      {6:cc             }{1:                                             }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:-- Keyword Local completion (^N^P) }{5:match 3 of 3}             |
    ]])

    feed('<f2>')
    screen:expect([[
      aa bb cc                                                    |
      cc^                                                          |
      {7:aa             }{1:                                             }|
      {7:bb             }{1:                                             }|
      {7:cc             }{1:                                             }|
      {1:~                                                           }|
      {1:~                                                           }|
      {2:-- Keyword Local completion (^N^P) }{8:Back at original}         |
    ]])

    feed('<f3>')
    screen:expect([[
      aa bb cc                                                    |
      bb^                                                          |
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
    it('can set pum height', function()
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
      meths.ui_pum_set_height(1)
      eq('Expected pum height > 0',
         pcall_err(meths.ui_pum_set_height, 0))
    end)

    it('an error occurs when ext_popupmenu is false', function()
      meths.ui_pum_set_height(1)
      screen:set_option('ext_popupmenu', false)
      eq('It must support the ext_popupmenu option',
         pcall_err(meths.ui_pum_set_height, 1))
    end)
  end)

  describe('pum_set_bounds', function()
    it('can set pum bounds', function()
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
      -- set bounds w h r c
      meths.ui_pum_set_bounds(10.5, 5.2, 6.3, 7.4)
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

    it('no error occurs if row or col set less than 0', function()
      meths.ui_pum_set_bounds(1.0, 1.0, 0.0, 1.5)
      meths.ui_pum_set_bounds(1.0, 1.0, -1.0, 0.0)
      meths.ui_pum_set_bounds(1.0, 1.0, 0.0, -1.0)
    end)

    it('an error occurs if width or height set 0 or less', function()
      meths.ui_pum_set_bounds(1.0, 1.0, 0.0, 1.5)
      eq('Expected width > 0',
         pcall_err(meths.ui_pum_set_bounds, 0.0, 1.0, 1.0, 0.0))
      eq('Expected height > 0',
         pcall_err(meths.ui_pum_set_bounds, 1.0, -1.0, 1.0, 0.0))
    end)

    it('an error occurs when ext_popupmenu is false', function()
      meths.ui_pum_set_bounds(1.0, 1.0, 0.0, 1.5)
      screen:set_option('ext_popupmenu', false)
      eq('UI must support the ext_popupmenu option',
         pcall_err(meths.ui_pum_set_bounds, 1.0, 1.0, 0.0, 1.5))
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

  it('does not interfere with mousemodel=popup', function()
    exec([[
      set mouse=a mousemodel=popup

      aunmenu PopUp
      menu PopUp.foo :let g:menustr = 'foo'<CR>
      menu PopUp.bar :let g:menustr = 'bar'<CR>
      menu PopUp.baz :let g:menustr = 'baz'<CR>
    ]])
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

    feed('<esc>')
    screen:expect{grid=[[
                                                                  |
      ^                                                            |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
                                                                  |
    ]]}
    feed('<RightMouse><0,0>')
    screen:expect([[
                                                                  |
      {7:^foo }                                                        |
      {7:bar }{1:                                                        }|
      {7:baz }{1:                                                        }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
                                                                  |
    ]])
    feed('<esc>')
    screen:expect([[
                                                                  |
      ^                                                            |
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
      {1:~                                                           }|
                                                                  |
    ]])
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
      [7] = {background = Screen.colors.Yellow},  -- Search
      [8] = {foreground = Screen.colors.Red},
    })
  end)

  it('with preview-window above', function()
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

  it('with preview-window below', function()
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

  it('with preview-window above and tall and inverted', function()
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

  it('with preview-window above and short and inverted', function()
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
      hh                              |
      {s:aa             }{c: }{3:ew][+]          }|
      {n:bb             }{c: }                |
      {n:cc             }{c: }                |
      {n:dd             }{c: }                |
      {n:ee             }{c: }                |
      {n:ff             }{c: }                |
      {n:gg             }{c: }                |
      {n:hh             }{c: }                |
      {n:ii             }{s: }                |
      aa^                              |
      {4:[No Name] [+]                   }|
      {2:-- }{5:match 1 of 10}                |
    ]])
  end)

  it('with preview-window below and inverted', function()
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

  -- oldtest: Test_pum_with_preview_win()
  it('preview window opened during completion', function()
    exec([[
      funct Omni_test(findstart, base)
        if a:findstart
          return col(".") - 1
        endif
        return [#{word: "one", info: "1info"}, #{word: "two", info: "2info"}, #{word: "three", info: "3info"}]
      endfunc
      set omnifunc=Omni_test
      set completeopt+=longest
    ]])
    feed('Gi<C-X><C-O>')
    screen:expect([[
      ^                                |
      {n:one            }{1:                 }|
      {n:two            }{1:                 }|
      {n:three          }{1:                 }|
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
      {1:~                               }|
      {2:-- }{8:Back at original}             |
    ]])
    feed('<C-N>')
    screen:expect([[
      1info                           |
                                      |
      {1:~                               }|
      {3:[Scratch] [Preview]             }|
      one^                             |
      {s:one            }{1:                 }|
      {n:two            }{1:                 }|
      {n:three          }{1:                 }|
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
      {4:[No Name] [+]                   }|
      {2:-- }{5:match 1 of 3}                 |
    ]])
  end)

  it('with vsplits', function()
    insert('aaa aab aac\n')
    feed(':vsplit<cr>')
    screen:expect([[
      aaa aab aac         │aaa aab aac|
      ^                    │           |
      {1:~                   }│{1:~          }|
      {1:~                   }│{1:~          }|
      {1:~                   }│{1:~          }|
      {1:~                   }│{1:~          }|
      {1:~                   }│{1:~          }|
      {1:~                   }│{1:~          }|
      {1:~                   }│{1:~          }|
      {1:~                   }│{1:~          }|
      {1:~                   }│{1:~          }|
      {1:~                   }│{1:~          }|
      {1:~                   }│{1:~          }|
      {1:~                   }│{1:~          }|
      {1:~                   }│{1:~          }|
      {1:~                   }│{1:~          }|
      {1:~                   }│{1:~          }|
      {1:~                   }│{1:~          }|
      {4:[No Name] [+]        }{3:<Name] [+] }|
      :vsplit                         |
    ]])

    feed('ibbb a<c-x><c-n>')
    screen:expect([[
      aaa aab aac         │aaa aab aac|
      bbb aaa^             │bbb aaa    |
      {1:~  }{s: aaa            }{1: }│{1:~          }|
      {1:~  }{n: aab            }{1: }│{1:~          }|
      {1:~  }{n: aac            }{1: }│{1:~          }|
      {1:~                   }│{1:~          }|
      {1:~                   }│{1:~          }|
      {1:~                   }│{1:~          }|
      {1:~                   }│{1:~          }|
      {1:~                   }│{1:~          }|
      {1:~                   }│{1:~          }|
      {1:~                   }│{1:~          }|
      {1:~                   }│{1:~          }|
      {1:~                   }│{1:~          }|
      {1:~                   }│{1:~          }|
      {1:~                   }│{1:~          }|
      {1:~                   }│{1:~          }|
      {1:~                   }│{1:~          }|
      {4:[No Name] [+]        }{3:<Name] [+] }|
      {2:-- }{5:match 1 of 3}                 |
    ]])

    feed('<esc><c-w><c-w>oc a<c-x><c-n>')
    screen:expect([[
      aaa aab aac│aaa aab aac         |
      bbb aaa    │bbb aaa             |
      c aaa      │c aaa^               |
      {1:~          }│{1:~}{s: aaa            }{1:   }|
      {1:~          }│{1:~}{n: aab            }{1:   }|
      {1:~          }│{1:~}{n: aac            }{1:   }|
      {1:~          }│{1:~                   }|
      {1:~          }│{1:~                   }|
      {1:~          }│{1:~                   }|
      {1:~          }│{1:~                   }|
      {1:~          }│{1:~                   }|
      {1:~          }│{1:~                   }|
      {1:~          }│{1:~                   }|
      {1:~          }│{1:~                   }|
      {1:~          }│{1:~                   }|
      {1:~          }│{1:~                   }|
      {1:~          }│{1:~                   }|
      {1:~          }│{1:~                   }|
      {3:<Name] [+]  }{4:[No Name] [+]       }|
      {2:-- }{5:match 1 of 3}                 |
    ]])
  end)

  it('with split and scroll', function()
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
      {1:~         }{n: word    }{1: }|
      {1:~         }{n: choice  }{1: }|
      {1:~         }{s: text    }{1: }|
      {1:~         }{n: thing   }{1: }|
      {1:~                   }|
      {2:-- INSERT --}        |
    ]])
  end)

  it('with VimResized autocmd', function()
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

  it('with rightleft window', function()
    command("set rl wildoptions+=pum")
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

    -- not rightleft on the cmdline
    feed('<esc>:sign ')
    screen:expect{grid=[[
                   drow tfelthgir emos|
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
      :sign ^                          |
    ]]}

    feed('<tab>')
    screen:expect{grid=[[
                   drow tfelthgir emos|
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
      {1:     }{s: define         }{1:          ~}|
      {1:     }{n: jump           }{1:          ~}|
      {1:     }{n: list           }{1:          ~}|
      {1:     }{n: place          }{1:          ~}|
      {1:     }{n: undefine       }{1:          ~}|
      {1:     }{n: unplace        }{1:          ~}|
      :sign define^                    |
    ]]}
  end)

  it('with multiline messages', function()
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

  it('with kind, menu and abbr attributes', function()
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

  it('wildoptions=pum', function()
    screen:try_resize(32,10)
    command('set wildmenu')
    command('set wildoptions=pum')
    command('set shellslash')
    command("cd test/functional/fixtures/wildpum")

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

    feed('<Tab>')
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

    feed('<Right><Right>')
    screen:expect([[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~    }{n: define         }{1:           }|
      {1:~    }{n: jump           }{1:           }|
      {1:~    }{s: list           }{1:           }|
      {1:~    }{n: place          }{1:           }|
      {1:~    }{n: undefine       }{1:           }|
      {1:~    }{n: unplace        }{1:           }|
      :sign list^                      |
    ]])

    feed('<C-N>')
    screen:expect([[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~    }{n: define         }{1:           }|
      {1:~    }{n: jump           }{1:           }|
      {1:~    }{n: list           }{1:           }|
      {1:~    }{s: place          }{1:           }|
      {1:~    }{n: undefine       }{1:           }|
      {1:~    }{n: unplace        }{1:           }|
      :sign place^                     |
    ]])

    feed('<C-P>')
    screen:expect([[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~    }{n: define         }{1:           }|
      {1:~    }{n: jump           }{1:           }|
      {1:~    }{s: list           }{1:           }|
      {1:~    }{n: place          }{1:           }|
      {1:~    }{n: undefine       }{1:           }|
      {1:~    }{n: unplace        }{1:           }|
      :sign list^                      |
    ]])

    feed('<Left>')
    screen:expect([[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~    }{n: define         }{1:           }|
      {1:~    }{s: jump           }{1:           }|
      {1:~    }{n: list           }{1:           }|
      {1:~    }{n: place          }{1:           }|
      {1:~    }{n: undefine       }{1:           }|
      {1:~    }{n: unplace        }{1:           }|
      :sign jump^                      |
    ]])

    -- pressing <C-E> should end completion and go back to the original match
    feed('<C-E>')
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

    -- pressing <C-Y> should select the current match and end completion
    feed('<Tab><C-P><C-P><C-Y>')
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
      :sign unplace^                   |
    ]])

    -- showing popup menu in different columns in the cmdline
    feed('<C-U>sign define <Tab>')
    screen:expect([[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~           }{s: culhl=         }{1:    }|
      {1:~           }{n: icon=          }{1:    }|
      {1:~           }{n: linehl=        }{1:    }|
      {1:~           }{n: numhl=         }{1:    }|
      {1:~           }{n: text=          }{1:    }|
      {1:~           }{n: texthl=        }{1:    }|
      :sign define culhl=^             |
    ]])

    feed('<Space><Tab>')
    screen:expect([[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~                  }{s: culhl=     }{1: }|
      {1:~                  }{n: icon=      }{1: }|
      {1:~                  }{n: linehl=    }{1: }|
      {1:~                  }{n: numhl=     }{1: }|
      {1:~                  }{n: text=      }{1: }|
      {1:~                  }{n: texthl=    }{1: }|
      :sign define culhl= culhl=^      |
    ]])

    feed('<C-U>e Xdi<Tab><Tab>')
    screen:expect([[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~      }{s: XdirA/         }{1:         }|
      {1:~      }{n: XfileA         }{1:         }|
      :e Xdir/XdirA/^                  |
    ]])

    -- Pressing <Down> on a directory name should go into that directory
    feed('<Down>')
    screen:expect([[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~            }{s: XdirB/         }{1:   }|
      {1:~            }{n: XfileB         }{1:   }|
      :e Xdir/XdirA/XdirB/^            |
    ]])

    -- Pressing <Up> on a directory name should go to the parent directory
    feed('<Up>')
    screen:expect([[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~      }{s: XdirA/         }{1:         }|
      {1:~      }{n: XfileA         }{1:         }|
      :e Xdir/XdirA/^                  |
    ]])

    -- Pressing <C-A> when the popup menu is displayed should list all the
    -- matches and remove the popup menu
    feed(':<C-U>sign <Tab><C-A>')
    screen:expect([[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {4:                                }|
      :sign define jump list place und|
      efine unplace^                   |
    ]])

    -- Pressing <Left> after that should move the cursor
    feed('<Left>')
    screen:expect([[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {4:                                }|
      :sign define jump list place und|
      efine unplac^e                   |
    ]])
    feed('<End>')

    -- Pressing <C-D> when the popup menu is displayed should remove the popup
    -- menu
    feed('<C-U>sign <Tab><C-D>')
    screen:expect([[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {4:                                }|
      :sign define                    |
      define                          |
      :sign define^                    |
    ]])

    -- Pressing <S-Tab> should open the popup menu with the last entry selected
    feed('<C-U><CR>:sign <S-Tab><C-P>')
    screen:expect([[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~    }{n: define         }{1:           }|
      {1:~    }{n: jump           }{1:           }|
      {1:~    }{n: list           }{1:           }|
      {1:~    }{n: place          }{1:           }|
      {1:~    }{s: undefine       }{1:           }|
      {1:~    }{n: unplace        }{1:           }|
      :sign undefine^                  |
    ]])

    -- Pressing <Esc> should close the popup menu and cancel the cmd line
    feed('<C-U><CR>:sign <Tab><Esc>')
    screen:expect([[
      ^                                |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
                                      |
    ]])

    -- Typing a character when the popup is open, should close the popup
    feed(':sign <Tab>x')
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
      :sign definex^                   |
    ]])

    -- When the popup is open, entering the cmdline window should close the popup
    feed('<C-U>sign <Tab><C-F>')
    screen:expect([[
                                      |
      {3:[No Name]                       }|
      {1::}sign define                    |
      {1::}sign define^                    |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {4:[Command Line]                  }|
      :sign define                    |
    ]])
    feed(':q<CR>')

    -- After the last popup menu item, <C-N> should show the original string
    feed(':sign u<Tab><C-N><C-N>')
    screen:expect([[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~    }{n: undefine       }{1:           }|
      {1:~    }{n: unplace        }{1:           }|
      :sign u^                         |
    ]])

    -- Use the popup menu for the command name
    feed('<C-U>bu<Tab>')
    screen:expect([[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {s: bufdo          }{1:                }|
      {n: buffer         }{1:                }|
      {n: buffers        }{1:                }|
      {n: bunload        }{1:                }|
      :bufdo^                          |
    ]])

    -- Pressing <BS> should remove the popup menu and erase the last character
    feed('<C-E><C-U>sign <Tab><BS>')
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
      :sign defin^                     |
    ]])

    -- Pressing <C-W> should remove the popup menu and erase the previous word
    feed('<C-E><C-U>sign <Tab><C-W>')
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

    -- Pressing <C-U> should remove the popup menu and erase the entire line
    feed('<C-E><C-U>sign <Tab><C-U>')
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
      :^                               |
    ]])

    -- Using <C-E> to cancel the popup menu and then pressing <Up> should recall
    -- the cmdline from history
    feed('sign xyz<Esc>:sign <Tab><C-E><Up>')
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
      :sign xyz^                       |
    ]])

    feed('<esc>')

    -- Check "list" still works
    command('set wildmode=longest,list')
    feed(':cn<Tab>')
    screen:expect([[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {4:                                }|
      :cn                             |
      cnewer       cnoreabbrev        |
      cnext        cnoremap           |
      cnfile       cnoremenu          |
      :cn^                             |
    ]])
    feed('s')
    screen:expect([[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {4:                                }|
      :cn                             |
      cnewer       cnoreabbrev        |
      cnext        cnoremap           |
      cnfile       cnoremenu          |
      :cns^                            |
    ]])

    feed('<esc>')
    command('set wildmode=full')

    -- Tests a directory name contained full-width characters.
    feed(':e あいう/<Tab>')
    screen:expect([[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~        }{s: 123            }{1:       }|
      {1:~        }{n: abc            }{1:       }|
      {1:~        }{n: xyz            }{1:       }|
      :e あいう/123^                   |
    ]])
    feed('<Esc>')

    -- Pressing <PageDown> should scroll the menu downward
    feed(':sign <Tab><PageDown>')
    screen:expect([[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~    }{n: define         }{1:           }|
      {1:~    }{n: jump           }{1:           }|
      {1:~    }{n: list           }{1:           }|
      {1:~    }{n: place          }{1:           }|
      {1:~    }{s: undefine       }{1:           }|
      {1:~    }{n: unplace        }{1:           }|
      :sign undefine^                  |
    ]])
    feed('<PageDown>')
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
    feed('<PageDown>')
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
    feed('<PageDown>')
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
    feed('<C-U>sign <Tab><Right><Right><PageDown>')
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

    -- Pressing <PageUp> should scroll the menu upward
    feed('<C-U>sign <Tab><PageUp>')
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
    feed('<PageUp>')
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
    feed('<PageUp>')
    screen:expect([[
                                      |
      {1:~                               }|
      {1:~                               }|
      {1:~    }{n: define         }{1:           }|
      {1:~    }{s: jump           }{1:           }|
      {1:~    }{n: list           }{1:           }|
      {1:~    }{n: place          }{1:           }|
      {1:~    }{n: undefine       }{1:           }|
      {1:~    }{n: unplace        }{1:           }|
      :sign jump^                      |
    ]])
    feed('<PageUp>')
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

    feed('<Esc>')

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

    feed('<esc>')
    command("close")
    command('set wildmode=full')

    -- special case: when patterns ends with "/", show menu items aligned
    -- after the "/"
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
      :e compdir/file1^                                  |
    ]])
  end)

  it('wildoptions=pum with scrolled messages', function()
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

  it('wildoptions=pum and wildmode=longest,full #11622', function()
    screen:try_resize(30,8)
    command('set wildmenu')
    command('set wildoptions=pum')
    command('set wildmode=longest,full')

    -- With 'wildmode' set to 'longest,full', completing a match should display
    -- the longest match, the wildmenu should not be displayed.
    feed(':sign u<Tab>')
    screen:expect{grid=[[
                                    |
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      :sign un^                      |
    ]]}
    eq(0, funcs.wildmenumode())

    -- pressing <Tab> should display the wildmenu
    feed('<Tab>')
    screen:expect{grid=[[
                                    |
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~    }{s: undefine       }{1:         }|
      {1:~    }{n: unplace        }{1:         }|
      :sign undefine^                |
    ]]}
    eq(1, funcs.wildmenumode())

    -- pressing <Tab> second time should select the next entry in the menu
    feed('<Tab>')
    screen:expect{grid=[[
                                    |
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~                             }|
      {1:~    }{n: undefine       }{1:         }|
      {1:~    }{s: unplace        }{1:         }|
      :sign unplace^                 |
    ]]}
  end)

  it('wildoptions=pum with a wrapped line in buffer vim-patch:8.2.4655', function()
    screen:try_resize(32, 10)
    meths.buf_set_lines(0, 0, -1, true, { ('a'):rep(100) })
    command('set wildoptions+=pum')
    feed('$')
    feed(':sign <Tab>')
    screen:expect([[
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa|
      aaaa {s: define         }           |
      {1:~    }{n: jump           }{1:           }|
      {1:~    }{n: list           }{1:           }|
      {1:~    }{n: place          }{1:           }|
      {1:~    }{n: undefine       }{1:           }|
      {1:~    }{n: unplace        }{1:           }|
      :sign define^                    |
    ]])
  end)

  -- oldtest: Test_wildmenu_pum_clear_entries()
  it('wildoptions=pum when using Ctrl-E as wildchar vim-patch:9.0.1030', function()
    screen:try_resize(30, 10)
    exec([[
      set wildoptions=pum
      set wildchar=<C-E>
    ]])
    feed(':sign <C-E><C-E>')
    screen:expect([[
                                    |
      {1:~                             }|
      {1:~                             }|
      {1:~    }{s: define         }{1:         }|
      {1:~    }{n: jump           }{1:         }|
      {1:~    }{n: list           }{1:         }|
      {1:~    }{n: place          }{1:         }|
      {1:~    }{n: undefine       }{1:         }|
      {1:~    }{n: unplace        }{1:         }|
      :sign define^                  |
    ]])
    assert_alive()
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

    -- can disable blending for individual attribute. For instance current
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

  it("'pumheight'", function()
    screen:try_resize(32,8)
    feed('isome long prefix before the ')
    command("set completeopt+=noinsert,noselect")
    command("set linebreak")
    command("set pumheight=2")
    funcs.complete(29, {'word', 'choice', 'text', 'thing'})
    screen:expect([[
      some long prefix before the ^    |
      {1:~                       }{n: word  }{c: }|
      {1:~                       }{n: choice}{s: }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {2:-- INSERT --}                    |
    ]])
  end)

  it("'pumwidth'", function()
    screen:try_resize(32,8)
    feed('isome long prefix before the ')
    command("set completeopt+=noinsert,noselect")
    command("set linebreak")
    command("set pumwidth=8")
    funcs.complete(29, {'word', 'choice', 'text', 'thing'})
    screen:expect([[
      some long prefix before the ^    |
      {1:~                        }{n: word  }|
      {1:~                        }{n: choice}|
      {1:~                        }{n: text  }|
      {1:~                        }{n: thing }|
      {1:~                               }|
      {1:~                               }|
      {2:-- INSERT --}                    |
    ]])
  end)

  it('does not crash when displayed in the last column with rightleft (#12032)', function()
    local col = 30
    local items = {'word', 'choice', 'text', 'thing'}
    local max_len = 0
    for _, v in ipairs(items) do
      max_len = max_len < #v and #v or max_len
    end
    screen:try_resize(col, 8)
    command('set rightleft')
    command('call setline(1, repeat(" ", &columns - '..max_len..'))')
    feed('$i')
    funcs.complete(col - max_len, items)
    feed('<c-y>')
    assert_alive()
  end)

  it('truncates double-width character correctly when there is no scrollbar', function()
    screen:try_resize(32,8)
    command('set completeopt+=menuone,noselect')
    feed('i' .. string.rep(' ', 13))
    funcs.complete(14, {'哦哦哦哦哦哦哦哦哦哦'})
    screen:expect([[
                   ^                   |
      {1:~           }{n: 哦哦哦哦哦哦哦哦哦>}|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {2:-- INSERT --}                    |
    ]])
  end)

  it('truncates double-width character correctly when there is scrollbar', function()
    screen:try_resize(32,8)
    command('set completeopt+=noselect')
    command('set pumheight=4')
    feed('i' .. string.rep(' ', 12))
    local items = {}
    for _ = 1, 8 do
      table.insert(items, {word = '哦哦哦哦哦哦哦哦哦哦', equal = 1, dup = 1})
    end
    funcs.complete(13, items)
    screen:expect([[
                  ^                    |
      {1:~          }{n: 哦哦哦哦哦哦哦哦哦>}{c: }|
      {1:~          }{n: 哦哦哦哦哦哦哦哦哦>}{c: }|
      {1:~          }{n: 哦哦哦哦哦哦哦哦哦>}{s: }|
      {1:~          }{n: 哦哦哦哦哦哦哦哦哦>}{s: }|
      {1:~                               }|
      {1:~                               }|
      {2:-- INSERT --}                    |
    ]])
  end)

  it('supports mousemodel=popup', function()
    screen:try_resize(32, 6)
    exec([[
      call setline(1, 'popup menu test')
      set mouse=a mousemodel=popup

      aunmenu PopUp
      menu PopUp.foo :let g:menustr = 'foo'<CR>
      menu PopUp.bar :let g:menustr = 'bar'<CR>
      menu PopUp.baz :let g:menustr = 'baz'<CR>
    ]])
    feed('<RightMouse><4,0>')
    screen:expect([[
      ^popup menu test                 |
      {1:~  }{n: foo }{1:                        }|
      {1:~  }{n: bar }{1:                        }|
      {1:~  }{n: baz }{1:                        }|
      {1:~                               }|
                                      |
    ]])
    feed('<Down>')
    screen:expect([[
      ^popup menu test                 |
      {1:~  }{s: foo }{1:                        }|
      {1:~  }{n: bar }{1:                        }|
      {1:~  }{n: baz }{1:                        }|
      {1:~                               }|
                                      |
    ]])
    feed('<Down>')
    screen:expect([[
      ^popup menu test                 |
      {1:~  }{n: foo }{1:                        }|
      {1:~  }{s: bar }{1:                        }|
      {1:~  }{n: baz }{1:                        }|
      {1:~                               }|
                                      |
    ]])
    feed('<CR>')
    screen:expect([[
      ^popup menu test                 |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      :let g:menustr = 'bar'          |
    ]])
    eq('bar', meths.get_var('menustr'))
    feed('<RightMouse><20,1>')
    screen:expect([[
      ^popup menu test                 |
      {1:~                               }|
      {1:~                  }{n: foo }{1:        }|
      {1:~                  }{n: bar }{1:        }|
      {1:~                  }{n: baz }{1:        }|
      :let g:menustr = 'bar'          |
    ]])
    feed('<LeftMouse><22,4>')
    screen:expect([[
      ^popup menu test                 |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      :let g:menustr = 'baz'          |
    ]])
    eq('baz', meths.get_var('menustr'))
    feed('<RightMouse><4,0>')
    screen:expect([[
      ^popup menu test                 |
      {1:~  }{n: foo }{1:                        }|
      {1:~  }{n: bar }{1:                        }|
      {1:~  }{n: baz }{1:                        }|
      {1:~                               }|
      :let g:menustr = 'baz'          |
    ]])
    feed('<RightDrag><6,3>')
    screen:expect([[
      ^popup menu test                 |
      {1:~  }{n: foo }{1:                        }|
      {1:~  }{n: bar }{1:                        }|
      {1:~  }{s: baz }{1:                        }|
      {1:~                               }|
      :let g:menustr = 'baz'          |
    ]])
    feed('<RightRelease><6,1>')
    screen:expect([[
      ^popup menu test                 |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      :let g:menustr = 'foo'          |
    ]])
    eq('foo', meths.get_var('menustr'))
    eq(false, screen.options.mousemoveevent)
    feed('<RightMouse><4,0>')
    screen:expect([[
      ^popup menu test                 |
      {1:~  }{n: foo }{1:                        }|
      {1:~  }{n: bar }{1:                        }|
      {1:~  }{n: baz }{1:                        }|
      {1:~                               }|
      :let g:menustr = 'foo'          |
    ]])
    eq(true, screen.options.mousemoveevent)
    feed('<MouseMove><6,3>')
    screen:expect([[
      ^popup menu test                 |
      {1:~  }{n: foo }{1:                        }|
      {1:~  }{n: bar }{1:                        }|
      {1:~  }{s: baz }{1:                        }|
      {1:~                               }|
      :let g:menustr = 'foo'          |
    ]])
    eq(true, screen.options.mousemoveevent)
    feed('<LeftMouse><6,2>')
    screen:expect([[
      ^popup menu test                 |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      :let g:menustr = 'bar'          |
    ]])
    eq(false, screen.options.mousemoveevent)
    eq('bar', meths.get_var('menustr'))
  end)

  -- oldtest: Test_popup_command_dump()
  it(':popup command', function()
    exec([[
      func ChangeMenu()
        aunmenu PopUp.&Paste
        nnoremenu 1.40 PopUp.&Paste :echomsg "pasted"<CR>
        echomsg 'changed'
        return "\<Ignore>"
      endfunc

      let lines =<< trim END
        one two three four five
        and one two Xthree four five
        one more two three four five
      END
      call setline(1, lines)

      aunmenu *
      source $VIMRUNTIME/menu.vim
    ]])
    feed('/X<CR>:popup PopUp<CR>')
    screen:expect([[
      one two three four five         |
      and one two {7:^X}three four five    |
      one more tw{n: Undo             }   |
      {1:~          }{n:                  }{1:   }|
      {1:~          }{n: Paste            }{1:   }|
      {1:~          }{n:                  }{1:   }|
      {1:~          }{n: Select Word      }{1:   }|
      {1:~          }{n: Select Sentence  }{1:   }|
      {1:~          }{n: Select Paragraph }{1:   }|
      {1:~          }{n: Select Line      }{1:   }|
      {1:~          }{n: Select Block     }{1:   }|
      {1:~          }{n: Select All       }{1:   }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      :popup PopUp                    |
    ]])

    -- go to the Paste entry in the menu
    feed('jj')
    screen:expect([[
      one two three four five         |
      and one two {7:^X}three four five    |
      one more tw{n: Undo             }   |
      {1:~          }{n:                  }{1:   }|
      {1:~          }{s: Paste            }{1:   }|
      {1:~          }{n:                  }{1:   }|
      {1:~          }{n: Select Word      }{1:   }|
      {1:~          }{n: Select Sentence  }{1:   }|
      {1:~          }{n: Select Paragraph }{1:   }|
      {1:~          }{n: Select Line      }{1:   }|
      {1:~          }{n: Select Block     }{1:   }|
      {1:~          }{n: Select All       }{1:   }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      :popup PopUp                    |
    ]])

    -- Select a word
    feed('j')
    screen:expect([[
      one two three four five         |
      and one two {7:^X}three four five    |
      one more tw{n: Undo             }   |
      {1:~          }{n:                  }{1:   }|
      {1:~          }{n: Paste            }{1:   }|
      {1:~          }{n:                  }{1:   }|
      {1:~          }{s: Select Word      }{1:   }|
      {1:~          }{n: Select Sentence  }{1:   }|
      {1:~          }{n: Select Paragraph }{1:   }|
      {1:~          }{n: Select Line      }{1:   }|
      {1:~          }{n: Select Block     }{1:   }|
      {1:~          }{n: Select All       }{1:   }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      :popup PopUp                    |
    ]])

    feed('<Esc>')

    -- Set an <expr> mapping to change a menu entry while it's displayed.
    -- The text should not change but the command does.
    -- Also verify that "changed" shows up, which means the mapping triggered.
    command('nnoremap <expr> <F2> ChangeMenu()')
    feed('/X<CR>:popup PopUp<CR><F2>')
    screen:expect([[
      one two three four five         |
      and one two {7:^X}three four five    |
      one more tw{n: Undo             }   |
      {1:~          }{n:                  }{1:   }|
      {1:~          }{n: Paste            }{1:   }|
      {1:~          }{n:                  }{1:   }|
      {1:~          }{n: Select Word      }{1:   }|
      {1:~          }{n: Select Sentence  }{1:   }|
      {1:~          }{n: Select Paragraph }{1:   }|
      {1:~          }{n: Select Line      }{1:   }|
      {1:~          }{n: Select Block     }{1:   }|
      {1:~          }{n: Select All       }{1:   }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      changed                         |
    ]])

    -- Select the Paste entry, executes the changed menu item.
    feed('jj<CR>')
    screen:expect([[
      one two three four five         |
      and one two {7:^X}three four five    |
      one more two three four five    |
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
      {1:~                               }|
      {1:~                               }|
      pasted                          |
    ]])
  end)
end)

describe('builtin popupmenu with ui/ext_multigrid', function()
  local screen
  before_each(function()
    clear()
    screen = Screen.new(32, 20)
    screen:attach({ext_multigrid=true})
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

  it('truncates double-width character correctly when there is no scrollbar', function()
    screen:try_resize(32,8)
    command('set completeopt+=menuone,noselect')
    feed('i' .. string.rep(' ', 13))
    funcs.complete(14, {'哦哦哦哦哦哦哦哦哦哦'})
    screen:expect({grid=[[
      ## grid 1
        [2:--------------------------------]|
        [2:--------------------------------]|
        [2:--------------------------------]|
        [2:--------------------------------]|
        [2:--------------------------------]|
        [2:--------------------------------]|
        [2:--------------------------------]|
        [3:--------------------------------]|
      ## grid 2
                     ^                   |
        {1:~                               }|
        {1:~                               }|
        {1:~                               }|
        {1:~                               }|
        {1:~                               }|
        {1:~                               }|
      ## grid 3
        {2:-- INSERT --}                    |
      ## grid 4
        {n: 哦哦哦哦哦哦哦哦哦>}|
    ]], float_pos={[4] = {{id = -1}, 'NW', 2, 1, 12, false, 100}}})
  end)

  it('truncates double-width character correctly when there is scrollbar', function()
    screen:try_resize(32,8)
    command('set completeopt+=noselect')
    command('set pumheight=4')
    feed('i' .. string.rep(' ', 12))
    local items = {}
    for _ = 1, 8 do
      table.insert(items, {word = '哦哦哦哦哦哦哦哦哦哦', equal = 1, dup = 1})
    end
    funcs.complete(13, items)
    screen:expect({grid=[[
      ## grid 1
        [2:--------------------------------]|
        [2:--------------------------------]|
        [2:--------------------------------]|
        [2:--------------------------------]|
        [2:--------------------------------]|
        [2:--------------------------------]|
        [2:--------------------------------]|
        [3:--------------------------------]|
      ## grid 2
                    ^                    |
        {1:~                               }|
        {1:~                               }|
        {1:~                               }|
        {1:~                               }|
        {1:~                               }|
        {1:~                               }|
      ## grid 3
        {2:-- INSERT --}                    |
      ## grid 4
        {n: 哦哦哦哦哦哦哦哦哦>}{c: }|
        {n: 哦哦哦哦哦哦哦哦哦>}{c: }|
        {n: 哦哦哦哦哦哦哦哦哦>}{s: }|
        {n: 哦哦哦哦哦哦哦哦哦>}{s: }|
    ]], float_pos={[4] = {{id = -1}, 'NW', 2, 1, 11, false, 100}}})
  end)

  it('supports mousemodel=popup', function()
    screen:try_resize(32, 6)
    exec([[
      call setline(1, 'popup menu test')
      set mouse=a mousemodel=popup

      aunmenu PopUp
      menu PopUp.foo :let g:menustr = 'foo'<CR>
      menu PopUp.bar :let g:menustr = 'bar'<CR>
      menu PopUp.baz :let g:menustr = 'baz'<CR>
    ]])
    meths.input_mouse('right', 'press', '', 2, 1, 20)
    screen:expect({grid=[[
    ## grid 1
      [2:--------------------------------]|
      [2:--------------------------------]|
      [2:--------------------------------]|
      [2:--------------------------------]|
      [2:--------------------------------]|
      [3:--------------------------------]|
    ## grid 2
      ^popup menu test                 |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
    ## grid 3
                                      |
    ## grid 4
      {n: foo }|
      {n: bar }|
      {n: baz }|
    ]], float_pos={[4] = {{id = -1}, 'NW', 2, 2, 19, false, 100}}})
    meths.input_mouse('left', 'press', '', 4, 2, 2)
    screen:expect({grid=[[
    ## grid 1
      [2:--------------------------------]|
      [2:--------------------------------]|
      [2:--------------------------------]|
      [2:--------------------------------]|
      [2:--------------------------------]|
      [3:--------------------------------]|
    ## grid 2
      ^popup menu test                 |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
    ## grid 3
      :let g:menustr = 'baz'          |
    ]]})
    eq('baz', meths.get_var('menustr'))
    meths.input_mouse('right', 'press', '', 2, 0, 4)
    screen:expect({grid=[[
    ## grid 1
      [2:--------------------------------]|
      [2:--------------------------------]|
      [2:--------------------------------]|
      [2:--------------------------------]|
      [2:--------------------------------]|
      [3:--------------------------------]|
    ## grid 2
      ^popup menu test                 |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
    ## grid 3
      :let g:menustr = 'baz'          |
    ## grid 4
      {n: foo }|
      {n: bar }|
      {n: baz }|
    ]], float_pos={[4] = {{id = -1}, 'NW', 2, 1, 3, false, 100}}})
    meths.input_mouse('right', 'drag', '', 2, 3, 6)
    screen:expect({grid=[[
    ## grid 1
      [2:--------------------------------]|
      [2:--------------------------------]|
      [2:--------------------------------]|
      [2:--------------------------------]|
      [2:--------------------------------]|
      [3:--------------------------------]|
    ## grid 2
      ^popup menu test                 |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
    ## grid 3
      :let g:menustr = 'baz'          |
    ## grid 4
      {n: foo }|
      {n: bar }|
      {s: baz }|
    ]], float_pos={[4] = {{id = -1}, 'NW', 2, 1, 3, false, 100}}})
    meths.input_mouse('right', 'release', '', 2, 1, 6)
    screen:expect({grid=[[
    ## grid 1
      [2:--------------------------------]|
      [2:--------------------------------]|
      [2:--------------------------------]|
      [2:--------------------------------]|
      [2:--------------------------------]|
      [3:--------------------------------]|
    ## grid 2
      ^popup menu test                 |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
    ## grid 3
      :let g:menustr = 'foo'          |
    ]]})
    eq('foo', meths.get_var('menustr'))
    eq(false, screen.options.mousemoveevent)
    meths.input_mouse('right', 'press', '', 2, 0, 4)
    screen:expect({grid=[[
    ## grid 1
      [2:--------------------------------]|
      [2:--------------------------------]|
      [2:--------------------------------]|
      [2:--------------------------------]|
      [2:--------------------------------]|
      [3:--------------------------------]|
    ## grid 2
      ^popup menu test                 |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
    ## grid 3
      :let g:menustr = 'foo'          |
    ## grid 4
      {n: foo }|
      {n: bar }|
      {n: baz }|
    ]], float_pos={[4] = {{id = -1}, 'NW', 2, 1, 3, false, 100}}})
    eq(true, screen.options.mousemoveevent)
    meths.input_mouse('move', '', '', 2, 3, 6)
    screen:expect({grid=[[
    ## grid 1
      [2:--------------------------------]|
      [2:--------------------------------]|
      [2:--------------------------------]|
      [2:--------------------------------]|
      [2:--------------------------------]|
      [3:--------------------------------]|
    ## grid 2
      ^popup menu test                 |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
    ## grid 3
      :let g:menustr = 'foo'          |
    ## grid 4
      {n: foo }|
      {n: bar }|
      {s: baz }|
    ]], float_pos={[4] = {{id = -1}, 'NW', 2, 1, 3, false, 100}}})
    eq(true, screen.options.mousemoveevent)
    meths.input_mouse('left', 'press', '', 2, 2, 6)
    screen:expect({grid=[[
    ## grid 1
      [2:--------------------------------]|
      [2:--------------------------------]|
      [2:--------------------------------]|
      [2:--------------------------------]|
      [2:--------------------------------]|
      [3:--------------------------------]|
    ## grid 2
      ^popup menu test                 |
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
      {1:~                               }|
    ## grid 3
      :let g:menustr = 'bar'          |
    ]]})
    eq(false, screen.options.mousemoveevent)
    eq('bar', meths.get_var('menustr'))
  end)
end)
