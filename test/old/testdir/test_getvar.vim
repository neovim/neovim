" Tests for getwinvar(), gettabvar(), gettabwinvar() and get().

func Test_var()
  " Use strings to test for memory leaks.  First, check that in an empty
  " window, gettabvar() returns the correct value
  let t:testvar='abcd'
  call assert_equal('abcd', gettabvar(1, 'testvar'))
  call assert_equal('abcd', gettabvar(1, 'testvar'))

  " test for getwinvar()
  let w:var_str = "Dance"
  let def_str = "Chance"
  call assert_equal('Dance', getwinvar(1, 'var_str'))
  call assert_equal('Dance', getwinvar(1, 'var_str', def_str))
  call assert_equal({'var_str': 'Dance'}, 1->getwinvar(''))
  call assert_equal({'var_str': 'Dance'}, 1->getwinvar('', def_str))
  unlet w:var_str
  call assert_equal('Chance', getwinvar(1, 'var_str', def_str))
  call assert_equal({}, getwinvar(1, ''))
  call assert_equal({}, getwinvar(1, '', def_str))
  call assert_equal('', getwinvar(9, ''))
  call assert_equal('Chance', getwinvar(9, '', def_str))
  call assert_equal(0, getwinvar(1, '&nu'))
  call assert_equal(0, getwinvar(1, '&nu', 1))
  call assert_match(v:t_dict, type(getwinvar(1, '&')))
  call assert_match(v:t_dict, type(getwinvar(1, '&', def_str)))
  call assert_equal('', getwinvar(9, '&'))
  call assert_equal('Chance', getwinvar(9, '&', def_str))
  call assert_equal('', getwinvar(1, '&nux'))
  call assert_equal('Chance', getwinvar(1, '&nux', def_str))
  unlet def_str

  " test for gettabvar()
  tabnew
  tabnew
  let t:var_list = [1, 2, 3]
  let t:other = 777
  let def_list = [4, 5, 6, 7]
  tabrewind
  call assert_equal([1, 2, 3], 3->gettabvar('var_list'))
  call assert_equal([1, 2, 3], gettabvar(3, 'var_list', def_list))
  call assert_equal({'var_list': [1, 2, 3], 'other': 777}, gettabvar(3, ''))
  call assert_equal({'var_list': [1, 2, 3], 'other': 777},
					\ gettabvar(3, '', def_list))

  tablast
  unlet t:var_list
  tabrewind
  call assert_equal([4, 5, 6, 7], gettabvar(3, 'var_list', def_list))
  call assert_equal('', gettabvar(9, ''))
  call assert_equal([4, 5, 6, 7], gettabvar(9, '', def_list))
  call assert_equal('', gettabvar(3, '&nu'))
  call assert_equal([4, 5, 6, 7], gettabvar(3, '&nu', def_list))
  unlet def_list
  tabonly

  " test for gettabwinvar()
  tabnew
  tabnew
  tabprev
  split
  split
  wincmd w
  vert split
  wincmd w
  let w:var_dict = {'dict': 'tabwin'}
  let def_dict = {'dict2': 'newval'}
  wincmd b
  tabrewind
  call assert_equal({'dict': 'tabwin'}, 2->gettabwinvar(3, 'var_dict'))
  call assert_equal({'dict': 'tabwin'},
				\ gettabwinvar(2, 3, 'var_dict', def_dict))
  call assert_equal({'var_dict': {'dict': 'tabwin'}}, gettabwinvar(2, 3, ''))
  call assert_equal({'var_dict': {'dict': 'tabwin'}},
				\ gettabwinvar(2, 3, '', def_dict))

  tabnext
  3wincmd w
  unlet w:var_dict
  tabrewind
  call assert_equal({'dict2': 'newval'},
				\ gettabwinvar(2, 3, 'var_dict', def_dict))
  call assert_equal({}, gettabwinvar(2, 3, ''))
  call assert_equal({}, gettabwinvar(2, 3, '', def_dict))
  call assert_equal("", gettabwinvar(2, 9, ''))
  call assert_equal({'dict2': 'newval'}, gettabwinvar(2, 9, '', def_dict))
  call assert_equal('', gettabwinvar(9, 3, ''))
  call assert_equal({'dict2': 'newval'}, gettabwinvar(9, 3, '', def_dict))

  unlet def_dict

  call assert_match(v:t_dict, type(gettabwinvar(2, 3, '&')))
  call assert_match(v:t_dict, type(gettabwinvar(2, 3, '&', 1)))
  call assert_equal("", gettabwinvar(9, 2020, ''))
  call assert_equal(1, gettabwinvar(9, 2020, '', 1))
  call assert_equal('', gettabwinvar(9, 2020, '&'))
  call assert_equal(1, gettabwinvar(9, 2020, '&', 1))
  call assert_equal('', gettabwinvar(2, 3, '&nux'))
  call assert_equal(1, gettabwinvar(2, 3, '&nux', 1))
  tabonly
