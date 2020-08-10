
source shared.vim

func TablineWithCaughtError()
  let s:func_in_tabline_called = 1
  try
    call eval('unknown expression')
  catch
  endtry
  return ''
endfunc

func TablineWithError()
  let s:func_in_tabline_called = 1
  call eval('unknown expression')
  return ''
endfunc

func Test_caught_error_in_tabline()
  let showtabline_save = &showtabline
  set showtabline=2
  let s:func_in_tabline_called = 0
  let tabline = '%{TablineWithCaughtError()}'
  let &tabline = tabline
  redraw!
  call assert_true(s:func_in_tabline_called)
  call assert_equal(tabline, &tabline)
  set tabline=
  let &showtabline = showtabline_save
endfunc

func Test_tabline_will_be_disabled_with_error()
  let showtabline_save = &showtabline
  set showtabline=2
  let s:func_in_tabline_called = 0
  let tabline = '%{TablineWithError()}'
  try
    let &tabline = tabline
    redraw!
  catch
  endtry
  call assert_true(s:func_in_tabline_called)
  call assert_equal('', &tabline)
  set tabline=
  let &showtabline = showtabline_save
endfunc

func Test_redrawtabline()
  if has('gui')
    set guioptions-=e
  endif
  let showtabline_save = &showtabline
  set showtabline=2
  set tabline=%{bufnr('$')}
  edit Xtabline1
  edit Xtabline2
  redraw
  call assert_match(bufnr('$') . '', Screenline(1))
  au BufAdd * redrawtabline
  badd Xtabline3
  call assert_match(bufnr('$') . '', Screenline(1))

  set tabline=
  let &showtabline = showtabline_save
  au! Bufadd
endfunc

function EmptyTabname()
  return ""
endfunction

function MakeTabLine() abort
  let titles = map(range(1, tabpagenr('$')), '"%( %" . v:val . "T%{EmptyTabname()}%T %)"')
  let sep = 'あ'
  let tabpages = join(titles, sep)
  return tabpages .. sep .. '%=%999X X'
endfunction

func Test_tabline_empty_group()
  " this was reading invalid memory
  set tabline=%!MakeTabLine()
  tabnew
  redraw!

  tabclose
  set tabline=
endfunc



" vim: shiftwidth=2 sts=2 expandtab
