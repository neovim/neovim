" test 'taglist' function

func Test_taglist()
  call writefile([
	\ "FFoo\tXfoo\t1",
	\ "FBar\tXfoo\t2",
	\ "BFoo\tXbar\t1",
	\ "BBar\tXbar\t2"
	\ ], 'Xtags')
  set tags=Xtags
  split Xtext

  call assert_equal(['FFoo', 'BFoo'], map(taglist("Foo"), {i, v -> v.name}))
  call assert_equal(['FFoo', 'BFoo'], map(taglist("Foo", "Xtext"), {i, v -> v.name}))
  call assert_equal(['FFoo', 'BFoo'], map(taglist("Foo", "Xfoo"), {i, v -> v.name}))
  call assert_equal(['BFoo', 'FFoo'], map(taglist("Foo", "Xbar"), {i, v -> v.name}))

  call delete('Xtags')
  bwipe
endfunc

