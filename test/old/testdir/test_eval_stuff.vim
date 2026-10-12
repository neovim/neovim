" Tests for various eval things.

source view_util.vim
source shared.vim

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

func Test_nocatch_restore_silent_emsg()
  silent! try
    throw 1
  catch
  endtry
  echoerr 'wrong again'
  call assert_equal('wrong again', ScreenLine(&lines))
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
  call assert_fails('call mkdir("Xfile", "p")', 'E739:')
  call delete('Xfile')
  call delete('Xmkdir', 'rf')
  call assert_equal(0, mkdir(v:_null_string))
  call assert_fails('call mkdir([])', 'E730:')
  call assert_fails('call mkdir("abc", [], [])', 'E745:')
endfunc

func DoMkdirDel(name)
  call mkdir(a:name, 'pD')
  call assert_true(isdirectory(a:name))
endfunc

func DoMkdirDelAddFile(name)
  call mkdir(a:name, 'pD')
  call assert_true(isdirectory(a:name))
  call writefile(['text'], a:name .. '/file')
endfunc

func DoMkdirDelRec(name)
  call mkdir(a:name, 'pR')
  call assert_true(isdirectory(a:name))
endfunc

func DoMkdirDelRecAddFile(name)
  call mkdir(a:name, 'pR')
  call assert_true(isdirectory(a:name))
  call writefile(['text'], a:name .. '/file')
endfunc

func Test_mkdir_defer_del()
  " Xtopdir/tmp is created thus deleted, not Xtopdir itself
  call mkdir('Xtopdir', 'R')
  call DoMkdirDel('Xtopdir/tmp')
  call assert_true(isdirectory('Xtopdir'))
  call assert_false(isdirectory('Xtopdir/tmp'))

  " Deletion fails because "tmp" contains "sub"
  call DoMkdirDel('Xtopdir/tmp/sub')
  call assert_true(isdirectory('Xtopdir'))
  call assert_true(isdirectory('Xtopdir/tmp'))
  call delete('Xtopdir/tmp', 'rf')

  " Deletion fails because "tmp" contains "file"
  call DoMkdirDelAddFile('Xtopdir/tmp')
  call assert_true(isdirectory('Xtopdir'))
  call assert_true(isdirectory('Xtopdir/tmp'))
  call assert_true(filereadable('Xtopdir/tmp/file'))
  call delete('Xtopdir/tmp', 'rf')

  " Xtopdir/tmp is created thus deleted, not Xtopdir itself
  call DoMkdirDelRec('Xtopdir/tmp')
  call assert_true(isdirectory('Xtopdir'))
  call assert_false(isdirectory('Xtopdir/tmp'))

  " Deletion works even though "tmp" contains "sub"
  call DoMkdirDelRec('Xtopdir/tmp/sub')
  call assert_true(isdirectory('Xtopdir'))
  call assert_false(isdirectory('Xtopdir/tmp'))

  " Deletion works even though "tmp" contains "file"
  call DoMkdirDelRecAddFile('Xtopdir/tmp')
  call assert_true(isdirectory('Xtopdir'))
  call assert_false(isdirectory('Xtopdir/tmp'))
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
  call assert_fails("for x in 99", 'E1098:')
  call assert_fails("for x in function('winnr')", 'E1098:')
  call assert_fails("for x in {'a': 9}", 'E1098:')

  if 0
    /1/5/2/s/\n
  endif
  redraw
endfunc

func Test_for_over_null_string()
  let save_enc = &enc
  " set enc=iso8859
  let cnt = 0
  for c in v:_null_string
    let cnt += 1
  endfor
  call assert_equal(0, cnt)

  let &enc = save_enc
endfunc

func Test_for_with_modifier()
  " this checks has_loop_cmd() works with a modifier
  let result = []
  horizontal for i in range(3)
    call extend(result, [i])
  endfor
  call assert_equal([0, 1, 2], result)
endfunc

func Test_for_invalid_line_count()
  let lines =<< trim END
      111111111111111111111111 for line in ['one']
      endfor
  END
  call writefile(lines, 'XinvalidFor')
  " only test that this doesn't crash
  call RunVim([], [], '-u NONE -e -s -S XinvalidFor -c qa')

  call delete('XinvalidFor')
