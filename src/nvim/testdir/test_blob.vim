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

  call assert_fails('let b = 0z1', 'E973:')
  call assert_fails('let b = 0z1x', 'E973:')
  call assert_fails('let b = 0z12345', 'E973:')

  call assert_equal(0z, v:_null_blob)

  let b = 0z001122.33445566.778899.aabbcc.dd
  call assert_equal(0z00112233445566778899aabbccdd, b)
  call assert_fails('let b = 0z1.1')
  call assert_fails('let b = 0z.')
  call assert_fails('let b = 0z001122.')
  call assert_fails('call get("", 1)', 'E896:')
  call assert_equal(0, len(v:_null_blob))
endfunc

" assignment to a blob
func Test_blob_assign()
  let b = 0zDEADBEEF
  let b2 = b[1:2]
  call assert_equal(0zADBE, b2)

  let bcopy = b[:]
  call assert_equal(b, bcopy)
  call assert_false(b is bcopy)

  let b = 0zDEADBEEF
  let b2 = b
  call assert_true(b is b2)
  let b[:] = 0z11223344
  call assert_equal(0z11223344, b)
  call assert_equal(0z11223344, b2)
  call assert_true(b is b2)

  let b = 0zDEADBEEF
  let b[3:] = 0z66
  call assert_equal(0zDEADBE66, b)
  let b[:1] = 0z8899
  call assert_equal(0z8899BE66, b)

  call assert_fails('let b[2:3] = 0z112233', 'E972:')
  call assert_fails('let b[2:3] = 0z11', 'E972:')
  call assert_fails('let b[3:2] = 0z', 'E979:')

  let b = 0zDEADBEEF
  let b += 0z99
  call assert_equal(0zDEADBEEF99, b)

  call assert_fails('let b .= 0z33', 'E734:')
  call assert_fails('let b .= "xx"', 'E734:')
  call assert_fails('let b += "xx"', 'E734:')
  call assert_fails('let b[1:1] .= 0z55', 'E734:')

  let l = [0z12]
  let m = deepcopy(l)
  let m[0] = 0z34	" E742 or E741 should not occur.
endfunc

func Test_blob_get_range()
  let b = 0z0011223344
  call assert_equal(0z2233, b[2:3])
  call assert_equal(0z223344, b[2:-1])
  call assert_equal(0z00, b[0:-5])
  call assert_equal(0z, b[0:-11])
  call assert_equal(0z44, b[-1:])
  call assert_equal(0z0011223344, b[:])
  call assert_equal(0z0011223344, b[:-1])
  call assert_equal(0z, b[5:6])
endfunc

func Test_blob_get()
  let b = 0z0011223344
  call assert_equal(0x00, get(b, 0))
  call assert_equal(0x22, get(b, 2, 999))
  call assert_equal(0x44, get(b, 4))
  call assert_equal(0x44, get(b, -1))
  call assert_equal(-1, get(b, 5))
  call assert_equal(999, get(b, 5, 999))
  call assert_equal(-1, get(b, -8))
  call assert_equal(999, get(b, -8, 999))
  call assert_equal(10, get(v:_null_blob, 2, 10))

  call assert_equal(0x00, b[0])
  call assert_equal(0x22, b[2])
  call assert_equal(0x44, b[4])
  call assert_equal(0x44, b[-1])
  call assert_fails('echo b[5]', 'E979:')
  call assert_fails('echo b[-8]', 'E979:')
endfunc

func Test_blob_to_string()
  let b = 0z00112233445566778899aabbccdd
  call assert_equal('0z00112233.44556677.8899AABB.CCDD', string(b))
  call assert_equal(b, eval(string(b)))
  call remove(b, 4, -1)
  call assert_equal('0z00112233', string(b))
  call remove(b, 0, 3)
  call assert_equal('0z', string(b))
endfunc

func Test_blob_compare()
  let b1 = 0z0011
  let b2 = 0z1100
  let b3 = 0z001122
  call assert_true(b1 == b1)
  call assert_false(b1 == b2)
  call assert_false(b1 == b3)
  call assert_true(b1 != b2)
  call assert_true(b1 != b3)
  call assert_true(b1 == 0z0011)
  call assert_fails('echo b1 == 9', 'E977:')
  call assert_fails('echo b1 != 9', 'E977:')

  call assert_false(b1 is b2)
  let b2 = b1
  call assert_true(b1 == b2)
  call assert_true(b1 is b2)
  let b2 = copy(b1)
  call assert_true(b1 == b2)
  call assert_false(b1 is b2)
  let b2 = b1[:]
  call assert_true(b1 == b2)
  call assert_false(b1 is b2)

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
  call assert_fails('let b[4] = 0x33', 'E979:')
endfunc

