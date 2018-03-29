" Tests for :unlet

func Test_read_only()
  try
    " this caused a crash
    unlet v:count
  catch
    call assert_true(v:exception =~ ':E795:')
  endtry
endfunc

func Test_existing()
  let does_exist = 1
  call assert_true(exists('does_exist'))
  unlet does_exist
  call assert_false(exists('does_exist'))
endfunc

func Test_not_existing()
  unlet! does_not_exist
  try
    unlet does_not_exist
  catch
    call assert_true(v:exception =~ ':E108:')
  endtry
endfunc

func Test_unlet_fails()
  call assert_fails('unlet v:["count"]', 'E46:')
endfunc
