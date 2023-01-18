" Tests for the List and Dict types

func TearDown()
  " Run garbage collection after every test
  call test_garbagecollect_now()
endfunc

" Tests for List type

" List creation
func Test_list_create()
  " Creating List directly with different types
  let l = [1, 'as''d', [1, 2, function("strlen")], {'a': 1},]
  call assert_equal("[1, 'as''d', [1, 2, function('strlen')], {'a': 1}]", string(l))
  call assert_equal({'a' : 1}, l[-1])
  call assert_equal(1, l[-4])
  let x = 10
  try
    let x = l[-5]
  catch
    call assert_match('E684:', v:exception)
  endtry
  call assert_equal(10, x)
endfunc

" List slices
func Test_list_slice()
  let l = [1, 'as''d', [1, 2, function("strlen")], {'a': 1},]
  call assert_equal([1, 'as''d', [1, 2, function('strlen')], {'a': 1}], l[:])
  call assert_equal(['as''d', [1, 2, function('strlen')], {'a': 1}], l[1:])
  call assert_equal([1, 'as''d', [1, 2, function('strlen')]], l[:-2])
  call assert_equal([1, 'as''d', [1, 2, function('strlen')], {'a': 1}], l[0:8])
  call assert_equal([], l[8:-1])
  call assert_equal([], l[0:-10])
  " perform an operation on a list slice
  let l = [1, 2, 3]
  let l[:1] += [1, 2]
  let l[2:] -= [1]
  call assert_equal([2, 4, 2], l)
endfunc

" List identity
func Test_list_identity()
  let l = [1, 'as''d', [1, 2, function("strlen")], {'a': 1},]
  let ll = l
  let lx = copy(l)
  call assert_true(l == ll)
  call assert_false(l isnot ll)
  call assert_true(l is ll)
  call assert_true(l == lx)
  call assert_false(l is lx)
  call assert_true(l isnot lx)
endfunc

" removing items with :unlet
func Test_list_unlet()
  let l = [1, 'as''d', [1, 2, function("strlen")], {'a': 1},]
  unlet l[2]
  call assert_equal([1, 'as''d', {'a': 1}], l)
  let l = range(8)
  unlet l[:3]
  unlet l[1:]
  call assert_equal([4], l)

  " removing items out of range: silently skip items that don't exist
  let l = [0, 1, 2, 3]
  call assert_fails('unlet l[2:1]', 'E684')
  let l = [0, 1, 2, 3]
  unlet l[2:2]
  call assert_equal([0, 1, 3], l)
  let l = [0, 1, 2, 3]
  unlet l[2:3]
  call assert_equal([0, 1], l)
  let l = [0, 1, 2, 3]
  unlet l[2:4]
  call assert_equal([0, 1], l)
  let l = [0, 1, 2, 3]
  unlet l[2:5]
  call assert_equal([0, 1], l)
  let l = [0, 1, 2, 3]
  call assert_fails('unlet l[-1:2]', 'E684')
  let l = [0, 1, 2, 3]
  unlet l[-2:2]
  call assert_equal([0, 1, 3], l)
  let l = [0, 1, 2, 3]
  unlet l[-3:2]
  call assert_equal([0, 3], l)
  let l = [0, 1, 2, 3]
  unlet l[-4:2]
  call assert_equal([3], l)
  let l = [0, 1, 2, 3]
  unlet l[-5:2]
  call assert_equal([3], l)
  let l = [0, 1, 2, 3]
  unlet l[-6:2]
  call assert_equal([3], l)
endfunc

" assignment to a list
func Test_list_assign()
  let l = [0, 1, 2, 3]
  let [va, vb] = l[2:3]
  call assert_equal([2, 3], [va, vb])
  call assert_fails('let [va, vb] = l', 'E687')
  call assert_fails('let [va, vb] = l[1:1]', 'E688')
endfunc

" test for range assign
func Test_list_range_assign()
  let l = [0]
  let l[:] = [1, 2]
  call assert_equal([1, 2], l)
  let l[-4:-1] = [5, 6]
  call assert_equal([5, 6], l)
endfunc

" Test removing items in list
func Test_list_func_remove()
  " Test removing 1 element
  let l = [1, 2, 3, 4]
  call assert_equal(1, remove(l, 0))
  call assert_equal([2, 3, 4], l)

  let l = [1, 2, 3, 4]
  call assert_equal(2, remove(l, 1))
  call assert_equal([1, 3, 4], l)

  let l = [1, 2, 3, 4]
  call assert_equal(4, remove(l, -1))
  call assert_equal([1, 2, 3], l)

  " Test removing range of element(s)
  let l = [1, 2, 3, 4]
  call assert_equal([3], remove(l, 2, 2))
  call assert_equal([1, 2, 4], l)

  let l = [1, 2, 3, 4]
  call assert_equal([2, 3], remove(l, 1, 2))
  call assert_equal([1, 4], l)

  let l = [1, 2, 3, 4]
  call assert_equal([2, 3], remove(l, -3, -2))
  call assert_equal([1, 4], l)

  " Test invalid cases
  let l = [1, 2, 3, 4]
  call assert_fails("call remove(l, 5)", 'E684:')
  call assert_fails("call remove(l, 1, 5)", 'E684:')
  call assert_fails("call remove(l, 3, 2)", 'E16:')
  call assert_fails("call remove(1, 0)", 'E896:')
  call assert_fails("call remove(l, l)", 'E745:')
