local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local feed = helpers.feed
local source = helpers.source
local clear = helpers.clear
local poke_eventloop = helpers.poke_eventloop
local meths = helpers.meths
local eq = helpers.eq

describe('prompt buffer', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(25, 10)
    screen:attach()
    source([[
      set laststatus=0 nohidden

      func TextEntered(text)
        if a:text == "exit"
          " Reset &modified to allow the buffer to be closed.
          set nomodified
          stopinsert
          close
        else
          " Add the output above the current prompt.
          call append(line("$") - 1, 'Command: "' . a:text . '"')
          " Reset &modified to allow the buffer to be closed.
          set nomodified
          call timer_start(20, {id -> TimerFunc(a:text)})
        endif
      endfunc

      func TimerFunc(text)
        " Add the output above the current prompt.
        call append(line("$") - 1, 'Result: "' . a:text .'"')
        " Reset &modified to allow the buffer to be closed.
        set nomodified
      endfunc

      func SwitchWindows()
        call timer_start(0, {-> execute("wincmd p", "")})
      endfunc

      call setline(1, "other buffer")
      set nomodified
      new
      set buftype=prompt
      call prompt_setcallback(bufnr(''), function("TextEntered"))
      eval bufnr("")->prompt_setprompt("cmd: ")
      startinsert
    ]])
    screen:expect([[
      cmd: ^                    |
      ~                        |
      ~                        |
      ~                        |
      [Prompt] [+]             |
      other buffer             |
      ~                        |
      ~                        |
      ~                        |
      -- INSERT --             |
    ]])
  end)

  after_each(function()
    screen:detach()
  end)

  -- oldtest: Test_prompt_basic()
  it('works', function()
    feed("hello\n")
    screen:expect([[
      cmd: hello               |
      Command: "hello"         |
      Result: "hello"          |
      cmd: ^                    |
      [Prompt]                 |
      other buffer             |
      ~                        |
      ~                        |
      ~                        |
      -- INSERT --             |
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

  -- oldtest: Test_prompt_editing()
  it('editing', function()
    feed("hello<BS><BS>")
    screen:expect([[
      cmd: hel^                 |
      ~                        |
      ~                        |
      ~                        |
      [Prompt] [+]             |
      other buffer             |
      ~                        |
      ~                        |
      ~                        |
      -- INSERT --             |
    ]])
    feed("<Left><Left><Left><BS>-")
    screen:expect([[
      cmd: -^hel                |
      ~                        |
      ~                        |
      ~                        |
      [Prompt] [+]             |
      other buffer             |
      ~                        |
      ~                        |
      ~                        |
      -- INSERT --             |
    ]])
    feed("<C-O>lz")
    screen:expect([[
      cmd: -hz^el               |
      ~                        |
      ~                        |
      ~                        |
      [Prompt] [+]             |
      other buffer             |
      ~                        |
      ~                        |
      ~                        |
      -- INSERT --             |
    ]])
    feed("<End>x")
    screen:expect([[
      cmd: -hzelx^              |
      ~                        |
      ~                        |
      ~                        |
      [Prompt] [+]             |
      other buffer             |
      ~                        |
      ~                        |
      ~                        |
      -- INSERT --             |
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

  -- oldtest: Test_prompt_switch_windows()
  it('switch windows', function()
    feed("<C-O>:call SwitchWindows()<CR>")
    screen:expect{grid=[[
      cmd:                     |
      ~                        |
      ~                        |
      ~                        |
      [Prompt] [+]             |
      ^other buffer             |
      ~                        |
      ~                        |
      ~                        |
                               |
    ]]}
    feed("<C-O>:call SwitchWindows()<CR>")
    screen:expect([[
      cmd: ^                    |
      ~                        |
      ~                        |
      ~                        |
      [Prompt] [+]             |
      other buffer             |
      ~                        |
      ~                        |
      ~                        |
      -- INSERT --             |
    ]])
    feed("<Esc>")
    screen:expect([[
      cmd:^                     |
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
  end)

  -- oldtest: Test_prompt_while_writing_to_hidden_buffer()
  it('keeps insert mode after aucmd_restbuf in callback', function()
    source [[
      let s:buf = nvim_create_buf(1, 1)
      call timer_start(0, {-> nvim_buf_set_lines(s:buf, -1, -1, 0, ['walrus'])})
    ]]
    poke_eventloop()
    eq({ mode = "i", blocking = false }, meths.get_mode())
  end)
end)
