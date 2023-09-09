" Inserts 2 million lines with consecutive integers starting from 1
" (essentially, the output of GNU's seq 1 2000000), writes them to Xtest
" and writes its cksum to test.out.
"
" We need 2 million lines to trigger a call to mf_hash_grow().  If it would mess
" up the lines the checksum would differ.
"
" cksum is part of POSIX and so should be available on most Unixes.
" If it isn't available then the test will be skipped.
func Test_File_Size()
  if !executable('cksum')
      return
  endif

  new
  set fileformat=unix undolevels=-1
  for i in range(1, 2000000, 100)
      call append(i, range(i, i + 99))
  endfor

  1delete
  w! Xtest
  let res = systemlist('cksum Xtest')[0]
  let res = substitute(res, "\r", "", "")
  call assert_equal('3678979763 14888896 Xtest', res)

  enew!
  call delete('Xtest')
  set fileformat& undolevels&
endfunc

" Test for writing and reading a file of over 100 Kbyte
func Test_File_Read_Write()
  enew!

  " Create a file with the following contents
  " 1 line: "This is the start"
  " 3001 lines: "This is the leader"
  " 1 line: "This is the middle"
  " 3001 lines: "This is the trailer"
  " 1 line: "This is the end"
  call append(0, "This is the start")
  call append(1, repeat(["This is the leader"], 3001))
  call append(3002, "This is the middle")
  call append(3003, repeat(["This is the trailer"], 3001))
  call append(6004, "This is the end")

  write! Xtest
  enew!
  edit! Xtest

  call assert_equal("This is the start", getline(1))
  call assert_equal("This is the middle", getline(3003))
  call assert_equal("This is the end", getline(6005))

  enew!
  call delete("Xtest")
endfunc
