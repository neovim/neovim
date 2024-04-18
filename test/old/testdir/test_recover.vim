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
  call writefile(b, '.Xfile1.swm', 'D')
  call writefile(b, '.Xfile1.swn', 'D')
  call writefile(b, '.Xfile1.swo', 'D')
  %bw!
  call feedkeys(":recover Xfile1\<CR>3\<CR>q", 'xt')
  call assert_equal(['a', 'b', 'c'], getline(1, '$'))
  " try using out-of-range number to select a swap file
  bw!
  call feedkeys(":recover Xfile1\<CR>4\<CR>q", 'xt')
  call assert_equal('Xfile1', @%)
  call assert_equal([''], getline(1, '$'))
  bw!
  call feedkeys(":recover Xfile1\<CR>0\<CR>q", 'xt')
  call assert_equal('Xfile1', @%)
  call assert_equal([''], getline(1, '$'))
  bw!
endfunc

" Test for :recover using an empty swap file
func Test_recover_empty_swap_file()
  CheckUnix
  call writefile([], '.Xfile1.swp', 'D')
  set dir=.
  let msg = execute('recover Xfile1')
  call assert_match('Unable to read block 0 from .Xfile1.swp', msg)
  call assert_equal('Xfile1', @%)
  bw!

  " make sure there are no old swap files laying around
  for f in glob('.sw?', 0, 1)
    call delete(f)
  endfor

  " :recover from an empty buffer
  call assert_fails('recover', 'E305:')
  set dir&vim
endfunc

" Test for :recover using a corrupted swap file
" Refer to the comments in the memline.c file for the swap file headers
" definition.
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

  " Not all fields are written in a system-independent manner.  Detect whether
  " the test is running on a little or big-endian system, so the correct
  " corruption values can be set.
  " The B0_MAGIC_LONG field may be 32-bit or 64-bit, depending on the system,
  " even though the value stored is only 32-bits.  Therefore, need to check
  " both the high and low 32-bits to compute these values.
  let little_endian = (b[1008:1011] == 0z33323130) || (b[1012:1015] == 0z33323130)
  let system_64bit = little_endian ? (b[1012:1015] == 0z00000000) : (b[1008:1011] == 0z00000000)

  " clear the B0_MAGIC_LONG field
  if system_64bit
    let b[1008:1015] = 0z00000000.00000000
  else
    let b[1008:1011] = 0z00000000
  endif
  call writefile(b, sn)
  let msg = execute('recover Xfile1')
  call assert_match('the file has been damaged', msg)
  call assert_equal('Xfile1', @%)
  call assert_equal([''], getline(1, '$'))
  bw!

  " reduce the page size
  let b = copy(save_b)
  let b[12:15] = 0z00010000
  call writefile(b, sn)
  let msg = execute('recover Xfile1')
  call assert_match('page size is smaller than minimum value', msg)
  call assert_equal('Xfile1', @%)
  call assert_equal([''], getline(1, '$'))
  bw!

  " clear the pointer ID
  let b = copy(save_b)
  let b[4096:4097] = 0z0000
  call writefile(b, sn)
  call assert_fails('recover Xfile1', 'E310:')
  call assert_equal('Xfile1', @%)
  call assert_equal([''], getline(1, '$'))
  bw!

  " set the number of pointers in a pointer block to zero
  let b = copy(save_b)
  let b[4098:4099] = 0z0000
  call writefile(b, sn)
  call assert_fails('recover Xfile1', 'E312:')
  call assert_equal('Xfile1', @%)
  call assert_equal(['???EMPTY BLOCK'], getline(1, '$'))
  bw!

  " set the number of pointers in a pointer block to a large value
  let b = copy(save_b)
  let b[4098:4099] = 0zFFFF
  call writefile(b, sn)
  call assert_fails('recover Xfile1', 'E1364:')
  call assert_equal('Xfile1', @%)
  bw!

  " set the block number in a pointer entry to a negative number
  let b = copy(save_b)
  if v:true  " Nvim changed this field from a long to an int64_t
    let b[4104:4111] = little_endian ? 0z00000000.00000080 : 0z80000000.00000000
  else
    let b[4104:4107] = little_endian ? 0z00000080 : 0z80000000
  endif
  call writefile(b, sn)
  call assert_fails('recover Xfile1', 'E312:')
  call assert_equal('Xfile1', @%)
  call assert_equal(['???LINES MISSING'], getline(1, '$'))
  bw!

  " clear the data block ID
  let b = copy(save_b)
  let b[8192:8193] = 0z0000
  call writefile(b, sn)
  call assert_fails('recover Xfile1', 'E312:')
  call assert_equal('Xfile1', @%)
  call assert_equal(['???BLOCK MISSING'], getline(1, '$'))
  bw!

  " set the number of lines in the data block to zero
  let b = copy(save_b)
  if system_64bit
    let b[8208:8215] = 0z00000000.00000000
  else
    let b[8208:8211] = 0z00000000
  endif
  call writefile(b, sn)
  call assert_fails('recover Xfile1', 'E312:')
  call assert_equal('Xfile1', @%)
  call assert_equal(['??? from here until ???END lines may have been inserted/deleted',
        \ '???END'], getline(1, '$'))
  bw!

  " set the number of lines in the data block to a large value
  let b = copy(save_b)
  if system_64bit
    let b[8208:8215] = 0z00FFFFFF.FFFFFF00
  else
    let b[8208:8211] = 0z00FFFF00
  endif
  call writefile(b, sn)
  call assert_fails('recover Xfile1', 'E312:')
  call assert_equal('Xfile1', @%)
  call assert_equal(['??? from here until ???END lines may have been inserted/deleted',
        \ '', '???', '??? lines may be missing',
        \ '???END'], getline(1, '$'))
  bw!

  " use an invalid text start for the lines in a data block
  let b = copy(save_b)
  if system_64bit
    let b[8216:8219] = 0z00000000
  else
    let b[8212:8215] = 0z00000000
  endif
  call writefile(b, sn)
  call assert_fails('recover Xfile1', 'E312:')
  call assert_equal('Xfile1', @%)
  call assert_equal(['???'], getline(1, '$'))
  bw!

  " use an incorrect text end (db_txt_end) for the data block
  let b = copy(save_b)
  let b[8204:8207] = little_endian ? 0z80000000 : 0z00000080
  call writefile(b, sn)
  call assert_fails('recover Xfile1', 'E312:')
  call assert_equal('Xfile1', @%)
  call assert_equal(['??? from here until ???END lines may be messed up', '',
        \ '???END'], getline(1, '$'))
  bw!

  " remove the data block
  let b = copy(save_b)
  call writefile(b[:8191], sn)
  call assert_fails('recover Xfile1', 'E312:')
  call assert_equal('Xfile1', @%)
  call assert_equal(['???MANY LINES MISSING'], getline(1, '$'))

  bw!
  call delete(sn)
