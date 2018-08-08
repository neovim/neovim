" Tests for getwinvar(), gettabvar() and gettabwinvar().
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
  call assert_equal({'var_str': 'Dance'}, getwinvar(1, ''))
  call assert_equal({'var_str': 'Dance'}, getwinvar(1, '', def_str))
  unlet w:var_str
  call assert_equal('Chance', getwinvar(1, 'var_str', def_str))
  call assert_equal({}, getwinvar(1, ''))
  call assert_equal({}, getwinvar(1, '', def_str))
  call assert_equal('', getwinvar(9, ''))
  call assert_equal('Chance', getwinvar(9, '', def_str))
  call assert_equal(0, getwinvar(1, '&nu'))
  call assert_equal(0, getwinvar(1, '&nu', 1))
  unlet def_str

  " test for gettabvar()
  tabnew
  tabnew
  let t:var_list = [1, 2, 3]
  let t:other = 777
  let def_list = [4, 5, 6, 7]
  tabrewind
  call assert_equal([1, 2, 3], gettabvar(3, 'var_list'))
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
  call assert_equal({'dict': 'tabwin'}, gettabwinvar(2, 3, 'var_dict'))
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
