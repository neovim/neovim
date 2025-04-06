" Tests for editing the command line.

source check.vim
source screendump.vim


func Test_cant_open_cmdwin_in_cmdwin()
  try
    call feedkeys("q:q::q\<CR>", "x!")
  catch
    let caught = v:exception
  endtry
  call assert_match('E1292:', caught)
endfunc

func Test_cmdwin_virtual_edit()
  enew!
  set ve=all cpo+=$
  silent normal q/s

  set ve= cpo-=$
endfunc

" Check that a :normal command can be used to stop Visual mode without side
" effects.
func Test_normal_escape()
  call feedkeys("q:i\" foo\<Esc>:normal! \<C-V>\<Esc>\<CR>:\" bar\<CR>", 'ntx')
  call assert_equal('" bar', @:)
endfunc

" This was using a pointer to a freed buffer
func Test_cmdwin_freed_buffer_ptr()
  " this does not work on MS-Windows because renaming an open file fails
  CheckNotMSWindows

  au BufEnter * next 0| file 
  edit 0
  silent! norm q/

  au! BufEnter
  bwipe!
endfunc

" This was resulting in a window with negative width.
" The test doesn't reproduce the illegal memory access though...
func Test_cmdwin_split_often()
  let lines = &lines
  let columns = &columns
  set t_WS=

  try
    " set encoding=iso8859
    set ruler
    winsize 0 0
    noremap 0 H
    sil norm 0000000q:
  catch /E36:/
  endtry

  bwipe!
  set encoding=utf8
  let &lines = lines
  let &columns = columns
endfunc

func Test_cmdwin_restore_heights()
  set showtabline=0 cmdheight=2 laststatus=0
  call feedkeys("q::set cmdheight=1\<CR>:q\<CR>", 'ntx')
  call assert_equal(&lines - 1, winheight(0))

  set showtabline=2 cmdheight=3
  call feedkeys("q::set showtabline=0\<CR>:q\<CR>", 'ntx')
  call assert_equal(&lines - 3, winheight(0))

  set cmdheight=1 laststatus=2
  call feedkeys("q::set laststatus=0\<CR>:q\<CR>", 'ntx')
  call assert_equal(&lines - 1, winheight(0))

  set laststatus=2
  call feedkeys("q::set laststatus=1\<CR>:q\<CR>", 'ntx')
  call assert_equal(&lines - 1, winheight(0))

  set laststatus=2
  belowright vsplit
  wincmd _
  let restcmds = winrestcmd()
  call feedkeys("q::set laststatus=1\<CR>:q\<CR>", 'ntx')
  " As we have 2 windows, &ls = 1 should still have a statusline on the last
  " window. As such, the number of available rows hasn't changed and the window
  " sizes should be restored.
  call assert_equal(restcmds, winrestcmd())

  set cmdheight& showtabline& laststatus&
endfunc

func Test_cmdwin_temp_curwin()
  func CheckWraps(expect_wrap)
    setlocal textwidth=0 wrapmargin=1

    call deletebufline('', 1, '$')
    let as = repeat('a', winwidth(0) - 2 - &wrapmargin)
    call setline(1, as .. ' b')
    normal! gww

    setlocal textwidth& wrapmargin&
    call assert_equal(a:expect_wrap ? [as, 'b'] : [as .. ' b'], getline(1, '$'))
  endfunc

  func CheckCmdWin()
    call assert_equal('command', win_gettype())
    " textoff and &wrapmargin formatting considers the cmdwin_type char.
    call assert_equal(1, getwininfo(win_getid())[0].textoff)
    call CheckWraps(1)
  endfunc

  func CheckOtherWin()
    call assert_equal('', win_gettype())
    call assert_equal(0, getwininfo(win_getid())[0].textoff)
    call CheckWraps(0)
  endfunc

  call feedkeys("q::call CheckCmdWin()\<CR>:call win_execute(win_getid(winnr('#')), 'call CheckOtherWin()')\<CR>:q<CR>", 'ntx')

  %bwipe!
  delfunc CheckWraps
  delfunc CheckCmdWin
  delfunc CheckOtherWin
endfunc

func Test_cmdwin_interrupted()
  func CheckInterrupted()
    call feedkeys("q::call assert_equal('', getcmdwintype())\<CR>:call assert_equal('', getcmdtype())\<CR>:q<CR>", 'ntx')
  endfunc

  augroup CmdWin

  " While opening the cmdwin's split:
  " Close the cmdwin's window.
  au WinEnter * ++once quit
  call CheckInterrupted()

  " Close the old window.
  au WinEnter * ++once execute winnr('#') 'quit'
  call CheckInterrupted()

  " Switch back to the old window.
  au WinEnter * ++once wincmd p
  call CheckInterrupted()

  " Change the old window's buffer.
  au WinEnter * ++once call win_execute(win_getid(winnr('#')), 'enew')
  call CheckInterrupted()

  " Using BufLeave autocmds as cmdwin restrictions do not apply to them when
  " fired from opening the cmdwin...
  " After opening the cmdwin's split, while creating the cmdwin's buffer:
  " Delete the cmdwin's buffer.
  au BufLeave * ++once bwipe
  call CheckInterrupted()

  " Close the cmdwin's window.
  au BufLeave * ++once quit
  call CheckInterrupted()

  " Close the old window.
  au BufLeave * ++once execute winnr('#') 'quit'
  call CheckInterrupted()

  " Switch to a different window.
  au BufLeave * ++once split
  call CheckInterrupted()

  " Change the old window's buffer.
  au BufLeave * ++once call win_execute(win_getid(winnr('#')), 'enew')
  call CheckInterrupted()

  " However, changing the current buffer is OK and does not interrupt.
  au BufLeave * ++once edit other
  call feedkeys("q::let t=getcmdwintype()\<CR>:let b=bufnr()\<CR>:clo<CR>", 'ntx')
  call assert_equal(':', t)
  call assert_equal(1, bufloaded('other'))
  call assert_notequal(b, bufnr('other'))

  augroup END

  " No autocmds should remain, but clear the augroup to be sure.
  augroup CmdWin
    au!
  augroup END

  %bwipe!
  delfunc CheckInterrupted
endfunc

func Test_cmdwin_existing_bufname()
  func CheckName()
    call assert_equal(1, getbufinfo('')[0].command)
    call assert_equal(0, getbufinfo('[Command Line]')[0].command)
    call assert_match('#a\s*"\[Command Line\]"', execute('ls'))
    call assert_match('%a\s*"\[Command Line\]"', execute('ls'))
  endfunc
  file [Command Line]
  call feedkeys("q::call CheckName()\<CR>:q\<CR>", 'ntx')
  0file
  delfunc CheckName
endfunc

" vim: shiftwidth=2 sts=2 expandtab
