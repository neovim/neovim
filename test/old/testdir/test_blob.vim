" Tests for the Blob types

source check.vim
source vim9.vim

func TearDown()
  " Run garbage collection after every test
  call test_garbagecollect_now()
endfunc

" Tests for Blob type

" Blob creation from constant
func Test_blob_create()
  let lines =<< trim END
      VAR b = 0zDEADBEEF
      call assert_equal(v:t_blob, type(b))
      call assert_equal(4, len(b))
      call assert_equal(0xDE, b[0])
      call assert_equal(0xAD, b[1])
      call assert_equal(0xBE, b[2])
      call assert_equal(0xEF, b[3])
      call assert_fails('VAR x = b[4]')

      call assert_equal(0xDE, get(b, 0))
      call assert_equal(0xEF, get(b, 3))

      call assert_fails('VAR b = 0z1', 'E973:')
      call assert_fails('VAR b = 0z1x', 'E973:')
      call assert_fails('VAR b = 0z12345', 'E973:')

      call assert_equal(0z, v:_null_blob)

      LET b = 0z001122.33445566.778899.aabbcc.dd
      call assert_equal(0z00112233445566778899aabbccdd, b)
      call assert_fails('VAR b = 0z1.1')
      call assert_fails('VAR b = 0z.')
      call assert_fails('VAR b = 0z001122.')
      call assert_fails('call get("", 1)', 'E896:')
      call assert_equal(0, len(v:_null_blob))
      call assert_equal(0z, copy(v:_null_blob))
  END
  call CheckLegacyAndVim9Success(lines)
endfunc

" assignment to a blob
func Test_blob_assign()
  let lines =<< trim END
      VAR b = 0zDEADBEEF
      VAR b2 = b[1 : 2]
      call assert_equal(0zADBE, b2)

      VAR bcopy = b[:]
      call assert_equal(b, bcopy)
      call assert_false(b is bcopy)

      LET b = 0zDEADBEEF
      LET b2 = b
      call assert_true(b is b2)
      LET b[:] = 0z11223344
      call assert_equal(0z11223344, b)
      call assert_equal(0z11223344, b2)
      call assert_true(b is b2)

      LET b = 0zDEADBEEF
      LET b[3 :] = 0z66
      call assert_equal(0zDEADBE66, b)
      LET b[: 1] = 0z8899
      call assert_equal(0z8899BE66, b)

      LET b = 0zDEADBEEF
      LET b += 0z99
      call assert_equal(0zDEADBEEF99, b)

      VAR l = [0z12]
      VAR m = deepcopy(l)
      LET m[0] = 0z34	#" E742 or E741 should not occur.

      VAR blob1 = 0z10
      LET blob1 += v:_null_blob
      call assert_equal(0z10, blob1)
      LET blob1 = v:_null_blob
      LET blob1 += 0z20
      call assert_equal(0z20, blob1)
  END
  call CheckLegacyAndVim9Success(lines)

  let lines =<< trim END
      VAR b = 0zDEADBEEF
      LET b[2 : 3] = 0z112233
  END
  call CheckLegacyAndVim9Failure(lines, 'E972:')

  let lines =<< trim END
      VAR b = 0zDEADBEEF
      LET b[2 : 3] = 0z11
  END
  call CheckLegacyAndVim9Failure(lines, 'E972:')

  let lines =<< trim END
      VAR b = 0zDEADBEEF
      LET b[3 : 2] = 0z
  END
  call CheckLegacyAndVim9Failure(lines, 'E979:')

  let lines =<< trim END
      VAR b = 0zDEADBEEF
      LET b ..= 0z33
  END
  call CheckLegacyAndVim9Failure(lines, ['E734:', 'E1019:', 'E734:'])

  let lines =<< trim END
      VAR b = 0zDEADBEEF
      LET b ..= "xx"
  END
  call CheckLegacyAndVim9Failure(lines, ['E734:', 'E1019:', 'E734:'])

  let lines =<< trim END
      VAR b = 0zDEADBEEF
      LET b += "xx"
  END
  call CheckLegacyAndVim9Failure(lines, ['E734:', 'E1012:', 'E734:'])

  let lines =<< trim END
      VAR b = 0zDEADBEEF
      LET b[1 : 1] ..= 0z55
  END
  call CheckLegacyAndVim9Failure(lines, ['E734:', 'E1183:', 'E734:'])

  call assert_fails('let b = readblob("a1b2c3")', 'E484:')
