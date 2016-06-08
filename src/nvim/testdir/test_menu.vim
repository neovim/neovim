" Test that the system menu can be loaded.

func Test_load_menu()
  try
    source $VIMRUNTIME/menu.vim
  catch
    call assert_false(1, 'error while loading menus: ' . v:exception)
  endtry
endfunc
