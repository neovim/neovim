function! health#full_render#check()
  call health#report_start("report 1")
  call health#report_ok("life is fine")
  call health#report_warn("no what installed", ["pip what", "make what"])
  call health#report_start("report 2")
  call health#report_info("stuff is stable")
  call health#report_error("why no hardcopy", [":h :hardcopy", ":h :TOhtml"])
endfunction
