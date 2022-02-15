local helpers = require('test.functional.helpers')(after_each)
local exec_lua = helpers.exec_lua
local eq = helpers.eq
local eval = helpers.eval
local command = helpers.command
local clear = helpers.clear
local Screen = require('test.functional.ui.screen')
local meths = helpers.meths

describe('vim.highlight.on_yank', function()

  before_each(function()
    clear()
  end)

  it('does not show errors even if buffer is wiped before timeout', function()
    command('new')
    exec_lua[[
      vim.highlight.on_yank({timeout = 10, on_macro = true, event = {operator = "y", regtype = "v"}})
      vim.cmd('bwipeout!')
    ]]
    helpers.sleep(10)
    helpers.feed('<cr>') -- avoid hang if error message exists
    eq('', eval('v:errmsg'))
  end)

end)

describe("vim.highlight.range", function ()
  local screen
  before_each(function ()
    clear()
    screen = Screen.new(40, 8)
    screen:attach()
    screen:set_default_attr_ids {
      [1] = {bold=true, foreground=Screen.colors.Blue};
      [2] = {foreground = Screen.colors.Red};
      [3] = {foreground = Screen.colors.Blue1};
    }
  end)

  it ('can overwrite older highlight', function ()
    for k,v in pairs {
      Hl1 = {bold=true, fg="Blue"};
      Hl2 = {fg="Red"};
      Hl3 = {fg="Magenta"};
    } do meths.set_hl(0, k, v) end

    meths.buf_set_lines(0, 0, -1, false, {"line1 ..... end", "line2 ..... end "})

    screen:expect{grid=[[
      ^line1 ..... end                         |
      line2 ..... end                         |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]]}

    exec_lua([[vim.highlight.range(0, 1, 'Hl2', {0, 0}, {1, -1})]])
    screen:expect{grid=[[
      {2:^line1 ..... end}                         |
      {2:line2 ..... end }                        |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]]}

    exec_lua([[vim.highlight.range(0, 1, 'Hl3', {0, 0}, {0, -1})]])
    screen:expect{grid=[[
      {4:^line1 ..... end}                         |
      {2:line2 ..... end }                        |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]], attr_ids={
      [1] = {foreground = Screen.colors.Blue1, bold = true};
      [2] = {foreground = Screen.colors.Red};
      [3] = {foreground = Screen.colors.Blue1};
      [4] = {foreground = Screen.colors.Magenta};
    }}

    exec_lua([[vim.highlight.range(0, 1, 'Hl1', {0, 0}, {0, -1})]])
    screen:expect{grid=[[
      {1:^line1 ..... end}                         |
      {2:line2 ..... end }                        |
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
      {1:~                                       }|
                                              |
    ]]}
  end)
end)
