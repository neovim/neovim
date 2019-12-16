" Tests for the swap feature

func s:swapname()
  return trim(execute('swapname'))
endfunc

" Tests for 'directory' option.
func Test_swap_directory()
  if !has("unix")
    return
  endif
  let content = ['start of testfile',
	      \ 'line 2 Abcdefghij',
	      \ 'line 3 Abcdefghij',
	      \ 'end of testfile']
  call writefile(content, 'Xtest1')

  "  '.', swap file in the same directory as file
  set dir=.,~

  " Verify that the swap file doesn't exist in the current directory
  call assert_equal([], glob(".Xtest1*.swp", 1, 1, 1))
  edit Xtest1
  let swfname = s:swapname()
  call assert_equal([swfname], glob(swfname, 1, 1, 1))

  " './dir', swap file in a directory relative to the file
  set dir=./Xtest2,.,~

  call mkdir("Xtest2")
  edit Xtest1
  call assert_equal([], glob(swfname, 1, 1, 1))
  let swfname = "Xtest2/Xtest1.swp"
  call assert_equal(swfname, s:swapname())
  call assert_equal([swfname], glob("Xtest2/*", 1, 1, 1))

  " 'dir', swap file in directory relative to the current dir
  set dir=Xtest.je,~

  call mkdir("Xtest.je")
  call writefile(content, 'Xtest2/Xtest3')
  edit Xtest2/Xtest3
  call assert_equal(["Xtest2/Xtest3"], glob("Xtest2/*", 1, 1, 1))
  let swfname = "Xtest.je/Xtest3.swp"
  call assert_equal(swfname, s:swapname())
  call assert_equal([swfname], glob("Xtest.je/*", 1, 1, 1))

  set dir&
  call delete("Xtest1")
  call delete("Xtest2", "rf")
  call delete("Xtest.je", "rf")
endfunc

func Test_swap_group()
  if !has("unix")
    return
  endif
  let groups = split(system('groups'))
  if len(groups) <= 1
    throw 'Skipped: need at least two groups, got ' . string(groups)
  endif

  try
    call delete('Xtest')
    split Xtest
    call setline(1, 'just some text')
    wq
    if system('ls -l Xtest') !~ ' ' . groups[0] . ' \d'
      throw 'Skipped: test file does not have the first group'
    else
      silent !chmod 640 Xtest
      call system('chgrp ' . groups[1] . ' Xtest')
      if system('ls -l Xtest') !~ ' ' . groups[1] . ' \d'
	throw 'Skipped: cannot set second group on test file'
      else
	split Xtest
	let swapname = substitute(execute('swapname'), '[[:space:]]', '', 'g')
	call assert_match('Xtest', swapname)
	" Group of swapfile must now match original file.
	call assert_match(' ' . groups[1] . ' \d', system('ls -l ' . swapname))

	bwipe!
      endif
    endif
  finally
    call delete('Xtest')
  endtry
endfunc

func Test_missing_dir()
  call mkdir('Xswapdir')
  exe 'set directory=' . getcwd() . '/Xswapdir'

  call assert_equal('', glob('foo'))
  call assert_equal('', glob('bar'))
  edit foo/x.txt
  " This should not give a warning for an existing swap file.
  split bar/x.txt
  only

  " Delete the buffer so that swap file is removed before we try to delete the
  " directory.  That fails on MS-Windows.
  %bdelete!
  set directory&
  call delete('Xswapdir', 'rf')
endfunc

func Test_swapinfo()
  new Xswapinfo
  call setline(1, ['one', 'two', 'three'])
  w
  let fname = s:swapname()
  call assert_match('Xswapinfo', fname)
  let info = swapinfo(fname)

  let ver = printf('VIM %d.%d', v:version / 100, v:version % 100)
  call assert_equal(ver, info.version)

  call assert_match('\w', info.user)
  " host name is truncated to 39 bytes in the swap file
  call assert_equal(hostname()[:38], info.host)
  call assert_match('Xswapinfo', info.fname)
  call assert_match(0, info.dirty)
  call assert_equal(getpid(), info.pid)
  call assert_match('^\d*$', info.mtime)
  if has_key(info, 'inode')
    call assert_match('\d', info.inode)
  endif
  bwipe!
  call delete(fname)
  call delete('Xswapinfo')

  let info = swapinfo('doesnotexist')
  call assert_equal('Cannot open file', info.error)

  call writefile(['burp'], 'Xnotaswapfile')
  let info = swapinfo('Xnotaswapfile')
  call assert_equal('Cannot read file', info.error)
  call delete('Xnotaswapfile')

  call writefile([repeat('x', 10000)], 'Xnotaswapfile')
  let info = swapinfo('Xnotaswapfile')
  call assert_equal('Not a swap file', info.error)
  call delete('Xnotaswapfile')
endfunc

