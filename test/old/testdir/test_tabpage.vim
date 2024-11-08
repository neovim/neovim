" Tests for tabpage

source screendump.vim
source check.vim

function Test_tabpage()
  CheckFeature quickfix

  bw!
  " Simple test for opening and closing a tab page
  tabnew
  call assert_equal(2, tabpagenr())
  quit

  " Open three tab pages and use ":tabdo"
  0tabnew
  1tabnew
  $tabnew
  %del
  tabdo call append(line('$'), tabpagenr())
  tabclose! 2
  tabrewind
  let line1 = getline('$')
  undo
  q
  tablast
  let line2 = getline('$')
  q!
  call append(line('$'), line1)
  call append(line('$'), line2)
  unlet line1 line2
  call assert_equal(['', '3', '1', '4'], getline(1, '$'))
  "
  " Test for settabvar() and gettabvar() functions. Open a new tab page and
  " set 3 variables to a number, string and a list. Verify that the variables
  " are correctly set.
  tabnew
  tabfirst
  call settabvar(2, 'val_num', 100)
  eval 'SetTabVar test'->settabvar(2, 'val_str')
  call settabvar(2, 'val_list', ['red', 'blue', 'green'])
  "
  call assert_true(gettabvar(2, 'val_num') == 100 && gettabvar(2, 'val_str') == 'SetTabVar test' && gettabvar(2, 'val_list') == ['red', 'blue', 'green'])

  tabnext 2
  call assert_true(t:val_num == 100 && t:val_str == 'SetTabVar test'  && t:val_list == ['red', 'blue', 'green'])
  tabclose

  " Test for ":tab drop exist-file" to keep current window.
  sp test1
  tab drop test1
  call assert_true(tabpagenr('$') == 1 && winnr('$') == 2 && winnr() == 1)
  close
  "
  "
  " Test for ":tab drop new-file" to keep current window of tabpage 1.
  split
  tab drop newfile
  call assert_true(tabpagenr('$') == 2 && tabpagewinnr(1, '$') == 2 && tabpagewinnr(1) == 1)
  tabclose
  q
  "
  "
  " Test for ":tab drop multi-opened-file" to keep current tabpage and window.
  new test1
  tabnew
  new test1
  tab drop test1
  call assert_true(tabpagenr() == 2 && tabpagewinnr(2, '$') == 2 && tabpagewinnr(2) == 1)
  tabclose
  q
  "
  "
  " Test for ":tab drop vertical-split-window" to jump test1 buffer
  tabedit test1
  vnew
  tabfirst
  tab drop test1
  call assert_equal([2, 2, 2, 2], [tabpagenr('$'), tabpagenr(), tabpagewinnr(2, '$'), tabpagewinnr(2)])
  1tabonly
  "
  "
  for i in range(9) | tabnew | endfor
  normal! 1gt
  call assert_equal(1, tabpagenr())
  tabmove 5
  call assert_equal(5, tabpagenr())
  .tabmove
  call assert_equal(5, tabpagenr())
  tabmove -
  call assert_equal(4, tabpagenr())
  tabmove +
  call assert_equal(5, tabpagenr())
  tabmove -2
  call assert_equal(3, tabpagenr())
  tabmove +4
  call assert_equal(7, tabpagenr())
  tabmove
  call assert_equal(10, tabpagenr())
  0tabmove
  call assert_equal(1, tabpagenr())
  $tabmove
  call assert_equal(10, tabpagenr())
  tabmove 0
  call assert_equal(1, tabpagenr())
  tabmove $
  call assert_equal(10, tabpagenr())
  3tabmove
  call assert_equal(4, tabpagenr())
  7tabmove 5
  call assert_equal(5, tabpagenr())
  -tabmove
  call assert_equal(4, tabpagenr())
  +tabmove
  call assert_equal(5, tabpagenr())
  -2tabmove
  call assert_equal(3, tabpagenr())
  +3tabmove
  call assert_equal(6, tabpagenr())
  silent -tabmove
  call assert_equal(5, tabpagenr())
  silent -2 tabmove
  call assert_equal(3, tabpagenr())
  silent	-2	tabmove
  call assert_equal(1, tabpagenr())

  norm! 2gt
  call assert_equal(2, tabpagenr())
  " The following are a no-op
  tabmove 2
  call assert_equal(2, tabpagenr())
  2tabmove
  call assert_equal(2, tabpagenr())
  tabmove 1
  call assert_equal(2, tabpagenr())
  1tabmove
  call assert_equal(2, tabpagenr())

  call assert_fails('let t = tabpagenr("@")', 'E15:')
  call assert_equal(0, tabpagewinnr(-1))
  call assert_fails("99tabmove", 'E16:')
  call assert_fails("+99tabmove", 'E16:')
  call assert_fails("-99tabmove", 'E16:')
  call assert_fails("tabmove foo", 'E475:')
  call assert_fails("tabmove 99", 'E475:')
  call assert_fails("tabmove +99", 'E475:')
  call assert_fails("tabmove -99", 'E475:')
  call assert_fails("tabmove -3+", 'E475:')
  call assert_fails("tabmove $3", 'E475:')
  call assert_fails("%tabonly", 'E16:')
  1tabonly!
  tabmove 1
  call assert_equal(1, tabpagenr())
  tabnew
  call assert_fails("-2tabmove", 'E16:')
  tabonly!
