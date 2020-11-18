" Tests for the Blob types

func TearDown()
  " Run garbage collection after every test
  call test_garbagecollect_now()
endfunc

" Tests for Blob type

" Blob creation from constant
func Test_blob_create()
  let b = 0zDEADBEEF
  call assert_equal(v:t_blob, type(b))
  call assert_equal(4, len(b))
  call assert_equal(0xDE, b[0])
  call assert_equal(0xAD, b[1])
  call assert_equal(0xBE, b[2])
  call assert_equal(0xEF, b[3])
  call assert_fails('let x = b[4]')

  call assert_equal(0xDE, get(b, 0))
  call assert_equal(0xEF, get(b, 3))
  call assert_fails('let x = get(b, 4)')
endfunc

" assignment to a blob
func Test_blob_assign()
  let b = 0zDEADBEEF
  let b2 = b[1:2]
  call assert_equal(0zADBE, b2)

  let bcopy = b[:]
  call assert_equal(b, bcopy)
  call assert_false(b is bcopy)
endfunc

func Test_blob_to_string()
  let b = 0zDEADBEEF
  call assert_equal('[0xDE,0xAD,0xBE,0xEF]', string(b))
  call remove(b, 0, 3)
  call assert_equal('[]', string(b))
endfunc

func Test_blob_compare()
  let b1 = 0z0011
  let b2 = 0z1100
  call assert_false(b1 == b2)
  call assert_true(b1 != b2)
  call assert_true(b1 == 0z0011)

  call assert_false(b1 is b2)
  let b2 = b1
  call assert_true(b1 is b2)

  call assert_fails('let x = b1 > b2')
  call assert_fails('let x = b1 < b2')
  call assert_fails('let x = b1 - b2')
  call assert_fails('let x = b1 / b2')
  call assert_fails('let x = b1 * b2')
endfunc

" test for range assign
func Test_blob_range_assign()
  let b = 0z00
  let b[1] = 0x11
  let b[2] = 0x22
  call assert_equal(0z001122, b)
  call assert_fails('let b[4] = 0x33')
endfunc

func Test_blob_for_loop()
  let blob = 0z00010203
  let i = 0
  for byte in blob
    call assert_equal(i, byte)
    let i += 1
  endfor

  let blob = 0z00
  call remove(blob, 0)
  call assert_equal(0, len(blob))
  for byte in blob
    call assert_error('loop over empty blob')
  endfor
endfunc

func Test_blob_concatenate()
  let b = 0z0011
  let b += 0z2233
  call assert_equal(0z00112233, b)

  call assert_fails('let b += "a"')
  call assert_fails('let b += 88')

  let b = 0zDEAD + 0zBEEF
  call assert_equal(0zDEADBEEF, b)
endfunc

" Test removing items in blob
func Test_blob_func_remove()
  " Test removing 1 element
  let b = 0zDEADBEEF
  call assert_equal(0xDE, remove(b, 0))
  call assert_equal(0zADBEEF, b)

  let b = 0zDEADBEEF
  call assert_equal(0xEF, remove(b, -1))
  call assert_equal(0zDEADBE, b)

  let b = 0zDEADBEEF
  call assert_equal(0xAD, remove(b, 1))
  call assert_equal(0zDEBEEF, b)

  " Test removing range of element(s)
  let b = 0zDEADBEEF
  call assert_equal(0zBE, remove(b, 2, 2))
  call assert_equal(0zDEADEF, b)

  let b = 0zDEADBEEF
  call assert_equal(0zADBE, remove(b, 1, 2))
  call assert_equal(0zDEEF, b)

  " Test invalid cases
  let b = 0zDEADBEEF
  call assert_fails("call remove(b, 5)", 'E979:')
  call assert_fails("call remove(b, 1, 5)", 'E979:')
  call assert_fails("call remove(b, 3, 2)", 'E979:')
  call assert_fails("call remove(1, 0)", 'E712:')
  call assert_fails("call remove(b, b)", 'E974:')
endfunc

func Test_blob_read_write()
  let b = 0zDEADBEEF
  call writefile(b, 'Xblob')
  let br = readfile('Xblob', 'B')
  call assert_equal(b, br)
  call delete('Xblob')
endfunc

" filter() item in blob
func Test_blob_filter()
  let b = 0zDEADBEEF
  call filter(b, 'v:val != 0xEF')
  call assert_equal(0zDEADBE, b)
endfunc

" map() item in blob
func Test_blob_map()
  let b = 0zDEADBEEF
  call map(b, 'v:val + 1')
  call assert_equal(0zDFAEBFF0, b)
endfunc

func Test_blob_index()
  call assert_equal(2, index(0zDEADBEEF, 0xBE))
  call assert_equal(-1, index(0zDEADBEEF, 0))
endfunc

func Test_blob_insert()
  let b = 0zDEADBEEF
  call insert(b, 0x33)
  call assert_equal(0z33DEADBEEF, b)

  let b = 0zDEADBEEF
  call insert(b, 0x33, 2)
  call assert_equal(0zDEAD33BEEF, b)
endfunc

func Test_blob_reverse()
  call assert_equal(0zEFBEADDE, reverse(0zDEADBEEF))
  call assert_equal(0zBEADDE, reverse(0zDEADBE))
  call assert_equal(0zADDE, reverse(0zDEAD))
  call assert_equal(0zDE, reverse(0zDE))
endfunc

" vim: shiftwidth=2 sts=2 expandtab
