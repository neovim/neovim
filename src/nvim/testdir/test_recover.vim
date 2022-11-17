" Test :recover

source check.vim

func Test_recover_root_dir()
  " This used to access invalid memory.
  split Xtest
  set dir=/
  call assert_fails('recover', 'E305:')
  close!

  if has('win32')
    " can write in / directory on MS-Windows
    let &directory = 'F:\\'
  elseif filewritable('/') == 2
    set dir=/notexist/
  endif
  call assert_fails('split Xtest', 'E303:')

  " No error with empty 'directory' setting.
  set directory=
  split XtestOK
  close!

  set dir&
endfunc

" Make a copy of the current swap file to "Xswap".
" Return the name of the swap file.
func CopySwapfile()
  preserve
  " get the name of the swap file
  let swname = split(execute("swapname"))[0]
  let swname = substitute(swname, '[[:blank:][:cntrl:]]*\(.\{-}\)[[:blank:][:cntrl:]]*$', '\1', '')
  " make a copy of the swap file in Xswap
  set binary
  exe 'sp ' . swname
  w! Xswap
  set nobinary
  return swname
endfunc

" Inserts 10000 lines with text to fill the swap file with two levels of pointer
" blocks.  Then recovers from the swap file and checks all text is restored.
"
" We need about 10000 lines of 100 characters to get two levels of pointer
" blocks.
func Test_swap_file()
  set directory=.
  set fileformat=unix undolevels=-1
  edit! Xtest
  let text = "\tabcdefghijklmnoparstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnoparstuvwxyz0123456789"
  let i = 1
  let linecount = 10000
  while i <= linecount
    call append(i - 1, i . text)
    let i += 1
  endwhile
  $delete

  let swname = CopySwapfile()

  new
  only!
  bwipe! Xtest
  call rename('Xswap', swname)
  recover Xtest
  call delete(swname)
  let linedollar = line('$')
  call assert_equal(linecount, linedollar)
  if linedollar < linecount
    let linecount = linedollar
  endif
  let i = 1
  while i <= linecount
    call assert_equal(i . text, getline(i))
    let i += 1
  endwhile

  set undolevels&
  enew! | only
endfunc

func Test_nocatch_process_still_running()
  let g:skipped_reason = 'test_override() is N/A'
  return
  " sysinfo.uptime probably only works on Linux
  if !has('linux')
    let g:skipped_reason = 'only works on Linux'
    return
  endif
  " the GUI dialog can't be handled
  if has('gui_running')
    let g:skipped_reason = 'only works in the terminal'
    return
  endif

  " don't intercept existing swap file here
  au! SwapExists

  " Edit a file and grab its swapfile.
  edit Xswaptest
  call setline(1, ['a', 'b', 'c'])
  let swname = CopySwapfile()

  " Forget we edited this file
  new
  only!
  bwipe! Xswaptest

  call rename('Xswap', swname)
  call feedkeys('e', 'tL')
  redir => editOutput
  edit Xswaptest
  redir END
  call assert_match('E325: ATTENTION', editOutput)
  call assert_match('file name: .*Xswaptest', editOutput)
  call assert_match('process ID: \d* (STILL RUNNING)', editOutput)

  " Forget we edited this file
  new
  only!
  bwipe! Xswaptest

  " pretend we rebooted
  call test_override("uptime", 0)
  sleep 1

  call rename('Xswap', swname)
  call feedkeys('e', 'tL')
  redir => editOutput
  edit Xswaptest
  redir END
  call assert_match('E325: ATTENTION', editOutput)
  call assert_notmatch('(STILL RUNNING)', editOutput)

  call test_override("ALL", 0)
  call delete(swname)
endfunc

" Test for :recover with multiple swap files
func Test_recover_multiple_swap_files()
  CheckUnix
  new Xfile1
  call setline(1, ['a', 'b', 'c'])
  preserve
  let b = readblob(swapname(''))
  call writefile(b, '.Xfile1.swm')
  call writefile(b, '.Xfile1.swn')
  call writefile(b, '.Xfile1.swo')
  %bw!
  call feedkeys(":recover Xfile1\<CR>3\<CR>q", 'xt')
  call assert_equal(['a', 'b', 'c'], getline(1, '$'))

  call delete('.Xfile1.swm')
  call delete('.Xfile1.swn')
  call delete('.Xfile1.swo')
endfunc

