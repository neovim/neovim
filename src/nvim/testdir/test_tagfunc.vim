" Test 'tagfunc'

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
  call assert_fails('tag nothing', 'E426')
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

" vim: shiftwidth=2 sts=2 expandtab
