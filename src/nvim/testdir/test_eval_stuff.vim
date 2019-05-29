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
