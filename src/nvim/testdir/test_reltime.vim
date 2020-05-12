" Tests for reltime()

if !has('reltime') || !has('float')
  finish
endif

func Test_reltime()
  let now = reltime()
  sleep 10m
  let later = reltime()
  let elapsed = reltime(now)
  call assert_true(reltimestr(elapsed) =~ '0\.0')
  call assert_true(reltimestr(elapsed) != '0.0')
  call assert_true(reltimefloat(elapsed) < 0.1)
  call assert_true(reltimefloat(elapsed) > 0.0)

  let same = reltime(now, now)
  call assert_equal('0.000', split(reltimestr(same))[0][:4])
  call assert_equal(0.0, reltimefloat(same))

  let differs = reltime(now, later)
  call assert_true(reltimestr(differs) =~ '0\.0')
  call assert_true(reltimestr(differs) != '0.0')
  call assert_true(reltimefloat(differs) < 0.1)
  call assert_true(reltimefloat(differs) > 0.0)

endfunc
