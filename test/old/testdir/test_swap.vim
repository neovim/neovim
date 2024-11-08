" Tests for the swap feature

source check.vim
source shared.vim
source term_util.vim

func s:swapname()
  return trim(execute('swapname'))
endfunc

" Tests for 'directory' option.
func Test_swap_directory()
  CheckUnix

  let content = ['start of testfile',
	      \ 'line 2 Abcdefghij',
	      \ 'line 3 Abcdefghij',
	      \ 'end of testfile']
  call writefile(content, 'Xtest1', 'D')

  "  '.', swap file in the same directory as file
  set dir=.,~

  " Verify that the swap file doesn't exist in the current directory
  call assert_equal([], glob(".Xtest1*.swp", 1, 1, 1))
  edit Xtest1
  let swfname = s:swapname()
  call assert_equal([swfname], glob(swfname, 1, 1, 1))

  " './dir', swap file in a directory relative to the file
  set dir=./Xtest2,.,~

  call mkdir("Xtest2", 'R')
  edit Xtest1
  call assert_equal([], glob(swfname, 1, 1, 1))
  let swfname = "Xtest2/Xtest1.swp"
  call assert_equal(swfname, s:swapname())
  call assert_equal([swfname], glob("Xtest2/*", 1, 1, 1))

  " 'dir', swap file in directory relative to the current dir
  set dir=Xtest.je,~

  call mkdir("Xtest.je", 'R')
  call writefile(content, 'Xtest2/Xtest3')
  edit Xtest2/Xtest3
  call assert_equal(["Xtest2/Xtest3"], glob("Xtest2/*", 1, 1, 1))
  let swfname = "Xtest.je/Xtest3.swp"
  call assert_equal(swfname, s:swapname())
  call assert_equal([swfname], glob("Xtest.je/*", 1, 1, 1))

  set dir&
endfunc

func Test_swap_group()
  CheckUnix

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

  " Check the tail appears in the list from swapfilelist().  The path depends
  " on the system.
  let tail = fnamemodify(fname, ":t")->fnameescape()
  let nr = 0
  for name in swapfilelist()
    if name =~ tail .. '$'
      let nr += 1
    endif
  endfor
  call assert_equal(1, nr, 'not found in ' .. string(swapfilelist()))

  let info = fname->swapinfo()
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

  call writefile(['burp'], 'Xnotaswapfile', 'D')
  let info = swapinfo('Xnotaswapfile')
  call assert_equal('Cannot read file', info.error)
  call delete('Xnotaswapfile')

  call writefile([repeat('x', 10000)], 'Xnotaswapfile')
  let info = swapinfo('Xnotaswapfile')
  call assert_equal('Not a swap file', info.error)
endfunc

func Test_swapname()
  edit Xtest1
  let expected = s:swapname()
  call assert_equal(expected, swapname('%'))

  new Xtest2
  let buf = bufnr('%')
  let expected = s:swapname()
  wincmd p
  call assert_equal(expected, buf->swapname())

  new Xtest3
  setlocal noswapfile
  call assert_equal('', swapname('%'))

  bwipe!
  call delete('Xtest1')
  call delete('Xtest2')
  call delete('Xtest3')
endfunc

func Test_swapfile_delete()
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
  call writefile(swapfile_bytes, swapfile_name, 'D')
  let s:swap_choice = 'e'
  let s:swapname = ''
  split XswapfileText
  quit
  call assert_equal(fnamemodify(swapfile_name, ':t'), fnamemodify(s:swapname, ':t'))

  " This test won't work as root because root can successfully run kill(1, 0)
  if !IsRoot()
    " Write the swapfile with a modified PID, now it will be automatically
    " deleted. Process 0x3fffffff most likely does not exist.
    let swapfile_bytes[24:27] = 0zffffff3f
    call writefile(swapfile_bytes, swapfile_name)
    let s:swapname = ''
    split XswapfileText
    quit
    call assert_equal('', s:swapname)
  endif

  " Now set the modified flag, the swap file will not be deleted
  let swapfile_bytes[28 + 80 + 899] = 0x55
  call writefile(swapfile_bytes, swapfile_name)
  let s:swapname = ''
  split XswapfileText
  quit
  call assert_equal(fnamemodify(swapfile_name, ':t'), fnamemodify(s:swapname, ':t'))

  call delete('XswapfileText')
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

  call mkdir('Xswap', 'R')
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
  call writefile(swapfile_bytes, swapfile_name, 'D')
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
  call writefile(swapfile_bytes, swapfile_name, 'D')
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
  augroup test_swap_recover_ext
    autocmd!
  augroup END
  augroup! test_swap_recover_ext
