scriptencoding utf-8

func Test_environ()
  unlet! $TESTENV
  call assert_equal(0, has_key(environ(), 'TESTENV'))
  let $TESTENV = 'foo'
  call assert_equal(1, has_key(environ(), 'TESTENV'))
  let $TESTENV = 'こんにちわ'
  call assert_equal('こんにちわ', environ()['TESTENV'])
endfunc

func Test_getenv()
  unlet! $TESTENV
  call assert_equal(v:null, getenv('TESTENV'))
  let $TESTENV = 'foo'
  call assert_equal('foo', getenv('TESTENV'))
endfunc

func Test_setenv()
  unlet! $TESTENV
  call setenv('TEST ENV', 'foo')
  call assert_equal('foo', getenv('TEST ENV'))
  call setenv('TEST ENV', v:null)
  call assert_equal(v:null, getenv('TEST ENV'))
endfunc

func Test_external_env()
  call setenv('FOO', 'HelloWorld')
  if has('win32')
    let result = system('echo %FOO%')
  else
    let result = system('echo $FOO')
  endif
  let result = substitute(result, '[ \r\n]', '', 'g')
  call assert_equal('HelloWorld', result)

  call setenv('FOO', v:null)
  if has('win32')
    let result = system('set | findstr "^FOO="')
  else
    let result = system('env | grep ^FOO=')
  endif
  call assert_equal('', result)
endfunc