endfunc

func Test_tabpage_drop()
  edit f1
  tab split f2
  tab split f3
  normal! gt
  call assert_equal(1, tabpagenr())
  tab drop f4
  call assert_equal(1, tabpagenr('#'))

  tab drop f3
  call assert_equal(4, tabpagenr())
  call assert_equal(2, tabpagenr('#'))
  bwipe!
  bwipe!
  bwipe!
  bwipe!
  call assert_equal(1, tabpagenr('$'))

  call assert_equal(1, winnr('$'))
  call assert_equal('', bufname(''))
  call writefile(['L1', 'L2'], 'Xdropfile', 'D')

  " Test for ':tab drop single-file': reuse current buffer
  let expected_nr = bufnr()
  tab drop Xdropfile
  call assert_equal(1, tabpagenr('$'))
  call assert_equal(expected_nr, bufnr())
  call assert_equal('L2', getline(2))
  bwipe!

  " Test for ':tab drop single-file': not reuse modified buffer
  set modified
  let expected_nr = bufnr() + 1
  tab drop Xdropfile
  call assert_equal(2, tabpagenr())
  call assert_equal(2, tabpagenr('$'))
  call assert_equal(expected_nr, bufnr())
  call assert_equal('L2', getline(2))
  bwipe!

  " Test for ':tab drop single-file': multiple tabs already exist
  tab split f2
  tab split f3
  let expected_nr = bufnr() + 1
  tab drop Xdropfile
  call assert_equal(4, tabpagenr())
  call assert_equal(4, tabpagenr('$'))
  call assert_equal(expected_nr, bufnr())
  call assert_equal('L2', getline(2))
  %bwipe!

  " Test for ':tab drop multi-files': reuse current buffer
  let expected_nr = bufnr()
  tab drop Xdropfile f1 f2 f3
  call assert_equal(1, tabpagenr())
  call assert_equal(4, tabpagenr('$'))
  call assert_equal(expected_nr, bufnr())
  call assert_equal('L2', getline(2))
  %bwipe!

  " Test for ':tab drop multi-files': not reuse modified buffer
  set modified
  let expected_nr = bufnr() + 1
  tab drop Xdropfile f1 f2 f3
  call assert_equal(2, tabpagenr())
  call assert_equal(5, tabpagenr('$'))
  call assert_equal(expected_nr, bufnr())
  call assert_equal('L2', getline(2))
  %bwipe!

  " Test for ':tab drop multi-files': multiple tabs already exist
  tab split f2
  tab split f3
  let expected_nr = bufnr() + 1
  tab drop a b c
  call assert_equal(4, tabpagenr())
  call assert_equal(6, tabpagenr('$'))
  call assert_equal(expected_nr, bufnr())
  let expected_nr = bufnr() + 3
  tab drop Xdropfile f1 f2 f3
  call assert_equal(5, tabpagenr())
  call assert_equal(8, tabpagenr('$'))
  call assert_equal(expected_nr, bufnr())
  call assert_equal('L2', getline(2))
  %bwipe!
endfunc

