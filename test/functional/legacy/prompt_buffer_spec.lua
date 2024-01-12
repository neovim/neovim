local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')
local feed = helpers.feed
local source = helpers.source
local clear = helpers.clear
local command = helpers.command
local poke_eventloop = helpers.poke_eventloop
local api = helpers.api
local eq = helpers.eq
local neq = helpers.neq

describe('prompt buffer', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(25, 10)
    screen:attach()
    command('set laststatus=0 nohidden')
  end)

  local function source_script()
    source([[
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
      ~                        |*3
      [Prompt] [+]             |
      other buffer             |
      ~                        |*3
      -- INSERT --             |
    ]])
  end

  after_each(function()
    screen:detach()
  end)

  -- oldtest: Test_prompt_basic()
  it('works', function()
    source_script()
    feed('hello\n')
    screen:expect([[
      cmd: hello               |
      Command: "hello"         |
      Result: "hello"          |
      cmd: ^                    |
      [Prompt]                 |
      other buffer             |
      ~                        |*3
      -- INSERT --             |
    ]])
    feed('exit\n')
    screen:expect([[
      ^other buffer             |
      ~                        |*8
                               |
    ]])
  end)

  -- oldtest: Test_prompt_editing()
  it('editing', function()
    source_script()
    feed('hello<BS><BS>')
    screen:expect([[
      cmd: hel^                 |
      ~                        |*3
      [Prompt] [+]             |
      other buffer             |
      ~                        |*3
      -- INSERT --             |
    ]])
    feed('<Left><Left><Left><BS>-')
    screen:expect([[
      cmd: -^hel                |
      ~                        |*3
      [Prompt] [+]             |
      other buffer             |
      ~                        |*3
      -- INSERT --             |
    ]])
    feed('<C-O>lz')
    screen:expect([[
      cmd: -hz^el               |
      ~                        |*3
      [Prompt] [+]             |
      other buffer             |
      ~                        |*3
      -- INSERT --             |
    ]])
    feed('<End>x')
    screen:expect([[
      cmd: -hzelx^              |
      ~                        |*3
      [Prompt] [+]             |
      other buffer             |
      ~                        |*3
      -- INSERT --             |
    ]])
    feed('<C-U>exit\n')
    screen:expect([[
      ^other buffer             |
      ~                        |*8
                               |
    ]])
  end)

  -- oldtest: Test_prompt_switch_windows()
  it('switch windows', function()
    source_script()
    feed('<C-O>:call SwitchWindows()<CR>')
    screen:expect {
      grid = [[
      cmd:                     |
      ~                        |*3
      [Prompt] [+]             |
      ^other buffer             |
      ~                        |*3
                               |
    ]],
    }
    feed('<C-O>:call SwitchWindows()<CR>')
    screen:expect([[
      cmd: ^                    |
      ~                        |*3
      [Prompt] [+]             |
      other buffer             |
      ~                        |*3
      -- INSERT --             |
    ]])
    feed('<Esc>')
    screen:expect([[
      cmd:^                     |
      ~                        |*3
      [Prompt] [+]             |
      other buffer             |
      ~                        |*3
                               |
    ]])
  end)

  -- oldtest: Test_prompt_while_writing_to_hidden_buffer()
  it('keeps insert mode after aucmd_restbuf in callback', function()
    source_script()
    source [[
      let s:buf = nvim_create_buf(1, 1)
      call timer_start(0, {-> nvim_buf_set_lines(s:buf, -1, -1, 0, ['walrus'])})
    ]]
    poke_eventloop()
    eq({ mode = 'i', blocking = false }, api.nvim_get_mode())
  end)

  -- oldtest: Test_prompt_appending_while_hidden()
  it('accessing hidden prompt buffer does not start insert mode', function()
    local prev_win = api.nvim_get_current_win()
    source([[
      new prompt
      set buftype=prompt
      set bufhidden=hide

      func s:TextEntered(text)
          if a:text == 'exit'
              close
          endif
          let g:entered = a:text
      endfunc
      call prompt_setcallback(bufnr(), function('s:TextEntered'))

      func DoAppend()
        call appendbufline('prompt', '$', 'Test')
        return ''
      endfunc
    ]])
    feed('asomething<CR>')
    eq('something', api.nvim_get_var('entered'))
    neq(prev_win, api.nvim_get_current_win())
    feed('exit<CR>')
    eq(prev_win, api.nvim_get_current_win())
    eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
    command('call DoAppend()')
    eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
    feed('i')
    eq({ mode = 'i', blocking = false }, api.nvim_get_mode())
    command('call DoAppend()')
    eq({ mode = 'i', blocking = false }, api.nvim_get_mode())
  end)
end)
