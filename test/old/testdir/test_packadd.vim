" Tests for 'packpath' and :packadd


func SetUp()
  let s:topdir = getcwd() . '/Xdir'
  exe 'set packpath=' . s:topdir
  let s:plugdir = s:topdir . '/pack/mine/opt/mytest'
endfunc

func TearDown()
  call delete(s:topdir, 'rf')
endfunc

func Test_packadd()
  if !exists('s:plugdir')
    echomsg 'when running this test manually, call SetUp() first'
    return
  endif

  call mkdir(s:plugdir . '/plugin/also', 'p')
  call mkdir(s:plugdir . '/ftdetect', 'p')
  call mkdir(s:plugdir . '/after', 'p')

  " This used to crash Vim
  let &rtp = 'nosuchdir,' . s:plugdir . '/after'
  packadd mytest
  " plugdir should be inserted before plugdir/after
  call assert_match('^nosuchdir,' . s:plugdir . ',', &rtp)

  set rtp&
  let rtp = &rtp
  filetype on

  let rtp_entries = split(rtp, ',')
  for entry in rtp_entries
    if entry =~? '\<after\>'
      let first_after_entry = entry
      break
    endif
  endfor

  exe 'split ' . s:plugdir . '/plugin/test.vim'
  call setline(1, 'let g:plugin_works = 42')
  wq

  exe 'split ' . s:plugdir . '/plugin/also/loaded.vim'
  call setline(1, 'let g:plugin_also_works = 77')
  wq

  exe 'split ' . s:plugdir . '/ftdetect/test.vim'
  call setline(1, 'let g:ftdetect_works = 17')
  wq

  packadd mytest

  call assert_equal(42, g:plugin_works)
  call assert_equal(77, g:plugin_also_works)
  call assert_equal(17, g:ftdetect_works)
  call assert_true(len(&rtp) > len(rtp))
  call assert_match('/testdir/Xdir/pack/mine/opt/mytest\($\|,\)', &rtp)

  let new_after = match(&rtp, '/testdir/Xdir/pack/mine/opt/mytest/after,')
  let forwarded = substitute(first_after_entry, '\\', '[/\\\\]', 'g')
  let old_after = match(&rtp, ',' . forwarded . '\>')
  call assert_true(new_after > 0, 'rtp is ' . &rtp)
  call assert_true(old_after > 0, 'match ' . forwarded . ' in ' . &rtp)
  call assert_true(new_after < old_after, 'rtp is ' . &rtp)

  " NOTE: '/.../opt/myte' forwardly matches with '/.../opt/mytest'
  call mkdir(fnamemodify(s:plugdir, ':h') . '/myte', 'p')
  let rtp = &rtp
  packadd myte

  " Check the path of 'myte' is added
  call assert_true(len(&rtp) > len(rtp))
  call assert_match('/testdir/Xdir/pack/mine/opt/myte\($\|,\)', &rtp)

  " Check exception
  call assert_fails("packadd directorynotfound", 'E919:')
  call assert_fails("packadd", 'E471:')
endfunc

func Test_packadd_start()
  let plugdir = s:topdir . '/pack/mine/start/other'
  call mkdir(plugdir . '/plugin', 'p')
  set rtp&
  let rtp = &rtp
  filetype on

  exe 'split ' . plugdir . '/plugin/test.vim'
  call setline(1, 'let g:plugin_works = 24')
  wq

  packadd other

  call assert_equal(24, g:plugin_works)
  call assert_true(len(&rtp) > len(rtp))
  call assert_match('/testdir/Xdir/pack/mine/start/other\($\|,\)', &rtp)
endfunc

func Test_packadd_noload()
  call mkdir(s:plugdir . '/plugin', 'p')
  call mkdir(s:plugdir . '/syntax', 'p')
  set rtp&
  let rtp = &rtp

  exe 'split ' . s:plugdir . '/plugin/test.vim'
  call setline(1, 'let g:plugin_works = 42')
  wq
  let g:plugin_works = 0

  packadd! mytest

  call assert_true(len(&rtp) > len(rtp))
  call assert_match('testdir/Xdir/pack/mine/opt/mytest\($\|,\)', &rtp)
  call assert_equal(0, g:plugin_works)

  " check the path is not added twice
  let new_rtp = &rtp
  packadd! mytest
  call assert_equal(new_rtp, &rtp)