endfunc

func Test_blob_get_range()
  let lines =<< trim END
      VAR b = 0z0011223344
      call assert_equal(0z2233, b[2 : 3])
      call assert_equal(0z223344, b[2 : -1])
      call assert_equal(0z00, b[0 : -5])
      call assert_equal(0z, b[0 : -11])
      call assert_equal(0z44, b[-1 :])
      call assert_equal(0z0011223344, b[:])
      call assert_equal(0z0011223344, b[: -1])
      call assert_equal(0z, b[5 : 6])
      call assert_equal(0z0011, b[-10 : 1])
  END
  call CheckLegacyAndVim9Success(lines)

  " legacy script white space
  let b = 0z0011223344
  call assert_equal(0z2233, b[2:3])
endfunc

func Test_blob_get()
  let lines =<< trim END
      VAR b = 0z0011223344
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
  END
  call CheckLegacyAndVim9Success(lines)

  let lines =<< trim END
      VAR b = 0z0011223344
      echo b[5]
  END
  call CheckLegacyAndVim9Failure(lines, 'E979:')

  let lines =<< trim END
      VAR b = 0z0011223344
      echo b[-8]
  END
  call CheckLegacyAndVim9Failure(lines, 'E979:')
endfunc

func Test_blob_to_string()
  let lines =<< trim END
      VAR b = 0z00112233445566778899aabbccdd
      call assert_equal('0z00112233.44556677.8899AABB.CCDD', string(b))
      call assert_equal(b, eval(string(b)))
      call remove(b, 4, -1)
      call assert_equal('0z00112233', string(b))
      call remove(b, 0, 3)
      call assert_equal('0z', string(b))
      call assert_equal('0z', string(v:_null_blob))
  END
  call CheckLegacyAndVim9Success(lines)
endfunc

func Test_blob_compare()
  let lines =<< trim END
      VAR b1 = 0z0011
      VAR b2 = 0z1100
      VAR b3 = 0z001122
      call assert_true(b1 == b1)
      call assert_false(b1 == b2)
      call assert_false(b1 == b3)
      call assert_true(b1 != b2)
      call assert_true(b1 != b3)
      call assert_true(b1 == 0z0011)

      call assert_false(b1 is b2)
      LET b2 = b1
      call assert_true(b1 == b2)
      call assert_true(b1 is b2)
      LET b2 = copy(b1)
      call assert_true(b1 == b2)
      call assert_false(b1 is b2)
      LET b2 = b1[:]
      call assert_true(b1 == b2)
      call assert_false(b1 is b2)
      call assert_true(b1 isnot b2)
      call assert_true(0z != 0z10)
      call assert_true(0z10 != 0z)
  END
  call CheckLegacyAndVim9Success(lines)

  let lines =<< trim END
      VAR b1 = 0z0011
      echo b1 == 9
  END
  call CheckLegacyAndVim9Failure(lines, ['E977:', 'E1072', 'E1072'])

  let lines =<< trim END
      VAR b1 = 0z0011
      echo b1 != 9
  END
  call CheckLegacyAndVim9Failure(lines, ['E977:', 'E1072', 'E1072'])

  let lines =<< trim END
      VAR b1 = 0z0011
      VAR b2 = 0z1100
      VAR x = b1 > b2
  END
  call CheckLegacyAndVim9Failure(lines, ['E978:', 'E1072:', 'E1072:'])

  let lines =<< trim END
      VAR b1 = 0z0011
      VAR b2 = 0z1100
      VAR x = b1 < b2
  END
  call CheckLegacyAndVim9Failure(lines, ['E978:', 'E1072:', 'E1072:'])

  let lines =<< trim END
      VAR b1 = 0z0011
      VAR b2 = 0z1100
      VAR x = b1 - b2
  END
  call CheckLegacyAndVim9Failure(lines, ['E974:', 'E1036:', 'E974:'])

  let lines =<< trim END
      VAR b1 = 0z0011
      VAR b2 = 0z1100
      VAR x = b1 / b2
  END
  call CheckLegacyAndVim9Failure(lines, ['E974:', 'E1036:', 'E974:'])

  let lines =<< trim END
      VAR b1 = 0z0011
      VAR b2 = 0z1100
      VAR x = b1 * b2
  END
  call CheckLegacyAndVim9Failure(lines, ['E974:', 'E1036:', 'E974:'])
