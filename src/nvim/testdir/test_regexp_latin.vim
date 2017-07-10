func Test_nested_backrefs()
  " Check example in change.txt.
  new
  for re in range(0, 2)
    exe 'set re=' . re
    call setline(1, 'aa ab x')
    1s/\(\(a[a-d] \)*\)\(x\)/-\1- -\2- -\3-/
    call assert_equal('-aa ab - -ab - -x-', getline(1))

    call assert_equal('-aa ab - -ab - -x-', substitute('aa ab x', '\(\(a[a-d] \)*\)\(x\)', '-\1- -\2- -\3-', ''))
  endfor
  bwipe!
  set re=0
endfunc
