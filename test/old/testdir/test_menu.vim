" Test that the system menu can be loaded.

source check.vim
CheckFeature menu

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

func Test_buffer_menu_special_buffers()
  " Load in runtime menus
  try
    source $VIMRUNTIME/menu.vim
  catch
    call assert_report('error while loading menus: ' . v:exception)
  endtry

  let v:errmsg = ''
  doautocmd LoadBufferMenu VimEnter
  call assert_equal('', v:errmsg)

  let orig_buffer_menus = execute("nmenu Buffers")

  " Test that regular new buffer results in a new buffer menu item.
  new
  let new_buffer_menus = execute('nmenu Buffers')
  call assert_equal(len(split(orig_buffer_menus, "\n")) + 2, len(split(new_buffer_menus, "\n")))
  bwipe!
  call assert_equal(orig_buffer_menus, execute("nmenu Buffers"))

  " Make a new command-line window, test that it does not create a new buffer
  " menu.
  call feedkeys("q::let cmdline_buffer_menus=execute('nmenu Buffers')\<CR>:q\<CR>", 'ntx')
  call assert_equal(len(split(orig_buffer_menus, "\n")) + 2, len(split(cmdline_buffer_menus, "\n")))
  call assert_equal(orig_buffer_menus, execute("nmenu Buffers"))

  if has('terminal')
    " Open a terminal window and test that it does not create a buffer menu
    " item.
    terminal
    let term_buffer_menus = execute('nmenu Buffers')
    call assert_equal(len(split(orig_buffer_menus, "\n")) + 2, len(split(term_buffer_menus, "\n")))
    bwipe!
    call assert_equal(orig_buffer_menus, execute("nmenu Buffers"))
  endif

  " Remove menus to clean up
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

" Test various menu related errors
func Test_menu_errors()
  menu Test.Foo  :version<CR>

  " Error cases
  call assert_fails('menu .Test.Foo :ls<CR>', 'E475:')
  call assert_fails('menu Test. :ls<CR>', 'E330:')
  call assert_fails('menu Foo. :ls<CR>', 'E331:')
  call assert_fails('unmenu Test.Foo abc', 'E488:')
  call assert_fails('menu <Tab>:ls  :ls<CR>', 'E792:')
  call assert_fails('menu Test.<Tab>:ls  :ls<CR>', 'E792:')
  call assert_fails('menu Test.Foo.Bar  :ls<CR>', 'E327:')
  call assert_fails('menu Test.-Sep-.Baz  :ls<CR>', 'E332:')
  call assert_fails('menu Foo.Bar.--.Baz  :ls<CR>', 'E332:')
  call assert_fails('menu disable Test.Foo.Bar', 'E327:')
  call assert_fails('menu disable T.Foo', 'E329:')
  call assert_fails('unmenu Test.Foo.Bar', 'E327:')
  call assert_fails('cunmenu Test.Foo', 'E328:')
  call assert_fails('unmenu Test.Bar', 'E329:')
  call assert_fails('menu Test.Foo.Bar', 'E327:')
  call assert_fails('cmenu Test.Foo', 'E328:')
  call assert_fails('emenu x Test.Foo', 'E475:')
  call assert_fails('emenu Test.Foo.Bar', 'E327:')
  call assert_fails('menutranslate Test', 'E474:')

  silent! unmenu Foo
  unmenu Test
endfunc

