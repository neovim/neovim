local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local feed = n.feed
local fn = n.call
local source = n.source
local clear = n.clear
local command = n.command
local expect = n.expect
local poke_eventloop = n.poke_eventloop
local api = n.api
local eq = t.eq
local neq = t.neq

describe('prompt buffer', function()
  local screen

  before_each(function()
    clear()
    screen = Screen.new(25, 10)
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
          call append(line("$") - 1, split('Command: "' . a:text . '"', '\n'))
          " Reset &modified to allow the buffer to be closed.
          set nomodified
          call timer_start(20, {id -> TimerFunc(a:text)})
        endif
      endfunc

      func TimerFunc(text)
        " Add the output above the current prompt.
        call append(line("$") - 1, split('Result: "' . a:text .'"', '\n'))
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

  it('can insert multiline text', function()
    source_script()
    local buf = api.nvim_get_current_buf()

    feed('line 1<s-cr>line 2<s-cr>line 3')
    screen:expect([[
      cmd: line 1              |
      line 2                   |
      line 3^                   |
      {1:~                        }|
      {3:[Prompt] [+]             }|
      other buffer             |
      {1:~                        }|*3
      {5:-- INSERT --}             |
    ]])

    -- prompt_getinput works with multiline input
    eq('line 1\nline 2\nline 3', fn('prompt_getinput', buf))

    feed('<cr>')
    -- submiting multiline text works
    screen:expect([[
      Result: "line 1          |
      line 2                   |
      line 3"                  |
      cmd: ^                    |
      {3:[Prompt]                 }|
      other buffer             |
      {1:~                        }|*3
      {5:-- INSERT --}             |
    ]])

    eq('', fn('prompt_getinput', buf))

    -- % prompt is not repeated with formatoptions+=r
    source([[
      bwipeout!
      set formatoptions+=r
      set buftype=prompt
      call prompt_setprompt(bufnr(), "% ")
    ]])
    feed('iline1<s-cr>line2')
    screen:expect([[
      other buffer             |
      % line1                  |
      line2^                    |
      {1:~                        }|*6
      {5:-- INSERT --}             |
    ]])
  end)

  it('can put (p) multiline text', function()
    source_script()
    local buf = api.nvim_get_current_buf()

    fn('setreg', 'a', 'line 1\nline 2\nline 3')
    feed('<esc>"ap')
    screen:expect([[
      cmd: ^line 1              |
      line 2                   |
      line 3                   |
      {1:~                        }|
      {3:[Prompt] [+]             }|
      other buffer             |
      {1:~                        }|*3
                               |
    ]])

    -- prompt_getinput works with pasted input
    eq('line 1\nline 2\nline 3', fn('prompt_getinput', buf))

    feed('i<cr>')
    screen:expect([[
      Result: "line 1          |
      line 2                   |
      line 3"                  |
      cmd: ^                    |
      {3:[Prompt]                 }|
      other buffer             |
      {1:~                        }|*3
      {5:-- INSERT --}             |
    ]])
  end)

  it('can put multiline text with nvim_paste', function()
    source_script()
    api.nvim_paste('line 1\nline 2\nline 3', false, -1)
    screen:expect([[
      cmd: line 1              |
      line 2                   |
      line 3^                   |
      {1:~                        }|
      {3:[Prompt] [+]             }|
      other buffer             |
      {1:~                        }|*3
      {5:-- INSERT --}             |
    ]])
  end)

  it('can undo current prompt', function()
    source_script()
    local buf = api.nvim_get_current_buf()

    -- text editiing alowed in current prompt
    feed('tests-initial<esc>')
    feed('bimiddle-<esc>')
    screen:expect([[
      cmd: tests-middle^-initial|
      {1:~                        }|*3
      {3:[Prompt] [+]             }|
      other buffer             |
      {1:~                        }|*3
                               |
    ]])

    feed('Fdx')
    screen:expect([[
      cmd: tests-mid^le-initial |
      {1:~                        }|*3
      {3:[Prompt] [+]             }|
      other buffer             |
      {1:~                        }|*3
                               |
    ]])

    -- can undo edits until prompt has been submitted
    feed('u')
    screen:expect([[
      cmd: tests-mid^dle-initial|
      {1:~                        }|*3
      {3:[Prompt] [+]             }|
      other buffer             |
      {1:~                        }|*3
      1 change; {MATCH:.*} |
    ]])

    -- undo is reflected in prompt_getinput
    eq('tests-middle-initial', fn('prompt_getinput', buf))

    feed('u')
    screen:expect([[
      cmd: tests-^initial       |
      {1:~                        }|*3
      {3:[Prompt] [+]             }|
      other buffer             |
      {1:~                        }|*3
      1 change; {MATCH:.*} |
    ]])

    feed('i<cr><esc>')
    screen:expect([[
      cmd: tests-initial       |
      Command: "tests-initial" |
      Result: "tests-initial"  |
      cmd:^                     |
      {3:[Prompt]                 }|
      other buffer             |
      {1:~                        }|*3
                               |
    ]])

    -- after submit undo does nothing
    feed('u')
    screen:expect([[
      cmd: tests-initial       |
      Command: "tests-initial" |
      cmd:^                     |
      {1:~                        }|
      {3:[Prompt] [+]             }|
      other buffer             |
      {1:~                        }|*3
      1 line {MATCH:.*} |
    ]])
  end)

  it('o/O can create new lines', function()
    source_script()
    local buf = api.nvim_get_current_buf()

    feed('line 1<s-cr>line 2<s-cr>line 3')
    screen:expect([[
      cmd: line 1              |
      line 2                   |
      line 3^                   |
      {1:~                        }|
      {3:[Prompt] [+]             }|
      other buffer             |
      {1:~                        }|*3
      {5:-- INSERT --}             |
    ]])

    feed('<esc>koafter')
    screen:expect([[
      cmd: line 1              |
      line 2                   |
      after^                    |
      line 3                   |
      {3:[Prompt] [+]             }|
      other buffer             |
      {1:~                        }|*3
      {5:-- INSERT --}             |
    ]])

    -- newline created with o is reflected in prompt_getinput
    eq('line 1\nline 2\nafter\nline 3', fn('prompt_getinput', buf))

    feed('<esc>kObefore')

    screen:expect([[
      cmd: line 1              |
      before^                   |
      line 2                   |
      after                    |
      {3:[Prompt] [+]             }|
      other buffer             |
      {1:~                        }|*3
      {5:-- INSERT --}             |
    ]])

    -- newline created with O is reflected in prompt_getinput
    eq('line 1\nbefore\nline 2\nafter\nline 3', fn('prompt_getinput', buf))

    feed('<cr>')
    screen:expect([[
      line 2                   |
      after                    |
      line 3"                  |
      cmd: ^                    |
      {3:[Prompt]                 }|
      other buffer             |
      {1:~                        }|*3
      {5:-- INSERT --}             |
    ]])

    feed('line 4<s-cr>line 5')

    feed('<esc>k0oafter prompt')
    screen:expect([[
      after                    |
      line 3"                  |
      cmd: line 4              |
      after prompt^             |
      {3:[Prompt] [+]             }|
      other buffer             |
      {1:~                        }|*3
      {5:-- INSERT --}             |
    ]])

    feed('<esc>k0Oat prompt')
    screen:expect([[
      after                    |
      line 3"                  |
      cmd: at prompt^           |
      line 4                   |
      {3:[Prompt] [+]             }|
      other buffer             |
      {1:~                        }|*3
      {5:-- INSERT --}             |
    ]])

    feed('<cr>')
    screen:expect([[
      line 4                   |
      after prompt             |
      line 5"                  |
      cmd: ^                    |
      {3:[Prompt]                 }|
      other buffer             |
      {1:~                        }|*3
      {5:-- INSERT --}             |
    ]])
  end)

  it('deleting prompt adds it back on insert', function()
    source_script()
    feed('asdf')
    screen:expect([[
      cmd: asdf^                |
      {1:~                        }|*3
      {3:[Prompt] [+]             }|
      other buffer             |
      {1:~                        }|*3
      {5:-- INSERT --}             |
    ]])

    feed('<esc>ddi')
    screen:expect([[
      cmd: ^                    |
      {1:~                        }|*3
      {3:[Prompt] [+]             }|
      other buffer             |
      {1:~                        }|*3
      {5:-- INSERT --}             |
    ]])

    feed('asdf')
    screen:expect([[
      cmd: asdf^                |
      {1:~                        }|*3
      {3:[Prompt] [+]             }|
      other buffer             |
      {1:~                        }|*3
      {5:-- INSERT --}             |
    ]])

    feed('<esc>cc')
    screen:expect([[
      cmd: ^                    |
      {1:~                        }|*3
      {3:[Prompt] [+]             }|
      other buffer             |
      {1:~                        }|*3
      {5:-- INSERT --}             |
    ]])
  end)

  it("sets the ': mark", function()
    source_script()
    feed('asdf')
    eq({ 1, 1 }, api.nvim_buf_get_mark(0, ':'))
    feed('<cr>')
    eq({ 3, 1 }, api.nvim_buf_get_mark(0, ':'))
    -- Multiline prompt.
    feed('<s-cr>line1<s-cr>line2<s-cr>line3<cr>')
    eq({ 11, 1 }, api.nvim_buf_get_mark(0, ':'))

    -- ': mark is only available in prompt buffer.
    source('set buftype=')
    eq("Invalid mark name: ':'", t.pcall_err(api.nvim_buf_get_mark, 0, ':'))
  end)

  describe('prompt_getinput', function()
    it('returns current prompts text', function()
      command('new')
      local bufnr = fn('bufnr')
      api.nvim_set_option_value('buftype', 'prompt', { buf = 0 })
      eq('', fn('prompt_getinput', bufnr))
      feed('iasdf')
      eq('asdf', fn('prompt_getinput', bufnr))
      feed('<esc>dd')
      eq('', fn('prompt_getinput', bufnr))
      feed('iasdf2')
      eq('asdf2', fn('prompt_getinput', bufnr))

      -- returns empty string when called from non prompt buffer
      api.nvim_set_option_value('buftype', '', { buf = 0 })
      eq('', fn('prompt_getinput', bufnr))
    end)
  end)
end)
