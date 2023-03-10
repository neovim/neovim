" Test for gn command

func Test_gn_command()
  noautocmd new
  " replace a single char by itself quoted:
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

  " make sure it works correctly for one-char wide search items
  call setline('.', ['abcdefghi'])
  let @/ = 'a'
  exe "norm! 0fhvhhgNgU"
  call assert_equal(['ABCDEFGHi'], getline(1,'$'))
  call setline('.', ['abcdefghi'])
  let @/ = 'b'
  " this gn wraps around the end of the file
  exe "norm! 0fhvhhgngU"
  call assert_equal(['aBCDEFGHi'], getline(1,'$'))
  sil! %d _
  call setline('.', ['abcdefghi'])
  let @/ = 'f'
  exe "norm! 0vllgngU"
  call assert_equal(['ABCDEFghi'], getline(1,'$'))
  sil! %d _
  call setline('.', ['12345678'])
  let @/ = '5'
  norm! gg0f7vhhhhgnd
  call assert_equal(['12348'], getline(1,'$'))
  sil! %d _
  call setline('.', ['12345678'])
  let @/ = '5'
  norm! gg0f2vf7gNd
  call assert_equal(['1678'], getline(1,'$'))
  sil! %d _
  set wrapscan&vim

  " Without 'wrapscan', in visual mode, running gn without a match should fail
  " but the visual mode should be kept.
  set nowrapscan
  call setline('.', 'one two')
  let @/ = 'one'
  call assert_beeps('normal 0wvlgn')
  exe "normal y"
  call assert_equal('tw', @")

  " with exclusive selection, run gn and gN
  set selection=exclusive
  normal 0gny
  call assert_equal('one', @")
  normal 0wgNy
  call assert_equal('one', @")
  set selection&
endfunc

func Test_gN_repeat()
  new
  call setline(1, 'this list is a list with a list of a list.')
  /list
  normal $gNgNgNx
  call assert_equal('list with a list of a list', @")
  bwipe!
endfunc

func Test_gN_then_gn()
  new

  call setline(1, 'this list is a list with a list of a last.')
  /l.st
  normal $gNgNgnx
  call assert_equal('last', @")

  call setline(1, 'this list is a list with a lust of a last.')
  /l.st
  normal $gNgNgNgnx
  call assert_equal('lust of a last', @")

  bwipe!
endfunc

func Test_gn_multi_line()
  new
  call setline(1, [
        \ 'func Tm1()',
        \ ' echo "one"',
        \ 'endfunc',
        \ 'func Tm2()',
        \ ' echo "two"',
        \ 'endfunc',
        \ 'func Tm3()',
        \ ' echo "three"',
        \ 'endfunc',
        \])
  /\v^func Tm\d\(\)\n.*\zs".*"\ze$
  normal jgnrx
  call assert_equal(' echo xxxxx', getline(5))
  bwipe!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
