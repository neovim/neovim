" Test for wordcount() function

if !has('multi_byte')
  finish
endif

func Test_wordcount()
  let save_enc = &enc
  set encoding=utf-8
  set selection=inclusive fileformat=unix fileformats=unix

  new

  " Test 1: empty window
  call assert_equal({'chars': 0, 'cursor_chars': 0, 'words': 0, 'cursor_words': 0,
				\ 'bytes': 0, 'cursor_bytes': 0}, wordcount())

  " Test 2: some words, cursor at start
  call append(1, 'one two three')
  call cursor([1, 1, 0])
  call assert_equal({'chars': 15, 'cursor_chars': 1, 'words': 3, 'cursor_words': 0,
				\ 'bytes': 15, 'cursor_bytes': 1}, wordcount())

  " Test 3: some words, cursor at end
  %d _
  call append(1, 'one two three')
  call cursor([2, 99, 0])
  call assert_equal({'chars': 15, 'cursor_chars': 14, 'words': 3, 'cursor_words': 3,
				\ 'bytes': 15, 'cursor_bytes': 14}, wordcount())

  " Test 4: some words, cursor at end, ve=all
  set ve=all
  %d _
  call append(1, 'one two three')
  call cursor([2, 99, 0])
  call assert_equal({'chars': 15, 'cursor_chars': 15, 'words': 3, 'cursor_words': 3,
				\ 'bytes': 15, 'cursor_bytes': 15}, wordcount())
  set ve=

  " Test 5: several lines with words
  %d _
  call append(1, ['one two three', 'one two three', 'one two three'])
  call cursor([4, 99, 0])
  call assert_equal({'chars': 43, 'cursor_chars': 42, 'words': 9, 'cursor_words': 9,
				\ 'bytes': 43, 'cursor_bytes': 42}, wordcount())

  " Test 6: one line with BOM set
  %d _
  call append(1, 'one two three')
  set bomb
  w! Xtest
  call cursor([2, 99, 0])
  call assert_equal({'chars': 15, 'cursor_chars': 14, 'words': 3, 'cursor_words': 3,
				\ 'bytes': 18, 'cursor_bytes': 14}, wordcount())
  set nobomb
  w!
  call delete('Xtest')

  " Test 7: one line with multibyte words
  %d _
  call append(1, ['Äne M¤ne Müh'])
  call cursor([2, 99, 0])
  call assert_equal({'chars': 14, 'cursor_chars': 13, 'words': 3, 'cursor_words': 3,
				\ 'bytes': 17, 'cursor_bytes': 16}, wordcount())

  " Test 8: several lines with multibyte words
  %d _
  call append(1, ['Äne M¤ne Müh', 'und raus bist dü!'])
  call cursor([3, 99, 0])
  call assert_equal({'chars': 32, 'cursor_chars': 31, 'words': 7, 'cursor_words': 7,
				\ 'bytes': 36, 'cursor_bytes': 35}, wordcount())

  " Visual map to capture wordcount() in visual mode
  vnoremap <expr> <F2> execute("let g:visual_stat = wordcount()")

  " Test 9: visual mode, complete buffer
  let g:visual_stat = {}
  %d _
  call append(1, ['Äne M¤ne Müh', 'und raus bist dü!'])
  " start visual mode and select the complete buffer
  0
  exe "normal V2j\<F2>y"
  call assert_equal({'chars': 32, 'words': 7, 'bytes': 36, 'visual_chars': 32,
				\ 'visual_words': 7, 'visual_bytes': 36}, g:visual_stat)

  " Test 10: visual mode (empty)
  %d _
  call append(1, ['Äne M¤ne Müh', 'und raus bist dü!'])
  " start visual mode and select the complete buffer
  0
  exe "normal v$\<F2>y"
  call assert_equal({'chars': 32, 'words': 7, 'bytes': 36, 'visual_chars': 1,
				\ 'visual_words': 0, 'visual_bytes': 1}, g:visual_stat)

  " Test 11: visual mode, single line
  %d _
  call append(1, ['Äne M¤ne Müh', 'und raus bist dü!'])
  " start visual mode and select the complete buffer
  2
  exe "normal 0v$\<F2>y"
  call assert_equal({'chars': 32, 'words': 7, 'bytes': 36, 'visual_chars': 13,
				\ 'visual_words': 3, 'visual_bytes': 16}, g:visual_stat)

  set selection& fileformat& fileformats&
  let &enc = save_enc
  enew!
  close
endfunc
