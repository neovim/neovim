" Test for various Normal mode commands

source shared.vim
source check.vim
source view_util.vim
source vim9.vim
source screendump.vim

func Setup_NewWindow()
  10new
  call setline(1, range(1,100))
endfunc

func MyFormatExpr()
  " Adds '->$' at lines having numbers followed by trailing whitespace
  for ln in range(v:lnum, v:lnum+v:count-1)
    let line = getline(ln)
    if getline(ln) =~# '\d\s\+$'
      call setline(ln, substitute(line, '\s\+$', '', '') . '->$')
    endif
  endfor
endfunc

func CountSpaces(type, ...)
  " for testing operatorfunc
  " will count the number of spaces
  " and return the result in g:a
  let sel_save = &selection
  let &selection = "inclusive"
  let reg_save = @@

  if a:0  " Invoked from Visual mode, use gv command.
    silent exe "normal! gvy"
  elseif a:type == 'line'
    silent exe "normal! '[V']y"
  else
    silent exe "normal! `[v`]y"
  endif
  let g:a = strlen(substitute(@@, '[^ ]', '', 'g'))
  let &selection = sel_save
  let @@ = reg_save
endfunc

func OpfuncDummy(type, ...)
  " for testing operatorfunc
  let g:opt = &linebreak

  if a:0  " Invoked from Visual mode, use gv command.
    silent exe "normal! gvy"
  elseif a:type == 'line'
    silent exe "normal! '[V']y"
  else
    silent exe "normal! `[v`]y"
  endif
  " Create a new dummy window
  new
  let g:bufnr = bufnr('%')
endfunc

func Test_normal00_optrans()
  new
  call append(0, ['1 This is a simple test: abcd', '2 This is the second line', '3 this is the third line'])
  1
  exe "norm! Sfoobar\<esc>"
  call assert_equal(['foobar', '2 This is the second line', '3 this is the third line', ''], getline(1,'$'))
  2
  exe "norm! $vbsone"
  call assert_equal(['foobar', '2 This is the second one', '3 this is the third line', ''], getline(1,'$'))
  norm! VS Second line here
  call assert_equal(['foobar', ' Second line here', '3 this is the third line', ''], getline(1, '$'))
  %d
  call append(0, ['4 This is a simple test: abcd', '5 This is the second line', '6 this is the third line'])
  call append(0, ['1 This is a simple test: abcd', '2 This is the second line', '3 this is the third line'])

  1
  norm! 2D
  call assert_equal(['3 this is the third line', '4 This is a simple test: abcd', '5 This is the second line', '6 this is the third line', ''], getline(1,'$'))
  " Nvim: no "#" flag in 'cpoptions'.
  " set cpo+=#
  " norm! 4D
  " call assert_equal(['', '4 This is a simple test: abcd', '5 This is the second line', '6 this is the third line', ''], getline(1,'$'))

  " clean up
  set cpo-=#
  bw!
endfunc

func Test_normal01_keymodel()
  call Setup_NewWindow()
  " Test 1: depending on 'keymodel' <s-down> does something different
  50
  call feedkeys("V\<S-Up>y", 'tx')
  call assert_equal(['47', '48', '49', '50'], getline("'<", "'>"))
  set keymodel=startsel
  50
  call feedkeys("V\<S-Up>y", 'tx')
  call assert_equal(['49', '50'], getline("'<", "'>"))
  " Start visual mode when keymodel = startsel
  50
  call feedkeys("\<S-Up>y", 'tx')
  call assert_equal(['49', '5'], getreg(0, 0, 1))
  " Use the different Shift special keys
  50
  call feedkeys("\<S-Right>\<S-Left>\<S-Up>\<S-Down>\<S-Home>\<S-End>y", 'tx')
  call assert_equal(['50'], getline("'<", "'>"))
  call assert_equal(['50', ''], getreg(0, 0, 1))

  " Do not start visual mode when keymodel=
  set keymodel=
  50
  call feedkeys("\<S-Up>y$", 'tx')
  call assert_equal(['42'], getreg(0, 0, 1))
  " Stop visual mode when keymodel=stopsel
  set keymodel=stopsel
  50
  call feedkeys("Vkk\<Up>yy", 'tx')
  call assert_equal(['47'], getreg(0, 0, 1))

  set keymodel=
  50
  call feedkeys("Vkk\<Up>yy", 'tx')
  call assert_equal(['47', '48', '49', '50'], getreg(0, 0, 1))

  " Test for using special keys to start visual selection
  %d
  call setline(1, ['red fox tail', 'red fox tail', 'red fox tail'])
  set keymodel=startsel
  " Test for <S-PageUp> and <S-PageDown>
  call cursor(1, 1)
  call feedkeys("\<S-PageDown>y", 'xt')
  call assert_equal([0, 1, 1, 0], getpos("'<"))
  call assert_equal([0, 3, 1, 0], getpos("'>"))
  call feedkeys("Gz\<CR>8|\<S-PageUp>y", 'xt')
  call assert_equal([0, 3, 1, 0], getpos("'<"))
  call assert_equal([0, 3, 8, 0], getpos("'>"))
  " Test for <S-C-Home> and <S-C-End>
  call cursor(2, 12)
  call feedkeys("\<S-C-Home>y", 'xt')
  call assert_equal([0, 1, 1, 0], getpos("'<"))
  call assert_equal([0, 2, 12, 0], getpos("'>"))
  call cursor(1, 4)
  call feedkeys("\<S-C-End>y", 'xt')
  call assert_equal([0, 1, 4, 0], getpos("'<"))
  call assert_equal([0, 3, 13, 0], getpos("'>"))
  " Test for <S-C-Left> and <S-C-Right>
  call cursor(2, 5)
  call feedkeys("\<S-C-Right>y", 'xt')
  call assert_equal([0, 2, 5, 0], getpos("'<"))
  call assert_equal([0, 2, 9, 0], getpos("'>"))
  call cursor(2, 9)
  call feedkeys("\<S-C-Left>y", 'xt')
  call assert_equal([0, 2, 5, 0], getpos("'<"))
  call assert_equal([0, 2, 9, 0], getpos("'>"))

  set keymodel&

  " clean up
  bw!
endfunc

func Test_normal03_join()
  " basic join test
  call Setup_NewWindow()
  50
  norm! VJ
  call assert_equal('50 51', getline('.'))
  $
  norm! J
  call assert_equal('100', getline('.'))
  $
  norm! V9-gJ
  call assert_equal('919293949596979899100', getline('.'))
  call setline(1, range(1,100))
  $
  :j 10
  call assert_equal('100', getline('.'))
  call assert_beeps('normal GVJ')
  " clean up
  bw!
endfunc

" basic filter test
func Test_normal04_filter()
  " only test on non windows platform
  CheckNotMSWindows
  call Setup_NewWindow()
  1
  call feedkeys("!!sed -e 's/^/|    /'\n", 'tx')
  call assert_equal('|    1', getline('.'))
  90
  :sil :!echo one
  call feedkeys('.', 'tx')
  call assert_equal('|    90', getline('.'))
  95
  set cpo+=!
  " 2 <CR>, 1: for executing the command,
  "         2: clear hit-enter-prompt
  call feedkeys("!!\n", 'tx')
  call feedkeys(":!echo one\n\n", 'tx')
  call feedkeys(".", 'tx')
  call assert_equal('one', getline('.'))
  set cpo-=!
  bw!
endfunc

func Test_normal05_formatexpr()
  " basic formatexpr test
  call Setup_NewWindow()
  %d_
  call setline(1, ['here: 1   ', '2', 'here: 3   ', '4', 'not here:   '])
  1
  set formatexpr=MyFormatExpr()
  norm! gqG
  call assert_equal(['here: 1->$', '2', 'here: 3->$', '4', 'not here:   '], getline(1,'$'))
  set formatexpr=
  bw!
endfunc

func Test_normal05_formatexpr_newbuf()
  " Edit another buffer in the 'formatexpr' function
  new
  func! Format()
    edit another
  endfunc
  set formatexpr=Format()
  norm gqG
  bw!
  set formatexpr=
endfunc

func Test_normal05_formatexpr_setopt()
  " Change the 'formatexpr' value in the function
  new
  func! Format()
    set formatexpr=
  endfunc
  set formatexpr=Format()
  norm gqG
  bw!
  set formatexpr=
endfunc

" When 'formatexpr' returns non-zero, internal formatting is used.
func Test_normal_formatexpr_returns_nonzero()
  new
  call setline(1, ['one', 'two'])
  func! Format()
    return 1
  endfunc
  setlocal formatexpr=Format()
  normal VGgq
  call assert_equal(['one two'], getline(1, '$'))

  setlocal formatexpr=
  delfunc Format
  bwipe!
endfunc

" Test for using a script-local function for 'formatexpr'
func Test_formatexpr_scriptlocal_func()
  func! s:Format()
    let g:FormatArgs = [v:lnum, v:count]
  endfunc
  set formatexpr=s:Format()
  call assert_equal(expand('<SID>') .. 'Format()', &formatexpr)
  call assert_equal(expand('<SID>') .. 'Format()', &g:formatexpr)
  new | only
  call setline(1, range(1, 40))
  let g:FormatArgs = []
  normal! 2GVjgq
  call assert_equal([2, 2], g:FormatArgs)
  bw!
  set formatexpr=<SID>Format()
  call assert_equal(expand('<SID>') .. 'Format()', &formatexpr)
  call assert_equal(expand('<SID>') .. 'Format()', &g:formatexpr)
  new | only
  call setline(1, range(1, 40))
  let g:FormatArgs = []
  normal! 4GVjgq
  call assert_equal([4, 2], g:FormatArgs)
  bw!
  let &formatexpr = 's:Format()'
  call assert_equal(expand('<SID>') .. 'Format()', &g:formatexpr)
  new | only
  call setline(1, range(1, 40))
  let g:FormatArgs = []
  normal! 6GVjgq
  call assert_equal([6, 2], g:FormatArgs)
  bw!
  let &formatexpr = '<SID>Format()'
  call assert_equal(expand('<SID>') .. 'Format()', &g:formatexpr)
  new | only
  call setline(1, range(1, 40))
  let g:FormatArgs = []
  normal! 8GVjgq
  call assert_equal([8, 2], g:FormatArgs)
  bw!
  setlocal formatexpr=
  setglobal formatexpr=s:Format()
  call assert_equal(expand('<SID>') .. 'Format()', &g:formatexpr)
  call assert_equal('', &formatexpr)
  new
  call assert_equal(expand('<SID>') .. 'Format()', &formatexpr)
  call setline(1, range(1, 40))
  let g:FormatArgs = []
  normal! 10GVjgq
  call assert_equal([10, 2], g:FormatArgs)
  bw!
  setglobal formatexpr=<SID>Format()
  call assert_equal(expand('<SID>') .. 'Format()', &g:formatexpr)
  call assert_equal('', &formatexpr)
  new
  call assert_equal(expand('<SID>') .. 'Format()', &formatexpr)
  call setline(1, range(1, 40))
  let g:FormatArgs = []
  normal! 12GVjgq
  call assert_equal([12, 2], g:FormatArgs)
  bw!
  let &g:formatexpr = 's:Format()'
  call assert_equal(expand('<SID>') .. 'Format()', &g:formatexpr)
  call assert_equal('', &formatexpr)
  new
  call assert_equal(expand('<SID>') .. 'Format()', &formatexpr)
  call setline(1, range(1, 40))
  let g:FormatArgs = []
  normal! 14GVjgq
  call assert_equal([14, 2], g:FormatArgs)
  bw!
  let &g:formatexpr = '<SID>Format()'
  call assert_equal(expand('<SID>') .. 'Format()', &g:formatexpr)
  call assert_equal('', &formatexpr)
  new
  call assert_equal(expand('<SID>') .. 'Format()', &formatexpr)
  call setline(1, range(1, 40))
  let g:FormatArgs = []
  normal! 16GVjgq
  call assert_equal([16, 2], g:FormatArgs)
  bw!
  set formatexpr=
  delfunc s:Format
  bw!
endfunc

" basic test for formatprg
func Test_normal06_formatprg()
  " only test on non windows platform
  CheckNotMSWindows

  " uses sed to number non-empty lines
  call writefile(['#!/bin/sh', 'sed ''/./=''|sed ''/./{', 'N', 's/\n/    /', '}'''], 'Xsed_format.sh', 'D')
  call system('chmod +x ./Xsed_format.sh')
  let text = ['a', '', 'c', '', ' ', 'd', 'e']
  let expected = ['1    a', '', '3    c', '', '5     ', '6    d', '7    e']

  10new
  call setline(1, text)
  set formatprg=./Xsed_format.sh
  norm! gggqG
  call assert_equal(expected, getline(1, '$'))
  %d

  call setline(1, text)
  set formatprg=donothing
  setlocal formatprg=./Xsed_format.sh
  norm! gggqG
  call assert_equal(expected, getline(1, '$'))
  %d

  " Check for the command-line ranges added to 'formatprg'
  set formatprg=cat
  call setline(1, ['one', 'two', 'three', 'four', 'five'])
  call feedkeys('gggqG', 'xt')
  call assert_equal('.,$!cat', @:)
  call feedkeys('2Ggq2j', 'xt')
  call assert_equal('.,.+2!cat', @:)

  bw!
  " clean up
  set formatprg=
  setlocal formatprg=
endfunc

func Test_normal07_internalfmt()
  " basic test for internal formatter to textwidth of 12
  let list=range(1,11)
  call map(list, 'v:val."    "')
  10new
  call setline(1, list)
  set tw=12
  norm! ggVGgq
  call assert_equal(['1    2    3', '4    5    6', '7    8    9', '10    11    '], getline(1, '$'))
  " clean up
  set tw=0
  bw!
endfunc

" basic tests for foldopen/folddelete
func Test_normal08_fold()
  CheckFeature folding
  call Setup_NewWindow()
  50
  setl foldenable fdm=marker
  " First fold
  norm! V4jzf
  " check that folds have been created
  call assert_equal(['50/* {{{ */', '51', '52', '53', '54/* }}} */'], getline(50,54))
  " Second fold
  46
  norm! V10jzf
  " check that folds have been created
  call assert_equal('46/* {{{ */', getline(46))
  call assert_equal('60/* }}} */', getline(60))
  norm! k
  call assert_equal('45', getline('.'))
  norm! j
  call assert_equal('46/* {{{ */', getline('.'))
  norm! j
  call assert_equal('61', getline('.'))
  norm! k
  " open a fold
  norm! Vzo
  norm! k
  call assert_equal('45', getline('.'))
  norm! j
  call assert_equal('46/* {{{ */', getline('.'))
  norm! j
  call assert_equal('47', getline('.'))
  norm! k
  norm! zcVzO
  call assert_equal('46/* {{{ */', getline('.'))
  norm! j
  call assert_equal('47', getline('.'))
  norm! j
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49', getline('.'))
  norm! j
  call assert_equal('50/* {{{ */', getline('.'))
  norm! j
  call assert_equal('51', getline('.'))
  " delete folds
  :46
  " collapse fold
  norm! V14jzC
  " delete all folds recursively
  norm! VzD
  call assert_equal(['46', '47', '48', '49', '50', '51', '52', '53', '54', '55', '56', '57', '58', '59', '60'], getline(46,60))

  " clean up
  setl nofoldenable fdm=marker
  bw!
endfunc

func Test_normal09a_operatorfunc()
  " Test operatorfunc
  call Setup_NewWindow()
  " Add some spaces for counting
  50,60s/$/  /
  unlet! g:a
  let g:a=0
  nmap <buffer><silent> ,, :set opfunc=CountSpaces<CR>g@
  vmap <buffer><silent> ,, :<C-U>call CountSpaces(visualmode(), 1)<CR>
  50
  norm V2j,,
  call assert_equal(6, g:a)
  norm V,,
  call assert_equal(2, g:a)
  norm ,,l
  call assert_equal(0, g:a)
  50
  exe "norm 0\<c-v>10j2l,,"
  call assert_equal(11, g:a)
  50
  norm V10j,,
  call assert_equal(22, g:a)

  " clean up
  unmap <buffer> ,,
  set opfunc=
  unlet! g:a
  bw!
endfunc

func Test_normal09b_operatorfunc()
  " Test operatorfunc
  call Setup_NewWindow()
  " Add some spaces for counting
  50,60s/$/  /
  unlet! g:opt
  set linebreak
  nmap <buffer><silent> ,, :set opfunc=OpfuncDummy<CR>g@
  50
  norm ,,j
  exe "bd!" g:bufnr
  call assert_true(&linebreak)
  call assert_equal(g:opt, &linebreak)
  set nolinebreak
  norm ,,j
  exe "bd!" g:bufnr
  call assert_false(&linebreak)
  call assert_equal(g:opt, &linebreak)

  " clean up
  unmap <buffer> ,,
  set opfunc=
  call assert_fails('normal Vg@', 'E774:')
  bw!
  unlet! g:opt
endfunc

func OperatorfuncRedo(_)
  let g:opfunc_count = v:count
endfunc

func Underscorize(_)
  normal! '[V']r_
endfunc

func Test_normal09c_operatorfunc()
  " Test redoing operatorfunc
  new
  call setline(1, 'some text')
  set operatorfunc=OperatorfuncRedo
  normal v3g@
  call assert_equal(3, g:opfunc_count)
  let g:opfunc_count = 0
  normal .
  call assert_equal(3, g:opfunc_count)

  bw!
  unlet g:opfunc_count

  " Test redoing Visual mode
  set operatorfunc=Underscorize
  new
  call setline(1, ['first', 'first', 'third', 'third', 'second'])
  normal! 1GVjg@
  normal! 5G.
  normal! 3G.
  call assert_equal(['_____', '_____', '_____', '_____', '______'], getline(1, '$'))
  bwipe!
  set operatorfunc=