endfunc

func Test_blob_index_assign()
  let lines =<< trim END
      VAR b = 0z00
      LET b[1] = 0x11
      LET b[2] = 0x22
      LET b[0] = 0x33
      call assert_equal(0z331122, b)
  END
  call CheckLegacyAndVim9Success(lines)

  let lines =<< trim END
      VAR b = 0z00
      LET b[2] = 0x33
  END
  call CheckLegacyAndVim9Failure(lines, 'E979:')

  let lines =<< trim END
      VAR b = 0z00
      LET b[-2] = 0x33
  END
  call CheckLegacyAndVim9Failure(lines, 'E979:')

  let lines =<< trim END
      VAR b = 0z00010203
      LET b[0 : -1] = 0z33
  END
  call CheckLegacyAndVim9Failure(lines, 'E979:')

  let lines =<< trim END
      VAR b = 0z00010203
      LET b[3 : 4] = 0z3344
  END
  call CheckLegacyAndVim9Failure(lines, 'E979:')
endfunc

func Test_blob_for_loop()
  let lines =<< trim END
      VAR blob = 0z00010203
      VAR i = 0
      for byte in blob
        call assert_equal(i, byte)
        LET i += 1
      endfor
      call assert_equal(4, i)

      LET blob = 0z00
      call remove(blob, 0)
      call assert_equal(0, len(blob))
      for byte in blob
        call assert_report('loop over empty blob')
      endfor

      LET blob = 0z0001020304
      LET i = 0
      for byte in blob
        call assert_equal(i, byte)
        if i == 1
          call remove(blob, 0)
        elseif i == 3
          call remove(blob, 3)
        endif
        LET i += 1
      endfor
      call assert_equal(5, i)
  END
  call CheckLegacyAndVim9Success(lines)

  " Test for skipping the loop var assignment in a for loop
  let lines =<< trim END
    VAR blob = 0z998877
    VAR c = 0
    for _ in blob
      LET c += 1
    endfor
    call assert_equal(3, c)
  END
  call CheckLegacyAndVim9Success(lines)
endfunc

func Test_blob_concatenate()
  let lines =<< trim END
      VAR b = 0z0011
      LET b += 0z2233
      call assert_equal(0z00112233, b)

      LET b = 0zDEAD + 0zBEEF
      call assert_equal(0zDEADBEEF, b)
  END
  call CheckLegacyAndVim9Success(lines)

  let lines =<< trim END
      VAR b = 0z0011
      LET b += "a"
  END
  call CheckLegacyAndVim9Failure(lines, ['E734:', 'E1012:', 'E734:'])

  let lines =<< trim END
      VAR b = 0z0011
      LET b += 88
  END
  call CheckLegacyAndVim9Failure(lines, ['E734:', 'E1012:', 'E734:'])
endfunc

func Test_blob_add()
  let lines =<< trim END
      VAR b = 0z0011
      call add(b, 0x22)
      call assert_equal(0z001122, b)
  END
  call CheckLegacyAndVim9Success(lines)

  " Only works in legacy script
  let b = 0z0011
  call add(b, '51')
  call assert_equal(0z001133, b)
  call assert_equal(1, add(v:_null_blob, 0x22))

  let lines =<< trim END
      VAR b = 0z0011
      call add(b, [9])
  END
  call CheckLegacyAndVim9Failure(lines, ['E745:', 'E1012:', 'E745:'])

  let lines =<< trim END
      VAR b = 0z0011
      call add("", 0x01)
  END
  call CheckLegacyAndVim9Failure(lines, 'E897:')

  let lines =<< trim END
      add(v:_null_blob, 0x22)
  END
  call CheckDefExecAndScriptFailure(lines, 'E1131:')

  let lines =<< trim END
      let b = 0zDEADBEEF
      lockvar b
      call add(b, 0)
      unlockvar b
  END
  call CheckScriptFailure(lines, 'E741:')
endfunc

func Test_blob_empty()
  call assert_false(empty(0z001122))
  call assert_true(empty(0z))
  call assert_true(empty(v:_null_blob))
endfunc

