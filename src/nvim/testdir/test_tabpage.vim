" Tests for tabpage


function Test_tabpage()
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
  call settabvar(2, 'val_str', 'SetTabVar test')
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
  " Test for ":tab drop multi-opend-file" to keep current tabpage and window.
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

  " The following are a no-op
  norm! 2gt
  call assert_equal(2, tabpagenr())
  tabmove 2
  call assert_equal(2, tabpagenr())
  2tabmove
  call assert_equal(2, tabpagenr())
  tabmove 1
  call assert_equal(2, tabpagenr())
  1tabmove
  call assert_equal(2, tabpagenr())

  call assert_fails("99tabmove", 'E16:')
  call assert_fails("+99tabmove", 'E16:')
  call assert_fails("-99tabmove", 'E16:')
  call assert_fails("tabmove foo", 'E474:')
  call assert_fails("tabmove 99", 'E474:')
  call assert_fails("tabmove +99", 'E474:')
  call assert_fails("tabmove -99", 'E474:')
  call assert_fails("tabmove -3+", 'E474:')
  call assert_fails("tabmove $3", 'E474:')
  1tabonly!
endfunc

" Test autocommands
function Test_tabpage_with_autocmd()
  if !has('autocmd')
    return
  endif
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
  C call map(copy(winr), 'settabwinvar('.tabn.', v:val, ''a'', v:val*2)')
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

function Test_tabpage_with_tab_modifier()
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
  call assert_fails('tabnext 0', 'E474:')
  call assert_fails('tabnext .', 'E474:')
  call assert_fails('tabnext -+', 'E474:')
  call assert_fails('tabnext +2-', 'E474:')
  call assert_fails('tabnext $3', 'E474:')
  call assert_fails('tabnext 99', 'E474:')
  call assert_fails('tabnext +99', 'E474:')
  call assert_fails('tabnext -99', 'E474:')

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
          let err_code = 'E474:'
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
        let err_code = 'E474:'
      endif
      call assert_fails(entire_cmd, err_code)
      call assert_equal(6, tabpagenr('$'))
    endfor
  endfor

  call assert_fails('3tabclose', 'E37:')
  call assert_fails('tabclose 3', 'E37:')
  call assert_fails('tabclose -+', 'E474:')
  call assert_fails('tabclose +2-', 'E474:')
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
        let err_code = 'E474:'
      endif
      call assert_fails(entire_cmd, err_code)
      call assert_equal(6, tabpagenr('$'))
    endfor
  endfor

  " Test for the error behavior (post count only)
  for c in tc
    call s:reconstruct_tabpage_for_test(6)
    let entire_cmd = 'tabonly' . c[2] . ' ' . c[1]
    let err_code = 'E474:'
    call assert_fails(entire_cmd, err_code)
    call assert_equal(6, tabpagenr('$'))
  endfor

  call assert_fails('tabonly -+', 'E474:')
  call assert_fails('tabonly +2-', 'E474:')
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
      \              '    [No Name]',
      \              'Tab page 2',
      \              '> + tab1'], a)

  1tabonly!
  bw!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