endfunc

" It was discovered that "gettabvar()" would fail if called from within the
" tabline when the user closed a window.  This test confirms the fix.
func Test_gettabvar_in_tabline()
  let t:var_str = 'value'

  set tabline=%{assert_equal('value',gettabvar(1,'var_str'))}
  set showtabline=2

  " Simulate the user opening a split (which becomes window #1) and then
  " closing the split, which triggers the redrawing of the tabline.
  leftabove split
  redrawstatus!
  close
  redrawstatus!
endfunc

" Test get() function using default value.

" get({dict}, {key} [, {default}])
func Test_get_dict()
  let d = {'foo': 42}
  call assert_equal(42, get(d, 'foo', 99))
  call assert_equal(999, get(d, 'bar', 999))
endfunc

" get({list}, {idx} [, {default}])
func Test_get_list()
  let l = [1,2,3]
  call assert_equal(1, get(l, 0, 999))
  call assert_equal(3, get(l, -1, 999))
  call assert_equal(999, get(l, 3, 999))
endfunc

" get({blob}, {idx} [, {default}]) - in test_blob.vim

" get({lambda}, {what} [, {default}])
func Test_get_lambda()
  let l:L = {-> 42}
  call assert_match('^<lambda>', get(l:L, 'name'))
  call assert_equal(l:L, get(l:L, 'func'))
  call assert_equal({'lambda has': 'no dict'}, get(l:L, 'dict', {'lambda has': 'no dict'}))
  call assert_equal(0, get(l:L, 'dict'))
  call assert_equal([], get(l:L, 'args'))
endfunc

func s:FooBar()
endfunc

" get({func}, {what} [, {default}])
func Test_get_func()
  let l:F = function('tr')
  call assert_equal('tr', get(l:F, 'name'))
  call assert_equal(l:F, get(l:F, 'func'))
  call assert_equal({'required': 3, 'optional': 0, 'varargs': v:false},
      \ get(l:F, 'arity'))

  let Fb_func = function('s:FooBar')
  call assert_match('<SNR>\d\+_FooBar', get(Fb_func, 'name'))
  call assert_equal({'required': 0, 'optional': 0, 'varargs': v:false},
      \ get(Fb_func, 'arity'))
  let Fb_ref = funcref('s:FooBar')
  call assert_match('<SNR>\d\+_FooBar', get(Fb_ref, 'name'))
  call assert_equal({'required': 0, 'optional': 0, 'varargs': v:false},
      \ get(Fb_ref, 'arity'))

  call assert_equal({'func has': 'no dict'}, get(l:F, 'dict', {'func has': 'no dict'}))
  call assert_equal(0, get(l:F, 'dict'))
  call assert_equal([], get(l:F, 'args'))

  " Nvim doesn't have null functions
  " let NF = test_null_function()
  " call assert_equal('', get(NF, 'name'))
  " call assert_equal(NF, get(NF, 'func'))
  " call assert_equal(0, get(NF, 'dict'))
  " call assert_equal([], get(NF, 'args'))
  " call assert_equal({'required': 0, 'optional': 0, 'varargs': v:false}, get(NF, 'arity'))
endfunc

" get({partial}, {what} [, {default}]) - in test_partial.vim

" vim: shiftwidth=2 sts=2 expandtab