" Test removing items in blob
func Test_blob_func_remove()
  let lines =<< trim END
      #" Test removing 1 element
      VAR b = 0zDEADBEEF
      call assert_equal(0xDE, remove(b, 0))
      call assert_equal(0zADBEEF, b)

      LET b = 0zDEADBEEF
      call assert_equal(0xEF, remove(b, -1))
      call assert_equal(0zDEADBE, b)

      LET b = 0zDEADBEEF
      call assert_equal(0xAD, remove(b, 1))
      call assert_equal(0zDEBEEF, b)

      #" Test removing range of element(s)
      LET b = 0zDEADBEEF
      call assert_equal(0zBE, remove(b, 2, 2))
      call assert_equal(0zDEADEF, b)

      LET b = 0zDEADBEEF
      call assert_equal(0zADBE, remove(b, 1, 2))
      call assert_equal(0zDEEF, b)
  END
  call CheckLegacyAndVim9Success(lines)

  " Test invalid cases
  let lines =<< trim END
      VAR b = 0zDEADBEEF
      call remove(b, 5)
  END
  call CheckLegacyAndVim9Failure(lines, 'E979:')

  let lines =<< trim END
      VAR b = 0zDEADBEEF
      call remove(b, 1, 5)
  END
  call CheckLegacyAndVim9Failure(lines, 'E979:')

  let lines =<< trim END
      VAR b = 0zDEADBEEF
      call remove(b, -10)
  END
  call CheckLegacyAndVim9Failure(lines, 'E979:')

  let lines =<< trim END
      VAR b = 0zDEADBEEF
      call remove(b, 3, 2)
  END
  call CheckLegacyAndVim9Failure(lines, 'E979:')

  let lines =<< trim END
      VAR b = 0zDEADBEEF
      call remove(1, 0)
  END
  call CheckLegacyAndVim9Failure(lines, 'E896:')

  let lines =<< trim END
      VAR b = 0zDEADBEEF
      call remove(b, b)
  END
  call CheckLegacyAndVim9Failure(lines, 'E974:')

  let lines =<< trim END
      VAR b = 0zDEADBEEF
      call remove(b, 1, [])
  END
  call CheckLegacyAndVim9Failure(lines, 'E745:')

  let lines =<< trim END
      VAR b = 0zDEADBEEF
      call remove(v:_null_blob, 1, 2)
  END
  call CheckLegacyAndVim9Failure(lines, 'E979:')

  let lines =<< trim END
      let b = 0zDEADBEEF
      lockvar b
      call remove(b, 0)
      unlockvar b
  END
  call CheckScriptFailure(lines, 'E741:')

  " can only check at script level, not in a :def function
  let lines =<< trim END
      vim9script
      var b = 0zDEADBEEF
      lockvar b
      remove(b, 0)
  END
  call CheckScriptFailure(lines, 'E741:')

  call assert_fails('echo remove(0z1020, [])', 'E745:')
  call assert_fails('echo remove(0z1020, 0, [])', 'E745:')
endfunc

func Test_blob_read_write()
  let lines =<< trim END
      VAR b = 0zDEADBEEF
      call writefile(b, 'Xblob')
      VAR br = readfile('Xblob', 'B')
      call assert_equal(b, br)
      VAR br2 = readblob('Xblob')
      call assert_equal(b, br2)
      VAR br3 = readblob('Xblob', 1)
      call assert_equal(b[1 :], br3)
      VAR br4 = readblob('Xblob', 1, 2)
      call assert_equal(b[1 : 2], br4)
      VAR br5 = readblob('Xblob', -3)
      call assert_equal(b[-3 :], br5)
      VAR br6 = readblob('Xblob', -3, 2)
      call assert_equal(b[-3 : -2], br6)

      #" reading past end of file, empty result
      VAR br1e = readblob('Xblob', 10000)
      call assert_equal(0z, br1e)

      #" reading too much, result is truncated
      VAR blong = readblob('Xblob', -1000)
      call assert_equal(b, blong)
      LET blong = readblob('Xblob', -10, 8)
      call assert_equal(b, blong)
      LET blong = readblob('Xblob', 0, 10)
      call assert_equal(b, blong)

      call delete('Xblob')
  END
  call CheckLegacyAndVim9Success(lines)

  if filereadable('/dev/random')
    let b = readblob('/dev/random', 0, 10)
    call assert_equal(10, len(b))
  endif

  call assert_fails("call readblob('notexist')", 'E484:')
  " TODO: How do we test for the E485 error?

  " This was crashing when calling readfile() with a directory.
  call assert_fails("call readfile('.', 'B')", 'E17: "." is a directory')
