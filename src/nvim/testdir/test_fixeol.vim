" Tests for 'fixeol' and 'eol'
func Test_fixeol()
  " first write two test files – with and without trailing EOL
  " use Unix fileformat for consistency
  set ff=unix
  enew!
  call setline('.', 'with eol')
  w! XXEol
  enew!
  set noeol nofixeol
  call setline('.', 'without eol')
  w! XXNoEol
  set eol fixeol
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

  call assert_equal(['with eol', 'END'], readfile('XXEol'))
  call assert_equal(['without eolEND'], readfile('XXNoEol'))
  call assert_equal(['with eol', 'stays eol', 'END'], readfile('XXTestEol'))
  call assert_equal(['without eol', 'stays withoutEND'],
	      \ readfile('XXTestNoEol'))

  call delete('XXEol')
  call delete('XXNoEol')
  call delete('XXTestEol')
  call delete('XXTestNoEol')
  set ff& fixeol& eol&
  enew!
endfunc