endfunc

func Test_readfile_binary()
  new
  call setline(1, ['one', 'two', 'three'])
  setlocal ff=dos
  silent write XReadfile_bin
  let lines = 'XReadfile_bin'->readfile()
  call assert_equal(['one', 'two', 'three'], lines)
  let lines = readfile('XReadfile_bin', '', 2)
  call assert_equal(['one', 'two'], lines)
  let lines = readfile('XReadfile_bin', 'b')
  call assert_equal(["one\r", "two\r", "three\r", ""], lines)
  let lines = readfile('XReadfile_bin', 'b', 2)
  call assert_equal(["one\r", "two\r"], lines)

  bwipe!
  call delete('XReadfile_bin')
endfunc

func Test_readfile_binary_empty()
  call writefile([], 'Xempty-file')
  " This used to compare uninitialized memory in Vim <= 8.2.4065
  call assert_equal([''], readfile('Xempty-file', 'b'))
  call delete('Xempty-file')
endfunc

func Test_readfile_bom()
  call writefile(["\ufeffFOO", "FOO\ufeffBAR"], 'XReadfile_bom')
  call assert_equal(['FOO', 'FOOBAR'], readfile('XReadfile_bom'))
  call delete('XReadfile_bom')
endfunc

func Test_readfile_max()
  call writefile(range(1, 4), 'XReadfile_max')
  call assert_equal(['1', '2'], readfile('XReadfile_max', '', 2))
  call assert_equal(['3', '4'], readfile('XReadfile_max', '', -2))
  call delete('XReadfile_max')
endfunc

func Test_let_errmsg()
  call assert_fails('let v:errmsg = []', 'E730:')
  let v:errmsg = ''
  call assert_fails('let v:errmsg = []', 'E730:')
  let v:errmsg = ''
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

  if has('float')
    let a = 'A'
    let b = 1.234
    call assert_equal('A1.234', a .. b)
  endif
endfunc

" Test fix for issue #4507
func Test_skip_after_throw()
  try
    throw 'something'
    let x = wincol() || &ts
  catch /something/
  endtry
endfunc

" scriptversion 1
func Test_string_concat_scriptversion1()
  call assert_true(has('vimscript-1'))
  let a = 'a'
  let b = 'b'

  echo a . b
  let a .= b
  let vers = 1.2.3
  call assert_equal('123', vers)

  if has('float')
    call assert_fails('let f = .5', 'E15:')
  endif
endfunc

" scriptversion 2
func Test_vvar_scriptversion2()
  call assert_true(exists('version'))
  echo version
  call assert_fails('let version = 1', 'E46:')
  call assert_equal(v:version, version)

  call assert_equal(v:version, v:versionlong / 10000)
  call assert_true(v:versionlong > 8011525)
endfunc

" scriptversion 1
func Test_vvar_scriptversion1()
  call assert_equal(15, 017)
  call assert_equal(15, 0o17)
  call assert_equal(15, 0O17)
  call assert_equal(18, 018)
  call assert_equal(511, 0o777)
endfunc

func Test_execute_cmd_with_null()
  call assert_fails('execute v:_null_list', 'E730:')
  call assert_fails('execute v:_null_dict', 'E731:')
  call assert_fails('execute v:_null_blob', 'E976:')
  execute v:_null_string
  " Nvim doesn't have null partials
  " call assert_fails('execute test_null_partial()', 'E729:')
  " Nvim doesn't have test_unknown()
  " call assert_fails('execute test_unknown()', 'E908:')
  if has('job')
    call assert_fails('execute test_null_job()', 'E908:')
    call assert_fails('execute test_null_channel()', 'E908:')
  endif
endfunc

func Test_number_max_min_size()
  " This will fail on systems without 64 bit number support or when not
  " configured correctly.
  call assert_equal(64, v:numbersize)

  call assert_true(v:numbermin < -9999999)
  call assert_true(v:numbermax > 9999999)
endfunc