func Test_swapname()
  edit Xtest1
  let expected = s:swapname()
  call assert_equal(expected, swapname('%'))

  new Xtest2
  let buf = bufnr('%')
  let expected = s:swapname()
  wincmd p
  call assert_equal(expected, swapname(buf))

  new Xtest3
  setlocal noswapfile
  call assert_equal('', swapname('%'))

  bwipe!
  call delete('Xtest1')
  call delete('Xtest2')
  call delete('Xtest3')
endfunc

func Test_swapfile_delete()
  throw 'skipped: need the "blob" feature for this test'
  autocmd! SwapExists
  function s:swap_exists()
    let v:swapchoice = s:swap_choice
    let s:swapname = v:swapname
    let s:filename = expand('<afile>')
  endfunc
  augroup test_swapfile_delete
    autocmd!
    autocmd SwapExists * call s:swap_exists()
  augroup END


  " Create a valid swapfile by editing a file.
  split XswapfileText
  call setline(1, ['one', 'two', 'three'])
  write  " file is written, not modified
  " read the swapfile as a Blob
  let swapfile_name = swapname('%')
  let swapfile_bytes = readfile(swapfile_name, 'B')

  " Close the file and recreate the swap file.
  " Now editing the file will run into the process still existing
  quit
  call writefile(swapfile_bytes, swapfile_name)
  let s:swap_choice = 'e'
  let s:swapname = ''
  split XswapfileText
  quit
  call assert_equal(fnamemodify(swapfile_name, ':t'), fnamemodify(s:swapname, ':t'))

  " Write the swapfile with a modified PID, now it will be automatically
  " deleted. Process one should never be Vim.
  let swapfile_bytes[24:27] = 0z01000000
  call writefile(swapfile_bytes, swapfile_name)
  let s:swapname = ''
  split XswapfileText
  quit
  call assert_equal('', s:swapname)

  " Now set the modified flag, the swap file will not be deleted
  let swapfile_bytes[28 + 80 + 899] = 0x55
  call writefile(swapfile_bytes, swapfile_name)
  let s:swapname = ''
  split XswapfileText
  quit
  call assert_equal(fnamemodify(swapfile_name, ':t'), fnamemodify(s:swapname, ':t'))

  call delete('XswapfileText')
  call delete(swapfile_name)
  augroup test_swapfile_delete
    autocmd!
  augroup END
  augroup! test_swapfile_delete
endfunc

func Test_swap_recover()
  autocmd! SwapExists
  augroup test_swap_recover
    autocmd!
    autocmd SwapExists * let v:swapchoice = 'r'
  augroup END


  call mkdir('Xswap')
  let $Xswap = 'foo'  " Check for issue #4369.
  set dir=Xswap//
  " Create a valid swapfile by editing a file.
  split Xswap/text
  call setline(1, ['one', 'two', 'three'])
  write  " file is written, not modified
  " read the swapfile as a Blob
  let swapfile_name = swapname('%')
  let swapfile_bytes = readfile(swapfile_name, 'B')

  " Close the file and recreate the swap file.
  quit
  call writefile(swapfile_bytes, swapfile_name)
  " Edit the file again. This triggers recovery.
  try
    split Xswap/text
  catch
    " E308 should be caught, not E305.
    call assert_exception('E308:')  " Original file may have been changed
  endtry
  " The file should be recovered.
  call assert_equal(['one', 'two', 'three'], getline(1, 3))
  quit!

  call delete('Xswap/text')
  call delete(swapfile_name)
  call delete('Xswap', 'd')
  unlet $Xswap
  set dir&
  augroup test_swap_recover
    autocmd!
  augroup END
  augroup! test_swap_recover
endfunc

func Test_swap_recover_ext()
  autocmd! SwapExists
  augroup test_swap_recover_ext
    autocmd!
    autocmd SwapExists * let v:swapchoice = 'r'
  augroup END


  " Create a valid swapfile by editing a file with a special extension.
  split Xtest.scr
  call setline(1, ['one', 'two', 'three'])
  write  " file is written, not modified
  write  " write again to make sure the swapfile is created
  " read the swapfile as a Blob
  let swapfile_name = swapname('%')
  let swapfile_bytes = readfile(swapfile_name, 'B')

  " Close and delete the file and recreate the swap file.
  quit
  call delete('Xtest.scr')
  call writefile(swapfile_bytes, swapfile_name)
  " Edit the file again. This triggers recovery.
  try
    split Xtest.scr
  catch
    " E308 should be caught, not E306.
    call assert_exception('E308:')  " Original file may have been changed
  endtry
  " The file should be recovered.
  call assert_equal(['one', 'two', 'three'], getline(1, 3))
  quit!

  call delete('Xtest.scr')
  call delete(swapfile_name)
  augroup test_swap_recover_ext
    autocmd!
  augroup END
  augroup! test_swap_recover_ext
endfunc