" Test for menu item completion in command line
func Test_menu_expand()
  " Create the menu items for test
  menu Dummy.Nothing lll
  for i in range(1, 4)
    let m = 'menu Xmenu.A' .. i .. '.A' .. i
    for j in range(1, 4)
      exe m .. 'B' .. j .. ' :echo "A' .. i .. 'B' .. j .. '"' .. "<CR>"
    endfor
  endfor
  set wildmenu

  " Test for <CR> selecting a submenu
  call feedkeys(":emenu Xmenu.A\<Tab>\<CR>\<Right>x\<BS>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"emenu Xmenu.A1.A1B2', @:)

  " Test for <Down> selecting a submenu
  call feedkeys(":emenu Xmenu.A\<Tab>\<Right>\<Right>\<Down>" ..
        \ "\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"emenu Xmenu.A3.A3B1 A3B2 A3B3 A3B4', @:)

  " Test for <Up> to go up a submenu
  call feedkeys(":emenu Xmenu.A\<Tab>\<Down>\<Up>\<Right>\<Right>" ..
        \ "\<Left>\<Down>\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"emenu Xmenu.A2.A2B1 A2B2 A2B3 A2B4', @:)

  " Test for <Up> to go up a menu
  call feedkeys(":emenu Xmenu.A\<Tab>\<Down>\<Up>\<Up>\<Up>" ..
        \ "\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"emenu Dummy. Xmenu.', @:)

  " Test for expanding only submenus
  call feedkeys(":popup Xmenu.\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"popup Xmenu.A1 A2 A3 A4', @:)

  " Test for expanding menus after enable/disable
  call feedkeys(":menu enable Xmenu.\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"menu enable Xmenu.A1. A2. A3. A4.', @:)
  call feedkeys(":menu disable Xmenu.\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"menu disable Xmenu.A1. A2. A3. A4.', @:)

  " Test for expanding non-existing menu path
  call feedkeys(":menu xyz.\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"menu xyz.', @:)
  call feedkeys(":menu Xmenu.A1.A1B1.xyz.\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"menu Xmenu.A1.A1B1.xyz.', @:)

  set wildmenu&
  unmenu Xmenu
  unmenu Dummy

  " Test for expanding popup menus with some hidden items
  menu Xmenu.foo.A1 a1
  menu Xmenu.]bar bar
  menu Xmenu.]baz.B1 b1
  menu Xmenu.-sep- :
  call feedkeys(":popup Xmenu.\<C-A>\<C-B>\"\<CR>", 'xt')
  call assert_equal('"popup Xmenu.foo', @:)
  unmenu Xmenu
endfunc

" Test for the menu_info() function
func Test_menu_info()
  " Define menus with various attributes
  10nnoremenu 10.10 T&est.F&oo  :echo 'foo'<CR>
  10nmenu <silent> 10.20 T&est.B&ar<Tab>:bar  :echo 'bar'<CR>
  10nmenu <script> 10.30.5 T&est.Ba&z.Qu&x  :echo 'qux'<CR>

  let d = #{name: "B&ar\t:bar", display: 'Bar', modes: 'n', shortcut: 'a',
        \ accel: ':bar', priority: 20, enabled: v:true, silent: v:true,
        \ noremenu: v:false, script: v:false, rhs: ":echo 'bar'<CR>"}
  call assert_equal(d, menu_info('Test.Bar'))

  let d = #{name: 'Ba&z', display: 'Baz', modes: 'n', shortcut: 'z',
        \ priority: 30, submenus: ['Qux']}
  call assert_equal(d, menu_info('Test.Baz'))

  let d = #{name: 'T&est', display: 'Test', modes: 'n', shortcut: 'e',
        \ priority: 10, submenus: ['Foo', 'Bar', 'Baz']}
  call assert_equal(d, menu_info('Test'))
  call assert_equal({}, menu_info('Test.Dummy'))
  call assert_equal({}, menu_info('Dummy'))

  nmenu disable Test.Foo
  call assert_equal(v:false, menu_info('Test.Foo').enabled)
  nmenu enable Test.Foo
  call assert_equal(v:true, menu_info('Test.Foo').enabled)

  call assert_equal(menu_info('Test.Foo'), menu_info('Test.Foo', ''))
  nmenu Test.abc  <Nop>
  call assert_equal('<Nop>', menu_info('Test.abc').rhs)
  call assert_fails('call menu_info([])', 'E730:')
  call assert_fails('call menu_info("", [])', 'E730:')
  nunmenu Test

  " Test for defining menus in different modes
  menu Test.menu :menu<CR>
  menu! Test.menu! :menu!<CR>
  amenu Test.amenu  :amenu<CR>
  nmenu Test.nmenu  :nmenu<CR>
  omenu Test.omenu  :omenu<CR>
  vmenu Test.vmenu  :vmenu<CR>
  xmenu Test.xmenu  :xmenu<CR>
  smenu Test.smenu  :smenu<CR>
  imenu <silent> <script> Test.imenu  :imenu<CR>
  cmenu Test.cmenu  :cmenu<CR>
  tlmenu Test.tlmenu  :tlmenu<CR>
  tmenu Test.nmenu Normal mode menu
  tmenu Test.omenu Op-pending mode menu
  noremenu Test.noremenu :noremenu<CR>
  noremenu! Test.noremenu! :noremenu!<CR>
  anoremenu Test.anoremenu  :anoremenu<CR>
  nnoremenu Test.nnoremenu  :nnoremenu<CR>
  onoremenu Test.onoremenu  :onoremenu<CR>
  vnoremenu Test.vnoremenu  :vnoremenu<CR>
  xnoremenu Test.xnoremenu  :xnoremenu<CR>
  snoremenu Test.snoremenu  :snoremenu<CR>
  inoremenu <silent> Test.inoremenu  :inoremenu<CR>
  cnoremenu Test.cnoremenu  :cnoremenu<CR>
  tlnoremenu Test.tlnoremenu  :tlnoremenu<CR>
  call assert_equal(#{name: 'menu', priority: 500, shortcut: '',
        \ display: 'menu', modes: ' ', enabled: v:true, silent: v:false,
        \ rhs: ":menu<CR>", noremenu: v:false, script: v:false},
        \ menu_info('Test.menu'))
  call assert_equal(#{name: 'menu!', priority: 500, shortcut: '',
        \ display: 'menu!', modes: '!', enabled: v:true, silent: v:false,
        \ rhs: ":menu!<CR>", noremenu: v:false, script: v:false},
        \ menu_info('Test.menu!', '!'))
  call assert_equal(#{name: 'amenu', priority: 500, shortcut: '',
        \ display: 'amenu', modes: 'a', enabled: v:true, silent: v:false,
        \ rhs: ":amenu<CR>", noremenu: v:false, script: v:false},
        \ menu_info('Test.amenu', 'a'))
  call assert_equal(#{name: 'nmenu', priority: 500, shortcut: '',
        \ display: 'nmenu', modes: 'n', enabled: v:true, silent: v:false,
        \ rhs: ':nmenu<CR>', noremenu: v:false, script: v:false},
        \ menu_info('Test.nmenu', 'n'))
  call assert_equal(#{name: 'omenu', priority: 500, shortcut: '',
        \ display: 'omenu', modes: 'o', enabled: v:true, silent: v:false,
        \ rhs: ':omenu<CR>', noremenu: v:false, script: v:false},
        \ menu_info('Test.omenu', 'o'))
  call assert_equal(#{name: 'vmenu', priority: 500, shortcut: '',
        \ display: 'vmenu', modes: 'v', enabled: v:true, silent: v:false,
        \ rhs: ':vmenu<CR>', noremenu: v:false, script: v:false},
        \ menu_info('Test.vmenu', 'v'))
  call assert_equal(#{name: 'xmenu', priority: 500, shortcut: '',
        \ display: 'xmenu', modes: 'x', enabled: v:true, silent: v:false,
        \ rhs: ':xmenu<CR>', noremenu: v:false, script: v:false},
        \ menu_info('Test.xmenu', 'x'))
  call assert_equal(#{name: 'smenu', priority: 500, shortcut: '',
        \ display: 'smenu', modes: 's', enabled: v:true, silent: v:false,
        \ rhs: ':smenu<CR>', noremenu: v:false, script: v:false},
        \ menu_info('Test.smenu', 's'))
  call assert_equal(#{name: 'imenu', priority: 500, shortcut: '',
        \ display: 'imenu', modes: 'i', enabled: v:true, silent: v:true,
        \ rhs: ':imenu<CR>', noremenu: v:false, script: v:true},
        \ menu_info('Test.imenu', 'i'))
  call assert_equal(#{ name: 'cmenu', priority: 500, shortcut: '',
        \ display: 'cmenu', modes: 'c', enabled: v:true, silent: v:false,
        \ rhs: ':cmenu<CR>', noremenu: v:false, script: v:false},
        \ menu_info('Test.cmenu', 'c'))
  call assert_equal(#{name: 'tlmenu', priority: 500, shortcut: '',
        \ display: 'tlmenu', modes: 'tl', enabled: v:true, silent: v:false,
        \ rhs: ':tlmenu<CR>', noremenu: v:false, script: v:false},
        \ menu_info('Test.tlmenu', 'tl'))
  call assert_equal(#{name: 'noremenu', priority: 500, shortcut: '',
        \ display: 'noremenu', modes: ' ', enabled: v:true, silent: v:false,
        \ rhs: ":noremenu<CR>", noremenu: v:true, script: v:false},
        \ menu_info('Test.noremenu'))
  call assert_equal(#{name: 'noremenu!', priority: 500, shortcut: '',
        \ display: 'noremenu!', modes: '!', enabled: v:true, silent: v:false,
        \ rhs: ":noremenu!<CR>", noremenu: v:true, script: v:false},
        \ menu_info('Test.noremenu!', '!'))
  call assert_equal(#{name: 'anoremenu', priority: 500, shortcut: '',
        \ display: 'anoremenu', modes: 'a', enabled: v:true, silent: v:false,
        \ rhs: ":anoremenu<CR>", noremenu: v:true, script: v:false},
        \ menu_info('Test.anoremenu', 'a'))
  call assert_equal(#{name: 'nnoremenu', priority: 500, shortcut: '',
        \ display: 'nnoremenu', modes: 'n', enabled: v:true, silent: v:false,
        \ rhs: ':nnoremenu<CR>', noremenu: v:true, script: v:false},
        \ menu_info('Test.nnoremenu', 'n'))
  call assert_equal(#{name: 'onoremenu', priority: 500, shortcut: '',
        \ display: 'onoremenu', modes: 'o', enabled: v:true, silent: v:false,
        \ rhs: ':onoremenu<CR>', noremenu: v:true, script: v:false},
        \ menu_info('Test.onoremenu', 'o'))
  call assert_equal(#{name: 'vnoremenu', priority: 500, shortcut: '',
        \ display: 'vnoremenu', modes: 'v', enabled: v:true, silent: v:false,
        \ rhs: ':vnoremenu<CR>', noremenu: v:true, script: v:false},
        \ menu_info('Test.vnoremenu', 'v'))
  call assert_equal(#{name: 'xnoremenu', priority: 500, shortcut: '',
        \ display: 'xnoremenu', modes: 'x', enabled: v:true, silent: v:false,
        \ rhs: ':xnoremenu<CR>', noremenu: v:true, script: v:false},
        \ menu_info('Test.xnoremenu', 'x'))
  call assert_equal(#{name: 'snoremenu', priority: 500, shortcut: '',
        \ display: 'snoremenu', modes: 's', enabled: v:true, silent: v:false,
        \ rhs: ':snoremenu<CR>', noremenu: v:true, script: v:false},
        \ menu_info('Test.snoremenu', 's'))
  call assert_equal(#{name: 'inoremenu', priority: 500, shortcut: '',
        \ display: 'inoremenu', modes: 'i', enabled: v:true, silent: v:true,
        \ rhs: ':inoremenu<CR>', noremenu: v:true, script: v:false},
        \ menu_info('Test.inoremenu', 'i'))
  call assert_equal(#{ name: 'cnoremenu', priority: 500, shortcut: '',
        \ display: 'cnoremenu', modes: 'c', enabled: v:true, silent: v:false,
        \ rhs: ':cnoremenu<CR>', noremenu: v:true, script: v:false},
        \ menu_info('Test.cnoremenu', 'c'))
  call assert_equal(#{name: 'tlnoremenu', priority: 500, shortcut: '',
        \ display: 'tlnoremenu', modes: 'tl', enabled: v:true, silent: v:false,
        \ rhs: ':tlnoremenu<CR>', noremenu: v:true, script: v:false},
        \ menu_info('Test.tlnoremenu', 'tl'))

  " Test for getting all the top-level menu names
  call assert_notequal(menu_info('').submenus, [])

  aunmenu Test
  tlunmenu Test
  call assert_equal({}, menu_info('Test'))
  call assert_equal({}, menu_info('Test', '!'))
  call assert_equal({}, menu_info('Test', 'a'))
  call assert_equal({}, menu_info('Test', 'n'))
  call assert_equal({}, menu_info('Test', 'o'))
  call assert_equal({}, menu_info('Test', 'v'))
  call assert_equal({}, menu_info('Test', 'x'))
  call assert_equal({}, menu_info('Test', 's'))
  call assert_equal({}, menu_info('Test', 'i'))
  call assert_equal({}, menu_info('Test', 'c'))
  call assert_equal({}, menu_info('Test', 't'))
  call assert_equal({}, menu_info('Test', 'tl'))

  amenu Test.amenu  :amenu<CR>
  call assert_equal(':amenu<CR>', menu_info('Test.amenu', '').rhs)
  call assert_equal('<C-\><C-O>:amenu<CR>', menu_info('Test.amenu', '!').rhs)
  call assert_equal(':amenu<CR>', menu_info('Test.amenu', 'n').rhs)
  call assert_equal('<C-C>:amenu<CR><C-\><C-G>',
        \ menu_info('Test.amenu', 'o').rhs)
  call assert_equal('<C-C>:amenu<CR><C-\><C-G>',
        \ menu_info('Test.amenu', 'v').rhs)
  call assert_equal('<C-C>:amenu<CR><C-\><C-G>',
        \ menu_info('Test.amenu', 'x').rhs)
  call assert_equal('<C-C>:amenu<CR><C-\><C-G>',
        \ menu_info('Test.amenu', 's').rhs)
  call assert_equal('<C-\><C-O>:amenu<CR>', menu_info('Test.amenu', 'i').rhs)
  call assert_equal('<C-C>:amenu<CR><C-\><C-G>',
        \ menu_info('Test.amenu', 'c').rhs)
  aunmenu Test.amenu

  " Test for hidden menus
  menu ]Test.menu :menu<CR>
  call assert_equal(#{name: ']Test', display: ']Test', priority: 500,
        \ shortcut: '', modes: ' ', submenus: ['menu']},
        \ menu_info(']Test'))
  unmenu ]Test
