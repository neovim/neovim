" Test for assignment

func Test_no_type_checking()
  let v = 1
  let v = [1,2,3]
  let v = {'a': 1, 'b': 2}
  let v = 3.4
  let v = 'hello'
endfunc

func Test_let_termcap()
  " Nvim does not support `:set termcap`.
  return
  " Terminal code
  let old_t_te = &t_te
  let &t_te = "\<Esc>[yes;"
  call assert_match('t_te.*^[[yes;', execute("set termcap"))
  let &t_te = old_t_te

  if exists("+t_k1")
    " Key code
    let old_t_k1 = &t_k1
    let &t_k1 = "that"
    call assert_match('t_k1.*that', execute("set termcap"))
    let &t_k1 = old_t_k1
  endif

  call assert_fails('let x = &t_xx', 'E15')
  let &t_xx = "yes"
  call assert_equal("yes", &t_xx)
  let &t_xx = ""
  call assert_fails('let x = &t_xx', 'E15')
endfunc
