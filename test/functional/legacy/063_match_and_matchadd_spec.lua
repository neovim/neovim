-- Tests for adjusting window and contents

local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local clear, command = helpers.clear, helpers.command
local insert = helpers.insert

describe('063: Test for ":match", "matchadd()" and related functions', function()
  setup(clear)

  it('is working', function()
    local screen = Screen.new(40, 5)
    screen:attach()
    screen:set_default_attr_ids({
      [0] = {bold = true, foreground = Screen.colors.Blue},
      [1] = {background = Screen.colors.Red},
    })

    command("highlight MyGroup1 term=bold ctermbg=red guibg=red")
    command("highlight MyGroup2 term=italic ctermbg=green guibg=green")
    command("highlight MyGroup3 term=underline ctermbg=blue guibg=blue")

    -- Check that "matchaddpos()" positions matches correctly
    insert('abcdefghijklmnopq')
    command("call matchaddpos('MyGroup1', [[1, 5], [1, 8, 3]], 10, 3)")
    screen:expect([[
      abcd{1:e}fg{1:hij}klmnop^q                       |
      {0:~                                       }|
      {0:~                                       }|
      {0:~                                       }|
                                              |
    ]])

    command("call clearmatches()")
    command("call setline(1, 'abcdΣabcdef')")
    command("call matchaddpos('MyGroup1', [[1, 4, 2], [1, 9, 2]])")
    screen:expect([[
      abc{1:dΣ}ab{1:cd}e^f                             |
      {0:~                                       }|
      {0:~                                       }|
      {0:~                                       }|
                                              |
    ]])
  end)
end)