" Test autocommands
function Test_tabpage_with_autocmd()
  command -nargs=1 -bar C :call add(s:li, '=== ' . <q-args> . ' ===')|<args>
  augroup TestTabpageGroup
    au!
    autocmd TabEnter * call add(s:li, 'TabEnter')
    autocmd WinEnter * call add(s:li, 'WinEnter')
    autocmd BufEnter * call add(s:li, 'BufEnter')
    autocmd TabLeave * call add(s:li, 'TabLeave')
    autocmd WinLeave * call add(s:li, 'WinLeave')
    autocmd BufLeave * call add(s:li, 'BufLeave')
  augroup END

  let s:li = []
  let t:a='a'
  C tab split
  call assert_equal(['=== tab split ===', 'WinLeave', 'TabLeave', 'WinEnter', 'TabEnter'], s:li)
  let s:li = []
  let t:a='b'
  C tabnew
  call assert_equal(['=== tabnew ===', 'WinLeave', 'TabLeave', 'WinEnter', 'TabEnter', 'BufLeave', 'BufEnter'], s:li)
  let t:a='c'
  let s:li = split(join(map(range(1, tabpagenr('$')), 'gettabvar(v:val, "a")')) , '\s\+')
  call assert_equal(['a', 'b', 'c'], s:li)

  let s:li = []
  C call map(range(1, tabpagenr('$')), 'settabvar(v:val, ''a'', v:val*2)')
  call assert_equal(["=== call map(range(1, tabpagenr('$')), 'settabvar(v:val, ''a'', v:val*2)') ==="], s:li)
  let s:li = split(join(map(range(1, tabpagenr('$')), 'gettabvar(v:val, "a")')) , '\s\+')
  call assert_equal(['2', '4', '6'], s:li)

  let s:li = []
  let w:a='a'
  C vsplit
  call assert_equal(['=== vsplit ===', 'WinLeave', 'WinEnter'], s:li)
  let s:li = []
  let w:a='a'
  let tabn=tabpagenr()
  let winr=range(1, winnr('$'))
  C tabnext 1
  call assert_equal(['=== tabnext 1 ===', 'BufLeave', 'WinLeave', 'TabLeave', 'WinEnter', 'TabEnter', 'BufEnter'], s:li)
  let s:li = split(join(map(copy(winr), 'gettabwinvar('.tabn.', v:val, "a")')), '\s\+')
  call assert_equal(['a', 'a'], s:li)
  let s:li = []
  C call map(copy(winr), '(v:val*2)->settabwinvar(' .. tabn .. ', v:val, ''a'')')
  let s:li = split(join(map(copy(winr), 'gettabwinvar('.tabn.', v:val, "a")')), '\s\+')
  call assert_equal(['2', '4'], s:li)

  augroup TabDestructive
    autocmd TabEnter * :C tabnext 2 | C tabclose 3
  augroup END
  let s:li = []
  C tabnext 3
  call assert_equal(['=== tabnext 3 ===', 'BufLeave', 'WinLeave', 'TabLeave', 'WinEnter', 'TabEnter', '=== tabnext 2 ===', '=== tabclose 3 ==='], s:li)
  call assert_equal(['2/2'], [tabpagenr().'/'.tabpagenr('$')])

  autocmd! TabDestructive TabEnter
  let s:li = []
  C tabnew
  call assert_equal(['=== tabnew ===', 'WinLeave', 'TabLeave', 'WinEnter', 'TabEnter', 'BufLeave', 'BufEnter'], s:li)
  let s:li = []
  C tabnext 1
  call assert_equal(['=== tabnext 1 ===', 'BufLeave', 'WinLeave', 'TabLeave', 'WinEnter', 'TabEnter', 'BufEnter'], s:li)

  autocmd TabDestructive TabEnter * nested :C tabnext 2 | C tabclose 3
  let s:li = []
  call assert_equal(3, tabpagenr('$'))
  C tabnext 2
  call assert_equal(2, tabpagenr('$'))
  call assert_equal(['=== tabnext 2 ===', 'WinLeave', 'TabLeave', 'WinEnter', 'TabEnter', '=== tabnext 2 ===', '=== tabclose 3 ==='], s:li)
  call assert_equal(['2/2'], [tabpagenr().'/'.tabpagenr('$')])

  delcommand C
  autocmd! TabDestructive
  augroup! TabDestructive
  autocmd! TestTabpageGroup
  augroup! TestTabpageGroup
  1tabonly!
endfunction

" Test autocommands on tab drop
function Test_tabpage_with_autocmd_tab_drop()
  augroup TestTabpageGroup
    au!
    autocmd TabEnter * call add(s:li, 'TabEnter')
    autocmd WinEnter * call add(s:li, 'WinEnter')
    autocmd BufEnter * call add(s:li, 'BufEnter')
    autocmd TabLeave * call add(s:li, 'TabLeave')
    autocmd WinLeave * call add(s:li, 'WinLeave')
    autocmd BufLeave * call add(s:li, 'BufLeave')
  augroup END

  let s:li = []
  tab drop test1
  call assert_equal(['BufEnter'], s:li)

  let s:li = []
  tab drop test2 test3
  call assert_equal([
        \ 'TabLeave', 'TabEnter', 'TabLeave', 'TabEnter',
        \ 'TabLeave', 'WinEnter', 'TabEnter', 'BufEnter',
        \ 'TabLeave', 'WinEnter', 'TabEnter', 'BufEnter', 'BufEnter'], s:li)

  autocmd! TestTabpageGroup
  augroup! TestTabpageGroup
  1tabonly!
endfunction

