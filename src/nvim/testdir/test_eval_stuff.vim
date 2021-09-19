" Tests for various eval things.

function s:foo() abort
  try
    return [] == 0
  catch
    return 1
  endtry
endfunction

func Test_catch_return_with_error()
  call assert_equal(1, s:foo())
endfunc

func Test_E963()
  " These commands used to cause an internal error prior to vim 8.1.0563
  let v_e = v:errors
  let v_o = v:oldfiles
  call assert_fails("let v:errors=''", 'E963:')
  call assert_equal(v_e, v:errors)
  call assert_fails("let v:oldfiles=''", 'E963:')
  call assert_equal(v_o, v:oldfiles)
endfunc

func Test_for_invalid()
  call assert_fails("for x in 99", 'E714:')
  call assert_fails("for x in function('winnr')", 'E714:')
  call assert_fails("for x in {'a': 9}", 'E714:')

  if 0
    /1/5/2/s/\n
  endif
  redraw
endfunc

func Test_mkdir_p()
  call mkdir('Xmkdir/nested', 'p')
  call assert_true(isdirectory('Xmkdir/nested'))
  try
    " Trying to make existing directories doesn't error
    call mkdir('Xmkdir', 'p')
    call mkdir('Xmkdir/nested', 'p')
  catch /E739:/
    call assert_report('mkdir(..., "p") failed for an existing directory')
  endtry
  " 'p' doesn't suppress real errors
  call writefile([], 'Xfile')
  call assert_fails('call mkdir("Xfile", "p")', 'E739')
  call delete('Xfile')
  call delete('Xmkdir', 'rf')
endfunc

func Test_line_continuation()
  let array = [5,
	"\ ignore this
	\ 6,
	"\ more to ignore
	"\ more moreto ignore
	\ ]
	"\ and some more
  call assert_equal([5, 6], array)
endfunc

func Test_string_concatenation()
  call assert_equal('ab', 'a'.'b')
  call assert_equal('ab', 'a' .'b')
  call assert_equal('ab', 'a'. 'b')
  call assert_equal('ab', 'a' . 'b')

  call assert_equal('ab', 'a'..'b')
  call assert_equal('ab', 'a' ..'b')
  call assert_equal('ab', 'a'.. 'b')
  call assert_equal('ab', 'a' .. 'b')

  let a = 'a'
  let b = 'b'
  let a .= b
  call assert_equal('ab', a)

  let a = 'a'
  let a.=b
  call assert_equal('ab', a)

  let a = 'a'
  let a ..= b
  call assert_equal('ab', a)

  let a = 'a'
  let a..=b
  call assert_equal('ab', a)
endfunc

func Test_nocatch_restore_silent_emsg()
  silent! try
    throw 1
  catch
  endtry
  echoerr 'wrong'
  let c1 = nr2char(screenchar(&lines, 1))
  let c2 = nr2char(screenchar(&lines, 2))
  let c3 = nr2char(screenchar(&lines, 3))
  let c4 = nr2char(screenchar(&lines, 4))
  let c5 = nr2char(screenchar(&lines, 5))
  call assert_equal('wrong', c1 . c2 . c3 . c4 . c5)
endfunc

func Test_let_errmsg()
  call assert_fails('let v:errmsg = []', 'E730:')
  let v:errmsg = ''
  call assert_fails('let v:errmsg = []', 'E730:')
  let v:errmsg = ''
endfunc

" Test fix for issue #4507
func Test_skip_after_throw()
  try
    throw 'something'
    let x = wincol() || &ts
  catch /something/
  endtry
endfunc

func Test_number_max_min_size()
  " This will fail on systems without 64 bit number support or when not
  " configured correctly.
  call assert_equal(64, v:numbersize)

  call assert_true(v:numbermin < -9999999)
  call assert_true(v:numbermax > 9999999)
endfunc

func Test_curly_assignment()
  let s:svar = 'svar'
  let g:gvar = 'gvar'
  let lname = 'gvar'
  let gname = 'gvar'
  let {'s:'.lname} = {'g:'.gname}
  call assert_equal('gvar', s:gvar)
  let s:gvar = ''
  let { 's:'.lname } = { 'g:'.gname }
  call assert_equal('gvar', s:gvar)
  let s:gvar = ''
  let { 's:' . lname } = { 'g:' . gname }
  call assert_equal('gvar', s:gvar)
  let s:gvar = ''
  let { 's:' .. lname } = { 'g:' .. gname }
  call assert_equal('gvar', s:gvar)

  unlet s:svar
  unlet s:gvar
  unlet g:gvar
endfunc

" vim: shiftwidth=2 sts=2 expandtab
