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

func Test_eof()
  let data = 0z68656c6c6f.0d0a.776f726c64   " "hello\r\nworld"

  " 1. Eol, Eof
  " read
  call writefile(data + 0z0d0a.1a, 'XXEolEof')
  e! XXEolEof
  call assert_equal(['hello', 'world'], getline(1, 2))
  call assert_equal([1, 1], [&eol, &eof])
  " write
  set fixeol
  w!
  call assert_equal(data + 0z0d0a, readblob('XXEolEof'))
  set nofixeol
  w!
  call assert_equal(data + 0z0d0a.1a, readblob('XXEolEof'))

  " 2. NoEol, Eof
  " read
  call writefile(data + 0z1a, 'XXNoEolEof')
  e! XXNoEolEof
  call assert_equal(['hello', 'world'], getline(1, 2))
  call assert_equal([0, 1], [&eol, &eof])
  " write
  set fixeol
  w!
  call assert_equal(data + 0z0d0a, readblob('XXNoEolEof'))
  set nofixeol
  w!
  call assert_equal(data + 0z1a, readblob('XXNoEolEof'))

  " 3. Eol, NoEof
  " read
  call writefile(data + 0z0d0a, 'XXEolNoEof')
  e! XXEolNoEof
  call assert_equal(['hello', 'world'], getline(1, 2))
  call assert_equal([1, 0], [&eol, &eof])
  " write
  set fixeol
  w!
  call assert_equal(data + 0z0d0a, readblob('XXEolNoEof'))
  set nofixeol
  w!
  call assert_equal(data + 0z0d0a, readblob('XXEolNoEof'))

  " 4. NoEol, NoEof
  " read
  call writefile(data, 'XXNoEolNoEof')
  e! XXNoEolNoEof
  call assert_equal(['hello', 'world'], getline(1, 2))
  call assert_equal([0, 0], [&eol, &eof])
  " write
  set fixeol
  w!
  call assert_equal(data + 0z0d0a, readblob('XXNoEolNoEof'))
  set nofixeol
  w!
  call assert_equal(data, readblob('XXNoEolNoEof'))

  call delete('XXEolEof')
  call delete('XXNoEolEof')
  call delete('XXEolNoEof')
  call delete('XXNoEolNoEof')
  set ff& fixeol& eof& eol&
  enew!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
