" Tests for setting 'buftype' to "prompt"

source check.vim
" Nvim's channel implementation differs from Vim's
" CheckFeature channel

source shared.vim
source screendump.vim

func CanTestPromptBuffer()
  " We need to use a terminal window to be able to feed keys without leaving
  " Insert mode.
  CheckFeature terminal

  " TODO: make the tests work on MS-Windows
  CheckNotMSWindows
endfunc

func WriteScript(name)
  call writefile([
	\ 'func TextEntered(text)',
	\ '  if a:text == "exit"',
	\ '    " Reset &modified to allow the buffer to be closed.',
	\ '    set nomodified',
	\ '    stopinsert',
	\ '    close',
	\ '  else',
	\ '    " Add the output above the current prompt.',
	\ '    call append(line("$") - 1, "Command: \"" . a:text . "\"")',
	\ '    " Reset &modified to allow the buffer to be closed.',
	\ '    set nomodified',
	\ '    call timer_start(20, {id -> TimerFunc(a:text)})',
	\ '  endif',
	\ 'endfunc',
	\ '',
	\ 'func TimerFunc(text)',
	\ '  " Add the output above the current prompt.',
	\ '  call append(line("$") - 1, "Result: \"" . a:text . "\"")',
	\ '  " Reset &modified to allow the buffer to be closed.',
	\ '  set nomodified',
	\ 'endfunc',
	\ '',
	\ 'func SwitchWindows()',
	\ '  call timer_start(0, {-> execute("wincmd p|wincmd p", "")})',
	\ 'endfunc',
	\ '',
	\ 'call setline(1, "other buffer")',
	\ 'set nomodified',
	\ 'new',
	\ 'set buftype=prompt',
	\ 'call prompt_setcallback(bufnr(""), function("TextEntered"))',
	\ 'eval bufnr("")->prompt_setprompt("cmd: ")',
	\ 'startinsert',
	\ ], a:name)
endfunc

func Test_prompt_basic()
  call CanTestPromptBuffer()
  let scriptName = 'XpromptscriptBasic'
  call WriteScript(scriptName)

  let buf = RunVimInTerminal('-S ' . scriptName, {})
  call WaitForAssert({-> assert_equal('cmd:', term_getline(buf, 1))})

  call term_sendkeys(buf, "hello\<CR>")
  call WaitForAssert({-> assert_equal('cmd: hello', term_getline(buf, 1))})
  call WaitForAssert({-> assert_equal('Command: "hello"', term_getline(buf, 2))})
  call WaitForAssert({-> assert_equal('Result: "hello"', term_getline(buf, 3))})

  call term_sendkeys(buf, "exit\<CR>")
  call WaitForAssert({-> assert_equal('other buffer', term_getline(buf, 1))})

  call StopVimInTerminal(buf)
  call delete(scriptName)
endfunc

func Test_prompt_editing()
  call CanTestPromptBuffer()
  let scriptName = 'XpromptscriptEditing'
  call WriteScript(scriptName)

  let buf = RunVimInTerminal('-S ' . scriptName, {})
  call WaitForAssert({-> assert_equal('cmd:', term_getline(buf, 1))})

  let bs = "\<BS>"
  call term_sendkeys(buf, "hello" . bs . bs)
  call WaitForAssert({-> assert_equal('cmd: hel', term_getline(buf, 1))})

  let left = "\<Left>"
  call term_sendkeys(buf, left . left . left . bs . '-')
  call WaitForAssert({-> assert_equal('cmd: -hel', term_getline(buf, 1))})

  call term_sendkeys(buf, "\<C-O>lz")
  call WaitForAssert({-> assert_equal('cmd: -hzel', term_getline(buf, 1))})

  let end = "\<End>"
  call term_sendkeys(buf, end . "x")
  call WaitForAssert({-> assert_equal('cmd: -hzelx', term_getline(buf, 1))})

  call term_sendkeys(buf, "\<C-U>exit\<CR>")
  call WaitForAssert({-> assert_equal('other buffer', term_getline(buf, 1))})

  call StopVimInTerminal(buf)
  call delete(scriptName)
endfunc

