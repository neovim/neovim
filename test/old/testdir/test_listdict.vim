" Tests for the List and Dict types
scriptencoding utf-8

source vim9.vim

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

  let lines =<< trim END
      VAR l = [1, 2]
      call assert_equal([1, 2], l[:])
      call assert_equal([2], l[-1 : -1])
      call assert_equal([1, 2], l[-2 : -1])
  END
  call CheckLegacyAndVim9Success(lines)

  let l = [1, 2]
  call assert_equal([], l[-3 : -1])

  let lines =<< trim END
      var l = [1, 2]
      assert_equal([1, 2], l[-3 : -1])
  END
  call CheckDefAndScriptSuccess(lines)
endfunc

" List identity
func Test_list_identity()
  let lines =<< trim END
      VAR l = [1, 'as''d', [1, 2, function("strlen")], {'a': 1},]
      VAR ll = l
      VAR lx = copy(l)
      call assert_true(l == ll)
      call assert_false(l isnot ll)
      call assert_true(l is ll)
      call assert_true(l == lx)
      call assert_false(l is lx)
      call assert_true(l isnot lx)
  END
  call CheckLegacyAndVim9Success(lines)
endfunc

" removing items with :unlet
func Test_list_unlet()
  let lines =<< trim END
      VAR l = [1, 'as''d', [1, 2, function("strlen")], {'a': 1},]
      unlet l[2]
      call assert_equal([1, 'as''d', {'a': 1}], l)
      LET l = range(8)
      unlet l[: 3]
      unlet l[1 :]
      call assert_equal([4], l)

      #" removing items out of range: silently skip items that don't exist
      LET l = [0, 1, 2, 3]
      unlet l[2 : 2]
      call assert_equal([0, 1, 3], l)
      LET l = [0, 1, 2, 3]
      unlet l[2 : 3]
      call assert_equal([0, 1], l)
      LET l = [0, 1, 2, 3]
      unlet l[2 : 4]
      call assert_equal([0, 1], l)
      LET l = [0, 1, 2, 3]
      unlet l[2 : 5]
      call assert_equal([0, 1], l)
      LET l = [0, 1, 2, 3]
      unlet l[-2 : 2]
      call assert_equal([0, 1, 3], l)
      LET l = [0, 1, 2, 3]
      unlet l[-3 : 2]
      call assert_equal([0, 3], l)
      LET l = [0, 1, 2, 3]
      unlet l[-4 : 2]
      call assert_equal([3], l)
      LET l = [0, 1, 2, 3]
      unlet l[-5 : 2]
      call assert_equal([3], l)
      LET l = [0, 1, 2, 3]
      unlet l[-6 : 2]
      call assert_equal([3], l)
  END
  call CheckLegacyAndVim9Success(lines)

  let l = [0, 1, 2, 3]
  unlet l[2:2]
  call assert_equal([0, 1, 3], l)
  let l = [0, 1, 2, 3]
  unlet l[2:3]
  call assert_equal([0, 1], l)

  let lines =<< trim END
      VAR l = [0, 1, 2, 3]
      unlet l[2 : 1]
  END
  call CheckLegacyAndVim9Failure(lines, 'E684:')

  let lines =<< trim END
      VAR l = [0, 1, 2, 3]
      unlet l[-1 : 2]
  END
  call CheckLegacyAndVim9Failure(lines, 'E684:')
endfunc

" assignment to a list
func Test_list_assign()
  let lines =<< trim END
      VAR l = [0, 1, 2, 3]
      VAR va = 0
      VAR vb = 0
      LET [va, vb] = l[2 : 3]
      call assert_equal([2, 3], [va, vb])
  END
  call CheckLegacyAndVim9Success(lines)

  let lines =<< trim END
      let l = [0, 1, 2, 3]
      let [va, vb] = l
  END
  call CheckScriptFailure(lines, 'E687:')
  let lines =<< trim END
      var l = [0, 1, 2, 3]
      var va = 0
      var vb = 0
      [va, vb] = l
  END
  call CheckScriptFailure(['vim9script'] + lines, 'E687:')
  call CheckDefExecFailure(lines, 'E1093: Expected 2 items but got 4')

  let lines =<< trim END
      let l = [0, 1, 2, 3]
      let [va, vb] = l[1:1]
  END
  call CheckScriptFailure(lines, 'E688:')
  let lines =<< trim END
      var l = [0, 1, 2, 3]
      var va = 0
      var vb = 0
      [va, vb] = l[1 : 1]
  END
  call CheckScriptFailure(['vim9script'] + lines, 'E688:')
  call CheckDefExecFailure(lines, 'E1093: Expected 2 items but got 1')
endfunc

" test for range assign
func Test_list_range_assign()
  let lines =<< trim END
      VAR l = [0]
      LET l[:] = [1, 2]
      call assert_equal([1, 2], l)
      LET l[-4 : -1] = [5, 6]
      call assert_equal([5, 6], l)
  END
  call CheckLegacyAndVim9Success(lines)

  let lines =<< trim END
    var l = [7]
    l[:] = ['text']
  END
  call CheckDefAndScriptFailure(lines, 'E1012:', 2)
endfunc