endfunc

func Test_packadd_symlink_dir()
  if !has('unix')
    return
  endif
  let top2_dir = s:topdir . '/Xdir2'
  let real_dir = s:topdir . '/Xsym'
  call mkdir(real_dir, 'p')
  exec "silent !ln -s Xsym"  top2_dir
  let &rtp = top2_dir . ',' . top2_dir . '/after'
  let &packpath = &rtp

  let s:plugdir = top2_dir . '/pack/mine/opt/mytest'
  call mkdir(s:plugdir . '/plugin', 'p')

  exe 'split ' . s:plugdir . '/plugin/test.vim'
  call setline(1, 'let g:plugin_works = 44')
  wq
  let g:plugin_works = 0

  packadd mytest

  " Must have been inserted in the middle, not at the end
  call assert_match('/pack/mine/opt/mytest,', &rtp)
  call assert_equal(44, g:plugin_works)

  " No change when doing it again.
  let rtp_before = &rtp
  packadd mytest
  call assert_equal(rtp_before, &rtp)

  set rtp&
  let rtp = &rtp
  exec "silent !rm" top2_dir
endfunc

func Test_packadd_symlink_dir2()
  if !has('unix')
    return
  endif
  let top2_dir = s:topdir . '/Xdir2'
  let real_dir = s:topdir . '/Xsym/pack'
  call mkdir(top2_dir, 'p')
  call mkdir(real_dir, 'p')
  let &rtp = top2_dir . ',' . top2_dir . '/after'
  let &packpath = &rtp

  exec "silent !ln -s ../Xsym/pack"  top2_dir . '/pack'
  let s:plugdir = top2_dir . '/pack/mine/opt/mytest'
  call mkdir(s:plugdir . '/plugin', 'p')

  exe 'split ' . s:plugdir . '/plugin/test.vim'
  call setline(1, 'let g:plugin_works = 48')
  wq
  let g:plugin_works = 0

  packadd mytest

  " Must have been inserted in the middle, not at the end
  call assert_match('/Xdir2/pack/mine/opt/mytest,', &rtp)
  call assert_equal(48, g:plugin_works)

  " No change when doing it again.
  let rtp_before = &rtp
  packadd mytest
  call assert_equal(rtp_before, &rtp)

  set rtp&
  let rtp = &rtp
  exec "silent !rm" top2_dir . '/pack'
  exec "silent !rmdir" top2_dir
endfunc

" Check command-line completion for :packadd
func Test_packadd_completion()
  let optdir1 = &packpath . '/pack/mine/opt'
  let optdir2 = &packpath . '/pack/candidate/opt'

  call mkdir(optdir1 . '/pluginA', 'p')
  call mkdir(optdir1 . '/pluginC', 'p')
  call writefile([], optdir1 . '/unrelated')
  call mkdir(optdir2 . '/pluginB', 'p')
  call mkdir(optdir2 . '/pluginC', 'p')
  call writefile([], optdir2 . '/unrelated')

  let li = []
  call feedkeys(":packadd \<Tab>')\<C-B>call add(li, '\<CR>", 't')
  call feedkeys(":packadd " . repeat("\<Tab>", 2) . "')\<C-B>call add(li, '\<CR>", 't')
  call feedkeys(":packadd " . repeat("\<Tab>", 3) . "')\<C-B>call add(li, '\<CR>", 't')
  call feedkeys(":packadd " . repeat("\<Tab>", 4) . "')\<C-B>call add(li, '\<CR>", 'tx')
  call assert_equal("packadd pluginA", li[0])
  call assert_equal("packadd pluginB", li[1])
  call assert_equal("packadd pluginC", li[2])
  call assert_equal("packadd ", li[3])
endfunc