function Test_tabpage_with_tab_modifier()
  CheckFeature quickfix

  for n in range(4)
    tabedit
  endfor

  function s:check_tab(pre_nr, cmd, post_nr)
    exec 'tabnext ' . a:pre_nr
    exec a:cmd
    call assert_equal(a:post_nr, tabpagenr())
    call assert_equal('help', &buftype)
    helpclose
  endfunc

  call s:check_tab(1, 'tab help', 2)
  call s:check_tab(1, '3tab help', 4)
  call s:check_tab(1, '.tab help', 2)
  call s:check_tab(1, '.+1tab help', 3)
  call s:check_tab(1, '0tab help', 1)
  call s:check_tab(2, '+tab help', 4)
  call s:check_tab(2, '+2tab help', 5)
  call s:check_tab(4, '-tab help', 4)
  call s:check_tab(4, '-2tab help', 3)
  call s:check_tab(3, '$tab help', 6)
  call assert_fails('99tab help', 'E16:')
  call assert_fails('+99tab help', 'E16:')
  call assert_fails('-99tab help', 'E16:')

  delfunction s:check_tab
  1tabonly!
endfunction

function Check_tab_count(pre_nr, cmd, post_nr)
  exec 'tabnext' a:pre_nr
  normal! G
  exec a:cmd
  call assert_equal(a:post_nr, tabpagenr(), a:cmd)
endfunc

" Test for [count] of tabnext
function Test_tabpage_with_tabnext()
  for n in range(4)
    tabedit
    call setline(1, ['', '', '3'])
  endfor

  call Check_tab_count(1, 'tabnext', 2)
  call Check_tab_count(1, '3tabnext', 3)
  call Check_tab_count(1, '.tabnext', 1)
  call Check_tab_count(1, '.+1tabnext', 2)
  call Check_tab_count(2, '+tabnext', 3)
  call Check_tab_count(2, '+2tabnext', 4)
  call Check_tab_count(4, '-tabnext', 3)
  call Check_tab_count(4, '-2tabnext', 2)
  call Check_tab_count(3, '$tabnext', 5)
  call assert_fails('0tabnext', 'E16:')
  call assert_fails('99tabnext', 'E16:')
  call assert_fails('+99tabnext', 'E16:')
  call assert_fails('-99tabnext', 'E16:')
  call Check_tab_count(1, 'tabnext 3', 3)
  call Check_tab_count(2, 'tabnext +', 3)
  call Check_tab_count(2, 'tabnext +2', 4)
  call Check_tab_count(4, 'tabnext -', 3)
  call Check_tab_count(4, 'tabnext -2', 2)
  call Check_tab_count(3, 'tabnext $', 5)
  call assert_fails('tabnext 0', 'E475:')
  call assert_fails('tabnext .', 'E475:')
  call assert_fails('tabnext -+', 'E475:')
  call assert_fails('tabnext +2-', 'E475:')
  call assert_fails('tabnext $3', 'E475:')
  call assert_fails('tabnext 99', 'E475:')
  call assert_fails('tabnext +99', 'E475:')
  call assert_fails('tabnext -99', 'E475:')

  1tabonly!
endfunction

" Test for [count] of tabprevious
function Test_tabpage_with_tabprevious()
  for n in range(5)
    tabedit
    call setline(1, ['', '', '3'])
  endfor

  for cmd in ['tabNext', 'tabprevious']
    call Check_tab_count(6, cmd, 5)
    call Check_tab_count(6, '3' . cmd, 3)
    call Check_tab_count(6, '8' . cmd, 4)
    call Check_tab_count(6, cmd . ' 3', 3)
    call Check_tab_count(6, cmd . ' 8', 4)
    for n in range(2)
      for c in ['0', '.+3', '+', '+2' , '-', '-2' , '$', '+99', '-99']
        if n == 0 " pre count
          let entire_cmd = c . cmd
          let err_code = 'E16:'
        else
          let entire_cmd = cmd . ' ' . c
          let err_code = 'E475:'
        endif
        call assert_fails(entire_cmd, err_code)
      endfor
    endfor
  endfor

  1tabonly!
endfunction

function s:reconstruct_tabpage_for_test(nr)
  let n = (a:nr > 2) ? a:nr - 2 : 1
  1tabonly!
  0tabedit n0
  for n in range(1, n)
    exec '$tabedit n' . n
    if n == 1
      call setline(1, ['', '', '3'])
    endif
  endfor
endfunc

func Test_tabpage_ctrl_pgup_pgdown()
  enew!
  tabnew tab1
  tabnew tab2

  call assert_equal(3, tabpagenr())
  exe "norm! \<C-PageUp>"
  call assert_equal(2, tabpagenr())
  exe "norm! \<C-PageDown>"
  call assert_equal(3, tabpagenr())

  " Check wrapping at last or first page.
  exe "norm! \<C-PageDown>"
  call assert_equal(1, tabpagenr())
  exe "norm! \<C-PageUp>"
  call assert_equal(3, tabpagenr())

 " With a count, <C-PageUp> and <C-PageDown> are not symmetrical somehow:
 " - {count}<C-PageUp> goes {count} pages downward (relative count)
 " - {count}<C-PageDown> goes to page number {count} (absolute count)
  exe "norm! 2\<C-PageUp>"
  call assert_equal(1, tabpagenr())
  exe "norm! 2\<C-PageDown>"
  call assert_equal(2, tabpagenr())

  1tabonly!
