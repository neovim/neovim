local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local feed= helpers.feed
local source = helpers.source
local clear = helpers.clear
local feed_command = helpers.feed_command

describe('prompt buffer', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(25, 10)
    screen:attach()
    source([[
      func TextEntered(text)
        if a:text == "exit"
          set nomodified
          stopinsert
          close
        else
          call append(line("$") - 1, 'Command: "' . a:text . '"')
          set nomodfied
          call timer_start(20, {id -> TimerFunc(a:text)})
        endif
      endfunc

      func TimerFunc(text)
        call append(line("$") - 1, 'Result: "' . a:text .'"')
      endfunc
    ]])
    feed_command("set noshowmode | set laststatus=0")
    feed_command("call setline(1, 'other buffer')")
    feed_command("new")
    feed_command("set buftype=prompt")
    feed_command("call prompt_setcallback(bufnr(''), function('TextEntered'))")
  end)

  after_each(function()
    screen:detach()
  end)

  it('works', function()
    screen:expect([[
      ^                         |
      ~                        |
      ~                        |
      ~                        |
      [Prompt]                 |
      other buffer             |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]])
    feed("i")
    feed("hello\n")
    screen:expect([[
      % hello                  |
      Command: "hello"         |
      Result: "hello"          |
      % ^                       |
      [Prompt] [+]             |
      other buffer             |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]])
    feed("exit\n")
    screen:expect([[
      ^other buffer             |
      ~                        |
      ~                        |
      ~                        |
      ~                        |
      ~                        |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]])
  end)

  it('editing', function()
    screen:expect([[
      ^                         |
      ~                        |
      ~                        |
      ~                        |
      [Prompt]                 |
      other buffer             |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]])
    feed("i")
    feed("hello<BS><BS>")
    screen:expect([[
      % hel^                    |
      ~                        |
      ~                        |
      ~                        |
      [Prompt] [+]             |
      other buffer             |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]])
    feed("<Left><Left><Left><BS>-")
    screen:expect([[
      % -^hel                   |
      ~                        |
      ~                        |
      ~                        |
      [Prompt] [+]             |
      other buffer             |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]])
    feed("<End>x")
    screen:expect([[
      % -helx^                  |
      ~                        |
      ~                        |
      ~                        |
      [Prompt] [+]             |
      other buffer             |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]])
    feed("<C-U>exit\n")
    screen:expect([[
      ^other buffer             |
      ~                        |
      ~                        |
      ~                        |
      ~                        |
      ~                        |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]])
  end)

end)
