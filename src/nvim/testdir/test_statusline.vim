function! StatuslineWithCaughtError()
  let s:func_in_statusline_called = 1
  try
    call eval('unknown expression')
  catch
  endtry
  return ''
endfunction

function! StatuslineWithError()
  let s:func_in_statusline_called = 1
  call eval('unknown expression')
  return ''
endfunction

function! Test_caught_error_in_statusline()
  let s:func_in_statusline_called = 0
  set laststatus=2
  let statusline = '%{StatuslineWithCaughtError()}'
  let &statusline = statusline
  redrawstatus
  call assert_true(s:func_in_statusline_called)
  call assert_equal(statusline, &statusline)
  set statusline=
endfunction

function! Test_statusline_will_be_disabled_with_error()
  let s:func_in_statusline_called = 0
  set laststatus=2
  let statusline = '%{StatuslineWithError()}'
  try
    let &statusline = statusline
    redrawstatus
  catch
  endtry
  call assert_true(s:func_in_statusline_called)
  call assert_equal('', &statusline)
  set statusline=
endfunction
