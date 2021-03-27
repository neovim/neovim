" Tests for :messages, :echomsg, :echoerr

source check.vim
source shared.vim

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
function! Test_stopinsert_does_not_break_message_output()
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
endfunction

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
  call test_ignore_error('<lambda>')
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
