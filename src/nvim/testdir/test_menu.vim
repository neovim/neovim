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

  let v:errmsg = ''
  doautocmd LoadBufferMenu VimEnter
  call assert_equal('', v:errmsg)

  source $VIMRUNTIME/delmenu.vim
  call assert_equal('', v:errmsg)
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

func Test_menu_commands()
  nmenu 2 Test.FooBar :let g:did_menu = 'normal'<CR>
  vmenu 2 Test.FooBar :let g:did_menu = 'visual'<CR>
  smenu 2 Test.FooBar :let g:did_menu = 'select'<CR>
  omenu 2 Test.FooBar :let g:did_menu = 'op-pending'<CR>
  tlmenu 2 Test.FooBar :let g:did_menu = 'terminal'<CR>
  imenu 2 Test.FooBar :let g:did_menu = 'insert'<CR>
  cmenu 2 Test.FooBar :let g:did_menu = 'cmdline'<CR>
  emenu n Test.FooBar

  call feedkeys(":menu Test.FooB\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"menu Test.FooBar', @:)

  call assert_equal('normal', g:did_menu)
  emenu v Test.FooBar
  call assert_equal('visual', g:did_menu)
  emenu s Test.FooBar
  call assert_equal('select', g:did_menu)
  emenu o Test.FooBar
  call assert_equal('op-pending', g:did_menu)
  emenu t Test.FooBar
  call assert_equal('terminal', g:did_menu)
  emenu i Test.FooBar
  call assert_equal('insert', g:did_menu)
  emenu c Test.FooBar
  call assert_equal('cmdline', g:did_menu)

  nunmenu Test.FooBar
  call assert_fails('emenu n Test.FooBar', 'E335: Menu not defined for Normal mode')
  vunmenu Test.FooBar
  call assert_fails('emenu v Test.FooBar', 'E335: Menu not defined for Visual mode')
  vmenu 2 Test.FooBar :let g:did_menu = 'visual'<CR>
  sunmenu Test.FooBar
  call assert_fails('emenu s Test.FooBar', 'E335: Menu not defined for Select mode')
  ounmenu Test.FooBar
  call assert_fails('emenu o Test.FooBar', 'E335: Menu not defined for Op-pending mode')
  iunmenu Test.FooBar
  call assert_fails('emenu i Test.FooBar', 'E335: Menu not defined for Insert mode')
  cunmenu Test.FooBar
  call assert_fails('emenu c Test.FooBar', 'E335: Menu not defined for Cmdline mode')
  tlunmenu Test.FooBar
  call assert_fails('emenu t Test.FooBar', 'E335: Menu not defined for Terminal mode')

  aunmenu Test.FooBar
  call assert_fails('emenu n Test.FooBar', 'E334:')

  nmenu 2 Test.FooBar.Child :let g:did_menu = 'foobar'<CR>
  call assert_fails('emenu n Test.FooBar', 'E333:')
  nunmenu Test.FooBar.Child

  unlet g:did_menu
endfun