endfunc

" Test for [count] of tabclose
function Test_tabpage_with_tabclose()

  " pre count
  call s:reconstruct_tabpage_for_test(6)
  call Check_tab_count(3, 'tabclose!', 3)
  call Check_tab_count(1, '3tabclose', 1)
  call Check_tab_count(4, '4tabclose', 3)
  call Check_tab_count(3, '1tabclose', 2)
  call Check_tab_count(2, 'tabclose', 1)
  call assert_equal(1, tabpagenr('$'))
  call assert_equal('', bufname(''))

  call s:reconstruct_tabpage_for_test(6)
  call Check_tab_count(2, '$tabclose', 2)
  call Check_tab_count(4, '.tabclose', 4)
  call Check_tab_count(3, '.+tabclose', 3)
  call Check_tab_count(3, '.-2tabclose', 2)
  call Check_tab_count(1, '.+1tabclose!', 1)
  call assert_equal(1, tabpagenr('$'))
  call assert_equal('', bufname(''))

  " post count
  call s:reconstruct_tabpage_for_test(6)
  call Check_tab_count(3, 'tabclose!', 3)
  call Check_tab_count(1, 'tabclose 3', 1)
  call Check_tab_count(4, 'tabclose 4', 3)
  call Check_tab_count(3, 'tabclose 1', 2)
  call Check_tab_count(2, 'tabclose', 1)
  call assert_equal(1, tabpagenr('$'))
  call assert_equal('', bufname(''))

  call s:reconstruct_tabpage_for_test(6)
  call Check_tab_count(2, 'tabclose $', 2)
  call Check_tab_count(4, 'tabclose', 4)
  call Check_tab_count(3, 'tabclose +', 3)
  call Check_tab_count(3, 'tabclose -2', 2)
  call Check_tab_count(1, 'tabclose! +1', 1)
  call assert_equal(1, tabpagenr('$'))
  call assert_equal('', bufname(''))

  call s:reconstruct_tabpage_for_test(6)
  for n in range(2)
    for c in ['0', '$3', '99', '+99', '-99']
      if n == 0 " pre count
        let entire_cmd = c . 'tabclose'
        let err_code = 'E16:'
      else
        let entire_cmd = 'tabclose ' . c
        let err_code = 'E475:'
      endif
      call assert_fails(entire_cmd, err_code)
      call assert_equal(6, tabpagenr('$'))
    endfor
  endfor

  call assert_fails('3tabclose', 'E37:')
  call assert_fails('tabclose 3', 'E37:')
  call assert_fails('tabclose -+', 'E475:')
  call assert_fails('tabclose +2-', 'E475:')
  call assert_equal(6, tabpagenr('$'))

  1tabonly!
endfunction

" Test for [count] of tabonly
function Test_tabpage_with_tabonly()

  " Test for the normal behavior (pre count only)
  let tc = [ [4, '.', '!'], [2, '.+', ''], [3, '.-2', '!'], [1, '.+1', '!'] ]
  for c in tc
    call s:reconstruct_tabpage_for_test(6)
    let entire_cmd = c[1] . 'tabonly' . c[2]
    call Check_tab_count(c[0], entire_cmd, 1)
    call assert_equal(1, tabpagenr('$'))
  endfor

  " Test for the normal behavior
  let tc2 = [ [3, '', ''], [1, '3', ''], [4, '4', '!'], [3, '1', '!'],
        \    [2, '', '!'],
        \    [2, '$', '!'], [3, '+', '!'], [3, '-2', '!'], [3, '+1', '!']
        \  ]
  for n in range(2)
    for c in tc2
      call s:reconstruct_tabpage_for_test(6)
      if n == 0 " pre count
        let entire_cmd = c[1] . 'tabonly' . c[2]
      else
        let entire_cmd = 'tabonly' . c[2] . ' ' . c[1]
      endif
      call Check_tab_count(c[0], entire_cmd, 1)
      call assert_equal(1, tabpagenr('$'))
    endfor
  endfor

  " Test for the error behavior
  for n in range(2)
    for c in ['0', '$3', '99', '+99', '-99']
      call s:reconstruct_tabpage_for_test(6)
      if n == 0 " pre count
        let entire_cmd = c . 'tabonly'
        let err_code = 'E16:'
      else
        let entire_cmd = 'tabonly ' . c
        let err_code = 'E475:'
      endif
      call assert_fails(entire_cmd, err_code)
      call assert_equal(6, tabpagenr('$'))
    endfor
  endfor

  " Test for the error behavior (post count only)
  for c in tc
    call s:reconstruct_tabpage_for_test(6)
    let entire_cmd = 'tabonly' . c[2] . ' ' . c[1]
    let err_code = 'E475:'
    call assert_fails(entire_cmd, err_code)
    call assert_equal(6, tabpagenr('$'))
  endfor

  call assert_fails('tabonly -+', 'E475:')
  call assert_fails('tabonly +2-', 'E475:')
  call assert_equal(6, tabpagenr('$'))

  1tabonly!
  new
  only!
