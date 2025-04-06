" Test for environment variables.

scriptencoding utf-8

source check.vim

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
  call assert_equal(v:null, 'TESTENV'->getenv())
  let $TESTENV = 'foo'
  call assert_equal('foo', getenv('TESTENV'))
endfunc

func Test_setenv()
  unlet! $TESTENV
  eval 'foo'->setenv('TEST ENV')
  call assert_equal('foo', getenv('TEST ENV'))
  call setenv('TEST ENV', v:null)
  call assert_equal(v:null, getenv('TEST ENV'))
endfunc

func Test_special_env()
  " The value for $HOME is cached internally by Vim, ensure the value is up to
  " date.
  let orig_ENV = $HOME

  let $HOME = 'foo'
  call assert_equal('foo', expand('~'))
  " old $HOME value is kept until a new one is set
  unlet $HOME
  call assert_equal('foo', expand('~'))

  call setenv('HOME', 'bar')
  call assert_equal('bar', expand('~'))
  " old $HOME value is kept until a new one is set
  call setenv('HOME', v:null)
  call assert_equal('bar', expand('~'))

  let $HOME = orig_ENV
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

func Test_mac_locale()
  CheckFeature osxdarwin

  " If $LANG is not set then the system locale will be used.
  " Run Vim after unsetting all the locale environmental vars, and capture the
  " output of :lang.
  let lang_results = system("unset LANG; unset LC_MESSAGES; unset LC_CTYPE; " ..
            \ shellescape(v:progpath) ..
            \ " --clean -esX -c 'redir @a' -c 'lang' -c 'put a' -c 'print' -c 'qa!' ")

  " Check that:
  " 1. The locale is the form of <locale>.UTF-8.
  " 2. Check that fourth item (LC_NUMERIC) is properly set to "C".
  " Example match: "en_US.UTF-8/en_US.UTF-8/en_US.UTF-8/C/en_US.UTF-8/en_US.UTF-8"
  call assert_match('"\([a-zA-Z_]\+\.UTF-8/\)\{3}C\(/[a-zA-Z_]\+\.UTF-8\)\{2}"',
        \ lang_results,
        \ "Default locale should have UTF-8 encoding set, and LC_NUMERIC set to 'C'")
endfunc

" vim: shiftwidth=2 sts=2 expandtab
