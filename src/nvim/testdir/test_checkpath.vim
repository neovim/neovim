" Tests for the :checkpath command

" Test for 'include' without \zs or \ze
func Test_checkpath1()
  call mkdir("Xdir1/dir2", "p")
  call writefile(['#include    "bar.a"'], 'Xdir1/dir2/foo.a')
  call writefile(['#include    "baz.a"'], 'Xdir1/dir2/bar.a')
  call writefile(['#include    "foo.a"'], 'Xdir1/dir2/baz.a')
  call writefile(['#include    <foo.a>'], 'Xbase.a')

  edit Xbase.a
  set path=Xdir1/dir2
  let res = split(execute("checkpath!"), "\n")
  call assert_equal([
	      \ '--- Included files in path ---',
	      \ 'Xdir1/dir2/foo.a',
	      \ 'Xdir1/dir2/foo.a -->',
	      \ '  Xdir1/dir2/bar.a',
	      \ '  Xdir1/dir2/bar.a -->',
	      \ '    Xdir1/dir2/baz.a',
	      \ '    Xdir1/dir2/baz.a -->',
	      \ '      "foo.a"  (Already listed)'], res)

  enew
  call delete("./Xbase.a")
  call delete("Xdir1", "rf")
  set path&
endfunc

func DotsToSlashes()
  return substitute(v:fname, '\.', '/', 'g') . '.b'
endfunc

" Test for 'include' with \zs and \ze
func Test_checkpath2()
  call mkdir("Xdir1/dir2", "p")
  call writefile(['%inc    /bar/'], 'Xdir1/dir2/foo.b')
  call writefile(['%inc    /baz/'], 'Xdir1/dir2/bar.b')
  call writefile(['%inc    /foo/'], 'Xdir1/dir2/baz.b')
  call writefile(['%inc    /foo/'], 'Xbase.b')

  let &include='^\s*%inc\s*/\zs[^/]\+\ze'
  let &includeexpr='DotsToSlashes()'

  edit Xbase.b
  set path=Xdir1/dir2
  let res = split(execute("checkpath!"), "\n")
  call assert_equal([
	      \ '--- Included files in path ---',
	      \ 'Xdir1/dir2/foo.b',
	      \ 'Xdir1/dir2/foo.b -->',
	      \ '  Xdir1/dir2/bar.b',
	      \ '  Xdir1/dir2/bar.b -->',
	      \ '    Xdir1/dir2/baz.b',
	      \ '    Xdir1/dir2/baz.b -->',
	      \ '      foo  (Already listed)'], res)

  enew
  call delete("./Xbase.b")
  call delete("Xdir1", "rf")
  set path&
  set include&
  set includeexpr&
endfunc

func StripNewlineChar()
  if v:fname =~ '\n$'
    return v:fname[:-2]
  endif
  return v:fname
endfunc

" Test for 'include' with \zs and no \ze
func Test_checkpath3()
  call mkdir("Xdir1/dir2", "p")
  call writefile(['%inc    bar.c'], 'Xdir1/dir2/foo.c')
  call writefile(['%inc    baz.c'], 'Xdir1/dir2/bar.c')
  call writefile(['%inc    foo.c'], 'Xdir1/dir2/baz.c')
  call writefile(['%inc    foo.c'], 'Xdir1/dir2/FALSE.c')
  call writefile(['%inc    FALSE.c foo.c'], 'Xbase.c')

  let &include='^\s*%inc\s*\%([[:upper:]][^[:space:]]*\s\+\)\?\zs\S\+\ze'
  let &includeexpr='StripNewlineChar()'

  edit Xbase.c
  set path=Xdir1/dir2
  let res = split(execute("checkpath!"), "\n")
  call assert_equal([
	      \ '--- Included files in path ---',
	      \ 'Xdir1/dir2/foo.c',
	      \ 'Xdir1/dir2/foo.c -->',
	      \ '  Xdir1/dir2/bar.c',
	      \ '  Xdir1/dir2/bar.c -->',
	      \ '    Xdir1/dir2/baz.c',
	      \ '    Xdir1/dir2/baz.c -->',
	      \ '      foo.c  (Already listed)'], res)

  enew
  call delete("./Xbase.c")
  call delete("Xdir1", "rf")
  set path&
  set include&
  set includeexpr&
endfunc
