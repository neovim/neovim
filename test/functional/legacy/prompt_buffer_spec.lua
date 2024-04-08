local t = require('test.functional.testutil')(after_each)
local Screen = require('test.functional.ui.screen')
local feed = t.feed
local source = t.source
local clear = t.clear
local command = t.command
local expect = t.expect
local poke_eventloop = t.poke_eventloop
local api = t.api
local eq = t.eq
local neq = t.neq

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
      {1:~                        }|*3
      {3:[Prompt] [+]             }|
      other buffer             |
      {1:~                        }|*3
      {5:-- INSERT --}             |
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
      {3:[Prompt]                 }|
      other buffer             |
      {1:~                        }|*3
      {5:-- INSERT --}             |
    ]])
    feed('exit\n')
    screen:expect([[
      ^other buffer             |
      {1:~                        }|*8
                               |
    ]])
  end)

  -- oldtest: Test_prompt_editing()
  it('editing', function()
    source_script()
    feed('hello<BS><BS>')
    screen:expect([[
      cmd: hel^                 |
      {1:~                        }|*3
      {3:[Prompt] [+]             }|
      other buffer             |
      {1:~                        }|*3
      {5:-- INSERT --}             |
    ]])
    feed('<Left><Left><Left><BS>-')
    screen:expect([[
      cmd: -^hel                |
      {1:~                        }|*3
      {3:[Prompt] [+]             }|
      other buffer             |
      {1:~                        }|*3
      {5:-- INSERT --}             |
    ]])
    feed('<C-O>lz')
    screen:expect([[
      cmd: -hz^el               |
      {1:~                        }|*3
      {3:[Prompt] [+]             }|
      other buffer             |
      {1:~                        }|*3
      {5:-- INSERT --}             |
    ]])
    feed('<End>x')
    screen:expect([[
      cmd: -hzelx^              |
      {1:~                        }|*3
      {3:[Prompt] [+]             }|
      other buffer             |
      {1:~                        }|*3
      {5:-- INSERT --}             |
    ]])
    feed('<C-U>exit\n')
    screen:expect([[
      ^other buffer             |
      {1:~                        }|*8
                               |
    ]])
  end)

  -- oldtest: Test_prompt_switch_windows()
  it('switch windows', function()
    source_script()
    feed('<C-O>:call SwitchWindows()<CR>')
    screen:expect([[
      cmd:                     |
      {1:~                        }|*3
      {2:[Prompt] [+]             }|
      ^other buffer             |
      {1:~                        }|*3
                               |
    ]])
    feed('<C-O>:call SwitchWindows()<CR>')
    screen:expect([[
      cmd: ^                    |
      {1:~                        }|*3
      {3:[Prompt] [+]             }|
      other buffer             |
      {1:~                        }|*3
      {5:-- INSERT --}             |
    ]])
    feed('<Esc>')
    screen:expect([[
      cmd:^                     |
      {1:~                        }|*3
      {3:[Prompt] [+]             }|
      other buffer             |
      {1:~                        }|*3
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

  -- oldtest: Test_prompt_leave_modify_hidden()
  it('modifying hidden buffer does not prevent prompt buffer mode change', function()
    source([[
      file hidden
      set bufhidden=hide
      enew
      new prompt
      set buftype=prompt

      inoremap <buffer> w <Cmd>wincmd w<CR>
      inoremap <buffer> q <Cmd>bwipe!<CR>
      autocmd BufLeave prompt call appendbufline('hidden', '$', 'Leave')
      autocmd BufEnter prompt call appendbufline('hidden', '$', 'Enter')
      autocmd BufWinLeave prompt call appendbufline('hidden', '$', 'Close')
    ]])
    feed('a')
    eq({ mode = 'i', blocking = false }, api.nvim_get_mode())
    feed('w')
    eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
    feed('<C-W>w')
    eq({ mode = 'i', blocking = false }, api.nvim_get_mode())
    feed('q')
    eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
    command('bwipe!')
    expect([[

      Leave
      Enter
      Leave
      Close]])
  end)
end)
