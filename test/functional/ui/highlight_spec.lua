local helpers = require('test.functional.helpers')
local Screen = require('test.functional.ui.screen')
local os = require('os')
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
end)

describe('manual syntax highlight', function()
  -- When using manual syntax highlighting, it should be preserved even when
  -- switching buffers... bug did only occur without :set hidden
  -- Ref: vim patch 7.4.1236
  local screen

  before_each(function()
    clear()
    screen = Screen.new(20,5)
    screen:attach()
    --ignore highligting of ~-lines
    screen:set_default_attr_ignore( {{bold=true, foreground=Screen.colors.Blue}} )
    --syntax highlight for vimcscripts "echo"
    screen:set_default_attr_ids( {[1] = {bold=true, foreground=Screen.colors.Brown}} )
  end)

  after_each(function()
    screen:detach()
    os.remove('Xtest-functional-ui-highlight.tmp.vim')
  end)

  -- test with "set hidden" even if the bug did not occur this way
  it("works with buffer switch and 'hidden'", function()
    execute('e tmp1.vim')
    execute('e Xtest-functional-ui-highlight.tmp.vim')
    execute('filetype on')
    execute('syntax manual')
    execute('set ft=vim')
    execute('set syntax=ON')
    feed('iecho 1<esc>0')

    execute('set hidden')
    execute('w')
    execute('bn')
    execute('bp')
    screen:expect([[
      {1:^echo} 1              |
      ~                   |
      ~                   |
      ~                   |
      <f 1 --100%-- col 1 |
    ]])
  end)

  it("works with buffer switch and 'nohidden'", function()
    execute('e tmp1.vim')
    execute('e Xtest-functional-ui-highlight.tmp.vim')
    execute('filetype on')
    execute('syntax manual')
    execute('set ft=vim')
    execute('set syntax=ON')
    feed('iecho 1<esc>0')

    execute('set nohidden')
    execute('w')
    execute('bn')
    execute('bp')
    screen:expect([[
      {1:^echo} 1              |
      ~                   |
      ~                   |
      ~                   |
      <ht.tmp.vim" 1L, 7C |
    ]])
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
  it('can be cleared and linked to other highlight groups', function()
    execute('highlight clear ModeMsg')
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
      -- INSERT --                                         |
    ]], {})
    feed('<esc>')
    execute('highlight CustomHLGroup guifg=red guibg=green')
    execute('highlight link ModeMsg CustomHLGroup')
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
    ]], {[1] = {foreground = Screen.colors.Red, background = Screen.colors.Green}})
  end)
end)

describe("'cursorline' with 'listchars'", function()
  local screen

  local hlgroup_colors = {
    NonText = Screen.colors.Blue,
    Cursorline = Screen.colors.Grey90,
    SpecialKey = Screen.colors.Red,
  }

  before_each(function()
    clear()
    screen = Screen.new(20,5)
    screen:attach()
  end)

  after_each(function()
    screen:detach()
  end)

  it("'cursorline' and 'cursorcolumn'", function()
    screen:set_default_attr_ids({[1] = {background=hlgroup_colors.Cursorline}})
    screen:set_default_attr_ignore( {{bold=true, foreground=hlgroup_colors.NonText}} )
    execute('highlight clear ModeMsg')
    execute('set cursorline')
    feed('i')
    screen:expect([[
      {1:^                    }|
      ~                   |
      ~                   |
      ~                   |
      -- INSERT --        |
    ]])
    feed('abcdefg<cr>kkasdf')
    screen:expect([[
      abcdefg             |
      {1:kkasdf^              }|
      ~                   |
      ~                   |
      -- INSERT --        |
    ]])
    feed('<esc>')
    screen:expect([[
      abcdefg             |
      {1:kkasd^f              }|
      ~                   |
      ~                   |
                          |
    ]])
    execute('set nocursorline')
    screen:expect([[
      abcdefg             |
      kkasd^f              |
      ~                   |
      ~                   |
      :set nocursorline   |
    ]])
    feed('k')
    screen:expect([[
      abcde^fg             |
      kkasdf              |
      ~                   |
      ~                   |
      :set nocursorline   |
    ]])
    feed('jjji<cr><cr><cr><esc>')
    screen:expect([[
      kkasd               |
                          |
                          |
      ^f                   |
                          |
    ]])
    execute('set cursorline')
    execute('set cursorcolumn')
    feed('kkiabcdefghijk<esc>hh')
    screen:expect([[
      kkasd   {1: }           |
      {1:abcdefgh^ijk         }|
              {1: }           |
      f       {1: }           |
                          |
    ]])
    feed('khh')
    screen:expect([[
      {1:kk^asd               }|
      ab{1:c}defghijk         |
        {1: }                 |
      f {1: }                 |
                          |
    ]])
  end)

  it("'cursorline' and with 'listchar' option: space, eol, tab, and trail", function()
    screen:set_default_attr_ids({
      [1] = {background=hlgroup_colors.Cursorline},
      [2] = {
        foreground=hlgroup_colors.SpecialKey,
        background=hlgroup_colors.Cursorline,
      },
      [3] = {
        background=hlgroup_colors.Cursorline,
        foreground=hlgroup_colors.NonText,
        bold=true,
      },
      [4] = {
        foreground=hlgroup_colors.NonText,
        bold=true,
      },
      [5] = {
        foreground=hlgroup_colors.SpecialKey,
      },
    })
    execute('highlight clear ModeMsg')
    execute('highlight SpecialKey guifg=#FF0000')
    execute('set cursorline')
    execute('set tabstop=8')
    execute('set listchars=space:.,eol:¬,tab:>-,extends:],precedes:[,trail:* list')
    feed('i\t abcd <cr>\t abcd <cr><esc>k')
    screen:expect([[
      {5:>-------.}abcd{5:*}{4:¬}     |
      {2:^>-------.}{1:abcd}{2:*}{3:¬}{1:     }|
      {4:¬}                   |
      {4:~                   }|
                          |
    ]])
    feed('k')
    screen:expect([[
      {2:^>-------.}{1:abcd}{2:*}{3:¬}{1:     }|
      {5:>-------.}abcd{5:*}{4:¬}     |
      {4:¬}                   |
      {4:~                   }|
                          |
    ]])
    execute('set nocursorline')
    screen:expect([[
      {5:^>-------.}abcd{5:*}{4:¬}     |
      {5:>-------.}abcd{5:*}{4:¬}     |
      {4:¬}                   |
      {4:~                   }|
      :set nocursorline   |
    ]])
  end)
end)