endfunction

func Test_tabnext_on_buf_unload1()
  " This once caused a crash
  new
  tabedit
  tabfirst
  au BufUnload <buffer> tabnext
  q

  while tabpagenr('$') > 1
    bwipe!
  endwhile
endfunc

func Test_tabnext_on_buf_unload2()
  " This once caused a crash
  tabedit
  autocmd BufUnload <buffer> tabnext
  file x
  edit y

  while tabpagenr('$') > 1
    bwipe!
  endwhile
endfunc

func Test_close_on_quitpre()
  " This once caused a crash
  edit Xtest
  new
  only
  set bufhidden=delete
  au QuitPre <buffer> close
  tabnew tab1
  tabnew tab2
  1tabn
  q!
  call assert_equal(1, tabpagenr())
  call assert_equal(2, tabpagenr('$'))
  " clean up
  while tabpagenr('$') > 1
    bwipe!
  endwhile
  buf Xtest
endfunc

func Test_tabs()
  enew!
  tabnew tab1
  norm ixxx
  let a=split(execute(':tabs'), "\n")
  call assert_equal(['Tab page 1',
      \              '#   [No Name]',
      \              'Tab page 2',
      \              '> + tab1'], a)

  1tabonly!
  bw!
endfunc

func Test_tabpage_cmdheight()
  CheckRunVimInTerminal
  call writefile([
        \ 'set laststatus=2',
        \ 'set cmdheight=2',
        \ 'tabnew',
        \ 'set cmdheight=3',
        \ 'tabnext',
        \ 'redraw!',
        \ 'echo "hello\nthere"',
        \ 'tabnext',
        \ 'redraw',
	\ ], 'XTest_tabpage_cmdheight')
  " Check that cursor line is concealed
  let buf = RunVimInTerminal('-S XTest_tabpage_cmdheight', {'statusoff': 3})
  call VerifyScreenDump(buf, 'Test_tabpage_cmdheight', {})

  call StopVimInTerminal(buf)
  call delete('XTest_tabpage_cmdheight')
endfunc

" Test for closing the tab page from a command window
func Test_tabpage_close_cmdwin()
  tabnew
  call feedkeys("q/:tabclose\<CR>\<Esc>", 'xt')
  call assert_equal(2, tabpagenr('$'))
  call feedkeys("q/:tabonly\<CR>\<Esc>", 'xt')
  call assert_equal(2, tabpagenr('$'))
  tabonly
endfunc

" Pressing <C-PageUp> in insert mode should go to the previous tab page
" and <C-PageDown> should go to the next tab page
func Test_tabpage_Ctrl_Pageup()
  tabnew
  call feedkeys("i\<C-PageUp>", 'xt')
  call assert_equal(1, tabpagenr())
  call feedkeys("i\<C-PageDown>", 'xt')
  call assert_equal(2, tabpagenr())
  %bw!
endfunc

" Return the terminal key code for selecting a tab page from the tabline. This
" sequence contains the following codes: a CSI (0x9b), KS_TABLINE (0xf0),
" KS_FILLER (0x58) and then the tab page number.
func TabLineSelectPageCode(tabnr)
  return "\x9b\xf0\x58" ..  nr2char(a:tabnr)
endfunc

" Return the terminal key code for opening a new tabpage from the tabpage
" menu. This sequence consists of the following codes: a CSI (0x9b),
" KS_TABMENU (0xef), KS_FILLER (0x58), the tab page number and
" TABLINE_MENU_NEW (2).
func TabMenuNewItemCode(tabnr)
  return "\x9b\xef\x58" .. nr2char(a:tabnr) .. nr2char(2)
endfunc

" Return the terminal key code for closing a tabpage from the tabpage menu.
" This sequence consists of the following codes: a CSI (0x9b), KS_TABMENU
" (0xef), KS_FILLER (0x58), the tab page number and TABLINE_MENU_CLOSE (1).
func TabMenuCloseItemCode(tabnr)
  return "\x9b\xef\x58" .. nr2char(a:tabnr) .. nr2char(1)
endfunc

