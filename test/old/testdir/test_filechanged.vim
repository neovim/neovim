" Tests for when a file was changed outside of Vim.

source check.vim

func Test_FileChangedShell_reload()
  CheckUnix

  augroup testreload
    au FileChangedShell Xchanged_r let g:reason = v:fcs_reason | let v:fcs_choice = 'reload'
  augroup END
  new Xchanged_r
  call setline(1, 'reload this')
  write
  " Need to wait until the timestamp would change.
  if has('nanotime')
    sleep 10m
  else
    sleep 2
  endif
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
  if has('nanotime')
    sleep 10m
  else
    sleep 2
  endif
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
    if has('nanotime')
      sleep 10m
    else
      sleep 2
    endif
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

func Test_FileChangedShell_edit()
  CheckUnix

  new Xchanged_r
  call setline(1, 'reload this')
  set fileformat=unix
  write

  " File format changed, reload (content only, no 'ff' etc)
  augroup testreload
    au!
    au FileChangedShell Xchanged_r let g:reason = v:fcs_reason | let v:fcs_choice = 'reload'
  augroup END
  call assert_equal(&fileformat, 'unix')
  sleep 10m  " make the test less flaky in Nvim
  call writefile(["line1\r", "line2\r"], 'Xchanged_r')
  let g:reason = ''
  checktime
  call assert_equal('changed', g:reason)
  call assert_equal(&fileformat, 'unix')
  call assert_equal("line1\r", getline(1))
  call assert_equal("line2\r", getline(2))
  %s/\r
  write

  " File format changed, reload with 'ff', etc
  augroup testreload
    au!
    au FileChangedShell Xchanged_r let g:reason = v:fcs_reason | let v:fcs_choice = 'edit'
  augroup END
  call assert_equal(&fileformat, 'unix')
  sleep 10m  " make the test less flaky in Nvim
  call writefile(["line1\r", "line2\r"], 'Xchanged_r')
  let g:reason = ''
  checktime
  call assert_equal('changed', g:reason)
  call assert_equal(&fileformat, 'dos')
  call assert_equal('line1', getline(1))
  call assert_equal('line2', getline(2))
  set fileformat=unix
  write

  au! testreload
  bwipe!
  call delete(undofile('Xchanged_r'))
  call delete('Xchanged_r')
endfunc

func Test_FileChangedShell_edit_dialog()
  CheckNotGui
  CheckUnix  " Using low level feedkeys() does not work on MS-Windows.

  new Xchanged_r
  call setline(1, 'reload this')
  set fileformat=unix
  write

  " File format changed, reload (content only) via prompt
  augroup testreload
    au!
    au FileChangedShell Xchanged_r let g:reason = v:fcs_reason | let v:fcs_choice = 'ask'
  augroup END
  call assert_equal(&fileformat, 'unix')
  sleep 10m  " make the test less flaky in Nvim
  call writefile(["line1\r", "line2\r"], 'Xchanged_r')
  let g:reason = ''
  call feedkeys('L', 'L') " load file content only
  checktime
  call assert_equal('changed', g:reason)
  call assert_equal(&fileformat, 'unix')
  call assert_equal("line1\r", getline(1))
  call assert_equal("line2\r", getline(2))
  %s/\r
  write

  " File format changed, reload (file and options) via prompt
  augroup testreload
    au!
    au FileChangedShell Xchanged_r let g:reason = v:fcs_reason | let v:fcs_choice = 'ask'
  augroup END
  call assert_equal(&fileformat, 'unix')
  sleep 10m  " make the test less flaky in Nvim
  call writefile(["line1\r", "line2\r"], 'Xchanged_r')
  let g:reason = ''
  call feedkeys('a', 'L') " load file content and options
  checktime
  call assert_equal('changed', g:reason)
  call assert_equal(&fileformat, 'dos')
  call assert_equal("line1", getline(1))
  call assert_equal("line2", getline(2))
  set fileformat=unix
  write

  au! testreload
  bwipe!
  call delete(undofile('Xchanged_r'))
  call delete('Xchanged_r')
endfunc

func Test_file_changed_dialog()
  CheckUnix
  CheckNotGui
  au! FileChangedShell

  new Xchanged_d
  call setline(1, 'reload this')
  write
  " Need to wait until the timestamp would change.
  if has('nanotime')
    sleep 10m
  else
    sleep 2
  endif
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
  if has('nanotime')
    sleep 10m
  else
    sleep 2
  endif
  silent !touch Xchanged_d
  let v:warningmsg = ''
  checktime Xchanged_d
  call assert_equal('', v:warningmsg)
  call assert_equal(1, line('$'))
  call assert_equal('new line', getline(1))

  " File created after starting to edit it
  call delete('Xchanged_d')
  new Xchanged_d
  call writefile(['one'], 'Xchanged_d')
  call feedkeys('L', 'L')
  checktime Xchanged_d
  call assert_equal(['one'], getline(1, '$'))
  close!

  bwipe!
  call delete('Xchanged_d')
endfunc

" Test for editing a new buffer from a FileChangedShell autocmd
func Test_FileChangedShell_newbuf()
  call writefile(['one', 'two'], 'Xfile')
  new Xfile
  augroup testnewbuf
    autocmd FileChangedShell * enew
  augroup END
  sleep 10m  " make the test less flaky in Nvim
  call writefile(['red'], 'Xfile')
  call assert_fails('checktime', 'E811:')
  au! testnewbuf
  call delete('Xfile')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
