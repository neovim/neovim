" Tests for tagjump (tags and special searches)

" SEGV occurs in older versions.  (At least 7.4.1748 or older)
func Test_ptag_with_notagstack()
  set notagstack
  call assert_fails('ptag does_not_exist_tag_name', 'E426')
  set tagstack&vim
endfunc
" vim: sw=2 et