endfunc

" Test for <special> keyword in a menu with 'cpo' containing '<'
func Test_menu_special()
  throw 'Skipped: Nvim does not support cpoptions flag "<"'
  new
  set cpo+=<
  nmenu Test.Sign  am<Tab>n<Esc>
  call feedkeys(":emenu n Test.Sign\<CR>", 'x')
  call assert_equal("m<Tab>n<Esc>", getline(1))
  nunmenu Test.Sign
  nmenu <special> Test.Sign  am<Tab>n<Esc>
  call setline(1, '')
  call feedkeys(":emenu n Test.Sign\<CR>", 'x')
  call assert_equal("m\tn", getline(1))
  set cpo-=<
  close!
  nunmenu Test.Sign
endfunc

" Test for "icon=filename" in a toolbar
func Test_menu_icon()
  CheckFeature toolbar
  nmenu icon=myicon.xpm Toolbar.Foo  :echo "Foo"<CR>
  call assert_equal('myicon.xpm', "Toolbar.Foo"->menu_info().icon)
  nunmenu Toolbar.Foo

  " Test for using the builtin icon
  amenu ToolBar.BuiltIn22 :echo "BuiltIn22"<CR>
  call assert_equal(#{name: 'BuiltIn22', display: 'BuiltIn22',
        \ enabled: v:true, shortcut: '', modes: 'a', script: v:false,
        \ iconidx: 22, priority: 500, silent: v:false,
        \ rhs: ':echo "BuiltIn22"<CR>', noremenu: v:false},
        \ menu_info("ToolBar.BuiltIn22"))
  aunmenu ToolBar.BuiltIn22