func Test_packloadall()
  " plugin foo with an autoload directory
  let fooplugindir = &packpath . '/pack/mine/start/foo/plugin'
  call mkdir(fooplugindir, 'p')
  call writefile(['let g:plugin_foo_number = 1234',
	\ 'let g:plugin_foo_auto = bbb#value',
	\ 'let g:plugin_extra_auto = extra#value'], fooplugindir . '/bar.vim')
  let fooautodir = &packpath . '/pack/mine/start/foo/autoload'
  call mkdir(fooautodir, 'p')
  call writefile(['let bar#value = 77'], fooautodir . '/bar.vim')

  " plugin aaa with an autoload directory
  let aaaplugindir = &packpath . '/pack/mine/start/aaa/plugin'
  call mkdir(aaaplugindir, 'p')
  call writefile(['let g:plugin_aaa_number = 333',
	\ 'let g:plugin_aaa_auto = bar#value'], aaaplugindir . '/bbb.vim')
  let aaaautodir = &packpath . '/pack/mine/start/aaa/autoload'
  call mkdir(aaaautodir, 'p')
  call writefile(['let bbb#value = 55'], aaaautodir . '/bbb.vim')

  " plugin extra with only an autoload directory
  let extraautodir = &packpath . '/pack/mine/start/extra/autoload'
  call mkdir(extraautodir, 'p')
  call writefile(['let extra#value = 99'], extraautodir . '/extra.vim')

  packloadall
  call assert_equal(1234, g:plugin_foo_number)
  call assert_equal(55, g:plugin_foo_auto)
  call assert_equal(99, g:plugin_extra_auto)
  call assert_equal(333, g:plugin_aaa_number)
  call assert_equal(77, g:plugin_aaa_auto)

  " only works once
  call writefile(['let g:plugin_bar_number = 4321'], fooplugindir . '/bar2.vim')
  packloadall
  call assert_false(exists('g:plugin_bar_number'))

  " works when ! used
  packloadall!
  call assert_equal(4321, g:plugin_bar_number)
endfunc

