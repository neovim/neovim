local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local exec = helpers.exec
local feed = helpers.feed

before_each(clear)

describe('statusline', function()
  local screen

  before_each(function()
    screen = Screen.new(50, 7)
    screen:attach()
  end)

  it('is updated in cmdline mode when using window-local statusline vim-patch:8.2.2737', function()
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue},  -- NonText
      [2] = {bold = true, reverse = true},  -- StatusLine
      [3] = {reverse = true},  -- StatusLineNC, VertSplit
    })
    exec([[
      setlocal statusline=-%{mode()}-
      split
      setlocal statusline=+%{mode()}+
    ]])
    screen:expect([[
      ^                                                  |
      {1:~                                                 }|
      {2:+n+                                               }|
                                                        |
      {1:~                                                 }|
      {3:-n-                                               }|
                                                        |
    ]])
    feed(':')
    screen:expect([[
                                                        |
      {1:~                                                 }|
      {2:+c+                                               }|
                                                        |
      {1:~                                                 }|
      {3:-c-                                               }|
      :^                                                 |
    ]])
  end)

  it('truncated item does not cause off-by-one highlight vim-patch:8.2.4929', function()
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue},  -- NonText
      [2] = {foreground = Screen.colors.Blue},  -- User1
      [3] = {background = Screen.colors.Red, foreground = Screen.colors.White},  -- User2
    })
    exec([[
      set laststatus=2
      hi! link User1 Directory
      hi! link User2 ErrorMsg
      set statusline=%.5(%1*ABC%2*DEF%1*GHI%)
    ]])
    screen:expect([[
      ^                                                  |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {3:<F}{2:GHI                                             }|
                                                        |
    ]])
  end)
end)
