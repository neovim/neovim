
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
  call assert_equal('testtar/', getline(5))
  call assert_equal('testtar/file1.txt', getline(6))

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
  call assert_equal('/etc/ax-pwn', getline(6))

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
  call assert_equal('/etc/ax-pwn', getline(6))

  call assert_equal(1, b:leading_slash)

  bw!
endfunc

func s:CreateTar(archivename, content, outputdir)
  let tempdir = tempname()
  call mkdir(tempdir, 'R')
  call writefile([a:content], tempdir .. '/X.txt')
  call assert_true(filereadable(tempdir .. '/X.txt'))
  call system('tar -C ' .. tempdir .. ' -cf ' .. a:outputdir .. '/' .. a:archivename .. ' X.txt')
  call assert_equal(0, v:shell_error)
endfunc

func s:CreateTgz(archivename, content, outputdir)
  let tempdir = tempname()
  call mkdir(tempdir, 'R')
  call writefile([a:content], tempdir .. '/X.txt')
  call assert_true(filereadable(tempdir .. '/X.txt'))
  call system('tar -C ' .. tempdir .. ' -czf ' .. a:outputdir .. '/' .. a:archivename .. ' X.txt')
  call assert_equal(0, v:shell_error)
endfunc

func s:CreateTbz(archivename, content, outputdir)
  let tempdir = tempname()
  call mkdir(tempdir, 'R')
  call writefile([a:content], tempdir .. '/X.txt')
  call assert_true(filereadable(tempdir .. '/X.txt'))
  call system('tar -C ' .. tempdir .. ' -cjf ' .. a:outputdir .. '/' .. a:archivename .. ' X.txt')
  call assert_equal(0, v:shell_error)
endfunc

func s:CreateTxz(archivename, content, outputdir)
  let tempdir = tempname()
  call mkdir(tempdir, 'R')
  call writefile([a:content], tempdir .. '/X.txt')
  call assert_true(filereadable(tempdir .. '/X.txt'))
  call system('tar -C ' .. tempdir .. ' -cJf ' .. a:outputdir .. '/' .. a:archivename .. ' X.txt')
  call assert_equal(0, v:shell_error)
endfunc

func s:CreateTzst(archivename, content, outputdir)
  let tempdir = tempname()
  call mkdir(tempdir, 'R')
  call writefile([a:content], tempdir .. '/X.txt')
  call assert_true(filereadable(tempdir .. '/X.txt'))
  call system('tar --zstd -C ' .. tempdir .. ' -cf ' .. a:outputdir .. '/' .. a:archivename .. ' X.txt')
  call assert_equal(0, v:shell_error)
endfunc

func s:CreateTlz4(archivename, content, outputdir)
  let tempdir = tempname()
  call mkdir(tempdir, 'R')
  call writefile([a:content], tempdir .. '/X.txt')
  call assert_true(filereadable(tempdir .. '/X.txt'))
  call system('tar -C ' .. tempdir .. ' -cf ' .. tempdir .. '/Xarchive.tar X.txt')
  call assert_equal(0, v:shell_error)
  call assert_true(filereadable(tempdir .. '/Xarchive.tar'))
  call system('lz4 -z ' .. tempdir .. '/Xarchive.tar ' .. a:outputdir .. '/' .. a:archivename)
  call assert_equal(0, v:shell_error)
endfunc

" XXX: Add test for .tar.bz3
func Test_extraction()
  let control = [
  \   #{create: function('s:CreateTar'),
  \     archive: 'Xarchive.tar'},
  \   #{create: function('s:CreateTgz'),
  \     archive: 'Xarchive.tgz'},
  \   #{create: function('s:CreateTgz'),
  \     archive: 'Xarchive.tar.gz'},
  \   #{create: function('s:CreateTbz'),
  \     archive: 'Xarchive.tbz'},
  \   #{create: function('s:CreateTbz'),
  \     archive: 'Xarchive.tar.bz2'},
  \   #{create: function('s:CreateTxz'),
  \     archive: 'Xarchive.txz'},
  \   #{create: function('s:CreateTxz'),
  \     archive: 'Xarchive.tar.xz'},
  \ ]

  if executable('lz4') == 1
    eval control->add(#{
    \   create: function('s:CreateTlz4'),
    \   archive: 'Xarchive.tar.lz4'
    \ })
    eval control->add(#{
    \   create: function('s:CreateTlz4'),
    \   archive: 'Xarchive.tlz4'
    \ })
  endif
  if executable('zstd') == 1
    eval control->add(#{
    \   create: function('s:CreateTzst'),
    \   archive: 'Xarchive.tar.zst'
    \ })
    eval control->add(#{
    \   create: function('s:CreateTzst'),
    \   archive: 'Xarchive.tzst'
    \ })
  endif

  for c in control
    let dir = tempname()
    call mkdir(dir, 'R')
    call call(c.create, [c.archive, 'hello', dir])

    call delete('X.txt')
    execute 'edit ' .. dir .. '/' .. c.archive
    call assert_equal('X.txt', getline(5), 'line 5 wrong in archive: ' .. c.archive)
    :5
    normal x
    call assert_equal(0, v:shell_error, 'vshell error not 0')
    call assert_true(filereadable('X.txt'), 'X.txt not readable for archive: ' .. c.archive)
    call assert_equal(['hello'], readfile('X.txt'), 'X.txt wrong contents for archive: ' .. c.archive)
    call delete('X.txt')
    call delete(dir .. '/' .. c.archive)
    bw!
  endfor
endfunc

func Test_extract_with_dotted_dir()
  call delete('X.txt')
  call writefile(['when they kiss they spit white noise'], 'X.txt')

  let dirname = tempname()
  call mkdir(dirname, 'R')
  let dirname = dirname .. '/foo.bar'
  call mkdir(dirname, 'R')
  let tarpath = dirname .. '/Xarchive.tar.gz'
  call system('tar -czf ' .. tarpath .. ' X.txt')
  call assert_true(filereadable(tarpath))
  call assert_equal(0, v:shell_error)

  call delete('X.txt')
  defer delete(tarpath)

  execute 'e ' .. tarpath
  call assert_equal('X.txt', getline(5))
  :5
  normal x
  call assert_true(filereadable('X.txt'))
  call assert_equal(['when they kiss they spit white noise'], readfile('X.txt'))
  call delete('X.txt')
  bw!
endfunc

func Test_extract_with_dotted_filename()
  call delete('X.txt')
  call writefile(['holiday inn'], 'X.txt')

  let dirname = tempname()
  call mkdir(dirname, 'R')
  let tarpath = dirname .. '/Xarchive.foo.tar.gz'
  call system('tar -czf ' .. tarpath .. ' X.txt')
  call assert_true(filereadable(tarpath))
  call assert_equal(0, v:shell_error)

  call delete('X.txt')
  defer delete(tarpath)

  execute 'e ' .. tarpath
  call assert_equal('X.txt', getline(5))
  :5
  normal x
  call assert_true(filereadable('X.txt'))
  call assert_equal(['holiday inn'], readfile('X.txt'))
  call delete('X.txt')
  bw!
endfunc
