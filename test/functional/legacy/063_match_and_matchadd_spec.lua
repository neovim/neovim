-- Tests for adjusting window and contents

local t = require('test.functional.testutil')(after_each)
local Screen = require('test.functional.ui.screen')

local clear, command = t.clear, t.command
local insert = t.insert

describe('063: Test for ":match", "matchadd()" and related functions', function()
  setup(clear)

  it('is working', function()
    local screen = Screen.new(40, 5)
    screen:attach()

    command('highlight MyGroup1 term=bold ctermbg=red guibg=red')
    command('highlight MyGroup2 term=italic ctermbg=green guibg=green')
    command('highlight MyGroup3 term=underline ctermbg=blue guibg=blue')

    -- Check that "matchaddpos()" positions matches correctly
    insert('abcdefghijklmnopq')
    command("call matchaddpos('MyGroup1', [[1, 5], [1, 8, 3]], 10, 3)")
    screen:expect([[
      abcd{30:e}fg{30:hij}klmnop^q                       |
      {1:~                                       }|*3
                                              |
    ]])

    command('call clearmatches()')
    command("call setline(1, 'abcdΣabcdef')")
    command("call matchaddpos('MyGroup1', [[1, 4, 2], [1, 9, 2]])")
    screen:expect([[
      abc{30:dΣ}ab{30:cd}e^f                             |
      {1:~                                       }|*3
                                              |
    ]])
  end)
end)