endfunc

" Test for closing a split window automatically when a swap file is detected
" and 'Q' is selected in the confirmation prompt.
func Test_swap_split_win()
  autocmd! SwapExists
  augroup test_swap_splitwin
    autocmd!
    autocmd SwapExists * let v:swapchoice = 'q'
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
  call writefile(swapfile_bytes, swapfile_name, 'D')
  " Split edit the file again. This should fail to open the window
  try
    split Xtest.scr
  catch
    " E308 should be caught, not E306.
    call assert_exception('E308:')  " Original file may have been changed
  endtry
  call assert_equal(1, winnr('$'))

  call delete('Xtest.scr')

  augroup test_swap_splitwin
      autocmd!
  augroup END
  augroup! test_swap_splitwin
endfunc

" Test for selecting 'q' in the attention prompt
func Test_swap_prompt_splitwin()
  CheckRunVimInTerminal

  call writefile(['foo bar'], 'Xfile1', 'D')
  edit Xfile1
  preserve  " should help to make sure the swap file exists

  let buf = RunVimInTerminal('', {'rows': 20})
  call term_sendkeys(buf, ":set nomore\n")
  call term_sendkeys(buf, ":set noruler\n")

  call term_sendkeys(buf, ":split Xfile1\n")
  call TermWait(buf)
  call WaitForAssert({-> assert_match('^\[O\]pen Read-Only, (E)dit anyway, (R)ecover, (Q)uit, (A)bort: $', term_getline(buf, 20))})
  call term_sendkeys(buf, "q")
  call TermWait(buf)
  call term_sendkeys(buf, ":\<CR>")
  call WaitForAssert({-> assert_match('^:$', term_getline(buf, 20))})
  call term_sendkeys(buf, ":echomsg winnr('$')\<CR>")
  call TermWait(buf)
  call WaitForAssert({-> assert_match('^1$', term_getline(buf, 20))})
  call StopVimInTerminal(buf)

  " This caused Vim to crash when typing "q" at the swap file prompt.
  let buf = RunVimInTerminal('-c "au bufadd * let foo_w = wincol()"', {'rows': 18})
  call term_sendkeys(buf, ":e Xfile1\<CR>")
  call WaitForAssert({-> assert_match('More', term_getline(buf, 18))})
  call term_sendkeys(buf, " ")
  call WaitForAssert({-> assert_match('^\[O\]pen Read-Only, (E)dit anyway, (R)ecover, (Q)uit, (A)bort:', term_getline(buf, 18))})
  call term_sendkeys(buf, "q")
  call TermWait(buf)
  " check that Vim is still running
  call term_sendkeys(buf, ":echo 'hello'\<CR>")
  call WaitForAssert({-> assert_match('^hello', term_getline(buf, 18))})
  call term_sendkeys(buf, ":%bwipe!\<CR>")
  call StopVimInTerminal(buf)

  %bwipe!
endfunc

func Test_swap_symlink()
  CheckUnix

  call writefile(['text'], 'Xtestfile', 'D')
  silent !ln -s -f Xtestfile Xtestlink

  set dir=.

  " Test that swap file uses the name of the file when editing through a
  " symbolic link (so that editing the file twice is detected)
  edit Xtestlink
  call assert_match('Xtestfile\.swp$', s:swapname())
  bwipe!

  call mkdir('Xswapdir', 'R')
  exe 'set dir=' . getcwd() . '/Xswapdir//'

  " Check that this also works when 'directory' ends with '//'
  edit Xtestlink
  call assert_match('Xswapdir[/\\]%.*testdir%Xtestfile\.swp$', s:swapname())
  bwipe!

  set dir&
  call delete('Xtestlink')
endfunc

func s:get_unused_pid(base)
  if has('job')
    " Execute 'echo' as a temporary job, and return its pid as an unused pid.
    if has('win32')
      let cmd = 'cmd /D /c echo'
    else
      let cmd = 'echo'
    endif
    let j = job_start(cmd)
    while job_status(j) ==# 'run'
      sleep 10m
    endwhile
    if job_status(j) ==# 'dead'
      return job_info(j).process
    endif
  elseif has('nvim')
    let j = jobstart('echo')
    let pid = jobpid(j)
    if jobwait([j])[0] >= 0
      return pid
    endif
  endif
  " Must add four for MS-Windows to see it as a different one.
  return a:base + 4
