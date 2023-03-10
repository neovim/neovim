" Test the :behave command

func Test_behave()
  behave mswin
  call assert_equal('mouse,key', &selectmode)
  call assert_equal('popup', &mousemodel)
  call assert_equal('startsel,stopsel', &keymodel)
  call assert_equal('exclusive', &selection)

  behave xterm
  call assert_equal('', &selectmode)
  call assert_equal('extend', &mousemodel)
  call assert_equal('', &keymodel)
  call assert_equal('inclusive', &selection)

  set selection&
  set mousemodel&
  set keymodel&
  set selection&
endfunc

func Test_behave_completion()
  call feedkeys(":behave \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"behave mswin xterm', @:)
endfunc

func Test_behave_error()
  call assert_fails('behave x', 'E475:')
endfunc