endfunc

" Test for different ways of setting the 'operatorfunc' option
func Test_opfunc_callback()
  new
  func OpFunc1(callnr, type)
    let g:OpFunc1Args = [a:callnr, a:type]
  endfunc
  func OpFunc2(type)
    let g:OpFunc2Args = [a:type]
  endfunc

  let lines =<< trim END
    #" Test for using a function name
    LET &opfunc = 'g:OpFunc2'
    LET g:OpFunc2Args = []
    normal! g@l
    call assert_equal(['char'], g:OpFunc2Args)

    #" Test for using a function()
    set opfunc=function('g:OpFunc1',\ [10])
    LET g:OpFunc1Args = []
    normal! g@l
    call assert_equal([10, 'char'], g:OpFunc1Args)

    #" Using a funcref variable to set 'operatorfunc'
    VAR Fn = function('g:OpFunc1', [11])
    LET &opfunc = Fn
    LET g:OpFunc1Args = []
    normal! g@l
    call assert_equal([11, 'char'], g:OpFunc1Args)

    #" Using a string(funcref_variable) to set 'operatorfunc'
    LET Fn = function('g:OpFunc1', [12])
    LET &operatorfunc = string(Fn)
    LET g:OpFunc1Args = []
    normal! g@l
    call assert_equal([12, 'char'], g:OpFunc1Args)

    #" Test for using a funcref()
    set operatorfunc=funcref('g:OpFunc1',\ [13])
    LET g:OpFunc1Args = []
    normal! g@l
    call assert_equal([13, 'char'], g:OpFunc1Args)

    #" Using a funcref variable to set 'operatorfunc'
    LET Fn = funcref('g:OpFunc1', [14])
    LET &opfunc = Fn
    LET g:OpFunc1Args = []
    normal! g@l
    call assert_equal([14, 'char'], g:OpFunc1Args)

    #" Using a string(funcref_variable) to set 'operatorfunc'
    LET Fn = funcref('g:OpFunc1', [15])
    LET &opfunc = string(Fn)
    LET g:OpFunc1Args = []
    normal! g@l
    call assert_equal([15, 'char'], g:OpFunc1Args)

    #" Test for using a lambda function using set
    VAR optval = "LSTART a LMIDDLE OpFunc1(16, a) LEND"
    LET optval = substitute(optval, ' ', '\\ ', 'g')
    exe "set opfunc=" .. optval
    LET g:OpFunc1Args = []
    normal! g@l
    call assert_equal([16, 'char'], g:OpFunc1Args)

    #" Test for using a lambda function using LET
    LET &opfunc = LSTART a LMIDDLE OpFunc1(17, a) LEND
    LET g:OpFunc1Args = []
    normal! g@l
    call assert_equal([17, 'char'], g:OpFunc1Args)

    #" Set 'operatorfunc' to a string(lambda expression)
    LET &opfunc = 'LSTART a LMIDDLE OpFunc1(18, a) LEND'
    LET g:OpFunc1Args = []
    normal! g@l
    call assert_equal([18, 'char'], g:OpFunc1Args)

    #" Set 'operatorfunc' to a variable with a lambda expression
    VAR Lambda = LSTART a LMIDDLE OpFunc1(19, a) LEND
    LET &opfunc = Lambda
    LET g:OpFunc1Args = []
    normal! g@l
    call assert_equal([19, 'char'], g:OpFunc1Args)

    #" Set 'operatorfunc' to a string(variable with a lambda expression)
    LET Lambda = LSTART a LMIDDLE OpFunc1(20, a) LEND
    LET &opfunc = string(Lambda)
    LET g:OpFunc1Args = []
    normal! g@l
    call assert_equal([20, 'char'], g:OpFunc1Args)

    #" Try to use 'operatorfunc' after the function is deleted
    func g:TmpOpFunc1(type)
      let g:TmpOpFunc1Args = [21, a:type]
    endfunc
    LET &opfunc = function('g:TmpOpFunc1')
    delfunc g:TmpOpFunc1
    call test_garbagecollect_now()
    LET g:TmpOpFunc1Args = []
    call assert_fails('normal! g@l', 'E117:')
    call assert_equal([], g:TmpOpFunc1Args)

    #" Try to use a function with two arguments for 'operatorfunc'
    func g:TmpOpFunc2(x, y)
      let g:TmpOpFunc2Args = [a:x, a:y]
    endfunc
    set opfunc=TmpOpFunc2
    LET g:TmpOpFunc2Args = []
    call assert_fails('normal! g@l', 'E119:')
    call assert_equal([], g:TmpOpFunc2Args)
    delfunc TmpOpFunc2

    #" Try to use a lambda function with two arguments for 'operatorfunc'
    LET &opfunc = LSTART a, b LMIDDLE OpFunc1(22, b) LEND
    LET g:OpFunc1Args = []
    call assert_fails('normal! g@l', 'E119:')
    call assert_equal([], g:OpFunc1Args)

    #" Test for clearing the 'operatorfunc' option
    set opfunc=''
    set opfunc&
    call assert_fails("set opfunc=function('abc')", "E700:")
    call assert_fails("set opfunc=funcref('abc')", "E700:")

    #" set 'operatorfunc' to a non-existing function
    LET &opfunc = function('g:OpFunc1', [23])
    call assert_fails("set opfunc=function('NonExistingFunc')", 'E700:')
    call assert_fails("LET &opfunc = function('NonExistingFunc')", 'E700:')
    LET g:OpFunc1Args = []
    normal! g@l
    call assert_equal([23, 'char'], g:OpFunc1Args)
  END
  call CheckTransLegacySuccess(lines)

  " Test for using a script-local function name
  func s:OpFunc3(type)
    let g:OpFunc3Args = [a:type]
  endfunc
  set opfunc=s:OpFunc3
  let g:OpFunc3Args = []
  normal! g@l
  call assert_equal(['char'], g:OpFunc3Args)

  let &opfunc = 's:OpFunc3'
  let g:OpFunc3Args = []
  normal! g@l
  call assert_equal(['char'], g:OpFunc3Args)
  delfunc s:OpFunc3

  " Using Vim9 lambda expression in legacy context should fail
  set opfunc=(a)\ =>\ OpFunc1(24,\ a)
  let g:OpFunc1Args = []
  call assert_fails('normal! g@l', 'E117:')
  call assert_equal([], g:OpFunc1Args)

  " set 'operatorfunc' to a partial with dict. This used to cause a crash.
  func SetOpFunc()
    let operator = {'execute': function('OperatorExecute')}
    let &opfunc = operator.execute
  endfunc
  func OperatorExecute(_) dict
  endfunc
  call SetOpFunc()
  call test_garbagecollect_now()
  set operatorfunc=
  delfunc SetOpFunc
  delfunc OperatorExecute

  " Vim9 tests
  let lines =<< trim END
    vim9script

    def g:Vim9opFunc(val: number, type: string): void
      g:OpFunc1Args = [val, type]
    enddef

    # Test for using a def function with opfunc
    set opfunc=function('g:Vim9opFunc',\ [60])
    g:OpFunc1Args = []
    normal! g@l
    assert_equal([60, 'char'], g:OpFunc1Args)

    # Test for using a global function name
    &opfunc = g:OpFunc2
    g:OpFunc2Args = []
    normal! g@l
    assert_equal(['char'], g:OpFunc2Args)
    bw!

    # Test for using a script-local function name
    def LocalOpFunc(type: string): void
      g:LocalOpFuncArgs = [type]
    enddef
    &opfunc = LocalOpFunc
    g:LocalOpFuncArgs = []
    normal! g@l
    assert_equal(['char'], g:LocalOpFuncArgs)
    bw!
  END
  call CheckScriptSuccess(lines)

  " setting 'opfunc' to a script local function outside of a script context
  " should fail
  let cleanup =<< trim END
    call writefile([execute('messages')], 'Xtest.out')
    qall
  END
  call writefile(cleanup, 'Xverify.vim')
  call RunVim([], [], "-c \"set opfunc=s:abc\" -S Xverify.vim")
  call assert_match('E81: Using <SID> not in a', readfile('Xtest.out')[0])
  call delete('Xtest.out')
  call delete('Xverify.vim')

  " cleanup
  set opfunc&
  delfunc OpFunc1
  delfunc OpFunc2
  unlet g:OpFunc1Args g:OpFunc2Args
  %bw!
endfunc

func Test_normal10_expand()
  " Test for expand()
  10new
  call setline(1, ['1', 'ifooar,,cbar'])
  2
  norm! $
  call assert_equal('cbar', expand('<cword>'))
  call assert_equal('ifooar,,cbar', expand('<cWORD>'))

  call setline(1, ['prx = list[idx];'])
  1
  let expected = ['', 'prx', 'prx', 'prx',
	\ 'list', 'list', 'list', 'list', 'list', 'list', 'list',
	\ 'idx', 'idx', 'idx', 'idx',
	\ 'list[idx]',
	\ '];',
	\ ]
  for i in range(1, 16)
    exe 'norm ' . i . '|'
    call assert_equal(expected[i], expand('<cexpr>'), 'i == ' . i)
  endfor

  " Test for <cexpr> in state.val and ptr->val
  call setline(1, 'x = state.val;')
  call cursor(1, 10)
  call assert_equal('state.val', expand('<cexpr>'))
  call setline(1, 'x = ptr->val;')
  call cursor(1, 9)
  call assert_equal('ptr->val', expand('<cexpr>'))

  if executable('echo')
    " Test expand(`...`) i.e. backticks command expansion.
    " MS-Windows has a trailing space.
    call assert_match('^abcde *$', expand('`echo abcde`'))
  endif

  " Test expand(`=...`) i.e. backticks expression expansion
  call assert_equal('5', expand('`=2+3`'))
  call assert_equal('3.14', expand('`=3.14`'))

  " clean up
  bw!
endfunc

" Test for expand() in latin1 encoding
func Test_normal_expand_latin1()
  new
  let save_enc = &encoding
  " set encoding=latin1
  call setline(1, 'val = item->color;')
  call cursor(1, 11)
  call assert_equal('color', expand("<cword>"))
  call assert_equal('item->color', expand("<cexpr>"))
  let &encoding = save_enc
  bw!
endfunc

