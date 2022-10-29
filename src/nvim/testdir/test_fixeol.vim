" Tests for 'fixeol', 'eof' and 'eol'

func Test_fixeol()
  " first write two test files – with and without trailing EOL
  " use Unix fileformat for consistency
  set ff=unix
  enew!
  call setline('.', 'with eol or eof')
  w! XXEol
  enew!
  set noeof noeol nofixeol
  call setline('.', 'without eol or eof')
  w! XXNoEol
  set eol eof fixeol
  bwipe XXEol XXNoEol

  " try editing files with 'fixeol' disabled
  e! XXEol
  normal ostays eol
  set nofixeol
  w! XXTestEol
  e! XXNoEol
  normal ostays without
  set nofixeol
  w! XXTestNoEol
  bwipe! XXEol XXNoEol XXTestEol XXTestNoEol
  set fixeol

  " Append "END" to each file so that we can see what the last written char
  " was.
  normal ggdGaEND
  w >>XXEol
  w >>XXNoEol
  w >>XXTestEol
  w >>XXTestNoEol

  call assert_equal(['with eol or eof', 'END'], readfile('XXEol'))
  call assert_equal(['without eol or eofEND'], readfile('XXNoEol'))
  call assert_equal(['with eol or eof', 'stays eol', 'END'], readfile('XXTestEol'))
  call assert_equal(['without eol or eof', 'stays withoutEND'],
	      \ readfile('XXTestNoEol'))

  call delete('XXEol')
  call delete('XXNoEol')
  call delete('XXTestEol')
  call delete('XXTestNoEol')
  set ff& fixeol& eof& eol&
  enew!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