func Test_blob_for_loop()
  let blob = 0z00010203
  let i = 0
  for byte in blob
    call assert_equal(i, byte)
    let i += 1
  endfor
  call assert_equal(4, i)

  let blob = 0z00
  call remove(blob, 0)
  call assert_equal(0, len(blob))
  for byte in blob
    call assert_error('loop over empty blob')
  endfor

  let blob = 0z0001020304
  let i = 0
  for byte in blob
    call assert_equal(i, byte)
    if i == 1
      call remove(blob, 0)
    elseif i == 3
      call remove(blob, 3)
    endif
    let i += 1
  endfor
  call assert_equal(5, i)
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

func Test_blob_add()
  let b = 0z0011
  call add(b, 0x22)
  call assert_equal(0z001122, b)
  call add(b, '51')
  call assert_equal(0z00112233, b)

  call assert_fails('call add(b, [9])', 'E745:')
  call assert_fails('call add("", 0x01)', 'E897:')
endfunc

func Test_blob_empty()
  call assert_false(empty(0z001122))
  call assert_true(empty(0z))
  call assert_true(empty(v:_null_blob))
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
  call assert_fails("call remove(1, 0)", 'E896:')
  call assert_fails("call remove(b, b)", 'E974:')
  call assert_fails("call remove(v:_null_blob, 1, 2)", 'E979:')

  " Translated from v8.2.3284
  let b = 0zDEADBEEF
  lockvar b
  call assert_fails('call remove(b, 0)', 'E741:')
  unlockvar b
endfunc

func Test_blob_read_write()
  let b = 0zDEADBEEF
  call writefile(b, 'Xblob')
  let br = readfile('Xblob', 'B')
  call assert_equal(b, br)
  call delete('Xblob')

  " This was crashing when calling readfile() with a directory.
  call assert_fails("call readfile('.', 'B')", 'E17: "." is a directory')
endfunc

" filter() item in blob
func Test_blob_filter()
  call assert_equal(0z, filter(0zDEADBEEF, '0'))
  call assert_equal(0zADBEEF, filter(0zDEADBEEF, 'v:val != 0xDE'))
  call assert_equal(0zDEADEF, filter(0zDEADBEEF, 'v:val != 0xBE'))
  call assert_equal(0zDEADBE, filter(0zDEADBEEF, 'v:val != 0xEF'))
  call assert_equal(0zDEADBEEF, filter(0zDEADBEEF, '1'))
  call assert_equal(0z01030103, filter(0z010203010203, 'v:val != 0x02'))
  call assert_equal(0zADEF, filter(0zDEADBEEF, 'v:key % 2'))
endfunc

" map() item in blob
func Test_blob_map()
  call assert_equal(0zDFAEBFF0, map(0zDEADBEEF, 'v:val + 1'))
  call assert_equal(0z00010203, map(0zDEADBEEF, 'v:key'))
  call assert_equal(0zDEAEC0F2, map(0zDEADBEEF, 'v:key + v:val'))

  call assert_fails("call map(0z00, '[9]')", 'E978:')
endfunc

func Test_blob_index()
  call assert_equal(2, index(0zDEADBEEF, 0xBE))
  call assert_equal(-1, index(0zDEADBEEF, 0))
  call assert_equal(2, index(0z11111111, 0x11, 2))
  call assert_equal(3, index(0z11110111, 0x11, 2))
  call assert_equal(2, index(0z11111111, 0x11, -2))
  call assert_equal(3, index(0z11110111, 0x11, -2))

  call assert_fails('call index("asdf", 0)', 'E897:')
endfunc

func Test_blob_insert()
  let b = 0zDEADBEEF
  call insert(b, 0x33)
  call assert_equal(0z33DEADBEEF, b)

  let b = 0zDEADBEEF
  call insert(b, 0x33, 2)
  call assert_equal(0zDEAD33BEEF, b)

  call assert_fails('call insert(b, -1)', 'E475:')
  call assert_fails('call insert(b, 257)', 'E475:')
  call assert_fails('call insert(b, 0, [9])', 'E745:')
  call assert_equal(0, insert(v:_null_blob, 0x33))

  " Translated from v8.2.3284
  let b = 0zDEADBEEF
  lockvar b
  call assert_fails('call insert(b, 3)', 'E741:')
  unlockvar b
endfunc

func Test_blob_reverse()
  call assert_equal(0zEFBEADDE, reverse(0zDEADBEEF))
  call assert_equal(0zBEADDE, reverse(0zDEADBE))
  call assert_equal(0zADDE, reverse(0zDEAD))
  call assert_equal(0zDE, reverse(0zDE))
  call assert_equal(0z, reverse(v:_null_blob))
endfunc

func Test_blob_lock()
  let b = 0z112233
  lockvar b
  call assert_fails('let b = 0z44', 'E741:')
  unlockvar b
  let b = 0z44
endfunc

func Test_blob_sort()
  if has('float')
    call assert_fails('call sort([1.0, 0z11], "f")', 'E975:')
  else
    call assert_fails('call sort(["abc", 0z11], "f")', 'E702:')
  endif
endfunc

" vim: shiftwidth=2 sts=2 expandtab