func Test_normal11_showcmd()
  " test for 'showcmd'
  10new
  exe "norm! ofoobar\<esc>"
  call assert_equal(2, line('$'))
  set showcmd
  exe "norm! ofoobar2\<esc>"
  call assert_equal(3, line('$'))
  exe "norm! VAfoobar3\<esc>"
  call assert_equal(3, line('$'))
  exe "norm! 0d3\<del>2l"
  call assert_equal('obar2foobar3', getline('.'))
  " test for the visual block size displayed in the status line
  call setline(1, ['aaaaa', 'bbbbb', 'ccccc'])
  call feedkeys("ggl\<C-V>lljj", 'xt')
  redraw!
  call assert_match('3x3$', Screenline(&lines))
  call feedkeys("\<C-V>", 'xt')
  " test for visually selecting a multi-byte character
  call setline(1, ["\U2206"])
  call feedkeys("ggv", 'xt')
  redraw!
  call assert_match('1-3$', Screenline(&lines))
  call feedkeys("v", 'xt')
  " test for visually selecting the end of line
  call setline(1, ["foobar"])
  call feedkeys("$vl", 'xt')
  redraw!
  call assert_match('2$', Screenline(&lines))
  call feedkeys("y", 'xt')
  call assert_equal("r\n", @")
  bw!
endfunc

" Test for nv_error and normal command errors
func Test_normal12_nv_error()
  10new
  call setline(1, range(1,5))
  " should not do anything, just beep
  call assert_beeps('exe "norm! <c-k>"')
  call assert_equal(map(range(1,5), 'string(v:val)'), getline(1,'$'))
  call assert_beeps('normal! G2dd')
  call assert_beeps("normal! g\<C-A>")
  call assert_beeps("normal! g\<C-X>")
  call assert_beeps("normal! g\<C-B>")
  " call assert_beeps("normal! vQ\<Esc>")
  call assert_beeps("normal! 2[[")
  call assert_beeps("normal! 2]]")
  call assert_beeps("normal! 2[]")
  call assert_beeps("normal! 2][")
  call assert_beeps("normal! 4[z")
  call assert_beeps("normal! 4]z")
  call assert_beeps("normal! 4[c")
  call assert_beeps("normal! 4]c")
  call assert_beeps("normal! 200%")
  call assert_beeps("normal! %")
  call assert_beeps("normal! 2{")
  call assert_beeps("normal! 2}")
  call assert_beeps("normal! r\<Right>")
  call assert_beeps("normal! 8ry")
  call assert_beeps('normal! "@')
  bw!
endfunc

func Test_normal13_help()
  " Test for F1
  call assert_equal(1, winnr())
  call feedkeys("\<f1>", 'txi')
  call assert_match('help\.txt', bufname('%'))
  call assert_equal(2, winnr('$'))
  bw!
endfunc

func Test_normal14_page()
  " basic test for Ctrl-F and Ctrl-B
  call Setup_NewWindow()
  exe "norm! \<c-f>"
  call assert_equal('9', getline('.'))
  exe "norm! 2\<c-f>"
  call assert_equal('25', getline('.'))
  exe "norm! 2\<c-b>"
  call assert_equal('18', getline('.'))
  1
  set scrolloff=5
  exe "norm! 2\<c-f>"
  call assert_equal('21', getline('.'))
  exe "norm! \<c-b>"
  call assert_equal('13', getline('.'))
  1
  set scrolloff=99
  exe "norm! \<c-f>"
  call assert_equal('13', getline('.'))
  set scrolloff=0
  100
  exe "norm! $\<c-b>"
  call assert_equal([0, 92, 1, 0, 1], getcurpos())
  100
  set nostartofline
  exe "norm! $\<c-b>"
  call assert_equal([0, 92, 2, 0, v:maxcol], getcurpos())
  " cleanup
  set startofline
  bw!
endfunc

func Test_normal14_page_eol()
  10new
  norm oxxxxxxx
  exe "norm 2\<c-f>"
  " check with valgrind that cursor is put back in column 1
  exe "norm 2\<c-b>"
  bw!
endfunc

" Test for errors with z command
func Test_normal_z_error()
  call assert_beeps('normal! z2p')
  call assert_beeps('normal! zq')
  call assert_beeps('normal! cz1')
endfunc

func Test_normal15_z_scroll_vert()
  " basic test for z commands that scroll the window
  call Setup_NewWindow()
  100
  norm! >>
  " Test for z<cr>
  exe "norm! z\<cr>"
  call assert_equal('	100', getline('.'))
  call assert_equal(100, winsaveview()['topline'])
  call assert_equal([0, 100, 2, 0, 9], getcurpos())

  " Test for zt
  21
  norm! >>0zt
  call assert_equal('	21', getline('.'))
  call assert_equal(21, winsaveview()['topline'])
  call assert_equal([0, 21, 1, 0, 8], getcurpos())

  " Test for zb
  30
  norm! >>$ztzb
  call assert_equal('	30', getline('.'))
  call assert_equal(30, winsaveview()['topline']+winheight(0)-1)
  call assert_equal([0, 30, 3, 0, v:maxcol], getcurpos())

  " Test for z-
  1
  30
  norm! 0z-
  call assert_equal('	30', getline('.'))
  call assert_equal(30, winsaveview()['topline']+winheight(0)-1)
  call assert_equal([0, 30, 2, 0, 9], getcurpos())

  " Test for z{height}<cr>
  call assert_equal(10, winheight(0))
  exe "norm! z12\<cr>"
  call assert_equal(12, winheight(0))
  exe "norm! z15\<Del>0\<cr>"
  call assert_equal(10, winheight(0))

  " Test for z.
  1
  21
  norm! 0z.
  call assert_equal('	21', getline('.'))
  call assert_equal(17, winsaveview()['topline'])
  call assert_equal([0, 21, 2, 0, 9], getcurpos())

  " Test for zz
  1
  21
  norm! 0zz
  call assert_equal('	21', getline('.'))
  call assert_equal(17, winsaveview()['topline'])
  call assert_equal([0, 21, 1, 0, 8], getcurpos())

  " Test for z+
  11
  norm! zt
  norm! z+
  call assert_equal('	21', getline('.'))
  call assert_equal(21, winsaveview()['topline'])
  call assert_equal([0, 21, 2, 0, 9], getcurpos())

  " Test for [count]z+
  1
  norm! 21z+
  call assert_equal('	21', getline('.'))
  call assert_equal(21, winsaveview()['topline'])
  call assert_equal([0, 21, 2, 0, 9], getcurpos())

  " Test for z+ with [count] greater than buffer size
  1
  norm! 1000z+
  call assert_equal('	100', getline('.'))
  call assert_equal(100, winsaveview()['topline'])
  call assert_equal([0, 100, 2, 0, 9], getcurpos())

  " Test for z+ from the last buffer line
  norm! Gz.z+
  call assert_equal('	100', getline('.'))
  call assert_equal(100, winsaveview()['topline'])
  call assert_equal([0, 100, 2, 0, 9], getcurpos())

  " Test for z^
  norm! 22z+0
  norm! z^
  call assert_equal('	21', getline('.'))
  call assert_equal(12, winsaveview()['topline'])
  call assert_equal([0, 21, 2, 0, 9], getcurpos())

  " Test for z^ from first buffer line
  norm! ggz^
  call assert_equal('1', getline('.'))
  call assert_equal(1, winsaveview()['topline'])
  call assert_equal([0, 1, 1, 0, 1], getcurpos())

  " Test for [count]z^
  1
  norm! 30z^
  call assert_equal('	21', getline('.'))
  call assert_equal(12, winsaveview()['topline'])
  call assert_equal([0, 21, 2, 0, 9], getcurpos())

  " cleanup
  bw!
endfunc

func Test_normal16_z_scroll_hor()
  " basic test for z commands that scroll the window
  10new
  15vsp
  set nowrap listchars=
  let lineA='abcdefghijklmnopqrstuvwxyz'
  let lineB='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  $put =lineA
  $put =lineB
  1d

  " Test for zl and zh with a count
  norm! 0z10l
  call assert_equal([11, 1], [col('.'), wincol()])
  norm! z4h
  call assert_equal([11, 5], [col('.'), wincol()])
  normal! 2gg

  " Test for zl
  1
  norm! 5zl
  call assert_equal(lineA, getline('.'))
  call assert_equal(6, col('.'))
  call assert_equal(5, winsaveview()['leftcol'])
  norm! yl
  call assert_equal('f', @0)

  " Test for zh
  norm! 2zh
  call assert_equal(lineA, getline('.'))
  call assert_equal(6, col('.'))
  norm! yl
  call assert_equal('f', @0)
  call assert_equal(3, winsaveview()['leftcol'])

  " Test for zL
  norm! zL
  call assert_equal(11, col('.'))
  norm! yl
  call assert_equal('k', @0)
  call assert_equal(10, winsaveview()['leftcol'])
  norm! 2zL
  call assert_equal(25, col('.'))
  norm! yl
  call assert_equal('y', @0)
  call assert_equal(24, winsaveview()['leftcol'])

  " Test for zH
  norm! 2zH
  call assert_equal(25, col('.'))
  call assert_equal(10, winsaveview()['leftcol'])
  norm! yl
  call assert_equal('y', @0)

  " Test for zs
  norm! $zs
  call assert_equal(26, col('.'))
  call assert_equal(25, winsaveview()['leftcol'])
  norm! yl
  call assert_equal('z', @0)

  " Test for ze
  norm! ze
  call assert_equal(26, col('.'))
  call assert_equal(11, winsaveview()['leftcol'])
  norm! yl
  call assert_equal('z', @0)

  " Test for zs and ze with folds
  %fold
  norm! $zs
  call assert_equal(26, col('.'))
  call assert_equal(0, winsaveview()['leftcol'])
  norm! yl
  call assert_equal('z', @0)
  norm! ze
  call assert_equal(26, col('.'))
  call assert_equal(0, winsaveview()['leftcol'])
  norm! yl
  call assert_equal('z', @0)

  " cleanup
  set wrap listchars=eol:$
  bw!
endfunc

func Test_normal17_z_scroll_hor2()
  " basic test for z commands that scroll the window
  " using 'sidescrolloff' setting
  10new
  20vsp
  set nowrap listchars= sidescrolloff=5
  let lineA='abcdefghijklmnopqrstuvwxyz'
  let lineB='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  $put =lineA
  $put =lineB
  1d

  " Test for zl
  1
  norm! 5zl
  call assert_equal(lineA, getline('.'))
  call assert_equal(11, col('.'))
  call assert_equal(5, winsaveview()['leftcol'])
  norm! yl
  call assert_equal('k', @0)

  " Test for zh
  norm! 2zh
  call assert_equal(lineA, getline('.'))
  call assert_equal(11, col('.'))
  norm! yl
  call assert_equal('k', @0)
  call assert_equal(3, winsaveview()['leftcol'])

  " Test for zL
  norm! 0zL
  call assert_equal(16, col('.'))
  norm! yl
  call assert_equal('p', @0)
  call assert_equal(10, winsaveview()['leftcol'])
  norm! 2zL
  call assert_equal(26, col('.'))
  norm! yl
  call assert_equal('z', @0)
  call assert_equal(15, winsaveview()['leftcol'])

  " Test for zH
  norm! 2zH
  call assert_equal(15, col('.'))
  call assert_equal(0, winsaveview()['leftcol'])
  norm! yl
  call assert_equal('o', @0)

  " Test for zs
  norm! $zs
  call assert_equal(26, col('.'))
  call assert_equal(20, winsaveview()['leftcol'])
  norm! yl
  call assert_equal('z', @0)

  " Test for ze
  norm! ze
  call assert_equal(26, col('.'))
  call assert_equal(11, winsaveview()['leftcol'])
  norm! yl
  call assert_equal('z', @0)

  " cleanup
  set wrap listchars=eol:$ sidescrolloff=0
  bw!
endfunc

" Test for commands that scroll the window horizontally. Test with folds.
"   H, M, L, CTRL-E, CTRL-Y, CTRL-U, CTRL-D, PageUp, PageDown commands
func Test_vert_scroll_cmds()
  15new
  call setline(1, range(1, 100))
  exe "normal! 30ggz\<CR>"
  set foldenable
  33,36fold
  40,43fold
  46,49fold
  let h = winheight(0)

  " Test for H, M and L commands
  " Top of the screen = 30
  " Folded lines = 9
  " Bottom of the screen = 30 + h + 9 - 1
  normal! 4L
  call assert_equal(35 + h, line('.'))
  normal! 4H
  call assert_equal(33, line('.'))

  " Test for using a large count value
  %d
  call setline(1, range(1, 4))
  norm! 6H
  call assert_equal(4, line('.'))

  " Test for 'M' with folded lines
  %d
  call setline(1, range(1, 20))
  1,5fold
  norm! LM
  call assert_equal(12, line('.'))

  " Test for the CTRL-E and CTRL-Y commands with folds
  %d
  call setline(1, range(1, 10))
  3,5fold
  exe "normal 6G3\<C-E>"
  call assert_equal(6, line('w0'))
  exe "normal 2\<C-Y>"
  call assert_equal(2, line('w0'))

  " Test for CTRL-Y on a folded line
  %d
  call setline(1, range(1, 100))
  exe (h + 2) .. "," .. (h + 4) .. "fold"
  exe h + 5
  normal z-
  exe "normal \<C-Y>\<C-Y>"
  call assert_equal(h + 1, line('w$'))

  " Test for CTRL-Y from the first line and CTRL-E from the last line
  %d
  set scrolloff=2
  call setline(1, range(1, 4))
  exe "normal gg\<C-Y>"
  call assert_equal(1, line('w0'))
  call assert_equal(1, line('.'))
  exe "normal G4\<C-E>\<C-E>"
  call assert_equal(4, line('w$'))
  call assert_equal(4, line('.'))
  set scrolloff&

  " Using <PageUp> and <PageDown> in an empty buffer should beep
  %d
  call assert_beeps('exe "normal \<PageUp>"')
  call assert_beeps('exe "normal \<C-B>"')
  call assert_beeps('exe "normal \<PageDown>"')
  call assert_beeps('exe "normal \<C-F>"')

  " Test for <C-U> and <C-D> with fold
  %d
  call setline(1, range(1, 100))
  10,35fold
  set scroll=10
  exe "normal \<C-D>"
  call assert_equal(36, line('.'))
  exe "normal \<C-D>"
  call assert_equal(46, line('.'))
  exe "normal \<C-U>"
  call assert_equal(36, line('.'))
  exe "normal \<C-U>"
  call assert_equal(1, line('.'))
  exe "normal \<C-U>"
  call assert_equal(1, line('.'))
  set scroll&

  " Test for scrolling to the top of the file with <C-U> and a fold
  10
  normal ztL
  exe "normal \<C-U>\<C-U>"
  call assert_equal(1, line('w0'))

  " Test for CTRL-D on a folded line
  %d
  call setline(1, range(1, 100))
  50,100fold
  75
  normal z-
  exe "normal \<C-D>"
  call assert_equal(50, line('.'))
  call assert_equal(100, line('w$'))
  normal z.
  let lnum = winline()
  exe "normal \<C-D>"
  call assert_equal(lnum, winline())
  call assert_equal(50, line('.'))
  normal zt
  exe "normal \<C-D>"
  call assert_equal(50, line('w0'))

  " Test for <S-CR>. Page down.
  %d
  call setline(1, range(1, 100))
  call feedkeys("\<S-CR>", 'xt')
  call assert_equal(14, line('w0'))
  call assert_equal(28, line('w$'))

  " Test for <S-->. Page up.
  call feedkeys("\<S-->", 'xt')
  call assert_equal(1, line('w0'))
  call assert_equal(15, line('w$'))

  set foldenable&
  bwipe!
endfunc

func Test_scroll_in_ex_mode()
  " This was using invalid memory because w_botline was invalid.
  let lines =<< trim END
      diffsplit
      norm os00(
      call writefile(['done'], 'Xdone')
      qa!
  END
  call writefile(lines, 'Xscript', 'D')
  call assert_equal(1, RunVim([], [], '--clean -X -Z -e -s -S Xscript'))
  call assert_equal(['done'], readfile('Xdone'))

  call delete('Xdone')
endfunc

func Test_scroll_and_paste_in_ex_mode()
  throw 'Skipped: does not work when Nvim is run from :!'
  " This used to crash because of moving cursor to line 0.
  let lines =<< trim END
      v/foo/vi|YY9PYQ
      v/bar/vi|YY9PYQ
      v/bar/exe line('.') == 1 ? "vi|Y\<C-B>9PYQ" : "vi|YQ"
      call writefile(['done'], 'Xdone')
      qa!
  END
  call writefile(lines, 'Xscript', 'D')
  call assert_equal(1, RunVim([], [], '-u NONE -i NONE -n -X -Z -e -s -S Xscript'))
  call assert_equal(['done'], readfile('Xdone'))

  call delete('Xdone')
endfunc

" Test for the 'sidescroll' option
func Test_sidescroll_opt()
  new
  20vnew

  " scroll by 2 characters horizontally
  set sidescroll=2 nowrap
  call setline(1, repeat('a', 40))
  normal g$l
  call assert_equal(19, screenpos(0, 1, 21).col)
  normal l
  call assert_equal(20, screenpos(0, 1, 22).col)
  normal g0h
  call assert_equal(2, screenpos(0, 1, 2).col)
  call assert_equal(20, screenpos(0, 1, 20).col)

  " when 'sidescroll' is 0, cursor positioned at the center
  set sidescroll=0
  normal g$l
  call assert_equal(11, screenpos(0, 1, 21).col)
  normal g0h
  call assert_equal(10, screenpos(0, 1, 10).col)

  %bw!
  set wrap& sidescroll&
endfunc

" basic tests for foldopen/folddelete
func Test_normal18_z_fold()
  CheckFeature folding
  call Setup_NewWindow()
  50
  setl foldenable fdm=marker foldlevel=5

  call assert_beeps('normal! zj')
  call assert_beeps('normal! zk')

  " Test for zF
  " First fold
  norm! 4zF
  " check that folds have been created
  call assert_equal(['50/* {{{ */', '51', '52', '53/* }}} */'], getline(50,53))

  " Test for zd
  51
  norm! 2zF
  call assert_equal(2, foldlevel('.'))
  norm! kzd
  call assert_equal(['50', '51/* {{{ */', '52/* }}} */', '53'], getline(50,53))
  norm! j
  call assert_equal(1, foldlevel('.'))

  " Test for zD
  " also deletes partially selected folds recursively
  51
  norm! zF
  call assert_equal(2, foldlevel('.'))
  norm! kV2jzD
  call assert_equal(['50', '51', '52', '53'], getline(50,53))

  " Test for zE
  85
  norm! 4zF
  86
  norm! 2zF
  90
  norm! 4zF
  call assert_equal(['85/* {{{ */', '86/* {{{ */', '87/* }}} */', '88/* }}} */', '89', '90/* {{{ */', '91', '92', '93/* }}} */'], getline(85,93))
  norm! zE
  call assert_equal(['85', '86', '87', '88', '89', '90', '91', '92', '93'], getline(85,93))

  " Test for zn
  50
  set foldlevel=0
  norm! 2zF
  norm! zn
  norm! k
  call assert_equal('49', getline('.'))
  norm! j
  call assert_equal('50/* {{{ */', getline('.'))
  norm! j
  call assert_equal('51/* }}} */', getline('.'))
  norm! j
  call assert_equal('52', getline('.'))
  call assert_equal(0, &foldenable)

  " Test for zN
  49
  norm! zN
  call assert_equal('49', getline('.'))
  norm! j
  call assert_equal('50/* {{{ */', getline('.'))
  norm! j
  call assert_equal('52', getline('.'))
  call assert_equal(1, &foldenable)

  " Test for zi
  norm! zi
  call assert_equal(0, &foldenable)
  norm! zi
  call assert_equal(1, &foldenable)
  norm! zi
  call assert_equal(0, &foldenable)
  norm! zi
  call assert_equal(1, &foldenable)

  " Test for za
  50
  norm! za
  norm! k
  call assert_equal('49', getline('.'))
  norm! j
  call assert_equal('50/* {{{ */', getline('.'))
  norm! j
  call assert_equal('51/* }}} */', getline('.'))
  norm! j
  call assert_equal('52', getline('.'))
  50
  norm! za
  norm! k
  call assert_equal('49', getline('.'))
  norm! j
  call assert_equal('50/* {{{ */', getline('.'))
  norm! j
  call assert_equal('52', getline('.'))

  49
  norm! 5zF
  norm! k
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/* {{{ */', getline('.'))
  norm! j
  call assert_equal('55', getline('.'))
  49
  norm! za
  call assert_equal('49/* {{{ */', getline('.'))
  norm! j
  call assert_equal('50/* {{{ */', getline('.'))
  norm! j
  call assert_equal('52', getline('.'))
  set nofoldenable
  " close fold and set foldenable
  norm! za
  call assert_equal(1, &foldenable)

  50
  " have to use {count}za to open all folds and make the cursor visible
  norm! 2za
  norm! 2k
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/* {{{ */', getline('.'))
  norm! j
  call assert_equal('50/* {{{ */', getline('.'))
  norm! j
  call assert_equal('51/* }}} */', getline('.'))
  norm! j
  call assert_equal('52', getline('.'))

  " Test for zA
  49
  set foldlevel=0
  50
  norm! zA
  norm! 2k
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/* {{{ */', getline('.'))
  norm! j
  call assert_equal('50/* {{{ */', getline('.'))
  norm! j
  call assert_equal('51/* }}} */', getline('.'))
  norm! j
  call assert_equal('52', getline('.'))

  " zA on an opened fold when foldenable is not set
  50
  set nofoldenable
  norm! zA
  call assert_equal(1, &foldenable)
  norm! k
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/* {{{ */', getline('.'))
  norm! j
  call assert_equal('55', getline('.'))

  " Test for zc
  norm! zE
  50
  norm! 2zF
  49
  norm! 5zF
  set nofoldenable
  50
  " There most likely is a bug somewhere:
  " https://groups.google.com/d/msg/vim_dev/v2EkfJ_KQjI/u-Cvv94uCAAJ
  " TODO: Should this only close the inner most fold or both folds?
  norm! zc
  call assert_equal(1, &foldenable)
  norm! k
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/* {{{ */', getline('.'))
  norm! j
  call assert_equal('55', getline('.'))
  set nofoldenable
  50
  norm! Vjzc
  norm! k
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/* {{{ */', getline('.'))
  norm! j
  call assert_equal('55', getline('.'))

  " Test for zC
  set nofoldenable
  50
  norm! zCk
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/* {{{ */', getline('.'))
  norm! j
  call assert_equal('55', getline('.'))

  " Test for zx
  " 1) close folds at line 49-54
  set nofoldenable
  48
  norm! zx
  call assert_equal(1, &foldenable)
  norm! j
  call assert_equal('49/* {{{ */', getline('.'))
  norm! j
  call assert_equal('55', getline('.'))

  " 2) do not close fold under cursor
  51
  set nofoldenable
  norm! zx
  call assert_equal(1, &foldenable)
  norm! 3k
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/* {{{ */', getline('.'))
  norm! j
  call assert_equal('50/* {{{ */', getline('.'))
  norm! j
  call assert_equal('51/* }}} */', getline('.'))
  norm! j
  call assert_equal('52', getline('.'))
  norm! j
  call assert_equal('53', getline('.'))
  norm! j
  call assert_equal('54/* }}} */', getline('.'))
  norm! j
  call assert_equal('55', getline('.'))

  " 3) close one level of folds
  48
  set nofoldenable
  set foldlevel=1
  norm! zx
  call assert_equal(1, &foldenable)
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/* {{{ */', getline('.'))
  norm! j
  call assert_equal('50/* {{{ */', getline('.'))
  norm! j
  call assert_equal('52', getline('.'))
  norm! j
  call assert_equal('53', getline('.'))
  norm! j
  call assert_equal('54/* }}} */', getline('.'))
  norm! j
  call assert_equal('55', getline('.'))

  " Test for zX
  " Close all folds
  set foldlevel=0 nofoldenable
  50
  norm! zX
  call assert_equal(1, &foldenable)
  norm! k
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/* {{{ */', getline('.'))
  norm! j
  call assert_equal('55', getline('.'))

  " Test for zm
  50
  set nofoldenable foldlevel=2
  norm! zm
  call assert_equal(1, &foldenable)
  call assert_equal(1, &foldlevel)
  norm! zm
  call assert_equal(0, &foldlevel)
  norm! zm
  call assert_equal(0, &foldlevel)
  norm! k
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/* {{{ */', getline('.'))
  norm! j
  call assert_equal('55', getline('.'))

  " Test for zm with a count
  50
  set foldlevel=2
  norm! 3zm
  call assert_equal(0, &foldlevel)
  call assert_equal(49, foldclosed(line('.')))

  " Test for zM
  48
  set nofoldenable foldlevel=99
  norm! zM
  call assert_equal(1, &foldenable)
  call assert_equal(0, &foldlevel)
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/* {{{ */', getline('.'))
  norm! j
  call assert_equal('55', getline('.'))

  " Test for zr
  48
  set nofoldenable foldlevel=0
  norm! zr
  call assert_equal(0, &foldenable)
  call assert_equal(1, &foldlevel)
  set foldlevel=0 foldenable
  norm! zr
  call assert_equal(1, &foldenable)
  call assert_equal(1, &foldlevel)
  norm! zr
  call assert_equal(2, &foldlevel)
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/* {{{ */', getline('.'))
  norm! j
  call assert_equal('50/* {{{ */', getline('.'))
  norm! j
  call assert_equal('51/* }}} */', getline('.'))
  norm! j
  call assert_equal('52', getline('.'))

  " Test for zR
  48
  set nofoldenable foldlevel=0
  norm! zR
  call assert_equal(0, &foldenable)
  call assert_equal(2, &foldlevel)
  set foldenable foldlevel=0
  norm! zR
  call assert_equal(1, &foldenable)
  call assert_equal(2, &foldlevel)
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/* {{{ */', getline('.'))
  norm! j
  call assert_equal('50/* {{{ */', getline('.'))
  norm! j
  call assert_equal('51/* }}} */', getline('.'))
  norm! j
  call assert_equal('52', getline('.'))
  call append(50, ['a /* {{{ */', 'b /* }}} */'])
  48
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/* {{{ */', getline('.'))
  norm! j
  call assert_equal('50/* {{{ */', getline('.'))
  norm! j
  call assert_equal('a /* {{{ */', getline('.'))
  norm! j
  call assert_equal('51/* }}} */', getline('.'))
  norm! j
  call assert_equal('52', getline('.'))
  48
  norm! zR
  call assert_equal(1, &foldenable)
  call assert_equal(3, &foldlevel)
  call assert_equal('48', getline('.'))
  norm! j
  call assert_equal('49/* {{{ */', getline('.'))
  norm! j
  call assert_equal('50/* {{{ */', getline('.'))
  norm! j
  call assert_equal('a /* {{{ */', getline('.'))
  norm! j
  call assert_equal('b /* }}} */', getline('.'))
  norm! j
  call assert_equal('51/* }}} */', getline('.'))
  norm! j
  call assert_equal('52', getline('.'))

  " clean up
  setl nofoldenable fdm=marker foldlevel=0
  bw!
endfunc

func Test_normal20_exmode()
  " Reading from redirected file doesn't work on MS-Windows
  CheckNotMSWindows
  call writefile(['1a', 'foo', 'bar', '.', 'w! Xfile2', 'q!'], 'Xscript')
  call writefile(['1', '2'], 'Xfile')
  call system(GetVimCommand() .. ' -e -s < Xscript Xfile')
  let a=readfile('Xfile2')
  call assert_equal(['1', 'foo', 'bar', '2'], a)

  " clean up
  for file in ['Xfile', 'Xfile2', 'Xscript']
    call delete(file)
  endfor
  bw!
endfunc

func Test_normal21_nv_hat()

  " Edit a fresh file and wipe the buffer list so that there is no alternate
  " file present.  Next, check for the expected command failures.
  edit Xfoo | %bw
  call assert_fails(':buffer #', 'E86')
  call assert_fails(':execute "normal! \<C-^>"', 'E23')
  call assert_fails("normal i\<C-R>#", 'E23:')

  " Test for the expected behavior when switching between two named buffers.
  edit Xfoo | edit Xbar
  call feedkeys("\<C-^>", 'tx')
  call assert_equal('Xfoo', fnamemodify(bufname('%'), ':t'))
  call feedkeys("\<C-^>", 'tx')
  call assert_equal('Xbar', fnamemodify(bufname('%'), ':t'))

  " Test for the expected behavior when only one buffer is named.
  enew | let l:nr = bufnr('%')
  call feedkeys("\<C-^>", 'tx')
  call assert_equal('Xbar', fnamemodify(bufname('%'), ':t'))
  call feedkeys("\<C-^>", 'tx')
  call assert_equal('', bufname('%'))
  call assert_equal(l:nr, bufnr('%'))

  " Test that no action is taken by "<C-^>" when an operator is pending.
  edit Xfoo
  call feedkeys("ci\<C-^>", 'tx')
  call assert_equal('Xfoo', fnamemodify(bufname('%'), ':t'))

  %bw!
endfunc

func Test_normal22_zet()
  " Test for ZZ
  " let shell = &shell
  " let &shell = 'sh'
  call writefile(['1', '2'], 'Xn22file', 'D')
  let args = ' -N -i NONE --noplugins -X --headless'
  call system(GetVimCommand() .. args .. ' -c "%d" -c ":norm! ZZ" Xn22file')
  let a = readfile('Xn22file')
  call assert_equal([], a)
  " Test for ZQ
  call writefile(['1', '2'], 'Xn22file')
  call system(GetVimCommand() . args . ' -c "%d" -c ":norm! ZQ" Xn22file')
  let a = readfile('Xn22file')
  call assert_equal(['1', '2'], a)

  " Unsupported Z command
  call assert_beeps('normal! ZW')

  " clean up
  " let &shell = shell
endfunc

func Test_normal23_K()
  " Test for K command
  new
  call append(0, ['helphelp.txt', 'man', 'aa%bb', 'cc|dd'])
  let k = &keywordprg
  set keywordprg=:help
  1
  norm! VK
  call assert_equal('helphelp.txt', fnamemodify(bufname('%'), ':t'))
  call assert_equal('help', &ft)
  call assert_match('\*helphelp.txt\*', getline('.'))
  helpclose
  norm! 0K
  call assert_equal('helphelp.txt', fnamemodify(bufname('%'), ':t'))
  call assert_equal('help', &ft)
  call assert_match('Help on help files', getline('.'))
  helpclose

  set keywordprg=:new
  set iskeyword+=%
  set iskeyword+=\|
  2
  norm! K
  call assert_equal('man', fnamemodify(bufname('%'), ':t'))
  bwipe!
  3
  norm! K
  call assert_equal('aa%bb', fnamemodify(bufname('%'), ':t'))
  bwipe!
  if !has('win32')
    4
    norm! K
    call assert_equal('cc|dd', fnamemodify(bufname('%'), ':t'))
    bwipe!
  endif
  set iskeyword-=%
  set iskeyword-=\|

  " Currently doesn't work in Nvim, see #19436
  " Test for specifying a count to K
  " 1
  " com! -nargs=* Kprog let g:Kprog_Args = <q-args>
  " set keywordprg=:Kprog
  " norm! 3K
  " call assert_equal('3 version8', g:Kprog_Args)
  " delcom Kprog

  " Only expect "man" to work on Unix
  if !has("unix") || has('nvim')  " Nvim K uses :terminal. #15398
    let &keywordprg = k
    bw!
    return
  endif

  let not_gnu_man = has('mac') || has('bsd')
  if not_gnu_man
    " In macOS and BSD, the option for specifying a pager is different
    set keywordprg=man\ -P\ cat
  else
    set keywordprg=man\ --pager=cat
  endif
  " Test for using man
  2
  let a = execute('unsilent norm! K')
  if not_gnu_man
    call assert_match("man -P cat 'man'", a)
  else
    call assert_match("man --pager=cat 'man'", a)
  endif

  " Error cases
  call setline(1, '#$#')
  call assert_fails('normal! ggK', 'E349:')
  call setline(1, '---')
  call assert_fails('normal! ggv2lK', 'E349:')
  call setline(1, ['abc', 'xyz'])
  call assert_fails("normal! gg2lv2h\<C-]>", 'E433:')
  call assert_beeps("normal! ggVjK")

  " clean up
  let &keywordprg = k
  bw!
endfunc

func Test_normal24_rot13()
  " Testing for g?? g?g?
  new
  call append(0, 'abcdefghijklmnopqrstuvwxyzäüö')
  1
  norm! g??
  call assert_equal('nopqrstuvwxyzabcdefghijklmäüö', getline('.'))
  norm! g?g?
  call assert_equal('abcdefghijklmnopqrstuvwxyzäüö', getline('.'))

  " clean up
  bw!
endfunc

func Test_normal25_tag()
  CheckFeature quickfix

  " Testing for CTRL-] g CTRL-] g]
  " CTRL-W g] CTRL-W CTRL-] CTRL-W g CTRL-]
  h
  " Test for CTRL-]
  call search('\<x\>$')
  exe "norm! \<c-]>"
  call assert_equal("change.txt", fnamemodify(bufname('%'), ':t'))
  norm! yiW
  call assert_equal("*x*", @0)
  exe ":norm \<c-o>"

  " Test for g_CTRL-]
  call search('\<v_u\>$')
  exe "norm! g\<c-]>"
  call assert_equal("change.txt", fnamemodify(bufname('%'), ':t'))
  norm! yiW
  call assert_equal("*v_u*", @0)
  exe ":norm \<c-o>"

  " Test for g]
  call search('\<i_<Esc>$')
  let a = execute(":norm! g]")
  call assert_match('i_<Esc>.*insert.txt', a)

  if !empty(exepath('cscope')) && has('cscope')
    " setting cscopetag changes how g] works
    set cst
    exe "norm! g]"
    call assert_equal("insert.txt", fnamemodify(bufname('%'), ':t'))
    norm! yiW
    call assert_equal("*i_<Esc>*", @0)
    exe ":norm \<c-o>"
    " Test for CTRL-W g]
    exe "norm! \<C-W>g]"
    call assert_equal("insert.txt", fnamemodify(bufname('%'), ':t'))
    norm! yiW
    call assert_equal("*i_<Esc>*", @0)
    call assert_equal(3, winnr('$'))
    helpclose
    set nocst
  endif

  " Test for CTRL-W g]
  let a = execute("norm! \<C-W>g]")
  call assert_match('i_<Esc>.*insert.txt', a)

  " Test for CTRL-W CTRL-]
  exe "norm! \<C-W>\<C-]>"
  call assert_equal("insert.txt", fnamemodify(bufname('%'), ':t'))
  norm! yiW
  call assert_equal("*i_<Esc>*", @0)
  call assert_equal(3, winnr('$'))
  helpclose

  " Test for CTRL-W g CTRL-]
  exe "norm! \<C-W>g\<C-]>"
  call assert_equal("insert.txt", fnamemodify(bufname('%'), ':t'))
  norm! yiW
  call assert_equal("*i_<Esc>*", @0)
  call assert_equal(3, winnr('$'))
  helpclose

  " clean up
  helpclose
endfunc

func Test_normal26_put()
  " Test for ]p ]P [p and [P
  new
  call append(0, ['while read LINE', 'do', '  ((count++))', '  if [ $? -ne 0 ]; then', "    echo 'Error writing file'", '  fi', 'done'])
  1
  /Error/y a
  2
  norm! "a]pj"a[p
  call assert_equal(['do', "echo 'Error writing file'", "  echo 'Error writing file'", '  ((count++))'], getline(2,5))
  1
  /^\s\{4}/
  exe "norm!  \"a]P3Eldt'"
  exe "norm! j\"a[P2Eldt'"
  call assert_equal(['  if [ $? -ne 0 ]; then', "    echo 'Error writing'", "    echo 'Error'", "    echo 'Error writing file'", '  fi'], getline(6,10))

  " clean up
  bw!
endfunc

func Test_normal27_bracket()
  " Test for [' [` ]' ]`
  call Setup_NewWindow()
  1,21s/.\+/  &   b/
  1
  norm! $ma
  5
  norm! $mb
  10
  norm! $mc
  15
  norm! $md
  20
  norm! $me

  " Test for ['
  9
  norm! 2['
  call assert_equal('  1   b', getline('.'))
  call assert_equal(1, line('.'))
  call assert_equal(3, col('.'))

  " Test for ]'
  norm! ]'
  call assert_equal('  5   b', getline('.'))
  call assert_equal(5, line('.'))
  call assert_equal(3, col('.'))

  " No mark before line 1, cursor moves to first non-blank on current line
  1
  norm! 5|['
  call assert_equal('  1   b', getline('.'))
  call assert_equal(1, line('.'))
  call assert_equal(3, col('.'))

  " No mark after line 21, cursor moves to first non-blank on current line
  21
  norm! 5|]'
  call assert_equal('  21   b', getline('.'))
  call assert_equal(21, line('.'))
  call assert_equal(3, col('.'))

  " Test for [`
  norm! 2[`
  call assert_equal('  15   b', getline('.'))
  call assert_equal(15, line('.'))
  call assert_equal(8, col('.'))

  " Test for ]`
  norm! ]`
  call assert_equal('  20   b', getline('.'))
  call assert_equal(20, line('.'))
  call assert_equal(8, col('.'))

  " No mark before line 1, cursor does not move
  1
  norm! 5|[`
  call assert_equal('  1   b', getline('.'))
  call assert_equal(1, line('.'))
  call assert_equal(5, col('.'))

  " No mark after line 21, cursor does not move
  21
  norm! 5|]`
  call assert_equal('  21   b', getline('.'))
  call assert_equal(21, line('.'))
  call assert_equal(5, col('.'))

  " Count too large for [`
  " cursor moves to first lowercase mark
  norm! 99[`
  call assert_equal('  1   b', getline('.'))
  call assert_equal(1, line('.'))
  call assert_equal(7, col('.'))

  " Count too large for ]`
  " cursor moves to last lowercase mark
  norm! 99]`
  call assert_equal('  20   b', getline('.'))
  call assert_equal(20, line('.'))
  call assert_equal(8, col('.'))

  " clean up
  bw!
endfunc

" Test for ( and ) sentence movements
func Test_normal28_parenthesis()
  new
  call append(0, ['This is a test. With some sentences!', '', 'Even with a question? And one more. And no sentence here'])

  $
  norm! d(
  call assert_equal(['This is a test. With some sentences!', '', 'Even with a question? And one more. ', ''], getline(1, '$'))
  norm! 2d(
  call assert_equal(['This is a test. With some sentences!', '', ' ', ''], getline(1, '$'))
  1
  norm! 0d)
  call assert_equal(['With some sentences!', '', ' ', ''], getline(1, '$'))

  call append('$', ['This is a long sentence', '', 'spanning', 'over several lines. '])
  $
  norm! $d(
  call assert_equal(['With some sentences!', '', ' ', '', 'This is a long sentence', ''], getline(1, '$'))

  " Move to the next sentence from a paragraph macro
  %d
  call setline(1, ['.LP', 'blue sky!. blue sky.', 'blue sky. blue sky.'])
  call cursor(1, 1)
  normal )
  call assert_equal([2, 1], [line('.'), col('.')])
  normal )
  call assert_equal([2, 12], [line('.'), col('.')])
  normal ((
  call assert_equal([1, 1], [line('.'), col('.')])

  " It is an error if a next sentence is not found
  %d
  call setline(1, '.SH')
  call assert_beeps('normal )')

  " If only dot is present, don't treat that as a sentence
  call setline(1, '. This is a sentence.')
  normal $((
  call assert_equal(3, col('.'))

  " Jumping to a fold should open the fold
  call setline(1, ['', '', 'one', 'two', 'three'])
  set foldenable
  2,$fold
  call feedkeys(')', 'xt')
  call assert_equal(3, line('.'))
  call assert_equal(1, foldlevel('.'))
  call assert_equal(-1, foldclosed('.'))
  set foldenable&

  " clean up
  bw!
endfunc

" Test for { and } paragraph movements
func Test_normal29_brace()
  let text =<< trim [DATA]
    A paragraph begins after each empty line, and also at each of a set of
    paragraph macros, specified by the pairs of characters in the 'paragraphs'
    option.  The default is "IPLPPPQPP TPHPLIPpLpItpplpipbp", which corresponds to
    the macros ".IP", ".LP", etc.  (These are nroff macros, so the dot must be in
    the first column).  A section boundary is also a paragraph boundary.
    Note that a blank line (only containing white space) is NOT a paragraph
    boundary.


    Also note that this does not include a '{' or '}' in the first column.  When
    the '{' flag is in 'cpoptions' then '{' in the first column is used as a
    paragraph boundary |posix|.
    {
    This is no paragraph
    unless the '{' is set
    in 'cpoptions'
    }
    .IP
    The nroff macros IP separates a paragraph
    That means, it must be a '.'
    followed by IP
    .LPIt does not matter, if afterwards some
    more characters follow.
    .SHAlso section boundaries from the nroff
    macros terminate a paragraph. That means
    a character like this:
    .NH
    End of text here
  [DATA]

  new
  call append(0, text)
  1
  norm! 0d2}

  let expected =<< trim [DATA]
    .IP
    The nroff macros IP separates a paragraph
    That means, it must be a '.'
    followed by IP
    .LPIt does not matter, if afterwards some
    more characters follow.
    .SHAlso section boundaries from the nroff
    macros terminate a paragraph. That means
    a character like this:
    .NH
    End of text here

  [DATA]
  call assert_equal(expected, getline(1, '$'))

  norm! 0d}

  let expected =<< trim [DATA]
    .LPIt does not matter, if afterwards some
    more characters follow.
    .SHAlso section boundaries from the nroff
    macros terminate a paragraph. That means
    a character like this:
    .NH
    End of text here

  [DATA]
  call assert_equal(expected, getline(1, '$'))

  $
  norm! d{

  let expected =<< trim [DATA]
    .LPIt does not matter, if afterwards some
    more characters follow.
    .SHAlso section boundaries from the nroff
    macros terminate a paragraph. That means
    a character like this:

  [DATA]
  call assert_equal(expected, getline(1, '$'))

  norm! d{

  let expected =<< trim [DATA]
    .LPIt does not matter, if afterwards some
    more characters follow.

  [DATA]
  call assert_equal(expected, getline(1, '$'))

  " Test with { in cpoptions
  %d
  call append(0, text)
  " Nvim: no "{" flag in 'cpoptions'.
  " set cpo+={
  " 1
  " norm! 0d2}

  let expected =<< trim [DATA]
    {
    This is no paragraph
    unless the '{' is set
    in 'cpoptions'
    }
    .IP
    The nroff macros IP separates a paragraph
    That means, it must be a '.'
    followed by IP
    .LPIt does not matter, if afterwards some
    more characters follow.
    .SHAlso section boundaries from the nroff
    macros terminate a paragraph. That means
    a character like this:
    .NH
    End of text here

  [DATA]
  " call assert_equal(expected, getline(1, '$'))

  " $
  " norm! d}

  let expected =<< trim [DATA]
    {
    This is no paragraph
    unless the '{' is set
    in 'cpoptions'
    }
    .IP
    The nroff macros IP separates a paragraph
    That means, it must be a '.'
    followed by IP
    .LPIt does not matter, if afterwards some
    more characters follow.
    .SHAlso section boundaries from the nroff
    macros terminate a paragraph. That means
    a character like this:
    .NH
    End of text here

  [DATA]
  " call assert_equal(expected, getline(1, '$'))

  " norm! gg}
  " norm! d5}

  let expected =<< trim [DATA]
    {
    This is no paragraph
    unless the '{' is set
    in 'cpoptions'
    }

  [DATA]
  " call assert_equal(expected, getline(1, '$'))

  " Jumping to a fold should open the fold
  " %d
  " call setline(1, ['', 'one', 'two', ''])
  " set foldenable
  " 2,$fold
  " call feedkeys('}', 'xt')
  " call assert_equal(4, line('.'))
  " call assert_equal(1, foldlevel('.'))
  " call assert_equal(-1, foldclosed('.'))
  " set foldenable&

  " clean up
  set cpo-={
  bw!
endfunc

" Test for section movements
func Test_normal_section()
  new
  let lines =<< trim [END]
    int foo()
    {
      if (1)
      {
        a = 1;
      }
    }
  [END]
  call setline(1, lines)

  " jumping to a folded line using [[ should open the fold
  2,3fold
  call cursor(5, 1)
  call feedkeys("[[", 'xt')
  call assert_equal(2, line('.'))
  call assert_equal(-1, foldclosedend(line('.')))

  bwipe!
endfunc

" Test for changing case using u, U, gu, gU and ~ (tilde) commands
func Test_normal30_changecase()
  new
  call append(0, 'This is a simple test: äüöß')
  norm! 1ggVu
  call assert_equal('this is a simple test: äüöß', getline('.'))
  norm! VU
  call assert_equal('THIS IS A SIMPLE TEST: ÄÜÖẞ', getline('.'))
  norm! guu
  call assert_equal('this is a simple test: äüöß', getline('.'))
  norm! gUgU
  call assert_equal('THIS IS A SIMPLE TEST: ÄÜÖẞ', getline('.'))
  norm! gugu
  call assert_equal('this is a simple test: äüöß', getline('.'))
  norm! gUU
  call assert_equal('THIS IS A SIMPLE TEST: ÄÜÖẞ', getline('.'))
  norm! 010~
  call assert_equal('this is a SIMPLE TEST: ÄÜÖẞ', getline('.'))
  norm! V~
  call assert_equal('THIS IS A simple test: äüöß', getline('.'))
  call assert_beeps('norm! c~')
  %d
  call assert_beeps('norm! ~')

  " Test with multiple lines
  call setline(1, ['AA', 'BBBB', 'CCCCCC', 'DDDDDDDD'])
  norm! ggguG
  call assert_equal(['aa', 'bbbb', 'cccccc', 'dddddddd'], getline(1, '$'))
  norm! GgUgg
  call assert_equal(['AA', 'BBBB', 'CCCCCC', 'DDDDDDDD'], getline(1, '$'))
  %d

  " Test for changing case across lines using 'whichwrap'
  call setline(1, ['aaaaaa', 'aaaaaa'])
  normal! gg10~
  call assert_equal(['AAAAAA', 'aaaaaa'], getline(1, 2))
  set whichwrap+=~
  normal! gg10~
  call assert_equal(['aaaaaa', 'AAAAaa'], getline(1, 2))
  set whichwrap&

  " try changing the case with a double byte encoding (DBCS)
  %bw!
  let enc = &enc
  " set encoding=cp932
  call setline(1, "\u8470")
  normal ~
  normal gU$gu$gUgUg~g~gugu
  call assert_equal("\u8470", getline(1))
  let &encoding = enc

  " clean up
  bw!
endfunc

" Turkish ASCII turns to multi-byte.  On some systems Turkish locale
" is available but toupper()/tolower() don't do the right thing.
func Test_normal_changecase_turkish()
  new
  try
    lang tr_TR.UTF-8
    set casemap=
    let iupper = toupper('i')
    if iupper == "\u0130"
      call setline(1, 'iI')
      1normal gUU
      call assert_equal("\u0130I", getline(1))
      call assert_equal("\u0130I", toupper("iI"))

      call setline(1, 'iI')
      1normal guu
      call assert_equal("i\u0131", getline(1))
      call assert_equal("i\u0131", tolower("iI"))
    elseif iupper == "I"
      call setline(1, 'iI')
      1normal gUU
      call assert_equal("II", getline(1))
      call assert_equal("II", toupper("iI"))

      call setline(1, 'iI')
      1normal guu
      call assert_equal("ii", getline(1))
      call assert_equal("ii", tolower("iI"))
    else
      call assert_true(false, "expected toupper('i') to be either 'I' or '\u0131'")
    endif
    set casemap&
    call setline(1, 'iI')
    1normal gUU
    call assert_equal("II", getline(1))
    call assert_equal("II", toupper("iI"))

    call setline(1, 'iI')
    1normal guu
    call assert_equal("ii", getline(1))
    call assert_equal("ii", tolower("iI"))

    lang en_US.UTF-8
  catch /E197:/
    " can't use Turkish locale
    throw 'Skipped: Turkish locale not available'
  endtry

  bwipe!
endfunc

" Test for r (replace) command
func Test_normal31_r_cmd()
  new
  call append(0, 'This is a simple test: abcd')
  exe "norm! 1gg$r\<cr>"
  call assert_equal(['This is a simple test: abc', '', ''], getline(1,'$'))
  exe "norm! 1gg2wlr\<cr>"
  call assert_equal(['This is a', 'simple test: abc', '', ''], getline(1,'$'))
  exe "norm! 2gg0W5r\<cr>"
  call assert_equal(['This is a', 'simple ', ' abc', '', ''], getline('1', '$'))
  set autoindent
  call setline(2, ['simple test: abc', ''])
  exe "norm! 2gg0W5r\<cr>"
  call assert_equal(['This is a', 'simple ', 'abc', '', '', ''], getline('1', '$'))
  exe "norm! 1ggVr\<cr>"
  call assert_equal('^M^M^M^M^M^M^M^M^M', strtrans(getline(1)))
  call setline(1, 'This is a')
  exe "norm! 1gg05rf"
  call assert_equal('fffffis a', getline(1))

  " When replacing characters, copy characters from above and below lines
  " using CTRL-Y and CTRL-E.
  " Different code paths are used for utf-8 and latin1 encodings
  set showmatch
  " for enc in ['latin1', 'utf-8']
  for enc in ['utf-8']
    enew!
    let &encoding = enc
    call setline(1, [' {a}', 'xxxxxxxxxx', '      [b]'])
    exe "norm! 2gg5r\<C-Y>l5r\<C-E>"
    call assert_equal(' {a}x [b]x', getline(2))
  endfor
  set showmatch&

  " r command should fail in operator pending mode
  call assert_beeps('normal! cr')

  " replace a tab character in visual mode
  %d
  call setline(1, ["a\tb", "c\td", "e\tf"])
  normal gglvjjrx
  call assert_equal(['axx', 'xxx', 'xxf'], getline(1, '$'))

  " replace with a multibyte character (with multiple composing characters)
  %d
  new
  call setline(1, 'aaa')
  exe "normal $ra\u0328\u0301"
  call assert_equal("aaa\u0328\u0301", getline(1))

  " clean up
  set noautoindent
  bw!
endfunc

" Test for g*, g#
func Test_normal32_g_cmd1()
  new
  call append(0, ['abc.x_foo', 'x_foobar.abc'])
  1
  norm! $g*
  call assert_equal('x_foo', @/)
  call assert_equal('x_foobar.abc', getline('.'))
  norm! $g#
  call assert_equal('abc', @/)
  call assert_equal('abc.x_foo', getline('.'))

  " clean up
  bw!
endfunc

" Test for g`, g;, g,, g&, gv, gk, gj, gJ, g0, g^, g_, gm, g$, gM, g CTRL-G,
" gi and gI commands
func Test_normal33_g_cmd2()
  call Setup_NewWindow()
  " Test for g`
  clearjumps
  norm! ma10j
  let a=execute(':jumps')
  " empty jumplist
  call assert_equal('>', a[-1:])
  norm! g`a
  call assert_equal('>', a[-1:])
  call assert_equal(1, line('.'))
  call assert_equal('1', getline('.'))
  call cursor(10, 1)
  norm! g'a
  call assert_equal('>', a[-1:])
  call assert_equal(1, line('.'))
  let v:errmsg = ''
  call assert_nobeep("normal! g`\<Esc>")
  call assert_equal('', v:errmsg)
  call assert_nobeep("normal! g'\<Esc>")
  call assert_equal('', v:errmsg)

  " Test for g; and g,
  norm! g;
  " there is only one change in the changelist
  " currently, when we setup the window
  call assert_equal(2, line('.'))
  call assert_fails(':norm! g;', 'E662')
  call assert_fails(':norm! g,', 'E663')
  let &ul = &ul
  call append('$', ['a', 'b', 'c', 'd'])
  let &ul = &ul
  call append('$', ['Z', 'Y', 'X', 'W'])
  let a = execute(':changes')
  call assert_match('2\s\+0\s\+2', a)
  call assert_match('101\s\+0\s\+a', a)
  call assert_match('105\s\+0\s\+Z', a)
  norm! 3g;
  call assert_equal(2, line('.'))
  norm! 2g,
  call assert_equal(105, line('.'))

  " Test for g& - global substitute
  %d
  call setline(1, range(1,10))
  call append('$', ['a', 'b', 'c', 'd'])
  $s/\w/&&/g
  exe "norm! /[1-8]\<cr>"
  norm! g&
  call assert_equal(['11', '22', '33', '44', '55', '66', '77', '88', '9', '110', 'a', 'b', 'c', 'dd'], getline(1, '$'))

  " Jumping to a fold using gg should open the fold
  set foldenable
  set foldopen+=jump
  5,8fold
  call feedkeys('6gg', 'xt')
  call assert_equal(1, foldlevel('.'))
  call assert_equal(-1, foldclosed('.'))
  set foldopen-=jump
  set foldenable&

  " Test for gv
  %d
  call append('$', repeat(['abcdefgh'], 8))
  exe "norm! 2gg02l\<c-v>2j2ly"
  call assert_equal(['cde', 'cde', 'cde'], getreg(0, 1, 1))
  " in visual mode, gv swaps current and last selected region
  exe "norm! G0\<c-v>4k4lgvd"
  call assert_equal(['', 'abfgh', 'abfgh', 'abfgh', 'abcdefgh', 'abcdefgh', 'abcdefgh', 'abcdefgh', 'abcdefgh'], getline(1,'$'))
  exe "norm! G0\<c-v>4k4ly"
  exe "norm! gvood"
  call assert_equal(['', 'abfgh', 'abfgh', 'abfgh', 'fgh', 'fgh', 'fgh', 'fgh', 'fgh'], getline(1,'$'))
  " gv cannot be used in operator pending mode
  call assert_beeps('normal! cgv')
  " gv should beep without a previously selected visual area
  new
  call assert_beeps('normal! gv')
  close

  " Test for gk/gj
  %d
  15vsp
  set wrap listchars= sbr=
  let lineA = 'abcdefghijklmnopqrstuvwxyz'
  let lineB = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  let lineC = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz01234567890123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
  $put =lineA
  $put =lineB

  norm! 3gg0dgk
  call assert_equal(['', 'abcdefghijklmno', '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'], getline(1, '$'))
  set nu
  norm! 3gg0gjdgj
  call assert_equal(['', 'abcdefghijklmno', '0123456789AMNOPQRSTUVWXYZ'], getline(1,'$'))

  " Test for gJ
  norm! 2gggJ
  call assert_equal(['', 'abcdefghijklmno0123456789AMNOPQRSTUVWXYZ'], getline(1,'$'))
  call assert_equal(16, col('.'))
  " shouldn't do anything
  norm! 10gJ
  call assert_equal(1, col('.'))

  " Test for g0 g^ gm g$
  exe "norm! 2gg0gji   "
  call assert_equal(['', 'abcdefghijk   lmno0123456789AMNOPQRSTUVWXYZ'], getline(1,'$'))
  norm! g0yl
  call assert_equal(12, col('.'))
  call assert_equal(' ', getreg(0))
  norm! g$yl
  call assert_equal(22, col('.'))
  call assert_equal('3', getreg(0))
  norm! gmyl
  call assert_equal(17, col('.'))
  call assert_equal('n', getreg(0))
  norm! g^yl
  call assert_equal(15, col('.'))
  call assert_equal('l', getreg(0))
  call assert_beeps('normal 5g$')

  " Test for g$ with double-width character half displayed
  vsplit
  9wincmd |
  setlocal nowrap nonumber
  call setline(2, 'asdfasdfヨ')
  2
  normal 0g$
  call assert_equal(8, col('.'))
  10wincmd |
  normal 0g$
  call assert_equal(9, col('.'))

  setlocal signcolumn=yes
  11wincmd |
  normal 0g$
  call assert_equal(8, col('.'))
  12wincmd |
  normal 0g$
  call assert_equal(9, col('.'))

  close

  " Test for g_
  call assert_beeps('normal! 100g_')
  call setline(2, ['  foo  ', '  foobar  '])
  normal! 2ggg_
  call assert_equal(5, col('.'))
  normal! 2g_
  call assert_equal(8, col('.'))

  norm! 2ggdG
  $put =lineC

  " Test for gM
  norm! gMyl
  call assert_equal(73, col('.'))
  call assert_equal('0', getreg(0))
  " Test for 20gM
  norm! 20gMyl
  call assert_equal(29, col('.'))
  call assert_equal('S', getreg(0))
  " Test for 60gM
  norm! 60gMyl
  call assert_equal(87, col('.'))
  call assert_equal('E', getreg(0))

  " Have an odd number of chars in the line
  norm! A.
  call assert_equal(145, col('.'))
  norm! gMyl
  call assert_equal(73, col('.'))
  call assert_equal('0', getreg(0))

  " 'listchars' "eol" should not affect gM behavior
  setlocal list listchars=eol:$
  norm! $
  call assert_equal(145, col('.'))
  norm! gMyl
  call assert_equal(73, col('.'))
  call assert_equal('0', getreg(0))
  setlocal nolist

  " Test for gM with Tab characters
  call setline('.', "\ta\tb\tc\td\te\tf")
  norm! gMyl
  call assert_equal(6, col('.'))
  call assert_equal("c", getreg(0))

  " Test for g Ctrl-G
  call setline('.', lineC)
  norm! 60gMyl
  set ff=unix
  let a=execute(":norm! g\<c-g>")
  call assert_match('Col 87 of 144; Line 2 of 2; Word 1 of 1; Byte 88 of 146', a)

  " Test for gI
  norm! gIfoo
  call assert_equal(['', 'foo0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz01234567890123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'], getline(1,'$'))

  " Test for gi
  wincmd c
  %d
  set tw=0
  call setline(1, ['foobar', 'new line'])
  norm! A next word
  $put ='third line'
  norm! gi another word
  call assert_equal(['foobar next word another word', 'new line', 'third line'], getline(1,'$'))
  call setline(1, 'foobar')
  normal! Ggifirst line
  call assert_equal('foobarfirst line', getline(1))
  " Test gi in 'virtualedit' mode with cursor after the end of the line
  set virtualedit=all
  call setline(1, 'foo')
  exe "normal! Abar\<Right>\<Right>\<Right>\<Right>"
  call setline(1, 'foo')
  normal! Ggifirst line
  call assert_equal('foo       first line', getline(1))
  set virtualedit&

  " Test for aborting a g command using CTRL-\ CTRL-G
  exe "normal! g\<C-\>\<C-G>"
  call assert_equal('foo       first line', getline('.'))

  " clean up
  bw!
endfunc

func Test_normal_ex_substitute()
  " This was hanging on the substitute prompt.
  new
  call setline(1, 'a')
  exe "normal! gggQs/a/b/c\<CR>"
  call assert_equal('a', getline(1))
  bwipe!
endfunc

" Test for g CTRL-G
func Test_g_ctrl_g()
  new

  let a = execute(":norm! g\<c-g>")
  call assert_equal("\n--No lines in buffer--", a)

  " Test for CTRL-G (same as :file)
  let a = execute(":norm! \<c-g>")
  call assert_equal("\n\n\"[No Name]\" --No lines in buffer--", a)

  call setline(1, ['first line', 'second line'])

  " Test g CTRL-g with dos, mac and unix file type.
  norm! gojll
  set ff=dos
  let a = execute(":norm! g\<c-g>")
  call assert_equal("\nCol 3 of 11; Line 2 of 2; Word 3 of 4; Byte 15 of 25", a)

  set ff=mac
  let a = execute(":norm! g\<c-g>")
  call assert_equal("\nCol 3 of 11; Line 2 of 2; Word 3 of 4; Byte 14 of 23", a)

  set ff=unix
  let a = execute(":norm! g\<c-g>")
  call assert_equal("\nCol 3 of 11; Line 2 of 2; Word 3 of 4; Byte 14 of 23", a)

  " Test g CTRL-g in visual mode (v)
  let a = execute(":norm! gojllvlg\<c-g>")
  call assert_equal("\nSelected 1 of 2 Lines; 1 of 4 Words; 2 of 23 Bytes", a)

  " Test g CTRL-g in visual mode (CTRL-V) with end col > start col
  let a = execute(":norm! \<Esc>gojll\<C-V>kllg\<c-g>")
  call assert_equal("\nSelected 3 Cols; 2 of 2 Lines; 2 of 4 Words; 6 of 23 Bytes", a)

  " Test g_CTRL-g in visual mode (CTRL-V) with end col < start col
  let a = execute(":norm! \<Esc>goll\<C-V>jhhg\<c-g>")
  call assert_equal("\nSelected 3 Cols; 2 of 2 Lines; 2 of 4 Words; 6 of 23 Bytes", a)

  " Test g CTRL-g in visual mode (CTRL-V) with end_vcol being MAXCOL
  let a = execute(":norm! \<Esc>gojll\<C-V>k$g\<c-g>")
  call assert_equal("\nSelected 2 of 2 Lines; 4 of 4 Words; 17 of 23 Bytes", a)

  " There should be one byte less with noeol
  set bin noeol
  let a = execute(":norm! \<Esc>gog\<c-g>")
  call assert_equal("\nCol 1 of 10; Line 1 of 2; Word 1 of 4; Char 1 of 23; Byte 1 of 22", a)
  set bin & eol&

  call setline(1, ['Français', '日本語'])

  let a = execute(":norm! \<Esc>gojlg\<c-g>")
  call assert_equal("\nCol 4-3 of 9-6; Line 2 of 2; Word 2 of 2; Char 11 of 13; Byte 16 of 20", a)

  let a = execute(":norm! \<Esc>gojvlg\<c-g>")
  call assert_equal("\nSelected 1 of 2 Lines; 1 of 2 Words; 2 of 13 Chars; 6 of 20 Bytes", a)

  let a = execute(":norm! \<Esc>goll\<c-v>jlg\<c-g>")
  call assert_equal("\nSelected 4 Cols; 2 of 2 Lines; 2 of 2 Words; 6 of 13 Chars; 11 of 20 Bytes", a)

  set fenc=utf8 bomb
  let a = execute(":norm! \<Esc>gojlg\<c-g>")
  call assert_equal("\nCol 4-3 of 9-6; Line 2 of 2; Word 2 of 2; Char 11 of 13; Byte 16 of 20(+3 for BOM)", a)

  set fenc=utf16 bomb
  let a = execute(":norm! g\<c-g>")
  call assert_equal("\nCol 4-3 of 9-6; Line 2 of 2; Word 2 of 2; Char 11 of 13; Byte 16 of 20(+2 for BOM)", a)

  set fenc=utf32 bomb
  let a = execute(":norm! g\<c-g>")
  call assert_equal("\nCol 4-3 of 9-6; Line 2 of 2; Word 2 of 2; Char 11 of 13; Byte 16 of 20(+4 for BOM)", a)

  set fenc& bomb&

  set ff&
  bwipe!
endfunc

" Test for g8
func Test_normal34_g_cmd3()
  new
  let a=execute(':norm! 1G0g8')
  call assert_equal("\nNUL", a)

  call setline(1, 'abcdefghijklmnopqrstuvwxyzäüö')
  let a=execute(':norm! 1G$g8')
  call assert_equal("\nc3 b6 ", a)

  call setline(1, "a\u0302")
  let a=execute(':norm! 1G0g8')
  call assert_equal("\n61 + cc 82 ", a)

  " clean up
  bw!
endfunc

" Test 8g8 which finds invalid utf8 at or after the cursor.
func Test_normal_8g8()
  new

  " With invalid byte.
  call setline(1, "___\xff___")
  norm! 1G08g8g
  call assert_equal([0, 1, 4, 0, 1], getcurpos())

  " With invalid byte before the cursor.
  call setline(1, "___\xff___")
  norm! 1G$h8g8g
  call assert_equal([0, 1, 6, 0, 9], getcurpos())

  " With truncated sequence.
  call setline(1, "___\xE2\x82___")
  norm! 1G08g8g
  call assert_equal([0, 1, 4, 0, 1], getcurpos())

  " With overlong sequence.
  call setline(1, "___\xF0\x82\x82\xAC___")
  norm! 1G08g8g
  call assert_equal([0, 1, 4, 0, 1], getcurpos())

  " With valid utf8.
  call setline(1, "café")
  norm! 1G08g8
  call assert_equal([0, 1, 1, 0, 1], getcurpos())

  bw!
endfunc

" Test for g<
func Test_normal35_g_cmd4()
  " Cannot capture its output,
  " probably a bug, therefore, test disabled:
  throw "Skipped: output of g< can't be tested currently"
  echo "a\nb\nc\nd"
  let b=execute(':norm! g<')
  call assert_true(!empty(b), 'failed `execute(g<)`')
endfunc

" Test for gp gP go
func Test_normal36_g_cmd5()
  new
  call append(0, 'abcdefghijklmnopqrstuvwxyz')
  set ff=unix
  " Test for gp gP
  call append(1, range(1,10))
  1
  norm! 1yy
  3
  norm! gp
  call assert_equal([0, 5, 1, 0, 1], getcurpos())
  $
  norm! gP
  call assert_equal([0, 14, 1, 0, 1], getcurpos())

  " Test for go
  norm! 26go
  call assert_equal([0, 1, 26, 0, 26], getcurpos())
  norm! 27go
  call assert_equal([0, 1, 26, 0, 26], getcurpos())
  norm! 28go
  call assert_equal([0, 2, 1, 0, 1], getcurpos())
  set ff=dos
  norm! 29go
  call assert_equal([0, 2, 1, 0, 1], getcurpos())
  set ff=unix
  norm! gg0
  norm! 101go
  call assert_equal([0, 13, 26, 0, 26], getcurpos())
  norm! 103go
  call assert_equal([0, 14, 1, 0, 1], getcurpos())
  " count > buffer content
  norm! 120go
  call assert_equal([0, 14, 1, 0, v:maxcol], getcurpos())
  " clean up
  bw!
endfunc

" Test for gt and gT
func Test_normal37_g_cmd6()
  tabnew 1.txt
  tabnew 2.txt
  tabnew 3.txt
  norm! 1gt
  call assert_equal(1, tabpagenr())
  norm! 3gt
  call assert_equal(3, tabpagenr())
  norm! 1gT
  " count gT goes not to the absolute tabpagenumber
  " but, but goes to the count previous tabpagenumber
  call assert_equal(2, tabpagenr())
  " wrap around
  norm! 3gT
  call assert_equal(3, tabpagenr())
  " gt does not wrap around
  norm! 5gt
  call assert_equal(3, tabpagenr())

  for i in range(3)
    tabclose
  endfor
  " clean up
  call assert_fails(':tabclose', 'E784:')
endfunc

" Test for <Home> and <C-Home> key
func Test_normal38_nvhome()
  new
  call setline(1, range(10))
  $
  setl et sw=2
  norm! V10>$
  " count is ignored
  exe "norm! 10\<home>"
  call assert_equal(1, col('.'))
  exe "norm! \<home>"
  call assert_equal([0, 10, 1, 0, 1], getcurpos())
  exe "norm! 5\<c-home>"
  call assert_equal([0, 5, 1, 0, 1], getcurpos())
  exe "norm! \<c-home>"
  call assert_equal([0, 1, 1, 0, 1], getcurpos())
  exe "norm! G\<c-kHome>"
  call assert_equal([0, 1, 1, 0, 1], getcurpos())

  " clean up
  bw!
endfunc

" Test for <End> and <C-End> keys
func Test_normal_nvend()
  new
  call setline(1, map(range(1, 10), '"line" .. v:val'))
  exe "normal! \<End>"
  call assert_equal(5, col('.'))
  exe "normal! 4\<End>"
  call assert_equal([4, 5], [line('.'), col('.')])
  exe "normal! \<C-End>"
  call assert_equal([10, 6], [line('.'), col('.')])

  bwipe!
endfunc

" Test for cw cW ce
func Test_normal39_cw()
  " Test for cw and cW on whitespace
  new
  set tw=0
  call append(0, 'here      are   some words')
  norm! 1gg0elcwZZZ
  call assert_equal('hereZZZare   some words', getline('.'))
  norm! 1gg0elcWYYY
  call assert_equal('hereZZZareYYYsome words', getline('.'))
  norm! 2gg0cwfoo
  call assert_equal('foo', getline('.'))

  call setline(1, 'one; two')
  call cursor(1, 1)
  call feedkeys('cwvim', 'xt')
  call assert_equal('vim; two', getline(1))
  call feedkeys('0cWone', 'xt')
  call assert_equal('one two', getline(1))
  "When cursor is at the end of a word 'ce' will change until the end of the
  "next word, but 'cw' will change only one character
  call setline(1, 'one two')
  call feedkeys('0ecwce', 'xt')
  call assert_equal('once two', getline(1))
  call setline(1, 'one two')
  call feedkeys('0ecely', 'xt')
  call assert_equal('only', getline(1))

  " clean up
  bw!
endfunc

" Test for CTRL-\ commands
func Test_normal40_ctrl_bsl()
  new
  call append(0, 'here      are   some words')
  exe "norm! 1gg0a\<C-\>\<C-N>"
  call assert_equal('n', mode())
  call assert_equal(1, col('.'))
  call assert_equal('', visualmode())
  exe "norm! 1gg0viw\<C-\>\<C-N>"
  call assert_equal('n', mode())
  call assert_equal(4, col('.'))
  exe "norm! 1gg0a\<C-\>\<C-G>"
  call assert_equal('n', mode())
  call assert_equal(1, col('.'))
  "imap <buffer> , <c-\><c-n>
  " set im
  exe ":norm! \<c-\>\<c-n>dw"
  " set noim
  call assert_equal('are   some words', getline(1))
  call assert_false(&insertmode)
  call assert_beeps("normal! \<C-\>\<C-A>")

  " Using CTRL-\ CTRL-N in cmd window should close the window
  call feedkeys("q:\<C-\>\<C-N>", 'xt')
  call assert_equal('', getcmdwintype())

  " clean up
  bw!
endfunc

" Test for <c-r>=, <c-r><c-r>= and <c-r><c-o>= in insert mode
func Test_normal41_insert_reg()
  new
  set sts=2 sw=2 ts=8 tw=0
  call append(0, ["aaa\tbbb\tccc", '', '', ''])
  let a=getline(1)
  norm! 2gg0
  exe "norm! a\<c-r>=a\<cr>"
  norm! 3gg0
  exe "norm! a\<c-r>\<c-r>=a\<cr>"
  norm! 4gg0
  exe "norm! a\<c-r>\<c-o>=a\<cr>"
  call assert_equal(['aaa	bbb	ccc', 'aaa bbb	ccc', 'aaa bbb	ccc', 'aaa	bbb	ccc', ''], getline(1, '$'))

  " clean up
  set sts=0 sw=8 ts=8
  bw!
endfunc

" Test for Ctrl-D and Ctrl-U
func Test_normal42_halfpage()
  call Setup_NewWindow()
  call assert_equal(5, &scroll)
  exe "norm! \<c-d>"
  call assert_equal('6', getline('.'))
  exe "norm! 2\<c-d>"
  call assert_equal('8', getline('.'))
  call assert_equal(2, &scroll)
  set scroll=5
  exe "norm! \<c-u>"
  call assert_equal('3', getline('.'))
  1
  set scrolloff=5
  exe "norm! \<c-d>"
  call assert_equal('10', getline('.'))
  exe "norm! \<c-u>"
  call assert_equal('5', getline('.'))
  1
  set scrolloff=99
  exe "norm! \<c-d>"
  call assert_equal('10', getline('.'))
  set scrolloff=0
  100
  exe "norm! $\<c-u>"
  call assert_equal('95', getline('.'))
  call assert_equal([0, 95, 1, 0, 1], getcurpos())
  100
  set nostartofline
  exe "norm! $\<c-u>"
  call assert_equal('95', getline('.'))
  call assert_equal([0, 95, 2, 0, v:maxcol], getcurpos())
  " cleanup
  set startofline
  bw!
endfunc

func Test_normal45_drop()
  if !has('dnd')
    " The ~ register does not exist
    call assert_beeps('norm! "~')
    return
  endif

  " basic test for drag-n-drop
  " unfortunately, without a gui, we can't really test much here,
  " so simply test that ~p fails (which uses the drop register)
  new
  call assert_fails(':norm! "~p', 'E353')
  call assert_equal([],  getreg('~', 1, 1))
  " the ~ register is read only
  call assert_fails(':let @~="1"', 'E354')
  bw!
endfunc

func Test_normal46_ignore()
  new
  " How to test this?
  " let's just for now test, that the buffer
  " does not change
  call feedkeys("\<c-s>", 't')
  call assert_equal([''], getline(1,'$'))

  " no valid commands
  exe "norm! \<char-0x100>"
  call assert_equal([''], getline(1,'$'))

  exe "norm! ä"
  call assert_equal([''], getline(1,'$'))

  " clean up
  bw!
endfunc

func Test_normal47_visual_buf_wipe()
  " This was causing a crash or ml_get error.
  enew!
  call setline(1,'xxx')
  normal $
  new
  call setline(1, range(1,2))
  2
  exe "norm \<C-V>$"
  bw!
  norm yp
  set nomodified
endfunc

func Test_normal48_wincmd()
  new
  exe "norm! \<c-w>c"
  call assert_equal(1, winnr('$'))
  call assert_fails(":norm! \<c-w>c", "E444")
endfunc

func Test_normal49_counts()
  new
  call setline(1, 'one two three four five six seven eight nine ten')
  1
  norm! 3d2w
  call assert_equal('seven eight nine ten', getline(1))
  bw!
endfunc

func Test_normal50_commandline()
  CheckFeature timers
  CheckFeature cmdline_hist

  func! DoTimerWork(id)
    call assert_equal(1, getbufinfo('')[0].command)

    " should fail, with E11, but does fail with E23?
    "call feedkeys("\<c-^>", 'tm')

    " should fail with E11 - "Invalid in command-line window"
    call assert_fails(":wincmd p", 'E11')

    " Return from commandline window.
    call feedkeys("\<CR>", 't')
  endfunc

  let oldlang=v:lang
  lang C
  set updatetime=20
  call timer_start(100, 'DoTimerWork')
  try
    " throws E23, for whatever reason...
    call feedkeys('q:', 'x!')
  catch /E23/
    " no-op
  endtry

  " clean up
  delfunc DoTimerWork
  set updatetime=4000
  exe "lang" oldlang
  bw!
endfunc

func Test_normal51_FileChangedRO()
  CheckFeature autocmd
  call writefile(['foo'], 'Xreadonly.log')
  new Xreadonly.log
  setl ro
  au FileChangedRO <buffer> :call feedkeys("\<c-^>", 'tix')
  call assert_fails(":norm! Af", 'E788')
  call assert_equal(['foo'], getline(1,'$'))
  call assert_equal('Xreadonly.log', bufname(''))

  " cleanup
  bw!
  call delete("Xreadonly.log")
endfunc

func Test_normal52_rl()
  CheckFeature rightleft
  new
  call setline(1, 'abcde fghij klmnopq')
  norm! 1gg$
  set rl
  call assert_equal(19, col('.'))
  call feedkeys('l', 'tx')
  call assert_equal(18, col('.'))
  call feedkeys('h', 'tx')
  call assert_equal(19, col('.'))
  call feedkeys("\<right>", 'tx')
  call assert_equal(18, col('.'))
  call feedkeys("\<left>", 'tx')
  call assert_equal(19, col('.'))
  call feedkeys("\<s-right>", 'tx')
  call assert_equal(13, col('.'))
  call feedkeys("\<c-right>", 'tx')
  call assert_equal(7, col('.'))
  call feedkeys("\<c-left>", 'tx')
  call assert_equal(13, col('.'))
  call feedkeys("\<s-left>", 'tx')
  call assert_equal(19, col('.'))
  call feedkeys("<<", 'tx')
  call assert_equal('	abcde fghij klmnopq',getline(1))
  call feedkeys(">>", 'tx')
  call assert_equal('abcde fghij klmnopq',getline(1))

  " cleanup
  set norl
  bw!
endfunc

func Test_normal54_Ctrl_bsl()
  new
  call setline(1, 'abcdefghijklmn')
  exe "norm! df\<c-\>\<c-n>"
  call assert_equal(['abcdefghijklmn'], getline(1,'$'))
  exe "norm! df\<c-\>\<c-g>"
  call assert_equal(['abcdefghijklmn'], getline(1,'$'))
  exe "norm! df\<c-\>m"
  call assert_equal(['abcdefghijklmn'], getline(1,'$'))

  call setline(2, 'abcdefghijklmnāf')
  norm! 2gg0
  exe "norm! df\<Char-0x101>"
  call assert_equal(['abcdefghijklmn', 'f'], getline(1,'$'))
  norm! 1gg0
  exe "norm! df\<esc>"
  call assert_equal(['abcdefghijklmn', 'f'], getline(1,'$'))

  " clean up
  bw!
endfunc

func Test_normal_large_count()
  " This may fail with 32bit long, how do we detect that?
  new
  normal o
  normal 6666666666dL
  bwipe!
endfunc

func Test_delete_until_paragraph()
  new
  normal grádv}
  call assert_equal('á', getline(1))
  normal grád}
  call assert_equal('', getline(1))
  bwipe!
