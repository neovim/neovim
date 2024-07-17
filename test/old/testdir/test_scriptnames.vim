
" Test for the :scriptnames command
func Test_scriptnames()
  call writefile(['let did_load_script = 123'], 'Xscripting', 'D')
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

  let msgs = execute('messages')
  scriptnames
  call assert_equal(msgs, execute('messages'))
endfunc

" Test for the getscriptinfo() function
func Test_getscriptinfo()
  let lines =<< trim END
    " scriptversion 3
    let g:loaded_script_id = expand("<SID>")
    let s:XscriptVar = [1, #{v: 2}]
    func s:XgetScriptVar()
      return s:XscriptVar
    endfunc
    func s:Xscript_legacy_func1()
    endfunc
    " def s:Xscript_def_func1()
    " enddef
    func Xscript_legacy_func2()
    endfunc
    " def Xscript_def_func2()
    " enddef
  END
  call writefile(lines, 'X22script91', 'D')
  source X22script91
  let l = getscriptinfo()
  call assert_match('X22script91$', l[-1].name)
  call assert_equal(g:loaded_script_id, $"<SNR>{l[-1].sid}_")
  " call assert_equal(3, l[-1].version)
  call assert_equal(1, l[-1].version)
  call assert_equal(0, has_key(l[-1], 'variables'))
  call assert_equal(0, has_key(l[-1], 'functions'))

  " Get script information using script name
  let l = getscriptinfo(#{name: '22script91'})
  call assert_equal(1, len(l))
  call assert_match('22script91$', l[0].name)
  let sid = l[0].sid

  " Get script information using script-ID
  let l = getscriptinfo({'sid': sid})
  call assert_equal(#{XscriptVar: [1, {'v': 2}]}, l[0].variables)
  let funcs = ['Xscript_legacy_func2',
        \ $"<SNR>{sid}_Xscript_legacy_func1",
        "\ $"<SNR>{sid}_Xscript_def_func1",
        "\ 'Xscript_def_func2',
        \ $"<SNR>{sid}_XgetScriptVar"]
  for f in funcs
    call assert_true(index(l[0].functions, f) != -1)
  endfor

  " Verify that a script-local variable cannot be modified using the dict
  " returned by getscriptinfo()
  let l[0].variables.XscriptVar = ['n']
  let funcname = $"<SNR>{sid}_XgetScriptVar"
  call assert_equal([1, {'v': 2}], call(funcname, []))

  let l = getscriptinfo({'name': 'foobar'})
  call assert_equal(0, len(l))
  let l = getscriptinfo({'name': ''})
  call assert_true(len(l) > 1)

  call assert_fails("echo getscriptinfo({'name': []})", 'E730:')
  call assert_fails("echo getscriptinfo({'name': '\\@'})", 'E866:')
  let l = getscriptinfo({'name': v:_null_string})
  call assert_true(len(l) > 1)
  call assert_fails("echo getscriptinfo('foobar')", 'E1206:')

  call assert_fails("echo getscriptinfo({'sid': []})", 'E745:')
  call assert_fails("echo getscriptinfo({'sid': {}})", 'E728:')
  call assert_fails("echo getscriptinfo({'sid': 0})", 'E475:')
  call assert_fails("echo getscriptinfo({'sid': -1})", 'E475:')
  call assert_fails("echo getscriptinfo({'sid': -999})", 'E475:')

  echo getscriptinfo({'sid': '1'})
  " call assert_fails("vim9cmd echo getscriptinfo({'sid': '1'})", 'E1030:')

  let max_sid = max(map(getscriptinfo(), { k, v -> v.sid }))
  call assert_equal([], getscriptinfo({'sid': max_sid + 1}))
endfunc

" vim: shiftwidth=2 sts=2 expandtab
