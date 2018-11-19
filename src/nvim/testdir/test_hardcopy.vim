" Test :hardcopy

func Test_printoptions_parsing()
  " Only test that this doesn't throw an error.
  set printoptions=left:5in,right:10pt,top:8mm,bottom:2pc
  set printoptions=left:2in,top:30pt,right:16mm,bottom:3pc
  set printoptions=header:3,syntax:y,number:7,wrap:n
  set printoptions=duplex:short,collate:n,jobsplit:y,portrait:n
  set printoptions=paper:10x14
  set printoptions=paper:A3
  set printoptions=paper:A4
  set printoptions=paper:A5
  set printoptions=paper:B4
  set printoptions=paper:B5
  set printoptions=paper:executive
  set printoptions=paper:folio
  set printoptions=paper:ledger
  set printoptions=paper:legal
  set printoptions=paper:letter
  set printoptions=paper:quarto
  set printoptions=paper:statement
  set printoptions=paper:tabloid
  set printoptions=formfeed:y
  set printoptions=
  set printoptions&

  call assert_fails('set printoptions=paper', 'E550:')
  call assert_fails('set printoptions=shredder:on', 'E551:')
  call assert_fails('set printoptions=left:no', 'E552:')
endfunc

func Test_printmbfont_parsing()
  " Only test that this doesn't throw an error.
  set printmbfont=r:WadaMin-Regular,b:WadaMin-Bold,i:WadaMin-Italic,o:WadaMin-Bold-Italic,c:yes,a:no
  set printmbfont=
  set printmbfont&
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

" Test that :hardcopy produces a non-empty file.
" We don't check much of the contents.
func Test_with_syntax()
  if has('postscript')
    edit test_hardcopy.vim
    set printoptions=syntax:y
    syn on
    hardcopy > Xhardcopy
    let lines = readfile('Xhardcopy')
    call assert_true(len(lines) > 20)
    call assert_true(lines[0] =~ 'PS-Adobe')
    call delete('Xhardcopy')
    set printoptions&
  endif
endfunc

func Test_fname_with_spaces()
  if !has('postscript')
    return
  endif
  split t\ e\ s\ t.txt
  call setline(1, ['just', 'some', 'text'])
  hardcopy > %.ps
  call assert_true(filereadable('t e s t.txt.ps'))
  call delete('t e s t.txt.ps')
  bwipe!
endfunc

func Test_illegal_byte()
  if !has('postscript') || &enc != 'utf-8'
    return
  endif
  new
  " conversion of 0xff will fail, this used to cause a crash
  call setline(1, "\xff")
  hardcopy >Xpstest

  bwipe!
  call delete('Xpstest')
endfunc

