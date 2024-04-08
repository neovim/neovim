local t = require('test.functional.testutil')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = t.clear
local command = t.command
local expect = t.expect
local feed = t.feed
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
    screen:attach()
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
  end)

  -- oldtest: Test_edit_ctrl_r_failed()
  it('positioning cursor after CTRL-R expression failed', function()
    local screen = Screen.new(60, 6)
    screen:attach()

    feed('i<C-R>')
    screen:expect([[
      {18:^"}                                                           |
      {1:~                                                           }|*4
      {5:-- INSERT --}                                                |
    ]])
    feed('={}')
    screen:expect([[
      {18:"}                                                           |
      {1:~                                                           }|*4
      ={16:{}}^                                                         |
    ]])
    -- trying to insert a dictionary produces an error
    feed('<CR>')
    screen:expect([[
      {18:"}                                                           |
      {1:~                                                           }|
      {3:                                                            }|
      ={16:{}}                                                         |
      {9:E731: Using a Dictionary as a String}                        |
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
end)
