function! health#success1#check()
  call health#report_start("report 1")
  call health#report_ok("everything is fine")
  call health#report_start("report 2")
  call health#report_ok("nothing to see here")
endfunction
