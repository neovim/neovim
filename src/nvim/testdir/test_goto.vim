" Test commands that jump somewhere.

func Test_geeDEE()
  new
  call setline(1, ["Filename x;", "", "int Filename", "int func() {", "Filename y;"])
  /y;/
  normal gD
  call assert_equal(1, line('.'))
  quit!
endfunc

func Test_gee_dee()
  new
  call setline(1, ["int x;", "", "int func(int x)", "{", "  return x;", "}"])
  /return/
  normal $hgd
  call assert_equal(3, line('.'))
  call assert_equal(14, col('.'))
  quit!
endfunc
