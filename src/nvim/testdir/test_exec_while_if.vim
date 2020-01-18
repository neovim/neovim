" Test for :execute, :while and :if

function Test_exec_while_if()
  new

  let i = 0
  while i < 12
    let i = i + 1
    if has("ebcdic")
      execute "normal o" . i . "\047"
    else
      execute "normal o" . i . "\033"
    endif
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
          if has("ebcdic")
            execute "normal" j . "a" . j . "\x27"
          else
            execute "normal" j . "a" . j . "\x1b"
          endif
          let j = j - 1
        endwhile
      endif
    endif
    if i == 9
      if has("ebcdic")
        execute "normal Az\047"
      else
        execute "normal Az\033"
      endif
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
endfunction
