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


" vim: shiftwidth=2 sts=2 expandtab
