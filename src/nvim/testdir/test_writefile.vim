" Tests for the writefile() function and some :write commands.

source check.vim
source term_util.vim

func Test_writefile()
  let f = tempname()
  call writefile(["over","written"], f, "b")
  call writefile(["hello","world"], f, "b")
  call writefile(["!", "good"], f, "a")
  call writefile(["morning"], f, "ab")
  call writefile(["", "vimmers"], f, "ab")
  let l = readfile(f)
  call assert_equal("hello", l[0])
  call assert_equal("world!", l[1])
  call assert_equal("good", l[2])
  call assert_equal("morning", l[3])
  call assert_equal("vimmers", l[4])
  call delete(f)

  call assert_fails('call writefile("text", "Xfile")', 'E475: Invalid argument: writefile() first argument must be a List or a Blob')
endfunc

func Test_writefile_ignore_regexp_error()
  write Xt[z-a]est.txt
  call delete('Xt[z-a]est.txt')
endfunc

func Test_writefile_fails_gently()
  call assert_fails('call writefile(["test"], "Xfile", [])', 'E730:')
  call assert_false(filereadable("Xfile"))
  call delete("Xfile")

  call assert_fails('call writefile(["test", [], [], [], "tset"], "Xfile")', 'E745:')
  call assert_false(filereadable("Xfile"))
  call delete("Xfile")

  call assert_fails('call writefile([], "Xfile", [])', 'E730:')
  call assert_false(filereadable("Xfile"))
  call delete("Xfile")

  call assert_fails('call writefile([], [])', 'E730:')
endfunc

func Test_writefile_fails_conversion()
  if !has('iconv') || has('sun')
    return
  endif
  " Without a backup file the write won't happen if there is a conversion
  " error.
  set nobackup nowritebackup backupdir=. backupskip=
  new
  let contents = ["line one", "line two"]
  call writefile(contents, 'Xfile')
  edit Xfile
  call setline(1, ["first line", "cannot convert \u010b", "third line"])
  call assert_fails('write ++enc=cp932', 'E513:')
  call assert_equal(contents, readfile('Xfile'))

  call delete('Xfile')
  bwipe!
  set backup& writebackup& backupdir&vim backupskip&vim
endfunc

func Test_writefile_fails_conversion2()
  if !has('iconv') || has('sun')
    return
  endif
  " With a backup file the write happens even if there is a conversion error,
  " but then the backup file must remain
  set nobackup writebackup backupdir=. backupskip=
  let contents = ["line one", "line two"]
  call writefile(contents, 'Xfile_conversion_err')
  edit Xfile_conversion_err
  call setline(1, ["first line", "cannot convert \u010b", "third line"])
  set fileencoding=latin1
  let output = execute('write')
  call assert_match('CONVERSION ERROR', output)
  call assert_equal(contents, readfile('Xfile_conversion_err~'))

  call delete('Xfile_conversion_err')
  call delete('Xfile_conversion_err~')
  bwipe!
  set backup& writebackup& backupdir&vim backupskip&vim
endfunc

func SetFlag(timer)
  let g:flag = 1
endfunc

func Test_write_quit_split()
  " Prevent exiting by splitting window on file write.
  augroup testgroup
    autocmd BufWritePre * split
  augroup END
  e! Xfile
  call setline(1, 'nothing')
  wq

  if has('timers')
    " timer will not run if "exiting" is still set
    let g:flag = 0
    call timer_start(1, 'SetFlag')
    sleep 50m
    call assert_equal(1, g:flag)
    unlet g:flag
  endif
  au! testgroup
  bwipe Xfile
  call delete('Xfile')
endfunc

func Test_nowrite_quit_split()
  " Prevent exiting by opening a help window.
  e! Xfile
  help
  wincmd w
  exe winnr() . 'q'

  if has('timers')
    " timer will not run if "exiting" is still set
    let g:flag = 0
    call timer_start(1, 'SetFlag')
    sleep 50m
    call assert_equal(1, g:flag)
    unlet g:flag
  endif
  bwipe Xfile
endfunc

func Test_writefile_autowrite()
  set autowrite
  new
  next Xa Xb Xc
  call setline(1, 'aaa')
  next
  call assert_equal(['aaa'], readfile('Xa'))
  call setline(1, 'bbb')
  call assert_fails('edit XX')
  call assert_false(filereadable('Xb'))

  set autowriteall
  edit XX
  call assert_equal(['bbb'], readfile('Xb'))

  bwipe!
  call delete('Xa')
  call delete('Xb')
  set noautowrite
