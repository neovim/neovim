-- Tests for List and Dictionary types.

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('55', function()
  setup(clear)

  it('is working', function()
    insert([[
      start:]])

    execute('fun Test(...)')
    execute('lang C')
    -- Creating List directly with different types.
    execute([=[let l = [1, 'as''d', [1, 2, function("strlen")], {'a': 1},]]=])
    execute('$put =string(l)')
    execute('$put =string(l[-1])')
    execute('$put =string(l[-4])')
    execute('try')
    execute('  $put =string(l[-5])')
    execute('catch')
    execute('  $put =v:exception[:14]')
    execute('endtry')
    -- List slices.
    execute('$put =string(l[:])')
    execute('$put =string(l[1:])')
    execute('$put =string(l[:-2])')
    execute('$put =string(l[0:8])')
    execute('$put =string(l[8:-1])')

    -- List identity.
    execute('let ll = l')
    execute('let lx = copy(l)')
    execute('try')
    execute('  $put =(l == ll) . (l isnot ll) . (l is ll) . (l == lx) . (l is lx) . (l isnot lx)')
    execute('catch')
    execute('  $put =v:exception')
    execute('endtry')

    -- Creating Dictionary directly with different types.
    execute([=[let d = {001: 'asd', 'b': [1, 2, function('strlen')], -1: {'a': 1},}]=])
    execute('$put =string(d) . d.1')
    execute('$put =string(sort(keys(d)))')
    execute('$put =string (values(d))')
    execute('for [key, val] in items(d)')
    execute([[  $put =key . ':' . string(val)]])
    execute('  unlet key val')
    execute('endfor')
    execute('call extend  (d, {3:33, 1:99})')
    execute([[call extend(d, {'b':'bbb', 'c':'ccc'}, "keep")]])
    execute('try')
    execute('  call extend(d, {3:333,4:444}, "error")')
    execute('catch')
    execute('  $put =v:exception[:15] . v:exception[-1:-1]')
    execute('endtry')
    execute('$put =string(d)')
    execute([=[call filter(d, 'v:key =~ ''[ac391]''')]=])
    execute('$put =string(d)')

    -- Dictionary identity.
    execute('let dd = d')
    execute('let dx = copy(d)')
    execute('try')
    execute('  $put =(d == dd) . (d isnot dd) . (d is dd) . (d == dx) . (d is dx) . (d isnot dx)')
    execute('catch')
    execute('  $put =v:exception')
    execute('endtry')

    -- Changing var type should fail.
    execute('try')
    execute('  let d = []')
    execute('catch')
    execute('  $put =v:exception[:14] . v:exception[-1:-1]')
    execute('endtry')
    execute('try')
    execute('  let l = {}')
    execute('catch')
    execute('  $put =v:exception[:14] . v:exception[-1:-1]')
    execute('endtry')

    -- Removing items with :unlet.
    execute('unlet l[2]')
    execute('$put =string(l)')
    execute('let l = range(8)')
    execute('try')
    execute('unlet l[:3]')
    execute('unlet l[1:]')
    execute('catch')
    execute('$put =v:exception')
    execute('endtry')
    execute('$put =string(l)')

    execute('unlet d.c')
    execute('unlet d[-1]')
    execute('$put =string(d)')

    -- Removing items out of range: silently skip items that don't exist.
    feed('let l = [0, 1, 2, 3]<cr>')
    execute('unlet l[2:1]')
    execute('$put =string(l)')
    feed('let l = [0, 1, 2, 3]<cr>')
    execute('unlet l[2:2]')
    execute('$put =string(l)')
    feed('let l = [0, 1, 2, 3]<cr>')
    execute('unlet l[2:3]')
    execute('$put =string(l)')
    feed('let l = [0, 1, 2, 3]<cr>')
    execute('unlet l[2:4]')
    execute('$put =string(l)')
    feed('let l = [0, 1, 2, 3]<cr>')
    execute('unlet l[2:5]')
    execute('$put =string(l)')
    feed('let l = [0, 1, 2, 3]<cr>')
    execute('unlet l[-1:2]')
    execute('$put =string(l)')
    feed('let l = [0, 1, 2, 3]<cr>')
    execute('unlet l[-2:2]')
    execute('$put =string(l)')
    feed('let l = [0, 1, 2, 3]<cr>')
    execute('unlet l[-3:2]')
    execute('$put =string(l)')
    feed('let l = [0, 1, 2, 3]<cr>')
    execute('unlet l[-4:2]')
    execute('$put =string(l)')
    feed('let l = [0, 1, 2, 3]<cr>')
    execute('unlet l[-5:2]')
    execute('$put =string(l)')
    feed('let l = [0, 1, 2, 3]<cr>')
    execute('unlet l[-6:2]')
    execute('$put =string(l)')

    -- Assignment to a list.
    execute('let l = [0, 1, 2, 3]')
    execute('let [va, vb] = l[2:3]')
    execute('$put =va')
    execute('$put =vb')
    execute('try')
    execute('  let [va, vb] = l')
    execute('catch')
    execute('  $put =v:exception[:14]')
    execute('endtry')
    execute('try')
    execute('  let [va, vb] = l[1:1]')
    execute('catch')
    execute('  $put =v:exception[:14]')
    execute('endtry')

    -- Manipulating a big Dictionary (hashtable.c has a border of 1000 entries).
    execute('let d = {}')
    execute('for i in range(1500)')
    execute(' let d[i] = 3000 - i')
    execute('endfor')
    execute([=[$put =d[0] . ' ' . d[100] . ' ' . d[999] . ' ' . d[1400] . ' ' . d[1499]]=])
    execute('try')
    execute('  let n = d[1500]')
    execute('catch')
    execute([[  $put =substitute(v:exception, '\v(.{14}).*( \d{4}).*', '\1\2', '')]])
    execute('endtry')
    -- Lookup each items.
    execute('for i in range(1500)')
    execute(' if d[i] != 3000 - i')
    execute('  $put =d[i]')
    execute(' endif')
    execute('endfor')
    execute(' let i += 1')
    -- Delete even items.
    execute('while i >= 2')
    execute(' let i -= 2')
    execute(' unlet d[i]')
    execute('endwhile')
    execute([=[$put =get(d, 1500 - 100, 'NONE') . ' ' . d[1]]=])
    -- Delete odd items, checking value, one intentionally wrong.
    execute('let d[33] = 999')
    execute('let i = 1')
    execute('while i < 1500')
    execute(' if d[i] != 3000 - i')
    execute([=[  $put =i . '=' . d[i]]=])
    execute(' else')
    execute('  unlet d[i]')
    execute(' endif')
    execute(' let i += 2')
    execute('endwhile')
    -- Must be almost empty now.
    execute('$put =string(d)')
    execute('unlet d')

    -- Dictionary function.
    execute('let dict = {}')
    execute('func dict.func(a) dict')
    execute('  $put =a:a . len(self.data)')
    execute('endfunc')
    execute('let dict.data = [1,2,3]')
    execute('call dict.func("len: ")')
    execute('let x = dict.func("again: ")')
    execute('try')
    execute('  let Fn = dict.func')
    execute([[  call Fn('xxx')]])
    execute('catch')
    execute('  $put =v:exception[:15]')
    execute('endtry')

    -- Function in script-local List or Dict.
    execute('let g:dict = {}')
    execute('function g:dict.func() dict')
    execute([=[  $put ='g:dict.func'.self.foo[1].self.foo[0]('asdf')]=])
    execute('endfunc')
    execute([=[let g:dict.foo = ['-', 2, 3]]=])
    execute([[call insert(g:dict.foo, function('strlen'))]])
    execute('call g:dict.func()')

    -- Nasty: remove func from Dict that's being called (works).
    execute('let d = {1:1}')
    execute('func d.func(a)')
    execute('  return "a:". a:a')
    execute('endfunc')
    execute([[$put =d.func(string(remove(d, 'func')))]])

    -- Nasty: deepcopy() dict that refers to itself (fails when noref used).
    execute('let d = {1:1, 2:2}')
    execute('let l = [4, d, 6]')
    execute('let d[3] = l')
    execute('let dc = deepcopy(d)')
    execute('try')
    execute('  let dc = deepcopy(d, 1)')
    execute('catch')
    execute('  $put =v:exception[:14]')
    execute('endtry')
    execute('let l2 = [0, l, l, 3]')
    execute('let l[1] = l2')
    execute('let l3 = deepcopy(l2)')
    execute([=[$put ='same list: ' . (l3[1] is l3[2])]=])

    -- Locked variables.
    execute('for depth in range(5)')
    execute([[  $put ='depth is ' . depth]])
    execute('  for u in range(3)')
    execute('    unlet l')
    execute('    let l = [0, [1, [2, 3]], {4: 5, 6: {7: 8}}]')
    execute('    exe "lockvar " . depth . " l"')
    execute('    if u == 1')
    execute('      exe "unlockvar l"')
    execute('    elseif u == 2')
    execute('      exe "unlockvar " . depth . " l"')
    execute('    endif')
    execute([=[    let ps = islocked("l").islocked("l[1]").islocked("l[1][1]").islocked("l[1][1][0]").'-'.islocked("l[2]").islocked("l[2]['6']").islocked("l[2]['6'][7]")]=])
    execute('    $put =ps')
    execute([[    let ps = '']])
    execute('    try')
    execute('      let l[1][1][0] = 99')
    execute([[      let ps .= 'p']])
    execute('    catch')
    execute([[      let ps .= 'F']])
    execute('    endtry')
    execute('    try')
    execute('      let l[1][1] = [99]')
    execute([[      let ps .= 'p']])
    execute('    catch')
    execute([[      let ps .= 'F']])
    execute('    endtry')
    execute('    try')
    execute('      let l[1] = [99]')
    execute([[      let ps .= 'p']])
    execute('    catch')
    execute([[      let ps .= 'F']])
    execute('    endtry')
    execute('    try')
    execute([=[      let l[2]['6'][7] = 99]=])
    execute([[      let ps .= 'p']])
    execute('    catch')
    execute([[      let ps .= 'F']])
    execute('    endtry')
    execute('    try')
    execute('      let l[2][6] = {99: 99}')
    execute([[      let ps .= 'p']])
    execute('    catch')
    execute([[      let ps .= 'F']])
    execute('    endtry')
    execute('    try')
    execute('      let l[2] = {99: 99}')
    execute([[      let ps .= 'p']])
    execute('    catch')
    execute([[      let ps .= 'F']])
    execute('    endtry')
    execute('    try')
    execute('      let l = [99]')
    execute([[      let ps .= 'p']])
    execute('    catch')
    execute([[      let ps .= 'F']])
    execute('    endtry')
    execute('    $put =ps')
    execute('  endfor')
    execute('endfor')

    -- Unletting locked variables.
    execute([[$put ='Unletting:']])
    execute('for depth in range(5)')
    execute([[  $put ='depth is ' . depth]])
    execute('  for u in range(3)')
    execute('    unlet l')
    execute('    let l = [0, [1, [2, 3]], {4: 5, 6: {7: 8}}]')
    execute('    exe "lockvar " . depth . " l"')
    execute('    if u == 1')
    execute('      exe "unlockvar l"')
    execute('    elseif u == 2')
    execute('      exe "unlockvar " . depth . " l"')
    execute('    endif')
    execute([=[    let ps = islocked("l").islocked("l[1]").islocked("l[1][1]").islocked("l[1][1][0]").'-'.islocked("l[2]").islocked("l[2]['6']").islocked("l[2]['6'][7]")]=])
    execute('    $put =ps')
    execute([[    let ps = '']])
    execute('    try')
    execute([=[      unlet l[2]['6'][7]]=])
    execute([[      let ps .= 'p']])
    execute('    catch')
    execute([[      let ps .= 'F']])
    execute('    endtry')
    execute('    try')
    execute('      unlet l[2][6]')
    execute([[      let ps .= 'p']])
    execute('    catch')
    execute([[      let ps .= 'F']])
    execute('    endtry')
    execute('    try')
    execute('      unlet l[2]')
    execute([[      let ps .= 'p']])
    execute('    catch')
    execute([[      let ps .= 'F']])
    execute('    endtry')
    execute('    try')
    execute('      unlet l[1][1][0]')
    execute([[      let ps .= 'p']])
    execute('    catch')
    execute([[      let ps .= 'F']])
    execute('    endtry')
    execute('    try')
    execute('      unlet l[1][1]')
    execute([[      let ps .= 'p']])
    execute('    catch')
    execute([[      let ps .= 'F']])
    execute('    endtry')
    execute('    try')
    execute('      unlet l[1]')
    execute([[      let ps .= 'p']])
    execute('    catch')
    execute([[      let ps .= 'F']])
    execute('    endtry')
    execute('    try')
    execute('      unlet l')
    execute([[      let ps .= 'p']])
    execute('    catch')
    execute([[      let ps .= 'F']])
    execute('    endtry')
    execute('    $put =ps')
    execute('  endfor')
    execute('endfor')

    -- Locked variables and :unlet or list / dict functions.
    execute([[$put ='Locks and commands or functions:']])

    execute([[$put ='No :unlet after lock on dict:']])
    execute('unlet! d')
    execute([[let d = {'a': 99, 'b': 100}]])
    execute('lockvar 1 d')
    execute('try')
    execute('  unlet d.a')
    execute([[  $put ='did :unlet']])
    execute('catch')
    execute('  $put =v:exception[:16]')
    execute('endtry')
    execute('$put =string(d)')

    execute([[$put =':unlet after lock on dict item:']])
    execute('unlet! d')
    execute([[let d = {'a': 99, 'b': 100}]])
    execute('lockvar d.a')
    execute('try')
    execute('  unlet d.a')
    execute([[  $put ='did :unlet']])
    execute('catch')
    execute('  $put =v:exception[:16]')
    execute('endtry')
    execute('$put =string(d)')

    execute([[$put ='filter() after lock on dict item:']])
    execute('unlet! d')
    execute([[let d = {'a': 99, 'b': 100}]])
    execute('lockvar d.a')
    execute('try')
    execute([[  call filter(d, 'v:key != "a"')]])
    execute([[  $put ='did filter()']])
    execute('catch')
    execute('  $put =v:exception[:16]')
    execute('endtry')
    execute('$put =string(d)')

    execute([[$put ='map() after lock on dict:']])
    execute('unlet! d')
    execute([[let d = {'a': 99, 'b': 100}]])
    execute('lockvar 1 d')
    execute('try')
    execute([[  call map(d, 'v:val + 200')]])
    execute([[  $put ='did map()']])
    execute('catch')
    execute('  $put =v:exception[:16]')
    execute('endtry')
    execute('$put =string(d)')

    execute([[$put ='No extend() after lock on dict item:']])
    execute('unlet! d')
    execute([[let d = {'a': 99, 'b': 100}]])
    execute('lockvar d.a')
    execute('try')
    execute([[  $put =string(extend(d, {'a': 123}))]])
    execute([[  $put ='did extend()']])
    execute('catch')
    execute('  $put =v:exception[:14]')
    execute('endtry')
    execute('$put =string(d)')

    execute([[$put ='No remove() of write-protected scope-level variable:']])
    execute('fun! Tfunc(this_is_a_loooooooooong_parameter_name)')
    execute('  try')
    execute([[    $put =string(remove(a:, 'this_is_a_loooooooooong_parameter_name'))]])
    execute([[    $put ='did remove()']])
    execute('  catch')
    execute('    $put =v:exception[:14]')
    execute('  endtry')
    execute('endfun')
    execute([[call Tfunc('testval')]])

    execute([[$put ='No extend() of write-protected scope-level variable:']])
    execute('fun! Tfunc(this_is_a_loooooooooong_parameter_name)')
    execute('  try')
    execute([[    $put =string(extend(a:, {'this_is_a_loooooooooong_parameter_name': 1234}))]])
    execute([[    $put ='did extend()']])
    execute('  catch')
    execute('    $put =v:exception[:14]')
    execute('  endtry')
    execute('endfun')
    execute([[call Tfunc('testval')]])

    execute([[$put ='No :unlet of variable in locked scope:']])
    execute('let b:testvar = 123')
    execute('lockvar 1 b:')
    execute('try')
    execute('  unlet b:testvar')
    execute([[  $put ='b:testvar was :unlet: '. (!exists('b:testvar'))]])
    execute('catch')
    execute('  $put =v:exception[:16]')
    execute('endtry')
    execute('unlockvar 1 b:')
    execute('unlet! b:testvar')

    execute([[$put ='No :let += of locked list variable:']])
    execute([=[let l = ['a', 'b', 3]]=])
    execute('lockvar 1 l')
    execute('try')
    execute([=[  let l += ['x']]=])
    execute([[  $put ='did :let +=']])
    execute('catch')
    execute('  $put =v:exception[:14]')
    execute('endtry')
    execute('$put =string(l)')

    execute('unlet l')
    execute('let l = [1, 2, 3, 4]')
    execute('lockvar! l')
    execute('$put =string(l)')
    execute('unlockvar l[1]')
    execute('unlet l[0:1]')
    execute('$put =string(l)')
    execute('unlet l[1:2]')
    execute('$put =string(l)')
    execute('unlockvar l[1]')
    execute('let l[0:1] = [0, 1]')
    execute('$put =string(l)')
    execute('let l[1:2] = [0, 1]')
    execute('$put =string(l)')
    execute('unlet l')
    -- :lockvar/islocked() triggering script autoloading.
    execute('set rtp+=./sautest')
    execute('lockvar g:footest#x')
    execute('unlockvar g:footest#x')
    execute([[$put ='locked g:footest#x:'.islocked('g:footest#x')]])
    execute([[$put ='exists g:footest#x:'.exists('g:footest#x')]])
    execute([[$put ='g:footest#x: '.g:footest#x]])

    -- A:000 function argument.
    -- First the tests that should fail.
    execute('try')
    execute('  let a:000 = [1, 2]')
    execute('catch')
    execute([[  $put ='caught a:000']])
    execute('endtry')
    execute('try')
    execute('  let a:000[0] = 9')
    execute('catch')
    execute([=[  $put ='caught a:000[0]']=])
    execute('endtry')
    execute('try')
    execute('  let a:000[2] = [9, 10]')
    execute('catch')
    execute([=[  $put ='caught a:000[2]']=])
    execute('endtry')
    execute('try')
    execute('  let a:000[3] = {9: 10}')
    execute('catch')
    execute([=[  $put ='caught a:000[3]']=])
    execute('endtry')
    -- Now the tests that should pass.
    execute('try')
    execute('  let a:000[2][1] = 9')
    execute('  call extend(a:000[2], [5, 6])')
    execute('  let a:000[3][5] = 8')
    execute([=[  let a:000[3]['a'] = 12]=])
    execute('  $put =string(a:000)')
    execute('catch')
    execute([[  $put ='caught ' . v:exception]])
    execute('endtry')

    -- Reverse(), sort(), uniq().
    execute([=[let l = ['-0', 'A11', 2, 2, 'xaaa', 4, 'foo', 'foo6', 'foo', [0, 1, 2], 'x8', [0, 1, 2], 1.5]]=])
    execute('$put =string(uniq(copy(l)))')
    execute('$put =string(reverse(l))')
    execute('$put =string(reverse(reverse(l)))')
    execute('$put =string(sort(l))')
    execute('$put =string(reverse(sort(l)))')
    execute('$put =string(sort(reverse(sort(l))))')
    execute('$put =string(uniq(sort(l)))')
    execute([=[let l=[7, 9, 'one', 18, 12, 22, 'two', 10.0e-16, -1, 'three', 0xff, 0.22, 'four']]=])
    execute([[$put =string(sort(copy(l), 'n'))]])
    execute([=[let l=[7, 9, 18, 12, 22, 10.0e-16, -1, 0xff, 0, -0, 0.22, 'bar', 'BAR', 'Bar', 'Foo', 'FOO', 'foo', 'FOOBAR', {}, []]]=])
    execute('$put =string(sort(copy(l), 1))')
    execute([[$put =string(sort(copy(l), 'i'))]])
    execute('$put =string(sort(copy(l)))')

    -- Splitting a string to a List.
    execute([[$put =string(split('  aa  bb '))]])
    execute([[$put =string(split('  aa  bb  ', '\W\+', 0))]])
    execute([[$put =string(split('  aa  bb  ', '\W\+', 1))]])
    execute([[$put =string(split('  aa  bb  ', '\W', 1))]])
    execute([[$put =string(split(':aa::bb:', ':', 0))]])
    execute([[$put =string(split(':aa::bb:', ':', 1))]])
    execute([[$put =string(split('aa,,bb, cc,', ',\s*', 1))]])
    execute([[$put =string(split('abc', '\zs'))]])
    execute([[$put =string(split('abc', '\zs', 1))]])

    -- Compare recursively linked list and dict.
    execute('let l = [1, 2, 3, 4]')
    execute([[let d = {'1': 1, '2': l, '3': 3}]])
    execute('let l[1] = d')
    execute('$put =(l == l)')
    execute('$put =(d == d)')
    execute('$put =(l != deepcopy(l))')
    execute('$put =(d != deepcopy(d))')

    -- Compare complex recursively linked list and dict.
    execute('let l = []')
    execute('call add(l, l)')
    execute('let dict4 = {"l": l}')
    execute('call add(dict4.l, dict4)')
    execute('let lcopy = deepcopy(l)')
    execute('let dict4copy = deepcopy(dict4)')
    execute('$put =(l == lcopy)')
    execute('$put =(dict4 == dict4copy)')

    -- Pass the same List to extend().
    execute('let l = [1, 2, 3, 4, 5]')
    execute('call extend(l, l)')
    execute('$put =string(l)')

    -- Pass the same Dict to extend().
    execute([[let d = { 'a': {'b': 'B'}}]])
    execute('call extend(d, d)')
    execute('$put =string(d)')

    -- Pass the same Dict to extend() with "error".
    execute('try')
    execute('  call extend(d, d, "error")')
    execute('catch')
    execute('  $put =v:exception[:15] . v:exception[-1:-1]')
    execute('endtry')
    execute('$put =string(d)')

    -- Test for range assign.
    execute('let l = [0]')
    execute('let l[:] = [1, 2]')
    execute('$put =string(l)')
    execute('endfun')

    -- This may take a while.
    execute('call Test(1, 2, [3, 4], {5: 6})')

    execute('delfunc Test')
    execute('unlet dict')
    execute('call garbagecollect(1)')

    -- Test for patch 7.3.637.
    execute([[let a = 'No error caught']])
    execute([=[try|foldopen|catch|let a = matchstr(v:exception,'^[^ ]*')|endtry]=])

    feed('o<C-R>=a<CR><esc>')
    execute('lang C')
    execute('redir => a')
    execute([=[try|foobar|catch|let a = matchstr(v:exception,'^[^ ]*')|endtry]=])
    execute('redir END')

    feed('o<C-R>=a<CR><esc>:<cr>')

    -- Assert buffer contents.
    expect([=[
      start:
      [1, 'as''d', [1, 2, function('strlen')], {'a': 1}]
      {'a': 1}
      1
      Vim(put):E684: 
      [1, 'as''d', [1, 2, function('strlen')], {'a': 1}]
      ['as''d', [1, 2, function('strlen')], {'a': 1}]
      [1, 'as''d', [1, 2, function('strlen')]]
      [1, 'as''d', [1, 2, function('strlen')], {'a': 1}]
      []
      101101
      {'1': 'asd', 'b': [1, 2, function('strlen')], '-1': {'a': 1}}asd
      ['-1', '1', 'b']
      ['asd', [1, 2, function('strlen')], {'a': 1}]
      1:'asd'
      b:[1, 2, function('strlen')]
      -1:{'a': 1}
      Vim(call):E737: 3
      {'c': 'ccc', '1': 99, 'b': [1, 2, function('strlen')], '3': 33, '-1': {'a': 1}}
      {'c': 'ccc', '1': 99, '3': 33, '-1': {'a': 1}}
      101101
      Vim(let):E706: d
      Vim(let):E706: l
      [1, 'as''d', {'a': 1}]
      [4]
      {'1': 99, '3': 33}
      [0, 1, 2, 3]
      [0, 1, 3]
      [0, 1]
      [0, 1]
      [0, 1]
      [0, 1, 2, 3]
      [0, 1, 3]
      [0, 3]
      [3]
      [3]
      [3]
      2
      3
      Vim(let):E687: 
      Vim(let):E688: 
      3000 2900 2001 1600 1501
      Vim(let):E716: 1500
      NONE 2999
      33=999
      {'33': 999}
      len: 3
      again: 3
      Vim(call):E725: 
      g:dict.func-4
      a:function('3')
      Vim(let):E698: 
      same list: 1
      depth is 0
      0000-000
      ppppppp
      0000-000
      ppppppp
      0000-000
      ppppppp
      depth is 1
      1000-000
      ppppppF
      0000-000
      ppppppp
      0000-000
      ppppppp
      depth is 2
      1100-100
      ppFppFF
      0000-000
      ppppppp
      0000-000
      ppppppp
      depth is 3
      1110-110
      pFFpFFF
      0010-010
      pFppFpp
      0000-000
      ppppppp
      depth is 4
      1111-111
      FFFFFFF
      0011-011
      FFpFFpp
      0000-000
      ppppppp
      Unletting:
      depth is 0
      0000-000
      ppppppp
      0000-000
      ppppppp
      0000-000
      ppppppp
      depth is 1
      1000-000
      ppFppFp
      0000-000
      ppppppp
      0000-000
      ppppppp
      depth is 2
      1100-100
      pFFpFFp
      0000-000
      ppppppp
      0000-000
      ppppppp
      depth is 3
      1110-110
      FFFFFFp
      0010-010
      FppFppp
      0000-000
      ppppppp
      depth is 4
      1111-111
      FFFFFFp
      0011-011
      FppFppp
      0000-000
      ppppppp
      Locks and commands or functions:
      No :unlet after lock on dict:
      Vim(unlet):E741: 
      {'a': 99, 'b': 100}
      :unlet after lock on dict item:
      did :unlet
      {'b': 100}
      filter() after lock on dict item:
      did filter()
      {'b': 100}
      map() after lock on dict:
      did map()
      {'a': 299, 'b': 300}
      No extend() after lock on dict item:
      Vim(put):E741: 
      {'a': 99, 'b': 100}
      No remove() of write-protected scope-level variable:
      Vim(put):E795: 
      No extend() of write-protected scope-level variable:
      Vim(put):E742: 
      No :unlet of variable in locked scope:
      Vim(unlet):E741: 
      No :let += of locked list variable:
      Vim(let):E741: 
      ['a', 'b', 3]
      [1, 2, 3, 4]
      [1, 2, 3, 4]
      [1, 2, 3, 4]
      [1, 2, 3, 4]
      [1, 2, 3, 4]
      locked g:footest#x:-1
      exists g:footest#x:0
      g:footest#x: 1
      caught a:000
      caught a:000[0]
      caught a:000[2]
      caught a:000[3]
      [1, 2, [3, 9, 5, 6], {'a': 12, '5': 8}]
      ['-0', 'A11', 2, 'xaaa', 4, 'foo', 'foo6', 'foo', [0, 1, 2], 'x8', [0, 1, 2], 1.5]
      [1.5, [0, 1, 2], 'x8', [0, 1, 2], 'foo', 'foo6', 'foo', 4, 'xaaa', 2, 2, 'A11', '-0']
      [1.5, [0, 1, 2], 'x8', [0, 1, 2], 'foo', 'foo6', 'foo', 4, 'xaaa', 2, 2, 'A11', '-0']
      ['-0', 'A11', 'foo', 'foo', 'foo6', 'x8', 'xaaa', 1.5, 2, 2, 4, [0, 1, 2], [0, 1, 2]]
      [[0, 1, 2], [0, 1, 2], 4, 2, 2, 1.5, 'xaaa', 'x8', 'foo6', 'foo', 'foo', 'A11', '-0']
      ['-0', 'A11', 'foo', 'foo', 'foo6', 'x8', 'xaaa', 1.5, 2, 2, 4, [0, 1, 2], [0, 1, 2]]
      ['-0', 'A11', 'foo', 'foo6', 'x8', 'xaaa', 1.5, 2, 4, [0, 1, 2]]
      [-1, 'one', 'two', 'three', 'four', 1.0e-15, 0.22, 7, 9, 12, 18, 22, 255]
      ['bar', 'BAR', 'Bar', 'Foo', 'FOO', 'foo', 'FOOBAR', -1, 0, 0, 0.22, 1.0e-15, 12, 18, 22, 255, 7, 9, [], {}]
      ['bar', 'BAR', 'Bar', 'Foo', 'FOO', 'foo', 'FOOBAR', -1, 0, 0, 0.22, 1.0e-15, 12, 18, 22, 255, 7, 9, [], {}]
      ['BAR', 'Bar', 'FOO', 'FOOBAR', 'Foo', 'bar', 'foo', -1, 0, 0, 0.22, 1.0e-15, 12, 18, 22, 255, 7, 9, [], {}]
      ['aa', 'bb']
      ['aa', 'bb']
      ['', 'aa', 'bb', '']
      ['', '', 'aa', '', 'bb', '', '']
      ['aa', '', 'bb']
      ['', 'aa', '', 'bb', '']
      ['aa', '', 'bb', 'cc', '']
      ['a', 'b', 'c']
      ['', 'a', '', 'b', '', 'c', '']
      1
      1
      0
      0
      1
      1
      [1, 2, 3, 4, 5, 1, 2, 3, 4, 5]
      {'a': {'b': 'B'}}
      Vim(call):E737: a
      {'a': {'b': 'B'}}
      [1, 2]
      Vim(foldopen):E490:
      
      
      Error detected while processing :
      E492: Not an editor command: foobar|catch|let a = matchstr(v:exception,'^[^ ]*')|endtry
      ]=])
  end)
end)