endfunc

" Test for the gr (virtual replace) command
func Test_gr_command()
  enew!
  " Test for the bug fixed by 7.4.387
  let save_cpo = &cpo
  call append(0, ['First line', 'Second line', 'Third line'])
  exe "normal i\<C-G>u"
  call cursor(2, 1)
  set cpo-=X
  normal 4gro
  call assert_equal('oooond line', getline(2))
  undo
  set cpo+=X
  normal 4gro
  call assert_equal('ooooecond line', getline(2))
  let &cpo = save_cpo

  normal! ggvegrx
  call assert_equal('xxxxx line', getline(1))
  exe "normal! gggr\<C-V>122"
  call assert_equal('zxxxx line', getline(1))

  set virtualedit=all
  normal! 15|grl
  call assert_equal('zxxxx line    l', getline(1))
  set virtualedit&
  set nomodifiable
  call assert_fails('normal! grx', 'E21:')
  call assert_fails('normal! gRx', 'E21:')
  call assert_nobeep("normal! gr\<Esc>")
  set modifiable&

  call assert_nobeep("normal! gr\<Esc>")
  call assert_nobeep("normal! cgr\<Esc>")
  call assert_beeps("normal! cgrx")

  call assert_equal('zxxxx line    l', getline(1))
  exe "normal! 2|gr\<C-V>\<Esc>"
  call assert_equal("z\<Esc>xx line    l", getline(1))

  call setline(1, 'abcdef')
  exe "normal! 0gr\<C-O>lx"
  call assert_equal("\<C-O>def", getline(1))

  call setline(1, 'abcdef')
  exe "normal! 0gr\<C-G>lx"
  call assert_equal("\<C-G>def", getline(1))

  bwipe!
