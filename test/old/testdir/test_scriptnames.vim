
" Test for the :scriptnames command
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

  let msgs = execute('messages')
  scriptnames
  call assert_equal(msgs, execute('messages'))
endfunc

" Test for the getscriptinfo() function
func Test_getscriptinfo()
  call writefile(['let loaded_script_id = expand("<SID>")'], 'Xscript')
  source Xscript
  let l = getscriptinfo()
  call assert_match('Xscript$', l[-1].name)
  call assert_equal(g:loaded_script_id, $"<SNR>{l[-1].sid}_")
  call delete('Xscript')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
