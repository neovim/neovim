
func Test_charsearch()
  enew!
  call append(0, ['Xabcdefghijkemnopqretuvwxyz',
	      \ 'Yabcdefghijkemnopqretuvwxyz',
	      \ 'Zabcdefghijkemnokqretkvwxyz'])
  " check that "fe" and ";" work
  1
  normal! ylfep;;p,,p
  call assert_equal('XabcdeXfghijkeXmnopqreXtuvwxyz', getline(1))
  " check that save/restore works
  2
  normal! ylfep
  let csave = getcharsearch()
  normal! fip
  call setcharsearch(csave)
  normal! ;p;p
  call assert_equal('YabcdeYfghiYjkeYmnopqreYtuvwxyz', getline(2))

  " check that setcharsearch() changes the settings.
  3
  normal! ylfep
  call setcharsearch({'char': 'k'})
  normal! ;p
  call setcharsearch({'forward': 0})
  normal! $;p
  call setcharsearch({'until': 1})
  set cpo-=;
  normal! ;;p
  call assert_equal('ZabcdeZfghijkZZemnokqretkZvwxyz', getline(3))
  enew!
endfunc

" Test for t,f,F,T movement commands and 'cpo-;' setting
func Test_search_cmds()
  enew!
  call append(0, ["aaa two three four", "    zzz", "yyy   ",
	      \ "bbb yee yoo four", "ccc two three four",
	      \ "ddd yee yoo four"])
  set cpo-=;
  1
  normal! 0tt;D
  2
  normal! 0fz;D
  3
  normal! $Fy;D
  4
  normal! $Ty;D
  set cpo+=;
  5
  normal! 0tt;;D
  6
  normal! $Ty;;D

  call assert_equal('aaa two', getline(1))
  call assert_equal('    z', getline(2))
  call assert_equal('y', getline(3))
  call assert_equal('bbb y', getline(4))
  call assert_equal('ccc', getline(5))
  call assert_equal('ddd yee y', getline(6))
  enew!
endfunc
