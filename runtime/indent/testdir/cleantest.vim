" Deletes all the test output files: *.fail and *.out
for fname in glob('testdir/*.out', 1, 1) + glob('testdir/*.fail', 1, 1)
  call delete(fname)
endfor

quit