endfunc

" Test for ":emenu" command in different modes
func Test_emenu_cmd()
  new
  xmenu Test.foo rx
  call setline(1, ['aaaa', 'bbbb'])
  normal ggVj
  %emenu Test.foo
  call assert_equal(['xxxx', 'xxxx'], getline(1, 2))
  call setline(1, ['aaaa', 'bbbb'])
  exe "normal ggVj\<Esc>"
  %emenu Test.foo
  call assert_equal(['xxxx', 'xxxx'], getline(1, 2))
  call setline(1, ['aaaa', 'bbbb'])
  exe "normal ggV\<Esc>"
  2emenu Test.foo
  call assert_equal(['aaaa', 'xxxx'], getline(1, 2))
  xunmenu Test.foo
  close!
endfunc

" Test for PopUp menus
func Test_popup_menu()
  20menu PopUp.foo :echo 'foo'<CR>
  20menu PopUp.bar :echo 'bar'<CR>
  call assert_equal(#{name: 'PopUp', display: 'PopUp', priority: 20,
        \ shortcut: '', modes: ' ', submenus: ['foo', 'bar']},
        \ menu_info('PopUp'))
  menu disable PopUp.bar
  call assert_equal(v:true, "PopUp.foo"->menu_info().enabled)
  call assert_equal(v:false, "PopUp.bar"->menu_info().enabled)
  menu enable PopUp.bar
  call assert_equal(v:true, "PopUp.bar"->menu_info().enabled)
  unmenu PopUp