endfunc

" filter() item in blob
func Test_blob_filter()
  let lines =<< trim END
      call assert_equal(v:_null_blob, filter(v:_null_blob, '0'))
      call assert_equal(0z, filter(0zDEADBEEF, '0'))
      call assert_equal(0zADBEEF, filter(0zDEADBEEF, 'v:val != 0xDE'))
      call assert_equal(0zDEADEF, filter(0zDEADBEEF, 'v:val != 0xBE'))
      call assert_equal(0zDEADBE, filter(0zDEADBEEF, 'v:val != 0xEF'))
      call assert_equal(0zDEADBEEF, filter(0zDEADBEEF, '1'))
      call assert_equal(0z01030103, filter(0z010203010203, 'v:val != 0x02'))
      call assert_equal(0zADEF, filter(0zDEADBEEF, 'v:key % 2'))
  END
  call CheckLegacyAndVim9Success(lines)
  call assert_fails('echo filter(0z10, "a10")', 'E121:')
endfunc

" map() item in blob
func Test_blob_map()
  let lines =<< trim END
      call assert_equal(0zDFAEBFF0, map(0zDEADBEEF, 'v:val + 1'))
      call assert_equal(0z00010203, map(0zDEADBEEF, 'v:key'))
      call assert_equal(0zDEAEC0F2, map(0zDEADBEEF, 'v:key + v:val'))
  END
  call CheckLegacyAndVim9Success(lines)

  let lines =<< trim END
      call map(0z00, '[9]')
  END
  call CheckLegacyAndVim9Failure(lines, 'E978:')
  call assert_fails('echo map(0z10, "a10")', 'E121:')
endfunc

func Test_blob_index()
  let lines =<< trim END
      call assert_equal(2, index(0zDEADBEEF, 0xBE))
      call assert_equal(-1, index(0zDEADBEEF, 0))
      call assert_equal(2, index(0z11111111, 0x11, 2))
      call assert_equal(3, 0z11110111->index(0x11, 2))
      call assert_equal(2, index(0z11111111, 0x11, -2))
      call assert_equal(3, index(0z11110111, 0x11, -2))
      call assert_equal(0, index(0z11110111, 0x11, -10))
      call assert_equal(-1, index(v:_null_blob, 1))
  END
  call CheckLegacyAndVim9Success(lines)

  let lines =<< trim END
      echo index(0z11110111, 0x11, [])
  END
  call CheckLegacyAndVim9Failure(lines, 'E745:')

  let lines =<< trim END
      call index("asdf", 0)
  END
  call CheckLegacyAndVim9Failure(lines, 'E897:')
endfunc

func Test_blob_insert()
  let lines =<< trim END
      VAR b = 0zDEADBEEF
      call insert(b, 0x33)
      call assert_equal(0z33DEADBEEF, b)

      LET b = 0zDEADBEEF
      call insert(b, 0x33, 2)
      call assert_equal(0zDEAD33BEEF, b)
  END
  call CheckLegacyAndVim9Success(lines)

  " only works in legacy script
  call assert_equal(0, insert(v:_null_blob, 0x33))

  let lines =<< trim END
      VAR b = 0zDEADBEEF
      call insert(b, -1)
  END
  call CheckLegacyAndVim9Failure(lines, 'E475:')

  let lines =<< trim END
      VAR b = 0zDEADBEEF
      call insert(b, 257)
  END
  call CheckLegacyAndVim9Failure(lines, 'E475:')

  let lines =<< trim END
      VAR b = 0zDEADBEEF
      call insert(b, 0, [9])
  END
  call CheckLegacyAndVim9Failure(lines, ['E745:', 'E1013:', 'E745:'])

  let lines =<< trim END
      VAR b = 0zDEADBEEF
      call insert(b, 0, -20)
  END
  call CheckLegacyAndVim9Failure(lines, 'E475:')

  let lines =<< trim END
      VAR b = 0zDEADBEEF
      call insert(b, 0, 20)
  END
  call CheckLegacyAndVim9Failure(lines, 'E475:')

  let lines =<< trim END
      VAR b = 0zDEADBEEF
      call insert(b, [])
  END
  call CheckLegacyAndVim9Failure(lines, ['E745:', 'E1013:', 'E745:'])

  let lines =<< trim END
      insert(v:_null_blob, 0x33)
  END
  call CheckDefExecAndScriptFailure(lines, 'E1131:')

  let lines =<< trim END
      let b = 0zDEADBEEF
      lockvar b
      call insert(b, 3)
      unlockvar b
  END
  call CheckScriptFailure(lines, 'E741:')

  let lines =<< trim END
      vim9script
      var b = 0zDEADBEEF
      lockvar b
      insert(b, 3)
  END
  call CheckScriptFailure(lines, 'E741:')