func Test_prompt_switch_windows()
  call CanTestPromptBuffer()
  let scriptName = 'XpromptSwitchWindows'
  call WriteScript(scriptName)

  let buf = RunVimInTerminal('-S ' . scriptName, {'rows': 12})
  call WaitForAssert({-> assert_equal('cmd:', term_getline(buf, 1))})
  call WaitForAssert({-> assert_match('-- INSERT --', term_getline(buf, 12))})

  call term_sendkeys(buf, "\<C-O>:call SwitchWindows()\<CR>")
  call term_wait(buf, 50)
  call WaitForAssert({-> assert_match('-- INSERT --', term_getline(buf, 12))})

  call term_sendkeys(buf, "\<Esc>")
  call term_wait(buf, 50)
  call WaitForAssert({-> assert_match('^ *$', term_getline(buf, 12))})

  call StopVimInTerminal(buf)
  call delete(scriptName)
endfunc

func Test_prompt_garbage_collect()
  func MyPromptCallback(x, text)
    " NOP
  endfunc
  func MyPromptInterrupt(x)
    " NOP
  endfunc

  new
  set buftype=prompt
  eval bufnr('')->prompt_setcallback(function('MyPromptCallback', [{}]))
  eval bufnr('')->prompt_setinterrupt(function('MyPromptInterrupt', [{}]))
  call test_garbagecollect_now()
  " Must not crash
  call feedkeys("\<CR>\<C-C>", 'xt')
  call assert_true(v:true)

  call assert_fails("call prompt_setcallback(bufnr(), [])", 'E921:')
  call assert_equal(0, prompt_setcallback({}, ''))
  call assert_fails("call prompt_setinterrupt(bufnr(), [])", 'E921:')
  call assert_equal(0, prompt_setinterrupt({}, ''))

  delfunc MyPromptCallback
  bwipe!
endfunc

func Test_prompt_backspace()
  new
  set buftype=prompt
  call feedkeys("A123456\<Left>\<BS>\<Esc>", 'xt')
  call assert_equal('% 12346', getline(1))
  bwipe!
endfunc

" Test for editing the prompt buffer
func Test_prompt_buffer_edit()
  new
  set buftype=prompt
  normal! i
  call assert_beeps('normal! dd')
  call assert_beeps('normal! ~')
  " Nvim: these operations are supported
  " call assert_beeps('normal! o')
  " call assert_beeps('normal! O')
  " call assert_beeps('normal! p')
  " call assert_beeps('normal! P')
  " call assert_beeps('normal! u')
  call assert_beeps('normal! ra')
  call assert_beeps('normal! s')
  call assert_beeps('normal! S')
  call assert_beeps("normal! \<C-A>")
  call assert_beeps("normal! \<C-X>")
  call assert_beeps("normal! dp")
  call assert_beeps("normal! do")
  " pressing CTRL-W in the prompt buffer should trigger the window commands
  call assert_equal(1, winnr())
  exe "normal A\<C-W>\<C-W>"
  call assert_equal(2, winnr())
  wincmd w
  close!
  call assert_equal(0, prompt_setprompt([], ''))
endfunc

func Test_prompt_buffer_getbufinfo()
  new
  call assert_equal('', prompt_getprompt('%'))
  call assert_equal('', prompt_getprompt(bufnr('%')))
  let another_buffer = bufnr('%')

  set buftype=prompt
  call assert_equal('% ', prompt_getprompt('%'))
  call prompt_setprompt( bufnr( '%' ), 'This is a test: ' )
  call assert_equal('This is a test: ', prompt_getprompt('%'))

  call prompt_setprompt( bufnr( '%' ), '' )
  call assert_equal('', '%'->prompt_getprompt())

  call prompt_setprompt( bufnr( '%' ), 'Another: ' )
  call assert_equal('Another: ', prompt_getprompt('%'))
  let another = bufnr('%')

  new

  call assert_equal('', prompt_getprompt('%'))
  call assert_equal('Another: ', prompt_getprompt(another))

  " Doesn't exist
  let buffers_before = len( getbufinfo() )
  call assert_equal('', prompt_getprompt( bufnr('$') + 1))
  call assert_equal(buffers_before, len( getbufinfo()))

  " invalid type
  call assert_fails('call prompt_getprompt({})', 'E728:')

  %bwipe!
endfunc

