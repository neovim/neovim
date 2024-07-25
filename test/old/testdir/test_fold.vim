" Test for folding

source check.vim
source view_util.vim
source screendump.vim

func PrepIndent(arg)
  return [a:arg] + repeat(["\t".a:arg], 5)
endfu

func Test_address_fold_new_default_commentstring()
  " Test with the new commentstring defaults, that includes padding after v9.1.464
  new
  call setline(1, ['int FuncName() {/* {{{ */', 1, 2, 3, 4, 5, '}/* }}} */',
	      \ 'after fold 1', 'after fold 2', 'after fold 3'])
  setl fen fdm=marker
  " The next commands should all copy the same part of the buffer,
  " regardless of the addressing type, since the part to be copied
  " is folded away
  :1y
  call assert_equal(['int FuncName() {/* {{{ */', '1', '2', '3', '4', '5', '}/* }}} */'], getreg(0,1,1))
  :.y
  call assert_equal(['int FuncName() {/* {{{ */', '1', '2', '3', '4', '5', '}/* }}} */'], getreg(0,1,1))
  :.+y
  call assert_equal(['int FuncName() {/* {{{ */', '1', '2', '3', '4', '5', '}/* }}} */'], getreg(0,1,1))
  :.,.y
  call assert_equal(['int FuncName() {/* {{{ */', '1', '2', '3', '4', '5', '}/* }}} */'], getreg(0,1,1))
  :sil .1,.y
  call assert_equal(['int FuncName() {/* {{{ */', '1', '2', '3', '4', '5', '}/* }}} */'], getreg(0,1,1))
  " use silent to make E493 go away
  :sil .+,.y
  call assert_equal(['int FuncName() {/* {{{ */', '1', '2', '3', '4', '5', '}/* }}} */'], getreg(0,1,1))
  :,y
  call assert_equal(['int FuncName() {/* {{{ */', '1', '2', '3', '4', '5', '}/* }}} */'], getreg(0,1,1))
  :,+y
  call assert_equal(['int FuncName() {/* {{{ */', '1', '2', '3', '4', '5', '}/* }}} */','after fold 1'], getreg(0,1,1))
  " using .+3 as second address should c opy  the whole folded line + the next  3
  " lines
  :.,+3y
  call assert_equal(['int FuncName() {/* {{{ */', '1', '2', '3', '4', '5', '}/* }}} */',
	      \ 'after fold 1', 'after fold 2' , 'after fold 3'], getreg(0,1,1))
  :sil .,-2y
  call assert_equal(['int FuncName() {/* {{{ */', '1', '2', '3', '4', '5', '}/* }}} */'], getreg(0,1,1))

  " now test again with folding disabled
  set nofoldenable
  :1y
  call assert_equal(['int FuncName() {/* {{{ */'], getreg(0,1,1))
  :.y
  call assert_equal(['int FuncName() {/* {{{ */'], getreg(0,1,1))
  :.+y
  call assert_equal(['1'], getreg(0,1,1) )
  :.,.y
  call assert_equal(['int FuncName() {/* {{{ */'], getreg(0,1,1))
  " use silent to make E493 go away
  :sil .1,.y
  call assert_equal(['int FuncName() {/* {{{ */', '1'], getreg(0,1,1))
  " use silent to make E493 go away
  :sil .+,.y
  call assert_equal(['int FuncName() {/* {{{ */', '1'], getreg(0,1,1))
  :,y
  call assert_equal(['int FuncName() {/* {{{ */'], getreg(0,1,1))
  :,+y
  call assert_equal(['int FuncName() {/* {{{ */', '1'], getreg(0,1,1))
  " using .+3 as second address should c opy  the whole folded line + the next 3
  " lines
  :.,+3y
  call assert_equal(['int FuncName() {/* {{{ */', '1', '2', '3'], getreg(0,1,1))
  :7
  :sil .,-2y
  call assert_equal(['4', '5', '}/* }}} */'], getreg(0,1,1))

  quit!
endfunc

func Test_address_fold_old_default_commentstring()
  " Test with the old commentstring defaults, before v9.1.464
  new
  call setline(1, ['int FuncName() {/*{{{*/', 1, 2, 3, 4, 5, '}/*}}}*/',
	      \ 'after fold 1', 'after fold 2', 'after fold 3'])
  setl fen fdm=marker
  " The next commands should all copy the same part of the buffer,
  " regardless of the addressing type, since the part to be copied
  " is folded away
  :1y
  call assert_equal(['int FuncName() {/*{{{*/', '1', '2', '3', '4', '5', '}/*}}}*/'], getreg(0,1,1))
  :.y
  call assert_equal(['int FuncName() {/*{{{*/', '1', '2', '3', '4', '5', '}/*}}}*/'], getreg(0,1,1))
  :.+y
  call assert_equal(['int FuncName() {/*{{{*/', '1', '2', '3', '4', '5', '}/*}}}*/'], getreg(0,1,1))
  :.,.y
  call assert_equal(['int FuncName() {/*{{{*/', '1', '2', '3', '4', '5', '}/*}}}*/'], getreg(0,1,1))
  :sil .1,.y
  call assert_equal(['int FuncName() {/*{{{*/', '1', '2', '3', '4', '5', '}/*}}}*/'], getreg(0,1,1))
  " use silent to make E493 go away
  :sil .+,.y
  call assert_equal(['int FuncName() {/*{{{*/', '1', '2', '3', '4', '5', '}/*}}}*/'], getreg(0,1,1))
  :,y
  call assert_equal(['int FuncName() {/*{{{*/', '1', '2', '3', '4', '5', '}/*}}}*/'], getreg(0,1,1))
  :,+y
  call assert_equal(['int FuncName() {/*{{{*/', '1', '2', '3', '4', '5', '}/*}}}*/','after fold 1'], getreg(0,1,1))
  " using .+3 as second address should copy the whole folded line + the next 3
  " lines
  :.,+3y
  call assert_equal(['int FuncName() {/*{{{*/', '1', '2', '3', '4', '5', '}/*}}}*/',
	      \ 'after fold 1', 'after fold 2', 'after fold 3'], getreg(0,1,1))
  :sil .,-2y
  call assert_equal(['int FuncName() {/*{{{*/', '1', '2', '3', '4', '5', '}/*}}}*/'], getreg(0,1,1))

  " now test again with folding disabled
  set nofoldenable
  :1y
  call assert_equal(['int FuncName() {/*{{{*/'], getreg(0,1,1))
  :.y
  call assert_equal(['int FuncName() {/*{{{*/'], getreg(0,1,1))
  :.+y
  call assert_equal(['1'], getreg(0,1,1))
  :.,.y
  call assert_equal(['int FuncName() {/*{{{*/'], getreg(0,1,1))
  " use silent to make E493 go away
  :sil .1,.y
  call assert_equal(['int FuncName() {/*{{{*/', '1'], getreg(0,1,1))
  " use silent to make E493 go away
  :sil .+,.y
  call assert_equal(['int FuncName() {/*{{{*/', '1'], getreg(0,1,1))
  :,y
  call assert_equal(['int FuncName() {/*{{{*/'], getreg(0,1,1))
  :,+y
  call assert_equal(['int FuncName() {/*{{{*/', '1'], getreg(0,1,1))
  " using .+3 as second address should copy the whole folded line + the next 3
  " lines
  :.,+3y
  call assert_equal(['int FuncName() {/*{{{*/', '1', '2', '3'], getreg(0,1,1))
  :7
  :sil .,-2y
  call assert_equal(['4', '5', '}/*}}}*/'], getreg(0,1,1))

  quit!