" Test for using the tabpage menu from the insert and normal modes
func Test_tabline_tabmenu()
  " only works in GUI
  CheckGui

  %bw!
  tabnew
  tabnew
  call assert_equal(3, tabpagenr())

  " go to tab page 2 in normal mode
  call feedkeys(TabLineSelectPageCode(2), "Lx!")
  call assert_equal(2, tabpagenr())

  " close tab page 3 in normal mode
  call feedkeys(TabMenuCloseItemCode(3), "Lx!")
  call assert_equal(2, tabpagenr('$'))
  call assert_equal(2, tabpagenr())

  " open new tab page before tab page 1 in normal mode
  call feedkeys(TabMenuNewItemCode(1), "Lx!")
  call assert_equal(1, tabpagenr())
  call assert_equal(3, tabpagenr('$'))

  " go to tab page 2 in operator-pending mode (should beep)
  call assert_beeps('call feedkeys("c" .. TabLineSelectPageCode(2), "Lx!")')
  call assert_equal(2, tabpagenr())
  call assert_equal(3, tabpagenr('$'))

  " open new tab page before tab page 1 in operator-pending mode (should beep)
  call assert_beeps('call feedkeys("c" .. TabMenuNewItemCode(1), "Lx!")')
  call assert_equal(1, tabpagenr())
  call assert_equal(4, tabpagenr('$'))

  " open new tab page after tab page 3 in normal mode
  call feedkeys(TabMenuNewItemCode(4), "Lx!")
  call assert_equal(4, tabpagenr())
  call assert_equal(5, tabpagenr('$'))

  " go to tab page 2 in insert mode
  call feedkeys("i" .. TabLineSelectPageCode(2) .. "\<C-C>", "Lx!")
  call assert_equal(2, tabpagenr())

  " close tab page 2 in insert mode
  call feedkeys("i" .. TabMenuCloseItemCode(2) .. "\<C-C>", "Lx!")
  call assert_equal(4, tabpagenr('$'))

  " open new tab page before tab page 3 in insert mode
  call feedkeys("i" .. TabMenuNewItemCode(3) .. "\<C-C>", "Lx!")
  call assert_equal(3, tabpagenr())
  call assert_equal(5, tabpagenr('$'))

  " open new tab page after tab page 4 in insert mode
  call feedkeys("i" .. TabMenuNewItemCode(5) .. "\<C-C>", "Lx!")
  call assert_equal(5, tabpagenr())
  call assert_equal(6, tabpagenr('$'))

  %bw!
endfunc

" Test for changing the current tab page from an autocmd when closing a tab
" page.
func Test_tabpage_switchtab_on_close()
  only
  tabnew
  tabnew
  " Test for BufLeave
  augroup T1
    au!
    au BufLeave * tabfirst
  augroup END
  tabclose
  call assert_equal(1, tabpagenr())
  augroup T1
    au!
  augroup END

  " Test for WinLeave
  $tabnew
  augroup T1
    au!
    au WinLeave * tabfirst
  augroup END
  tabclose
  call assert_equal(1, tabpagenr())
  augroup T1
    au!
  augroup END

  " Test for TabLeave
  $tabnew
  augroup T1
    au!
    au TabLeave * tabfirst
  augroup END
  tabclose
  call assert_equal(1, tabpagenr())
  augroup T1
    au!
  augroup END
  augroup! T1
  tabonly
endfunc

" Test for closing the destination tabpage when jumping from one to another.
func Test_tabpage_close_on_switch()
  tabnew
  tabnew
  edit Xfile
  augroup T2
    au!
    au BufLeave Xfile 1tabclose
  augroup END
  tabfirst
  call assert_equal(2, tabpagenr())
  call assert_equal('Xfile', @%)
  augroup T2
    au!
  augroup END
  augroup! T2
  %bw!
endfunc

" Test for jumping to last accessed tabpage
func Test_lastused_tabpage()
  tabonly!
  call assert_equal(0, tabpagenr('#'))
  call assert_beeps('call feedkeys("g\<Tab>", "xt")')
  call assert_beeps('call feedkeys("\<C-Tab>", "xt")')
  call assert_beeps('call feedkeys("\<C-W>g\<Tab>", "xt")')
  call assert_fails('tabnext #', 'E475:')

  " open four tab pages
  tabnew
  tabnew
  tabnew

  2tabnext

  " Test for g<Tab>
  call assert_equal(4, tabpagenr('#'))
  call feedkeys("g\<Tab>", "xt")
  call assert_equal(4, tabpagenr())
  call assert_equal(2, tabpagenr('#'))

  " Test for <C-Tab>
  call feedkeys("\<C-Tab>", "xt")
  call assert_equal(2, tabpagenr())
  call assert_equal(4, tabpagenr('#'))

  " Test for <C-W>g<Tab>
  call feedkeys("\<C-W>g\<Tab>", "xt")
  call assert_equal(4, tabpagenr())
  call assert_equal(2, tabpagenr('#'))

  " Test for :tabnext #
  tabnext #
  call assert_equal(2, tabpagenr())
  call assert_equal(4, tabpagenr('#'))

  " Try to jump to a closed tab page
  tabclose #
  call assert_equal(0, tabpagenr('#'))
  call feedkeys("g\<Tab>", "xt")
  call assert_equal(2, tabpagenr())
  call feedkeys("\<C-Tab>", "xt")
  call assert_equal(2, tabpagenr())
  call feedkeys("\<C-W>g\<Tab>", "xt")
  call assert_equal(2, tabpagenr())
  call assert_fails('tabnext #', 'E475:')
  call assert_equal(2, tabpagenr())

  " Test for :tabonly #
  let wnum = win_getid()
  $tabnew
  tabonly #
  call assert_equal(wnum, win_getid())
  call assert_equal(1, tabpagenr('$'))

  " Test for :tabmove #
  tabnew
  let wnum = win_getid()
  tabnew
  tabnew
  tabnext 2
  tabmove #
  call assert_equal(4, tabpagenr())
  call assert_equal(wnum, win_getid())

  tabonly!
