" Test :hardcopy

source check.vim

func Test_printoptions()
  edit test_hardcopy.vim
  syn on

  for opt in ['left:5in,right:10pt,top:8mm,bottom:2pc',
        \     'left:2in,top:30pt,right:16mm,bottom:3pc',
        \     'header:3,syntax:y,number:y,wrap:n',
        \     'header:3,syntax:n,number:y,wrap:y',
        \     'header:0,syntax:a,number:y,wrap:y',
        \     'duplex:short,collate:n,jobsplit:y,portrait:n',
        \     'duplex:long,collate:y,jobsplit:n,portrait:y',
        \     'duplex:off,collate:y,jobsplit:y,portrait:y',
        \     'paper:10x14',
        \     'paper:A3',
        \     'paper:A4',
        \     'paper:A5',
        \     'paper:B4',
        \     'paper:B5',
        \     'paper:executive',
        \     'paper:folio',
        \     'paper:ledger',
        \     'paper:legal',
        \     'paper:letter',
        \     'paper:quarto',
        \     'paper:statement',
        \     'paper:tabloid',
        \     'formfeed:y',
        \     '']
    exe 'set printoptions=' .. opt
    if has('postscript')
      1,50hardcopy > Xhardcopy_printoptions
      let lines = readfile('Xhardcopy_printoptions')
      call assert_true(len(lines) > 20, opt)
      call assert_true(lines[0] =~ 'PS-Adobe', opt)
      call delete('Xhardcopy_printoptions')
    endif
  endfor

  call assert_fails('set printoptions=paper', 'E550:')
  call assert_fails('set printoptions=shredder:on', 'E551:')
  call assert_fails('set printoptions=left:no', 'E552:')
  set printoptions&
  bwipe
endfunc

func Test_printmbfont()
  " Print a help page which contains tabs, underlines (etc) to recover more code.
  help syntax.txt
  syn on

  for opt in [':WadaMin-Regular,b:WadaMin-Bold,i:WadaMin-Italic,o:WadaMin-Bold-Italic,c:yes,a:no',
        \     '']
    exe 'set printmbfont=' .. opt
    if has('postscript')
      hardcopy > Xhardcopy_printmbfont
      let lines = readfile('Xhardcopy_printmbfont')
      call assert_true(len(lines) > 20, opt)
      call assert_true(lines[0] =~ 'PS-Adobe', opt)
      call delete('Xhardcopy_printmbfont')
    endif
  endfor
  set printmbfont&
  bwipe
endfunc

func Test_printmbcharset()
  CheckFeature postscript

  " digraph.txt has plenty of non-latin1 characters.
  help digraph.txt
  set printmbcharset=ISO10646 printencoding=utf-8
  for courier in ['yes', 'no']
    for ascii in ['yes', 'no']
      exe 'set printmbfont=r:WadaMin-Regular,b:WadaMin-Bold,i:WadaMin-Italic,o:WadaMin-BoldItalic'
      \   .. ',c:' .. courier .. ',a:' .. ascii
      hardcopy > Xhardcopy_printmbcharset
      let lines = readfile('Xhardcopy_printmbcharset')
      call assert_true(len(lines) > 20)
      call assert_true(lines[0] =~ 'PS-Adobe')
    endfor
  endfor

  set printmbcharset=does-not-exist printencoding=utf-8 printmbfont=r:WadaMin-Regular
  call assert_fails('hardcopy > Xhardcopy_printmbcharset', 'E456:')

  set printmbcharset=GB_2312-80 printencoding=utf-8 printmbfont=r:WadaMin-Regular
  call assert_fails('hardcopy > Xhardcopy_printmbcharset', 'E673:')

  set printmbcharset=ISO10646 printencoding=utf-8 printmbfont=
  call assert_fails('hardcopy > Xhardcopy_printmbcharset', 'E675:')

  call delete('Xhardcopy_printmbcharset')
  set printmbcharset& printencoding& printmbfont&
  bwipe
endfunc

func Test_printexpr()
  CheckFeature postscript

  " Not a very useful printexpr value, but enough to test
  " hardcopy with 'printexpr'.
  function PrintFile(fname)
    call writefile(['Test printexpr: ' .. v:cmdarg],
    \              'Xhardcopy_printexpr')
    call delete(a:fname)
    return 0
  endfunc
  set printexpr=PrintFile(v:fname_in)

  help help
  hardcopy dummy args
  call assert_equal(['Test printexpr: dummy args'],
  \                 readfile('Xhardcopy_printexpr'))
  call delete('Xhardcopy_printexpr')

  " Function returns 1 to test print failure.
  function PrintFails(fname)
    call delete(a:fname)
    return 1
  endfunc
  set printexpr=PrintFails(v:fname_in)
  call assert_fails('hardcopy', 'E365:')

  set printexpr&
  bwipe
endfunc

func Test_errors()
  CheckFeature postscript

  edit test_hardcopy.vim
  call assert_fails('hardcopy >', 'E324:')
  bwipe
endfunc

func Test_dark_background()
  edit test_hardcopy.vim
  syn on

  for bg in ['dark', 'light']
    exe 'set background=' .. bg

    if has('postscript')
      hardcopy > Xhardcopy_dark_background
      let lines = readfile('Xhardcopy_dark_background')
      call assert_true(len(lines) > 20)
      call assert_true(lines[0] =~ 'PS-Adobe')
      call delete('Xhardcopy_dark_background')
    endif
  endfor

  set background&
  bwipe
endfun

func Test_empty_buffer()
  CheckFeature postscript

  new
  call assert_equal("\nNo text to be printed", execute('hardcopy'))
  bwipe
endfunc

func Test_printheader_parsing()
  " Only test that this doesn't throw an error.
  set printheader=%<%f\ %h%m%r%=%-14.(%l,%c%V%)\ %P
  set printheader=%<%f%h%m%r%=%b\ 0x%B\ \ %l,%c%V\ %P
  set printheader=%<%f%=\ [%1*%M%*%n%R%H]\ %-19(%3l,%02c%03V%)%O'%02b'
  set printheader=...%r%{VarExists('b:gzflag','\ [GZ]')}%h...
  set printheader=
  set printheader&
endfunc

func Test_fname_with_spaces()
  CheckFeature postscript

  split t\ e\ s\ t.txt
  call setline(1, ['just', 'some', 'text'])
  hardcopy > %.ps
  call assert_true(filereadable('t e s t.txt.ps'))
  call delete('t e s t.txt.ps')
  bwipe!
endfunc

func Test_illegal_byte()
  CheckFeature postscript
  if &enc != 'utf-8'
    return
  endif

  new
  " conversion of 0xff will fail, this used to cause a crash
  call setline(1, "\xff")
  hardcopy >Xpstest

  bwipe!
  call delete('Xpstest')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