endfunc

func Test_writefile_autowrite_nowrite()
  set autowrite
  new
  next Xa Xb Xc
  set buftype=nowrite
  call setline(1, 'aaa')
  let buf = bufnr('%')
  " buffer contents silently lost
  edit XX
  call assert_false(filereadable('Xa'))
  rewind
  call assert_equal('', getline(1))

  bwipe!
  set noautowrite
endfunc

" Test for ':w !<cmd>' to pipe lines from the current buffer to an external
" command.
func Test_write_pipe_to_cmd()
  CheckUnix
  new
  call setline(1, ['L1', 'L2', 'L3', 'L4'])
  2,3w !cat > Xfile
  call assert_equal(['L2', 'L3'], readfile('Xfile'))
  close!
  call delete('Xfile')
endfunc

" Test for :saveas
func Test_saveas()
  call assert_fails('saveas', 'E471:')
  call writefile(['L1'], 'Xfile')
  new Xfile
  new
  call setline(1, ['L1'])
  call assert_fails('saveas Xfile', 'E139:')
  close!
  enew | only
  call delete('Xfile')

  " :saveas should detect and set the file type.
  syntax on
  saveas! Xsaveas.pl
  call assert_equal('perl', &filetype)
  syntax off
  %bw!
  call delete('Xsaveas.pl')
endfunc

func Test_write_errors()
  " Test for writing partial buffer
  call writefile(['L1', 'L2', 'L3'], 'Xfile')
  new Xfile
  call assert_fails('1,2write', 'E140:')
  close!

  " Try to overwrite a directory
  if has('unix')
    call mkdir('Xdir1')
    call assert_fails('write Xdir1', 'E17:')
    call delete('Xdir1', 'd')
  endif

  " Test for :wall for a buffer with no name
  enew | only
  call setline(1, ['L1'])
  call assert_fails('wall', 'E141:')
  enew!

  " Test for writing a 'readonly' file
  new Xfile
  set readonly
  call assert_fails('write', 'E45:')
  close

  " Test for writing to a read-only file
  new Xfile
  call setfperm('Xfile', 'r--r--r--')
  call assert_fails('write', 'E505:')
  call setfperm('Xfile', 'rw-rw-rw-')
  close

  call delete('Xfile')
endfunc

func Test_writefile_sync_dev_stdout()
  if !has('unix')
    return
  endif
  if filewritable('/dev/stdout')
    " Just check that this doesn't cause an error.
    call writefile(['one'], '/dev/stdout', 's')
  else
    throw 'Skipped: /dev/stdout is not writable'
  endif
endfunc

func Test_writefile_sync_arg()
  " This doesn't check if fsync() works, only that the argument is accepted.
  call writefile(['one'], 'Xtest', 's')
  call writefile(['two'], 'Xtest', 'S')
  call delete('Xtest')
endfunc