endfunc

func Test_blob_reverse()
  let lines =<< trim END
      call assert_equal(0zEFBEADDE, reverse(0zDEADBEEF))
      call assert_equal(0zBEADDE, reverse(0zDEADBE))
      call assert_equal(0zADDE, reverse(0zDEAD))
      call assert_equal(0zDE, reverse(0zDE))
      call assert_equal(0z, reverse(v:_null_blob))
  END
  call CheckLegacyAndVim9Success(lines)
endfunc

func Test_blob_json_encode()
  let lines =<< trim END
      #" call assert_equal('[222,173,190,239]', json_encode(0zDEADBEEF))
      call assert_equal('[222, 173, 190, 239]', json_encode(0zDEADBEEF))
      call assert_equal('[]', json_encode(0z))
  END
  call CheckLegacyAndVim9Success(lines)
endfunc

func Test_blob_lock()
  let lines =<< trim END
      let b = 0z112233
      lockvar b
      unlockvar b
      let b = 0z44
  END
  call CheckScriptSuccess(lines)

  let lines =<< trim END
      vim9script
      var b = 0z112233
      lockvar b
      unlockvar b
      b = 0z44
  END
  call CheckScriptSuccess(lines)

  let lines =<< trim END
      let b = 0z112233
      lockvar b
      let b = 0z44
  END
  call CheckScriptFailure(lines, 'E741:')

  let lines =<< trim END
      vim9script
      var b = 0z112233
      lockvar b
      b = 0z44
  END
  call CheckScriptFailure(lines, 'E741:')
endfunc

func Test_blob_sort()
  if has('float')
    call CheckLegacyAndVim9Failure(['call sort([1.0, 0z11], "f")'], 'E975:')
  endif
  call CheckLegacyAndVim9Failure(['call sort([11, 0z11], "N")'], 'E974:')
endfunc

" Tests for the blob2list() function
func Test_blob2list()
  call assert_fails('let v = blob2list(10)', 'E1238: Blob required for argument 1')
  eval 0zFFFF->blob2list()->assert_equal([255, 255])
  let tests = [[0z0102, [1, 2]],
        \ [0z00, [0]],
        \ [0z, []],
        \ [0z00000000, [0, 0, 0, 0]],
        \ [0zAABB.CCDD, [170, 187, 204, 221]]]
  for t in tests
    call assert_equal(t[0]->blob2list(), t[1])
  endfor
  exe 'let v = 0z' .. repeat('000102030405060708090A0B0C0D0E0F', 64)
  call assert_equal(1024, blob2list(v)->len())
  call assert_equal([4, 8, 15], [v[100], v[1000], v[1023]])
  call assert_equal([], blob2list(v:_null_blob))
endfunc

" Tests for the list2blob() function
func Test_list2blob()
  call assert_fails('let b = list2blob(0z10)', 'E1211: List required for argument 1')
  let tests = [[[1, 2], 0z0102],
        \ [[0], 0z00],
        \ [[], 0z],
        \ [[0, 0, 0, 0], 0z00000000],
        \ [[255, 255], 0zFFFF],
        \ [[170, 187, 204, 221], 0zAABB.CCDD],
        \ ]
  for t in tests
    call assert_equal(t[1], t[0]->list2blob())
  endfor
  call assert_fails('let b = list2blob([1, []])', 'E745:')
  call assert_fails('let b = list2blob([-1])', 'E1239:')
  call assert_fails('let b = list2blob([256])', 'E1239:')
  let b = range(16)->repeat(64)->list2blob()
  call assert_equal(1024, b->len())
  call assert_equal([4, 8, 15], [b[100], b[1000], b[1023]])
  call assert_equal(0z, list2blob(v:_null_list))
