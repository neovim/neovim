" Test for pyx* commands and functions with Python 2.

set pyx=2
if !has('python')
  finish
endif

let s:py2pattern = '^2\.[0-7]\.\d\+'
let s:py3pattern = '^3\.\d\+\.\d\+'


func Test_has_pythonx()
  call assert_true(has('pythonx'))
endfunc


func Test_pyx()
  redir => var
  pyx << EOF
import sys
print(sys.version)
EOF
  redir END
  call assert_match(s:py2pattern, split(var)[0])
endfunc


func Test_pyxdo()
  pyx import sys
  enew
  pyxdo return sys.version.split("\n")[0]
  call assert_match(s:py2pattern, split(getline('.'))[0])
endfunc


func Test_pyxeval()
  pyx import sys
  call assert_match(s:py2pattern, split(pyxeval('sys.version'))[0])
endfunc


func Test_pyxfile()
  " No special comments nor shebangs
  redir => var
  pyxfile pyxfile/pyx.py
  redir END
  call assert_match(s:py2pattern, split(var)[0])

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

  if has('python3')
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
  endif
endfunc
