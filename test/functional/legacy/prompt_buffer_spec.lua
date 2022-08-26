local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local feed = helpers.feed
local source = helpers.source
local clear = helpers.clear
local feed_command = helpers.feed_command
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
      func TextEntered(text)
        if a:text == "exit"
          set nomodified
          stopinsert
          close
        else
          call append(line("$") - 1, 'Command: "' . a:text . '"')
          set nomodified
          call timer_start(20, {id -> TimerFunc(a:text)})
        endif
      endfunc

      func TimerFunc(text)
        call append(line("$") - 1, 'Result: "' . a:text .'"')
      endfunc

      func SwitchWindows()
        call timer_start(0, {-> execute("wincmd p", "")})
      endfunc
    ]])
    feed_command("set noshowmode | set laststatus=0")
    feed_command("call setline(1, 'other buffer')")
    feed_command("new")
    feed_command("set buftype=prompt")
    feed_command("call prompt_setcallback(bufnr(''), function('TextEntered'))")
    feed_command("eval bufnr('')->prompt_setprompt('cmd: ')")
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
      cmd: hello               |
      Command: "hello"         |
      Result: "hello"          |
      cmd: ^                    |
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
      cmd: hel^                 |
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
      cmd: -^hel                |
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
                               |
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

  it('switch windows', function()
    feed_command("set showmode")
    feed("i")
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

  it('keeps insert mode after aucmd_restbuf in callback', function()
    source [[
      let s:buf = nvim_create_buf(1, 1)
      call timer_start(0, {-> nvim_buf_set_lines(s:buf, -1, -1, 0, ['walrus'])})
      startinsert
    ]]
    poke_eventloop()
    eq({ mode = "i", blocking = false }, meths.get_mode())
  end)
end)