endfunc

func Test_address_offsets()
  " check the help for :range-closed-fold
  enew
  call setline(1, [
        \ '1 one',
        \ '2 two',
        \ '3 three',
        \ '4 four FOLDED',
        \ '5 five FOLDED',
        \ '6 six',
        \ '7 seven',
        \ '8 eight',
        \])
  set foldmethod=manual
  normal 4Gvjzf
  3,4+2yank
  call assert_equal([
        \ '3 three',
        \ '4 four FOLDED',
        \ '5 five FOLDED',
        \ '6 six',
        \ '7 seven',
        \ ], getreg(0,1,1))

  enew!
  call setline(1, [
        \ '1 one',
        \ '2 two',
        \ '3 three FOLDED',
        \ '4 four FOLDED',
        \ '5 five FOLDED',
        \ '6 six FOLDED',
        \ '7 seven',
        \ '8 eight',
        \])
  normal 3Gv3jzf
  2,4-1yank
  call assert_equal([
        \ '2 two',
        \ '3 three FOLDED',
        \ '4 four FOLDED',
        \ '5 five FOLDED',
        \ '6 six FOLDED',
        \ ], getreg(0,1,1))

  bwipe!
endfunc

func Test_indent_fold()
    new
    call setline(1, ['', 'a', '    b', '    c'])
    setl fen fdm=indent
    2
    norm! >>
    let a=map(range(1,4), 'foldclosed(v:val)')
    call assert_equal([-1,-1,-1,-1], a)
    bw!
endfunc

func Test_indent_fold2()
    new
    call setline(1, ['', '{{{', '}}}', '{{{', '}}}'])
    setl fen fdm=marker
    2
    norm! >>
    let a=map(range(1,5), 'v:val->foldclosed()')
    call assert_equal([-1,-1,-1,4,4], a)
    bw!
endfunc

" Test for fold indent with indents greater than 'foldnestmax'
func Test_indent_fold_max()
  new
  setlocal foldmethod=indent
  setlocal shiftwidth=2
  " 'foldnestmax' default value is 20
  call setline(1, "\t\t\t\t\t\ta")
  call assert_equal(20, foldlevel(1))
  setlocal foldnestmax=10
  call assert_equal(10, foldlevel(1))
  setlocal foldnestmax=-1
  call assert_equal(0, foldlevel(1))
  bw!
endfunc

func Test_indent_fold_tabstop()
  call setline(1, ['0', '    1', '    1', "\t2", "\t2"])
  setlocal shiftwidth=4
  setlocal foldcolumn=1
  setlocal foldlevel=2
  setlocal foldmethod=indent
  redraw
  call assert_equal('2        2', ScreenLines(5, 10)[0])
  vsplit
  windo diffthis
  botright new
  " This 'tabstop' value should not be used for folding in other buffers.
  setlocal tabstop=4
  diffoff!
  redraw
  call assert_equal('2        2', ScreenLines(5, 10)[0])

  bwipe!
  bwipe!
endfunc

func Test_manual_fold_with_filter()
  CheckExecutable cat
  for type in ['manual', 'marker']
    exe 'set foldmethod=' . type
    new
    call setline(1, range(1, 20))
    4,$fold
    %foldopen
    10,$fold
    %foldopen
    " This filter command should not have an effect
    1,8! cat
    call feedkeys('5ggzdzMGdd', 'xt')
    call assert_equal(['1', '2', '3', '4', '5', '6', '7', '8', '9'], getline(1, '$'))

    bwipe!
    set foldmethod&
  endfor
endfunc

func Test_indent_fold_with_read()
  new
  set foldmethod=indent
  call setline(1, repeat(["\<Tab>a"], 4))
  for n in range(1, 4)
    call assert_equal(1, foldlevel(n))
  endfor

  call writefile(["a", "", "\<Tab>a"], 'Xfile')
  foldopen
  2read Xfile
  %foldclose
  call assert_equal(1, foldlevel(1))
  call assert_equal(2, foldclosedend(1))
  call assert_equal(0, foldlevel(3))
  call assert_equal(0, foldlevel(4))
  call assert_equal(1, foldlevel(5))
  call assert_equal(7, 5->foldclosedend())

  bwipe!
  set foldmethod&
  call delete('Xfile')
endfunc

func Test_combining_folds_indent()
  new
  let one = "\<Tab>a"
  let zero = 'a'
  call setline(1, [one, one, zero, zero, zero, one, one, one])
  set foldmethod=indent
  3,5d
  %foldclose
  call assert_equal(5, foldclosedend(1))

  set foldmethod&
  bwipe!
endfunc

func Test_combining_folds_marker()
  new
  call setline(1, ['{{{', '}}}', '', '', '', '{{{', '', '}}}'])
  set foldmethod=marker
  3,5d
  %foldclose
  call assert_equal(2, foldclosedend(1))

  set foldmethod&
  bwipe!
endfunc

func Test_folds_marker_in_comment()
  new
  call setline(1, ['" foo', 'bar', 'baz'])
  setl fen fdm=marker
  setl com=sO:\"\ -,mO:\"\ \ ,eO:\"\",:\" cms=\"%s
  norm! zf2j
  setl nofen
  :1y
  call assert_equal(['" foo{{{'], getreg(0,1,1))
  :+2y
  call assert_equal(['baz"}}}'], getreg(0,1,1))

  set foldmethod&
  bwipe!
endfunc

func s:TestFoldExpr(lnum)
  let thisline = getline(a:lnum)
  if thisline == 'a'
    return 1
  elseif thisline == 'b'
    return 0
  elseif thisline == 'c'
    return '<1'
  elseif thisline == 'd'
    return '>1'
  endif
  return 0
endfunction

func Test_update_folds_expr_read()
  new
  call setline(1, ['a', 'a', 'a', 'a', 'a', 'a'])
  set foldmethod=expr
  set foldexpr=s:TestFoldExpr(v:lnum)
  2
  foldopen
  call writefile(['b', 'b', 'a', 'a', 'd', 'a', 'a', 'c'], 'Xfile')
  read Xfile
  %foldclose
  call assert_equal(2, foldclosedend(1))
  call assert_equal(0, foldlevel(3))
  call assert_equal(0, 4->foldlevel())
  call assert_equal(6, foldclosedend(5))
  call assert_equal(10, foldclosedend(7))
  call assert_equal(14, foldclosedend(11))

  call delete('Xfile')
  bwipe!
  set foldmethod& foldexpr&
endfunc

" Test for what patch 8.1.0535 fixes.
func Test_foldexpr_no_interrupt_addsub()
  new
  func! FoldFunc()
    call setpos('.', getcurpos())
    return '='
  endfunc

  set foldmethod=expr
  set foldexpr=FoldFunc()
  call setline(1, '1.2')

  exe "norm! $\<C-A>"
  call assert_equal('1.3', getline(1))

  bwipe!
  delfunc FoldFunc
  set foldmethod& foldexpr&