endfunc

" Test for :recover using an encrypted swap file
func Test_recover_encrypted_swap_file()
  CheckFeature cryptv
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

" Test for :recover using an unreadable swap file
func Test_recover_unreadable_swap_file()
  CheckUnix
  CheckNotRoot
  new Xfile1
  let b = readblob('.Xfile1.swp')
  call writefile(b, '.Xfile1.swm', 'D')
  bw!
  call setfperm('.Xfile1.swm', '-w-------')
  call assert_fails('recover Xfile1', 'E306:')
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
  call writefile(b, '.Xfile1.swz', 'D')
  let msg = execute('recover Xfile1')
  call assert_equal(['aaa', 'bbb', 'ccc'], getline(1, '$'))
  call assert_false(&modified)
  call assert_match('Buffer contents equals file contents', msg)
  bw!
  call delete('Xfile1')
endfunc

" Test for recovering a file when editing a symbolically linked file
func Test_recover_symbolic_link()
  CheckUnix
  call writefile(['aaa', 'bbb', 'ccc'], 'Xfile1', 'D')
  silent !ln -s Xfile1 Xfile2
  edit Xfile2
  call assert_equal('.Xfile1.swp', fnamemodify(swapname(''), ':t'))
  preserve
  let b = readblob('.Xfile1.swp')
  %bw!
  call writefile([], 'Xfile1')
  call writefile(b, '.Xfile1.swp')
  silent! recover Xfile2
  call assert_equal(['aaa', 'bbb', 'ccc'], getline(1, '$'))
  call assert_true(&modified)
  update
  %bw!
  call assert_equal(['aaa', 'bbb', 'ccc'], readfile('Xfile1'))
  call delete('Xfile2')
  call delete('.Xfile1.swp')
endfunc

" Test for recovering a file when an autocmd moves the cursor to an invalid
" line. This used to result in an internal error (E315) which is fixed
" by 8.2.2966.
func Test_recover_invalid_cursor_pos()
  call writefile([], 'Xfile1', 'D')
  edit Xfile1
  preserve
  let b = readblob('.Xfile1.swp')
  bw!
  augroup Test
    au!
    au BufReadPost Xfile1 normal! 3G
  augroup END
  call writefile(range(1, 3), 'Xfile1')
  call writefile(b, '.Xfile1.swp', 'D')
  try
    recover Xfile1
  catch /E308:/
    " this test is for the :E315 internal error.
    " ignore the 'E308: Original file may have been changed' error
  endtry
  redraw!
  augroup Test
    au!
  augroup END
  augroup! Test
endfunc

" Test for recovering a buffer without a name
func Test_noname_buffer()
  new
  call setline(1, ['one', 'two'])
  preserve
  let sn = swapname('')
  let b = readblob(sn)
  bw!
  call writefile(b, sn, 'D')
  exe "recover " .. sn
  call assert_equal(['one', 'two'], getline(1, '$'))
endfunc

" vim: shiftwidth=2 sts=2 expandtab
