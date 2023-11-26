" Tests for 'makeencoding'.

source shared.vim
source check.vim

CheckFeature quickfix
let s:python = PythonProg()
if s:python == ''
  throw 'Skipped: python program missing'
endif

let s:script = 'test_makeencoding.py'

if has('iconv')
  let s:message_tbl = {
      \ 'utf-8': 'ÀÈÌÒÙ こんにちは 你好',
      \ 'latin1': 'ÀÈÌÒÙ',
      \ 'cp932': 'こんにちは',
      \ 'cp936': '你好',
      \}
else
  let s:message_tbl = {
      \ 'utf-8': 'ÀÈÌÒÙ こんにちは 你好',
      \ 'latin1': 'ÀÈÌÒÙ',
      \}
endif


" Tests for :cgetfile and :lgetfile.
func Test_getfile()
  set errorfile=Xerror.txt
  set errorformat=%f(%l)\ :\ %m

  " :cgetfile
  for enc in keys(s:message_tbl)
    let &makeencoding = enc
    exec "silent !" . s:python . " " . s:script . " " . enc . " > " . &errorfile
    cgetfile
    copen
    call assert_equal("Xfoobar.c|10| " . s:message_tbl[enc] . " (" . enc . ")",
          \ getline('.'))
    cclose
  endfor

  " :lgetfile
  for enc in keys(s:message_tbl)
    let &makeencoding = enc
    exec "silent !" . s:python . " " . s:script . " " . enc . " > " . &errorfile
    lgetfile
    lopen
    call assert_equal("Xfoobar.c|10| " . s:message_tbl[enc] . " (" . enc . ")",
          \ getline('.'))
    lclose
  endfor

  call delete(&errorfile)
endfunc


" Tests for :grep and :lgrep.
func Test_grep()
  let &grepprg = s:python
  set grepformat=%f(%l)\ :\ %m

  " :grep
  for enc in keys(s:message_tbl)
    let &makeencoding = enc
    exec "silent grep! " . s:script . " " . enc
    copen
    call assert_equal("Xfoobar.c|10| " . s:message_tbl[enc] . " (" . enc . ")",
          \ getline('.'))
    cclose
  endfor

  " :lgrep
  for enc in keys(s:message_tbl)
    let &makeencoding = enc
    exec "silent lgrep! " . s:script . " " . enc
    lopen
    call assert_equal("Xfoobar.c|10| " . s:message_tbl[enc] . " (" . enc . ")",
          \ getline('.'))
    lclose
  endfor
endfunc


" Tests for :make and :lmake.
func Test_make()
  let &makeprg = s:python
  set errorformat=%f(%l)\ :\ %m

  " :make
  for enc in keys(s:message_tbl)
    let &makeencoding = enc
    exec "silent make! " . s:script . " " . enc
    copen
    call assert_equal("Xfoobar.c|10| " . s:message_tbl[enc] . " (" . enc . ")",
          \ getline('.'))
    cclose
  endfor

  " :lmake
  for enc in keys(s:message_tbl)
    let &makeencoding = enc
    exec "silent lmake! " . s:script . " " . enc
    lopen
    call assert_equal("Xfoobar.c|10| " . s:message_tbl[enc] . " (" . enc . ")",
          \ getline('.'))
    lclose
  endfor
endfunc

" Test for an error file with a long line that needs an encoding conversion
func Test_longline_conversion()
  new
  call setline(1, ['Xfile:10:' .. repeat("\xe0", 2000)])
  write ++enc=latin1 Xerr.out
  bw!
  set errorformat&
  set makeencoding=latin1
  cfile Xerr.out
  call assert_equal(repeat("\u00e0", 2000), getqflist()[0].text)
  call delete('Xerr.out')
  set makeencoding&
endfunc

" vim: shiftwidth=2 sts=2 expandtab
