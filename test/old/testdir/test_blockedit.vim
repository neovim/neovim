" Test for block inserting
"

func Test_blockinsert_indent()
  new
  filetype plugin indent on
  setlocal sw=2 et ft=vim
  call setline(1, ['let a=[', '  ''eins'',', '  ''zwei'',', '  ''drei'']'])
  call cursor(2, 3)
  exe "norm! \<c-v>2jI\\ \<esc>"
  call assert_equal(['let a=[', '      \ ''eins'',', '      \ ''zwei'',', '      \ ''drei'']'],
        \ getline(1,'$'))
  " reset to sane state
  filetype off
  bwipe!
endfunc

func Test_blockinsert_autoindent()
  new
  let lines =<< trim END
      vim9script
      var d = {
      a: () => 0,
      b: () => 0,
      c: () => 0,
      }
  END
  call setline(1, lines)
  filetype plugin indent on
  setlocal sw=2 et ft=vim
  setlocal indentkeys+=:
  exe "norm! 3Gf)\<c-v>2jA: asdf\<esc>"
  let expected =<< trim END
      vim9script
      var d = {
        a: (): asdf => 0,
      b: (): asdf => 0,
      c: (): asdf => 0,
      }
  END
  call assert_equal(expected, getline(1, 6))

  " insert on the next column should do exactly the same
  :%dele
  call setline(1, lines)
  exe "norm! 3Gf)l\<c-v>2jI: asdf\<esc>"
  call assert_equal(expected, getline(1, 6))

  :%dele
  call setline(1, lines)
  setlocal sw=8 noet
  exe "norm! 3Gf)\<c-v>2jA: asdf\<esc>"
  let expected =<< trim END
      vim9script
      var d = {
	a: (): asdf => 0,
      b: (): asdf => 0,
      c: (): asdf => 0,
      }
  END
  call assert_equal(expected, getline(1, 6))

  " insert on the next column should do exactly the same
  :%dele
  call setline(1, lines)
  exe "norm! 3Gf)l\<c-v>2jI: asdf\<esc>"
  call assert_equal(expected, getline(1, 6))

  filetype off
  bwipe!
endfunc

func Test_blockinsert_delete()
  new
  let _bs = &bs
  set bs=2
  call setline(1, ['case Arg is ', '        when Name_Async,', '        when Name_Num_Gangs,', 'end if;'])
  exe "norm! ggjVj\<c-v>$o$A\<bs>\<esc>"
  "call feedkeys("Vj\<c-v>$o$A\<bs>\<esc>", 'ti')
  call assert_equal(["case Arg is ", "        when Name_Async", "        when Name_Num_Gangs,", "end if;"],
        \ getline(1,'$'))
  " reset to sane state
  let &bs = _bs
  bwipe!
endfunc

func Test_blockappend_eol_cursor()
  new
  " Test 1 Move 1 char left
  call setline(1, ['aaa', 'bbb', 'ccc'])
  exe "norm! gg$\<c-v>2jA\<left>x\<esc>"
  call assert_equal(['aaxa', 'bbxb', 'ccxc'], getline(1, '$'))
  " Test 2 Move 2 chars left
  sil %d
  call setline(1, ['aaa', 'bbb', 'ccc'])
  exe "norm! gg$\<c-v>2jA\<left>\<left>x\<esc>"
  call assert_equal(['axaa', 'bxbb', 'cxcc'], getline(1, '$'))
  " Test 3 Move 3 chars left (outside of the visual selection)
  sil %d
  call setline(1, ['aaa', 'bbb', 'ccc'])
  exe "norm! ggl$\<c-v>2jA\<left>\<left>\<left>x\<esc>"
  call assert_equal(['xaaa', 'bbb', 'ccc'], getline(1, '$'))
  bw!
endfunc

func Test_blockappend_eol_cursor2()
  new
  " Test 1 Move 1 char left
  call setline(1, ['aaaaa', 'bbb', 'ccccc'])
  exe "norm! gg\<c-v>$2jA\<left>x\<esc>"
  call assert_equal(['aaaaxa', 'bbbx', 'ccccxc'], getline(1, '$'))
  " Test 2 Move 2 chars left
  sil %d
  call setline(1, ['aaaaa', 'bbb', 'ccccc'])
  exe "norm! gg\<c-v>$2jA\<left>\<left>x\<esc>"
  call assert_equal(['aaaxaa', 'bbbx', 'cccxcc'], getline(1, '$'))
  " Test 3 Move 3 chars left (to the beginning of the visual selection)
  sil %d
  call setline(1, ['aaaaa', 'bbb', 'ccccc'])
  exe "norm! gg\<c-v>$2jA\<left>\<left>\<left>x\<esc>"
  call assert_equal(['aaxaaa', 'bbxb', 'ccxccc'], getline(1, '$'))
  " Test 4 Move 3 chars left (outside of the visual selection)
  sil %d
  call setline(1, ['aaaaa', 'bbb', 'ccccc'])
  exe "norm! ggl\<c-v>$2jA\<left>\<left>\<left>x\<esc>"
  call assert_equal(['aaxaaa', 'bbxb', 'ccxccc'], getline(1, '$'))
  " Test 5 Move 4 chars left (outside of the visual selection)
  sil %d
  call setline(1, ['aaaaa', 'bbb', 'ccccc'])
  exe "norm! ggl\<c-v>$2jA\<left>\<left>\<left>\<left>x\<esc>"
  call assert_equal(['axaaaa', 'bxbb', 'cxcccc'], getline(1, '$'))
  bw!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
