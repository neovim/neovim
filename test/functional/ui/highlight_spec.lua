local helpers = require('test.functional.helpers')
local Screen = require('test.functional.ui.screen')
local clear, feed = helpers.clear, helpers.feed
local execute, request, eq = helpers.execute, helpers.request, helpers.eq


describe('color scheme compatibility', function()
  before_each(function()
    clear()
  end)

  it('t_Co is set to 256 by default', function()
    eq('256', request('vim_eval', '&t_Co'))
    request('vim_set_option', 't_Co', '88')
    eq('88', request('vim_eval', '&t_Co'))
  end)

  it('emulates gui_running when a rgb UI is attached', function()
    eq(0, request('vim_eval', 'has("gui_running")'))
    local screen = Screen.new()
    screen:attach()
    eq(1, request('vim_eval', 'has("gui_running")'))
    screen:detach()
    eq(0, request('vim_eval', 'has("gui_running")'))
  end)
end)


describe('Default highlight groups', function()
  -- Test the default attributes for highlight groups shown by the :highlight
  -- command
  local screen

  local hlgroup_colors = {
    NonText = Screen.colors.Blue,
    Question = Screen.colors.SeaGreen
  }

  before_each(function()
    clear()
    screen = Screen.new()
    screen:attach()
    --ignore highligting of ~-lines
    screen:set_default_attr_ignore( {{bold=true, foreground=hlgroup_colors.NonText}} )
  end)

  after_each(function()
    screen:detach()
  end)
  it('window status bar', function()
    screen:set_default_attr_ids({
      [1] = {reverse = true, bold = true},  -- StatusLine
      [2] = {reverse = true}                -- StatusLineNC
    })
    execute('sp', 'vsp', 'vsp')
    screen:expect([[
      ^                    {2:|}                {2:|}               |
      ~                   {2:|}~               {2:|}~              |
      ~                   {2:|}~               {2:|}~              |
      ~                   {2:|}~               {2:|}~              |
      ~                   {2:|}~               {2:|}~              |
      ~                   {2:|}~               {2:|}~              |
      {1:[No Name]            }{2:[No Name]        [No Name]      }|
                                                           |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      {2:[No Name]                                            }|
                                                           |
    ]])
    -- navigate to verify that the attributes are properly moved
    feed('<c-w>j')
    screen:expect([[
                          {2:|}                {2:|}               |
      ~                   {2:|}~               {2:|}~              |
      ~                   {2:|}~               {2:|}~              |
      ~                   {2:|}~               {2:|}~              |
      ~                   {2:|}~               {2:|}~              |
      ~                   {2:|}~               {2:|}~              |
      {2:[No Name]            [No Name]        [No Name]      }|
      ^                                                     |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      {1:[No Name]                                            }|
                                                           |
    ]])
    -- note that when moving to a window with small width nvim will increase
    -- the width of the new active window at the expense of a inactive window
    -- (upstream vim has the same behavior)
    feed('<c-w>k<c-w>l')
    screen:expect([[
                          {2:|}^                    {2:|}           |
      ~                   {2:|}~                   {2:|}~          |
      ~                   {2:|}~                   {2:|}~          |
      ~                   {2:|}~                   {2:|}~          |
      ~                   {2:|}~                   {2:|}~          |
      ~                   {2:|}~                   {2:|}~          |
      {2:[No Name]            }{1:[No Name]            }{2:[No Name]  }|
                                                           |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      {2:[No Name]                                            }|
                                                           |
    ]])
    feed('<c-w>l')
    screen:expect([[
                          {2:|}           {2:|}^                    |
      ~                   {2:|}~          {2:|}~                   |
      ~                   {2:|}~          {2:|}~                   |
      ~                   {2:|}~          {2:|}~                   |
      ~                   {2:|}~          {2:|}~                   |
      ~                   {2:|}~          {2:|}~                   |
      {2:[No Name]            [No Name]   }{1:[No Name]           }|
                                                           |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      {2:[No Name]                                            }|
                                                           |
    ]])
    feed('<c-w>h<c-w>h')
    screen:expect([[
      ^                    {2:|}                    {2:|}           |
      ~                   {2:|}~                   {2:|}~          |
      ~                   {2:|}~                   {2:|}~          |
      ~                   {2:|}~                   {2:|}~          |
      ~                   {2:|}~                   {2:|}~          |
      ~                   {2:|}~                   {2:|}~          |
      {1:[No Name]            }{2:[No Name]            [No Name]  }|
                                                           |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      {2:[No Name]                                            }|
                                                           |
    ]])
  end)

  it('insert mode text', function()
    feed('i')
    screen:expect([[
      ^                                                     |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      {1:-- INSERT --}                                         |
    ]], {[1] = {bold = true}})
  end)

  it('end of file markers', function()
    screen:expect([[
      ^                                                     |
      {1:~                                                    }|
      {1:~                                                    }|
      {1:~                                                    }|
      {1:~                                                    }|
      {1:~                                                    }|
      {1:~                                                    }|
      {1:~                                                    }|
      {1:~                                                    }|
      {1:~                                                    }|
      {1:~                                                    }|
      {1:~                                                    }|
      {1:~                                                    }|
                                                           |
    ]], {[1] = {bold = true, foreground = hlgroup_colors.NonText}})
  end)

  it('"wait return" text', function()
    feed(':ls<cr>')
    screen:expect([[
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      ~                                                    |
      :ls                                                  |
        1 %a   "[No Name]"                    line 1       |
      {1:Press ENTER or type command to continue}^              |
    ]], {[1] = {bold = true, foreground = hlgroup_colors.Question}})
    feed('<cr>') --  skip the "Press ENTER..." state or tests will hang
  end)
end)