" Tests for reading and writing files with conversion for Win32.
func Test_write_file_encoding()
  CheckMSWindows
  throw 'skipped: Nvim does not support :w ++enc=cp1251'
  let save_encoding = &encoding
  let save_fileencodings = &fileencodings
  set encoding& fileencodings&
  let text =<< trim END
    1 utf-8 text: ÐÐ»Ñ Vim version 6.2.  ÐÐ¾ÑÐ»ÐµÐ´Ð½ÐµÐµ Ð¸Ð·Ð¼ÐµÐ½ÐµÐ½Ð¸Ðµ: 1970 Jan 01
    2 cp1251 text: Äëÿ Vim version 6.2.  Ïîñëåäíåå èçìåíåíèå: 1970 Jan 01
    3 cp866 text: «ï Vim version 6.2.  ®á«¥¤­¥¥ ¨§¬¥­¥­¨¥: 1970 Jan 01
  END
  call writefile(text, 'Xfile')
  edit Xfile

  " write tests:
  " combine three values for 'encoding' with three values for 'fileencoding'
  " also write files for read tests
  call cursor(1, 1)
  set encoding=utf-8
  .w! ++enc=utf-8 Xtest
  .w ++enc=cp1251 >> Xtest
  .w ++enc=cp866 >> Xtest
  .w! ++enc=utf-8 Xutf8
  let expected =<< trim END
    1 utf-8 text: ÐÐ»Ñ Vim version 6.2.  ÐÐ¾ÑÐ»ÐµÐ´Ð½ÐµÐµ Ð¸Ð·Ð¼ÐµÐ½ÐµÐ½Ð¸Ðµ: 1970 Jan 01
    1 utf-8 text: Äëÿ Vim version 6.2.  Ïîñëåäíåå èçìåíåíèå: 1970 Jan 01
    1 utf-8 text: «ï Vim version 6.2.  ®á«¥¤­¥¥ ¨§¬¥­¥­¨¥: 1970 Jan 01
  END
  call assert_equal(expected, readfile('Xtest'))

  call cursor(2, 1)
  set encoding=cp1251
  .w! ++enc=utf-8 Xtest
  .w ++enc=cp1251 >> Xtest
  .w ++enc=cp866 >> Xtest
  .w! ++enc=cp1251 Xcp1251
  let expected =<< trim END
    2 cp1251 text: ÐÐ»Ñ Vim version 6.2.  ÐÐ¾ÑÐ»ÐµÐ´Ð½ÐµÐµ Ð¸Ð·Ð¼ÐµÐ½ÐµÐ½Ð¸Ðµ: 1970 Jan 01
    2 cp1251 text: Äëÿ Vim version 6.2.  Ïîñëåäíåå èçìåíåíèå: 1970 Jan 01
    2 cp1251 text: «ï Vim version 6.2.  ®á«¥¤­¥¥ ¨§¬¥­¥­¨¥: 1970 Jan 01
  END
  call assert_equal(expected, readfile('Xtest'))

  call cursor(3, 1)
  set encoding=cp866
  .w! ++enc=utf-8 Xtest
  .w ++enc=cp1251 >> Xtest
  .w ++enc=cp866 >> Xtest
  .w! ++enc=cp866 Xcp866
  let expected =<< trim END
    3 cp866 text: ÐÐ»Ñ Vim version 6.2.  ÐÐ¾ÑÐ»ÐµÐ´Ð½ÐµÐµ Ð¸Ð·Ð¼ÐµÐ½ÐµÐ½Ð¸Ðµ: 1970 Jan 01
    3 cp866 text: Äëÿ Vim version 6.2.  Ïîñëåäíåå èçìåíåíèå: 1970 Jan 01
    3 cp866 text: «ï Vim version 6.2.  ®á«¥¤­¥¥ ¨§¬¥­¥­¨¥: 1970 Jan 01
  END
  call assert_equal(expected, readfile('Xtest'))

  " read three 'fileencoding's with utf-8 'encoding'
  set encoding=utf-8 fencs=utf-8,cp1251
  e Xutf8
  .w! ++enc=utf-8 Xtest
  e Xcp1251
  .w ++enc=utf-8 >> Xtest
  set fencs=utf-8,cp866
  e Xcp866
  .w ++enc=utf-8 >> Xtest
  let expected =<< trim END
    1 utf-8 text: ÐÐ»Ñ Vim version 6.2.  ÐÐ¾ÑÐ»ÐµÐ´Ð½ÐµÐµ Ð¸Ð·Ð¼ÐµÐ½ÐµÐ½Ð¸Ðµ: 1970 Jan 01
    2 cp1251 text: ÐÐ»Ñ Vim version 6.2.  ÐÐ¾ÑÐ»ÐµÐ´Ð½ÐµÐµ Ð¸Ð·Ð¼ÐµÐ½ÐµÐ½Ð¸Ðµ: 1970 Jan 01
    3 cp866 text: ÐÐ»Ñ Vim version 6.2.  ÐÐ¾ÑÐ»ÐµÐ´Ð½ÐµÐµ Ð¸Ð·Ð¼ÐµÐ½ÐµÐ½Ð¸Ðµ: 1970 Jan 01
  END
  call assert_equal(expected, readfile('Xtest'))

  " read three 'fileencoding's with cp1251 'encoding'
  set encoding=utf-8 fencs=utf-8,cp1251
  e Xutf8
  .w! ++enc=cp1251 Xtest
  e Xcp1251
  .w ++enc=cp1251 >> Xtest
  set fencs=utf-8,cp866
  e Xcp866
  .w ++enc=cp1251 >> Xtest
  let expected =<< trim END
    1 utf-8 text: Äëÿ Vim version 6.2.  Ïîñëåäíåå èçìåíåíèå: 1970 Jan 01
    2 cp1251 text: Äëÿ Vim version 6.2.  Ïîñëåäíåå èçìåíåíèå: 1970 Jan 01
    3 cp866 text: Äëÿ Vim version 6.2.  Ïîñëåäíåå èçìåíåíèå: 1970 Jan 01
  END
  call assert_equal(expected, readfile('Xtest'))

  " read three 'fileencoding's with cp866 'encoding'
  set encoding=cp866 fencs=utf-8,cp1251
  e Xutf8
  .w! ++enc=cp866 Xtest
  e Xcp1251
  .w ++enc=cp866 >> Xtest
  set fencs=utf-8,cp866
  e Xcp866
  .w ++enc=cp866 >> Xtest
  let expected =<< trim END
    1 utf-8 text: «ï Vim version 6.2.  ®á«¥¤­¥¥ ¨§¬¥­¥­¨¥: 1970 Jan 01
    2 cp1251 text: «ï Vim version 6.2.  ®á«¥¤­¥¥ ¨§¬¥­¥­¨¥: 1970 Jan 01
    3 cp866 text: «ï Vim version 6.2.  ®á«¥¤­¥¥ ¨§¬¥­¥­¨¥: 1970 Jan 01
  END
  call assert_equal(expected, readfile('Xtest'))

  call delete('Xfile')
  call delete('Xtest')
  call delete('Xutf8')
  call delete('Xcp1251')
  call delete('Xcp866')
  let &encoding = save_encoding
  let &fileencodings = save_fileencodings
  %bw!
