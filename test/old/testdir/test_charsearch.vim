" Test for character search commands - t, T, f, F, ; and ,

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
  eval {'char': 'k'}->setcharsearch()
  normal! ;p
  call setcharsearch({'forward': 0})
  normal! $;p
  call setcharsearch({'until': 1})
  set cpo-=;
  normal! ;;p
  call assert_equal('ZabcdeZfghijkZZemnokqretkZvwxyz', getline(3))

  " check that repeating a search before and after a line fails
  normal 3Gfv
  call assert_beeps('normal ;')
  call assert_beeps('normal ,')

  " clear the character search
  call setcharsearch({'char' : ''})
  call assert_equal('', getcharsearch().char)
  call assert_beeps('normal ;')
  call assert_beeps('normal ,')

  call assert_fails("call setcharsearch([])", 'E1206:')
  enew!
endfunc

" Test for character search in virtual edit mode with <Tab>
func Test_csearch_virtualedit()
  new
  set virtualedit=all
  call setline(1, "a\tb")
  normal! tb
  call assert_equal([0, 1, 2, 6], getpos('.'))
  set virtualedit&
  bw!
endfunc

" Test for character search failure in latin1 encoding
func Test_charsearch_latin1()
  new
  let save_enc = &encoding
  " set encoding=latin1
  call setline(1, 'abcdefghijk')
  call assert_beeps('normal fz')
  call assert_beeps('normal tx')
  call assert_beeps('normal $Fz')
  call assert_beeps('normal $Tx')
  let &encoding = save_enc
  bw!
endfunc

" Test for using character search to find a multibyte character with composing
" characters.
func Test_charsearch_composing_char()
  new
  call setline(1, "one two thq\u0328\u0301r\u0328\u0301ree")
  call feedkeys("fr\u0328\u0301", 'xt')
  call assert_equal([0, 1, 16, 0, 12], getcurpos())

  " use character search with a multi-byte character followed by a
  " non-composing character
  call setline(1, "abc deȉf ghi")
  call feedkeys("ggcf\u0209\u0210", 'xt')
  call assert_equal("\u0210f ghi", getline(1))
  bw!
endfunc

" Test for character search with 'hkmap'
func Test_charsearch_hkmap()
  throw "Skipped: Nvim does not support 'hkmap'"
  new
  set hkmap
  call setline(1, "ùðáâ÷ëòéïçìêöî")
  call feedkeys("fë", 'xt')
  call assert_equal([0, 1, 11, 0, 6], getcurpos())
  set hkmap&
  bw!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