func Assert_reg(name, type, value, valuestr, expr, exprstr)
  call assert_equal(a:type, getregtype(a:name))
  call assert_equal(a:value, getreg(a:name))
  call assert_equal(a:valuestr, string(getreg(a:name, 0, 1)))
  call assert_equal(a:expr, getreg(a:name, 1))
  call assert_equal(a:exprstr, string(getreg(a:name, 1, 1)))
endfunc

func Test_let_register()
  let @" = 'abc'
  call Assert_reg('"', 'v', "abc", "['abc']", "abc", "['abc']")
  let @" = "abc\n"
  call Assert_reg('"', 'V', "abc\n", "['abc']", "abc\n", "['abc']")
  let @" = "abc\<C-m>"
  call Assert_reg('"', 'V', "abc\r\n", "['abc\r']", "abc\r\n", "['abc\r']")
  let @= = '"abc"'
  call Assert_reg('=', 'v', "abc", "['abc']", '"abc"', "['\"abc\"']")
endfunc

func Assert_regput(name, result)
  new
  execute "silent normal! o==\n==\e\"" . a:name . "P"
  call assert_equal(a:result, getline(2, line('$')))
  bwipe!
endfunc

func Test_setreg_basic()
  call setreg('a', 'abcA', 'c')
  call Assert_reg('a', 'v', "abcA", "['abcA']", "abcA", "['abcA']")
  call Assert_regput('a', ['==', '=abcA='])

  call setreg('A', 'abcAc', 'c')
  call Assert_reg('A', 'v', "abcAabcAc", "['abcAabcAc']", "abcAabcAc", "['abcAabcAc']")
  call Assert_regput('a', ['==', '=abcAabcAc='])

  call setreg('A', 'abcAl', 'l')
  call Assert_reg('A', 'V', "abcAabcAcabcAl\n", "['abcAabcAcabcAl']", "abcAabcAcabcAl\n", "['abcAabcAcabcAl']")
  call Assert_regput('a', ['==', 'abcAabcAcabcAl', '=='])

  call setreg('A', 'abcAc2','c')
  call Assert_reg('A', 'v', "abcAabcAcabcAl\nabcAc2", "['abcAabcAcabcAl', 'abcAc2']", "abcAabcAcabcAl\nabcAc2", "['abcAabcAcabcAl', 'abcAc2']")
  call Assert_regput('a', ['==', '=abcAabcAcabcAl', 'abcAc2='])

  call setreg('b', 'abcB', 'v')
  call Assert_reg('b', 'v', "abcB", "['abcB']", "abcB", "['abcB']")
  call Assert_regput('b', ['==', '=abcB='])

  call setreg('b', 'abcBc', 'ca')
  call Assert_reg('b', 'v', "abcBabcBc", "['abcBabcBc']", "abcBabcBc", "['abcBabcBc']")
  call Assert_regput('b', ['==', '=abcBabcBc='])

  call setreg('b', 'abcBb', 'ba')
  call Assert_reg('b', "\<C-V>5", "abcBabcBcabcBb", "['abcBabcBcabcBb']", "abcBabcBcabcBb", "['abcBabcBcabcBb']")
  call Assert_regput('b', ['==', '=abcBabcBcabcBb='])

  call setreg('b', 'abcBc2','ca')
  call Assert_reg('b', "v", "abcBabcBcabcBb\nabcBc2", "['abcBabcBcabcBb', 'abcBc2']", "abcBabcBcabcBb\nabcBc2", "['abcBabcBcabcBb', 'abcBc2']")
  call Assert_regput('b', ['==', '=abcBabcBcabcBb', 'abcBc2='])

  call setreg('b', 'abcBb2','b50a')
  call Assert_reg('b', "\<C-V>50", "abcBabcBcabcBb\nabcBc2abcBb2", "['abcBabcBcabcBb', 'abcBc2abcBb2']", "abcBabcBcabcBb\nabcBc2abcBb2", "['abcBabcBcabcBb', 'abcBc2abcBb2']")
  call Assert_regput('b', ['==', '=abcBabcBcabcBb                                    =', ' abcBc2abcBb2'])

  call setreg('c', 'abcC', 'l')
  call Assert_reg('c', 'V', "abcC\n", "['abcC']", "abcC\n", "['abcC']")
  call Assert_regput('c', ['==', 'abcC', '=='])

  call setreg('C', 'abcCl', 'l')
  call Assert_reg('C', 'V', "abcC\nabcCl\n", "['abcC', 'abcCl']", "abcC\nabcCl\n", "['abcC', 'abcCl']")
  call Assert_regput('c', ['==', 'abcC', 'abcCl', '=='])

  call setreg('C', 'abcCc', 'c')
  call Assert_reg('C', 'v', "abcC\nabcCl\nabcCc", "['abcC', 'abcCl', 'abcCc']", "abcC\nabcCl\nabcCc", "['abcC', 'abcCl', 'abcCc']")
  call Assert_regput('c', ['==', '=abcC', 'abcCl', 'abcCc='])

  call setreg('d', 'abcD', 'V')
  call Assert_reg('d', 'V', "abcD\n", "['abcD']", "abcD\n", "['abcD']")
  call Assert_regput('d', ['==', 'abcD', '=='])

  call setreg('D', 'abcDb', 'b')
  call Assert_reg('d', "\<C-V>5", "abcD\nabcDb", "['abcD', 'abcDb']", "abcD\nabcDb", "['abcD', 'abcDb']")
  call Assert_regput('d', ['==', '=abcD =', ' abcDb'])

  call setreg('e', 'abcE', 'b')
  call Assert_reg('e', "\<C-V>4", "abcE", "['abcE']", "abcE", "['abcE']")
  call Assert_regput('e', ['==', '=abcE='])

  call setreg('E', 'abcEb', 'b')
  call Assert_reg('E', "\<C-V>5", "abcE\nabcEb", "['abcE', 'abcEb']", "abcE\nabcEb", "['abcE', 'abcEb']")
  call Assert_regput('e', ['==', '=abcE =', ' abcEb'])

  call setreg('E', 'abcEl', 'l')
  call Assert_reg('E', "V", "abcE\nabcEb\nabcEl\n", "['abcE', 'abcEb', 'abcEl']", "abcE\nabcEb\nabcEl\n", "['abcE', 'abcEb', 'abcEl']")
  call Assert_regput('e', ['==', 'abcE', 'abcEb', 'abcEl', '=='])

  call setreg('f', 'abcF', "\<C-v>")
  call Assert_reg('f', "\<C-V>4", "abcF", "['abcF']", "abcF", "['abcF']")
  call Assert_regput('f', ['==', '=abcF='])

  call setreg('F', 'abcFc', 'c')
  call Assert_reg('F', "v", "abcF\nabcFc", "['abcF', 'abcFc']", "abcF\nabcFc", "['abcF', 'abcFc']")
  call Assert_regput('f', ['==', '=abcF', 'abcFc='])

  call setreg('g', 'abcG', 'b10')
  call Assert_reg('g', "\<C-V>10", "abcG", "['abcG']", "abcG", "['abcG']")
  call Assert_regput('g', ['==', '=abcG      ='])

  call setreg('h', 'abcH', "\<C-v>10")
  call Assert_reg('h', "\<C-V>10", "abcH", "['abcH']", "abcH", "['abcH']")
  call Assert_regput('h', ['==', '=abcH      ='])

  call setreg('I', 'abcI')
  call Assert_reg('I', "v", "abcI", "['abcI']", "abcI", "['abcI']")
  call Assert_regput('I', ['==', '=abcI='])

  " Appending NL with setreg()
  call setreg('a', 'abcA2', 'c')
  call setreg('b', 'abcB2', 'v')
  call setreg('c', 'abcC2', 'l')
  call setreg('d', 'abcD2', 'V')
  call setreg('e', 'abcE2', 'b')
  call setreg('f', 'abcF2', "\<C-v>")
  call setreg('g', 'abcG2', 'b10')
  call setreg('h', 'abcH2', "\<C-v>10")
  call setreg('I', 'abcI2')

  call setreg('A', "\n")
  call Assert_reg('A', 'V', "abcA2\n", "['abcA2']", "abcA2\n", "['abcA2']")
  call Assert_regput('A', ['==', 'abcA2', '=='])

  call setreg('B', "\n", 'c')
  call Assert_reg('B', 'v', "abcB2\n", "['abcB2', '']", "abcB2\n", "['abcB2', '']")
  call Assert_regput('B', ['==', '=abcB2', '='])

  call setreg('C', "\n")
  call Assert_reg('C', 'V', "abcC2\n\n", "['abcC2', '']", "abcC2\n\n", "['abcC2', '']")
  call Assert_regput('C', ['==', 'abcC2', '', '=='])

  call setreg('D', "\n", 'l')
  call Assert_reg('D', 'V', "abcD2\n\n", "['abcD2', '']", "abcD2\n\n", "['abcD2', '']")
  call Assert_regput('D', ['==', 'abcD2', '', '=='])

  call setreg('E', "\n")
  call Assert_reg('E', 'V', "abcE2\n\n", "['abcE2', '']", "abcE2\n\n", "['abcE2', '']")
  call Assert_regput('E', ['==', 'abcE2', '', '=='])

  call setreg('F', "\n", 'b')
  call Assert_reg('F', "\<C-V>0", "abcF2\n", "['abcF2', '']", "abcF2\n", "['abcF2', '']")
  call Assert_regput('F', ['==', '=abcF2=', ' '])

  " Setting lists with setreg()
  call setreg('a', ['abcA3'], 'c')
  call Assert_reg('a', 'v', "abcA3", "['abcA3']", "abcA3", "['abcA3']")
  call Assert_regput('a', ['==', '=abcA3='])

  call setreg('b', ['abcB3'], 'l')
  call Assert_reg('b', 'V', "abcB3\n", "['abcB3']", "abcB3\n", "['abcB3']")
  call Assert_regput('b', ['==', 'abcB3', '=='])

  call setreg('c', ['abcC3'], 'b')
  call Assert_reg('c', "\<C-V>5", "abcC3", "['abcC3']", "abcC3", "['abcC3']")
  call Assert_regput('c', ['==', '=abcC3='])

  call setreg('d', ['abcD3'])
  call Assert_reg('d', 'V', "abcD3\n", "['abcD3']", "abcD3\n", "['abcD3']")
  call Assert_regput('d', ['==', 'abcD3', '=='])

  call setreg('e', [1, 2, 'abc', 3])
  call Assert_reg('e', 'V', "1\n2\nabc\n3\n", "['1', '2', 'abc', '3']", "1\n2\nabc\n3\n", "['1', '2', 'abc', '3']")
  call Assert_regput('e', ['==', '1', '2', 'abc', '3', '=='])

  call setreg('f', [1, 2, 3])
  call Assert_reg('f', 'V', "1\n2\n3\n", "['1', '2', '3']", "1\n2\n3\n", "['1', '2', '3']")
  call Assert_regput('f', ['==', '1', '2', '3', '=='])

  " Appending lists with setreg()
  call setreg('A', ['abcA3c'], 'c')
  call Assert_reg('A', 'v', "abcA3\nabcA3c", "['abcA3', 'abcA3c']", "abcA3\nabcA3c", "['abcA3', 'abcA3c']")
  call Assert_regput('A', ['==', '=abcA3', 'abcA3c='])

  call setreg('b', ['abcB3l'], 'la')
  call Assert_reg('b', 'V', "abcB3\nabcB3l\n", "['abcB3', 'abcB3l']", "abcB3\nabcB3l\n", "['abcB3', 'abcB3l']")
  call Assert_regput('b', ['==', 'abcB3', 'abcB3l', '=='])

  call setreg('C', ['abcC3b'], 'lb')
  call Assert_reg('C', "\<C-V>6", "abcC3\nabcC3b", "['abcC3', 'abcC3b']", "abcC3\nabcC3b", "['abcC3', 'abcC3b']")
  call Assert_regput('C', ['==', '=abcC3 =', ' abcC3b'])

  call setreg('D', ['abcD32'])
  call Assert_reg('D', 'V', "abcD3\nabcD32\n", "['abcD3', 'abcD32']", "abcD3\nabcD32\n", "['abcD3', 'abcD32']")
  call Assert_regput('D', ['==', 'abcD3', 'abcD32', '=='])

  call setreg('A', ['abcA32'])
  call Assert_reg('A', 'V', "abcA3\nabcA3c\nabcA32\n", "['abcA3', 'abcA3c', 'abcA32']", "abcA3\nabcA3c\nabcA32\n", "['abcA3', 'abcA3c', 'abcA32']")
  call Assert_regput('A', ['==', 'abcA3', 'abcA3c', 'abcA32', '=='])

  call setreg('B', ['abcB3c'], 'c')
  call Assert_reg('B', 'v', "abcB3\nabcB3l\nabcB3c", "['abcB3', 'abcB3l', 'abcB3c']", "abcB3\nabcB3l\nabcB3c", "['abcB3', 'abcB3l', 'abcB3c']")
  call Assert_regput('B', ['==', '=abcB3', 'abcB3l', 'abcB3c='])

  call setreg('C', ['abcC3l'], 'l')
  call Assert_reg('C', 'V', "abcC3\nabcC3b\nabcC3l\n", "['abcC3', 'abcC3b', 'abcC3l']", "abcC3\nabcC3b\nabcC3l\n", "['abcC3', 'abcC3b', 'abcC3l']")
  call Assert_regput('C', ['==', 'abcC3', 'abcC3b', 'abcC3l', '=='])

  call setreg('D', ['abcD3b'], 'b')
  call Assert_reg('D', "\<C-V>6", "abcD3\nabcD32\nabcD3b", "['abcD3', 'abcD32', 'abcD3b']", "abcD3\nabcD32\nabcD3b", "['abcD3', 'abcD32', 'abcD3b']")
  call Assert_regput('D', ['==', '=abcD3 =', ' abcD32', ' abcD3b'])

  " Appending lists with NL with setreg()
  call setreg('A', ["\n", 'abcA3l2'], 'l')
  call Assert_reg('A', "V", "abcA3\nabcA3c\nabcA32\n\n\nabcA3l2\n", "['abcA3', 'abcA3c', 'abcA32', '\n', 'abcA3l2']", "abcA3\nabcA3c\nabcA32\n\n\nabcA3l2\n", "['abcA3', 'abcA3c', 'abcA32', '\n', 'abcA3l2']")
  call Assert_regput('A', ['==', 'abcA3', 'abcA3c', 'abcA32', "\n", 'abcA3l2', '=='])

  call setreg('B', ["\n", 'abcB3c2'], 'c')
  call Assert_reg('B', "v", "abcB3\nabcB3l\nabcB3c\n\n\nabcB3c2", "['abcB3', 'abcB3l', 'abcB3c', '\n', 'abcB3c2']", "abcB3\nabcB3l\nabcB3c\n\n\nabcB3c2", "['abcB3', 'abcB3l', 'abcB3c', '\n', 'abcB3c2']")
  call Assert_regput('B', ['==', '=abcB3', 'abcB3l', 'abcB3c', "\n", 'abcB3c2='])

  call setreg('C', ["\n", 'abcC3b2'], 'b')
  call Assert_reg('C', "7", "abcC3\nabcC3b\nabcC3l\n\n\nabcC3b2", "['abcC3', 'abcC3b', 'abcC3l', '\n', 'abcC3b2']", "abcC3\nabcC3b\nabcC3l\n\n\nabcC3b2", "['abcC3', 'abcC3b', 'abcC3l', '\n', 'abcC3b2']")
  call Assert_regput('C', ['==', '=abcC3  =', ' abcC3b', ' abcC3l', " \n", ' abcC3b2'])

  call setreg('D', ["\n", 'abcD3b50'],'b50')
  call Assert_reg('D', "50", "abcD3\nabcD32\nabcD3b\n\n\nabcD3b50", "['abcD3', 'abcD32', 'abcD3b', '\n', 'abcD3b50']", "abcD3\nabcD32\nabcD3b\n\n\nabcD3b50", "['abcD3', 'abcD32', 'abcD3b', '\n', 'abcD3b50']")
  call Assert_regput('D', ['==', '=abcD3                                             =', ' abcD32', ' abcD3b', " \n", ' abcD3b50'])

  " Setting lists with NLs with setreg()
  call setreg('a', ['abcA4-0', "\n", "abcA4-2\n", "\nabcA4-3", "abcA4-4\nabcA4-4-2"])
  call Assert_reg('a', "V", "abcA4-0\n\n\nabcA4-2\n\n\nabcA4-3\nabcA4-4\nabcA4-4-2\n", "['abcA4-0', '\n', 'abcA4-2\n', '\nabcA4-3', 'abcA4-4\nabcA4-4-2']", "abcA4-0\n\n\nabcA4-2\n\n\nabcA4-3\nabcA4-4\nabcA4-4-2\n", "['abcA4-0', '\n', 'abcA4-2\n', '\nabcA4-3', 'abcA4-4\nabcA4-4-2']")
  call Assert_regput('a', ['==', 'abcA4-0', "\n", "abcA4-2\n", "\nabcA4-3", "abcA4-4\nabcA4-4-2", '=='])

  call setreg('b', ['abcB4c-0', "\n", "abcB4c-2\n", "\nabcB4c-3", "abcB4c-4\nabcB4c-4-2"], 'c')
  call Assert_reg('b', "v", "abcB4c-0\n\n\nabcB4c-2\n\n\nabcB4c-3\nabcB4c-4\nabcB4c-4-2", "['abcB4c-0', '\n', 'abcB4c-2\n', '\nabcB4c-3', 'abcB4c-4\nabcB4c-4-2']", "abcB4c-0\n\n\nabcB4c-2\n\n\nabcB4c-3\nabcB4c-4\nabcB4c-4-2", "['abcB4c-0', '\n', 'abcB4c-2\n', '\nabcB4c-3', 'abcB4c-4\nabcB4c-4-2']")
  call Assert_regput('b', ['==', '=abcB4c-0', "\n", "abcB4c-2\n", "\nabcB4c-3", "abcB4c-4\nabcB4c-4-2="])

  call setreg('c', ['abcC4l-0', "\n", "abcC4l-2\n", "\nabcC4l-3", "abcC4l-4\nabcC4l-4-2"], 'l')
  call Assert_reg('c', "V", "abcC4l-0\n\n\nabcC4l-2\n\n\nabcC4l-3\nabcC4l-4\nabcC4l-4-2\n", "['abcC4l-0', '\n', 'abcC4l-2\n', '\nabcC4l-3', 'abcC4l-4\nabcC4l-4-2']", "abcC4l-0\n\n\nabcC4l-2\n\n\nabcC4l-3\nabcC4l-4\nabcC4l-4-2\n", "['abcC4l-0', '\n', 'abcC4l-2\n', '\nabcC4l-3', 'abcC4l-4\nabcC4l-4-2']")
  call Assert_regput('c', ['==', 'abcC4l-0', "\n", "abcC4l-2\n", "\nabcC4l-3", "abcC4l-4\nabcC4l-4-2", '=='])

  call setreg('d', ['abcD4b-0', "\n", "abcD4b-2\n", "\nabcD4b-3", "abcD4b-4\nabcD4b-4-2"], 'b')
  call Assert_reg('d', "20", "abcD4b-0\n\n\nabcD4b-2\n\n\nabcD4b-3\nabcD4b-4\nabcD4b-4-2", "['abcD4b-0', '\n', 'abcD4b-2\n', '\nabcD4b-3', 'abcD4b-4\nabcD4b-4-2']", "abcD4b-0\n\n\nabcD4b-2\n\n\nabcD4b-3\nabcD4b-4\nabcD4b-4-2", "['abcD4b-0', '\n', 'abcD4b-2\n', '\nabcD4b-3', 'abcD4b-4\nabcD4b-4-2']")
  call Assert_regput('d', ['==', '=abcD4b-0            =', " \n", " abcD4b-2\n", " \nabcD4b-3", " abcD4b-4\nabcD4b-4-2"])

  call setreg('e', ['abcE4b10-0', "\n", "abcE4b10-2\n", "\nabcE4b10-3", "abcE4b10-4\nabcE4b10-4-2"], 'b10')
  call Assert_reg('e', "10", "abcE4b10-0\n\n\nabcE4b10-2\n\n\nabcE4b10-3\nabcE4b10-4\nabcE4b10-4-2", "['abcE4b10-0', '\n', 'abcE4b10-2\n', '\nabcE4b10-3', 'abcE4b10-4\nabcE4b10-4-2']", "abcE4b10-0\n\n\nabcE4b10-2\n\n\nabcE4b10-3\nabcE4b10-4\nabcE4b10-4-2", "['abcE4b10-0', '\n', 'abcE4b10-2\n', '\nabcE4b10-3', 'abcE4b10-4\nabcE4b10-4-2']")
  call Assert_regput('e', ['==', '=abcE4b10-0=', " \n", " abcE4b10-2\n", " \nabcE4b10-3", " abcE4b10-4\nabcE4b10-4-2"])

  " Search and expressions
  call setreg('/', ['abc/'])
  call Assert_reg('/', 'v', "abc/", "['abc/']", "abc/", "['abc/']")
  call Assert_regput('/', ['==', '=abc/='])

  call setreg('/', ["abc/\n"])
  call Assert_reg('/', 'v', "abc/\n", "['abc/\n']", "abc/\n", "['abc/\n']")
  call Assert_regput('/', ['==', "=abc/\n="])

  call setreg('=', ['"abc/"'])
  call Assert_reg('=', 'v', "abc/", "['abc/']", '"abc/"', "['\"abc/\"']")

  call setreg('=', ["\"abc/\n\""])
  call Assert_reg('=', 'v', "abc/\n", "['abc/\n']", "\"abc/\n\"", "['\"abc/\n\"']")

  " System clipboard
  if has('clipboard') && !has('nvim')  " Nvim: clipboard update is delayed
    new | only!
    call setline(1, ['clipboard contents', 'something else'])
    " Save and restore system clipboard.
    " If no connection to X-Server is possible, test should succeed.
    let _clipreg = ['*', getreg('*'), getregtype('*')]
    let _clipopt = &cb
    let &cb='unnamed'
    1y
    call Assert_reg('*', 'V', "clipboard contents\n", "['clipboard contents']", "clipboard contents\n", "['clipboard contents']")
    tabdo :windo :echo "hi"
    2y
    call Assert_reg('*', 'V', "something else\n", "['something else']", "something else\n", "['something else']")
    let &cb=_clipopt
    call call('setreg', _clipreg)
    enew!
  endif

  " Error cases
  call assert_fails('call setreg()', 'E119:')
  call assert_fails('call setreg(1)', 'E119:')
  call assert_fails('call setreg(1, 2, 3, 4)', 'E118:')
  call assert_fails('call setreg([], 2)', 'E730:')
  call assert_fails('call setreg(1, 2, [])', 'E730:')
  call assert_fails('call setreg("/", ["1", "2"])', 'E883:')
  call assert_fails('call setreg("=", ["1", "2"])', 'E883:')
  call assert_fails('call setreg(1, ["", "", [], ""])', 'E730:')
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

