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

  if has('gui') || has('clientserver')
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
  endif
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
  tabmove -20
  call assert_equal(1, tabpagenr())
  tabmove +20
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
  call assert_fails("tabmove foo", 'E474:')
endfunc

" Test autocommands
function Test_tabpage_with_autocmd()
  if !has('autocmd')
    return
  endif
  tabonly!
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
  C tabnext 3
  call assert_equal(['=== tabnext 3 ===', 'BufLeave', 'WinLeave', 'TabLeave', 'WinEnter', 'TabEnter', '=== tabnext 2 ===', 'BufLeave', 'WinLeave', 'TabLeave', 'WinEnter', 'TabEnter', '=== tabnext 2 ===', '=== tabclose 3 ===', 'BufEnter', '=== tabclose 3 ==='], s:li)
  call assert_equal(['2/2'], [tabpagenr().'/'.tabpagenr('$')])

  delcommand C
  autocmd! TabDestructive
  augroup! TabDestructive
  autocmd! TestTabpageGroup
  augroup! TestTabpageGroup
  tabonly!
  bw!
endfunction

function Test_tabpage_with_tab_modifier()
  for n in range(4)
    tabedit
  endfor

  function s:check_tab(pre_nr, cmd, post_nr)
    exec 'tabnext ' . a:pre_nr
    exec a:cmd
    call assert_equal(a:post_nr, tabpagenr())
    call assert_equal('help', &filetype)
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
  tabonly!
  bw!
endfunction

func Test_tabnext_on_buf_unload()
  " This once caused a crash
  new
  tabedit
  tabfirst
  au BufUnload <buffer> tabnext
  q

  while tabpagenr('$') > 1
    quit
  endwhile
endfunc


" vim: shiftwidth=2 sts=2 expandtab
