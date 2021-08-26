let g:loaded_foo_vim += 1

let foo#bar = {}

func foo#bar.echo()
  let g:called_foo_bar_echo += 1
endfunc

func foo#addFoo(head)
  return a:head .. 'foo'
endfunc
