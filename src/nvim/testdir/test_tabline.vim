function! TablineWithCaughtError()
  let s:func_in_tabline_called = 1
  try
    call eval('unknown expression')
  catch
  endtry
  return ''
endfunction

function! TablineWithError()
  let s:func_in_tabline_called = 1
  call eval('unknown expression')
  return ''
endfunction

function! Test_caught_error_in_tabline()
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
endfunction

function! Test_tabline_will_be_disabled_with_error()
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
endfunction
