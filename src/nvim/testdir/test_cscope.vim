" Test for cscope commands.

if !has('cscope')
  finish
endif

func Test_cscopequickfix()
  set cscopequickfix=s-,g-,d+,c-,t+,e-,f0,i-,a-
  call assert_equal('s-,g-,d+,c-,t+,e-,f0,i-,a-', &cscopequickfix)

  call assert_fails('set cscopequickfix=x-', 'E474:')
  call assert_fails('set cscopequickfix=s', 'E474:')
  call assert_fails('set cscopequickfix=s7', 'E474:')
  call assert_fails('set cscopequickfix=s-a', 'E474:')
endfunc
