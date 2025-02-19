local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local command = n.command
local expect = n.expect
local feed = n.feed
local sleep = vim.uv.sleep

before_each(clear)

describe('edit', function()
  -- oldtest: Test_autoindent_remove_indent()
  it('autoindent removes indent when Insert mode is stopped', function()
    command('set autoindent')
    -- leaving insert mode in a new line with indent added by autoindent, should
    -- remove the indent.
    feed('i<Tab>foo<CR><Esc>')
    -- Need to delay for sometime, otherwise the code in getchar.c will not be
    -- exercised.
    sleep(50)
    -- when a line is wrapped and the cursor is at the start of the second line,
    -- leaving insert mode, should move the cursor back to the first line.
    feed('o' .. ('x'):rep(20) .. '<Esc>')
    -- Need to delay for sometime, otherwise the code in getchar.c will not be
    -- exercised.
    sleep(50)
    expect('\tfoo\n\n' .. ('x'):rep(20))
  end)

  -- oldtest: Test_edit_insert_reg()
  it('inserting a register using CTRL-R', function()
    local screen = Screen.new(10, 6)
    feed('a<C-R>')
    screen:expect([[
      {18:^"}           |
      {1:~           }|*4
      {5:-- INSERT --}|
    ]])
    feed('=')
    screen:expect([[
      {18:"}           |
      {1:~           }|*4
      =^           |
    ]])
    feed([['r'<CR><Esc>]])
    expect('r')
    -- Test for inserting null and empty list
    feed('a<C-R>=v:_null_list<CR><Esc>')
    feed('a<C-R>=[]<CR><Esc>')
    expect('r')
  end)

  -- oldtest: Test_edit_ctrl_r_failed()
  it('positioning cursor after CTRL-R expression failed', function()
    local screen = Screen.new(60, 6)

    feed('i<C-R>')
    screen:expect([[
      {18:^"}                                                           |
      {1:~                                                           }|*4
      {5:-- INSERT --}                                                |
    ]])
    feed('=0z')
    screen:expect([[
      {18:"}                                                           |
      {1:~                                                           }|*4
      ={26:0}{9:z}^                                                         |
    ]])
    -- trying to insert a blob produces an error
    feed('<CR>')
    screen:expect([[
      {18:"}                                                           |
      {1:~                                                           }|
      {3:                                                            }|
      ={26:0}{9:z}                                                         |
      {9:E976: Using a Blob as a String}                              |
      {6:Press ENTER or type command to continue}^                     |
    ]])

    feed(':')
    screen:expect([[
      :^                                                           |
      {1:~                                                           }|*4
      {5:-- INSERT --}                                                |
    ]])
    -- ending Insert mode should put the cursor back on the ':'
    feed('<Esc>')
    screen:expect([[
      ^:                                                           |
      {1:~                                                           }|*4
                                                                  |
    ]])
  end)

  -- oldtest: Test_edit_CAR()
  it('Enter inserts newline with pum at original text after adding leader', function()
    local screen = Screen.new(10, 6)
    command('set cot=menu,menuone,noselect')
    feed('Shello hero<CR>h<C-X><C-N>e')
    screen:expect([[
      hello hero  |
      he^          |
      {4:hello       }|
      {4:hero        }|
      {1:~           }|
      {5:--}          |
    ]])

    feed('<CR>')
    screen:expect([[
      hello hero  |
      he          |
      ^            |
      {1:~           }|*2
      {5:-- INSERT --}|
    ]])
  end)
end)
