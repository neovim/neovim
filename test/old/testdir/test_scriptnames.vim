
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
  let lines =<< trim END
    let g:loaded_script_id = expand("<SID>")
    let s:XscriptVar = [1, #{v: 2}]
    func s:XscriptFunc()
    endfunc
  END
  call writefile(lines, 'X22script91')
  source X22script91
  let l = getscriptinfo()
  call assert_match('X22script91$', l[-1].name)
  call assert_equal(g:loaded_script_id, $"<SNR>{l[-1].sid}_")

  let l = getscriptinfo({'name': '22script91'})
  call assert_equal(1, len(l))
  call assert_match('22script91$', l[0].name)

  let l = getscriptinfo({'name': 'foobar'})
  call assert_equal(0, len(l))
  let l = getscriptinfo({'name': ''})
  call assert_true(len(l) > 1)

  call assert_fails("echo getscriptinfo({'name': []})", 'E730:')
  call assert_fails("echo getscriptinfo({'name': '\\@'})", 'E866:')
  let l = getscriptinfo({'name': v:_null_string})
  call assert_true(len(l) > 1)
  call assert_fails("echo getscriptinfo('foobar')", 'E1206:')

  call delete('X22script91')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
