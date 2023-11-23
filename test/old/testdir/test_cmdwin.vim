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


" vim: shiftwidth=2 sts=2 expandtab
