" Tests for :unlet

func Test_read_only()
  " these caused a crash
  call assert_fails('unlet v:count', 'E795:')
  call assert_fails('unlet v:errmsg', 'E795:')
endfunc

func Test_existing()
  let does_exist = 1
  call assert_true(exists('does_exist'))
  unlet does_exist
  call assert_false(exists('does_exist'))
endfunc

func Test_not_existing()
  unlet! does_not_exist
  call assert_fails('unlet does_not_exist', 'E108:')
endfunc

func Test_unlet_fails()
  call assert_fails('unlet v:["count"]', 'E46:')
  call assert_fails('unlet $', 'E475:')
  let v = {}
  call assert_fails('unlet v[:]', 'E719:')
  let l = []
  call assert_fails("unlet l['k'", 'E111:')
  let d = {'k' : 1}
  call assert_fails("unlet d.k2", 'E716:')
  call assert_fails("unlet {a};", 'E488:')
endfunc

func Test_unlet_env()
  let envcmd = has('win32') ? 'set' : 'env'

  let $FOOBAR = 'test'
  let found = 0
  for kv in split(system(envcmd), "\r*\n")
    if kv == 'FOOBAR=test'
      let found = 1
    endif
  endfor
  call assert_equal(1, found)

  unlet $FOOBAR
  let found = 0
  for kv in split(system(envcmd), "\r*\n")
    if kv == 'FOOBAR=test'
      let found = 1
    endif
  endfor
  call assert_equal(0, found)

  unlet $MUST_NOT_BE_AN_ERROR
endfunc

func Test_unlet_complete()
  let g:FOOBAR = 1
  call feedkeys(":unlet g:FOO\t\n", 'tx')
  call assert_true(!exists('g:FOOBAR'))

  let $FOOBAR = 1
  call feedkeys(":unlet $FOO\t\n", 'tx')
  call assert_true(!exists('$FOOBAR') || empty($FOOBAR))
endfunc

func Test_unlet_nonexisting_key()
  let g:base = {}
  call assert_fails(':unlet g:base["foobar"]', 'E716:')

  try
    unlet! g:base["foobar"]
  catch
    call assert_report("error when unletting non-existing dict key")
  endtry
  unlet g:base
endfunc

" vim: shiftwidth=2 sts=2 expandtab
