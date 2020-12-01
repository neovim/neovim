local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local clear = helpers.clear
local feed = helpers.feed
local feed_command = helpers.feed_command
local source = helpers.source

describe('cmdline', function()
  before_each(clear)

  it('is cleared when switching tabs', function()
    local screen = Screen.new(30, 10)
    screen:attach()
    feed_command([[call setline(1, range(30))]])
    screen:expect([[
      ^0                             |
      1                             |
      2                             |
      3                             |
      4                             |
      5                             |
      6                             |
      7                             |
      8                             |
      :call setline(1, range(30))   |
    ]])
    feed([[:tabnew<cr><C-w>-<C-w>-gtgt]])
    screen:expect([[
       + [No Name]  [No Name]      X|
      ^                              |
      ~                             |
      ~                             |
      ~                             |
      ~                             |
      ~                             |
      6                             |
      7                             |
                                    |
    ]])
  end)

  it('prints every executed Ex command if verbose >= 16', function()
    local screen = Screen.new(60, 12)
    screen:attach()
    source([[
      command DoSomething echo 'hello' |set ts=4 |let v = '123' |echo v
      call feedkeys("\r", 't') " for the hit-enter prompt
      set verbose=20
    ]])
    feed_command('DoSomething')
    screen:expect([[
                                                                  |
      ~                                                           |
      ~                                                           |
                                                                  |
      Executing: DoSomething                                      |
      Executing: echo 'hello' |set ts=4 |let v = '123' |echo v    |
      hello                                                       |
      Executing: set ts=4 |let v = '123' |echo v                  |
      Executing: let v = '123' |echo v                            |
      Executing: echo v                                           |
      123                                                         |
      Press ENTER or type command to continue^                     |
    ]])
  end)
end)