endfunc

func Check_foldlevels(expected)
  call assert_equal(a:expected, map(range(1, line('$')), 'foldlevel(v:val)'))
endfunc

func Test_move_folds_around_manual()
  new
  let input = PrepIndent("a") + PrepIndent("b") + PrepIndent("c")
  call setline(1, PrepIndent("a") + PrepIndent("b") + PrepIndent("c"))
  let folds=[-1, 2, 2, 2, 2, 2, -1, 8, 8, 8, 8, 8, -1, 14, 14, 14, 14, 14]
  " all folds closed
  set foldenable foldlevel=0 fdm=indent
  " needs a forced redraw
  redraw!
  set fdm=manual
  call assert_equal(folds, map(range(1, line('$')), 'foldclosed(v:val)'))
  call assert_equal(input, getline(1, '$'))
  7,12m0
  call assert_equal(PrepIndent("b") + PrepIndent("a") + PrepIndent("c"), getline(1, '$'))
  call assert_equal(folds, map(range(1, line('$')), 'foldclosed(v:val)'))
  10,12m0
  call assert_equal(PrepIndent("a")[1:] + PrepIndent("b") + ["a"] +  PrepIndent("c"), getline(1, '$'))
  call assert_equal([1, 1, 1, 1, 1, -1, 7, 7, 7, 7, 7, -1, -1, 14, 14, 14, 14, 14], map(range(1, line('$')), 'foldclosed(v:val)'))
  " moving should not close the folds
  %d
  call setline(1, PrepIndent("a") + PrepIndent("b") + PrepIndent("c"))
  set fdm=indent
  redraw!
  set fdm=manual
  call cursor(2, 1)
  %foldopen
  7,12m0
  let folds=repeat([-1], 18)
  call assert_equal(PrepIndent("b") + PrepIndent("a") + PrepIndent("c"), getline(1, '$'))
  call assert_equal(folds, map(range(1, line('$')), 'foldclosed(v:val)'))
  norm! zM
  " folds are not corrupted and all have been closed
  call assert_equal([-1, 2, 2, 2, 2, 2, -1, 8, 8, 8, 8, 8, -1, 14, 14, 14, 14, 14], map(range(1, line('$')), 'foldclosed(v:val)'))
  %d
  call setline(1, ["a", "\tb", "\tc", "\td", "\te"])
  set fdm=indent
  redraw!
  set fdm=manual
  %foldopen
  3m4
  %foldclose
  call assert_equal(["a", "\tb", "\td", "\tc", "\te"], getline(1, '$'))
  call assert_equal([-1, 5, 5, 5, 5], map(range(1, line('$')), 'foldclosedend(v:val)'))
  %d
  call setline(1, ["a", "\tb", "\tc", "\td", "\te", "z", "\ty", "\tx", "\tw", "\tv"])
  set fdm=indent foldlevel=0
  set fdm=manual
  %foldopen
  3m1
  %foldclose
  call assert_equal(["a", "\tc", "\tb", "\td", "\te", "z", "\ty", "\tx", "\tw", "\tv"], getline(1, '$'))
  call assert_equal(0, foldlevel(2))
  call assert_equal(5, foldclosedend(3))
  call assert_equal([-1, -1, 3, 3, 3, -1, 7, 7, 7, 7], map(range(1, line('$')), 'foldclosed(v:val)'))
  2,6m$
  %foldclose
  call assert_equal(5, foldclosedend(2))
  call assert_equal(0, foldlevel(6))
  call assert_equal(9, foldclosedend(7))
  call assert_equal([-1, 2, 2, 2, 2, -1, 7, 7, 7, -1], map(range(1, line('$')), 'foldclosed(v:val)'))

  %d
  " Ensure moving around the edges still works.
  call setline(1, PrepIndent("a") + repeat(["a"], 3) + ["\ta"])
  set fdm=indent foldlevel=0
  set fdm=manual
  %foldopen
  6m$
  " The first fold has been truncated to the 5'th line.
  " Second fold has been moved up because the moved line is now below it.
  call Check_foldlevels([0, 1, 1, 1, 1, 0, 0, 0, 1, 0])

  %delete
  set fdm=indent foldlevel=0
  call setline(1, [
	\ "a",
	\ "\ta",
	\ "\t\ta",
	\ "\t\ta",
	\ "\t\ta",
	\ "a",
	\ "a"])
  set fdm=manual
  %foldopen!
  4,5m6
  call Check_foldlevels([0, 1, 2, 0, 0, 0, 0])

  %delete
  set fdm=indent
  call setline(1, [
	\ "\ta",
	\ "\t\ta",
	\ "\t\ta",
	\ "\t\ta",
	\ "\ta",
	\ "\t\ta",
	\ "\t\ta",
	\ "\t\ta",
	\ "\ta",
	\ "\t\ta",
	\ "\t\ta",
	\ "\t\ta",
	\ "\t\ta",
	\ "\ta",
	\ "a"])
  set fdm=manual
  %foldopen!
  13m7
  call Check_foldlevels([1, 2, 2, 2, 1, 2, 2, 1, 1, 1, 2, 2, 2, 1, 0])

  bw!
endfunc

func Test_move_folds_around_indent()
  new
  let input = PrepIndent("a") + PrepIndent("b") + PrepIndent("c")
  call setline(1, PrepIndent("a") + PrepIndent("b") + PrepIndent("c"))
  let folds=[-1, 2, 2, 2, 2, 2, -1, 8, 8, 8, 8, 8, -1, 14, 14, 14, 14, 14]
  " all folds closed
  set fdm=indent
  call assert_equal(folds, map(range(1, line('$')), 'foldclosed(v:val)'))
  call assert_equal(input, getline(1, '$'))
  7,12m0
  call assert_equal(PrepIndent("b") + PrepIndent("a") + PrepIndent("c"), getline(1, '$'))
  call assert_equal(folds, map(range(1, line('$')), 'foldclosed(v:val)'))
  10,12m0
  call assert_equal(PrepIndent("a")[1:] + PrepIndent("b") + ["a"] +  PrepIndent("c"), getline(1, '$'))
  call assert_equal([1, 1, 1, 1, 1, -1, 7, 7, 7, 7, 7, -1, -1, 14, 14, 14, 14, 14], map(range(1, line('$')), 'foldclosed(v:val)'))
  " moving should not close the folds
  %d
  call setline(1, PrepIndent("a") + PrepIndent("b") + PrepIndent("c"))
  set fdm=indent
  call cursor(2, 1)
  %foldopen
  7,12m0
  let folds=repeat([-1], 18)
  call assert_equal(PrepIndent("b") + PrepIndent("a") + PrepIndent("c"), getline(1, '$'))
  call assert_equal(folds, map(range(1, line('$')), 'foldclosed(v:val)'))
  norm! zM
  " folds are not corrupted and all have been closed
  call assert_equal([-1, 2, 2, 2, 2, 2, -1, 8, 8, 8, 8, 8, -1, 14, 14, 14, 14, 14], map(range(1, line('$')), 'foldclosed(v:val)'))
  %d
  call setline(1, ["a", "\tb", "\tc", "\td", "\te"])
  set fdm=indent
  %foldopen
  3m4
  %foldclose
  call assert_equal(["a", "\tb", "\td", "\tc", "\te"], getline(1, '$'))
  call assert_equal([-1, 5, 5, 5, 5], map(range(1, line('$')), 'foldclosedend(v:val)'))
  %d
  call setline(1, ["a", "\tb", "\tc", "\td", "\te", "z", "\ty", "\tx", "\tw", "\tv"])
  set fdm=indent foldlevel=0
  %foldopen
  3m1
  %foldclose
  call assert_equal(["a", "\tc", "\tb", "\td", "\te", "z", "\ty", "\tx", "\tw", "\tv"], getline(1, '$'))
  call assert_equal(1, foldlevel(2))
  call assert_equal(5, foldclosedend(3))
  call assert_equal([-1, 2, 2, 2, 2, -1, 7, 7, 7, 7], map(range(1, line('$')), 'foldclosed(v:val)'))
  2,6m$
  %foldclose
  call assert_equal(9, foldclosedend(2))
  call assert_equal(1, foldlevel(6))
  call assert_equal(9, foldclosedend(7))
  call assert_equal([-1, 2, 2, 2, 2, 2, 2, 2, 2, -1], map(range(1, line('$')), 'foldclosed(v:val)'))
  " Ensure moving around the edges still works.
  %d
  call setline(1, PrepIndent("a") + repeat(["a"], 3) + ["\ta"])
  set fdm=indent foldlevel=0
  %foldopen
  6m$
  " The first fold has been truncated to the 5'th line.
  " Second fold has been moved up because the moved line is now below it.
  call Check_foldlevels([0, 1, 1, 1, 1, 0, 0, 0, 1, 1])
  bw!
