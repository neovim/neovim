" Test glob2regpat()

source vim9.vim

func Test_glob2regpat_invalid()
  if has('float')
    call assert_equal('^1\.33$', glob2regpat(1.33))
    call CheckDefExecAndScriptFailure(['echo glob2regpat(1.33)'], 'E806:')
  endif
  call assert_fails('call glob2regpat("}")', 'E219:')
  call assert_fails('call glob2regpat("{")', 'E220:')
endfunc

func Test_glob2regpat_valid()
  call assert_equal('^foo\.', glob2regpat('foo.*'))
  call assert_equal('^foo.$', 'foo?'->glob2regpat())
  call assert_equal('\.vim$', glob2regpat('*.vim'))
  call assert_equal('^[abc]$', glob2regpat('[abc]'))
  call assert_equal('^foo bar$', glob2regpat('foo\ bar'))
  call assert_equal('^foo,bar$', glob2regpat('foo,bar'))
  call assert_equal('^\(foo\|bar\)$', glob2regpat('{foo,bar}'))
  call assert_equal('.*', glob2regpat('**'))

  if exists('+shellslash')
    call assert_equal('^foo[\/].$', glob2regpat('foo\?'))
    call assert_equal('^\(foo[\/]\|bar\|foobar\)$', glob2regpat('{foo\,bar,foobar}'))
    call assert_equal('^[\/]\(foo\|bar[\/]\)$', glob2regpat('\{foo,bar\}'))
    call assert_equal('^[\/][\/]\(foo\|bar[\/][\/]\)$', glob2regpat('\\{foo,bar\\}'))
  else
    call assert_equal('^foo?$', glob2regpat('foo\?'))
    call assert_equal('^\(foo,bar\|foobar\)$', glob2regpat('{foo\,bar,foobar}'))
    call assert_equal('^{foo,bar}$', glob2regpat('\{foo,bar\}'))
    call assert_equal('^\\\(foo\|bar\\\)$', glob2regpat('\\{foo,bar\\}'))
  endif
endfunc
