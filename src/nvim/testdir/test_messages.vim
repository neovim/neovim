" Tests for :messages

function Test_messages()
  let oldmore = &more
  try
    set nomore
    " Avoid the "message maintainer" line.
    let $LANG = ''

    let arr = map(range(10), '"hello" . v:val')
    for s in arr
      echomsg s | redraw
    endfor
    let result = ''

    " get last two messages
    redir => result
    2messages | redraw
    redir END
    let msg_list = split(result, "\n")
    call assert_equal(["hello8", "hello9"], msg_list)

    " clear messages without last one
    1messages clear
    redir => result
    redraw | messages
    redir END
    let msg_list = split(result, "\n")
    call assert_equal(['hello9'], msg_list)

    " clear all messages
    messages clear
    redir => result
    redraw | messages
    redir END
    call assert_equal('', result)
  finally
    let &more = oldmore
  endtry
endfunction

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