func Test_start_autoload()
  " plugin foo with an autoload directory
  let autodir = &packpath .. '/pack/mine/start/foo/autoload'
  call mkdir(autodir, 'p')
  let fname = autodir .. '/foobar.vim'
  call writefile(['func foobar#test()',
	\ '  return 1666',
	\ 'endfunc'], fname)

  call assert_equal(1666, foobar#test())
  call delete(fname)
endfunc

func Test_helptags()
  let docdir1 = &packpath . '/pack/mine/start/foo/doc'
  let docdir2 = &packpath . '/pack/mine/start/bar/doc'
  call mkdir(docdir1, 'p')
  call mkdir(docdir2, 'p')
  call writefile(['look here: *look-here*'], docdir1 . '/bar.txt')
  call writefile(['look away: *look-away*'], docdir2 . '/foo.txt')
  exe 'set rtp=' . &packpath . '/pack/mine/start/foo,' . &packpath . '/pack/mine/start/bar'

  helptags ALL

  let tags1 = readfile(docdir1 . '/tags')
  call assert_match('look-here', tags1[0])
  let tags2 = readfile(docdir2 . '/tags')
  call assert_match('look-away', tags2[0])

  call assert_fails('helptags abcxyz', 'E150:')
endfunc

func Test_colorscheme()
  let colordirrun = &packpath . '/runtime/colors'
  let colordirstart = &packpath . '/pack/mine/start/foo/colors'
  let colordiropt = &packpath . '/pack/mine/opt/bar/colors'
  call mkdir(colordirrun, 'p')
  call mkdir(colordirstart, 'p')
  call mkdir(colordiropt, 'p')
  call writefile(['let g:found_one = 1'], colordirrun . '/one.vim')
  call writefile(['let g:found_two = 1'], colordirstart . '/two.vim')
  call writefile(['let g:found_three = 1'], colordiropt . '/three.vim')
  exe 'set rtp=' . &packpath . '/runtime'

  colorscheme one
  call assert_equal(1, g:found_one)
  colorscheme two
  call assert_equal(1, g:found_two)
  colorscheme three
  call assert_equal(1, g:found_three)
endfunc

func Test_colorscheme_completion()
  let colordirrun = &packpath . '/runtime/colors'
  let colordirstart = &packpath . '/pack/mine/start/foo/colors'
  let colordiropt = &packpath . '/pack/mine/opt/bar/colors'
  call mkdir(colordirrun, 'p')
  call mkdir(colordirstart, 'p')
  call mkdir(colordiropt, 'p')
  call writefile(['let g:found_one = 1'], colordirrun . '/one.vim')
  call writefile(['let g:found_two = 1'], colordirstart . '/two.vim')
  call writefile(['let g:found_three = 1'], colordiropt . '/three.vim')
  exe 'set rtp=' . &packpath . '/runtime'

  let li=[]
  call feedkeys(":colorscheme " . repeat("\<Tab>", 1) . "')\<C-B>call add(li, '\<CR>", 't')
  call feedkeys(":colorscheme " . repeat("\<Tab>", 2) . "')\<C-B>call add(li, '\<CR>", 't')
  call feedkeys(":colorscheme " . repeat("\<Tab>", 3) . "')\<C-B>call add(li, '\<CR>", 't')
  call feedkeys(":colorscheme " . repeat("\<Tab>", 4) . "')\<C-B>call add(li, '\<CR>", 'tx')
  call assert_equal("colorscheme one", li[0])
  call assert_equal("colorscheme three", li[1])
  call assert_equal("colorscheme two", li[2])
  call assert_equal("colorscheme ", li[3])
endfunc

func Test_runtime()
  let rundir = &packpath . '/runtime/extra'
  let startdir = &packpath . '/pack/mine/start/foo/extra'
  let optdir = &packpath . '/pack/mine/opt/bar/extra'
  call mkdir(rundir, 'p')
  call mkdir(startdir, 'p')
  call mkdir(optdir, 'p')
  call writefile(['let g:sequence .= "run"'], rundir . '/bar.vim')
  call writefile(['let g:sequence .= "start"'], startdir . '/bar.vim')
  call writefile(['let g:sequence .= "foostart"'], startdir . '/foo.vim')
  call writefile(['let g:sequence .= "opt"'], optdir . '/bar.vim')
  call writefile(['let g:sequence .= "xxxopt"'], optdir . '/xxx.vim')
  exe 'set rtp=' . &packpath . '/runtime'

  let g:sequence = ''
  runtime extra/bar.vim
  call assert_equal('run', g:sequence)
  let g:sequence = ''
  runtime NoSuchFile extra/bar.vim
  call assert_equal('run', g:sequence)

  let g:sequence = ''
  runtime START extra/bar.vim
  call assert_equal('start', g:sequence)
  let g:sequence = ''
  runtime START NoSuchFile extra/bar.vim extra/foo.vim
  call assert_equal('start', g:sequence)
  let g:sequence = ''
  runtime START NoSuchFile extra/foo.vim extra/bar.vim
  call assert_equal('foostart', g:sequence)
  let g:sequence = ''
  runtime! START NoSuchFile extra/bar.vim extra/foo.vim
  call assert_equal('startfoostart', g:sequence)

  let g:sequence = ''
  runtime OPT extra/bar.vim
  call assert_equal('opt', g:sequence)
  let g:sequence = ''
  runtime OPT NoSuchFile extra/bar.vim extra/xxx.vim
  call assert_equal('opt', g:sequence)
  let g:sequence = ''
  runtime OPT NoSuchFile extra/xxx.vim extra/bar.vim
  call assert_equal('xxxopt', g:sequence)
  let g:sequence = ''
  runtime! OPT NoSuchFile extra/bar.vim extra/xxx.vim
  call assert_equal('optxxxopt', g:sequence)

  let g:sequence = ''
  runtime PACK extra/bar.vim
  call assert_equal('start', g:sequence)
  let g:sequence = ''
  runtime! PACK extra/bar.vim
  call assert_equal('startopt', g:sequence)
  let g:sequence = ''
  runtime PACK extra/xxx.vim
  call assert_equal('xxxopt', g:sequence)
  let g:sequence = ''
  runtime PACK extra/xxx.vim extra/foo.vim extra/bar.vim
  call assert_equal('foostart', g:sequence)
  let g:sequence = ''
  runtime! PACK extra/bar.vim extra/xxx.vim extra/foo.vim
  call assert_equal('startfoostartoptxxxopt', g:sequence)

  let g:sequence = ''
  runtime ALL extra/bar.vim
  call assert_equal('run', g:sequence)
  let g:sequence = ''
  runtime ALL extra/foo.vim
  call assert_equal('foostart', g:sequence)
  let g:sequence = ''
  runtime! ALL extra/xxx.vim
  call assert_equal('xxxopt', g:sequence)
  let g:sequence = ''
  runtime! ALL extra/bar.vim
  call assert_equal('runstartopt', g:sequence)
  let g:sequence = ''
  runtime ALL extra/xxx.vim extra/foo.vim extra/bar.vim
  call assert_equal('run', g:sequence)
  let g:sequence = ''
  runtime! ALL extra/bar.vim extra/xxx.vim extra/foo.vim
  call assert_equal('runstartfoostartoptxxxopt', g:sequence)
endfunc

func Test_runtime_completion()
  let rundir = &packpath . '/runtime/Aextra'
  let startdir = &packpath . '/pack/mine/start/foo/Aextra'
  let optdir = &packpath . '/pack/mine/opt/bar/Aextra'
  call mkdir(rundir . '/Arunbaz', 'p')
  call mkdir(startdir . '/Astartbaz', 'p')
  call mkdir(optdir . '/Aoptbaz', 'p')
  call writefile([], rundir . '/../Arunfoo.vim')
  call writefile([], rundir . '/Arunbar.vim')
  call writefile([], rundir . '/Aunrelated')
  call writefile([], rundir . '/../Aunrelated')
  call writefile([], startdir . '/../Astartfoo.vim')
  call writefile([], startdir . '/Astartbar.vim')
  call writefile([], startdir . '/Aunrelated')
  call writefile([], startdir . '/../Aunrelated')
  call writefile([], optdir . '/../Aoptfoo.vim')
  call writefile([], optdir . '/Aoptbar.vim')
  call writefile([], optdir . '/Aunrelated')
  call writefile([], optdir . '/../Aunrelated')
  exe 'set rtp=' . &packpath . '/runtime'

  func Check_runtime_completion(arg, arg_prev, res)
    call feedkeys(':runtime ' .. a:arg .. "\<C-A>\<C-B>\"\<CR>", 'xt')
    call assert_equal('"runtime ' .. a:arg_prev .. join(a:res), @:)
    call assert_equal(a:res, getcompletion(a:arg, 'runtime'))
  endfunc

  call Check_runtime_completion('', '',
        \ ['Aextra/', 'Arunfoo.vim', 'START', 'OPT', 'PACK', 'ALL'])
  call Check_runtime_completion('S', '',
        \ ['START'])
  call Check_runtime_completion('O', '',
        \ ['OPT'])
  call Check_runtime_completion('P', '',
        \ ['PACK'])
  call Check_runtime_completion('A', '',
        \ ['Aextra/', 'Arunfoo.vim', 'ALL'])
  call Check_runtime_completion('Other.vim ', 'Other.vim ',
        \ ['Aextra/', 'Arunfoo.vim'])
  call Check_runtime_completion('Aextra/', '',
        \ ['Aextra/Arunbar.vim', 'Aextra/Arunbaz/'])
  call Check_runtime_completion('Other.vim Aextra/', 'Other.vim ',
        \ ['Aextra/Arunbar.vim', 'Aextra/Arunbaz/'])

  call Check_runtime_completion('START ', 'START ',
        \ ['Aextra/', 'Astartfoo.vim'])
  call Check_runtime_completion('START Other.vim ', 'START Other.vim ',
        \ ['Aextra/', 'Astartfoo.vim'])
  call Check_runtime_completion('START A', 'START ',
        \ ['Aextra/', 'Astartfoo.vim'])
  call Check_runtime_completion('START Other.vim A', 'START Other.vim ',
        \ ['Aextra/', 'Astartfoo.vim'])
  call Check_runtime_completion('START Aextra/', 'START ',
        \ ['Aextra/Astartbar.vim', 'Aextra/Astartbaz/'])
  call Check_runtime_completion('START Other.vim Aextra/', 'START Other.vim ',
        \ ['Aextra/Astartbar.vim', 'Aextra/Astartbaz/'])

  call Check_runtime_completion('OPT ', 'OPT ',
        \ ['Aextra/', 'Aoptfoo.vim'])
  call Check_runtime_completion('OPT Other.vim ', 'OPT Other.vim ',
        \ ['Aextra/', 'Aoptfoo.vim'])
  call Check_runtime_completion('OPT A', 'OPT ',
        \ ['Aextra/', 'Aoptfoo.vim'])
  call Check_runtime_completion('OPT Other.vim A', 'OPT Other.vim ',
        \ ['Aextra/', 'Aoptfoo.vim'])
  call Check_runtime_completion('OPT Aextra/', 'OPT ',
        \ ['Aextra/Aoptbar.vim', 'Aextra/Aoptbaz/'])
  call Check_runtime_completion('OPT Other.vim Aextra/', 'OPT Other.vim ',
        \ ['Aextra/Aoptbar.vim', 'Aextra/Aoptbaz/'])

  call Check_runtime_completion('PACK ', 'PACK ',
        \ ['Aextra/', 'Aoptfoo.vim', 'Astartfoo.vim'])
  call Check_runtime_completion('PACK Other.vim ', 'PACK Other.vim ',
        \ ['Aextra/', 'Aoptfoo.vim', 'Astartfoo.vim'])
  call Check_runtime_completion('PACK A', 'PACK ',
        \ ['Aextra/', 'Aoptfoo.vim', 'Astartfoo.vim'])
  call Check_runtime_completion('PACK Other.vim A', 'PACK Other.vim ',
        \ ['Aextra/', 'Aoptfoo.vim', 'Astartfoo.vim'])
  call Check_runtime_completion('PACK Aextra/', 'PACK ',
        \ ['Aextra/Aoptbar.vim', 'Aextra/Aoptbaz/',
        \ 'Aextra/Astartbar.vim', 'Aextra/Astartbaz/'])
  call Check_runtime_completion('PACK Other.vim Aextra/', 'PACK Other.vim ',
        \ ['Aextra/Aoptbar.vim', 'Aextra/Aoptbaz/',
        \ 'Aextra/Astartbar.vim', 'Aextra/Astartbaz/'])

  call Check_runtime_completion('ALL ', 'ALL ',
        \ ['Aextra/', 'Aoptfoo.vim', 'Arunfoo.vim', 'Astartfoo.vim'])
  call Check_runtime_completion('ALL Other.vim ', 'ALL Other.vim ',
        \ ['Aextra/', 'Aoptfoo.vim', 'Arunfoo.vim', 'Astartfoo.vim'])
  call Check_runtime_completion('ALL A', 'ALL ',
        \ ['Aextra/', 'Aoptfoo.vim', 'Arunfoo.vim', 'Astartfoo.vim'])
  call Check_runtime_completion('ALL Other.vim A', 'ALL Other.vim ',
        \ ['Aextra/', 'Aoptfoo.vim', 'Arunfoo.vim', 'Astartfoo.vim'])
  call Check_runtime_completion('ALL Aextra/', 'ALL ',
        \ ['Aextra/Aoptbar.vim', 'Aextra/Aoptbaz/',
        \ 'Aextra/Arunbar.vim', 'Aextra/Arunbaz/',
        \ 'Aextra/Astartbar.vim', 'Aextra/Astartbaz/'])
  call Check_runtime_completion('ALL Other.vim Aextra/', 'ALL Other.vim ',
        \ ['Aextra/Aoptbar.vim', 'Aextra/Aoptbaz/',
        \ 'Aextra/Arunbar.vim', 'Aextra/Arunbaz/',
        \ 'Aextra/Astartbar.vim', 'Aextra/Astartbaz/'])

  delfunc Check_runtime_completion
endfunc

" vim: shiftwidth=2 sts=2 expandtab
