" Test :version Ex command

func Test_version()
  " version should always return the same string.
  let v1 = execute('version')
  let v2 = execute('version')
  call assert_equal(v1, v2)

  call assert_match("^\n\nNVIM v[0-9]\\+\\.[0-9]\\+\\.[0-9]\\+.*", v1)
endfunc

" vim: shiftwidth=2 sts=2 expandtab
