" Test that the system menu can be loaded.

if !has('menu')
  finish
endif

func Test_load_menu()
  try
    source $VIMRUNTIME/menu.vim
  catch
    call assert_report('error while loading menus: ' . v:exception)
  endtry
  call assert_match('browse confirm w', execute(':menu File.Save'))
  source $VIMRUNTIME/delmenu.vim
endfunc

func Test_translate_menu()
  if !has('multi_lang')
    return
  endif
  if !filereadable($VIMRUNTIME . '/lang/menu_de_de.latin1.vim')
    throw 'Skipped: translated menu not found'
  endif

  " First delete any English menus.
  source $VIMRUNTIME/delmenu.vim
  set langmenu=de_de
  source $VIMRUNTIME/menu.vim
  call assert_match('browse confirm w', execute(':menu Datei.Speichern'))

  source $VIMRUNTIME/delmenu.vim
endfunc
