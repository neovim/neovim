
" Test for errors in setting 'viminfo'
func Test_viminfo_option_error()
  " Missing number
  call assert_fails('set viminfo=\"', 'E526:')
  for c in split("'/:<@s", '\zs')
    call assert_fails('set viminfo=' .. c, 'E526:')
  endfor

  " Missing comma
  call assert_fails('set viminfo=%10!', 'E527:')
  call assert_fails('set viminfo=!%10', 'E527:')
  call assert_fails('set viminfo=h%10', 'E527:')
  call assert_fails('set viminfo=c%10', 'E527:')
  call assert_fails('set viminfo=:10%10', 'E527:')

  " Missing ' setting
  call assert_fails('set viminfo=%10', 'E528:')
endfunc

func Test_viminfo_oldfiles_newfile()
  let v:oldfiles = v:_null_list
  call assert_equal("\nNo old files", execute('oldfiles'))
endfunc

" vim: shiftwidth=2 sts=2 expandtab
