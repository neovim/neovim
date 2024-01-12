local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local command = helpers.command
local expect = helpers.expect
local feed = helpers.feed
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
    screen:set_default_attr_ids({
      [0] = { bold = true, foreground = Screen.colors.Blue }, -- NonText
      [1] = { foreground = Screen.colors.Blue }, -- SpecialKey
      [2] = { bold = true }, -- ModeMsg
    })
    screen:attach()
    feed('a<C-R>')
    screen:expect([[
      {1:^"}           |
      {0:~           }|*4
      {2:-- INSERT --}|
    ]])
    feed('=')
    screen:expect([[
      {1:"}           |
      {0:~           }|*4
      =^           |
    ]])
  end)

  -- oldtest: Test_edit_ctrl_r_failed()
  it('positioning cursor after CTRL-R expression failed', function()
    local screen = Screen.new(60, 6)
    screen:set_default_attr_ids({
      [0] = { bold = true, foreground = Screen.colors.Blue }, -- NonText
      [1] = { foreground = Screen.colors.Blue }, -- SpecialKey
      [2] = { foreground = Screen.colors.SlateBlue },
      [3] = { bold = true }, -- ModeMsg
      [4] = { reverse = true, bold = true }, -- MsgSeparator
      [5] = { background = Screen.colors.Red, foreground = Screen.colors.White }, -- ErrorMsg
      [6] = { foreground = Screen.colors.SeaGreen, bold = true }, -- MoreMsg
    })
    screen:attach()

    feed('i<C-R>')
    screen:expect([[
      {1:^"}                                                           |
      {0:~                                                           }|*4
      {3:-- INSERT --}                                                |
    ]])
    feed('={}')
    screen:expect([[
      {1:"}                                                           |
      {0:~                                                           }|*4
      ={2:{}}^                                                         |
    ]])
    -- trying to insert a dictionary produces an error
    feed('<CR>')
    screen:expect([[
      {1:"}                                                           |
      {0:~                                                           }|
      {4:                                                            }|
      ={2:{}}                                                         |
      {5:E731: Using a Dictionary as a String}                        |
      {6:Press ENTER or type command to continue}^                     |
    ]])

    feed(':')
    screen:expect([[
      :^                                                           |
      {0:~                                                           }|*4
      {3:-- INSERT --}                                                |
    ]])
    -- ending Insert mode should put the cursor back on the ':'
    feed('<Esc>')
    screen:expect([[
      ^:                                                           |
      {0:~                                                           }|*4
                                                                  |
    ]])
  end)
end)
