" Tests for :messages

function Test_messages()
  let oldmore = &more
  try
    set nomore

    let arr = map(range(10), '"hello" . v:val')
    for s in arr
      echomsg s | redraw
    endfor
    let result = ''

    redir => result
    2messages | redraw
    redir END

    " get last two messages
    let msg = split(result, "\n")[1:][-2:]
    call assert_equal(["hello8", "hello9"], msg)

    " clear messages without last one
    1messages clear
    redir => result
    redraw | 1messages
    redir END
    " get last last message
    let msg = split(result, "\n")[1:][-1:]
    call assert_equal(['hello9'], msg)

    " clear all messages
    messages clear
    redir => result
    redraw | 1messages
    redir END
    " get last last message
    let msg = split(result, "\n")[1:][-1:]
    call assert_equal([], msg)
  finally
    let &more = oldmore
  endtry
endfunction