endfunc

func Test_popup_menu_truncated()
  CheckNotGui

  set mouse=a mousemodel=popup
  aunmenu PopUp
  for i in range(2 * &lines)
    exe $'menu PopUp.{i} <Cmd>let g:res = {i}<CR>'
  endfor

  func LeftClickExpr(row, col)
    call Ntest_setmouse(a:row, a:col)
    return "\<LeftMouse>"
  endfunc

  " Clicking at the bottom should place popup menu above click position.
  " <RightRelease> should not select an item immediately.
  let g:res = -1
  call Ntest_setmouse(&lines, 1)
  nnoremap <expr><F2> LeftClickExpr(4, 1)
  call feedkeys("\<RightMouse>\<RightRelease>\<F2>", 'tx')
  call assert_equal(3, g:res)

  " Clicking at the top should place popup menu below click position.
  let g:res = -1
  call Ntest_setmouse(1, 1)
  nnoremap <expr><F2> LeftClickExpr(5, 1)
  call feedkeys("\<RightMouse>\<RightRelease>\<F2>", 'tx')
  call assert_equal(3, g:res)

  nunmap <F2>
  delfunc LeftClickExpr
  unlet g:res
  aunmenu PopUp
  set mouse& mousemodel&
endfunc

" Test for MenuPopup autocommand
func Test_autocmd_MenuPopup()
  CheckNotGui

  set mouse=a mousemodel=popup
  aunmenu PopUp
  autocmd MenuPopup * exe printf(
    \ 'anoremenu PopUp.Foo <Cmd>let g:res = ["%s", "%s"]<CR>',
    \ expand('<afile>'), expand('<amatch>'))

  call feedkeys("\<RightMouse>\<Down>\<CR>", 'tnix')
  call assert_equal(['n', 'n'], g:res)

  call feedkeys("v\<RightMouse>\<Down>\<CR>\<Esc>", 'tnix')
  call assert_equal(['v', 'v'], g:res)

  call feedkeys("gh\<RightMouse>\<Down>\<CR>\<Esc>", 'tnix')
  call assert_equal(['s', 's'], g:res)

  call feedkeys("i\<RightMouse>\<Down>\<CR>\<Esc>", 'tnix')
  call assert_equal(['i', 'i'], g:res)

  autocmd! MenuPopup
  aunmenu PopUp.Foo
  unlet g:res
  set mouse& mousemodel&
