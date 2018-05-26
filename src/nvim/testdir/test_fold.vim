" Test for folding

func! PrepIndent(arg)
  return [a:arg] + repeat(["\t".a:arg], 5)
endfu

func! Test_address_fold()
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

func! Test_indent_fold()
    new
    call setline(1, ['', 'a', '    b', '    c'])
    setl fen fdm=indent
    2
    norm! >>
    let a=map(range(1,4), 'foldclosed(v:val)')
    call assert_equal([-1,-1,-1,-1], a)
endfunc

func! Test_indent_fold()
    new
    call setline(1, ['', 'a', '    b', '    c'])
    setl fen fdm=indent
    2
    norm! >>
    let a=map(range(1,4), 'foldclosed(v:val)')
    call assert_equal([-1,-1,-1,-1], a)
    bw!
endfunc

func! Test_indent_fold2()
    new
    call setline(1, ['', '{{{', '}}}', '{{{', '}}}'])
    setl fen fdm=marker
    2
    norm! >>
    let a=map(range(1,5), 'foldclosed(v:val)')
    call assert_equal([-1,-1,-1,4,4], a)
    bw!
endfunc

func Test_manual_fold_with_filter()
  if !executable('cat')
    return
  endif
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

func! Test_indent_fold_with_read()
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
  call assert_equal(7, foldclosedend(5))

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
  call assert_equal(0, foldlevel(4))
  call assert_equal(6, foldclosedend(5))
  call assert_equal(10, foldclosedend(7))
  call assert_equal(14, foldclosedend(11))

  call delete('Xfile')
  bwipe!
  set foldmethod& foldexpr&
endfunc

func! Test_move_folds_around_manual()
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
  call assert_equal([0, 1, 1, 1, 1, 0, 0, 0, 1, 0], map(range(1, line('$')), 'foldlevel(v:val)'))
  bw!
endfunc

func! Test_move_folds_around_indent()
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
  call assert_equal([0, 1, 1, 1, 1, 0, 0, 0, 1, 1], map(range(1, line('$')), 'foldlevel(v:val)'))
  bw!
endfunc

" test for patch 7.3.637
" Cannot catch the error caused by a foldopen when there is no fold.
func Test_foldopen_exception()
  enew!
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
