local t = require('test.functional.testutil')()
local Screen = require('test.functional.ui.screen')
local clear = t.clear
local exec = t.exec
local feed = t.feed
local poke_eventloop = t.poke_eventloop

before_each(clear)

describe(':global', function()
  -- oldtest: Test_interrupt_global()
  it('can be interrupted using Ctrl-C in cmdline mode vim-patch:9.0.0082', function()
    local screen = Screen.new(75, 6)
    screen:attach()

    exec([[
      set nohlsearch noincsearch
      cnoremap ; <Cmd>sleep 10<CR>
      call setline(1, repeat(['foo'], 5))
    ]])

    feed(':g/foo/norm :<C-V>;<CR>')
    poke_eventloop() -- Wait for :sleep to start
    feed('<C-C>')
    screen:expect([[
      ^foo                                                                        |
      foo                                                                        |*4
      {9:Interrupted}                                                                |
    ]])

    -- Also test in Ex mode
    feed('gQg/foo/norm :<C-V>;<CR>')
    poke_eventloop() -- Wait for :sleep to start
    feed('<C-C>')
    screen:expect([[
      {3:                                                                           }|
      Entering Ex mode.  Type "visual" to go to Normal mode.                     |
      :g/foo/norm :;                                                             |
                                                                                 |
      {9:Interrupted}                                                                |
      :^                                                                          |
    ]])
  end)
end)
