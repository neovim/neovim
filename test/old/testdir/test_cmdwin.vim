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


" vim: shiftwidth=2 sts=2 expandtab
