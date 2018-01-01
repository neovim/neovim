" Tests for b:changedtick

func Test_changedtick_increments()
  new
  " New buffer has an empty line, tick starts at 2.
  let expected = 2
  call assert_equal(expected, b:changedtick)
  call assert_equal(expected, b:['changedtick'])
  call setline(1, 'hello')
  let expected += 1
  call assert_equal(expected, b:changedtick)
  call assert_equal(expected, b:['changedtick'])
  undo
  " Somehow undo counts as two changes.
  let expected += 2
  call assert_equal(expected, b:changedtick)
  call assert_equal(expected, b:['changedtick'])
  bwipe!
endfunc

func Test_changedtick_dict_entry()
  let d = b:
  call assert_equal(b:changedtick, d['changedtick'])
endfunc

func Test_changedtick_bdel()
  new
  let bnr = bufnr('%')
  let v = b:changedtick
  bdel
  " Delete counts as a change too.
  call assert_equal(v + 1, getbufvar(bnr, 'changedtick'))
endfunc

func Test_changedtick_islocked()
  call assert_equal(0, islocked('b:changedtick'))
  let d = b:
  call assert_equal(0, islocked('d.changedtick'))
endfunc

func Test_changedtick_fixed()
  call assert_fails('let b:changedtick = 4', 'E46:')
  call assert_fails('let b:["changedtick"] = 4', 'E46:')

  call assert_fails('lockvar b:changedtick', 'E940:')
  call assert_fails('lockvar b:["changedtick"]', 'E46:')
  call assert_fails('unlockvar b:changedtick', 'E940:')
  call assert_fails('unlockvar b:["changedtick"]', 'E46:')
  call assert_fails('unlet b:changedtick', 'E795:')
  call assert_fails('unlet b:["changedtick"]', 'E46:')

  let d = b:
  call assert_fails('lockvar d["changedtick"]', 'E46:')
  call assert_fails('unlockvar d["changedtick"]', 'E46:')
  call assert_fails('unlet d["changedtick"]', 'E46:')

endfunc