" Test removing items in list
func Test_list_func_remove()
  let lines =<< trim END
      #" Test removing 1 element
      VAR l = [1, 2, 3, 4]
      call assert_equal(1, remove(l, 0))
      call assert_equal([2, 3, 4], l)

      LET l = [1, 2, 3, 4]
      call assert_equal(2, remove(l, 1))
      call assert_equal([1, 3, 4], l)

      LET l = [1, 2, 3, 4]
      call assert_equal(4, remove(l, -1))
      call assert_equal([1, 2, 3], l)

      #" Test removing range of element(s)
      LET l = [1, 2, 3, 4]
      call assert_equal([3], remove(l, 2, 2))
      call assert_equal([1, 2, 4], l)

      LET l = [1, 2, 3, 4]
      call assert_equal([2, 3], remove(l, 1, 2))
      call assert_equal([1, 4], l)

      LET l = [1, 2, 3, 4]
      call assert_equal([2, 3], remove(l, -3, -2))
      call assert_equal([1, 4], l)
  END
  call CheckLegacyAndVim9Success(lines)

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
  let lines =<< trim END
      VAR l = []
      call add(l, 1)
      call add(l, [2, 3])
      call add(l, [])
      call add(l, v:_null_list)
      call add(l, {'k': 3})
      call add(l, {})
      call add(l, v:_null_dict)
      call assert_equal([1, [2, 3], [], [], {'k': 3}, {}, {}], l)
  END
  call CheckLegacyAndVim9Success(lines)

  " weird legacy behavior
  " call assert_equal(1, add(v:_null_list, 4))
endfunc

" Tests for Dictionary type

func Test_dict()
  " Creating Dictionary directly with different types
  let lines =<< trim END
      VAR d = {'1': 'asd', 'b': [1, 2, function('strlen')], '-1': {'a': 1}, }
      call assert_equal("{'1': 'asd', 'b': [1, 2, function('strlen')], '-1': {'a': 1}}", string(d))
      call assert_equal('asd', d.1)
      call assert_equal(['-1', '1', 'b'], sort(keys(d)))
      call assert_equal(['asd', [1, 2, function('strlen')], {'a': 1}], values(d))
      call extend(d, {3: 33, 1: 99})
      call extend(d, {'b': 'bbb', 'c': 'ccc'}, "keep")
      call assert_equal({'c': 'ccc', '1': 99, 'b': [1, 2, function('strlen')], '3': 33, '-1': {'a': 1}}, d)
  END
  call CheckLegacyAndVim9Success(lines)

  let d = {001: 'asd', 'b': [1, 2, function('strlen')], -1: {'a': 1},}
  call assert_equal("{'1': 'asd', 'b': [1, 2, function('strlen')], '-1': {'a': 1}}", string(d))

  let v = []
  for [key, val] in items(d)
    call extend(v, [key, val])
    unlet key val
  endfor
  call assert_equal(['1','asd','b',[1, 2, function('strlen')],'-1',{'a': 1}], v)

  call extend(d, {3: 33, 1: 99})
  call assert_fails("call extend(d, {3:333,4:444}, 'error')", 'E737:')

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
  let lines =<< trim END
      VAR d = {'1': 'asd', 'b': [1, 2, function('strlen')], -1: {'a': 1}, }
      VAR dd = d
      VAR dx = copy(d)
      call assert_true(d == dd)
      call assert_false(d isnot dd)
      call assert_true(d is dd)
      call assert_true(d == dx)
      call assert_false(d is dx)
      call assert_true(d isnot dx)
  END
  call CheckLegacyAndVim9Success(lines)
endfunc

" removing items with :unlet
func Test_dict_unlet()
  let lines =<< trim END
      VAR d = {'b': 'bbb', '1': 99, '3': 33, '-1': {'a': 1}}
      unlet d.b
      unlet d[-1]
      call assert_equal({'1': 99, '3': 33}, d)
  END
  call CheckLegacyAndVim9Success(lines)
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

  " lookup each item
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

  let lines =<< trim END
      VAR d = {}
      LET d.a = 1
      LET d._ = 2
      call assert_equal({'a': 1, '_': 2}, d)
  END
  call CheckLegacyAndVim9Success(lines)

  let lines =<< trim END
    let n = 0
    let n.key = 3
  END
  call CheckScriptFailure(lines, 'E1203: Dot can only be used on a dictionary: n.key = 3')
  let lines =<< trim END
    vim9script
    var n = 0
    n.key = 3
  END
  call CheckScriptFailure(lines, 'E1203: Dot can only be used on a dictionary: n.key = 3')
  let lines =<< trim END
    var n = 0
    n.key = 3
  END
  call CheckDefFailure(lines, 'E1141:')
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
  let lines =<< trim END
      VAR d = {1: 'a', 2: 'b', 3: 'c'}
      call assert_equal('b', remove(d, 2))
      call assert_equal({1: 'a', 3: 'c'}, d)
  END
  call CheckLegacyAndVim9Success(lines)

  let lines =<< trim END
      VAR d = {1: 'a', 3: 'c'}
      call remove(d, 1, 2)
  END
  call CheckLegacyAndVim9Failure(lines, 'E118:')

  let lines =<< trim END
      VAR d = {1: 'a', 3: 'c'}
      call remove(d, 'a')
  END
  call CheckLegacyAndVim9Failure(lines, 'E716:')

  let lines =<< trim END
      let d = {'a-b': 55}
      echo d.a-b
  END
  call CheckScriptFailure(lines, 'E716: Key not present in Dictionary: "a"')

  let lines =<< trim END
      vim9script
      var d = {'a-b': 55}
      echo d.a-b
  END
  call CheckScriptFailure(lines, 'E716: Key not present in Dictionary: "a"')

  let lines =<< trim END
      var d = {'a-b': 55}
      echo d.a-b
  END
  call CheckDefFailure(lines, 'E1004: White space required before and after ''-''')

  let lines =<< trim END
      let d = {1: 'a', 3: 'c'}
      call remove(d, [])
  END
  call CheckScriptFailure(lines, 'E730:')
  let lines =<< trim END
      vim9script
      var d = {1: 'a', 3: 'c'}
      call remove(d, [])
  END
  call CheckScriptFailure(lines, 'E1174: String required for argument 2')
  let lines =<< trim END
      var d = {1: 'a', 3: 'c'}
      call remove(d, [])
  END
  call CheckDefExecFailure(lines, 'E1013: Argument 2: type mismatch, expected string but got list<unknown>')