endfunc

func Test_nv_hat_count()
  %bwipeout!
  let l:nr = bufnr('%') + 1
  call assert_fails(':execute "normal! ' . l:nr . '\<C-^>"', 'E92:')

  edit Xfoo
  let l:foo_nr = bufnr('Xfoo')

  edit Xbar
  let l:bar_nr = bufnr('Xbar')

  " Make sure we are not just using the alternate file.
  edit Xbaz

  call feedkeys(l:foo_nr . "\<C-^>", 'tx')
  call assert_equal('Xfoo', fnamemodify(bufname('%'), ':t'))

  call feedkeys(l:bar_nr . "\<C-^>", 'tx')
  call assert_equal('Xbar', fnamemodify(bufname('%'), ':t'))

  %bwipeout!
endfunc

func Test_message_when_using_ctrl_c()
  " Make sure no buffers are changed.
  %bwipe!

  exe "normal \<C-C>"
  call assert_match("Type  :qa  and press <Enter> to exit Nvim", Screenline(&lines))

  new
  cal setline(1, 'hi!')
  exe "normal \<C-C>"
  call assert_match("Type  :qa!  and press <Enter> to abandon all changes and exit Nvim", Screenline(&lines))

  bwipe!
endfunc

func Test_mode_updated_after_ctrl_c()
  CheckScreendump

  let buf = RunVimInTerminal('', {'rows': 5})
  call term_sendkeys(buf, "i")
  call term_sendkeys(buf, "\<C-O>")
  " wait a moment so that the "-- (insert) --" message is displayed
  call TermWait(buf, 50)
  call term_sendkeys(buf, "\<C-C>")
  call VerifyScreenDump(buf, 'Test_mode_updated_1', {})

  call StopVimInTerminal(buf)
