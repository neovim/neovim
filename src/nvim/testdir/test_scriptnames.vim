" Test for :scriptnames

func Test_scriptnames()
  call writefile(['let did_load_script = 123'], 'Xscripting')
  source Xscripting
  call assert_equal(123, g:did_load_script)

  let scripts = split(execute('scriptnames'), "\n")
  let last = scripts[-1]
  call assert_match('\<Xscripting\>', last)
  let lastnr = substitute(last, '\D*\(\d\+\):.*', '\1', '')
  exe 'script ' . lastnr
  call assert_equal('Xscripting', expand('%:t'))

  call assert_fails('script ' . (lastnr + 1), 'E474:')
  call assert_fails('script 0', 'E939:')

  new
  call setline(1, 'nothing')
  call assert_fails('script ' . lastnr, 'E37:')
  exe 'script! ' . lastnr
  call assert_equal('Xscripting', expand('%:t'))

  bwipe
  call delete('Xscripting')
endfunc
