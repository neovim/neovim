-- Tests for signs

local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear, command, exec, expect, feed = n.clear, n.command, n.exec, n.expect, n.feed

describe('signs', function()
  before_each(clear)

  it('are working', function()
    command('sign define JumpSign text=x')
    command([[exe 'sign place 42 line=2 name=JumpSign buffer=' . bufnr('')]])
    -- Split the window to the bottom to verify :sign-jump will stay in the current
    -- window if the buffer is displayed there.
    command('bot split')
    command([[exe 'sign jump 42 buffer=' . bufnr('')]])
    command([[call append(line('$'), winnr())]])

    -- Assert buffer contents.
    expect([[

      2]])
  end)

  -- oldtest: Test_sign_cursor_position()
  it('are drawn correctly', function()
    local screen = Screen.new(75, 6)
    exec([[
      call setline(1, [repeat('x', 75), 'mmmm', 'yyyy'])
      call cursor(2,1)
      sign define s1 texthl=Search text==>
      sign define s2 linehl=Pmenu
      redraw
      sign place 10 line=2 name=s1
    ]])
    screen:expect([[
      {7:  }xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx|
      {7:  }xx                                                                       |
      {10:=>}^mmmm                                                                     |
      {7:  }yyyy                                                                     |
      {1:~                                                                          }|
                                                                                 |
    ]])

    -- Change the sign text
    command('sign define s1 text=-)')
    screen:expect([[
      {7:  }xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx|
      {7:  }xx                                                                       |
      {10:-)}^mmmm                                                                     |
      {7:  }yyyy                                                                     |
      {1:~                                                                          }|
                                                                                 |
    ]])

    -- Also place a line HL sign
    command('sign place 11 line=2 name=s2')
    screen:expect([[
      {7:  }xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx|
      {7:  }xx                                                                       |
      {10:-)}{4:^mmmm                                                                     }|
      {7:  }yyyy                                                                     |
      {1:~                                                                          }|
                                                                                 |
    ]])

    -- update cursor position calculation
    feed('lh')
    command('sign unplace 11')
    command('sign unplace 10')
    screen:expect([[
      xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx|
      ^mmmm                                                                       |
      yyyy                                                                       |
      {1:~                                                                          }|*2
                                                                                 |
    ]])
  end)
end)