endfunc

" Test for '[m', ']m', '[M' and ']M'
" Jumping to beginning and end of methods in Java-like languages
func Test_java_motion()
  new
  call assert_beeps('normal! [m')
  call assert_beeps('normal! ]m')
  call assert_beeps('normal! [M')
  call assert_beeps('normal! ]M')
  let lines =<< trim [CODE]
	Piece of Java
	{
		tt m1 {
			t1;
		} e1

		tt m2 {
			t2;
		} e2

		tt m3 {
			if (x)
			{
				t3;
			}
		} e3
	}
  [CODE]
  call setline(1, lines)

  normal gg

  normal 2]maA
  call assert_equal("\ttt m1 {A", getline('.'))
  call assert_equal([3, 9, 16], [line('.'), col('.'), virtcol('.')])

  normal j]maB
  call assert_equal("\ttt m2 {B", getline('.'))
  call assert_equal([7, 9, 16], [line('.'), col('.'), virtcol('.')])

  normal ]maC
  call assert_equal("\ttt m3 {C", getline('.'))
  call assert_equal([11, 9, 16], [line('.'), col('.'), virtcol('.')])

  normal [maD
  call assert_equal("\ttt m3 {DC", getline('.'))
  call assert_equal([11, 9, 16], [line('.'), col('.'), virtcol('.')])

  normal k2[maE
  call assert_equal("\ttt m1 {EA", getline('.'))
  call assert_equal([3, 9, 16], [line('.'), col('.'), virtcol('.')])

  normal 3[maF
  call assert_equal("{F", getline('.'))
  call assert_equal([2, 2, 2], [line('.'), col('.'), virtcol('.')])

  normal ]MaG
  call assert_equal("\t}G e1", getline('.'))
  call assert_equal([5, 3, 10], [line('.'), col('.'), virtcol('.')])

  normal j2]MaH
  call assert_equal("\t}H e3", getline('.'))
  call assert_equal([16, 3, 10], [line('.'), col('.'), virtcol('.')])

  normal ]M]M
  normal aI
  call assert_equal("}I", getline('.'))
  call assert_equal([17, 2, 2], [line('.'), col('.'), virtcol('.')])

  normal 2[MaJ
  call assert_equal("\t}JH e3", getline('.'))
  call assert_equal([16, 3, 10], [line('.'), col('.'), virtcol('.')])

  normal k[MaK
  call assert_equal("\t}K e2", getline('.'))
  call assert_equal([9, 3, 10], [line('.'), col('.'), virtcol('.')])

  normal 3[MaL
  call assert_equal("{LF", getline('.'))
  call assert_equal([2, 2, 2], [line('.'), col('.'), virtcol('.')])

  call cursor(2, 1)
  call assert_beeps('norm! 5]m')

  " jumping to a method in a fold should open the fold
  6,10fold
  call feedkeys("gg3]m", 'xt')
  call assert_equal([7, 8, 15], [line('.'), col('.'), virtcol('.')])
  call assert_equal(-1, foldclosedend(7))

  bwipe!
endfunc

" Tests for g cmds
func Test_normal_gdollar_cmd()
  call Setup_NewWindow()
  " Make long lines that will wrap
  %s/$/\=repeat(' foobar', 10)/
  20vsp
  set wrap
  " Test for g$ with count
  norm! gg
  norm! 0vg$y
  call assert_equal(20, col("'>"))
  call assert_equal('1 foobar foobar foob', getreg(0))
  norm! gg
  norm! 0v4g$y
  call assert_equal(72, col("'>"))
  call assert_equal('1 foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar'.."\n", getreg(0))
  norm! gg
  norm! 0v6g$y
  call assert_equal(40, col("'>"))
  call assert_equal('1 foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar'.. "\n"..
		  \ '2 foobar foobar foobar foobar foobar foo', getreg(0))
  set nowrap
  " clean up
  norm! gg
  norm! 0vg$y
  call assert_equal(20, col("'>"))
  call assert_equal('1 foobar foobar foob', getreg(0))
  norm! gg
  norm! 0v4g$y
  call assert_equal(20, col("'>"))
  call assert_equal('1 foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar'.. "\n"..
                 \  '2 foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar'.. "\n"..
                 \  '3 foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar'.. "\n"..
                 \  '4 foobar foobar foob', getreg(0))
  norm! gg
  norm! 0v6g$y
  call assert_equal(20, col("'>"))
  call assert_equal('1 foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar'.. "\n"..
                 \  '2 foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar'.. "\n"..
                 \  '3 foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar'.. "\n"..
                 \  '4 foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar'.. "\n"..
                 \  '5 foobar foobar foobar foobar foobar foobar foobar foobar foobar foobar'.. "\n"..
                 \  '6 foobar foobar foob', getreg(0))
  " Move to last line, also down movement is not possible, should still move
  " the cursor to the last visible char
  norm! G
  norm! 0v6g$y
  call assert_equal(20, col("'>"))
  call assert_equal('100 foobar foobar fo', getreg(0))
  bw!
endfunc

func Test_normal_gk_gj()
  " needs 80 column new window
  new
  vert 80new
  call assert_beeps('normal gk')
  put =[repeat('x',90)..' {{{1', 'x {{{1']
  norm! gk
  " In a 80 column wide terminal the window will be only 78 char
  " (because Vim will leave space for the other window),
  " but if the terminal is larger, it will be 80 chars, so verify the
  " cursor column correctly.
  call assert_equal(winwidth(0)+1, col('.'))
  call assert_equal(winwidth(0)+1, virtcol('.'))
  norm! j
  call assert_equal(6, col('.'))
  call assert_equal(6, virtcol('.'))
  norm! gk
  call assert_equal(95, col('.'))
  call assert_equal(95, virtcol('.'))
  %bw!

  " needs 80 column new window
  new
  vert 80new
  call assert_beeps('normal gj')
  set number
  set numberwidth=10
  set cpoptions+=n
  put =[repeat('0',90), repeat('1',90)]
  norm! 075l
  call assert_equal(76, col('.'))
  norm! gk
  call assert_equal(1, col('.'))
  norm! gk
  call assert_equal(76, col('.'))
  norm! gk
  call assert_equal(1, col('.'))
  norm! gj
  call assert_equal(76, col('.'))
  norm! gj
  call assert_equal(1, col('.'))
  norm! gj
  call assert_equal(76, col('.'))
  " When 'nowrap' is set, gk and gj behave like k and j
  set nowrap
  normal! gk
  call assert_equal([2, 76], [line('.'), col('.')])
  normal! gj
  call assert_equal([3, 76], [line('.'), col('.')])
  %bw!
  set cpoptions& number& numberwidth& wrap&
endfunc

" Test for using : to run a multi-line Ex command in operator pending mode
func Test_normal_yank_with_excmd()
  new
  call setline(1, ['foo', 'bar', 'baz'])
  let @a = ''
  call feedkeys("\"ay:if v:true\<CR>normal l\<CR>endif\<CR>", 'xt')
  call assert_equal('f', @a)

  bwipe!
endfunc

" Test for supplying a count to a normal-mode command across a cursorhold call
func Test_normal_cursorhold_with_count()
  throw 'Skipped: Nvim removed <CursorHold> key'
  func s:cHold()
    let g:cHold_Called += 1
  endfunc
  new
  augroup normalcHoldTest
    au!
    au CursorHold <buffer> call s:cHold()
  augroup END
  let g:cHold_Called = 0
  call feedkeys("3\<CursorHold>2ix", 'xt')
  call assert_equal(1, g:cHold_Called)
  call assert_equal(repeat('x', 32), getline(1))
  augroup normalcHoldTest
    au!
  augroup END
  au! normalcHoldTest

  bwipe!
  delfunc s:cHold
endfunc

" Test for using a count and a command with CTRL-W
func Test_wincmd_with_count()
  call feedkeys("\<C-W>12n", 'xt')
  call assert_equal(12, winheight(0))
endfunc

" Test for 'b', 'B' 'ge' and 'gE' commands
func Test_horiz_motion()
  new
  normal! gg
  call assert_beeps('normal! b')
  call assert_beeps('normal! B')
  call assert_beeps('normal! gE')
  call assert_beeps('normal! ge')
  " <S-Backspace> moves one word left and <C-Backspace> moves one WORD left
  call setline(1, 'one ,two ,three')
  exe "normal! $\<S-BS>"
  call assert_equal(11, col('.'))
  exe "normal! $\<C-BS>"
  call assert_equal(10, col('.'))

  bwipe!
endfunc

" Test for using a ":" command in operator pending mode
func Test_normal_colon_op()
  new
  call setline(1, ['one', 'two'])
  call assert_beeps("normal! Gc:d\<CR>")
  call assert_equal(['one'], getline(1, '$'))

  call setline(1, ['one…two…three!'])
  normal! $
  " Using ":" as a movement is characterwise exclusive
  call feedkeys("d:normal! F…\<CR>", 'xt')
  call assert_equal(['one…two!'], getline(1, '$'))
  " Check that redoing a command with 0x80 bytes works
  call feedkeys('.', 'xt')
  call assert_equal(['one!'], getline(1, '$'))

  call setline(1, ['one', 'two', 'three', 'four', 'five'])
  " Add this to the command history
  call feedkeys(":normal! G0\<CR>", 'xt')
  " Use :normal! with control characters in operator pending mode
  call feedkeys("d:normal! \<C-V>\<C-P>\<C-V>\<C-P>\<CR>", 'xt')
  call assert_equal(['one', 'two', 'five'], getline(1, '$'))
  " Check that redoing a command with control characters works
  call feedkeys('.', 'xt')
  call assert_equal(['five'], getline(1, '$'))

  bwipe!
endfunc

" Test for d and D commands
func Test_normal_delete_cmd()
  new
  " D in an empty line
  call setline(1, '')
  normal D
  call assert_equal('', getline(1))
  " D in an empty line in virtualedit mode
  set virtualedit=all
  normal D
  call assert_equal('', getline(1))
  set virtualedit&
  " delete to a readonly register
  call setline(1, ['abcd'])
  call assert_beeps('normal ":d2l')

  " D and d with 'nomodifiable'
  call setline(1, ['abcd'])
  setlocal nomodifiable
  call assert_fails('normal D', 'E21:')
  call assert_fails('normal d$', 'E21:')

  bwipe!
endfunc

" Test for deleting or changing characters across lines with 'whichwrap'
" containing 's'. Should count <EOL> as one character.
func Test_normal_op_across_lines()
  new
  set whichwrap&
  call setline(1, ['one two', 'three four'])
  exe "norm! $3d\<Space>"
  call assert_equal(['one twhree four'], getline(1, '$'))

  call setline(1, ['one two', 'three four'])
  exe "norm! $3c\<Space>x"
  call assert_equal(['one twxhree four'], getline(1, '$'))

  set whichwrap+=l
  call setline(1, ['one two', 'three four'])
  exe "norm! $3x"
  call assert_equal(['one twhree four'], getline(1, '$'))

  bwipe!
  set whichwrap&
endfunc

" Test for 'w' and 'b' commands
func Test_normal_word_move()
  new
  call setline(1, ['foo bar a', '', 'foo bar b'])
  " copy a single character word at the end of a line
  normal 1G$yw
  call assert_equal('a', @")
  " copy a single character word at the end of a file
  normal G$yw
  call assert_equal('b', @")
  " check for a word movement handling an empty line properly
  normal 1G$vwy
  call assert_equal("a\n\n", @")

  " copy using 'b' command
  %d
  " non-empty blank line at the start of file
  call setline(1, ['  ', 'foo bar'])
  normal 2Gyb
  call assert_equal("  \n", @")
  " try to copy backwards from the start of the file
  call setline(1, ['one two', 'foo bar'])
  call assert_beeps('normal ggyb')
  " 'b' command should stop at an empty line
  call setline(1, ['one two', '', 'foo bar'])
  normal 3Gyb
  call assert_equal("\n", @")
  normal 3Gy2b
  call assert_equal("two\n", @")
  " 'b' command should not stop at a non-empty blank line
  call setline(1, ['one two', '  ', 'foo bar'])
  normal 3Gyb
  call assert_equal("two\n  ", @")

  bwipe!
endfunc

" Test for 'scrolloff' with a long line that doesn't fit in the screen
func Test_normal_scrolloff()
  10new
  60vnew
  call setline(1, ' 1 ' .. repeat('a', 57)
             \ .. ' 2 ' .. repeat('b', 57)
             \ .. ' 3 ' .. repeat('c', 57)
             \ .. ' 4 ' .. repeat('d', 57)
             \ .. ' 5 ' .. repeat('e', 57)
             \ .. ' 6 ' .. repeat('f', 57)
             \ .. ' 7 ' .. repeat('g', 57)
             \ .. ' 8 ' .. repeat('h', 57)
             \ .. ' 9 ' .. repeat('i', 57)
             \ .. '10 ' .. repeat('j', 57)
             \ .. '11 ' .. repeat('k', 57)
             \ .. '12 ' .. repeat('l', 57)
             \ .. '13 ' .. repeat('m', 57)
             \ .. '14 ' .. repeat('n', 57)
             \ .. '15 ' .. repeat('o', 57)
             \ .. '16 ' .. repeat('p', 57)
             \ .. '17 ' .. repeat('q', 57)
             \ .. '18 ' .. repeat('r', 57)
             \ .. '19 ' .. repeat('s', 57)
             \ .. '20 ' .. repeat('t', 57)
             \ .. '21 ' .. repeat('u', 57)
             \ .. '22 ' .. repeat('v', 57)
             \ .. '23 ' .. repeat('w', 57)
             \ .. '24 ' .. repeat('x', 57)
             \ .. '25 ' .. repeat('y', 57)
             \ .. '26 ' .. repeat('z', 57)
             \ )
  set scrolloff=10
  normal gg10gj
  call assert_equal(6, winline())
  normal 10gj
  call assert_equal(6, winline())
  normal 10gk
  call assert_equal(6, winline())
  normal 0
  call assert_equal(1, winline())
  normal $
  call assert_equal(10, winline())

  set scrolloff&
  bwipe!
endfunc

" Test for vertical scrolling with CTRL-F and CTRL-B with a long line
func Test_normal_vert_scroll_longline()
  10new
  80vnew
  call setline(1, range(1, 10))
  call append(5, repeat('a', 1000))
  exe "normal gg\<C-F>"
  call assert_equal(6, line('.'))
  exe "normal \<C-F>\<C-F>"
  call assert_equal(11, line('.'))
  call assert_equal(1, winline())
  exe "normal \<C-B>"
  call assert_equal(11, line('.'))
  call assert_equal(5, winline())
  exe "normal \<C-B>\<C-B>"
  call assert_equal(5, line('.'))
  call assert_equal(5, winline())

  bwipe!
endfunc

" Test for jumping in a file using %
func Test_normal_percent_jump()
  new
  call setline(1, range(1, 100))

  " jumping to a folded line should open the fold
  25,75fold
  call feedkeys('50%', 'xt')
  call assert_equal(50, line('.'))
  call assert_equal(-1, foldclosedend(50))

  bwipe!
endfunc

" Test for << and >> commands to shift text by 'shiftwidth'
func Test_normal_shift_rightleft()
  new
  call setline(1, ['one', '', "\t", '  two', "\tthree", '      four'])
  set shiftwidth=2 tabstop=8
  normal gg6>>
  call assert_equal(['  one', '', "\t  ", '    two', "\t  three", "\tfour"],
        \ getline(1, '$'))
  normal ggVG2>>
  call assert_equal(['      one', '', "\t      ", "\ttwo",
        \ "\t      three", "\t    four"], getline(1, '$'))
  normal gg6<<
  call assert_equal(['    one', '', "\t    ", '      two', "\t    three",
        \ "\t  four"], getline(1, '$'))
  normal ggVG2<<
  call assert_equal(['one', '', "\t", '  two', "\tthree", '      four'],
        \ getline(1, '$'))
  set shiftwidth& tabstop&
  bw!
endfunc

" Some commands like yy, cc, dd, >>, << and !! accept a count after
" typing the first letter of the command.
func Test_normal_count_after_operator()
  new
  setlocal shiftwidth=4 tabstop=8 autoindent
  call setline(1, ['one', 'two', 'three', 'four', 'five'])
  let @a = ''
  normal! j"ay4y
  call assert_equal("two\nthree\nfour\nfive\n", @a)
  normal! 3G>2>
  call assert_equal(['one', 'two', '    three', '    four', 'five'],
        \ getline(1, '$'))
  exe "normal! 3G0c2cred\nblue"
  call assert_equal(['one', 'two', '    red', '    blue', 'five'],
        \ getline(1, '$'))
  exe "normal! gg<8<"
  call assert_equal(['one', 'two', 'red', 'blue', 'five'],
        \ getline(1, '$'))
  exe "normal! ggd3d"
  call assert_equal(['blue', 'five'], getline(1, '$'))
  call setline(1, range(1, 4))
  call feedkeys("gg!3!\<C-B>\"\<CR>", 'xt')
  call assert_equal('".,.+2!', @:)
  call feedkeys("gg!1!\<C-B>\"\<CR>", 'xt')
  call assert_equal('".!', @:)
  call feedkeys("gg!9!\<C-B>\"\<CR>", 'xt')
  call assert_equal('".,$!', @:)
  bw!
endfunc

func Test_normal_gj_on_6_cell_wide_unprintable_char()
  new | 25vsp
  let text='1 foooooooo ar e  ins​zwe1 foooooooo ins​zwei' .
         \ ' i drei vier fünf sechs sieben acht un zehn elf zwöfl' .
         \ ' dreizehn v ierzehn fünfzehn'
  put =text
  call cursor(2,1)
  norm! gj
  call assert_equal([0,2,25,0], getpos('.'))
  bw!
endfunc

func Test_normal_count_out_of_range()
  new
  call setline(1, 'text')
  normal 44444444444|
  call assert_equal(999999999, v:count)
  normal 444444444444|
  call assert_equal(999999999, v:count)
  normal 4444444444444|
  call assert_equal(999999999, v:count)
  normal 4444444444444444444|
  call assert_equal(999999999, v:count)

  normal 9y99999999|
  call assert_equal(899999991, v:count)
  normal 10y99999999|
  call assert_equal(999999999, v:count)
  normal 44444444444y44444444444|
  call assert_equal(999999999, v:count)
  bwipe!
endfunc

" Test that mouse shape is restored to Normal mode after failed "c" operation.
func Test_mouse_shape_after_failed_change()
  CheckFeature mouseshape
  CheckCanRunGui

  let lines =<< trim END
    vim9script
    set mouseshape+=o:busy
    setlocal nomodifiable
    var mouse_shapes = []

    feedkeys('c')
    timer_start(50, (_) => {
      mouse_shapes += [getmouseshape()]
      timer_start(50, (_) => {
        feedkeys('c')
        timer_start(50, (_) => {
          mouse_shapes += [getmouseshape()]
          timer_start(50, (_) => {
            writefile(mouse_shapes, 'Xmouseshapes')
            quit
          })
        })
      })
    })
  END
  call writefile(lines, 'Xmouseshape.vim', 'D')
  call RunVim([], [], "-g -S Xmouseshape.vim")
  call WaitForAssert({-> assert_equal(['busy', 'arrow'], readfile('Xmouseshapes'))}, 300)

  call delete('Xmouseshapes')
endfunc

" Test that mouse shape is restored to Normal mode after cancelling "gr".
func Test_mouse_shape_after_cancelling_gr()
  CheckFeature mouseshape
  CheckCanRunGui

  let lines =<< trim END
    vim9script
    var mouse_shapes = []

    feedkeys('gr')
    timer_start(50, (_) => {
      mouse_shapes += [getmouseshape()]
      timer_start(50, (_) => {
        feedkeys("\<Esc>")
        timer_start(50, (_) => {
          mouse_shapes += [getmouseshape()]
          timer_start(50, (_) => {
            writefile(mouse_shapes, 'Xmouseshapes')
            quit
          })
        })
      })
    })
  END
  call writefile(lines, 'Xmouseshape.vim', 'D')
  call RunVim([], [], "-g -S Xmouseshape.vim")
  call WaitForAssert({-> assert_equal(['beam', 'arrow'], readfile('Xmouseshapes'))}, 300)

  call delete('Xmouseshapes')
endfunc

" Test that "j" does not skip lines when scrolling below botline and
" 'foldmethod' is not "manual".
func Test_normal_j_below_botline()
  CheckScreendump

  let lines =<< trim END
    set number foldmethod=diff scrolloff=0
    call setline(1, map(range(1, 9), 'repeat(v:val, 200)'))
    norm Lj
  END
  call writefile(lines, 'XNormalJBelowBotline', 'D')
  let buf = RunVimInTerminal('-S XNormalJBelowBotline', #{rows: 19, cols: 40})

  call VerifyScreenDump(buf, 'Test_normal_j_below_botline', {})

  call StopVimInTerminal(buf)
endfunc

" Test for r (replace) command with CTRL_V and CTRL_Q
func Test_normal_r_ctrl_v_cmd()
  new
  call append(0, 'This is a simple test: abcd')
  exe "norm! 1gg$r\<C-V>\<C-V>"
  call assert_equal(['This is a simple test: abc', ''], getline(1,'$'))
  exe "norm! 1gg$hr\<C-Q>\<C-Q>"
  call assert_equal(['This is a simple test: ab', ''], getline(1,'$'))
  exe "norm! 1gg$2hr\<C-V>x7e"
  call assert_equal(['This is a simple test: a~', ''], getline(1,'$'))
  exe "norm! 1gg$3hr\<C-Q>x7e"
  call assert_equal(['This is a simple test: ~~', ''], getline(1,'$'))

  if &encoding == 'utf-8'
    exe "norm! 1gg$4hr\<C-V>u20ac"
    call assert_equal(['This is a simple test:€~~', ''], getline(1,'$'))
    exe "norm! 1gg$5hr\<C-Q>u20ac"
    call assert_equal(['This is a simple test€€~~', ''], getline(1,'$'))
    exe "norm! 1gg0R\<C-V>xff WAS  \<esc>"
    call assert_equal(['ÿ WAS   a simple test€€~~', ''], getline(1,'$'))
    exe "norm! 1gg0elR\<C-Q>xffNOT\<esc>"
    call assert_equal(['ÿ WASÿNOT simple test€€~~', ''], getline(1,'$'))
  endif

  call setline(1, 'This is a simple test: abcd')
  exe "norm! 1gg$gr\<C-V>\<C-V>"
  call assert_equal(['This is a simple test: abc', ''], getline(1,'$'))
  exe "norm! 1gg$hgr\<C-Q>\<C-Q>"
  call assert_equal(['This is a simple test: ab ', ''], getline(1,'$'))
  exe "norm! 1gg$2hgr\<C-V>x7e"
  call assert_equal(['This is a simple test: a~ ', ''], getline(1,'$'))
  exe "norm! 1gg$3hgr\<C-Q>x7e"
  call assert_equal(['This is a simple test: ~~ ', ''], getline(1,'$'))

  " clean up
  bw!
endfunc

" Test clicking on a TAB or an unprintable character in Normal mode
func Test_normal_click_on_ctrl_char()
  let save_mouse = &mouse
  set mouse=a
  new

  call setline(1, "a\<Tab>b\<C-K>c")
  redraw
  call Ntest_setmouse(1, 1)
  call feedkeys("\<LeftMouse>", 'xt')
  call assert_equal([0, 1, 1, 0, 1], getcurpos())
  call Ntest_setmouse(1, 2)
  call feedkeys("\<LeftMouse>", 'xt')
  call assert_equal([0, 1, 2, 0, 2], getcurpos())
  call Ntest_setmouse(1, 3)
  call feedkeys("\<LeftMouse>", 'xt')
  call assert_equal([0, 1, 2, 0, 3], getcurpos())
  call Ntest_setmouse(1, 7)
  call feedkeys("\<LeftMouse>", 'xt')
  call assert_equal([0, 1, 2, 0, 7], getcurpos())
  call Ntest_setmouse(1, 8)
  call feedkeys("\<LeftMouse>", 'xt')
  call assert_equal([0, 1, 2, 0, 8], getcurpos())
  call Ntest_setmouse(1, 9)
  call feedkeys("\<LeftMouse>", 'xt')
  call assert_equal([0, 1, 3, 0, 9], getcurpos())
  call Ntest_setmouse(1, 10)
  call feedkeys("\<LeftMouse>", 'xt')
  call assert_equal([0, 1, 4, 0, 10], getcurpos())
  call Ntest_setmouse(1, 11)
  call feedkeys("\<LeftMouse>", 'xt')
  call assert_equal([0, 1, 4, 0, 11], getcurpos())
  call Ntest_setmouse(1, 12)
  call feedkeys("\<LeftMouse>", 'xt')
  call assert_equal([0, 1, 5, 0, 12], getcurpos())
  call Ntest_setmouse(1, 13)
  call feedkeys("\<LeftMouse>", 'xt')
  call assert_equal([0, 1, 5, 0, 13], getcurpos())

  bwipe!
  let &mouse = save_mouse
endfunc

" Test clicking on a double-width character in Normal mode
func Test_normal_click_on_double_width_char()
  let save_mouse = &mouse
  set mouse=a
  new

  call setline(1, "口口")
  redraw
  call Ntest_setmouse(1, 1)
  call feedkeys("\<LeftMouse>", 'xt')
  call assert_equal([0, 1, 1, 0, 1], getcurpos())
  call Ntest_setmouse(1, 2)
  call feedkeys("\<LeftMouse>", 'xt')
  call assert_equal([0, 1, 1, 0, 2], getcurpos())
  call Ntest_setmouse(1, 3)
  call feedkeys("\<LeftMouse>", 'xt')
  call assert_equal([0, 1, 4, 0, 3], getcurpos())
  call Ntest_setmouse(1, 4)
  call feedkeys("\<LeftMouse>", 'xt')
  call assert_equal([0, 1, 4, 0, 4], getcurpos())

  bwipe!
  let &mouse = save_mouse
endfunc

func Test_normal_click_on_empty_line()
  let save_mouse = &mouse
  set mouse=a
  botright new
  call setline(1, ['', '', ''])
  let row = win_screenpos(0)[0] + 2
  20vsplit
  redraw

  call Ntest_setmouse(row, 1)
  call feedkeys("\<LeftMouse>", 'xt')
  call assert_equal([0, 3, 1, 0, 1], getcurpos())
  call Ntest_setmouse(row, 2)
  call feedkeys("\<LeftMouse>", 'xt')
  call assert_equal([0, 3, 1, 0, 2], getcurpos())
  call Ntest_setmouse(row, 10)
  call feedkeys("\<LeftMouse>", 'xt')
  call assert_equal([0, 3, 1, 0, 10], getcurpos())

  call Ntest_setmouse(row, 21 + 1)
  call feedkeys("\<LeftMouse>", 'xt')
  call assert_equal([0, 3, 1, 0, 1], getcurpos())
  call Ntest_setmouse(row, 21 + 2)
  call feedkeys("\<LeftMouse>", 'xt')
  call assert_equal([0, 3, 1, 0, 2], getcurpos())
  call Ntest_setmouse(row, 21 + 10)
  call feedkeys("\<LeftMouse>", 'xt')
  call assert_equal([0, 3, 1, 0, 10], getcurpos())

  bwipe!
  let &mouse = save_mouse
endfunc

func Test_normal33_g_cmd_nonblank()
  " Test that g<End> goes to the last non-blank char and g$ to the last
  " visible column
  20vnew
  setlocal nowrap nonumber signcolumn=no
  call setline(1, ['fooo   fooo         fooo   fooo         fooo   fooo         fooo   fooo        '])
  exe "normal 0g\<End>"
  call assert_equal(11, col('.'))
  normal 0g$
  call assert_equal(20, col('.'))
  exe "normal 0g\<kEnd>"
  call assert_equal(11, col('.'))
  setlocal wrap
  exe "normal 0g\<End>"
  call assert_equal(11, col('.'))
  normal 0g$
  call assert_equal(20, col('.'))
  exe "normal 0g\<kEnd>"
  call assert_equal(11, col('.'))
  bw!
endfunc

func Test_normal34_zet_large()
  " shouldn't cause overflow
  norm! z9765405999999999999
endfunc

" Test for { and } paragraph movements in a single line
func Test_brace_single_line()
  new
  call setline(1, ['foobar one two three'])
  1
  norm! 0}

  call assert_equal([0, 1, 20, 0], getpos('.'))
  norm! {
  call assert_equal([0, 1, 1, 0], getpos('.'))
  bw!
endfunc

" Test for Ctrl-B/Ctrl-U in buffer with a single line
func Test_single_line_scroll()
  CheckFeature textprop

  new
  call setline(1, ['foobar one two three'])
  let vt = 'virt_above'
  call prop_type_add(vt, {'highlight': 'IncSearch'})
  call prop_add(1, 0, {'type': vt, 'text': '---', 'text_align': 'above'})
  call cursor(1, 1)

  " Ctrl-B/Ctrl-U scroll up with hidden "above" virtual text.
  set smoothscroll
  exe "normal \<C-E>"
  call assert_notequal(0, winsaveview().skipcol)
  exe "normal \<C-B>"
  call assert_equal(0, winsaveview().skipcol)
  exe "normal \<C-E>"
  call assert_notequal(0, winsaveview().skipcol)
  exe "normal \<C-U>"
  call assert_equal(0, winsaveview().skipcol)

  set smoothscroll&
  bw!
  call prop_type_delete(vt)
endfunc

" Test for zb in buffer with a single line and filler lines
func Test_single_line_filler_zb()
  call setline(1, ['', 'foobar one two three'])
  diffthis
  new
  call setline(1, ['foobar one two three'])
  diffthis

  " zb scrolls to reveal filler lines at the start of the buffer.
  exe "normal \<C-E>zb"
  call assert_equal(1, winsaveview().topfill)

  bw!
endfunc

" Test for Ctrl-U not getting stuck at end of buffer with 'scrolloff'.
func Test_halfpage_scrolloff_eob()
  set scrolloff=5

  call setline(1, range(1, 100))
  exe "norm! Gzz\<C-U>zz"
  call assert_notequal(100, line('.'))

  set scrolloff&
  bwipe!
endfunc

" Test for Ctrl-U/D moving the cursor at the buffer boundaries.
func Test_halfpage_cursor_startend()
  call setline(1, range(1, 100))
  exe "norm! jztj\<C-U>"
  call assert_equal(1, line('.'))
  exe "norm! G\<C-Y>k\<C-D>"
  call assert_equal(100, line('.'))
  bwipe!
endfunc

" Test for Ctrl-F/B moving the cursor to the window boundaries.
func Test_page_cursor_topbot()
  10new
  call setline(1, range(1, 100))
  exe "norm! gg2\<C-F>"
  call assert_equal(17, line('.'))
  exe "norm! \<C-B>"
  call assert_equal(18, line('.'))
  exe "norm! \<C-B>\<C-F>"
  call assert_equal(9, line('.'))
  " Not when already at the start of the buffer.
  exe "norm! ggj\<C-B>"
  call assert_equal(2, line('.'))
  bwipe!
endfunc

" Test for Ctrl-D with long line
func Test_halfpage_longline()
  10new
  40vsplit
  call setline(1, ['long'->repeat(1000), 'short'])
  exe "norm! \<C-D>"
  call assert_equal(2, line('.'))
  bwipe!
endfunc

" Test for Ctrl-E with long line and very narrow window,
" used to cause an infinite loop
func Test_scroll_longline_no_loop()
  4vnew
  setl smoothscroll number showbreak=> scrolloff=2
  call setline(1, repeat(['Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.'], 3))
  exe "normal! \<C-E>"
  bwipe!
endfunc

" Test for go command
func Test_normal_go()
  new
  call setline(1, ['one two three four'])
  call cursor(1, 5)
  norm! dvgo
  call assert_equal('wo three four', getline(1))
  norm! ...
  call assert_equal('three four', getline(1))

  bwipe!
endfunc

" Test for Ctrl-D with 'scrolloff' and narrow window does not get stuck.
func Test_scroll_longline_scrolloff()
  11new
  36vsplit
  set scrolloff=5

  call setline(1, ['']->repeat(5))
  call setline(6, ['foo'->repeat(20)]->repeat(2))
  call setline(8, ['bar'->repeat(30)])
  call setline(9, ['']->repeat(5))
  exe "normal! \<C-D>"
  call assert_equal(6, line('w0'))
  exe "normal! \<C-D>"
  call assert_equal(7, line('w0'))

  set scrolloff&
  bwipe!
endfunc

" vim: shiftwidth=2 sts=2 expandtab nofoldenable