endfunc

" The following used to cause an out-of-bounds memory access
func Test_blob2string()
  let v = '0z' .. repeat('01010101.', 444)
  let v ..= '01'
  exe 'let b = ' .. v
  call assert_equal(v, string(b))
endfunc

func Test_blob_repeat()
  call assert_equal(0z, repeat(0z00, 0))
  call assert_equal(0z00, repeat(0z00, 1))
  call assert_equal(0z0000, repeat(0z00, 2))
  call assert_equal(0z00000000, repeat(0z0000, 2))

  call assert_equal(0z, repeat(0z12, 0))
  call assert_equal(0z, repeat(0z1234, 0))
  call assert_equal(0z1234, repeat(0z1234, 1))
  call assert_equal(0z12341234, repeat(0z1234, 2))
endfunc

" Test for blob allocation failure
func Test_blob_alloc_failure()
  CheckFunction test_alloc_fail
  " blob variable
  call test_alloc_fail(GetAllocId('blob_alloc'), 0, 0)
  call assert_fails('let v = 0z10', 'E342:')

  " blob slice
  let v = 0z1020
  call test_alloc_fail(GetAllocId('blob_alloc'), 0, 0)
  call assert_fails('let x = v[0:0]', 'E342:')
  call assert_equal(0z1020, x)

  " blob remove()
  let v = 0z10203040
  call test_alloc_fail(GetAllocId('blob_alloc'), 0, 0)
  call assert_fails('let x = remove(v, 1, 2)', 'E342:')
  call assert_equal(0, x)

  " list2blob()
  call test_alloc_fail(GetAllocId('blob_alloc'), 0, 0)
  call assert_fails('let a = list2blob([1, 2, 4])', 'E342:')
  call assert_equal(0, a)

  " mapnew()
  call test_alloc_fail(GetAllocId('blob_alloc'), 0, 0)
  call assert_fails('let x = mapnew(0z1234, {_, v -> 1})', 'E342:')
  call assert_equal(0, x)

  " copy()
  call test_alloc_fail(GetAllocId('blob_alloc'), 0, 0)
  call assert_fails('let x = copy(v)', 'E342:')
  call assert_equal(0z, x)

  " readblob()
  call test_alloc_fail(GetAllocId('blob_alloc'), 0, 0)
  call assert_fails('let x = readblob("test_blob.vim")', 'E342:')
  call assert_equal(0, x)
endfunc

" Test for the indexof() function
func Test_indexof()
  let b = 0zdeadbeef
  call assert_equal(0, indexof(b, {i, v -> v == 0xde}))
  call assert_equal(3, indexof(b, {i, v -> v == 0xef}))
  call assert_equal(-1, indexof(b, {i, v -> v == 0x1}))
  call assert_equal(1, indexof(b, "v:val == 0xad"))
  call assert_equal(-1, indexof(b, "v:val == 0xff"))
  call assert_equal(-1, indexof(b, {_, v -> "v == 0xad"}))

  call assert_equal(-1, indexof(0z, "v:val == 0x0"))
  call assert_equal(-1, indexof(v:_null_blob, "v:val == 0xde"))
  call assert_equal(-1, indexof(b, v:_null_string))
  " Nvim doesn't have null functions
  " call assert_equal(-1, indexof(b, test_null_function()))
  call assert_equal(-1, indexof(b, ""))

  let b = 0z01020102
  call assert_equal(1, indexof(b, "v:val == 0x02", #{startidx: 0}))
  call assert_equal(2, indexof(b, "v:val == 0x01", #{startidx: -2}))
  call assert_equal(-1, indexof(b, "v:val == 0x01", #{startidx: 5}))
  call assert_equal(0, indexof(b, "v:val == 0x01", #{startidx: -5}))
  call assert_equal(0, indexof(b, "v:val == 0x01", v:_null_dict))

  " failure cases
  call assert_fails('let i = indexof(b, "val == 0xde")', 'E121:')
  call assert_fails('let i = indexof(b, {})', 'E1256:')
  call assert_fails('let i = indexof(b, " ")', 'E15:')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
