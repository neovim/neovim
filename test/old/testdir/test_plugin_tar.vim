
CheckExecutable tar
CheckNotMSWindows

runtime plugin/tarPlugin.vim

func s:CopyFile(source)
  if !filecopy($"samples/{a:source}", "X.tar")
    call assert_report($"Can't copy samples/{a:source}")
  endif
endfunc

func Test_tar_basic()
  call s:CopyFile("sample.tar")
  defer delete("X.tar")
  defer delete("./testtar", 'rf')
  e X.tar

  "## Check header
  call assert_match('^" tar\.vim version v\d\+', getline(1))
  call assert_match('^" Browsing tarfile .*/X.tar', getline(2))
  call assert_match('^" Select a file with cursor and press ENTER, "x" to extract a file', getline(3))
  call assert_match('^$', getline(4))
  call assert_match('testtar/', getline(5))
  call assert_match('testtar/file1.txt', getline(6))

  "## Check ENTER on header
  :1
  exe ":normal \<cr>"
  call assert_equal("X.tar", @%)

  "## Check ENTER on file
  :6
  exe ":normal \<cr>"
  call assert_equal("tarfile::testtar/file1.txt", @%)


  "## Check editing file
  "## Note: deleting entries not supported on BSD
  if has("mac")
    return
  endif
  if has("bsd")
    return
  endif
  s/.*/some-content/
  call assert_equal("some-content", getline(1))
  w!
  call assert_equal("tarfile::testtar/file1.txt", @%)
  bw!
  close
  bw!

  e X.tar
  :6
  exe "normal \<cr>"
  call assert_equal("some-content", getline(1))
  bw!
  close

  "## Check extracting file
  :5
  normal x
  call assert_true(filereadable("./testtar/file1.txt"))
  bw!
endfunc

func Test_tar_evil()
  " On s390x, tar outputs its full path in warning messages (e.g. /usr/bin/tar: Removing leading '/')
  " which tar.vim doesn't handle, causing path traversal detection to fail.
  CheckNotS390
  call s:CopyFile("evil.tar")
  defer delete("X.tar")
  defer delete("./etc", 'rf')
  e X.tar

  "## Check header
  call assert_match('^" tar\.vim version v\d\+', getline(1))
  call assert_match('^" Browsing tarfile .*/X.tar', getline(2))
  call assert_match('^" Select a file with cursor and press ENTER, "x" to extract a file', getline(3))
  call assert_match('^" Note: Path Traversal Attack detected', getline(4))
  call assert_match('^$', getline(5))
  call assert_match('/etc/ax-pwn', getline(6))

  "## Check ENTER on header
  :1
  exe ":normal \<cr>"
  call assert_equal("X.tar", @%)
  call assert_equal(1, b:leading_slash)

  "## Check ENTER on file
  :6
  exe ":normal \<cr>"
  call assert_equal(1, b:leading_slash)
  call assert_equal("tarfile::/etc/ax-pwn", @%)


  "## Check editing file
  "## Note: deleting entries not supported on BSD
  if has("mac")
    return
  endif
  if has("bsd")
    return
  endif
  s/.*/none/
  call assert_equal("none", getline(1))
  w!
  call assert_equal(1, b:leading_slash)
  call assert_equal("tarfile::/etc/ax-pwn", @%)
  bw!
  close
  bw!

  " Writing was aborted
  e X.tar
  call assert_match('^" Note: Path Traversal Attack detected', getline(4))
  :6
  exe "normal \<cr>"
  call assert_equal("something", getline(1))
  bw!
  close

  "## Check extracting file
  :5
  normal x
  call assert_true(filereadable("./etc/ax-pwn"))

  bw!
endfunc

func Test_tar_path_traversal_with_nowrapscan()
  CheckNotS390
  call s:CopyFile("evil.tar")
  defer delete("X.tar")
  " Make sure we still find the tar warning (or leading slashes) even when
  " wrapscan is off
  set nowrapscan
  e X.tar

  "## Check header
  call assert_match('^" tar\.vim version v\d\+', getline(1))
  call assert_match('^" Browsing tarfile .*/X.tar', getline(2))
  call assert_match('^" Select a file with cursor and press ENTER, "x" to extract a file', getline(3))
  call assert_match('^" Note: Path Traversal Attack detected', getline(4))
  call assert_match('^$', getline(5))
  call assert_match('/etc/ax-pwn', getline(6))

  call assert_equal(1, b:leading_slash)

  bw!
endfunc

func Test_tar_lz4_extract()
  CheckExecutable lz4

  call delete('X.txt')
  call delete('Xarchive.tar')
  call delete('Xarchive.tar.lz4')
  call writefile(['hello'], 'X.txt')
  call system('tar -cf Xarchive.tar X.txt')
  call assert_equal(0, v:shell_error)

  call system('lz4 -z Xarchive.tar Xarchive.tar.lz4')
  call assert_equal(0, v:shell_error)

  call delete('X.txt')
  call delete('Xarchive.tar')
  defer delete('Xarchive.tar.lz4')

  e Xarchive.tar.lz4
  call assert_match('X.txt', getline(5))
  :5
  normal x
  call assert_true(filereadable('X.txt'))
  call assert_equal(['hello'], readfile('X.txt'))
  call delete('X.txt')
  bw!
endfunc

func Test_tlz4_extract()
  CheckExecutable lz4

  call delete('X.txt')
  call delete('Xarchive.tar')
  call delete('Xarchive.tlz4')
  call writefile(['goodbye'], 'X.txt')
  call system('tar -cf Xarchive.tar X.txt')
  call assert_equal(0, v:shell_error)

  call system('lz4 -z Xarchive.tar Xarchive.tlz4')
  call assert_equal(0, v:shell_error)

  call delete('X.txt')
  call delete('Xarchive.tar')
  defer delete('Xarchive.tlz4')

  e Xarchive.tlz4
  call assert_match('X.txt', getline(5))
  :5
  normal x
  call assert_true(filereadable('X.txt'))
  call assert_equal(['goodbye'], readfile('X.txt'))
  call delete('X.txt')
  bw!
endfunc
