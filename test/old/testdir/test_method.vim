" Tests for ->method()

source check.vim

func Test_list_method()
  let l = [1, 2, 3]
  call assert_equal([1, 2, 3, 4], [1, 2, 3]->add(4))
  eval l->assert_equal(l)
  eval l->assert_equal(l, 'wrong')
  eval l->assert_notequal([3, 2, 1])
  eval l->assert_notequal([3, 2, 1], 'wrong')
  call assert_equal(l, l->copy())
  call assert_equal(l, l->deepcopy())
  call assert_equal(1, l->count(2))
  call assert_false(l->empty())
  call assert_true([]->empty())
  call assert_equal(579, ['123', '+', '456']->join()->eval())
  call assert_equal([1, 2, 3, 4, 5], [1, 2, 3]->extend([4, 5]))
  call assert_equal([1, 3], [1, 2, 3]->filter('v:val != 2'))
  call assert_equal(2, l->get(1))
  call assert_equal(1, l->index(2))
  call assert_equal([0, 1, 2, 3], [1, 2, 3]->insert(0))
  call assert_equal('1 2 3', l->join())
  call assert_fails('eval l->keys()', 'E1206:')
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
  call assert_fails('eval l->values()', 'E1206:')
  call assert_fails('echo []->len', 'E107:')
endfunc

func Test_dict_method()
  let d = #{one: 1, two: 2, three: 3}

  call assert_equal(d, d->copy())
  call assert_equal(d, d->deepcopy())
  call assert_equal(1, d->count(2))
  call assert_false(d->empty())
  call assert_true({}->empty())
  call assert_equal(#{one: 1, two: 2, three: 3, four: 4}, d->extend(#{four: 4}))
  call assert_equal(#{one: 1, two: 2, three: 3}, d->filter('v:val != 4'))
  call assert_equal(2, d->get('two'))
  call assert_fails("let x = d->index(2)", 'E897:')
  call assert_fails("let x = d->insert(0)", 'E899:')
  call assert_true(d->has_key('two'))
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
  call assert_fails('let x = d->reverse()', 'E1252:')
  call assert_fails('let x = d->sort()', 'E686:')
  call assert_equal("{'one': 1, 'two': 2, 'three': 3}", d->string())
  call assert_equal(v:t_dict, d->type())
  call assert_fails('let x = d->uniq()', 'E686:')
  call assert_equal([1, 2, 3], d->values())
endfunc

func Test_string_method()
  eval '1 2 3'->split()->assert_equal(['1', '2', '3'])
  eval '1 2 3'->split()->map({i, v -> str2nr(v)})->assert_equal([1, 2, 3])
  eval 'ABC'->str2list()->assert_equal([65, 66, 67])
  eval 'ABC'->strlen()->assert_equal(3)
  eval "a\rb\ec"->strtrans()->assert_equal('a^Mb^[c')
  eval "aあb"->strwidth()->assert_equal(4)
  eval 'abc'->substitute('b', 'x', '')->assert_equal('axc')
  call assert_fails('eval 123->items()', 'E1225:')

  eval 'abc'->printf('the %s arg')->assert_equal('the abc arg')
endfunc

func Test_method_append()
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

func Test_method_funcref()
  func Concat(one, two, three)
    return a:one .. a:two .. a:three
  endfunc
  let FuncRef = function('Concat')
  eval 'foo'->FuncRef('bar', 'tail')->assert_equal('foobartail')

  " not enough arguments
  call assert_fails("eval 'foo'->FuncRef('bar')", 'E119:')
  " too many arguments
  call assert_fails("eval 'foo'->FuncRef('bar', 'tail', 'four')", 'E118:')

  let Partial = function('Concat', ['two'])
  eval 'one'->Partial('three')->assert_equal('onetwothree')

  " not enough arguments
  call assert_fails("eval 'one'->Partial()", 'E119:')
  " too many arguments
  call assert_fails("eval 'one'->Partial('three', 'four')", 'E118:')

  delfunc Concat
endfunc

func Test_method_float()
  CheckFeature float
  eval 1.234->string()->assert_equal('1.234')
  eval -1.234->string()->assert_equal('-1.234')
endfunc

func Test_method_syntax()
  eval [1, 2, 3]  ->sort( )
  eval [1, 2, 3]
	\ ->sort(
	\ )
  call assert_fails('eval [1, 2, 3]-> sort()', 'E15:')
  call assert_fails('eval [1, 2, 3]->sort ()', 'E274:')
  call assert_fails('eval [1, 2, 3]-> sort ()', 'E15:')

  " Test for using a method name containing a curly brace name
  let s = 'len'
  call assert_equal(4, "xxxx"->str{s}())

  " Test for using a method in an interpolated string
  call assert_equal('4', $'{"xxxx"->strlen()}')
endfunc

func Test_method_lambda()
  eval "text"->{x -> x .. " extended"}()->assert_equal('text extended')
  eval "text"->{x, y -> x .. " extended " .. y}('more')->assert_equal('text extended more')

  call assert_fails('eval "text"->{x -> x .. " extended"} ()', 'E274:')

  " todo: lambda accepts more arguments than it consumes
  " call assert_fails('eval "text"->{x -> x .. " extended"}("more")', 'E99:')

  " Nvim doesn't include test_refcount().
  " let l = [1, 2, 3]
  " eval l->{x -> x}()
  " call assert_equal(1, test_refcount(l))
endfunc

func Test_method_not_supported()
  call assert_fails('eval 123->changenr()', 'E276:')
  call assert_fails('echo "abc"->invalidfunc()', 'E117:')
  " Test for too many or too few arguments to a method
  call assert_fails('let n="abc"->len(2)', 'E118:')
  call assert_fails('let n=10->setwinvar()', 'E119:')
endfunc

" Test for passing optional arguments to methods
func Test_method_args()
  let v:errors = []
  let n = 10->assert_inrange(1, 5, "Test_assert_inrange")
  if v:errors[0] !~ 'Test_assert_inrange'
    call assert_report(v:errors[0])
  else
    " Test passed
    let v:errors = []
  endif
endfunc

" vim: ts=8 sw=2 sts=2 expandtab tw=80 fdm=marker
