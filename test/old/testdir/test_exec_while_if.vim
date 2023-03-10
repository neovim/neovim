" Test for :execute, :while, :for and :if

func Test_exec_while_if()
  new

  let i = 0
  while i < 12
    let i = i + 1
    execute "normal o" . i . "\033"
    if i % 2
      normal Ax
      if i == 9
        break
      endif
      if i == 5
        continue
      else
        let j = 9
        while j > 0
          execute "normal" j . "a" . j . "\x1b"
          let j = j - 1
        endwhile
      endif
    endif
    if i == 9
      execute "normal Az\033"
    endif
  endwhile
  unlet i j

  call assert_equal(["",
        \ "1x999999999888888887777777666666555554444333221",
        \ "2",
        \ "3x999999999888888887777777666666555554444333221",
        \ "4",
        \ "5x",
        \ "6",
        \ "7x999999999888888887777777666666555554444333221",
        \ "8",
        \ "9x"], getline(1, 10))
endfunc

" vim: shiftwidth=2 sts=2 expandtab
