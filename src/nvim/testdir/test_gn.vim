" Test for gn command

func Test_gn_command()
  set belloff=all
  noautocmd new
  " replace a single char by itsself quoted:
  call setline('.', 'abc x def x ghi x jkl')
  let @/ = 'x'
  exe "norm! cgn'x'\<esc>.."
  call assert_equal("abc 'x' def 'x' ghi 'x' jkl", getline('.'))
  sil! %d_

  " simple search match
  call setline('.', 'foobar')
  let @/ = 'foobar'
  exe "norm! gncsearchmatch"
  call assert_equal('searchmatch', getline('.'))
  sil! %d _

  " replace a multi-line match
  call setline('.', ['', 'one', 'two'])
  let @/ = 'one\_s*two\_s'
  exe "norm! gnceins\<CR>zwei"
  call assert_equal(['','eins','zwei'], getline(1,'$'))
  sil! %d _

  " test count argument
  call setline('.', ['', 'abcdx | abcdx | abcdx'])
  let @/ = '[a]bcdx'
  exe "norm! 2gnd"
  call assert_equal(['','abcdx |  | abcdx'], getline(1,'$'))
  sil! %d _

  " join lines
  call setline('.', ['join ', 'lines'])
  let @/ = '$'
  exe "norm! 0gnd"
  call assert_equal(['join lines'], getline(1,'$'))
  sil! %d _

  " zero-width match
  call setline('.', ['', 'zero width pattern'])
  let @/ = '\>\zs'
  exe "norm! 0gnd"
  call assert_equal(['', 'zerowidth pattern'], getline(1,'$'))
  sil! %d _

  " delete first and last chars
  call setline('.', ['delete first and last chars'])
  let @/ = '^'
  exe "norm! 0gnd$"
  let @/ = '\zs'
  exe "norm! gnd"
  call assert_equal(['elete first and last char'], getline(1,'$'))
  sil! %d _

  " using visual mode
  call setline('.', ['', 'uniquepattern uniquepattern'])
  exe "norm! /[u]niquepattern/s\<cr>vlgnd"
  call assert_equal(['', ' uniquepattern'], getline(1,'$'))
  sil! %d _

  " backwards search
  call setline('.', ['my very excellent mother just served us nachos'])
  let @/ = 'mother'
  exe "norm! $cgNmongoose"
  call assert_equal(['my very excellent mongoose just served us nachos'], getline(1,'$'))
  sil! %d _

  " search for single char
  call setline('.', ['','for (i=0; i<=10; i++)'])
  let @/ = 'i'
  exe "norm! cgnj"
  call assert_equal(['','for (j=0; i<=10; i++)'], getline(1,'$'))
  sil! %d _

  " search hex char
  call setline('.', ['','Y'])
  set noignorecase
  let @/ = '\%x59'
  exe "norm! gnd"
  call assert_equal(['',''], getline(1,'$'))
  sil! %d _

  " test repeating gdn
  call setline('.', ['', '1', 'Johnny', '2', 'Johnny', '3'])
  let @/ = 'Johnny'
  exe "norm! dgn."
  call assert_equal(['','1', '', '2', '', '3'], getline(1,'$'))
  sil! %d _

  " test repeating gUgn
  call setline('.', ['', '1', 'Depp', '2', 'Depp', '3'])
  let @/ = 'Depp'
  exe "norm! gUgn."
  call assert_equal(['', '1', 'DEPP', '2', 'DEPP', '3'], getline(1,'$'))
  sil! %d _

  " test using look-ahead assertions
  call setline('.', ['a:10', '', 'a:1', '', 'a:20'])
  let @/ = 'a:0\@!\zs\d\+'
  exe "norm! 2nygno\<esc>p"
  call assert_equal(['a:10', '', 'a:1', '1', '', 'a:20'], getline(1,'$'))
  sil! %d _

  " test using nowrapscan
  set nowrapscan
  call setline(1, 'foo bar baz')
  exe "norm! /bar/e\<cr>"
  exe "norm! gnd"
  call assert_equal(['foo  baz'], getline(1,'$'))
  sil! %d_

  " search upwards with nowrapscan set
  call setline('.', ['foo', 'bar', 'foo', 'baz'])
  set nowrapscan
  let @/ = 'foo'
  $
  norm! dgN
  call assert_equal(['foo', 'bar', '', 'baz'], getline(1,'$'))
  sil! %d_

  " search using the \zs atom
  call setline(1, [' nnoremap', '' , 'nnoremap'])
  set wrapscan&vim
  let @/ = '\_s\zsnnoremap'
  $
  norm! cgnmatch
  call assert_equal([' nnoremap', '', 'match'], getline(1,'$'))
  sil! %d_

  set wrapscan&vim
  set belloff&vim
endfu

" vim: shiftwidth=2 sts=2 expandtab