endfunc

" Nasty: remove func from Dict that's being called (works)
func Test_dict_func_remove_in_use()
  let d = {1:1}
  func d.func(a)
    return "a:" . a:a
  endfunc
  let expected = 'a:' . string(get(d, 'func'))
  call assert_equal(expected, d.func(string(remove(d, 'func'))))

  " similar, in a way it also works in Vim9
  let lines =<< trim END
      VAR d = {1: 1, 2: 'x'}
      func GetArg(a)
        return "a:" .. a:a
      endfunc
      LET d.func = function('GetArg')
      VAR expected = 'a:' .. string(get(d, 'func'))
      call assert_equal(expected, d.func(string(remove(d, 'func'))))
  END
  call CheckTransLegacySuccess(lines)
  call CheckTransVim9Success(lines)
endfunc

func Test_dict_literal_keys()
  call assert_equal({'one': 1, 'two2': 2, '3three': 3, '44': 4}, #{one: 1, two2: 2, 3three: 3, 44: 4},)

  " why *{} cannot be used for a literal dictionary
  let blue = 'blue'
  call assert_equal('6', trim(execute('echo 2 *{blue: 3}.blue')))
endfunc

" Nasty: deepcopy() dict that refers to itself (fails when noref used)
func Test_dict_deepcopy()
  let lines =<< trim END
      VAR d = {1: 1, 2: '2'}
      VAR l = [4, d, 6]
      LET d[3] = l
      VAR dc = deepcopy(d)
      call deepcopy(d, 1)
  END
  call CheckLegacyAndVim9Failure(lines, 'E698:')

  let lines =<< trim END
      VAR d = {1: 1, 2: '2'}
      VAR l = [4, d, 6]
      LET d[3] = l
      VAR l2 = [0, l, l, 3]
      LET l[1] = l2
      VAR l3 = deepcopy(l2)
      call assert_true(l3[1] is l3[2])
  END
  call CheckLegacyAndVim9Success(lines)

  call assert_fails("call deepcopy([1, 2], 2)", 'E1212:')
endfunc

" Locked variables
func Test_list_locked_var()
  " Not tested with :def function, local vars cannot be locked.
  let lines =<< trim END
      VAR expected = [
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
          VAR l = [0, [1, [2, 3]], {4: 5, 6: {7: 8}}]
          exe "lockvar " .. depth .. " l"
          if u == 1
            exe "unlockvar l"
          elseif u == 2
            exe "unlockvar " .. depth .. " l"
          endif
          VAR ps = islocked("l") .. islocked("l[1]") .. islocked("l[1][1]") .. islocked("l[1][1][0]") .. '-' .. islocked("l[2]") .. islocked("l[2]['6']") .. islocked("l[2]['6'][7]")
          call assert_equal(expected[depth][u][0], ps, 'depth: ' .. depth)
          LET ps = ''
          try
            LET l[1][1][0] = 99
            LET ps ..= 'p'
          catch
            LET ps ..= 'F'
          endtry
          try
            LET l[1][1] = [99]
            LET ps ..= 'p'
          catch
            LET ps ..= 'F'
          endtry
          try
            LET l[1] = [99]
            LET ps ..= 'p'
          catch
            LET ps ..= 'F'
          endtry
          try
            LET l[2]['6'][7] = 99
            LET ps ..= 'p'
          catch
            LET ps ..= 'F'
          endtry
          try
            LET l[2][6] = {99: 99}
            LET ps ..= 'p'
          catch
            LET ps ..= 'F'
          endtry
          try
            LET l[2] = {99: 99}
            LET ps ..= 'p'
          catch
            LET ps ..= 'F'
          endtry
          try
            LET l = [99]
            LET ps ..= 'p'
          catch
            LET ps ..= 'F'
          endtry
          call assert_equal(expected[depth][u][1], ps, 'depth: ' .. depth)
          unlock! l
        endfor
      endfor
  END
  call CheckTransLegacySuccess(lines)
  call CheckTransVim9Success(lines)

  call assert_fails("let x=islocked('a b')", 'E488:')
  let mylist = [1, 2, 3]
  call assert_fails("let x = islocked('mylist[1:2]')", 'E786:')
  let mydict = {'k' : 'v'}
  call assert_fails("let x = islocked('mydict.a')", 'E716:')
endfunc

" Unletting locked variables
func Test_list_locked_var_unlet()
  " Not tested with Vim9: script and local variables cannot be unlocked
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

  " Deleting a list range with locked items works, but changing the items
  " fails.
  let l = [1, 2, 3, 4]
  lockvar l[1:2]
  call assert_fails('let l[1:2] = [8, 9]', 'E741:')
  unlet l[1:2]
  call assert_equal([1, 4], l)
  unlet l
endfunc

" Locked variables and :unlet or list / dict functions

" No :unlet after lock on dict:
func Test_dict_lock_unlet()
  let d = {'a': 99, 'b': 100}
  lockvar 1 d
  call assert_fails('unlet d.a', 'E741:')
endfunc

" unlet after lock on dict item
func Test_dict_item_lock_unlet()
  let lines =<< trim END
      VAR d = {'a': 99, 'b': 100}
      lockvar d.a
      unlet d.a
      call assert_equal({'b': 100}, d)
  END
  " TODO: make this work in a :def function
  "call CheckLegacyAndVim9Success(lines)
  call CheckTransLegacySuccess(lines)
  call CheckTransVim9Success(lines)
endfunc

" filter() after lock on dict item
func Test_dict_lock_filter()
  let lines =<< trim END
      VAR d = {'a': 99, 'b': 100}
      lockvar d.a
      call filter(d, 'v:key != "a"')
      call assert_equal({'b': 100}, d)
  END
  " TODO: make this work in a :def function
  "call CheckLegacyAndVim9Success(lines)
  call CheckTransLegacySuccess(lines)
  call CheckTransVim9Success(lines)
endfunc

" map() after lock on dict
func Test_dict_lock_map()
  let lines =<< trim END
      VAR d = {'a': 99, 'b': 100}
      lockvar 1 d
      call map(d, 'v:val + 200')
      call assert_equal({'a': 299, 'b': 300}, d)
  END
  " This won't work in a :def function
  call CheckTransLegacySuccess(lines)
  call CheckTransVim9Success(lines)
endfunc

" No extend() after lock on dict item
func Test_dict_lock_extend()
  let d = {'a': 99, 'b': 100}
  lockvar d.a
  call assert_fails("call extend(d, {'a' : 123})", 'E741:')
  call assert_equal({'a': 99, 'b': 100}, d)
endfunc

" Cannot use += with a locked dict
func Test_dict_lock_operator()
  let d = {}
  lockvar d
  call assert_fails("let d += {'k' : 10}", 'E741:')
  unlockvar d
endfunc

" No remove() of write-protected scope-level variable
func Tfunc1(this_is_a_long_parameter_name)
  call assert_fails("call remove(a:, 'this_is_a_long_parameter_name')", 'E742:')
endfunc
func Test_dict_scope_var_remove()
  call Tfunc1('testval')
endfunc

" No extend() of write-protected scope-level variable
func Test_dict_scope_var_extend()
  call assert_fails("call extend(a:, {'this_is_a_long_parameter_name': 1234})", 'E742:')
endfunc
func Tfunc2(this_is_a_long_parameter_name)
  call assert_fails("call extend(a:, {'this_is_a_long_parameter_name': 1234})", 'E742:')
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

" Tests for reverse(), sort(), uniq()
func Test_reverse_sort_uniq()
  let lines =<< trim END
      VAR l = ['-0', 'A11', 2, 2, 'xaaa', 4, 'foo', 'foo6', 'foo', [0, 1, 2], 'x8', [0, 1, 2], 1.5]
      call assert_equal(['-0', 'A11', 2, 'xaaa', 4, 'foo', 'foo6', 'foo', [0, 1, 2], 'x8', [0, 1, 2], 1.5], uniq(copy(l)))
      call assert_equal([1.5, [0, 1, 2], 'x8', [0, 1, 2], 'foo', 'foo6', 'foo', 4, 'xaaa', 2, 2, 'A11', '-0'], reverse(l))
      call assert_equal([1.5, [0, 1, 2], 'x8', [0, 1, 2], 'foo', 'foo6', 'foo', 4, 'xaaa', 2, 2, 'A11', '-0'], reverse(reverse(l)))
      if has('float')
        call assert_equal(['-0', 'A11', 'foo', 'foo', 'foo6', 'x8', 'xaaa', 1.5, 2, 2, 4, [0, 1, 2], [0, 1, 2]], sort(l))
        call assert_equal([[0, 1, 2], [0, 1, 2], 4, 2, 2, 1.5, 'xaaa', 'x8', 'foo6', 'foo', 'foo', 'A11', '-0'], reverse(sort(l)))
        call assert_equal(['-0', 'A11', 'foo', 'foo', 'foo6', 'x8', 'xaaa', 1.5, 2, 2, 4, [0, 1, 2], [0, 1, 2]], sort(reverse(sort(l))))
        call assert_equal(['-0', 'A11', 'foo', 'foo6', 'x8', 'xaaa', 1.5, 2, 4, [0, 1, 2]], uniq(sort(l)))

        LET l = [7, 9, 'one', 18, 12, 22, 'two', 10.0e-16, -1, 'three', 0xff, 0.22, 'four']
        call assert_equal([-1, 'one', 'two', 'three', 'four', 1.0e-15, 0.22, 7, 9, 12, 18, 22, 255], sort(copy(l), 'n'))

        LET l = [7, 9, 18, 12, 22, 10.0e-16, -1, 0xff, 0, -0, 0.22, 'bar', 'BAR', 'Bar', 'Foo', 'FOO', 'foo', 'FOOBAR', {}, []]
        call assert_equal(['bar', 'BAR', 'Bar', 'Foo', 'FOO', 'foo', 'FOOBAR', -1, 0, 0, 0.22, 1.0e-15, 12, 18, 22, 255, 7, 9, [], {}], sort(copy(l), 'i'))
        call assert_equal(['bar', 'BAR', 'Bar', 'Foo', 'FOO', 'foo', 'FOOBAR', -1, 0, 0, 0.22, 1.0e-15, 12, 18, 22, 255, 7, 9, [], {}], sort(copy(l), 'i'))
        call assert_equal(['BAR', 'Bar', 'FOO', 'FOOBAR', 'Foo', 'bar', 'foo', -1, 0, 0, 0.22, 1.0e-15, 12, 18, 22, 255, 7, 9, [], {}], sort(copy(l)))
      endif
  END
  call CheckLegacyAndVim9Success(lines)

  call assert_fails('call reverse({})', 'E1252:')
  call assert_fails('call uniq([1, 2], {x, y -> []})', 'E745:')
  call assert_fails("call sort([1, 2], function('min'), 1)", "E1206:")
  call assert_fails("call sort([1, 2], function('invalid_func'))", "E700:")
  call assert_fails("call sort([1, 2], function('min'))", "E118:")

  let lines =<< trim END
    call sort(['a', 'b'], 0)
  END
  call CheckDefAndScriptFailure(lines, 'E1256: String or function required for argument 2')

  let lines =<< trim END
    call sort(['a', 'b'], 1)
  END
  call CheckDefAndScriptFailure(lines, 'E1256: String or function required for argument 2')
endfunc

" reduce a list, blob or string
func Test_reduce()
  let lines =<< trim END
      call assert_equal(1, reduce([], LSTART acc, val LMIDDLE acc + val LEND, 1))
      call assert_equal(10, reduce([1, 3, 5], LSTART acc, val LMIDDLE acc + val LEND, 1))
      call assert_equal(2 * (2 * ((2 * 1) + 2) + 3) + 4, reduce([2, 3, 4], LSTART acc, val LMIDDLE 2 * acc + val LEND, 1))
      call assert_equal('a x y z', ['x', 'y', 'z']->reduce(LSTART acc, val LMIDDLE acc .. ' ' .. val LEND, 'a'))
      call assert_equal([0, 1, 2, 3], reduce([1, 2, 3], function('add'), [0]))

      VAR l = ['x', 'y', 'z']
      call assert_equal(42, reduce(l, function('get'), {'x': {'y': {'z': 42 } } }))
      call assert_equal(['x', 'y', 'z'], l)

      call assert_equal(1, reduce([1], LSTART acc, val LMIDDLE acc + val LEND))
      call assert_equal('x y z', reduce(['x', 'y', 'z'], LSTART acc, val LMIDDLE acc .. ' ' .. val LEND))
      call assert_equal(120, range(1, 5)->reduce(LSTART acc, val LMIDDLE acc * val LEND))

      call assert_equal(1, reduce(0z, LSTART acc, val LMIDDLE acc + val LEND, 1))
      call assert_equal(1 + 0xaf + 0xbf + 0xcf, reduce(0zAFBFCF, LSTART acc, val LMIDDLE acc + val LEND, 1))
      call assert_equal(2 * (2 * 1 + 0xaf) + 0xbf, 0zAFBF->reduce(LSTART acc, val LMIDDLE 2 * acc + val LEND, 1))

      call assert_equal(0xff, reduce(0zff, LSTART acc, val LMIDDLE acc + val LEND))
      call assert_equal(2 * (2 * 0xaf + 0xbf) + 0xcf, reduce(0zAFBFCF, LSTART acc, val LMIDDLE 2 * acc + val LEND))

      call assert_equal('x,y,z', 'xyz'->reduce(LSTART acc, val LMIDDLE acc .. ',' .. val LEND))
      call assert_equal('', ''->reduce(LSTART acc, val LMIDDLE acc .. ',' .. val LEND, ''))
      call assert_equal('あ,い,う,え,お,😊,💕', 'あいうえお😊💕'->reduce(LSTART acc, val LMIDDLE acc .. ',' .. val LEND))
      call assert_equal('😊,あ,い,う,え,お,💕', 'あいうえお💕'->reduce(LSTART acc, val LMIDDLE acc .. ',' .. val LEND, '😊'))
      call assert_equal('ऊ,ॠ,ॡ', reduce('ऊॠॡ', LSTART acc, val LMIDDLE acc .. ',' .. val LEND))
      call assert_equal('c,à,t', reduce('càt', LSTART acc, val LMIDDLE acc .. ',' .. val LEND))
      call assert_equal('Å,s,t,r,ö,m', reduce('Åström', LSTART acc, val LMIDDLE acc .. ',' .. val LEND))
      call assert_equal('Å,s,t,r,ö,m', reduce('Åström', LSTART acc, val LMIDDLE acc .. ',' .. val LEND))
      call assert_equal(',a,b,c', reduce('abc', LSTART acc, val LMIDDLE acc .. ',' .. val LEND, v:_null_string))

      call assert_equal(0x7d, reduce([0x30, 0x25, 0x08, 0x61], 'or'))
      call assert_equal(0x7d, reduce(0z30250861, 'or'))
      call assert_equal('β', reduce('ββββ', 'matchstr'))
  END
  call CheckLegacyAndVim9Success(lines)

  call assert_equal({'x': 1, 'y': 1, 'z': 1 }, ['x', 'y', 'z']->reduce({ acc, val -> extend(acc, { val: 1 }) }, {}))
  " vim9 assert_equal({'x': 1, 'y': 1, 'z': 1 }, ['x', 'y', 'z']->reduce((acc, val) => extend(acc, {[val]: 1 }), {}))

  call assert_fails("call reduce([], { acc, val -> acc + val })", 'E998: Reduce of an empty List with no initial value')
  call assert_fails("call reduce(0z, { acc, val -> acc + val })", 'E998: Reduce of an empty Blob with no initial value')
  call assert_fails("call reduce(v:_null_blob, { acc, val -> acc + val })", 'E998: Reduce of an empty Blob with no initial value')
  call assert_fails("call reduce('', { acc, val -> acc + val })", 'E998: Reduce of an empty String with no initial value')
  call assert_fails("call reduce(v:_null_string, { acc, val -> acc + val })", 'E998: Reduce of an empty String with no initial value')

  call assert_fails("call reduce({}, { acc, val -> acc + val }, 1)", 'E1098:')
  call assert_fails("call reduce(0, { acc, val -> acc + val }, 1)", 'E1098:')
  call assert_fails("call reduce([1, 2], 'Xdoes_not_exist')", 'E117:')
  call assert_fails("echo reduce(0z01, { acc, val -> 2 * acc + val }, '')", 'E1210:')

  " call assert_fails("vim9 reduce(0, (acc, val) => (acc .. val), '')", 'E1252:')
  " call assert_fails("vim9 reduce({}, (acc, val) => (acc .. val), '')", 'E1252:')
  " call assert_fails("vim9 reduce(0.1, (acc, val) => (acc .. val), '')", 'E1252:')
  " call assert_fails("vim9 reduce(function('tr'), (acc, val) => (acc .. val), '')", 'E1252:')
  call assert_fails("call reduce('', { acc, val -> acc + val }, 1)", 'E1174:')
  call assert_fails("call reduce('', { acc, val -> acc + val }, {})", 'E1174:')
  call assert_fails("call reduce('', { acc, val -> acc + val }, 0.1)", 'E1174:')
  call assert_fails("call reduce('', { acc, val -> acc + val }, function('tr'))", 'E1174:')
  call assert_fails("call reduce('abc', { a, v -> a10}, '')", 'E121:')
  call assert_fails("call reduce(0z0102, { a, v -> a10}, 1)", 'E121:')
  call assert_fails("call reduce([1, 2], { a, v -> a10}, '')", 'E121:')

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

  " should not crash
  " Nvim doesn't have null functions
  " call assert_fails('echo reduce([1], test_null_function())', 'E1132:')
  " Nvim doesn't have null partials
  " call assert_fails('echo reduce([1], test_null_partial())', 'E1132:')
endfunc

" splitting a string to a List using split()
func Test_str_split()
  let lines =<< trim END
      call assert_equal(['aa', 'bb'], split('  aa  bb '))
      call assert_equal(['aa', 'bb'], split('  aa  bb  ', '\W\+', 0))
      call assert_equal(['', 'aa', 'bb', ''], split('  aa  bb  ', '\W\+', 1))
      call assert_equal(['', '', 'aa', '', 'bb', '', ''], split('  aa  bb  ', '\W', 1))
      call assert_equal(['aa', '', 'bb'], split(':aa::bb:', ':', 0))
      call assert_equal(['', 'aa', '', 'bb', ''], split(':aa::bb:', ':', 1))
      call assert_equal(['aa', '', 'bb', 'cc', ''], split('aa,,bb, cc,', ',\s*', 1))
      call assert_equal(['a', 'b', 'c'], split('abc', '\zs'))
      call assert_equal(['', 'a', '', 'b', '', 'c', ''], split('abc', '\zs', 1))
      call assert_equal(['abc'], split('abc', '\\%('))
  END
  call CheckLegacyAndVim9Success(lines)

  call assert_fails("call split('abc', [])", 'E730:')
  call assert_fails("call split('abc', 'b', [])", 'E745:')
endfunc

" compare recursively linked list and dict
func Test_listdict_compare()
  let lines =<< trim END
      VAR l = [1, 2, 3, '4']
      VAR d = {'1': 1, '2': l, '3': 3}
      LET l[1] = d
      call assert_true(l == l)
      call assert_true(d == d)
      call assert_false(l != deepcopy(l))
      call assert_false(d != deepcopy(d))
  END
  call CheckLegacyAndVim9Success(lines)

  " comparison errors
  call assert_fails('echo [1, 2] =~ {}', 'E691:')
  call assert_fails('echo [1, 2] =~ [1, 2]', 'E692:')
  call assert_fails('echo {} =~ 5', 'E735:')
  call assert_fails('echo {} =~ {}', 'E736:')
endfunc

func Test_recursive_listdict_compare()
  let l1 = [0, 1]
  let l1[0] = l1
  let l2 = [0, 1]
  let l2[0] = l2
  call assert_true(l1 == l2)
  let d1 = {0: 0, 1: 1}
  let d1[0] = d1
  let d2 = {0: 0, 1: 1}
  let d2[0] = d2
  call assert_true(d1 == d2)
endfunc

  " compare complex recursively linked list and dict
func Test_listdict_compare_complex()
  let lines =<< trim END
      VAR l = []
      call add(l, l)
      VAR dict4 = {"l": l}
      call add(dict4.l, dict4)
      VAR lcopy = deepcopy(l)
      VAR dict4copy = deepcopy(dict4)
      call assert_true(l == lcopy)
      call assert_true(dict4 == dict4copy)
  END
  call CheckLegacyAndVim9Success(lines)
endfunc

" Test for extending lists and dictionaries
func Test_listdict_extend()
  " Test extend() with lists

  " Pass the same List to extend()
  let lines =<< trim END
      VAR l = [1, 2, 3]
      call assert_equal([1, 2, 3, 1, 2, 3], extend(l, l))
      call assert_equal([1, 2, 3, 1, 2, 3], l)

      LET l = [1, 2, 3]
      call assert_equal([1, 2, 3, 4, 5, 6], extend(l, [4, 5, 6]))
      call assert_equal([1, 2, 3, 4, 5, 6], l)

      LET l = [1, 2, 3]
      call extend(l, [4, 5, 6], 0)
      call assert_equal([4, 5, 6, 1, 2, 3], l)

      LET l = [1, 2, 3]
      call extend(l, [4, 5, 6], 1)
      call assert_equal([1, 4, 5, 6, 2, 3], l)

      LET l = [1, 2, 3]
      call extend(l, [4, 5, 6], 3)
      call assert_equal([1, 2, 3, 4, 5, 6], l)

      LET l = [1, 2, 3]
      call extend(l, [4, 5, 6], -1)
      call assert_equal([1, 2, 4, 5, 6, 3], l)

      LET l = [1, 2, 3]
      call extend(l, [4, 5, 6], -3)
      call assert_equal([4, 5, 6, 1, 2,  3], l)
  END
  call CheckLegacyAndVim9Success(lines)

  let l = [1, 2, 3]
  call assert_fails("call extend(l, [4, 5, 6], 4)", 'E684:')
  call assert_fails("call extend(l, [4, 5, 6], -4)", 'E684:')
  if has('float')
    call assert_fails("call extend(l, [4, 5, 6], 1.2)", 'E805:')
  endif

  " Test extend() with dictionaries.

  " Pass the same Dict to extend()
  let lines =<< trim END
      VAR d = {'a': {'b': 'B'}, 'x': 9}
      call extend(d, d)
      call assert_equal({'a': {'b': 'B'}, 'x': 9}, d)

      LET d = {'a': 'A', 'b': 9}
      call assert_equal({'a': 'A', 'b': 0, 'c': 'C'}, extend(d, {'b': 0, 'c': 'C'}))
      call assert_equal({'a': 'A', 'b': 0, 'c': 'C'}, d)

      LET d = {'a': 'A', 'b': 9}
      call extend(d, {'a': 'A', 'b': 0, 'c': 'C'}, "force")
      call assert_equal({'a': 'A', 'b': 0, 'c': 'C'}, d)

      LET d = {'a': 'A', 'b': 9}
      call extend(d, {'b': 0, 'c': 'C'}, "keep")
      call assert_equal({'a': 'A', 'b': 9, 'c': 'C'}, d)
  END
  call CheckLegacyAndVim9Success(lines)

  let d = {'a': 'A', 'b': 'B'}
  call assert_fails("call extend(d, {'b': 0, 'c':'C'}, 'error')", 'E737:')
  call assert_fails("call extend(d, {'b': 0}, [])", 'E730:')
  call assert_fails("call extend(d, {'b': 0, 'c':'C'}, 'xxx')", 'E475:')
  if has('float')
    call assert_fails("call extend(d, {'b': 0, 'c':'C'}, 1.2)", 'E475:')
  endif
  call assert_equal({'a': 'A', 'b': 'B'}, d)

  call assert_fails("call extend([1, 2], 1)", 'E712:')
  call assert_fails("call extend([1, 2], {})", 'E712:')

  " Extend g: dictionary with an invalid variable name
  call assert_fails("call extend(g:, {'-!' : 10})", 'E461:')

  " Extend a list with itself.
  let lines =<< trim END
      VAR l = [1, 5, 7]
      call extend(l, l, 0)
      call assert_equal([1, 5, 7, 1, 5, 7], l)
      LET l = [1, 5, 7]
      call extend(l, l, 1)
      call assert_equal([1, 1, 5, 7, 5, 7], l)
      LET l = [1, 5, 7]
      call extend(l, l, 2)
      call assert_equal([1, 5, 1, 5, 7, 7], l)
      LET l = [1, 5, 7]
      call extend(l, l, 3)
      call assert_equal([1, 5, 7, 1, 5, 7], l)
  END
  call CheckLegacyAndVim9Success(lines)
endfunc

func Test_listdict_extendnew()
  " Test extendnew() with lists
  let l = [1, 2, 3]
  call assert_equal([1, 2, 3, 4, 5], extendnew(l, [4, 5]))
  call assert_equal([1, 2, 3], l)
  lockvar l
  call assert_equal([1, 2, 3, 4, 5], extendnew(l, [4, 5]))

  " Test extendnew() with dictionaries.
  let d = {'a': {'b': 'B'}}
  call assert_equal({'a': {'b': 'B'}, 'c': 'cc'}, extendnew(d, {'c': 'cc'}))
  call assert_equal({'a': {'b': 'B'}}, d)
  lockvar d
  call assert_equal({'a': {'b': 'B'}, 'c': 'cc'}, extendnew(d, {'c': 'cc'}))
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
  call CheckLegacyAndVim9Failure(['echo function("min")[0]'], 'E695:')
  call CheckLegacyAndVim9Failure(['echo v:true[0]'], 'E909:')
  call CheckLegacyAndVim9Failure(['echo v:null[0]'], 'E909:')
  call CheckLegacyAndVim9Failure(['VAR d = {"k": 10}', 'echo d.'], ['E15:', 'E1127:', 'E15:'])
  call CheckLegacyAndVim9Failure(['VAR d = {"k": 10}', 'echo d[1 : 2]'], 'E719:')

  call assert_fails("let v = [4, 6][{-> 1}]", 'E729:')
  call CheckDefAndScriptFailure(['var v = [4, 6][() => 1]'], ['E1012', 'E703:'])

  call CheckLegacyAndVim9Failure(['VAR v = range(5)[2 : []]'], ['E730:', 'E1012:', 'E730:'])

  call assert_fails("let v = range(5)[2:{-> 2}(]", ['E15:', 'E116:'])
  call CheckDefAndScriptFailure(['var v = range(5)[2 : () => 2(]'], 'E15:')

  call CheckLegacyAndVim9Failure(['VAR v = range(5)[2 : 3'], ['E111:', 'E1097:', 'E111:'])
  call CheckLegacyAndVim9Failure(['VAR l = insert([1, 2, 3], 4, 10)'], 'E684:')
  call CheckLegacyAndVim9Failure(['VAR l = insert([1, 2, 3], 4, -10)'], 'E684:')
  call CheckLegacyAndVim9Failure(['VAR l = insert([1, 2, 3], 4, [])'], ['E745:', 'E1013:', 'E1210:'])

  call CheckLegacyAndVim9Failure(['VAR l = [1, 2, 3]', 'LET l[i] = 3'], ['E121:', 'E1001:', 'E121:'])
  call CheckLegacyAndVim9Failure(['VAR l = [1, 2, 3]', 'LET l[1.1] = 4'], ['E805:', 'E1012:', 'E805:'])
  call CheckLegacyAndVim9Failure(['VAR l = [1, 2, 3]', 'LET l[: i] = [4, 5]'], ['E121:', 'E1001:', 'E121:'])
  call CheckLegacyAndVim9Failure(['VAR l = [1, 2, 3]', 'LET l[: 3.2] = [4, 5]'], ['E805:', 'E1012:', 'E805:'])
  " call CheckLegacyAndVim9Failure(['VAR t = test_unknown()', 'echo t[0]'], ['E685:', 'E909:', 'E685:'])
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
  call assert_equal([], items(d))
  call assert_equal([], keys(d))
  call assert_equal([], values(d))
  call assert_false(has_key(d, 'k'))
  call assert_equal('{}', string(d))
  call assert_fails('let x = d[10]')
  call assert_equal({}, {})
  call assert_equal(0, len(copy(d)))
  call assert_equal(0, count(d, 'k'))
  call assert_equal({}, deepcopy(d))
  call assert_equal(20, get(d, 'k', 20))
  call assert_equal(0, min(d))
  call assert_equal(0, max(d))
  call assert_equal(0, remove(d, 'k'))
  call assert_equal('{}', string(d))
  " call assert_equal(0, extend(d, d, 0))
  lockvar d
  call assert_equal(1, islocked('d'))
  unlockvar d
endfunc

" Test for the indexof() function
func Test_indexof()
  let l = [#{color: 'red'}, #{color: 'blue'}, #{color: 'green'}]
  call assert_equal(0, indexof(l, {i, v -> v.color == 'red'}))
  call assert_equal(2, indexof(l, {i, v -> v.color == 'green'}))
  call assert_equal(-1, indexof(l, {i, v -> v.color == 'grey'}))
  call assert_equal(1, indexof(l, "v:val.color == 'blue'"))
  call assert_equal(-1, indexof(l, "v:val.color == 'cyan'"))

  let l = [#{n: 10}, #{n: 10}, #{n: 20}]
  call assert_equal(0, indexof(l, "v:val.n == 10", #{startidx: 0}))
  call assert_equal(1, indexof(l, "v:val.n == 10", #{startidx: -2}))
  call assert_equal(-1, indexof(l, "v:val.n == 10", #{startidx: 4}))
  call assert_equal(-1, indexof(l, "v:val.n == 10", #{startidx: -4}))
  call assert_equal(0, indexof(l, "v:val.n == 10", v:_null_dict))

  let s = ["a", "b", "c"]
  call assert_equal(2, indexof(s, {_, v -> v == 'c'}))
  call assert_equal(-1, indexof(s, {_, v -> v == 'd'}))
  call assert_equal(-1, indexof(s, {_, v -> "v == 'd'"}))

  call assert_equal(-1, indexof([], {i, v -> v == 'a'}))
  call assert_equal(-1, indexof([1, 2, 3], {_, v -> "v == 2"}))
  call assert_equal(-1, indexof(v:_null_list, {i, v -> v == 'a'}))
  call assert_equal(-1, indexof(l, v:_null_string))
  " Nvim doesn't have null functions
  " call assert_equal(-1, indexof(l, test_null_function()))

  " failure cases
  call assert_fails('let i = indexof(l, "v:val == ''cyan''")', 'E735:')
  call assert_fails('let i = indexof(l, "color == ''cyan''")', 'E121:')
  call assert_fails('let i = indexof(l, {})', 'E1256:')
  call assert_fails('let i = indexof({}, "v:val == 2")', 'E1226:')
  call assert_fails('let i = indexof([], "v:val == 2", [])', 'E1206:')

  func TestIdx(k, v)
    return a:v.n == 20
  endfunc
  call assert_equal(2, indexof(l, function("TestIdx")))
  delfunc TestIdx
  func TestIdx(k, v)
    return {}
  endfunc
  call assert_fails('let i = indexof(l, function("TestIdx"))', 'E728:')
  delfunc TestIdx
  func TestIdx(k, v)
    throw "IdxError"
  endfunc
  call assert_fails('let i = indexof(l, function("TestIdx"))', 'E605:')
  delfunc TestIdx
endfunc

func Test_extendnew_leak()
  " This used to leak memory
  for i in range(100) | silent! call extendnew([], [], []) | endfor
  for i in range(100) | silent! call extendnew({}, {}, {}) | endfor
endfunc

" Test for comparing deeply nested List/Dict values
func Test_deep_nested_listdict_compare()
  let lines =<< trim END
    func GetNestedList(sz)
      let l = []
      let x = l
      for i in range(a:sz)
        let y = [1]
        call add(x, y)
        let x = y
      endfor
      return l
    endfunc

    VAR l1 = GetNestedList(1000)
    VAR l2 = GetNestedList(999)
    call assert_false(l1 == l2)

    #" after 1000 nested items, the lists are considered to be equal
    VAR l3 = GetNestedList(1001)
    VAR l4 = GetNestedList(1002)
    call assert_true(l3 == l4)
  END
  call CheckLegacyAndVim9Success(lines)

  let lines =<< trim END
    func GetNestedDict(sz)
      let d = {}
      let x = d
      for i in range(a:sz)
        let y = {}
        let x['a'] = y
        let x = y
      endfor
      return d
    endfunc

    VAR d1 = GetNestedDict(1000)
    VAR d2 = GetNestedDict(999)
    call assert_false(d1 == d2)

    #" after 1000 nested items, the Dicts are considered to be equal
    VAR d3 = GetNestedDict(1001)
    VAR d4 = GetNestedDict(1002)
    call assert_true(d3 == d4)
  END
  call CheckLegacyAndVim9Success(lines)
endfunc

" vim: shiftwidth=2 sts=2 expandtab