endfunc

func s:blob_to_pid(b)
  return a:b[3] * 16777216 + a:b[2] * 65536 + a:b[1] * 256 + a:b[0]
endfunc

func s:pid_to_blob(i)
  let b = 0z
  let b[0] = and(a:i, 0xff)
  let b[1] = and(a:i / 256, 0xff)
  let b[2] = and(a:i / 65536, 0xff)
  let b[3] = and(a:i / 16777216, 0xff)
  return b
endfunc

func Test_swap_auto_delete()
  " Create a valid swapfile by editing a file with a special extension.
  split Xtest.scr
  call setline(1, ['one', 'two', 'three'])
  write  " file is written, not modified
  write  " write again to make sure the swapfile is created
  " read the swapfile as a Blob
  let swapfile_name = swapname('%')
  let swapfile_bytes = readfile(swapfile_name, 'B')

  " Forget about the file, recreate the swap file, then edit it again.  The
  " swap file should be automatically deleted.
  bwipe!
  " Change the process ID to avoid the "still running" warning.
  let swapfile_bytes[24:27] = s:pid_to_blob(s:get_unused_pid(
        \ s:blob_to_pid(swapfile_bytes[24:27])))
  call writefile(swapfile_bytes, swapfile_name, 'D')
  edit Xtest.scr
  " will end up using the same swap file after deleting the existing one
  call assert_equal(swapfile_name, swapname('%'))
  bwipe!

  " create the swap file again, but change the host name so that it won't be
  " deleted
  autocmd! SwapExists
  augroup test_swap_recover_ext
    autocmd!
    autocmd SwapExists * let v:swapchoice = 'e'
  augroup END

  " change the host name
  let swapfile_bytes[28 + 40] = swapfile_bytes[28 + 40] + 2
  call writefile(swapfile_bytes, swapfile_name)
  edit Xtest.scr
  call assert_equal(1, filereadable(swapfile_name))
  " will use another same swap file name
  call assert_notequal(swapfile_name, swapname('%'))
  bwipe!

  call delete('Xtest.scr')
  augroup test_swap_recover_ext
    autocmd!
  augroup END
  augroup! test_swap_recover_ext
endfunc

" Test for renaming a buffer when the swap file is deleted out-of-band
func Test_missing_swap_file()
  CheckUnix
  new Xfile2
  call delete(swapname(''))
  call assert_fails('file Xfile3', 'E301:')
  call assert_equal('Xfile3', bufname())
  call assert_true(bufexists('Xfile2'))
  call assert_true(bufexists('Xfile3'))
  %bw!
endfunc

" Test for :preserve command
func Test_preserve()
  new Xfile4
  setlocal noswapfile
  call assert_fails('preserve', 'E313:')
  bw!
endfunc

" Test for the v:swapchoice variable
func Test_swapchoice()
  call writefile(['aaa', 'bbb'], 'Xfile5', 'D')
  edit Xfile5
  preserve
  let swapfname = swapname('')
  let b = readblob(swapfname)
  bw!
  call writefile(b, swapfname, 'D')

  autocmd! SwapExists

  " Test for v:swapchoice = 'o' (readonly)
  augroup test_swapchoice
    autocmd!
    autocmd SwapExists * let v:swapchoice = 'o'
  augroup END
  edit Xfile5
  call assert_true(&readonly)
  call assert_equal(['aaa', 'bbb'], getline(1, '$'))
  %bw!
  call assert_true(filereadable(swapfname))

  " Test for v:swapchoice = 'a' (abort)
  augroup test_swapchoice
    autocmd!
    autocmd SwapExists * let v:swapchoice = 'a'
  augroup END
  try
    edit Xfile5
  catch /^Vim:Interrupt$/
  endtry
  call assert_equal('', @%)
  call assert_true(bufexists('Xfile5'))
  %bw!
  call assert_true(filereadable(swapfname))

  " Test for v:swapchoice = 'd' (delete)
  augroup test_swapchoice
    autocmd!
    autocmd SwapExists * let v:swapchoice = 'd'
  augroup END
  edit Xfile5
  call assert_equal('Xfile5', @%)
  %bw!
  call assert_false(filereadable(swapfname))

  call delete(swapfname)
  augroup test_swapchoice
    autocmd!
  augroup END
  augroup! test_swapchoice
endfunc

func Test_no_swap_file()
  call assert_equal("\nNo swap file", execute('swapname'))
endfunc

" vim: shiftwidth=2 sts=2 expandtab