endfunc

func Test_folddoopen_folddoclosed()
  new
  call setline(1, range(1, 9))
  set foldmethod=manual
  1,3 fold
  6,8 fold

  " Test without range.
  folddoopen   s/$/o/
  folddoclosed s/$/c/
  call assert_equal(['1c', '2c', '3c',
  \                  '4o', '5o',
  \                  '6c', '7c', '8c',
  \                  '9o'], getline(1, '$'))

  " Test with range.
  call setline(1, range(1, 9))
  1,8 folddoopen   s/$/o/
  4,$ folddoclosed s/$/c/
  call assert_equal(['1',  '2', '3',
  \                  '4o', '5o',
  \                  '6c', '7c', '8c',
  \                  '9'], getline(1, '$'))

  set foldmethod&
  bw!
endfunc

func Test_fold_error()
  new
  call setline(1, [1, 2])

  for fm in ['indent', 'expr', 'syntax', 'diff']
    exe 'set foldmethod=' . fm
    call assert_fails('norm zf', 'E350:')
    call assert_fails('norm zd', 'E351:')
    call assert_fails('norm zE', 'E352:')
  endfor

  set foldmethod=manual
  call assert_fails('norm zd', 'E490:')
  call assert_fails('norm zo', 'E490:')
  call assert_fails('3fold',   'E16:')

  set foldmethod=marker
  set nomodifiable
  call assert_fails('1,2fold', 'E21:')

  set modifiable&
  set foldmethod&
  bw!
endfunc

func Test_foldtext_recursive()
  new
  call setline(1, ['{{{', 'some text', '}}}'])
  setlocal foldenable foldmethod=marker foldtext=foldtextresult(v\:foldstart)
  " This was crashing because of endless recursion.
  2foldclose
  redraw
  call assert_equal(1, foldlevel(2))
  call assert_equal(1, foldclosed(2))
  call assert_equal(3, foldclosedend(2))
  bwipe!
endfunc

" Various fold related tests

" Basic test if a fold can be created, opened, moving to the end and closed
func Test_fold_manual()
  new
  set fdm=manual

  let content = ['1 aa', '2 bb', '3 cc']
  call append(0, content)
  call cursor(1, 1)
  normal zf2j
  call assert_equal('1 aa', getline(foldclosed('.')))
  normal zo
  call assert_equal(-1, foldclosed('.'))
  normal ]z
  call assert_equal('3 cc', getline('.'))
  normal zc
  call assert_equal('1 aa', getline(foldclosed('.')))

  " Create a fold inside a closed fold after setting 'foldlevel'
  %d _
  call setline(1, range(1, 5))
  1,5fold
  normal zR
  2,4fold
  set foldlevel=1
  3fold
  call assert_equal([1, 3, 3, 3, 1], map(range(1, 5), {->foldlevel(v:val)}))
  set foldlevel&

  " Create overlapping folds (at the start and at the end)
  normal zE
  2,3fold
  normal zR
  3,4fold
  call assert_equal([0, 2, 2, 1, 0], map(range(1, 5), {->foldlevel(v:val)}))
  normal zE
  3,4fold
  normal zR
  2,3fold
  call assert_equal([0, 1, 2, 2, 0], map(range(1, 5), {->foldlevel(v:val)}))

  " Create a nested fold across two non-adjoining folds
  %d _
  call setline(1, range(1, 7))
  1,2fold
  normal zR
  4,5fold
  normal zR
  6,7fold
  normal zR
  1,5fold
  call assert_equal([2, 2, 1, 2, 2, 1, 1],
        \ map(range(1, 7), {->foldlevel(v:val)}))

  " A newly created nested fold should be closed
  %d _
  call setline(1, range(1, 6))
  1,6fold
  normal zR
  3,4fold
  normal zR
  2,5fold
  call assert_equal([1, 2, 3, 3, 2, 1], map(range(1, 6), {->foldlevel(v:val)}))
  call assert_equal(2, foldclosed(4))
  call assert_equal(5, foldclosedend(4))

  " Test zO, zC and zA on a line with no folds.
  normal zE
  call assert_fails('normal zO', 'E490:')
  call assert_fails('normal zC', 'E490:')
  call assert_fails('normal zA', 'E490:')

  set fdm&
  bw!
endfunc

