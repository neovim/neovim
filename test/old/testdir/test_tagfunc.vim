" Test 'tagfunc'

source vim9.vim
source check.vim
source screendump.vim

func TagFunc(pat, flag, info)
  let g:tagfunc_args = [a:pat, a:flag, a:info]
  let tags = []
  for num in range(1,10)
    let tags += [{
          \ 'cmd': '2', 'name': 'nothing'.num, 'kind': 'm',
          \ 'filename': 'Xfile1', 'user_data': 'somedata'.num,
          \}]
  endfor
  return tags
endfunc

func Test_tagfunc()
  set tagfunc=TagFunc
  new Xfile1
  call setline(1, ['empty', 'one()', 'empty'])
  write

  call assert_equal({'cmd': '2', 'static': 0,
        \ 'name': 'nothing2', 'user_data': 'somedata2',
        \ 'kind': 'm', 'filename': 'Xfile1'}, taglist('.')[1])

  call settagstack(win_getid(), {'items': []})

  tag arbitrary
  call assert_equal('arbitrary', g:tagfunc_args[0])
  call assert_equal('', g:tagfunc_args[1])
  call assert_equal('somedata1', gettagstack().items[0].user_data)
  5tag arbitrary
  call assert_equal('arbitrary', g:tagfunc_args[0])
  call assert_equal('', g:tagfunc_args[1])
  call assert_equal('somedata5', gettagstack().items[1].user_data)
  pop
  tag
  call assert_equal('arbitrary', g:tagfunc_args[0])
  call assert_equal('', g:tagfunc_args[1])
  call assert_equal('somedata5', gettagstack().items[1].user_data)

  let g:tagfunc_args=[]
  execute "normal! \<c-]>"
  call assert_equal('one', g:tagfunc_args[0])
  call assert_equal('c', g:tagfunc_args[1])

  let g:tagfunc_args=[]
  execute "tag /foo$"
  call assert_equal('foo$', g:tagfunc_args[0])
  call assert_equal('r', g:tagfunc_args[1])

  set cpt=t
  let g:tagfunc_args=[]
  execute "normal! i\<c-n>\<c-y>"
  call assert_equal('\<\k\k', g:tagfunc_args[0])
  call assert_equal('cir', g:tagfunc_args[1])
  call assert_equal('nothing1', getline('.')[0:7])

  let g:tagfunc_args=[]
  execute "normal! ono\<c-n>\<c-n>\<c-y>"
  call assert_equal('\<no', g:tagfunc_args[0])
  call assert_equal('cir', g:tagfunc_args[1])
  call assert_equal('nothing2', getline('.')[0:7])

  func BadTagFunc1(...)
    return 0
  endfunc
  func BadTagFunc2(...)
    return [1]
  endfunc
  func BadTagFunc3(...)
    return [{'name': 'foo'}]
  endfunc

  for &tagfunc in ['BadTagFunc1', 'BadTagFunc2', 'BadTagFunc3']
    try
      tag nothing
      call assert_false(1, 'tag command should have failed')
    catch
      call assert_exception('E987:')
    endtry
    exe 'delf' &tagfunc
  endfor

  func NullTagFunc(...)
    return v:null
  endfunc
  set tags= tfu=NullTagFunc
  call assert_fails('tag nothing', 'E433:')
  delf NullTagFunc

  bwipe!
  set tags& tfu& cpt&
  call delete('Xfile1')
endfunc

" Test for modifying the tag stack from a tag function and jumping to a tag
" from a tag function
func Test_tagfunc_settagstack()
  func Mytagfunc1(pat, flags, info)
    call settagstack(1, {'tagname' : 'mytag', 'from' : [0, 10, 1, 0]})
    return [{'name' : 'mytag', 'filename' : 'Xtest', 'cmd' : '1'}]
  endfunc
  set tagfunc=Mytagfunc1
  call writefile([''], 'Xtest')
  call assert_fails('tag xyz', 'E986:')

  func Mytagfunc2(pat, flags, info)
    tag test_tag
    return [{'name' : 'mytag', 'filename' : 'Xtest', 'cmd' : '1'}]
  endfunc
  set tagfunc=Mytagfunc2
  call assert_fails('tag xyz', 'E986:')

  call delete('Xtest')
  set tagfunc&
  delfunc Mytagfunc1
  delfunc Mytagfunc2
endfunc

" Script local tagfunc callback function
func s:ScriptLocalTagFunc(pat, flags, info)
  let g:ScriptLocalFuncArgs = [a:pat, a:flags, a:info]
  return v:null
endfunc

