" Tests for the CSS omni-completion plugin (runtime/autoload/csscomplete.vim).

" Complete at the end of the first line of the current buffer.
func s:CompleteCSS()
  call cursor(1, col('$'))
  let start = csscomplete#CompleteCSS(1, '')
  return csscomplete#CompleteCSS(0, getline(1)[start :])
endfunc

" The text after @import was passed unescaped to glob(), which uses the shell
" for backticks, so completing the file name could execute a command.
func Test_csscomplete_import_no_shell_exec()
  CheckUnix
  new
  setfiletype css
  " The trailing space makes the whole line the completion context.
  for line in ['@import "`touch Xcsspwned`" ',
        \ '@import url(`touch Xcsspwned`) ',
        \ '@import url("`touch Xcsspwned`") ',
        \ '@import url(''`touch Xcsspwned`'') ']
    call setline(1, line)
    call s:CompleteCSS()
    call assert_false(filereadable('Xcsspwned'), line)
    call delete('Xcsspwned')
  endfor
  bwipe!
endfunc

" Completing a file name after @import still works.
func Test_csscomplete_import_files()
  call mkdir('Xcssdir', 'R')
  call writefile([], 'Xcssdir/style1.css')
  call writefile([], "Xcssdir/it's.css")
  new
  setfiletype css
  call setline(1, '@import "Xcssdir/sty')
  call assert_equal(['Xcssdir/style1.css'], s:CompleteCSS())
  call setline(1, '@import "Xcssdir/it')
  call assert_equal(["Xcssdir/it's.css"], s:CompleteCSS())
  call setline(1, '@import url(Xcssdir/sty')
  call assert_equal(['url(Xcssdir/style1.css'], s:CompleteCSS())
  bwipe!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
