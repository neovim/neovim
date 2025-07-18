
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
