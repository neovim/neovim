local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local source = n.source

describe('put', function()
  before_each(clear)

  -- oldtest: Test_put_other_window()
  it('above topline in buffer in two splits', function()
    local screen = Screen.new(80, 10)
    screen:attach()
    source([[
      40vsplit
      0put ='some text at the top'
      put ='  one more text'
      put ='  two more text'
      put ='  three more text'
      put ='  four more text'
    ]])

    screen:expect([[
      some text at the top                    │some text at the top                   |
        one more text                         │  one more text                        |
        two more text                         │  two more text                        |
        three more text                       │  three more text                      |
        ^four more text                        │  four more text                       |
                                              │                                       |
      {1:~                                       }│{1:~                                      }|*2
      {3:[No Name] [+]                            }{2:[No Name] [+]                          }|
                                                                                      |
    ]])
  end)

  -- oldtest: Test_put_in_last_displayed_line()
  it('in last displayed line', function()
    local screen = Screen.new(75, 10)
    screen:attach()
    source([[
      autocmd CursorMoved * eval line('w$')
      let @a = 'x'->repeat(&columns * 2 - 2)
      eval range(&lines)->setline(1)
      call feedkeys('G"ap')
    ]])

    screen:expect([[
      2                                                                          |
      3                                                                          |
      4                                                                          |
      5                                                                          |
      6                                                                          |
      7                                                                          |
      8                                                                          |
      9xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx|
      xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx^x |
                                                                                 |
    ]])
  end)
end)
