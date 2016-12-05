" Test commands that jump somewhere.

func Test_geedee()
  new
  call setline(1, ["Filename x;", "", "int Filename", "int func() {", "Filename y;"])
  /y;/
  normal gD
  call assert_equal(1, line('.'))
  quit!
endfunc