" Test for different ways of setting the 'tagfunc' option
func Test_tagfunc_callback()
  func TagFunc1(callnr, pat, flags, info)
    let g:TagFunc1Args = [a:callnr, a:pat, a:flags, a:info]
    return v:null
  endfunc
  func TagFunc2(pat, flags, info)
    let g:TagFunc2Args = [a:pat, a:flags, a:info]
    return v:null
  endfunc

  let lines =<< trim END
    #" Test for using a function name
    LET &tagfunc = 'g:TagFunc2'
    new
    LET g:TagFunc2Args = []
    call assert_fails('tag a10', 'E433:')
    call assert_equal(['a10', '', {}], g:TagFunc2Args)
    bw!

    #" Test for using a function()
    set tagfunc=function('g:TagFunc1',\ [10])
    new
    LET g:TagFunc1Args = []
    call assert_fails('tag a11', 'E433:')
    call assert_equal([10, 'a11', '', {}], g:TagFunc1Args)
    bw!

    #" Using a funcref variable to set 'tagfunc'
    VAR Fn = function('g:TagFunc1', [11])
    LET &tagfunc = Fn
    new
    LET g:TagFunc1Args = []
    call assert_fails('tag a12', 'E433:')
    call assert_equal([11, 'a12', '', {}], g:TagFunc1Args)
    bw!

    #" Using a string(funcref_variable) to set 'tagfunc'
    LET Fn = function('g:TagFunc1', [12])
    LET &tagfunc = string(Fn)
    new
    LET g:TagFunc1Args = []
    call assert_fails('tag a12', 'E433:')
    call assert_equal([12, 'a12', '', {}], g:TagFunc1Args)
    bw!

    #" Test for using a funcref()
    set tagfunc=funcref('g:TagFunc1',\ [13])
    new
    LET g:TagFunc1Args = []
    call assert_fails('tag a13', 'E433:')
    call assert_equal([13, 'a13', '', {}], g:TagFunc1Args)
    bw!

    #" Using a funcref variable to set 'tagfunc'
    LET Fn = funcref('g:TagFunc1', [14])
    LET &tagfunc = Fn
    new
    LET g:TagFunc1Args = []
    call assert_fails('tag a14', 'E433:')
    call assert_equal([14, 'a14', '', {}], g:TagFunc1Args)
    bw!

    #" Using a string(funcref_variable) to set 'tagfunc'
    LET Fn = funcref('g:TagFunc1', [15])
    LET &tagfunc = string(Fn)
    new
    LET g:TagFunc1Args = []
    call assert_fails('tag a14', 'E433:')
    call assert_equal([15, 'a14', '', {}], g:TagFunc1Args)
    bw!

    #" Test for using a lambda function
    VAR optval = "LSTART a, b, c LMIDDLE TagFunc1(16, a, b, c) LEND"
    LET optval = substitute(optval, ' ', '\\ ', 'g')
    exe "set tagfunc=" .. optval
    new
    LET g:TagFunc1Args = []
    call assert_fails('tag a17', 'E433:')
    call assert_equal([16, 'a17', '', {}], g:TagFunc1Args)
    bw!

    #" Set 'tagfunc' to a lambda expression
    LET &tagfunc = LSTART a, b, c LMIDDLE TagFunc1(17, a, b, c) LEND
    new
    LET g:TagFunc1Args = []
    call assert_fails('tag a18', 'E433:')
    call assert_equal([17, 'a18', '', {}], g:TagFunc1Args)
    bw!

    #" Set 'tagfunc' to a string(lambda expression)
    LET &tagfunc = 'LSTART a, b, c LMIDDLE TagFunc1(18, a, b, c) LEND'
    new
    LET g:TagFunc1Args = []
    call assert_fails('tag a18', 'E433:')
    call assert_equal([18, 'a18', '', {}], g:TagFunc1Args)
    bw!

    #" Set 'tagfunc' to a variable with a lambda expression
    VAR Lambda = LSTART a, b, c LMIDDLE TagFunc1(19, a, b, c) LEND
    LET &tagfunc = Lambda
    new
    LET g:TagFunc1Args = []
    call assert_fails("tag a19", "E433:")
    call assert_equal([19, 'a19', '', {}], g:TagFunc1Args)
    bw!

    #" Set 'tagfunc' to a string(variable with a lambda expression)
    LET Lambda = LSTART a, b, c LMIDDLE TagFunc1(20, a, b, c) LEND
    LET &tagfunc = string(Lambda)
    new
    LET g:TagFunc1Args = []
    call assert_fails("tag a19", "E433:")
    call assert_equal([20, 'a19', '', {}], g:TagFunc1Args)
    bw!

    #" Test for using a lambda function with incorrect return value
    LET Lambda = LSTART a, b, c LMIDDLE strlen(a) LEND
    LET &tagfunc = string(Lambda)
    new
    call assert_fails("tag a20", "E987:")
    bw!

    #" Test for clearing the 'tagfunc' option
    set tagfunc=''
    set tagfunc&
    call assert_fails("set tagfunc=function('abc')", "E700:")
    call assert_fails("set tagfunc=funcref('abc')", "E700:")

    #" set 'tagfunc' to a non-existing function
    LET &tagfunc = function('g:TagFunc2', [21])
    LET g:TagFunc2Args = []
    call assert_fails("set tagfunc=function('NonExistingFunc')", 'E700:')
    call assert_fails("LET &tagfunc = function('NonExistingFunc')", 'E700:')
    call assert_fails("tag axb123", 'E426:')
    call assert_equal([], g:TagFunc2Args)
    bw!
  END
  call CheckLegacyAndVim9Success(lines)

  " Test for using a script-local function name
  func s:TagFunc3(pat, flags, info)
    let g:TagFunc3Args = [a:pat, a:flags, a:info]
    return v:null
  endfunc
  set tagfunc=s:TagFunc3
  new
  let g:TagFunc3Args = []
  call assert_fails('tag a21', 'E433:')
  call assert_equal(['a21', '', {}], g:TagFunc3Args)
  bw!
  let &tagfunc = 's:TagFunc3'
  new
  let g:TagFunc3Args = []
  call assert_fails('tag a22', 'E433:')
  call assert_equal(['a22', '', {}], g:TagFunc3Args)
  bw!
  delfunc s:TagFunc3

  " invalid return value
  let &tagfunc = "{a -> 'abc'}"
  call assert_fails("echo taglist('a')", "E987:")

  " Using Vim9 lambda expression in legacy context should fail
  " set tagfunc=(a,\ b,\ c)\ =>\ g:TagFunc1(21,\ a,\ b,\ c)
  new
  let g:TagFunc1Args = []
  " call assert_fails("tag a17", "E117:")
  call assert_equal([], g:TagFunc1Args)
  bw!

  " Test for using a script local function
  set tagfunc=<SID>ScriptLocalTagFunc
  new
  let g:ScriptLocalFuncArgs = []
  call assert_fails('tag a15', 'E433:')
  call assert_equal(['a15', '', {}], g:ScriptLocalFuncArgs)
  bw!

  " Test for using a script local funcref variable
  let Fn = function("s:ScriptLocalTagFunc")
  let &tagfunc= Fn
  new
  let g:ScriptLocalFuncArgs = []
  call assert_fails('tag a16', 'E433:')
  call assert_equal(['a16', '', {}], g:ScriptLocalFuncArgs)
  bw!

  " Test for using a string(script local funcref variable)
  let Fn = function("s:ScriptLocalTagFunc")
  let &tagfunc= string(Fn)
  new
  let g:ScriptLocalFuncArgs = []
  call assert_fails('tag a16', 'E433:')
  call assert_equal(['a16', '', {}], g:ScriptLocalFuncArgs)
  bw!

  " set 'tagfunc' to a partial with dict. This used to cause a crash.
  func SetTagFunc()
    let params = {'tagfn': function('g:DictTagFunc')}
    let &tagfunc = params.tagfn
  endfunc
  func g:DictTagFunc(_) dict
  endfunc
  call SetTagFunc()
  new
  call SetTagFunc()
  bw
  call test_garbagecollect_now()
  new
  set tagfunc=
  wincmd w
  set tagfunc=
  :%bw!
  delfunc g:DictTagFunc
  delfunc SetTagFunc

  " Vim9 tests
  let lines =<< trim END
    vim9script

    def Vim9tagFunc(callnr: number, pat: string, flags: string, info: dict<any>): any
      g:Vim9tagFuncArgs = [callnr, pat, flags, info]
      return null
    enddef

    # Test for using a def function with completefunc
    set tagfunc=function('Vim9tagFunc',\ [60])
    new
    g:Vim9tagFuncArgs = []
    assert_fails('tag a10', 'E433:')
    assert_equal([60, 'a10', '', {}], g:Vim9tagFuncArgs)

    # Test for using a global function name
    &tagfunc = g:TagFunc2
    new
    g:TagFunc2Args = []
    assert_fails('tag a11', 'E433:')
    assert_equal(['a11', '', {}], g:TagFunc2Args)
    bw!

    # Test for using a script-local function name
    def LocalTagFunc(pat: string, flags: string, info: dict<any> ): any
      g:LocalTagFuncArgs = [pat, flags, info]
      return null
    enddef
    &tagfunc = LocalTagFunc
    new
    g:LocalTagFuncArgs = []
    assert_fails('tag a12', 'E433:')
    assert_equal(['a12', '', {}], g:LocalTagFuncArgs)
    bw!
  END
  call CheckScriptSuccess(lines)

  " cleanup
  delfunc TagFunc1
  delfunc TagFunc2
  set tagfunc&
  %bw!
endfunc

func Test_tagfunc_wipes_buffer()
  func g:Tag0unc0(t,f,o)
   bwipe
  endfunc
  set tagfunc=g:Tag0unc0
  new
  cal assert_fails('tag 0', 'E987:')

  delfunc g:Tag0unc0
  set tagfunc=
endfunc

func Test_tagfunc_closes_window()
  split any
  func MytagfuncClose(pat, flags, info)
    close
    return [{'name' : 'mytag', 'filename' : 'Xtest', 'cmd' : '1'}]
  endfunc
  set tagfunc=MytagfuncClose
  call assert_fails('tag xyz', 'E1299:')

  set tagfunc=
endfunc


" vim: shiftwidth=2 sts=2 expandtab