func Test_deep_recursion()
  " this was running out of stack
  call assert_fails("exe 'if ' .. repeat('(', 1002)", 'E1169: Expression too recursive: ((')
endfunc

" K_SPECIAL in the modified character used be escaped, which causes
" double-escaping with feedkeys() or as the return value of an <expr> mapping,
" and doesn't match what getchar() returns,
func Test_modified_char_no_escape_special()
  nnoremap <M-…> <Cmd>let g:got_m_ellipsis += 1<CR>
  call feedkeys("\<M-…>", 't')
  call assert_equal("\<M-…>", getchar())
  let g:got_m_ellipsis = 0
  call feedkeys("\<M-…>", 'xt')
  call assert_equal(1, g:got_m_ellipsis)
  func Func()
    return "\<M-…>"
  endfunc
  nmap <expr> <F2> Func()
  call feedkeys("\<F2>", 'xt')
  call assert_equal(2, g:got_m_ellipsis)
  delfunc Func
  nunmap <F2>
  unlet g:got_m_ellipsis
  nunmap <M-…>
endfunc

func Test_eval_string_in_special_key()
  " this was using the '{' inside <> as the start of an interpolated string
  silent! echo 0{1-$"\<S--{>n|nö%
endfunc

" vim: shiftwidth=2 sts=2 expandtab