endfunc

" Test for writing and reading a file starting with a BOM.
" Byte Order Mark (BOM) character for various encodings is below:
"     UTF-8      : EF BB BF
"     UTF-16 (BE): FE FF
"     UTF-16 (LE): FF FE
"     UTF-32 (BE): 00 00 FE FF
"     UTF-32 (LE): FF FE 00 00
func Test_readwrite_file_with_bom()
  let utf8_bom = "\xEF\xBB\xBF"
  let utf16be_bom = "\xFE\xFF"
  let utf16le_bom = "\xFF\xFE"
  let utf32be_bom = "\n\n\xFE\xFF"
  let utf32le_bom = "\xFF\xFE\n\n"
  let save_fileencoding = &fileencoding
  set cpoptions+=S

  " Check that editing a latin1 file doesn't see a BOM
  call writefile(["\xFE\xFElatin-1"], 'Xtest1')
  edit Xtest1
  call assert_equal('latin1', &fileencoding)
  call assert_equal(0, &bomb)
  set fenc=latin1
  write Xfile2
  call assert_equal(["\xFE\xFElatin-1", ''], readfile('Xfile2', 'b'))
  set bomb fenc=latin1
  write Xtest3
  call assert_equal(["\xFE\xFElatin-1", ''], readfile('Xtest3', 'b'))
  set bomb&

  " Check utf-8 BOM
  %bw!
  call writefile([utf8_bom .. "utf-8"], 'Xtest1')
  edit! Xtest1
  call assert_equal('utf-8', &fileencoding)
  call assert_equal(1, &bomb)
  call assert_equal('utf-8', getline(1))
  set fenc=latin1
  write! Xfile2
  call assert_equal(['utf-8', ''], readfile('Xfile2', 'b'))
  set fenc=utf-8
  w! Xtest3
  call assert_equal([utf8_bom .. "utf-8", ''], readfile('Xtest3', 'b'))

  " Check utf-8 with an error (will fall back to latin-1)
  %bw!
  call writefile([utf8_bom .. "utf-8\x80err"], 'Xtest1')
  edit! Xtest1
  call assert_equal('latin1', &fileencoding)
  call assert_equal(0, &bomb)
  call assert_equal("\xC3\xAF\xC2\xBB\xC2\xBFutf-8\xC2\x80err", getline(1))
  set fenc=latin1
  write! Xfile2
  call assert_equal([utf8_bom .. "utf-8\x80err", ''], readfile('Xfile2', 'b'))
  set fenc=utf-8
  w! Xtest3
  call assert_equal(["\xC3\xAF\xC2\xBB\xC2\xBFutf-8\xC2\x80err", ''],
        \ readfile('Xtest3', 'b'))

  " Check ucs-2 BOM
  %bw!
  call writefile([utf16be_bom .. "\nu\nc\ns\n-\n2\n"], 'Xtest1')
  edit! Xtest1
  call assert_equal('utf-16', &fileencoding)
  call assert_equal(1, &bomb)
  call assert_equal('ucs-2', getline(1))
  set fenc=latin1
  write! Xfile2
  call assert_equal(["ucs-2", ''], readfile('Xfile2', 'b'))
  set fenc=ucs-2
  w! Xtest3
  call assert_equal([utf16be_bom .. "\nu\nc\ns\n-\n2\n", ''],
        \ readfile('Xtest3', 'b'))

  " Check ucs-2le BOM
  %bw!
  call writefile([utf16le_bom .. "u\nc\ns\n-\n2\nl\ne\n"], 'Xtest1')
  " Need to add a NUL byte after the NL byte
  call writefile(0z00, 'Xtest1', 'a')
  edit! Xtest1
  call assert_equal('utf-16le', &fileencoding)
  call assert_equal(1, &bomb)
  call assert_equal('ucs-2le', getline(1))
  set fenc=latin1
  write! Xfile2
  call assert_equal(["ucs-2le", ''], readfile('Xfile2', 'b'))
  set fenc=ucs-2le
  w! Xtest3
  call assert_equal([utf16le_bom .. "u\nc\ns\n-\n2\nl\ne\n", "\n"],
        \ readfile('Xtest3', 'b'))

  " Check ucs-4 BOM
  %bw!
  call writefile([utf32be_bom .. "\n\n\nu\n\n\nc\n\n\ns\n\n\n-\n\n\n4\n\n\n"], 'Xtest1')
  edit! Xtest1
  call assert_equal('ucs-4', &fileencoding)
  call assert_equal(1, &bomb)
  call assert_equal('ucs-4', getline(1))
  set fenc=latin1
  write! Xfile2
  call assert_equal(["ucs-4", ''], readfile('Xfile2', 'b'))
  set fenc=ucs-4
  w! Xtest3
  call assert_equal([utf32be_bom .. "\n\n\nu\n\n\nc\n\n\ns\n\n\n-\n\n\n4\n\n\n", ''], readfile('Xtest3', 'b'))

  " Check ucs-4le BOM
  %bw!
  call writefile([utf32le_bom .. "u\n\n\nc\n\n\ns\n\n\n-\n\n\n4\n\n\nl\n\n\ne\n\n\n"], 'Xtest1')
  " Need to add three NUL bytes after the NL byte
  call writefile(0z000000, 'Xtest1', 'a')
  edit! Xtest1
  call assert_equal('ucs-4le', &fileencoding)
  call assert_equal(1, &bomb)
  call assert_equal('ucs-4le', getline(1))
  set fenc=latin1
  write! Xfile2
  call assert_equal(["ucs-4le", ''], readfile('Xfile2', 'b'))
  set fenc=ucs-4le
  w! Xtest3
  call assert_equal([utf32le_bom .. "u\n\n\nc\n\n\ns\n\n\n-\n\n\n4\n\n\nl\n\n\ne\n\n\n", "\n\n\n"], readfile('Xtest3', 'b'))

  set cpoptions-=S
  let &fileencoding = save_fileencoding
  call delete('Xtest1')
  call delete('Xfile2')
  call delete('Xtest3')
  %bw!
endfunc

func Test_read_write_bin()
  " write file missing EOL
  call writefile(['noeol'], "XNoEolSetEol", 'bS')
  call assert_equal(0z6E6F656F6C, readfile('XNoEolSetEol', 'B'))

  " when file is read 'eol' is off
  set nofixeol
  e! ++ff=unix XNoEolSetEol
  call assert_equal(0, &eol)

  " writing with 'eol' set adds the newline
  setlocal eol
  w
  call assert_equal(0z6E6F656F6C0A, readfile('XNoEolSetEol', 'B'))

  call delete('XNoEolSetEol')
  set ff&
  bwipe! XNoEolSetEol
endfunc

" Check that buffer is written before triggering QuitPre
func Test_wq_quitpre_autocommand()
  edit Xsomefile
  call setline(1, 'hello')
  split
  let g:seq = []
  augroup Testing
    au QuitPre * call add(g:seq, 'QuitPre - ' .. (&modified ? 'modified' : 'not modified'))
    au BufWritePost * call add(g:seq, 'written')
  augroup END
  wq
  call assert_equal(['written', 'QuitPre - not modified'], g:seq)

  augroup Testing
    au!
  augroup END
  bwipe!
  unlet g:seq
  call delete('Xsomefile')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
