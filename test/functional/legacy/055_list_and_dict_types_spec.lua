-- Tests for List and Dictionary types.

local n = require('test.functional.testnvim')()

local feed, source = n.feed, n.source
local clear, feed_command, expect = n.clear, n.feed_command, n.expect

describe('list and dictionary types', function()
  before_each(clear)

  it('creating list directly with different types', function()
    source([[
      lang C
      let l = [1, 'as''d', [1, 2, function("strlen")], {'a': 1},]
      $put =string(l)
      $put =string(l[-1])
      $put =string(l[-4])
      try
        $put =string(l[-5])
      catch
        $put =v:exception[:14]
      endtry]])
    expect([[

      [1, 'as''d', [1, 2, function('strlen')], {'a': 1}]
      {'a': 1}
      1
      Vim(put):E684: ]])
  end)

  it('list slices', function()
    source([[
      lang C
      " The list from the first test repeated after splitting the tests.
      let l = [1, 'as''d', [1, 2, function("strlen")], {'a': 1},]
      $put =string(l[:])
      $put =string(l[1:])
      $put =string(l[:-2])
      $put =string(l[0:8])
      $put =string(l[8:-1])]])
    expect([=[

      [1, 'as''d', [1, 2, function('strlen')], {'a': 1}]
      ['as''d', [1, 2, function('strlen')], {'a': 1}]
      [1, 'as''d', [1, 2, function('strlen')]]
      [1, 'as''d', [1, 2, function('strlen')], {'a': 1}]
      []]=])
  end)

  it('list identity', function()
    source([[
      lang C
      " The list from the first test repeated after splitting the tests.
      let l = [1, 'as''d', [1, 2, function("strlen")], {'a': 1},]
      let ll = l
      let lx = copy(l)
      try
	      $put =(l == ll) . (l isnot ll) . (l is ll) . (l == lx) .
	        \ (l is lx) . (l isnot lx)
      catch
	      $put =v:exception
      endtry]])
    expect('\n101101')
  end)

  it('creating dictionary directly with different types', function()
    source([[
      lang C
      let d = {001: 'asd', 'b': [1, 2, function('strlen')], -1: {'a': 1},}
      $put =string(d) . d.1
      $put =string(sort(keys(d)))
      $put =string (values(d))
      for [key, val] in items(d)
	      $put =key . ':' . string(val)
	      unlet key val
      endfor
      call extend  (d, {3:33, 1:99})
      call extend(d, {'b':'bbb', 'c':'ccc'}, "keep")
      try
	      call extend(d, {3:333,4:444}, "error")
      catch
	      $put =v:exception[:15] . v:exception[-1:-1]
      endtry
      $put =string(d)
      call filter(d, 'v:key =~ ''[ac391]''')
      $put =string(d)]])
    expect([[

      {'1': 'asd', 'b': [1, 2, function('strlen')], '-1': {'a': 1}}asd
      ['-1', '1', 'b']
      ['asd', [1, 2, function('strlen')], {'a': 1}]
      1:'asd'
      b:[1, 2, function('strlen')]
      -1:{'a': 1}
      Vim(call):E737: 3
      {'c': 'ccc', '1': 99, 'b': [1, 2, function('strlen')], '3': 33, '-1': {'a': 1}}
      {'c': 'ccc', '1': 99, '3': 33, '-1': {'a': 1}}]])
  end)

  it('dictionary identity', function()
    source([[
      lang C
      " The dict from the first test repeated after splitting the tests.
      let d = {'c': 'ccc', '1': 99, '3': 33, '-1': {'a': 1}}
      let dd = d
      let dx = copy(d)
      try
	      $put =(d == dd) . (d isnot dd) . (d is dd) . (d == dx) . (d is dx) .
	        \ (d isnot dx)
      catch
	      $put =v:exception
      endtry]])
    expect('\n101101')
  end)

  it('removing items with :unlet', function()
    source([[
      lang C
      " The list from the first test repeated after splitting the tests.
      let l = [1, 'as''d', [1, 2, function("strlen")], {'a': 1},]
      " The dict from the first test repeated after splitting the tests.
      let d = {'c': 'ccc', '1': 99, '3': 33, '-1': {'a': 1}}
      unlet l[2]
      $put =string(l)
      let l = range(8)
      try
	      unlet l[:3]
	      unlet l[1:]
      catch
	      $put =v:exception
      endtry
      $put =string(l)

      unlet d.c
      unlet d[-1]
      $put =string(d)]])
    expect([[

      [1, 'as''d', {'a': 1}]
      [4]
      {'1': 99, '3': 33}]])
  end)

  it("removing items out of range: silently skip items that don't exist", function()
    -- We can not use source() here as we want to ignore all errors.
    feed_command('lang C')
    feed_command('let l = [0, 1, 2, 3]')
    feed_command('unlet l[2:1]')
    feed_command('$put =string(l)')
    feed_command('let l = [0, 1, 2, 3]')
    feed_command('unlet l[2:2]')
    feed_command('$put =string(l)')
    feed_command('let l = [0, 1, 2, 3]')
    feed_command('unlet l[2:3]')
    feed_command('$put =string(l)')
    feed_command('let l = [0, 1, 2, 3]')
    feed_command('unlet l[2:4]')
    feed_command('$put =string(l)')
    feed_command('let l = [0, 1, 2, 3]')
    feed_command('unlet l[2:5]')
    feed_command('$put =string(l)')
    feed_command('let l = [0, 1, 2, 3]')
    feed_command('unlet l[-1:2]')
    feed_command('$put =string(l)')
    feed_command('let l = [0, 1, 2, 3]')
    feed_command('unlet l[-2:2]')
    feed_command('$put =string(l)')
    feed_command('let l = [0, 1, 2, 3]')
    feed_command('unlet l[-3:2]')
    feed_command('$put =string(l)')
    feed_command('let l = [0, 1, 2, 3]')
    feed_command('unlet l[-4:2]')
    feed_command('$put =string(l)')
    feed_command('let l = [0, 1, 2, 3]')
    feed_command('unlet l[-5:2]')
    feed_command('$put =string(l)')
    feed_command('let l = [0, 1, 2, 3]')
    feed_command('unlet l[-6:2]')
    feed_command('$put =string(l)')
    expect([=[

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
      [3]]=])
  end)

  -- luacheck: ignore 613 (Trailing whitespace in a string)
  it('assignment to a list', function()
    source([[
      let l = [0, 1, 2, 3]
      let [va, vb] = l[2:3]
      $put =va
      $put =vb
      try
	      let [va, vb] = l
      catch
	      $put =v:exception[:14]
      endtry
      try
	      let [va, vb] = l[1:1]
      catch
	      $put =v:exception[:14]
      endtry]])
    expect([[

      2
      3
      Vim(let):E687: 
      Vim(let):E688: ]])
  end)

  it('manipulating a big dictionary', function()
    -- Manipulating a big Dictionary (hashtable.c has a border of 1000
    -- entries).
    source([[
      let d = {}
      for i in range(1500)
	      let d[i] = 3000 - i
      endfor
      $put =d[0] . ' ' . d[100] . ' ' . d[999] . ' ' . d[1400] . ' ' .
	      \ d[1499]
      try
	      let n = d[1500]
      catch
	      $put = substitute(v:exception, '\v(.{14}).*( \"\d{4}\").*', '\1\2', '')
      endtry
      " Lookup each items.
      for i in range(1500)
	      if d[i] != 3000 - i
	        $put =d[i]
	      endif
      endfor
      let i += 1
      " Delete even items.
      while i >= 2
	      let i -= 2
	      unlet d[i]
      endwhile
      $put =get(d, 1500 - 100, 'NONE') . ' ' . d[1]
      " Delete odd items, checking value, one intentionally wrong.
      let d[33] = 999
      let i = 1
      while i < 1500
	      if d[i] != 3000 - i
	        $put =i . '=' . d[i]
	      else
	        unlet d[i]
	      endif
	      let i += 2
      endwhile
      " Must be almost empty now.
      $put =string(d)]])
    expect([[

      3000 2900 2001 1600 1501
      Vim(let):E716: "1500"
      NONE 2999
      33=999
      {'33': 999}]])
  end)

  it('dictionary function', function()
    source([[
      let dict = {}
      func dict.func(a) dict
	      $put =a:a . len(self.data)
      endfunc
      let dict.data = [1,2,3]
      call dict.func("len: ")
      let x = dict.func("again: ")
      let Fn = dict.func
      call Fn('xxx')]])
    expect([[

      len: 3
      again: 3
      xxx3]])
  end)

  it('Function in script-local List or Dict', function()
    source([[
      let g:dict = {}
      function g:dict.func() dict
	      $put ='g:dict.func'.self.foo[1].self.foo[0]('asdf')
      endfunc
      let g:dict.foo = ['-', 2, 3]
      call insert(g:dict.foo, function('strlen'))
      call g:dict.func()]])
    expect('\ng:dict.func-4')
  end)

  it("remove func from dict that's being called (works)", function()
    source([[
      let d = {1:1}
      func d.func(a)
	      return "a:". a:a
      endfunc
      $put =d.func(string(remove(d, 'func')))]])
    -- The function number changed from 3 to 1 because we split the test.
    -- There were two other functions in the old test before this.
    expect("\na:function('1')")
  end)

  it('deepcopy() dict that refers to itself', function()
    -- Nasty: deepcopy() dict that refers to itself (fails when noref used).
    source([[
      let d = {1:1, 2:2}
      let l = [4, d, 6]
      let d[3] = l
      let dc = deepcopy(d)
      try
	      let dc = deepcopy(d, 1)
      catch
	      $put =v:exception[:14]
      endtry
      let l2 = [0, l, l, 3]
      let l[1] = l2
      let l3 = deepcopy(l2)
      $put ='same list: ' . (l3[1] is l3[2])]])
    expect([[

      Vim(let):E698: 
      same list: 1]])
  end)

  it('locked variables and :unlet or list / dict functions', function()
    source([[
      $put ='Locks and commands or functions:'

      $put ='No :unlet after lock on dict:'
      unlet! d
      let d = {'a': 99, 'b': 100}
      lockvar 1 d
      try
        unlet d.a
        $put ='did :unlet'
      catch
        $put =v:exception[:16]
      endtry
      $put =string(d)

      $put =':unlet after lock on dict item:'
      unlet! d
      let d = {'a': 99, 'b': 100}
      lockvar d.a
      try
        unlet d.a
        $put ='did :unlet'
      catch
        $put =v:exception[:16]
      endtry
      $put =string(d)

      $put ='filter() after lock on dict item:'
      unlet! d
      let d = {'a': 99, 'b': 100}
      lockvar d.a
      try
        call filter(d, 'v:key != "a"')
        $put ='did filter()'
      catch
        $put =v:exception[:16]
      endtry
      $put =string(d)

      $put ='map() after lock on dict:'
      unlet! d
      let d = {'a': 99, 'b': 100}
      lockvar 1 d
      try
        call map(d, 'v:val + 200')
        $put ='did map()'
      catch
        $put =v:exception[:16]
      endtry
      $put =string(d)

      $put ='No extend() after lock on dict item:'
      unlet! d
      let d = {'a': 99, 'b': 100}
      lockvar d.a
      try
        $put =string(extend(d, {'a': 123}))
        $put ='did extend()'
      catch
        $put =v:exception[:14]
      endtry
      $put =string(d)

      $put ='No remove() of write-protected scope-level variable:'
      fun! Tfunc(this_is_a_loooooooooong_parameter_name)
        try
          $put =string(remove(a:, 'this_is_a_loooooooooong_parameter_name'))
          $put ='did remove()'
        catch
          $put =v:exception[:14]
        endtry
      endfun
      call Tfunc('testval')

      $put ='No extend() of write-protected scope-level variable:'
      fun! Tfunc(this_is_a_loooooooooong_parameter_name)
        try
          $put =string(extend(a:, {'this_is_a_loooooooooong_parameter_name': 1234}))
          $put ='did extend()'
        catch
          $put =v:exception[:14]
        endtry
      endfun
      call Tfunc('testval')

      $put ='No :unlet of variable in locked scope:'
      let b:testvar = 123
      lockvar 1 b:
      try
        unlet b:testvar
        $put ='b:testvar was :unlet: '. (!exists('b:testvar'))
      catch
        $put =v:exception[:16]
      endtry
      unlockvar 1 b:
      unlet! b:testvar

      $put ='No :let += of locked list variable:'
      let l = ['a', 'b', 3]
      lockvar 1 l
      try
        let l += ['x']
        $put ='did :let +='
      catch
        $put =v:exception[:14]
      endtry
      $put =string(l)]])

    expect([=[

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
      Vim(put):E742: 
      No extend() of write-protected scope-level variable:
      Vim(put):E742: 
      No :unlet of variable in locked scope:
      Vim(unlet):E741: 
      No :let += of locked list variable:
      Vim(let):E741: 
      ['a', 'b', 3]]=])
  end)

  it(':lockvar/islocked() triggering script autoloading.', function()
    source([[           
      set rtp+=test/functional/fixtures
      lockvar g:footest#x
      unlockvar g:footest#x
      $put ='locked g:footest#x:'.islocked('g:footest#x')
      $put ='exists g:footest#x:'.exists('g:footest#x')
      $put ='g:footest#x: '.g:footest#x]])
    expect([[

      locked g:footest#x:-1
      exists g:footest#x:0
      g:footest#x: 1]])
  end)

  it('a:000 function argument', function()
    source([[
      function Test(...)
        " First the tests that should fail.
        try
          let a:000 = [1, 2]
        catch
          $put ='caught a:000'
        endtry
        try
          let a:000[0] = 9
        catch
          $put ='caught a:000[0]'
        endtry
        try
          let a:000[2] = [9, 10]
        catch
          $put ='caught a:000[2]'
        endtry
        try
          let a:000[3] = {9: 10}
        catch
          $put ='caught a:000[3]'
        endtry
        " Now the tests that should pass.
        try
          let a:000[2][1] = 9
          call extend(a:000[2], [5, 6])
          let a:000[3][5] = 8
          let a:000[3]['a'] = 12
          $put =string(a:000)
        catch
          $put ='caught ' . v:exception
        endtry
      endfunction]])
    feed_command('call Test(1, 2, [3, 4], {5: 6})')
    expect([=[

      caught a:000
      caught a:000[0]
      caught a:000[2]
      caught a:000[3]
      [1, 2, [3, 9, 5, 6], {'a': 12, '5': 8}]]=])
  end)

  it('reverse(), sort(), uniq()', function()
    source([=[
      let l = ['-0', 'A11', 2, 2, 'xaaa', 4, 'foo', 'foo6', 'foo',
	      \ [0, 1, 2], 'x8', [0, 1, 2], 1.5]
      $put =string(uniq(copy(l)))
      $put =string(reverse(l))
      $put =string(reverse(reverse(l)))
      $put =string(sort(l))
      $put =string(reverse(sort(l)))
      $put =string(sort(reverse(sort(l))))
      $put =string(uniq(sort(l)))
      let l=[7, 9, 'one', 18, 12, 22, 'two', 10.0e-16, -1, 'three', 0xff,
	      \ 0.22, 'four']
      $put =string(sort(copy(l), 'n'))
      let l=[7, 9, 18, 12, 22, 10.0e-16, -1, 0xff, 0, -0, 0.22, 'bar',
	      \ 'BAR', 'Bar', 'Foo', 'FOO', 'foo', 'FOOBAR', {}, []]
      $put =string(sort(copy(l), 1))
      $put =string(sort(copy(l), 'i'))
      $put =string(sort(copy(l)))]=])
    expect(
      [=[

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
      ['BAR', 'Bar', 'FOO', 'FOOBAR', 'Foo', 'bar', 'foo', -1, 0, 0, 0.22, 1.0e-15, 12, 18, 22, 255, 7, 9, [], {}]]=]
    )
  end)

  it('splitting a string to a list', function()
    source([[
      $put =string(split('  aa  bb '))
      $put =string(split('  aa  bb  ', '\W\+', 0))
      $put =string(split('  aa  bb  ', '\W\+', 1))
      $put =string(split('  aa  bb  ', '\W', 1))
      $put =string(split(':aa::bb:', ':', 0))
      $put =string(split(':aa::bb:', ':', 1))
      $put =string(split('aa,,bb, cc,', ',\s*', 1))
      $put =string(split('abc', '\zs'))
      $put =string(split('abc', '\zs', 1))]])
    expect([=[

      ['aa', 'bb']
      ['aa', 'bb']
      ['', 'aa', 'bb', '']
      ['', '', 'aa', '', 'bb', '', '']
      ['aa', '', 'bb']
      ['', 'aa', '', 'bb', '']
      ['aa', '', 'bb', 'cc', '']
      ['a', 'b', 'c']
      ['', 'a', '', 'b', '', 'c', '']]=])
  end)

  it('compare recursively linked list and dict', function()
    source([[
      let l = [1, 2, 3, 4]
      let d = {'1': 1, '2': l, '3': 3}
      let l[1] = d
      $put =(l == l)
      $put =(d == d)
      $put =(l != deepcopy(l))
      $put =(d != deepcopy(d))]])
    expect([[

      1
      1
      0
      0]])
  end)

  it('compare complex recursively linked list and dict', function()
    source([[
      let l = []
      call add(l, l)
      let dict4 = {"l": l}
      call add(dict4.l, dict4)
      let lcopy = deepcopy(l)
      let dict4copy = deepcopy(dict4)
      $put =(l == lcopy)
      $put =(dict4 == dict4copy)]])
    expect([[

      1
      1]])
  end)

  it('pass the same list to extend()', function()
    source([[
      let l = [1, 2, 3, 4, 5]
      call extend(l, l)
      $put =string(l)]])
    expect([=[

      [1, 2, 3, 4, 5, 1, 2, 3, 4, 5]]=])
  end)

  it('pass the same dict to extend()', function()
    source([[
      let d = { 'a': {'b': 'B'}}
      call extend(d, d)
      $put =string(d)]])
    expect([[

      {'a': {'b': 'B'}}]])
  end)

  it('pass the same dict to extend() with "error"', function()
    source([[
      " Copy dict from previous test.
      let d = { 'a': {'b': 'B'}}
      try
	      call extend(d, d, "error")
      catch
	      $put =v:exception[:15] . v:exception[-1:-1]
      endtry
      $put =string(d)]])
    expect([[

      Vim(call):E737: a
      {'a': {'b': 'B'}}]])
  end)

  it('test for range assign', function()
    source([[
      let l = [0]
      let l[:] = [1, 2]
      $put =string(l)]])
    expect([=[

      [1, 2]]=])
  end)

  it('vim patch 7.3.637', function()
    feed_command('let a = "No error caught"')
    feed_command('try')
    feed_command('  foldopen')
    feed_command('catch')
    feed_command("  let a = matchstr(v:exception,'^[^ ]*')")
    feed_command('endtry')
    feed('o<C-R>=a<CR><esc>')
    feed_command('lang C')
    feed_command('redir => a')
    -- The test fails if this is not in one line.
    feed_command("try|foobar|catch|let a = matchstr(v:exception,'^[^ ]*')|endtry")
    feed_command('redir END')
    feed('o<C-R>=a<CR><esc>')
    expect([[

      Vim(foldopen):E490:


      Error in :
      E492: Not an editor command: foobar|catch|let a = matchstr(v:exception,'^[^ ]*')|endtry
      ]])
  end)
end)
