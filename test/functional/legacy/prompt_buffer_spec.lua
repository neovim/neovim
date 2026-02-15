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
local exec_lua = n.exec_lua

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

    -- :edit doesn't apply on prompt buffer
    eq('Vim(edit):cannot :edit a prompt buffer', t.pcall_err(api.nvim_command, 'edit'))

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

      func DoAppend(cmd_before = '')
        exe a:cmd_before
        call appendbufline('prompt', '$', 'Test')
        return ''
      endfunc

      autocmd User SwitchTabPages tabprevious | tabnext
      func DoAutoAll(cmd_before = '')
        exe a:cmd_before
        doautoall User SwitchTabPages
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
    command("call DoAppend('stopinsert')")
    eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
    command("call DoAppend('startreplace')")
    eq({ mode = 'R', blocking = false }, api.nvim_get_mode())
    feed('<Esc>')
    command('tabnew')
    eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
    command("call DoAutoAll('startinsert')")
    eq({ mode = 'i', blocking = false }, api.nvim_get_mode())
    command("call DoAutoAll('stopinsert')")
    eq({ mode = 'n', blocking = false }, api.nvim_get_mode())
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
    -- submitting multiline text works
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
      call prompt_setprompt(bufnr(), "% ")
      set buftype=prompt
    ]])
    feed('iline1<s-cr>line2')
    screen:expect([[
      other buffer             |
      % line1                  |
      line2^                    |
      {1:~                        }|*6
      {5:-- INSERT --}             |
    ]])

    -- ensure cursor gets placed on first line of user input.
    -- when insert mode is entered from read-only region of prompt buffer.
    local prompt_pos = api.nvim_buf_get_mark(0, ':')
    feed('<esc>')
    -- works before prompt
    api.nvim_win_set_cursor(0, { prompt_pos[1] - 1, 0 })
    screen:expect([[
      ^other buffer             |
      % line1                  |
      line2                    |
      {1:~                        }|*6
                               |
    ]])
    feed('a')
    feed('<esc>')
    screen:expect([[
      other buffer             |
      %^ line1                  |
      line2                    |
      {1:~                        }|*6
                               |
    ]])
    -- works on prompt
    api.nvim_win_set_cursor(0, { prompt_pos[1], 0 })
    screen:expect([[
      other buffer             |
      ^% line1                  |
      line2                    |
      {1:~                        }|*6
                               |
    ]])
    feed('a')
    feed('<esc>')
    screen:expect([[
      other buffer             |
      %^ line1                  |
      line2                    |
      {1:~                        }|*6
                               |
    ]])

    -- i_<Left> i_<C-Left> i_<Home> i_<End> keys on prompt-line doesn't put cursor
    -- at end of text
    feed('a<Left><C-Left>')
    screen:expect([[
      other buffer             |
      % ^line1                  |
      line2                    |
      {1:~                        }|*6
      {5:-- INSERT --}             |
    ]])

    feed('<End>')
    screen:expect([[
      other buffer             |
      % line1^                  |
      line2                    |
      {1:~                        }|*6
      {5:-- INSERT --}             |
    ]])

    feed('<Home>')
    screen:expect([[
      other buffer             |
      % ^line1                  |
      line2                    |
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

    -- text editing allowed in current prompt
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
    api.nvim_set_option_value('buftype', 'prompt', { buf = 0 })
    exec_lua(function()
      local buf = vim.api.nvim_get_current_buf()
      vim.fn.prompt_setprompt(buf, 'cmd > ')
      vim.fn.prompt_setcallback(buf, function(str)
        local last_line = vim.api.nvim_buf_line_count(buf)
        vim.api.nvim_buf_set_lines(buf, last_line - 1, last_line - 1, true, vim.split(str, '\n'))
      end)
    end)

    feed('asdf')
    eq({ 1, 6 }, api.nvim_buf_get_mark(0, ':'))
    feed('<cr>')
    eq({ 3, 6 }, api.nvim_buf_get_mark(0, ':'))
    -- Multiline prompt.
    feed('<s-cr>line1<s-cr>line2<s-cr>line3<cr>')
    eq({ 11, 6 }, api.nvim_buf_get_mark(0, ':'))

    -- ': mark is only available in prompt buffer.
    api.nvim_set_option_value('buftype', '', { buf = 0 })
    eq("Invalid mark name: ':'", t.pcall_err(api.nvim_buf_get_mark, 0, ':'))

    -- mark can be moved
    api.nvim_set_option_value('buftype', 'prompt', { buf = 0 })
    local last_line = api.nvim_buf_line_count(0)
    eq({ last_line, 6 }, api.nvim_buf_get_mark(0, ':'))
    eq(true, api.nvim_buf_set_mark(0, ':', 1, 5, {}))
    eq({ 1, 5 }, api.nvim_buf_get_mark(0, ':'))

    -- No crash from invalid col.
    eq(true, api.nvim_buf_set_mark(0, ':', fn('line', '.'), 999, {}))
    eq({ 12, 6 }, api.nvim_buf_get_mark(0, ':'))

    -- No ml_get error from invalid lnum.
    command('set messagesopt+=wait:0 messagesopt-=hit-enter')
    fn('setpos', "':", { 0, 999, 7, 0 })
    eq('', api.nvim_get_vvar('errmsg'))
    command('set messagesopt&')
    eq({ 12, 6 }, api.nvim_buf_get_mark(0, ':'))
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

  it('programmatic (non-user) edits', function()
    api.nvim_set_option_value('buftype', 'prompt', { buf = 0 })

    -- with nvim_buf_set_lines
    exec_lua([[
      local buf = vim.api.nvim_get_current_buf()
      vim.fn.prompt_setcallback(buf, function(text)
        vim.api.nvim_buf_set_lines(buf, -2, -2, true, vim.split(text, '\n'))
      end)
    ]])
    feed('iset_lines<cr>')
    feed('set_lines2<cr>')
    screen:expect([[
      % set_lines              |
      set_lines                |
      % set_lines2             |
      set_lines2               |
      % ^                       |
      {1:~                        }|*4
      {5:-- INSERT --}             |
    ]])

    feed('set_lines3(multi-1)<s-cr>set_lines3(multi-2)<cr>')
    screen:expect([[
      % set_lines              |
      set_lines                |
      % set_lines2             |
      set_lines2               |
      % set_lines3(multi-1)    |
      set_lines3(multi-2)      |
      set_lines3(multi-1)      |
      set_lines3(multi-2)      |
      % ^                       |
      {5:-- INSERT --}             |
    ]])
    -- with nvim_buf_set_text
    source('bwipeout!')
    api.nvim_set_option_value('buftype', 'prompt', { buf = 0 })
    exec_lua([[
      local buf = vim.api.nvim_get_current_buf()
      vim.fn.prompt_setcallback(buf, function(text)
        local lines = vim.split(text, '\n')
        if lines[#lines] ~= '' then
          table.insert(lines, '')
        end
        vim.api.nvim_buf_set_text(buf, -1, 0, -1, 0, lines)
      end)
    ]])
    feed('set_text<cr>')
    feed('set_text2<cr>')
    screen:expect([[
      % set_text               |
      set_text                 |
      % set_text2              |
      set_text2                |
      % ^                       |
      {1:~                        }|*4
      {5:-- INSERT --}             |
    ]])

    feed('set_text3(multi-1)<s-cr>set_text3(multi-2)<cr>')
    screen:expect([[
      % set_text               |
      set_text                 |
      % set_text2              |
      set_text2                |
      % set_text3(multi-1)     |
      set_text3(multi-2)       |
      set_text3(multi-1)       |
      set_text3(multi-2)       |
      % ^                       |
      {5:-- INSERT --}             |
    ]])
  end)

  it('works correctly with empty string as prompt', function()
    api.nvim_set_option_value('buftype', 'prompt', { buf = 0 })
    exec_lua(function()
      local buf = vim.api.nvim_get_current_buf()
      vim.fn.prompt_setprompt(buf, '')
    end)

    source('startinsert')

    -- mark correctly set
    eq({ 1, 0 }, api.nvim_buf_get_mark(0, ':'))

    feed('asdf')
    screen:expect([[
      asdf^                     |
      {1:~                        }|*8
      {5:-- INSERT --}             |
    ]])

    -- can clear all of it
    feed('<backspace><backspace><backspace><backspace>')
    screen:expect([[
      ^                         |
      {1:~                        }|*8
      {5:-- INSERT --}             |
    ]])
    feed('<cr>')

    eq({ 2, 0 }, api.nvim_buf_get_mark(0, ':'))
  end)

  it('prompt can be changed without interrupting user input', function()
    api.nvim_set_option_value('buftype', 'prompt', { buf = 0 })
    local buf = api.nvim_get_current_buf()

    local function set_prompt(prompt, b)
      fn('prompt_setprompt', b or buf, prompt)
    end

    set_prompt('> ')

    source('startinsert')

    feed('user input')
    -- Move the cursor a bit to check cursor maintaining position
    feed('<esc>hhi')

    screen:expect([[
      > user in^put             |
      {1:~                        }|*8
      {5:-- INSERT --}             |
    ]])

    eq({ 1, 2 }, api.nvim_buf_get_mark(0, ':'))

    set_prompt('new-prompt > ')

    screen:expect([[
      new-prompt > user in^put  |
      {1:~                        }|*8
      {5:-- INSERT --}             |
    ]])

    eq({ 1, 13 }, api.nvim_buf_get_mark(0, ':'))

    set_prompt('new-prompt(status) > ')

    screen:expect([[
      new-prompt(status) > user|
       in^put                   |
      {1:~                        }|*7
      {5:-- INSERT --}             |
    ]])
    eq({ 1, 21 }, api.nvim_buf_get_mark(0, ':'))

    set_prompt('new-prompt > ')

    screen:expect([[
      new-prompt > user in^put  |
      {1:~                        }|*8
      {5:-- INSERT --}             |
    ]])
    eq({ 1, 13 }, api.nvim_buf_get_mark(0, ':'))

    -- Cursor not moved when not on the prompt line.
    feed('<CR>user input<Esc>k')
    screen:expect([[
      new-prompt > user inpu^t  |
      new-prompt > user input  |
      {1:~                        }|*7
                               |
    ]])
    set_prompt('<>< ')
    screen:expect([[
      new-prompt > user inpu^t  |
      <>< user input           |
      {1:~                        }|*7
                               |
    ]])
    -- Correct col when prompt has multi-cell chars.
    feed('i<Left><Left>')
    screen:expect([[
      new-prompt > user input  |
      <>< user inp^ut           |
      {1:~                        }|*7
      {5:-- INSERT --}             |
    ]])
    set_prompt('\t > ')
    screen:expect([[
      new-prompt > user input  |
               > user inp^ut    |
      {1:~                        }|*7
      {5:-- INSERT --}             |
    ]])
    -- Works with 'virtualedit': coladd remains sensible. Cursor is redrawn correctly.
    -- Tab size visually changes due to multiples of 'tabstop'.
    command('set virtualedit=all')
    feed('<C-O>Sa<Tab>b<C-O>3h')
    screen:expect([[
      new-prompt > user input  |
               > a  ^  b        |
      {1:~                        }|*7
      {5:-- INSERT --}             |
    ]])
    set_prompt('😊 > ')
    screen:expect([[
      new-prompt > user input  |
      😊 > a ^ b                |
      {1:~                        }|*7
      {5:-- INSERT --}             |
    ]])

    -- No crash when setting shorter prompt than curbuf's in other buffer.
    feed('<C-O>zt')
    command('set virtualedit& | new | setlocal buftype=prompt')
    set_prompt('looooooooooooooooooooooooooooooooooooooooooooong > ', '') -- curbuf
    set_prompt('foo > ')
    screen:expect([[
      loooooooooooooooooooooooo|
      ooooooooooooooooooooong >|
       ^                        |
      {1:~                        }|
      {3:[Prompt] [+]             }|
      foo > a b                |
      {1:~                        }|*3
      {5:-- INSERT --}             |
    ]])

    -- No prompt_setprompt crash from invalid ': col. Must happen in the same event.
    exec_lua(function()
      vim.cmd 'bwipeout!'
      vim.api.nvim_buf_set_mark(0, ':', vim.fn.line('.'), 999, {})
      vim.fn.prompt_setprompt('', 'new-prompt > ')
    end)
    screen:expect([[
      new-prompt > ^            |
      {1:~                        }|*8
      {5:-- INSERT --}             |
    ]])
  end)
end)
