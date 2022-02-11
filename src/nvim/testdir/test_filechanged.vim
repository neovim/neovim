" Tests for when a file was changed outside of Vim.

func Test_FileChangedShell_reload()
  if !has('unix')
    return
  endif
  augroup testreload
    au FileChangedShell Xchanged_r let g:reason = v:fcs_reason | let v:fcs_choice = 'reload'
  augroup END
  new Xchanged_r
  call setline(1, 'reload this')
  write
  " Need to wait until the timestamp would change by at least a second.
  sleep 2
  silent !echo 'extra line' >>Xchanged_r
  checktime
  call assert_equal('changed', g:reason)
  call assert_equal(2, line('$'))
  call assert_equal('extra line', getline(2))

  " Only triggers once
  let g:reason = ''
  checktime
  call assert_equal('', g:reason)

  " When deleted buffer is not reloaded
  silent !rm Xchanged_r
  let g:reason = ''
  checktime
  call assert_equal('deleted', g:reason)
  call assert_equal(2, line('$'))
  call assert_equal('extra line', getline(2))

  " When recreated buffer is reloaded
  call setline(1, 'buffer is changed')
  silent !echo 'new line' >>Xchanged_r
  let g:reason = ''
  checktime
  call assert_equal('conflict', g:reason)
  call assert_equal(1, line('$'))
  call assert_equal('new line', getline(1))

  " Only mode changed
  silent !chmod +x Xchanged_r
  let g:reason = ''
  checktime
  call assert_equal('mode', g:reason)
  call assert_equal(1, line('$'))
  call assert_equal('new line', getline(1))

  " Only time changed
  sleep 2
  silent !touch Xchanged_r
  let g:reason = ''
  checktime
  call assert_equal('time', g:reason)
  call assert_equal(1, line('$'))
  call assert_equal('new line', getline(1))

  if has('persistent_undo')
    " With an undo file the reload can be undone and a change before the
    " reload.
    set undofile
    call setline(2, 'before write')
    write
    call setline(2, 'after write')
    sleep 2
    silent !echo 'different line' >>Xchanged_r
    let g:reason = ''
    checktime
    call assert_equal('conflict', g:reason)
    call assert_equal(3, line('$'))
    call assert_equal('before write', getline(2))
    call assert_equal('different line', getline(3))
    " undo the reload
    undo
    call assert_equal(2, line('$'))
    call assert_equal('after write', getline(2))
    " undo the change before reload
    undo
    call assert_equal(2, line('$'))
    call assert_equal('before write', getline(2))

    set noundofile
  endif

  au! testreload
  bwipe!
  call delete(undofile('Xchanged_r'))
  call delete('Xchanged_r')
endfunc

func Test_file_changed_dialog()
  throw 'Skipped: requires a UI to a active'
  if !has('unix') || has('gui_running')
    return
  endif
  au! FileChangedShell

  new Xchanged_d
  call setline(1, 'reload this')
  write
  " Need to wait until the timestamp would change by at least a second.
  sleep 2
  silent !echo 'extra line' >>Xchanged_d
  call feedkeys('L', 'L')
  checktime
  call assert_match('W11:', v:warningmsg)
  call assert_equal(2, line('$'))
  call assert_equal('reload this', getline(1))
  call assert_equal('extra line', getline(2))

  " delete buffer, only shows an error, no prompt
  silent !rm Xchanged_d
  checktime
  call assert_match('E211:', v:warningmsg)
  call assert_equal(2, line('$'))
  call assert_equal('extra line', getline(2))
  let v:warningmsg = 'empty'

  " change buffer, recreate the file and reload
  call setline(1, 'buffer is changed')
  silent !echo 'new line' >Xchanged_d
  call feedkeys('L', 'L')
  checktime
  call assert_match('W12:', v:warningmsg)
  call assert_equal(1, line('$'))
  call assert_equal('new line', getline(1))

  " Only mode changed, reload
  silent !chmod +x Xchanged_d
  call feedkeys('L', 'L')
  checktime
  call assert_match('W16:', v:warningmsg)
  call assert_equal(1, line('$'))
  call assert_equal('new line', getline(1))

  " Only time changed, no prompt
  sleep 2
  silent !touch Xchanged_d
  let v:warningmsg = ''
  checktime
  call assert_equal('', v:warningmsg)
  call assert_equal(1, line('$'))
  call assert_equal('new line', getline(1))

  bwipe!
  call delete('Xchanged_d')
endfunc