func Test_prompt_while_writing_to_hidden_buffer()
  call CanTestPromptBuffer()
  CheckUnix

  " Make a job continuously write to a hidden buffer, check that the prompt
  " buffer is not affected.
  let scriptName = 'XpromptscriptHiddenBuf'
  let script =<< trim END
    set buftype=prompt
    call prompt_setprompt( bufnr(), 'cmd:' )
    let job = job_start(['/bin/sh', '-c',
        \ 'while true;
        \   do echo line;
        \   sleep 0.1;
        \ done'], #{out_io: 'buffer', out_name: ''})
    startinsert
  END
  eval script->writefile(scriptName, 'D')

  let buf = RunVimInTerminal('-S ' .. scriptName, {})
  call WaitForAssert({-> assert_equal('cmd:', term_getline(buf, 1))})

  call term_sendkeys(buf, 'test')
  call WaitForAssert({-> assert_equal('cmd:test', term_getline(buf, 1))})
  call term_sendkeys(buf, 'test')
  call WaitForAssert({-> assert_equal('cmd:testtest', term_getline(buf, 1))})
  call term_sendkeys(buf, 'test')
  call WaitForAssert({-> assert_equal('cmd:testtesttest', term_getline(buf, 1))})

  call StopVimInTerminal(buf)
endfunc

func Test_prompt_appending_while_hidden()
  call CanTestPromptBuffer()

  let script =<< trim END
      new prompt
      set buftype=prompt
      set bufhidden=hide

      func s:TextEntered(text)
          if a:text == 'exit'
              close
          endif
          echowin 'Entered:' a:text
      endfunc
      call prompt_setcallback(bufnr(), function('s:TextEntered'))

      func DoAppend()
        call appendbufline('prompt', '$', 'Test')
        return ''
      endfunc
  END
  call writefile(script, 'XpromptBuffer', 'D')

  let buf = RunVimInTerminal('-S XpromptBuffer', {'rows': 10})
  call TermWait(buf)

  call term_sendkeys(buf, "asomething\<CR>")
  call TermWait(buf)

  call term_sendkeys(buf, "exit\<CR>")
  call WaitForAssert({-> assert_notmatch('-- INSERT --', term_getline(buf, 10))})

  call term_sendkeys(buf, ":call DoAppend()\<CR>")
  call WaitForAssert({-> assert_notmatch('-- INSERT --', term_getline(buf, 10))})

  call term_sendkeys(buf, "i")
  call WaitForAssert({-> assert_match('-- INSERT --', term_getline(buf, 10))})

  call term_sendkeys(buf, "\<C-R>=DoAppend()\<CR>")
  call WaitForAssert({-> assert_match('-- INSERT --', term_getline(buf, 10))})

  call term_sendkeys(buf, "\<Esc>")
  call StopVimInTerminal(buf)
endfunc

" Modifying a hidden buffer while leaving a prompt buffer should not prevent
" stopping of Insert mode, and returning to the prompt buffer later should
" restore Insert mode.
func Test_prompt_leave_modify_hidden()
  call CanTestPromptBuffer()

  let script =<< trim END
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
  END
  call writefile(script, 'XpromptLeaveModifyHidden', 'D')

  let buf = RunVimInTerminal('-S XpromptLeaveModifyHidden', {'rows': 10})
  call TermWait(buf)

  call term_sendkeys(buf, "a")
  call WaitForAssert({-> assert_match('-- INSERT --', term_getline(buf, 10))})

  call term_sendkeys(buf, "w")
  call WaitForAssert({-> assert_notmatch('-- INSERT --', term_getline(buf, 10))})

  call term_sendkeys(buf, "\<C-W>w")
  call WaitForAssert({-> assert_match('-- INSERT --', term_getline(buf, 10))})

  call term_sendkeys(buf, "q")
  call WaitForAssert({-> assert_notmatch('-- INSERT --', term_getline(buf, 10))})

  call term_sendkeys(buf, ":bwipe!\<CR>")
  call WaitForAssert({-> assert_equal('Leave', term_getline(buf, 2))})
  call WaitForAssert({-> assert_equal('Enter', term_getline(buf, 3))})
  call WaitForAssert({-> assert_equal('Leave', term_getline(buf, 4))})
  call WaitForAssert({-> assert_equal('Close', term_getline(buf, 5))})

  call StopVimInTerminal(buf)
endfunc

" vim: shiftwidth=2 sts=2 expandtab
