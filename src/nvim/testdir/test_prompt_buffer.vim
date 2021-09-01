" Tests for setting 'buftype' to "prompt"

source check.vim
" Nvim's channel implementation differs from Vim's
" CheckFeature channel

source shared.vim
source screendump.vim

func CanTestPromptBuffer()
  " We need to use a terminal window to be able to feed keys without leaving
  " Insert mode.
  " Nvim's terminal implementation differs from Vim's
  " CheckFeature terminal

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
  throw 'skipped: TODO'
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
  throw 'skipped: TODO'
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

  let end = "\<End>"
  call term_sendkeys(buf, end . "x")
  call WaitForAssert({-> assert_equal('cmd: -helx', term_getline(buf, 1))})

  call term_sendkeys(buf, "\<C-U>exit\<CR>")
  call WaitForAssert({-> assert_equal('other buffer', term_getline(buf, 1))})

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

" Test for editing the prompt buffer
func Test_prompt_buffer_edit()
  new
  set buftype=prompt
  normal! i
  call assert_beeps('normal! dd')
  call assert_beeps('normal! ~')
  call assert_beeps('normal! o')
  call assert_beeps('normal! O')
  call assert_beeps('normal! p')
  call assert_beeps('normal! P')
  call assert_beeps('normal! u')
  call assert_beeps('normal! ra')
  call assert_beeps('normal! s')
  call assert_beeps('normal! S')
  call assert_beeps("normal! \<C-A>")
  call assert_beeps("normal! \<C-X>")
  " pressing CTRL-W in the prompt buffer should trigger the window commands
  call assert_equal(1, winnr())
  " In Nvim, CTRL-W commands aren't usable from insert mode in a prompt buffer
  " exe "normal A\<C-W>\<C-W>"
  " call assert_equal(2, winnr())
  " wincmd w
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
  " Nvim doesn't support method call syntax yet.
  " call assert_equal('', '%'->prompt_getprompt())
  call assert_equal('', prompt_getprompt('%'))

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

" vim: shiftwidth=2 sts=2 expandtab