endfunc

" Test for listing the menus using the :menu command
func Test_show_menus()
  " In the GUI, tear-off menu items are present in the output below
  " So skip this test
  CheckNotGui
  aunmenu *
  call assert_equal(['--- Menus ---'], split(execute('menu'), "\n"))
  nmenu <script> 200.10 Test.nmenu1 :nmenu1<CR>
  nmenu 200.20 Test.nmenu2 :nmenu2<CR>
  nnoremenu 200.30 Test.nmenu3 :nmenu3<CR>
  nmenu 200.40 Test.nmenu4 :nmenu4<CR>
  nmenu 200.50 disable Test.nmenu4
  let exp =<< trim [TEXT]
  --- Menus ---
  200 Test
    10 nmenu1
        n&   :nmenu1<CR>
    20 nmenu2
        n    :nmenu2<CR>
    30 nmenu3
        n*   :nmenu3<CR>
    40 nmenu4
        n  - :nmenu4<CR>
  [TEXT]
  call assert_equal(exp, split(execute('nmenu'), "\n"))
  nunmenu Test
endfunc

" Test for menu tips
func Test_tmenu()
  tunmenu *
  call assert_equal(['--- Menus ---'], split(execute('tmenu'), "\n"))
  tmenu Test.nmenu1 nmenu1
  tmenu Test.nmenu2.sub1 nmenu2.sub1
  let exp =<< trim [TEXT]
  --- Menus ---
  500 Test
    500 nmenu1
        t  - nmenu1
    500 nmenu2
      500 sub1
          t  - nmenu2.sub1
  [TEXT]
  call assert_equal(exp, split(execute('tmenu'), "\n"))
  tunmenu Test
endfunc

func Test_only_modifier()
  exe "tmenu a.b \x80\xfc0"
  let exp =<< trim [TEXT]
  --- Menus ---
  500 a
    500 b
        t  - <T-2-^@>
  [TEXT]
  call assert_equal(exp, split(execute('tmenu'), "\n"))

  tunmenu a.b
endfunc

" vim: shiftwidth=2 sts=2 expandtab
