" Tests for :hide command/modifier and 'hidden' option

function SetUp()
  let s:save_hidden = &hidden
  let s:save_bufhidden = &bufhidden
  let s:save_autowrite = &autowrite
  set nohidden
  set bufhidden=
  set noautowrite
endfunc

function TearDown()
  let &hidden = s:save_hidden
  let &bufhidden = s:save_bufhidden
  let &autowrite = s:save_autowrite
endfunc

function Test_hide()
  let orig_bname = bufname('')
  let orig_winnr = winnr('$')

  new Xf1
  set modified
  call assert_fails('edit Xf2')
  bwipeout! Xf1

  new Xf1
  set modified
  edit! Xf2
  call assert_equal(['Xf2', 2], [bufname(''), winnr('$')])
  call assert_equal([1, 0], [buflisted('Xf1'), bufloaded('Xf1')])
  bwipeout! Xf1
  bwipeout! Xf2

  new Xf1
  set modified
  " :hide as a command
  hide
  call assert_equal([orig_bname, orig_winnr], [bufname(''), winnr('$')])
  call assert_equal([1, 1], [buflisted('Xf1'), bufloaded('Xf1')])
  bwipeout! Xf1

  new Xf1
  set modified
  " :hide as a command with trailing comment
  hide " comment
  call assert_equal([orig_bname, orig_winnr], [bufname(''), winnr('$')])
  call assert_equal([1, 1], [buflisted('Xf1'), bufloaded('Xf1')])
  bwipeout! Xf1

  new Xf1
  set modified
  " :hide as a command with bar
  hide | new Xf2 " comment
  call assert_equal(['Xf2', 2], [bufname(''), winnr('$')])
  call assert_equal([1, 1], [buflisted('Xf1'), bufloaded('Xf1')])
  bwipeout! Xf1
  bwipeout! Xf2

  new Xf1
  set modified
  " :hide as a modifier with trailing comment
  hide edit Xf2 " comment
  call assert_equal(['Xf2', 2], [bufname(''), winnr('$')])
  call assert_equal([1, 1], [buflisted('Xf1'), bufloaded('Xf1')])
  bwipeout! Xf1
  bwipeout! Xf2

  new Xf1
  set modified
  " To check that the bar is not recognized to separate commands
  hide echo "one|two"
  call assert_equal(['Xf1', 2], [bufname(''), winnr('$')])
  call assert_equal([1, 1], [buflisted('Xf1'), bufloaded('Xf1')])
  bwipeout! Xf1

  " set hidden
  new Xf1
  set hidden
  set modified
  edit Xf2 " comment
  call assert_equal(['Xf2', 2], [bufname(''), winnr('$')])
  call assert_equal([1, 1], [buflisted('Xf1'), bufloaded('Xf1')])
  bwipeout! Xf1
  bwipeout! Xf2

  " set hidden bufhidden=wipe
  new Xf1
  set bufhidden=wipe
  set modified
  hide edit! Xf2 " comment
  call assert_equal(['Xf2', 2], [bufname(''), winnr('$')])
  call assert_equal([0, 0], [buflisted('Xf1'), bufloaded('Xf1')])
  bwipeout! Xf2
endfunc

" vim: shiftwidth=2 sts=2 expandtab
