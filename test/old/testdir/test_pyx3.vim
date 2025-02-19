" Test for pyx* commands and functions with Python 3.

set pyx=3
source check.vim
CheckFeature python3

let s:py2pattern = '^2\.[0-7]\.\d\+'
let s:py3pattern = '^3\.\d\+\.\d\+'


func Test_has_pythonx()
  call assert_true(has('pythonx'))
endfunc


func Test_pyx()
  redir => var
  pyx << trim EOF
    import sys
    print(sys.version)
  EOF
  redir END
  call assert_match(s:py3pattern, split(var)[0])
endfunc


func Test_pyxdo()
  pyx import sys
  enew
  pyxdo return sys.version.split("\n")[0]
  call assert_match(s:py3pattern, split(getline('.'))[0])
endfunc


func Test_pyxeval()
  pyx import sys
  call assert_match(s:py3pattern, split(pyxeval('sys.version'))[0])
endfunc


func Test_pyxfile()
  " No special comments nor shebangs
  redir => var
  pyxfile pyxfile/pyx.py
  redir END
  call assert_match(s:py3pattern, split(var)[0])

  " Python 3 special comment
  redir => var
  pyxfile pyxfile/py3_magic.py
  redir END
  call assert_match(s:py3pattern, split(var)[0])

  " Python 3 shebang
  redir => var
  pyxfile pyxfile/py3_shebang.py
  redir END
  call assert_match(s:py3pattern, split(var)[0])

  if has('python')
    " Python 2 special comment
    redir => var
    pyxfile pyxfile/py2_magic.py
    redir END
    call assert_match(s:py2pattern, split(var)[0])

    " Python 2 shebang
    redir => var
    pyxfile pyxfile/py2_shebang.py
    redir END
    call assert_match(s:py2pattern, split(var)[0])
  endif
endfunc

func Test_Catch_Exception_Message()
  try
    pyx raise RuntimeError( 'TEST' )
  catch /.*/
    call assert_match('^Vim(.*):.*RuntimeError: TEST.*$', v:exception )
  endtry
endfunc

" Test for various heredoc syntaxes
func Test_pyx3_heredoc()
  pyx << END
result='A'
END
  pyx <<
result+='B'
.
  pyx << trim END
    result+='C'
  END
  pyx << trim
    result+='D'
  .
  pyx << trim eof
    result+='E'
  eof
  pyx << trimm
result+='F'
trimm
  call assert_equal('ABCDEF', pyxeval('result'))
endfunc

" vim: shiftwidth=2 sts=2 expandtab
