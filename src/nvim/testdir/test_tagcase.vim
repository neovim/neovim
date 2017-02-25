" test 'tagcase' option

func Test_tagcase()
  call writefile(["Bar\tXtext\t3", "Foo\tXtext\t2", "foo\tXtext\t4"], 'Xtags')
  set tags=Xtags
  e Xtext

  for &ic in [0, 1]
    for &scs in [0, 1]
      for &g:tc in ["followic", "ignore", "match", "followscs", "smart"]
        for &l:tc in ["", "followic", "ignore", "match", "followscs", "smart"]
          let smart = 0
          if &l:tc != ''
            let tc = &l:tc
          else
            let tc = &g:tc
          endif
          if tc == 'followic'
            let ic = &ic
          elseif tc == 'ignore'
            let ic = 1
          elseif tc == 'followscs'
            let ic = &ic
            let smart = &scs
          elseif tc == 'smart'
            let ic = 1
            let smart = 1
          else
            let ic = 0
          endif
          if ic && smart
            call assert_equal(['foo', 'Foo'], map(taglist("^foo$"), {i, v -> v.name}))
            call assert_equal(['Foo'], map(taglist("^Foo$"), {i, v -> v.name}))
          elseif ic
            call assert_equal(['foo', 'Foo'], map(taglist("^foo$"), {i, v -> v.name}))
            call assert_equal(['Foo', 'foo'], map(taglist("^Foo$"), {i, v -> v.name}))
          else
            call assert_equal(['foo'], map(taglist("^foo$"), {i, v -> v.name}))
            call assert_equal(['Foo'], map(taglist("^Foo$"), {i, v -> v.name}))
          endif
        endfor
      endfor
    endfor
  endfor

  call delete('Xtags')
  set ic&
  setg tc&
  setl tc&
  set scs&
endfunc

func Test_set_tagcase()
  " Verify default values.
  set ic&
  setg tc&
  setl tc&
  call assert_equal(0, &ic)
  call assert_equal('followic', &g:tc)
  call assert_equal('followic', &l:tc)
  call assert_equal('followic', &tc)

  " Verify that the local setting accepts <empty> but that the global setting
  " does not.  The first of these (setting the local value to <empty>) should
  " succeed; the other two should fail.
  setl tc=
  call assert_fails('setg tc=', 'E474:')
  call assert_fails('set tc=', 'E474:')

  set ic&
  setg tc&
  setl tc&
endfunc