endfunc

" Test for tabpage allocation failure
func Test_tabpage_alloc_failure()
  CheckFunction test_alloc_fail
  call test_alloc_fail(GetAllocId('newtabpage_tvars'), 0, 0)
  call assert_fails('tabnew', 'E342:')

  call test_alloc_fail(GetAllocId('newtabpage_tvars'), 0, 0)
  edit Xfile1
  call assert_fails('tabedit Xfile2', 'E342:')
  call assert_equal(1, winnr('$'))
  call assert_equal(1, tabpagenr('$'))
  call assert_equal('Xfile1', @%)

  new
  call test_alloc_fail(GetAllocId('newtabpage_tvars'), 0, 0)
  call assert_fails('wincmd T', 'E342:')
  bw!

  call test_alloc_fail(GetAllocId('newtabpage_tvars'), 0, 0)
  call assert_fails('tab split', 'E342:')
  call assert_equal(2, winnr('$'))
  call assert_equal(1, tabpagenr('$'))
endfunc

func Test_tabpage_tabclose()
  " Default behaviour, move to the right.
  call s:reconstruct_tabpage_for_test(6)
  norm! 4gt
  setl tcl=
  tabclose
  call assert_equal("n3", bufname())

  " Move to the left.
  call s:reconstruct_tabpage_for_test(6)
  norm! 4gt
  setl tcl=left
  tabclose
  call assert_equal("n1", bufname())

  " Move to the last used tab page.
  call s:reconstruct_tabpage_for_test(6)
  norm! 5gt
  norm! 2gt
  setl tcl=uselast
  tabclose
  call assert_equal("n3", bufname())

  " Same, but the last used tab page is invalid. Move to the right.
  call s:reconstruct_tabpage_for_test(6)
  norm! 5gt
  norm! 3gt
  setl tcl=uselast
  tabclose 5
  tabclose!
  call assert_equal("n2", bufname())

  " Same, but the last used tab page is invalid. Move to the left.
  call s:reconstruct_tabpage_for_test(6)
  norm! 5gt
  norm! 3gt
  setl tcl=uselast,left
  tabclose 5
  tabclose!
  call assert_equal("n0", bufname())

  " Move left when moving right is not possible.
  call s:reconstruct_tabpage_for_test(6)
  setl tcl=
  norm! 6gt
  tabclose
  call assert_equal("n3", bufname())

  " Move right when moving left is not possible.
  call s:reconstruct_tabpage_for_test(6)
  setl tcl=left
  norm! 1gt
  tabclose
  call assert_equal("n0", bufname())

  setl tcl&
endfunc

" this was giving ml_get errors
func Test_tabpage_last_line()
  enew
  call setline(1, repeat(['a'], &lines + 5))
  $
  tabnew
  call setline(1, repeat(['b'], &lines + 20))
  $
  tabNext
  call assert_equal('a', getline('.'))

  bwipe!
  bwipe!
endfunc

" this was causing an endless loop
func Test_tabpage_drop_tabmove()
  augroup TestTabpageTabmove
    au!
    autocmd! TabEnter * :if tabpagenr() > 1 | tabmove - | endif
  augroup end
  $tab drop XTab_99.log
  $tab drop XTab_98.log
  $tab drop XTab_97.log

  autocmd! TestTabpageTabmove
  augroup! TestTabpageTabmove

  " clean up
  bwipe!
  bwipe!
  bwipe!
endfunc

" Test that settabvar() shouldn't change the last accessed tabpage.
func Test_lastused_tabpage_settabvar()
  tabonly!
  tabnew
  tabnew
  tabnew
  call assert_equal(3, tabpagenr('#'))

  call settabvar(2, 'myvar', 'tabval')
  call assert_equal('tabval', gettabvar(2, 'myvar'))
  call assert_equal(3, tabpagenr('#'))

  bwipe!
  bwipe!
  bwipe!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