" Test for :recover using an empty swap file
func Test_recover_empty_swap_file()
  CheckUnix
  call writefile([], '.Xfile1.swp')
  let msg = execute('recover Xfile1')
  call assert_match('Unable to read block 0 from .Xfile1.swp', msg)
  call assert_equal('Xfile1', @%)
  bw!
  " :recover from an empty buffer
  call assert_fails('recover', 'E305:')
  call delete('.Xfile1.swp')
endfunc

" Test for :recover using a corrupted swap file
func Test_recover_corrupted_swap_file()
  CheckUnix

  " recover using a partial swap file
  call writefile(0z1234, '.Xfile1.swp')
  call assert_fails('recover Xfile1', 'E295:')
  bw!

  " recover using invalid content in the swap file
  call writefile([repeat('1', 2*1024)], '.Xfile1.swp')
  call assert_fails('recover Xfile1', 'E307:')
  call delete('.Xfile1.swp')

  " :recover using a swap file with a corrupted header
  edit Xfile1
  preserve
  let sn = swapname('')
  let b = readblob(sn)
  let save_b = copy(b)
  bw!
  " Run these tests only on little-endian systems. These tests fail on a
  " big-endian system (IBM S390x system).
  if b[1008:1011] == 0z33323130
        \ && b[4096:4097] == 0z7470
        \ && b[8192:8193] == 0z6164

    " clear the B0_MAGIC_LONG field
    let b[1008:1011] = 0z00000000
    call writefile(b, sn)
    let msg = execute('recover Xfile1')
    call assert_match('the file has been damaged', msg)
    bw!

    " clear the pointer ID
    let b = copy(save_b)
    let b[4096:4097] = 0z0000
    call writefile(b, sn)
    call assert_fails('recover Xfile1', 'E310:')
    bw!

    " clear the data block ID
    let b = copy(save_b)
    let b[8192:8193] = 0z0000
    call writefile(b, sn)
    call assert_fails('recover Xfile1', 'E312:')
    bw!

    " remove the data block
    let b = copy(save_b)
    call writefile(b[:8191], sn)
    call assert_fails('recover Xfile1', 'E312:')
  endif

  bw!
  call delete(sn)
endfunc

" Test for :recover using an encrypted swap file
func Test_recover_encrypted_swap_file()
  CheckUnix

  " Recover an encrypted file from the swap file without the original file
  new Xfile1
  call feedkeys(":X\<CR>vim\<CR>vim\<CR>", 'xt')
  call setline(1, ['aaa', 'bbb', 'ccc'])
  preserve
  let b = readblob('.Xfile1.swp')
  call writefile(b, '.Xfile1.swm')
  bw!
  call feedkeys(":recover Xfile1\<CR>vim\<CR>\<CR>", 'xt')
  call assert_equal(['aaa', 'bbb', 'ccc'], getline(1, '$'))
  bw!
  call delete('.Xfile1.swm')

  " Recover an encrypted file from the swap file with the original file
  new Xfile1
  call feedkeys(":X\<CR>vim\<CR>vim\<CR>", 'xt')
  call setline(1, ['aaa', 'bbb', 'ccc'])
  update
  call setline(1, ['111', '222', '333'])
  preserve
  let b = readblob('.Xfile1.swp')
  call writefile(b, '.Xfile1.swm')
  bw!
  call feedkeys(":recover Xfile1\<CR>vim\<CR>\<CR>", 'xt')
  call assert_equal(['111', '222', '333'], getline(1, '$'))
  call assert_true(&modified)
  bw!
  call delete('.Xfile1.swm')
  call delete('Xfile1')
endfunc

" Test for :recover using a unreadable swap file
func Test_recover_unreadble_swap_file()
  CheckUnix
  CheckNotRoot
  new Xfile1
  let b = readblob('.Xfile1.swp')
  call writefile(b, '.Xfile1.swm')
  bw!
  call setfperm('.Xfile1.swm', '-w-------')
  call assert_fails('recover Xfile1', 'E306:')
  call delete('.Xfile1.swm')
endfunc

" Test for using :recover when the original file and the swap file have the
" same contents.
func Test_recover_unmodified_file()
  CheckUnix
  call writefile(['aaa', 'bbb', 'ccc'], 'Xfile1')
  edit Xfile1
  preserve
  let b = readblob('.Xfile1.swp')
  %bw!
  call writefile(b, '.Xfile1.swz')
  let msg = execute('recover Xfile1')
  call assert_equal(['aaa', 'bbb', 'ccc'], getline(1, '$'))
  call assert_false(&modified)
  call assert_match('Buffer contents equals file contents', msg)
  bw!
  call delete('Xfile1')
  call delete('.Xfile1.swz')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
