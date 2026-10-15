" Tests for the GNAT autoload plugin.

func Test_gnat_project_file_is_shell_escaped()
  let gnat = gnat#New()
  let marker = 'Xgnat_command_executed'
  defer delete(marker)
  let gnat.Project_File = '$(touch ' .. marker .. ').gpr'

  call assert_equal('gnat make -P ' .. shellescape(gnat.Project_File, 1) ..
        \ '  -F -gnatef  ', gnat.Get_Command('Make'))
  call assert_equal('gnat pretty -P ' .. shellescape(gnat.Project_File, 1) ..
        \ ' ', gnat.Get_Command('Pretty'))
  call assert_equal('gnat xref -P ' .. shellescape(gnat.Project_File, 1) ..
        \ ' -v  *.AD*', gnat.Get_Command('Tags'))
  call assert_equal('gnat find -P ' .. shellescape(gnat.Project_File, 1) ..
        \ ' -F ', gnat.Get_Command('Find'))

  if has('unix')
    call system(gnat.Get_Command('Pretty'))
    call assert_false(filereadable(marker))
  endif
  unlet gnat
endfunc
