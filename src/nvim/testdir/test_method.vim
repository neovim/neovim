" Tests for ->method()

func Test_list()
  let l = [1, 2, 3]
  call assert_equal([1, 2, 3, 4], [1, 2, 3]->add(4))
  eval l->assert_equal(l)
  eval l->assert_equal(l, 'wrong')
  eval l->assert_notequal([3, 2, 1])
  eval l->assert_notequal([3, 2, 1], 'wrong')
  call assert_equal(l, l->copy())
  call assert_equal(1, l->count(2))
  call assert_false(l->empty())
  call assert_true([]->empty())
  call assert_equal(579, ['123', '+', '456']->join()->eval())
  call assert_equal([1, 2, 3, 4, 5], [1, 2, 3]->extend([4, 5]))
  call assert_equal([1, 3], [1, 2, 3]->filter('v:val != 2'))
  call assert_equal(2, l->get(1))
  call assert_equal(1, l->index(2))
  call assert_equal([0, 1, 2, 3], [1, 2, 3]->insert(0))
  call assert_fails('eval l->items()', 'E715:')
  call assert_equal('1 2 3', l->join())
  call assert_fails('eval l->keys()', 'E715:')
  call assert_equal(3, l->len())
  call assert_equal([2, 3, 4], [1, 2, 3]->map('v:val + 1'))
  call assert_equal(3, l->max())
  call assert_equal(1, l->min())
  call assert_equal(2, [1, 2, 3]->remove(1))
  call assert_equal([1, 2, 3, 1, 2, 3], l->repeat(2))
  call assert_equal([3, 2, 1], [1, 2, 3]->reverse())
  call assert_equal([1, 2, 3, 4], [4, 2, 3, 1]->sort())
  call assert_equal('[1, 2, 3]', l->string())
  call assert_equal(v:t_list, l->type())
  call assert_equal([1, 2, 3], [1, 1, 2, 3, 3]->uniq())
  call assert_fails('eval l->values()', 'E715:')
endfunc

func Test_dict()
  let d = #{one: 1, two: 2, three: 3}

  call assert_equal(d, d->copy())
  call assert_equal(1, d->count(2))
  call assert_false(d->empty())
  call assert_true({}->empty())
  call assert_equal(#{one: 1, two: 2, three: 3, four: 4}, d->extend(#{four: 4}))
  call assert_equal(#{one: 1, two: 2, three: 3}, d->filter('v:val != 4'))
  call assert_equal(2, d->get('two'))
  " Nvim doesn't support Blobs yet; expect a different emsg
  " call assert_fails("let x = d->index(2)", 'E897:')
  " call assert_fails("let x = d->insert(0)", 'E899:')
  call assert_fails("let x = d->index(2)", 'E714:')
  call assert_fails("let x = d->insert(0)", 'E686:')
  call assert_equal([['one', 1], ['two', 2], ['three', 3]], d->items())
  call assert_fails("let x = d->join()", 'E714:')
  call assert_equal(['one', 'two', 'three'], d->keys())
  call assert_equal(3, d->len())
  call assert_equal(#{one: 2, two: 3, three: 4}, d->map('v:val + 1'))
  call assert_equal(#{one: 1, two: 2, three: 3}, d->map('v:val - 1'))
  call assert_equal(3, d->max())
  call assert_equal(1, d->min())
  call assert_equal(2, d->remove("two"))
  let d.two = 2
  call assert_fails('let x = d->repeat(2)', 'E731:')
  " Nvim doesn't support Blobs yet; expect a different emsg
  " call assert_fails('let x = d->reverse()', 'E899:')
  call assert_fails('let x = d->reverse()', 'E686:')
  call assert_fails('let x = d->sort()', 'E686:')
  call assert_equal("{'one': 1, 'two': 2, 'three': 3}", d->string())
  call assert_equal(v:t_dict, d->type())
  call assert_fails('let x = d->uniq()', 'E686:')
  call assert_equal([1, 2, 3], d->values())
endfunc

func Test_append()
  new
  eval ['one', 'two', 'three']->append(1)
  call assert_equal(['', 'one', 'two', 'three'], getline(1, '$'))

  %del
  let bnr = bufnr('')
  wincmd w
  eval ['one', 'two', 'three']->appendbufline(bnr, 1)
  call assert_equal(['', 'one', 'two', 'three'], getbufline(bnr, 1, '$'))

  exe 'bwipe! ' .. bnr
endfunc

" vim: shiftwidth=2 sts=2 expandtab