endfunc

" List add() function
func Test_list_add()
  let l = []
  call add(l, 1)
  call add(l, [2, 3])
  call add(l, [])
  call add(l, v:_null_list)
  call add(l, {'k' : 3})
  call add(l, {})
  call add(l, v:_null_dict)
  call assert_equal([1, [2, 3], [], [], {'k' : 3}, {}, {}], l)
  " call assert_equal(1, add(v:_null_list, 4))
endfunc

" Tests for Dictionary type

func Test_dict()
  " Creating Dictionary directly with different types
  let d = {001: 'asd', 'b': [1, 2, function('strlen')], -1: {'a': 1},}
  call assert_equal("{'1': 'asd', 'b': [1, 2, function('strlen')], '-1': {'a': 1}}", string(d))
  call assert_equal('asd', d.1)
  call assert_equal(['-1', '1', 'b'], sort(keys(d)))
  call assert_equal(['asd', [1, 2, function('strlen')], {'a': 1}], values(d))
  let v = []
  for [key, val] in items(d)
    call extend(v, [key, val])
    unlet key val
  endfor
  call assert_equal(['1','asd','b',[1, 2, function('strlen')],'-1',{'a': 1}], v)

  call extend(d, {3:33, 1:99})
  call extend(d, {'b':'bbb', 'c':'ccc'}, "keep")
  call assert_fails("call extend(d, {3:333,4:444}, 'error')", 'E737')
  call assert_equal({'c': 'ccc', '1': 99, 'b': [1, 2, function('strlen')], '3': 33, '-1': {'a': 1}}, d)
  call filter(d, 'v:key =~ ''[ac391]''')
  call assert_equal({'c': 'ccc', '1': 99, '3': 33, '-1': {'a': 1}}, d)

  " duplicate key
  call assert_fails("let d = {'k' : 10, 'k' : 20}", 'E721:')
  " missing comma
  call assert_fails("let d = {'k' : 10 'k' : 20}", 'E722:')
  " missing curly brace
  call assert_fails("let d = {'k' : 10,", 'E723:')
  " invalid key
  call assert_fails('let d = #{++ : 10}', 'E15:')
  " wrong type for key
  call assert_fails('let d={[] : 10}', 'E730:')
  " undefined variable as value
  call assert_fails("let d={'k' : i}", 'E121:')

  " allow key starting with number at the start, not a curly expression
  call assert_equal({'1foo': 77}, #{1foo: 77})

  " #{expr} is not a curly expression
  let x = 'x'
  call assert_equal(#{g: x}, #{g:x})
endfunc

" Dictionary identity
func Test_dict_identity()
  let d = {001: 'asd', 'b': [1, 2, function('strlen')], -1: {'a': 1},}
  let dd = d
  let dx = copy(d)
  call assert_true(d == dd)
  call assert_false(d isnot dd)
  call assert_true(d is dd)
  call assert_true(d == dx)
  call assert_false(d is dx)
  call assert_true(d isnot dx)
endfunc

" removing items with :unlet
func Test_dict_unlet()
  let d = {'b':'bbb', '1': 99, '3': 33, '-1': {'a': 1}}
  unlet d.b
  unlet d[-1]
  call assert_equal({'1': 99, '3': 33}, d)
endfunc

" manipulating a big Dictionary (hashtable.c has a border of 1000 entries)
func Test_dict_big()
  let d = {}
  for i in range(1500)
    let d[i] = 3000 - i
  endfor
  call assert_equal([3000, 2900, 2001, 1600, 1501], [d[0], d[100], d[999], d[1400], d[1499]])
  let str = ''
  try
    let n = d[1500]
  catch
    let str = substitute(v:exception, '\v(.{14}).*( "\d{4}").*', '\1\2', '')
  endtry
  call assert_equal('Vim(let):E716: "1500"', str)

  " lookup each items
  for i in range(1500)
    call assert_equal(3000 - i, d[i])
  endfor
  let i += 1

  " delete even items
  while i >= 2
    let i -= 2
    unlet d[i]
  endwhile
  call assert_equal('NONE', get(d, 1500 - 100, 'NONE'))
  call assert_equal(2999, d[1])

  " delete odd items, checking value, one intentionally wrong
  let d[33] = 999
  let i = 1
  while i < 1500
   if i != 33
     call assert_equal(3000 - i, d[i])
   else
     call assert_equal(999, d[i])
   endif
   unlet d[i]
   let i += 2
  endwhile
  call assert_equal({}, d)
  unlet d
endfunc

" Dictionary function
func Test_dict_func()
  let d = {}
  func d.func(a) dict
    return a:a . len(self.data)
  endfunc
  let d.data = [1,2,3]
  call assert_equal('len: 3', d.func('len: '))
  let x = d.func('again: ')
  call assert_equal('again: 3', x)
  let Fn = d.func
  call assert_equal('xxx3', Fn('xxx'))
endfunc

func Test_dict_assign()
  let d = {}
  let d.1 = 1
  let d._ = 2
  call assert_equal({'1': 1, '_': 2}, d)

  let n = 0
  call assert_fails('let n.key = 3', 'E1203: Dot can only be used on a dictionary: n.key = 3')
endfunc

" Function in script-local List or Dict
func Test_script_local_dict_func()
  let g:dict = {}
  function g:dict.func() dict
    return 'g:dict.func' . self.foo[1] . self.foo[0]('asdf')
  endfunc
  let g:dict.foo = ['-', 2, 3]
  call insert(g:dict.foo, function('strlen'))
  call assert_equal('g:dict.func-4', g:dict.func())
  unlet g:dict
endfunc

" Test removing items in a dictionary
func Test_dict_func_remove()
  let d = {1:'a', 2:'b', 3:'c'}
  call assert_equal('b', remove(d, 2))
  call assert_equal({1:'a', 3:'c'}, d)

  call assert_fails("call remove(d, 1, 2)", 'E118:')
  call assert_fails("call remove(d, 'a')", 'E716:')
  call assert_fails("call remove(d, [])", 'E730:')
endfunc

" Nasty: remove func from Dict that's being called (works)
func Test_dict_func_remove_in_use()
  let d = {1:1}
  func d.func(a)
    return "a:" . a:a
  endfunc
  let expected = 'a:' . string(get(d, 'func'))
  call assert_equal(expected, d.func(string(remove(d, 'func'))))
endfunc

func Test_dict_literal_keys()
  call assert_equal({'one': 1, 'two2': 2, '3three': 3, '44': 4}, #{one: 1, two2: 2, 3three: 3, 44: 4},)

  " why *{} cannot be used
  let blue = 'blue'
  call assert_equal('6', trim(execute('echo 2 *{blue: 3}.blue')))
endfunc

" Nasty: deepcopy() dict that refers to itself (fails when noref used)
func Test_dict_deepcopy()
  let d = {1:1, 2:2}
  let l = [4, d, 6]
  let d[3] = l
  let dc = deepcopy(d)
  call assert_fails('call deepcopy(d, 1)', 'E698:')
  let l2 = [0, l, l, 3]
  let l[1] = l2
  let l3 = deepcopy(l2)
  call assert_true(l3[1] is l3[2])
  call assert_fails("call deepcopy([1, 2], 2)", 'E1023:')
endfunc

" Locked variables
func Test_list_locked_var()
  let expected = [
	      \ [['1000-000', 'ppppppF'],
	      \  ['0000-000', 'ppppppp'],
	      \  ['0000-000', 'ppppppp']],
	      \ [['1000-000', 'ppppppF'],
	      \  ['0000-000', 'ppppppp'],
	      \  ['0000-000', 'ppppppp']],
	      \ [['1100-100', 'ppFppFF'],
	      \  ['0000-000', 'ppppppp'],
	      \  ['0000-000', 'ppppppp']],
	      \ [['1110-110', 'pFFpFFF'],
	      \  ['0010-010', 'pFppFpp'],
	      \  ['0000-000', 'ppppppp']],
	      \ [['1111-111', 'FFFFFFF'],
	      \  ['0011-011', 'FFpFFpp'],
	      \  ['0000-000', 'ppppppp']]
	      \ ]
  for depth in range(5)
    for u in range(3)
      unlet! l
      let l = [0, [1, [2, 3]], {4: 5, 6: {7: 8}}]
      exe "lockvar " . depth . " l"
      if u == 1
        exe "unlockvar l"
      elseif u == 2
        exe "unlockvar " . depth . " l"
      endif
      let ps = islocked("l").islocked("l[1]").islocked("l[1][1]").islocked("l[1][1][0]").'-'.islocked("l[2]").islocked("l[2]['6']").islocked("l[2]['6'][7]")
      call assert_equal(expected[depth][u][0], ps, 'depth: ' .. depth)
      let ps = ''
      try
        let l[1][1][0] = 99
        let ps .= 'p'
      catch
        let ps .= 'F'
      endtry
      try
        let l[1][1] = [99]
        let ps .= 'p'
      catch
        let ps .= 'F'
      endtry
      try
        let l[1] = [99]
        let ps .= 'p'
      catch
        let ps .= 'F'
      endtry
      try
        let l[2]['6'][7] = 99
        let ps .= 'p'
      catch
        let ps .= 'F'
      endtry
      try
        let l[2][6] = {99: 99}
        let ps .= 'p'
      catch
        let ps .= 'F'
      endtry
      try
        let l[2] = {99: 99}
        let ps .= 'p'
      catch
        let ps .= 'F'
      endtry
      try
        let l = [99]
        let ps .= 'p'
      catch
        let ps .= 'F'
      endtry
      call assert_equal(expected[depth][u][1], ps, 'depth: ' .. depth)
    endfor
  endfor
  call assert_fails("let x=islocked('a b')", 'E488:')
  let mylist = [1, 2, 3]
  call assert_fails("let x = islocked('mylist[1:2]')", 'E786:')
  let mydict = {'k' : 'v'}
  call assert_fails("let x = islocked('mydict.a')", 'E716:')
endfunc

" Unletting locked variables
func Test_list_locked_var_unlet()
  let expected = [
	      \ [['1000-000', 'ppppppp'],
	      \  ['0000-000', 'ppppppp'],
	      \  ['0000-000', 'ppppppp']],
	      \ [['1000-000', 'ppFppFp'],
	      \  ['0000-000', 'ppppppp'],
	      \  ['0000-000', 'ppppppp']],
	      \ [['1100-100', 'pFFpFFp'],
	      \  ['0000-000', 'ppppppp'],
	      \  ['0000-000', 'ppppppp']],
	      \ [['1110-110', 'FFFFFFp'],
	      \  ['0010-010', 'FppFppp'],
	      \  ['0000-000', 'ppppppp']],
	      \ [['1111-111', 'FFFFFFp'],
	      \  ['0011-011', 'FppFppp'],
	      \  ['0000-000', 'ppppppp']]
	      \ ]

  for depth in range(5)
    for u in range(3)
      unlet! l
      let l = [0, [1, [2, 3]], {4: 5, 6: {7: 8}}]
      exe "lockvar " . depth . " l"
      if u == 1
        exe "unlockvar l"
      elseif u == 2
        exe "unlockvar " . depth . " l"
      endif
      let ps = islocked("l").islocked("l[1]").islocked("l[1][1]").islocked("l[1][1][0]").'-'.islocked("l[2]").islocked("l[2]['6']").islocked("l[2]['6'][7]")
      call assert_equal(expected[depth][u][0], ps, 'depth: ' .. depth)
      let ps = ''
      try
        unlet l[2]['6'][7]
        let ps .= 'p'
      catch
        let ps .= 'F'
      endtry
      try
        unlet l[2][6]
        let ps .= 'p'
      catch
        let ps .= 'F'
      endtry
      try
        unlet l[2]
        let ps .= 'p'
      catch
        let ps .= 'F'
      endtry
      try
        unlet l[1][1][0]
        let ps .= 'p'
      catch
        let ps .= 'F'
      endtry
      try
        unlet l[1][1]
        let ps .= 'p'
      catch
        let ps .= 'F'
      endtry
      try
        unlet l[1]
        let ps .= 'p'
      catch
        let ps .= 'F'
      endtry
      try
        unlet l
        let ps .= 'p'
      catch
        let ps .= 'F'
      endtry
      call assert_equal(expected[depth][u][1], ps)
    endfor
  endfor
  " Deleting a list range should fail if the range is locked
  let l = [1, 2, 3, 4]
  lockvar l[1:2]
  call assert_fails('unlet l[1:2]', 'E741:')
  unlet l
endfunc

" Locked variables and :unlet or list / dict functions

" No :unlet after lock on dict:
func Test_dict_lock_unlet()
  unlet! d
  let d = {'a': 99, 'b': 100}
  lockvar 1 d
  call assert_fails('unlet d.a', 'E741')
endfunc

" unlet after lock on dict item
func Test_dict_item_lock_unlet()
  unlet! d
  let d = {'a': 99, 'b': 100}
  lockvar d.a
  unlet d.a
  call assert_equal({'b' : 100}, d)
endfunc

" filter() after lock on dict item
func Test_dict_lock_filter()
  unlet! d
  let d = {'a': 99, 'b': 100}
  lockvar d.a
  call filter(d, 'v:key != "a"')
  call assert_equal({'b' : 100}, d)
endfunc

" map() after lock on dict
func Test_dict_lock_map()
  unlet! d
  let d = {'a': 99, 'b': 100}
  lockvar 1 d
  call map(d, 'v:val + 200')
  call assert_equal({'a' : 299, 'b' : 300}, d)
endfunc

" No extend() after lock on dict item
func Test_dict_lock_extend()
  unlet! d
  let d = {'a': 99, 'b': 100}
  lockvar d.a
  call assert_fails("call extend(d, {'a' : 123})", 'E741')
  call assert_equal({'a': 99, 'b': 100}, d)
endfunc

" Cannot use += with a locked dict
func Test_dict_lock_operator()
  unlet! d
  let d = {}
  lockvar d
  call assert_fails("let d += {'k' : 10}", 'E741:')
  unlockvar d
endfunc

" No remove() of write-protected scope-level variable
func Tfunc1(this_is_a_long_parameter_name)
  call assert_fails("call remove(a:, 'this_is_a_long_parameter_name')", 'E742')
endfunc
func Test_dict_scope_var_remove()
  call Tfunc1('testval')
endfunc

" No extend() of write-protected scope-level variable
func Test_dict_scope_var_extend()
  call assert_fails("call extend(a:, {'this_is_a_long_parameter_name': 1234})", 'E742')
endfunc
func Tfunc2(this_is_a_long_parameter_name)
  call assert_fails("call extend(a:, {'this_is_a_long_parameter_name': 1234})", 'E742')
endfunc
func Test_dict_scope_var_extend_overwrite()
  call Tfunc2('testval')
endfunc

" No :unlet of variable in locked scope
func Test_lock_var_unlet()
  let b:testvar = 123
  lockvar 1 b:
  call assert_fails('unlet b:testvar', 'E741:')
  unlockvar 1 b:
  unlet! b:testvar
endfunc

" No :let += of locked list variable
func Test_let_lock_list()
  let l = ['a', 'b', 3]
  lockvar 1 l
  call assert_fails("let l += ['x']", 'E741:')
  call assert_equal(['a', 'b', 3], l)

  unlet l
  let l = [1, 2, 3, 4]
  lockvar! l
  call assert_equal([1, 2, 3, 4], l)
  unlockvar l[1]
  call assert_fails('unlet l[0:1]', 'E741:')
  call assert_equal([1, 2, 3, 4], l)
  call assert_fails('unlet l[1:2]', 'E741:')
  call assert_equal([1, 2, 3, 4], l)
  unlockvar l[1]
  call assert_fails('let l[0:1] = [0, 1]', 'E741:')
  call assert_equal([1, 2, 3, 4], l)
  call assert_fails('let l[1:2] = [0, 1]', 'E741:')
  call assert_equal([1, 2, 3, 4], l)
  unlet l
endfunc

" Locking part of the list
func Test_let_lock_list_items()
  let l = [1, 2, 3, 4]
  lockvar l[2:]
  call assert_equal(0, islocked('l[0]'))
  call assert_equal(1, islocked('l[2]'))
  call assert_equal(1, islocked('l[3]'))
  call assert_fails('let l[2] = 10', 'E741:')
  call assert_fails('let l[3] = 20', 'E741:')
  unlet l
endfunc

" lockvar/islocked() triggering script autoloading
func Test_lockvar_script_autoload()
  let old_rtp = &rtp
  set rtp+=./sautest
  lockvar g:footest#x
  unlockvar g:footest#x
  call assert_equal(-1, 'g:footest#x'->islocked())
  call assert_equal(0, exists('g:footest#x'))
  call assert_equal(1, g:footest#x)
  let &rtp = old_rtp
endfunc

" a:000 function argument test
func s:arg_list_test(...)
  call assert_fails('let a:000 = [1, 2]', 'E46:')
  call assert_fails('let a:000[0] = 9', 'E742:')
  call assert_fails('let a:000[2] = [9, 10]', 'E742:')
  call assert_fails('let a:000[3] = {9 : 10}', 'E742:')

  " now the tests that should pass
  let a:000[2][1] = 9
  call extend(a:000[2], [5, 6])
  let a:000[3][5] = 8
  let a:000[3]['a'] = 12
  call assert_equal([1, 2, [3, 9, 5, 6], {'a': 12, '5': 8}], a:000)
endfunc

func Test_func_arg_list()
  call s:arg_list_test(1, 2, [3, 4], {5: 6})
endfunc

func Test_dict_item_locked()
endfunc

" Tests for reverse(), sort(), uniq()
func Test_reverse_sort_uniq()
  let l = ['-0', 'A11', 2, 2, 'xaaa', 4, 'foo', 'foo6', 'foo', [0, 1, 2], 'x8', [0, 1, 2], 1.5]
  call assert_equal(['-0', 'A11', 2, 'xaaa', 4, 'foo', 'foo6', 'foo', [0, 1, 2], 'x8', [0, 1, 2], 1.5], uniq(copy(l)))
  call assert_equal([1.5, [0, 1, 2], 'x8', [0, 1, 2], 'foo', 'foo6', 'foo', 4, 'xaaa', 2, 2, 'A11', '-0'], reverse(l))
  call assert_equal([1.5, [0, 1, 2], 'x8', [0, 1, 2], 'foo', 'foo6', 'foo', 4, 'xaaa', 2, 2, 'A11', '-0'], reverse(reverse(l)))
  if has('float')
    call assert_equal(['-0', 'A11', 'foo', 'foo', 'foo6', 'x8', 'xaaa', 1.5, 2, 2, 4, [0, 1, 2], [0, 1, 2]], sort(l))
    call assert_equal([[0, 1, 2], [0, 1, 2], 4, 2, 2, 1.5, 'xaaa', 'x8', 'foo6', 'foo', 'foo', 'A11', '-0'], reverse(sort(l)))
    call assert_equal(['-0', 'A11', 'foo', 'foo', 'foo6', 'x8', 'xaaa', 1.5, 2, 2, 4, [0, 1, 2], [0, 1, 2]], sort(reverse(sort(l))))
    call assert_equal(['-0', 'A11', 'foo', 'foo6', 'x8', 'xaaa', 1.5, 2, 4, [0, 1, 2]], uniq(sort(l)))

    let l = [7, 9, 'one', 18, 12, 22, 'two', 10.0e-16, -1, 'three', 0xff, 0.22, 'four']
    call assert_equal([-1, 'one', 'two', 'three', 'four', 1.0e-15, 0.22, 7, 9, 12, 18, 22, 255], sort(copy(l), 'n'))

    let l = [7, 9, 18, 12, 22, 10.0e-16, -1, 0xff, 0, -0, 0.22, 'bar', 'BAR', 'Bar', 'Foo', 'FOO', 'foo', 'FOOBAR', {}, []]
    call assert_equal(['bar', 'BAR', 'Bar', 'Foo', 'FOO', 'foo', 'FOOBAR', -1, 0, 0, 0.22, 1.0e-15, 12, 18, 22, 255, 7, 9, [], {}], sort(copy(l), 1))
    call assert_equal(['bar', 'BAR', 'Bar', 'Foo', 'FOO', 'foo', 'FOOBAR', -1, 0, 0, 0.22, 1.0e-15, 12, 18, 22, 255, 7, 9, [], {}], sort(copy(l), 'i'))
    call assert_equal(['BAR', 'Bar', 'FOO', 'FOOBAR', 'Foo', 'bar', 'foo', -1, 0, 0, 0.22, 1.0e-15, 12, 18, 22, 255, 7, 9, [], {}], sort(copy(l)))
  endif

  call assert_fails('call reverse("")', 'E899:')
  call assert_fails('call uniq([1, 2], {x, y -> []})', 'E745:')
  call assert_fails("call sort([1, 2], function('min'), 1)", "E715:")
  call assert_fails("call sort([1, 2], function('invalid_func'))", "E700:")
  call assert_fails("call sort([1, 2], function('min'))", "E118:")
endfunc

" reduce a list or a blob
func Test_reduce()
  call assert_equal(1, reduce([], { acc, val -> acc + val }, 1))
  call assert_equal(10, reduce([1, 3, 5], { acc, val -> acc + val }, 1))
  call assert_equal(2 * (2 * ((2 * 1) + 2) + 3) + 4, reduce([2, 3, 4], { acc, val -> 2 * acc + val }, 1))
  call assert_equal('a x y z', ['x', 'y', 'z']->reduce({ acc, val -> acc .. ' ' .. val}, 'a'))
  call assert_equal(#{ x: 1, y: 1, z: 1 }, ['x', 'y', 'z']->reduce({ acc, val -> extend(acc, { val: 1 }) }, {}))
  call assert_equal([0, 1, 2, 3], reduce([1, 2, 3], function('add'), [0]))

  let l = ['x', 'y', 'z']
  call assert_equal(42, reduce(l, function('get'), #{ x: #{ y: #{ z: 42 } } }))
  call assert_equal(['x', 'y', 'z'], l)

  call assert_equal(1, reduce([1], { acc, val -> acc + val }))
  call assert_equal('x y z', reduce(['x', 'y', 'z'], { acc, val -> acc .. ' ' .. val }))
  call assert_equal(120, range(1, 5)->reduce({ acc, val -> acc * val }))
  call assert_fails("call reduce([], { acc, val -> acc + val })", 'E998: Reduce of an empty List with no initial value')

  call assert_equal(1, reduce(0z, { acc, val -> acc + val }, 1))
  call assert_equal(1 + 0xaf + 0xbf + 0xcf, reduce(0zAFBFCF, { acc, val -> acc + val }, 1))
  call assert_equal(2 * (2 * 1 + 0xaf) + 0xbf, 0zAFBF->reduce({ acc, val -> 2 * acc + val }, 1))

  call assert_equal(0xff, reduce(0zff, { acc, val -> acc + val }))
  call assert_equal(2 * (2 * 0xaf + 0xbf) + 0xcf, reduce(0zAFBFCF, { acc, val -> 2 * acc + val }))
  call assert_fails("call reduce(0z, { acc, val -> acc + val })", 'E998: Reduce of an empty Blob with no initial value')

  call assert_fails("call reduce({}, { acc, val -> acc + val }, 1)", 'E897:')
  call assert_fails("call reduce(0, { acc, val -> acc + val }, 1)", 'E897:')
  call assert_fails("call reduce('', { acc, val -> acc + val }, 1)", 'E897:')
  call assert_fails("call reduce([1, 2], 'Xdoes_not_exist')", 'E117:')
  call assert_fails("echo reduce(0z01, { acc, val -> 2 * acc + val }, '')", 'E39:')

  let g:lut = [1, 2, 3, 4]
  func EvilRemove()
    call remove(g:lut, 1)
    return 1
  endfunc
  call assert_fails("call reduce(g:lut, { acc, val -> EvilRemove() }, 1)", 'E742:')
  unlet g:lut
  delfunc EvilRemove

  call assert_equal(42, reduce(v:_null_list, function('add'), 42))
  call assert_equal(42, reduce(v:_null_blob, function('add'), 42))
endfunc

" splitting a string to a List using split()
func Test_str_split()
  call assert_equal(['aa', 'bb'], split('  aa  bb '))
  call assert_equal(['aa', 'bb'], split('  aa  bb  ', '\W\+', 0))
  call assert_equal(['', 'aa', 'bb', ''], split('  aa  bb  ', '\W\+', 1))
  call assert_equal(['', '', 'aa', '', 'bb', '', ''], split('  aa  bb  ', '\W', 1))
  call assert_equal(['aa', '', 'bb'], split(':aa::bb:', ':', 0))
  call assert_equal(['', 'aa', '', 'bb', ''], split(':aa::bb:', ':', 1))
  call assert_equal(['aa', '', 'bb', 'cc', ''], split('aa,,bb, cc,', ',\s*', 1))
  call assert_equal(['a', 'b', 'c'], split('abc', '\zs'))
  call assert_equal(['', 'a', '', 'b', '', 'c', ''], split('abc', '\zs', 1))
  call assert_fails("call split('abc', [])", 'E730:')
  call assert_fails("call split('abc', 'b', [])", 'E745:')
  call assert_equal(['abc'], split('abc', '\\%('))
endfunc

" compare recursively linked list and dict
func Test_listdict_compare()
  let l = [1, 2, 3, 4]
  let d = {'1': 1, '2': l, '3': 3}
  let l[1] = d
  call assert_true(l == l)
  call assert_true(d == d)
  call assert_false(l != deepcopy(l))
  call assert_false(d != deepcopy(d))

  " comparison errors
  call assert_fails('echo [1, 2] =~ {}', 'E691:')
  call assert_fails('echo [1, 2] =~ [1, 2]', 'E692:')
  call assert_fails('echo {} =~ 5', 'E735:')
  call assert_fails('echo {} =~ {}', 'E736:')
endfunc

  " compare complex recursively linked list and dict
func Test_listdict_compare_complex()
  let l = []
  call add(l, l)
  let dict4 = {"l": l}
  call add(dict4.l, dict4)
  let lcopy = deepcopy(l)
  let dict4copy = deepcopy(dict4)
  call assert_true(l == lcopy)
  call assert_true(dict4 == dict4copy)
endfunc

func Test_listdict_extend()
  " Test extend() with lists

  " Pass the same List to extend()
  let l = [1, 2, 3]
  call assert_equal([1, 2, 3, 1, 2, 3], extend(l, l))
  call assert_equal([1, 2, 3, 1, 2, 3], l)

  let l = [1, 2, 3]
  call assert_equal([1, 2, 3, 4, 5, 6], extend(l, [4, 5, 6]))
  call assert_equal([1, 2, 3, 4, 5, 6], l)

  let l = [1, 2, 3]
  call extend(l, [4, 5, 6], 0)
  call assert_equal([4, 5, 6, 1, 2, 3], l)

  let l = [1, 2, 3]
  call extend(l, [4, 5, 6], 1)
  call assert_equal([1, 4, 5, 6, 2, 3], l)

  let l = [1, 2, 3]
  call extend(l, [4, 5, 6], 3)
  call assert_equal([1, 2, 3, 4, 5, 6], l)

  let l = [1, 2, 3]
  call extend(l, [4, 5, 6], -1)
  call assert_equal([1, 2, 4, 5, 6, 3], l)

  let l = [1, 2, 3]
  call extend(l, [4, 5, 6], -3)
  call assert_equal([4, 5, 6, 1, 2,  3], l)

  let l = [1, 2, 3]
  call assert_fails("call extend(l, [4, 5, 6], 4)", 'E684:')
  call assert_fails("call extend(l, [4, 5, 6], -4)", 'E684:')
  if has('float')
    call assert_fails("call extend(l, [4, 5, 6], 1.2)", 'E805:')
  endif

  " Test extend() with dictionaries.

  " Pass the same Dict to extend()
  let d = { 'a': {'b': 'B'}}
  call extend(d, d)
  call assert_equal({'a': {'b': 'B'}}, d)

  let d = {'a': 'A', 'b': 'B'}
  call assert_equal({'a': 'A', 'b': 0, 'c': 'C'}, extend(d, {'b': 0, 'c':'C'}))
  call assert_equal({'a': 'A', 'b': 0, 'c': 'C'}, d)

  let d = {'a': 'A', 'b': 'B'}
  call extend(d, {'a': 'A', 'b': 0, 'c': 'C'}, "force")
  call assert_equal({'a': 'A', 'b': 0, 'c': 'C'}, d)

  let d = {'a': 'A', 'b': 'B'}
  call extend(d, {'b': 0, 'c':'C'}, "keep")
  call assert_equal({'a': 'A', 'b': 'B', 'c': 'C'}, d)

  let d = {'a': 'A', 'b': 'B'}
  call assert_fails("call extend(d, {'b': 0, 'c':'C'}, 'error')", 'E737:')
  call assert_fails("call extend(d, {'b': 0, 'c':'C'}, 'xxx')", 'E475:')
  if has('float')
    call assert_fails("call extend(d, {'b': 0, 'c':'C'}, 1.2)", 'E806:')
  endif
  call assert_equal({'a': 'A', 'b': 'B'}, d)

  call assert_fails("call extend([1, 2], 1)", 'E712:')
  call assert_fails("call extend([1, 2], {})", 'E712:')

  " Extend g: dictionary with an invalid variable name
  call assert_fails("call extend(g:, {'-!' : 10})", 'E461:')

  " Extend a list with itself.
  let l = [1, 5, 7]
  call extend(l, l, 0)
  call assert_equal([1, 5, 7, 1, 5, 7], l)
  let l = [1, 5, 7]
  call extend(l, l, 1)
  call assert_equal([1, 1, 5, 7, 5, 7], l)
  let l = [1, 5, 7]
  call extend(l, l, 2)
  call assert_equal([1, 5, 1, 5, 7, 7], l)
  let l = [1, 5, 7]
  call extend(l, l, 3)
  call assert_equal([1, 5, 7, 1, 5, 7], l)
endfunc

func s:check_scope_dict(x, fixed)
  func s:gen_cmd(cmd, x)
    return substitute(a:cmd, '\<x\ze:', a:x, 'g')
  endfunc

  let cmd = s:gen_cmd('let x:foo = 1', a:x)
  if a:fixed
    call assert_fails(cmd, 'E461')
  else
    exe cmd
    exe s:gen_cmd('call assert_equal(1, x:foo)', a:x)
  endif

  let cmd = s:gen_cmd('let x:["bar"] = 2', a:x)
  if a:fixed
    call assert_fails(cmd, 'E461')
  else
    exe cmd
    exe s:gen_cmd('call assert_equal(2, x:bar)', a:x)
  endif

  let cmd = s:gen_cmd('call extend(x:, {"baz": 3})', a:x)
  if a:fixed
    call assert_fails(cmd, 'E742')
  else
    exe cmd
    exe s:gen_cmd('call assert_equal(3, x:baz)', a:x)
  endif

  if a:fixed
    if a:x ==# 'a'
      call assert_fails('unlet a:x', 'E795')
      call assert_fails('call remove(a:, "x")', 'E742')
    elseif a:x ==# 'v'
      call assert_fails('unlet v:count', 'E795')
      call assert_fails('call remove(v:, "count")', 'E742')
    endif
  else
    exe s:gen_cmd('unlet x:foo', a:x)
    exe s:gen_cmd('unlet x:bar', a:x)
    exe s:gen_cmd('call remove(x:, "baz")', a:x)
  endif

  delfunc s:gen_cmd
endfunc

func Test_scope_dict()
  " Test for g:
  call s:check_scope_dict('g', v:false)

  " Test for s:
  call s:check_scope_dict('s', v:false)

  " Test for l:
  call s:check_scope_dict('l', v:false)

  " Test for a:
  call s:check_scope_dict('a', v:true)

  " Test for b:
  call s:check_scope_dict('b', v:false)

  " Test for w:
  call s:check_scope_dict('w', v:false)

  " Test for t:
  call s:check_scope_dict('t', v:false)

  " Test for v:
  call s:check_scope_dict('v', v:true)
endfunc

" Test for deep nesting of lists (> 100)
func Test_deep_nested_list()
  let deep_list = []
  let l = deep_list
  for i in range(102)
    let newlist = []
    call add(l, newlist)
    let l = newlist
  endfor
  call add(l, 102)

  call assert_fails('let m = deepcopy(deep_list)', 'E698:')
  call assert_fails('lockvar 110 deep_list', 'E743:')
  call assert_fails('unlockvar 110 deep_list', 'E743:')
  " Nvim implements :echo very differently
  " call assert_fails('let x = execute("echo deep_list")', 'E724:')
  call test_garbagecollect_now()
  unlet deep_list
endfunc

" Test for deep nesting of dicts (> 100)
func Test_deep_nested_dict()
  let deep_dict = {}
  let d = deep_dict
  for i in range(102)
    let newdict = {}
    let d.k = newdict
    let d = newdict
  endfor
  let d.k = 'v'

  call assert_fails('let m = deepcopy(deep_dict)', 'E698:')
  call assert_fails('lockvar 110 deep_dict', 'E743:')
  call assert_fails('unlockvar 110 deep_dict', 'E743:')
  " Nvim implements :echo very differently
  " call assert_fails('let x = execute("echo deep_dict")', 'E724:')
  call test_garbagecollect_now()
  unlet deep_dict
endfunc

" List and dict indexing tests
func Test_listdict_index()
  call assert_fails('echo function("min")[0]', 'E695:')
  call assert_fails('echo v:true[0]', 'E909:')
  let d = {'k' : 10}
  call assert_fails('echo d.', 'E15:')
  call assert_fails('echo d[1:2]', 'E719:')
  call assert_fails("let v = [4, 6][{-> 1}]", 'E729:')
  call assert_fails("let v = range(5)[2:[]]", 'E730:')
  call assert_fails("let v = range(5)[2:{-> 2}(]", ['E15:', 'E116:'])
  call assert_fails("let v = range(5)[2:3", 'E111:')
  call assert_fails("let l = insert([1,2,3], 4, 10)", 'E684:')
  call assert_fails("let l = insert([1,2,3], 4, -10)", 'E684:')
  call assert_fails("let l = insert([1,2,3], 4, [])", 'E745:')
  let l = [1, 2, 3]
  call assert_fails("let l[i] = 3", 'E121:')
  call assert_fails("let l[1.1] = 4", 'E806:')
  call assert_fails("let l[:i] = [4, 5]", 'E121:')
  call assert_fails("let l[:3.2] = [4, 5]", 'E806:')
endfunc

" Test for a null list
func Test_null_list()
  let l = v:_null_list
  call assert_equal('', join(l))
  call assert_equal(0, len(l))
  call assert_equal(1, empty(l))
  call assert_fails('let s = join([1, 2], [])', 'E730:')
  call assert_equal([], split(v:_null_string))
  call assert_equal([], l[:2])
  call assert_true([] == l)
  call assert_equal('[]', string(l))
  " call assert_equal(0, sort(l))
  " call assert_equal(0, sort(l))
  " call assert_equal(0, uniq(l))
  let k = [] + l
  call assert_equal([], k)
  let k = l + []
  call assert_equal([], k)
  call assert_equal(0, len(copy(l)))
  call assert_equal(0, count(l, 5))
  call assert_equal([], deepcopy(l))
  call assert_equal(5, get(l, 2, 5))
  call assert_equal(-1, index(l, 2, 5))
  " call assert_equal(0, insert(l, 2, -1))
  call assert_equal(0, min(l))
  call assert_equal(0, max(l))
  " call assert_equal(0, remove(l, 0, 2))
  call assert_equal([], repeat(l, 2))
  " call assert_equal(0, reverse(l))
  " call assert_equal(0, sort(l))
  call assert_equal('[]', string(l))
  " call assert_equal(0, extend(l, l, 0))
  lockvar l
  call assert_equal(1, islocked('l'))
  unlockvar l
endfunc

" Test for a null dict
func Test_null_dict()
  call assert_equal(v:_null_dict, v:_null_dict)
  let d = v:_null_dict
  call assert_equal({}, d)
  call assert_equal(0, len(d))
  call assert_equal(1, empty(d))
  call assert_equal(0, items(d))
  call assert_equal(0, keys(d))
  call assert_equal(0, values(d))
  call assert_false(has_key(d, 'k'))
  call assert_equal('{}', string(d))
  call assert_fails('let x = v:_null_dict[10]')
  call assert_equal({}, {})
endfunc

" vim: shiftwidth=2 sts=2 expandtab
