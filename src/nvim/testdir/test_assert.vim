" Test that the methods used for testing work.

" Must be last.
func Test_zz_quit_detected()
  " Verify that if a test function ends Vim the test script detects this.
  quit
endfunc
