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

func Test_message_completion()
  call feedkeys(":message \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"message clear', @:)
endfunc
