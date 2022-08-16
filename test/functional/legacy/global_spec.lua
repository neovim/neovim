local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local exec = helpers.exec
local feed = helpers.feed
local poke_eventloop = helpers.poke_eventloop

before_each(clear)

describe(':global', function()
  -- oldtest: Test_interrupt_global()
  it('can be interrupted using Ctrl-C in cmdline mode vim-patch:9.0.0082', function()
    local screen = Screen.new(75, 6)
    screen:set_default_attr_ids({
      [0] = {bold = true, reverse = true},  -- MsgSeparator
      [1] = {background = Screen.colors.Red, foreground = Screen.colors.White},  -- ErrorMsg
    })
    screen:attach()

    exec([[
      set nohlsearch noincsearch
      cnoremap ; <Cmd>sleep 10<CR>
      call setline(1, repeat(['foo'], 5))
    ]])

    feed(':g/foo/norm :<C-V>;<CR>')
    poke_eventloop()  -- Wait for :sleep to start
    feed('<C-C>')
    screen:expect([[
      ^foo                                                                        |
      foo                                                                        |
      foo                                                                        |
      foo                                                                        |
      foo                                                                        |
      {1:Interrupted}                                                                |
    ]])

    -- Also test in Ex mode
    feed('gQg/foo/norm :<C-V>;<CR>')
    poke_eventloop()  -- Wait for :sleep to start
    feed('<C-C>')
    screen:expect([[
      {0:                                                                           }|
      Entering Ex mode.  Type "visual" to go to Normal mode.                     |
      :g/foo/norm :;                                                             |
                                                                                 |
      {1:Interrupted}                                                                |
      :^                                                                          |
    ]])
  end)
end)
