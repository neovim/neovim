func Test_empty_buffer()
  new
  insert
a
b
c
d
.
  call assert_equal(1, line("''"))
  bwipe!
endfunc
