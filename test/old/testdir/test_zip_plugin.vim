so check.vim

CheckExecutable unzip

if 0 " Find uncovered line
  profile start zip_profile
  profile! file */zip*.vim
endif

runtime plugin/zipPlugin.vim

func Test_zip_basic()

  "## get our zip file
  if !filecopy("samples/test.zip", "X.zip")
    call assert_report("Can't copy samples/test.zip")
    return
  endif
  defer delete("X.zip")

  e X.zip

  "## Check header
  call assert_match('^" zip\.vim version v\d\+', getline(1))
  call assert_match('^" Browsing zipfile .*/X.zip', getline(2))
  call assert_match('^" Select a file with cursor and press ENTER', getline(3))
  call assert_match('^$', getline(4))

  "## Check files listing
  call assert_equal(["Xzip/", "Xzip/dir/", "Xzip/file.txt"], getline(5, 7))

  "## Check ENTER on header
  :1
  exe ":normal \<cr>"
  call assert_equal("X.zip", @%)

  "## Check ENTER on directory
  :1|:/^$//dir/
  call assert_match('Please specify a file, not a directory',
                  \ execute("normal \<CR>"))

  "## Check ENTER on file
  :1
  call search('file.txt')
  exe ":normal \<cr>"
  call assert_match('zipfile://.*/X.zip::Xzip/file.txt', @%)
  call assert_equal('one', getline(1))

  "## Check editing file
  if executable("zip")
    s/one/two/
    call assert_equal("two", getline(1))
    w
    bw|bw
    e X.zip

    :1|:/^$//file/
    exe "normal \<cr>"
    call assert_equal("two", getline(1))
  endif

  only
  e X.zip

  "## Check extracting file
  :1|:/^$//file/
  normal x
  call assert_true(filereadable("Xzip/file.txt"))

  "## Check not overwriting existing file
  call assert_match('<Xzip/file.txt> .* not overwriting!', execute("normal x"))

  call delete("Xzip", "rf")

  "## Check extracting directory
  :1|:/^$//dir/
  call assert_match('Please specify a file, not a directory', execute("normal x"))
  call assert_equal("X.zip", @%)

  "## Check "x" on header
  :1
  normal x
  call assert_equal("X.zip", @%)
  bw

  "## Check opening zip when "unzip" program is missing
  let save_zip_unzipcmd = g:zip_unzipcmd
  let g:zip_unzipcmd = "/"
  call assert_match('unzip not available on your system', execute("e X.zip"))

  "## Check when "unzip" don't work
  if executable("false")
    let g:zip_unzipcmd = "false"
    call assert_match('X\.zip is not a zip file', execute("e X.zip"))
  endif
  bw

  let g:zip_unzipcmd = save_zip_unzipcmd
  e X.zip

  "## Check opening file when "unzip" is missing
  let g:zip_unzipcmd = "/"
  call assert_match('sorry, your system doesn''t appear to have the / program',
                  \ execute("normal \<CR>"))

  bw|bw
  let g:zip_unzipcmd = save_zip_unzipcmd
  e X.zip

  "## Check :write when "zip" program is missing
  :1|:/^$//file/
  exe "normal \<cr>Goanother\<esc>"
  let save_zip_zipcmd = g:zip_zipcmd
  let g:zip_zipcmd = "/"
  call assert_match('sorry, your system doesn''t appear to have the / program',
                  \ execute("write"))

  "## Check when "zip" report failure
  if executable("false")
    let g:zip_zipcmd = "false"
    call assert_match('sorry, unable to update .*/X.zip with Xzip/file.txt',
                    \ execute("write"))
  endif
  bw!|bw

  let g:zip_zipcmd = save_zip_zipcmd

  "## Check opening an no zipfile
  call writefile(["qsdf"], "Xcorupt.zip", "D")
  e! Xcorupt.zip
  call assert_equal("qsdf", getline(1))

  bw

  "## Check no existing zipfile
  call assert_match('File not readable', execute("e Xnot_exists.zip"))

  bw
endfunc

func Test_zip_glob_fname()
  CheckNotMSWindows
  " does not work on Windows, why?

  "## copy sample zip file
  if !filecopy("samples/testa.zip", "X.zip")
    call assert_report("Can't copy samples/testa.zip")
    return
  endif
  defer delete("X.zip")
  defer delete('zipglob', 'rf')

  e X.zip

  "## 1) Check extracting strange files
  :1
  let fname = 'a[a].txt'
  call search('\V' .. fname)
  normal x
  call assert_true(filereadable('zipglob/' .. fname))
  call delete('zipglob', 'rf')

  :1
  let fname = 'a*.txt'
  call search('\V' .. fname)
  normal x
  call assert_true(filereadable('zipglob/' .. fname))
  call delete('zipglob', 'rf')

  :1
  let fname = 'a?.txt'
  call search('\V' .. fname)
  normal x
  call assert_true(filereadable('zipglob/' .. fname))
  call delete('zipglob', 'rf')

  :1
  let fname = 'a\.txt'
  call search('\V' .. escape(fname, '\\'))
  normal x
  call assert_true(filereadable('zipglob/' .. fname))
  call delete('zipglob', 'rf')

  :1
  let fname = 'a\\.txt'
  call search('\V' .. escape(fname, '\\'))
  normal x
  call assert_true(filereadable('zipglob/' .. fname))
  call delete('zipglob', 'rf')

  "## 2) Check entering strange file names
  :1
  let fname = 'a[a].txt'
  call search('\V' .. fname)
  exe ":normal \<cr>"
  call assert_match('zipfile://.*/X.zip::zipglob/a\[a\].txt', @%)
  call assert_equal('a test file with []', getline(1))
  bw

  e X.zip
  :1
  let fname = 'a*.txt'
  call search('\V' .. fname)
  exe ":normal \<cr>"
  call assert_match('zipfile://.*/X.zip::zipglob/a\*.txt', @%)
  call assert_equal('a test file with a*', getline(1))
  bw

  e X.zip
  :1
  let fname = 'a?.txt'
  call search('\V' .. fname)
  exe ":normal \<cr>"
  call assert_match('zipfile://.*/X.zip::zipglob/a?.txt', @%)
  call assert_equal('a test file with a?', getline(1))
  bw

  e X.zip
  :1
  let fname = 'a\.txt'
  call search('\V' .. escape(fname, '\\'))
  exe ":normal \<cr>"
  call assert_match('zipfile://.*/X.zip::zipglob/a\\.txt', @%)
  call assert_equal('a test file with a\', getline(1))
  bw

  e X.zip
  :1
  let fname = 'a\\.txt'
  call search('\V' .. escape(fname, '\\'))
  exe ":normal \<cr>"
  call assert_match('zipfile://.*/X.zip::zipglob/a\\\\.txt', @%)
  call assert_equal('a test file with a double \', getline(1))
  bw

  bw
endfunc
