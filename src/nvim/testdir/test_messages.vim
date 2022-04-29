" Tests for :messages, :echomsg, :echoerr

source check.vim
source shared.vim
source term_util.vim
source view_util.vim
source screendump.vim

func Test_messages()
  let oldmore = &more
  try
    set nomore

    let arr = map(range(10), '"hello" . v:val')
    for s in arr
      echomsg s | redraw
    endfor

    " get last two messages
    redir => result
    2messages | redraw
    redir END
    let msg_list = split(result, "\n")
    call assert_equal(["hello8", "hello9"], msg_list)

    " clear messages without last one
    1messages clear
    let msg_list = GetMessages()
    call assert_equal(['hello9'], msg_list)

    " clear all messages
    messages clear
    let msg_list = GetMessages()
    call assert_equal([], msg_list)
  finally
    let &more = oldmore
  endtry

  call assert_fails('message 1', 'E474:')
endfunc

 " Patch 7.4.1696 defined the "clearmode()" command for clearing the mode
" indicator (e.g., "-- INSERT --") when ":stopinsert" is invoked.  Message
" output could then be disturbed when 'cmdheight' was greater than one.
" This test ensures that the bugfix for this issue remains in place.
func Test_stopinsert_does_not_break_message_output()
  set cmdheight=2
  redraw!

   stopinsert | echo 'test echo'
  call assert_equal(116, screenchar(&lines - 1, 1))
  call assert_equal(32, screenchar(&lines, 1))
  redraw!

   stopinsert | echomsg 'test echomsg'
  call assert_equal(116, screenchar(&lines - 1, 1))
  call assert_equal(32, screenchar(&lines, 1))
  redraw!

   set cmdheight&
endfunc

func Test_message_completion()
  call feedkeys(":message \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"message clear', @:)
endfunc

func Test_echomsg()
  call assert_equal("\nhello", execute(':echomsg "hello"'))
  call assert_equal("\n", execute(':echomsg ""'))
  call assert_equal("\n12345", execute(':echomsg 12345'))
  call assert_equal("\n[]", execute(':echomsg []'))
  call assert_equal("\n[1, 2, 3]", execute(':echomsg [1, 2, 3]'))
  call assert_equal("\n[1, 2, []]", execute(':echomsg [1, 2, v:_null_list]'))
  call assert_equal("\n{}", execute(':echomsg {}'))
  call assert_equal("\n{'a': 1, 'b': 2}", execute(':echomsg {"a": 1, "b": 2}'))
  if has('float')
    call assert_equal("\n1.23", execute(':echomsg 1.23'))
  endif
  call assert_match("function('<lambda>\\d*')", execute(':echomsg {-> 1234}'))
endfunc

func Test_echoerr()
  CheckFunction test_ignore_error
  call test_ignore_error('IgNoRe')
  call assert_equal("\nIgNoRe hello", execute(':echoerr "IgNoRe hello"'))
  call assert_equal("\n12345 IgNoRe", execute(':echoerr 12345 "IgNoRe"'))
  call assert_equal("\n[1, 2, 'IgNoRe']", execute(':echoerr [1, 2, "IgNoRe"]'))
  call assert_equal("\n{'IgNoRe': 2, 'a': 1}", execute(':echoerr {"a": 1, "IgNoRe": 2}'))
  if has('float')
    call assert_equal("\n1.23 IgNoRe", execute(':echoerr 1.23 "IgNoRe"'))
  endif
  eval '<lambda>'->test_ignore_error()
  call assert_match("function('<lambda>\\d*')", execute(':echoerr {-> 1234}'))
  call test_ignore_error('RESET')
endfunc

func Test_echospace()
  set noruler noshowcmd laststatus=1
  call assert_equal(&columns - 1, v:echospace)
  split
  call assert_equal(&columns - 1, v:echospace)
  set ruler
  call assert_equal(&columns - 1, v:echospace)
  close
  call assert_equal(&columns - 19, v:echospace)
  set showcmd noruler
  call assert_equal(&columns - 12, v:echospace)
  set showcmd ruler
  call assert_equal(&columns - 29, v:echospace)

  set ruler& showcmd&
endfunc

func Test_mapping_at_hit_return_prompt()
  nnoremap <C-B> :echo "hit ctrl-b"<CR>
  call feedkeys(":ls\<CR>", "xt")
  call feedkeys("\<*C-B>", "xt")
  call assert_match('hit ctrl-b', Screenline(&lines - 1))
  nunmap <C-B>
endfunc

func Test_quit_long_message()
  CheckScreendump

  let content =<< trim END
    echom range(9999)->join("\x01")
  END
  call writefile(content, 'Xtest_quit_message')
  let buf = RunVimInTerminal('-S Xtest_quit_message', #{rows: 6})
  call term_sendkeys(buf, "q")
  call VerifyScreenDump(buf, 'Test_quit_long_message', {})

  " clean up
  call StopVimInTerminal(buf)
  call delete('Xtest_quit_message')
endfunc

" this was missing a terminating NUL
func Test_echo_string_partial()
  function CountSpaces()
  endfunction
  call assert_equal("function('CountSpaces', [{'ccccccccccc': ['ab', 'cd'], 'aaaaaaaaaaa': v:false, 'bbbbbbbbbbbb': ''}])", string(function('CountSpaces', [#{aaaaaaaaaaa: v:false, bbbbbbbbbbbb: '', ccccccccccc: ['ab', 'cd']}])))
endfunc

" Message output was previously overwritten by the fileinfo display, shown
" when switching buffers. If a buffer is switched to, then a message if
" echoed, we should show the message, rather than overwriting it with
" fileinfo.
func Test_fileinfo_after_echo()
  CheckScreendump

  let content =<< trim END
    file a.txt

    hide edit b.txt
    call setline(1, "hi")
    setlocal modified

    hide buffer a.txt

    autocmd CursorHold * buf b.txt | w | echo "'b' written"
  END

  call writefile(content, 'Xtest_fileinfo_after_echo')
  let buf = RunVimInTerminal('-S Xtest_fileinfo_after_echo', #{rows: 6})
  call term_sendkeys(buf, ":set updatetime=50\<CR>")
  call term_sendkeys(buf, "0$")
  call VerifyScreenDump(buf, 'Test_fileinfo_after_echo', {})

  call term_sendkeys(buf, ":q\<CR>")

  " clean up
  call StopVimInTerminal(buf)
  call delete('Xtest_fileinfo_after_echo')
  call delete('b.txt')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