" test folding with markers.
func Test_fold_marker()
  new
  set fdm=marker fdl=1 fdc=3

  let content = ['4 dd {{{', '5 ee {{{ }}}', '6 ff }}}']
  call append(0, content)
  call cursor(2, 1)
  call assert_equal(2, foldlevel('.'))
  normal [z
  call assert_equal(1, foldlevel('.'))
  exe "normal jo{{ \<Esc>r{jj"
  call assert_equal(1, foldlevel('.'))
  normal kYpj
  call assert_equal(0, foldlevel('.'))

  " Use only closing fold marker (without and with a count)
  set fdl&
  %d _
  call setline(1, ['one }}}', 'two'])
  call assert_equal([0, 0], [foldlevel(1), foldlevel(2)])
  %d _
  call setline(1, ['one }}}4', 'two'])
  call assert_equal([4, 3], [foldlevel(1), foldlevel(2)])

  set fdm& fdl& fdc&
  bw!
endfunc

" test create fold markers with C filetype
func Test_fold_create_marker_in_C()
  bw!
  set fdm=marker fdl=9
  set filetype=c

  let content =<< trim [CODE]
    /*
     * comment
     *
     *
     */
    int f(int* p) {
        *p = 3;
        return 0;
    }
  [CODE]

  for c in range(len(content) - 1)
    bw!
    call append(0, content)
    call cursor(c + 1, 1)
    norm! zfG
    call assert_equal(content[c] . (c < 4 ? '{{{' : '/* {{{ */'), getline(c + 1))
  endfor

  set fdm& fdl&
  bw!
endfunc

" test folding with indent
func Test_fold_indent()
  new
  set fdm=indent sw=2

  let content = ['1 aa', '2 bb', '3 cc']
  call append(0, content)
  call cursor(2, 1)
  exe "normal i  \<Esc>jI    "
  call assert_equal(2, foldlevel('.'))
  normal k
  call assert_equal(1, foldlevel('.'))

  set fdm& sw&
  bw!
endfunc

" test syntax folding
func Test_fold_syntax()
  CheckFeature syntax

  new
  set fdm=syntax fdl=0

  syn region Hup start="dd" end="ii" fold contains=Fd1,Fd2,Fd3
  syn region Fd1 start="ee" end="ff" fold contained
  syn region Fd2 start="gg" end="hh" fold contained
  syn region Fd3 start="commentstart" end="commentend" fold contained
  let content = ['3 cc', '4 dd {{{', '5 ee {{{ }}}', '{{{{', '6 ff }}}',
	      \ '6 ff }}}', '7 gg', '8 hh', '9 ii']
  call append(0, content)
  normal Gzk
  call assert_equal('9 ii', getline('.'))
  normal k
  call assert_equal('3 cc', getline('.'))
  exe "normal jAcommentstart   \<Esc>Acommentend"
  set fdl=1
  normal 3j
  call assert_equal('7 gg', getline('.'))
  set fdl=0
  exe "normal zO\<C-L>j"
  call assert_equal('8 hh', getline('.'))
  syn clear Fd1 Fd2 Fd3 Hup

  set fdm& fdl&
  bw!
endfunc

func Flvl()
  let l = getline(v:lnum)
  if l =~ "bb$"
    return 2
  elseif l =~ "gg$"
    return "s1"
  elseif l =~ "ii$"
    return ">2"
  elseif l =~ "kk$"
    return "0"
  endif
  return "="
endfun

" test expression folding
func Test_fold_expr()
  new
  set fdm=expr fde=Flvl()

  let content = ['1 aa',
	      \ '2 bb',
	      \ '3 cc',
	      \ '4 dd {{{commentstart  commentend',
	      \ '5 ee {{{ }}}',
	      \ '{{{',
	      \ '6 ff }}}',
	      \ '6 ff }}}',
	      \ '  7 gg',
	      \ '    8 hh',
	      \ '9 ii',
	      \ 'a jj',
	      \ 'b kk']
  call append(0, content)
  call cursor(1, 1)
  exe "normal /bb$\<CR>"
  call assert_equal(2, foldlevel('.'))
  exe "normal /hh$\<CR>"
  call assert_equal(1, foldlevel('.'))
  exe "normal /ii$\<CR>"
  call assert_equal(2, foldlevel('.'))
  exe "normal /kk$\<CR>"
  call assert_equal(0, foldlevel('.'))

  set fdm& fde&
  bw!
endfunc

" Bug with fdm=indent and moving folds
" Moving a fold a few times, messes up the folds below the moved fold.
" Fixed by 7.4.700
func Test_fold_move()
  new
  set fdm=indent sw=2 fdl=0

  let content = ['', '', 'Line1', '  Line2', '  Line3',
	      \ 'Line4', '  Line5', '  Line6',
	      \ 'Line7', '  Line8', '  Line9']
  call append(0, content)
  normal zM
  call cursor(4, 1)
  move 2
  move 1
  call assert_equal(7, foldclosed(7))
  call assert_equal(8, foldclosedend(7))
  call assert_equal(0, foldlevel(9))
  call assert_equal(10, foldclosed(10))
  call assert_equal(11, foldclosedend(10))
  call assert_equal('+--  2 lines: Line2', foldtextresult(2))
  call assert_equal('+--  2 lines: Line8', 10->foldtextresult())

  set fdm& sw& fdl&
  bw!
endfunc

" test for patch 7.3.637
" Cannot catch the error caused by a foldopen when there is no fold.
func Test_foldopen_exception()
  new
  let a = 'No error caught'
  try
    foldopen
  catch
    let a = matchstr(v:exception,'^[^ ]*')
  endtry
  call assert_equal('Vim(foldopen):E490:', a)

  let a = 'No error caught'
  try
    foobar
  catch
    let a = matchstr(v:exception,'^[^ ]*')
  endtry
  call assert_match('E492:', a)
  bw!
endfunc

func Test_fold_last_line_with_pagedown()
  new
  set fdm=manual

  let expect = '+-- 11 lines: 9---'
  let content = range(1,19)
  call append(0, content)
  normal dd9G
  normal zfG
  normal zt
  call assert_equal('9', getline(foldclosed('.')))
  call assert_equal('19', getline(foldclosedend('.')))
  call assert_equal(expect, ScreenLines(1, len(expect))[0])
  call feedkeys("\<C-F>", 'xt')
  call assert_equal(expect, ScreenLines(1, len(expect))[0])
  call feedkeys("\<C-F>", 'xt')
  call assert_equal(expect, ScreenLines(1, len(expect))[0])
  call feedkeys("\<C-B>\<C-F>\<C-F>", 'xt')
  call assert_equal(expect, ScreenLines(1, len(expect))[0])

  set fdm&
  bw!
endfunc

func Test_folds_with_rnu()
  CheckScreendump

  call writefile([
	\ 'set fdm=marker rnu foldcolumn=2',
	\ 'call setline(1, ["{{{1", "nline 1", "{{{1", "line 2"])',
	\ ], 'Xtest_folds_with_rnu')
  let buf = RunVimInTerminal('-S Xtest_folds_with_rnu', {})

  call VerifyScreenDump(buf, 'Test_folds_with_rnu_01', {})
  call term_sendkeys(buf, "j")
  call VerifyScreenDump(buf, 'Test_folds_with_rnu_02', {})

  " clean up
  call StopVimInTerminal(buf)
  call delete('Xtest_folds_with_rnu')
endfunc

func Test_folds_marker_in_comment2()
  new
  call setline(1, ['Lorem ipsum dolor sit', 'Lorem ipsum dolor sit', 'Lorem ipsum dolor sit'])
  setl fen fdm=marker
  setl commentstring=<!--%s-->
  setl comments=s:<!--,m:\ \ \ \ ,e:-->
  norm! zf2j
  setl nofen
  :1y
  call assert_equal(['Lorem ipsum dolor sit<!--{{{-->'], getreg(0,1,1))
  :+2y
  call assert_equal(['Lorem ipsum dolor sit<!--}}}-->'], getreg(0,1,1))

  set foldmethod&
  bwipe!
endfunc

func Test_fold_delete_with_marker()
  new
  call setline(1, ['func Func() {{{1', 'endfunc'])
  1,2yank
  new
  set fdm=marker
  call setline(1, 'x')
  normal! Vp
  normal! zd
  call assert_equal(['func Func() ', 'endfunc'], getline(1, '$'))

  set fdm&
  bwipe!
  bwipe!
endfunc

func Test_fold_delete_with_marker_and_whichwrap()
  new
  let content1 = ['']
  let content2 = ['folded line 1 "{{{1', '  test', '  test2', '  test3', '', 'folded line 2 "{{{1', '  test', '  test2', '  test3']
  call setline(1, content1 + content2)
  set fdm=marker ww+=l
  normal! x
  call assert_equal(content2, getline(1, '$'))
  set fdm& ww&
  bwipe!
endfunc

func Test_fold_delete_first_line()
  new
  call setline(1, [
	\ '" x {{{1',
	\ '" a',
	\ '" aa',
	\ '" x {{{1',
	\ '" b',
	\ '" bb',
	\ '" x {{{1',
	\ '" c',
	\ '" cc',
	\ ])
  set foldmethod=marker
  1
  normal dj
  call assert_equal([
	\ '" x {{{1',
	\ '" c',
	\ '" cc',
	\ ], getline(1,'$'))
  bwipe!
  set foldmethod&
endfunc

" Add a test for deleting the outer fold of a nested fold and promoting the
" inner folds to one level up with already a fold at that level following the
" nested fold.
func Test_fold_delete_recursive_fold()
  new
  call setline(1, range(1, 7))
  2,3fold
  normal zR
  4,5fold
  normal zR
  1,5fold
  normal zR
  6,7fold
  normal zR
  normal 1Gzd
  normal 1Gzj
  call assert_equal(2, line('.'))
  normal zj
  call assert_equal(4, line('.'))
  normal zj
  call assert_equal(6, line('.'))
  bw!
endfunc

" Test for errors in 'foldexpr'
func Test_fold_expr_error()
  new
  call setline(1, ['one', 'two', 'three'])
  " In a window with no folds, foldlevel() should return 0
  call assert_equal(0, foldlevel(1))

  " Return a list from the expression
  set foldexpr=[]
  set foldmethod=expr
  for i in range(3)
    call assert_equal(0, foldlevel(i))
  endfor

  " expression error
  set foldexpr=[{]
  set foldmethod=expr
  for i in range(3)
    call assert_equal(0, foldlevel(i))
  endfor

  set foldmethod& foldexpr&
  close!
endfunc

func Test_undo_fold_deletion()
  new
  set fdm=marker
  let lines =<< trim END
      " {{{
      " }}}1
      " {{{
  END
  call setline(1, lines)
  3d
  g/"/d
  undo
  redo
  eval getline(1, '$')->assert_equal([''])

  set fdm&vim
  bwipe!
endfunc

" this was crashing
func Test_move_no_folds()
  new
  fold
  setlocal fdm=expr
  normal zj
  bwipe!
endfunc

" this was crashing
func Test_fold_create_delete_create()
  new
  fold
  fold
  normal zd
  fold
  bwipe!
endfunc

" this was crashing
func Test_fold_create_delete()
  new
  norm zFzFzdzj
  bwipe!
endfunc

func Test_fold_relative_move()
  new
  set fdm=indent sw=2 wrap tw=80

  let longtext = repeat('x', &columns + 1)
  let content = [ '  foo', '  ' .. longtext, '  baz',
              \   longtext,
              \   '  foo', '  ' .. longtext, '  baz'
              \ ]
  call append(0, content)

  normal zM

  for lnum in range(1, 3)
    call cursor(lnum, 1)
    call assert_true(foldclosed(line('.')))
    normal gj
    call assert_equal(2, winline())
  endfor

  call cursor(2, 1)
  call assert_true(foldclosed(line('.')))
  normal 2gj
  call assert_equal(3, winline())

  for lnum in range(5, 7)
    call cursor(lnum, 1)
    call assert_true(foldclosed(line('.')))
    normal gk
    call assert_equal(3, winline())
  endfor

  call cursor(6, 1)
  call assert_true(foldclosed(line('.')))
  normal 2gk
  call assert_equal(2, winline())

  set fdm& sw& wrap& tw&
  bw!
endfunc

" Test for calling foldlevel() from a fold expression
let g:FoldLevels = []
func FoldExpr1(lnum)
  let f = [a:lnum]
  for i in range(1, line('$'))
    call add(f, foldlevel(i))
  endfor
  call add(g:FoldLevels, f)
  return getline(a:lnum)[0] == "\t"
endfunc

func Test_foldexpr_foldlevel()
  new
  call setline(1, ['one', "\ttwo", "\tthree"])
  setlocal foldmethod=expr
  setlocal foldexpr=FoldExpr1(v:lnum)
  setlocal foldenable
  setlocal foldcolumn=3
  redraw!
  call assert_equal([[1, -1, -1, -1], [2, -1, -1, -1], [3, 0, 1, -1]],
        \ g:FoldLevels)
  set foldmethod& foldexpr& foldenable& foldcolumn&
  bw!
endfunc

" Test for returning different values from a fold expression
func FoldExpr2(lnum)
  if a:lnum == 1 || a:lnum == 4
    return -2
  elseif a:lnum == 2
    return 'a1'
  elseif a:lnum == 3
    return 's4'
  endif
  return '='
endfunc

func Test_foldexpr_2()
  new
  call setline(1, ['one', 'two', 'three', 'four'])
  setlocal foldexpr=FoldExpr2(v:lnum)
  setlocal foldmethod=expr
  call assert_equal([0, 1, 1, 0], [foldlevel(1), foldlevel(2), foldlevel(3),
        \ foldlevel(4)])
  bw!
endfunc

" Test for the 'foldclose' option
func Test_foldclose_opt()
  CheckScreendump

  let lines =<< trim END
    set foldmethod=manual foldclose=all foldopen=all
    call setline(1, ['one', 'two', 'three', 'four'])
    2,3fold
    func XsaveFoldLevels()
      redraw!
      call writefile([json_encode([foldclosed(1), foldclosed(2), foldclosed(3),
        \ foldclosed(4)])], 'Xoutput', 'a')
    endfunc
  END
  call writefile(lines, 'Xscript')
  let rows = 10
  let buf = RunVimInTerminal('-S Xscript', {'rows': rows})
  call term_wait(buf)
  call term_sendkeys(buf, ":set noruler\n")
  call term_wait(buf)
  call term_sendkeys(buf, ":call XsaveFoldLevels()\n")
  call term_sendkeys(buf, "2G")
  call WaitForAssert({-> assert_equal('two', term_getline(buf, 2))})
  call term_sendkeys(buf, ":call XsaveFoldLevels()\n")
  call term_sendkeys(buf, "4G")
  call WaitForAssert({-> assert_equal('four', term_getline(buf, 3))})
  call term_sendkeys(buf, ":call XsaveFoldLevels()\n")
  call term_sendkeys(buf, "3G")
  call WaitForAssert({-> assert_equal('three', term_getline(buf, 3))})
  call term_sendkeys(buf, ":call XsaveFoldLevels()\n")
  call term_sendkeys(buf, "1G")
  call WaitForAssert({-> assert_equal('four', term_getline(buf, 3))})
  call term_sendkeys(buf, ":call XsaveFoldLevels()\n")
  call term_sendkeys(buf, "2G")
  call WaitForAssert({-> assert_equal('two', term_getline(buf, 2))})
  call term_sendkeys(buf, "k")
  call WaitForAssert({-> assert_equal('four', term_getline(buf, 3))})

  " clean up
  call StopVimInTerminal(buf)

  call assert_equal(['[-1,2,2,-1]', '[-1,-1,-1,-1]', '[-1,2,2,-1]',
        \ '[-1,-1,-1,-1]', '[-1,2,2,-1]'], readfile('Xoutput'))
  call delete('Xscript')
  call delete('Xoutput')
endfunc

" Test for foldtextresult()
func Test_foldtextresult()
  new
  call assert_equal('', foldtextresult(-1))
  call assert_equal('', foldtextresult(0))
  call assert_equal('', foldtextresult(1))
  call setline(1, ['one', 'two', 'three', 'four'])
  2,3fold
  call assert_equal('', foldtextresult(1))
  call assert_equal('+--  2 lines: two', foldtextresult(2))
  setlocal foldtext=
  call assert_equal('+--  2 lines folded ', foldtextresult(2))

  " Fold text for a C comment fold
  %d _
  setlocal foldtext&
  call setline(1, ['', '/*', ' * Comment', ' */', ''])
  2,4fold
  call assert_equal('+--  3 lines: Comment', foldtextresult(2))

  bw!
endfunc

" Test for merging two recursive folds when an intermediate line with no fold
" is removed
func Test_fold_merge_recursive()
  new
  call setline(1, ['  one', '    two', 'xxxx', '    three',
        \ '      four', "\tfive"])
  setlocal foldmethod=indent shiftwidth=2
  3d_
  %foldclose
  call assert_equal([1, 5], [foldclosed(5), foldclosedend(1)])
  bw!
endfunc

" Test for moving a line which is the start of a fold from a recursive fold to
" outside. The fold length should reduce.
func Test_fold_move_foldlevel()
  new
  call setline(1, ['a{{{', 'b{{{', 'c{{{', 'd}}}', 'e}}}', 'f}}}', 'g'])
  setlocal foldmethod=marker
  normal zR
  call assert_equal([3, 2, 1], [foldlevel(4), foldlevel(5), foldlevel(6)])
  3move 7
  call assert_equal([2, 1, 0], [foldlevel(3), foldlevel(4), foldlevel(5)])
  call assert_equal(1, foldlevel(7))

  " Move a line from outside a fold to inside the fold.
  %d _
  call setline(1, ['a', 'b{{{', 'c}}}'])
  normal zR
  1move 2
  call assert_equal([1, 1, 1], [foldlevel(1), foldlevel(2), foldlevel(3)])

  " Move the start of one fold to inside another fold
  %d _
  call setline(1, ['a', 'b{{{', 'c}}}', 'd{{{', 'e}}}'])
  normal zR
  call assert_equal([0, 1, 1, 1, 1], [foldlevel(1), foldlevel(2),
        \ foldlevel(3), foldlevel(4), foldlevel(5)])
  1,2move 4
  call assert_equal([0, 1, 1, 2, 2], [foldlevel(1), foldlevel(2),
        \ foldlevel(3), foldlevel(4), foldlevel(5)])

  bw!
endfunc

" Test for using zj and zk to move downwards and upwards to the start and end
" of the next fold.
" Test for using [z and ]z in a closed fold to jump to the beginning and end
" of the fold.
func Test_fold_jump()
  new
  call setline(1, ["\t1", "\t2", "\t\t3", "\t\t4", "\t\t\t5", "\t\t\t6", "\t\t7", "\t\t8", "\t9", "\t10"])
  setlocal foldmethod=indent
  normal zR
  normal zj
  call assert_equal(3, line('.'))
  normal zj
  call assert_equal(5, line('.'))
  call assert_beeps('normal zj')
  call assert_equal(5, line('.'))
  call assert_beeps('normal 9Gzj')
  call assert_equal(9, line('.'))
  normal Gzk
  call assert_equal(8, line('.'))
  normal zk
  call assert_equal(6, line('.'))
  call assert_beeps('normal zk')
  call assert_equal(6, line('.'))
  call assert_beeps('normal 2Gzk')
  call assert_equal(2, line('.'))

  " Using [z or ]z in a closed fold should not move the cursor
  %d _
  call setline(1, ["1", "\t2", "\t3", "\t4", "\t5", "\t6", "7"])
  normal zR4Gzc
  call assert_equal(4, line('.'))
  call assert_beeps('normal [z')
  call assert_equal(4, line('.'))
  call assert_beeps('normal ]z')
  call assert_equal(4, line('.'))
  bw!
endfunc

" Test for using a script-local function for 'foldexpr'
func Test_foldexpr_scriptlocal_func()
  func! s:FoldFunc()
    let g:FoldLnum = v:lnum
  endfunc
  new | only
  call setline(1, 'abc')
  let g:FoldLnum = 0
  set foldmethod=expr foldexpr=s:FoldFunc()
  redraw!
  call assert_equal(expand('<SID>') .. 'FoldFunc()', &foldexpr)
  call assert_equal(expand('<SID>') .. 'FoldFunc()', &g:foldexpr)
  call assert_equal(1, g:FoldLnum)
  set foldmethod& foldexpr=
  bw!
  new | only
  call setline(1, 'abc')
  let g:FoldLnum = 0
  set foldmethod=expr foldexpr=<SID>FoldFunc()
  redraw!
  call assert_equal(expand('<SID>') .. 'FoldFunc()', &foldexpr)
  call assert_equal(expand('<SID>') .. 'FoldFunc()', &g:foldexpr)
  call assert_equal(1, g:FoldLnum)
  bw!
  call setline(1, 'abc')
  setlocal foldmethod& foldexpr&
  setglobal foldmethod=expr foldexpr=s:FoldFunc()
  call assert_equal(expand('<SID>') .. 'FoldFunc()', &g:foldexpr)
  call assert_equal('0', &foldexpr)
  enew!
  call setline(1, 'abc')
  redraw!
  call assert_equal(expand('<SID>') .. 'FoldFunc()', &foldexpr)
  call assert_equal(1, g:FoldLnum)
  bw!
  call setline(1, 'abc')
  setlocal foldmethod& foldexpr&
  setglobal foldmethod=expr foldexpr=<SID>FoldFunc()
  call assert_equal(expand('<SID>') .. 'FoldFunc()', &g:foldexpr)
  call assert_equal('0', &foldexpr)
  enew!
  call setline(1, 'abc')
  redraw!
  call assert_equal(expand('<SID>') .. 'FoldFunc()', &foldexpr)
  call assert_equal(1, g:FoldLnum)
  set foldmethod& foldexpr&
  delfunc s:FoldFunc
  bw!
endfunc

" Test for using a script-local function for 'foldtext'
func Test_foldtext_scriptlocal_func()
  func! s:FoldText()
    let g:FoldTextArgs = [v:foldstart, v:foldend]
    return foldtext()
  endfunc
  new | only
  call setline(1, range(50))
  let g:FoldTextArgs = []
  set foldtext=s:FoldText()
  norm! 4Gzf4j
  redraw!
  call assert_equal(expand('<SID>') .. 'FoldText()', &foldtext)
  call assert_equal(expand('<SID>') .. 'FoldText()', &g:foldtext)
  call assert_equal([4, 8], g:FoldTextArgs)
  set foldtext&
  bw!
  new | only
  call setline(1, range(50))
  let g:FoldTextArgs = []
  set foldtext=<SID>FoldText()
  norm! 8Gzf4j
  redraw!
  call assert_equal(expand('<SID>') .. 'FoldText()', &foldtext)
  call assert_equal(expand('<SID>') .. 'FoldText()', &g:foldtext)
  call assert_equal([8, 12], g:FoldTextArgs)
  set foldtext&
  bw!
  call setline(1, range(50))
  let g:FoldTextArgs = []
  setlocal foldtext&
  setglobal foldtext=s:FoldText()
  call assert_equal(expand('<SID>') .. 'FoldText()', &g:foldtext)
  call assert_equal('foldtext()', &foldtext)
  enew!
  call setline(1, range(50))
  norm! 12Gzf4j
  redraw!
  call assert_equal(expand('<SID>') .. 'FoldText()', &foldtext)
  call assert_equal([12, 16], g:FoldTextArgs)
  set foldtext&
  bw!
  call setline(1, range(50))
  let g:FoldTextArgs = []
  setlocal foldtext&
  setglobal foldtext=<SID>FoldText()
  call assert_equal(expand('<SID>') .. 'FoldText()', &g:foldtext)
  call assert_equal('foldtext()', &foldtext)
  enew!
  call setline(1, range(50))
  norm! 16Gzf4j
  redraw!
  call assert_equal(expand('<SID>') .. 'FoldText()', &foldtext)
  call assert_equal([16, 20], g:FoldTextArgs)
  set foldtext&
  bw!
  delfunc s:FoldText
endfunc

" Make sure a fold containing a nested fold is split correctly when using
" foldmethod=indent
func Test_fold_split()
  new
  let lines =<< trim END
    line 1
      line 2
      line 3
        line 4
        line 5
  END
  call setline(1, lines)
  setlocal sw=2
  setlocal foldmethod=indent foldenable
  call assert_equal([0, 1, 1, 2, 2], range(1, 5)->map('foldlevel(v:val)'))
  call append(2, 'line 2.5')
  call assert_equal([0, 1, 0, 1, 2, 2], range(1, 6)->map('foldlevel(v:val)'))
  3d
  call assert_equal([0, 1, 1, 2, 2], range(1, 5)->map('foldlevel(v:val)'))
  bw!
endfunc

" Make sure that when you append under a blank line that is under a fold with
" the same indent level as your appended line, the fold expands across the
" blank line
func Test_indent_append_under_blank_line()
  new
  let lines =<< trim END
    line 1
      line 2
      line 3
  END
  call setline(1, lines)
  setlocal sw=2
  setlocal foldmethod=indent foldenable
  call assert_equal([0, 1, 1], range(1, 3)->map('foldlevel(v:val)'))
  call append(3, '')
  call append(4, '  line 5')
  call assert_equal([0, 1, 1, 1, 1], range(1, 5)->map('foldlevel(v:val)'))
  bw!
endfunc

" Make sure that when you delete 1 line of a fold whose length is 2 lines, the
" fold can't be closed since its length (1) is now less than foldminlines.
func Test_indent_one_line_fold_close()
  let lines =<< trim END
    line 1
      line 2
      line 3
  END

  new
  setlocal sw=2 foldmethod=indent
  call setline(1, lines)
  " open all folds, delete line, then close all folds
  normal zR
  3delete
  normal zM
  call assert_equal(-1, foldclosed(2)) " the fold should not be closed

  " Now do the same, but delete line 2 this time; this covers different code.
  " (Combining this code with the above code doesn't expose both bugs.)
  1,$delete
  call setline(1, lines)
  normal zR
  2delete
  normal zM
  call assert_equal(-1, foldclosed(2))
  bw!
endfunc

" Make sure that when appending [an indented line then a blank line] right
" before a single indented line, the resulting extended fold can be closed
func Test_indent_append_blank_small_fold_close()
  new
  setlocal sw=2 foldmethod=indent
  " at first, the fold at the second line can't be closed since it's smaller
  " than foldminlines
  let lines =<< trim END
    line 1
      line 4
  END
  call setline(1, lines)
  call append(1, ['  line 2', ''])
  " close all folds
  normal zM
  call assert_notequal(-1, foldclosed(2)) " the fold should be closed now
  bw!
endfunc

func Test_sort_closed_fold()
  CheckExecutable sort

  call setline(1, [
        \ 'Section 1',
        \ '   how',
        \ '   now',
        \ '   brown',
        \ '   cow',
        \ 'Section 2',
        \ '   how',
        \ '   now',
        \ '   brown',
        \ '   cow',
        \])
  setlocal foldmethod=indent sw=3
  normal 2G

  " The "!!" expands to ".,.+3" and must only sort four lines
  call feedkeys("!!sort\<CR>", 'xt')
  call assert_equal([
        \ 'Section 1',
        \ '   brown',
        \ '   cow',
        \ '   how',
        \ '   now',
        \ 'Section 2',
        \ '   how',
        \ '   now',
        \ '   brown',
        \ '   cow',
        \ ], getline(1, 10))

  bwipe!
endfunc

func Test_indent_with_L_command()
  " The "L" command moved the cursor to line zero, causing the text saved for
  " undo to use line number -1, which caused trouble for undo later.
  new
  sil! norm 8RV{zf8=Lu
  bwipe!
endfunc

" Make sure that when there is a fold at the bottom of the buffer and a newline
" character is appended to the line, the fold gets expanded (instead of the new
" line not being part of the fold).
func Test_expand_fold_at_bottom_of_buffer()
  new
  " create a fold on the only line
  fold
  execute "normal A\<CR>"
  call assert_equal([1, 1], range(1, 2)->map('foldlevel(v:val)'))

  bwipe!
endfunc

func Test_fold_screenrow_motion()
  call setline(1, repeat(['aaaa'], 5))
  1,4fold
  norm Ggkzo
  call assert_equal(1, line('.'))
endfunc

" This was using freed memory
func Test_foldcolumn_linebreak_control_char()
  CheckFeature linebreak

  5vnew
  setlocal foldcolumn=1 linebreak
  call setline(1, "aaa\<C-A>b")
  redraw
  call assert_equal([' aaa^', ' Ab  '], ScreenLines([1, 2], 5))
  call assert_equal(screenattr(1, 5), screenattr(2, 2))

  bwipe!
endfunc

" This used to cause invalid memory access
func Test_foldexpr_return_empty_string()
  new
  setlocal foldexpr='' foldmethod=expr
  redraw

  bwipe!
endfunc

" Make sure that when ending a fold that hasn't been started, it does not
" start a new fold.
func Test_foldexpr_end_fold()
  new
  setlocal foldmethod=expr
  let &l:foldexpr = 'v:lnum == 2 ? "<2" : "="'
  call setline(1, range(1, 3))
  redraw
  call assert_equal([0, 0, 0], range(1, 3)->map('foldlevel(v:val)'))

  bwipe!
endfunc

" Test moving cursor down to or beyond start of folded end of buffer.
func Test_cursor_down_fold_eob()
  call setline(1, range(1, 4))
  norm Gzf2kj
  call assert_equal(2, line('.'))
  norm zojzc
  call assert_equal(3, line('.'))
  norm j
  call assert_equal(3, line('.'))
  norm k2j
  call assert_equal(4, line('.'))
  bwipe!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
