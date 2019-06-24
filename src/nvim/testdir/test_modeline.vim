" Tests for parsing the modeline.

func Test_modeline_invalid()
  " This was reading allocated memory in the past.
  call writefile(['vi:0', 'nothing'], 'Xmodeline')
  let modeline = &modeline
  set modeline
  call assert_fails('set Xmodeline', 'E518:')

  let &modeline = modeline
  bwipe!
  call delete('Xmodeline')
 endfunc

func Test_modeline_filetype()
  call writefile(['vim: set ft=c :', 'nothing'], 'Xmodeline_filetype')
  let modeline = &modeline
  set modeline
  filetype plugin on
  split Xmodeline_filetype
  call assert_equal("c", &filetype)
  call assert_equal(1, b:did_ftplugin)
  call assert_equal("ccomplete#Complete", &ofu)

  bwipe!
  call delete('Xmodeline_filetype')
  let &modeline = modeline
  filetype plugin off
endfunc

func Test_modeline_syntax()
  call writefile(['vim: set syn=c :', 'nothing'], 'Xmodeline_syntax')
  let modeline = &modeline
  set modeline
  syntax enable
  split Xmodeline_syntax
  call assert_equal("c", &syntax)
  call assert_equal("c", b:current_syntax)

  bwipe!
  call delete('Xmodeline_syntax')
  let &modeline = modeline
  syntax off
endfunc

func Test_modeline_keymap()
  if !has('keymap')
    return
  endif
  call writefile(['vim: set keymap=greek :', 'nothing'], 'Xmodeline_keymap')
  let modeline = &modeline
  set modeline
  split Xmodeline_keymap
  call assert_equal("greek", &keymap)
  call assert_match('greek\|grk', b:keymap_name)

  bwipe!
  call delete('Xmodeline_keymap')
  let &modeline = modeline
  set keymap= iminsert=0 imsearch=-1
endfunc

func s:modeline_fails(what, text, error)
  if !exists('+' . a:what)
    return
  endif
  let fname = "Xmodeline_fails_" . a:what
  call writefile(['vim: set ' . a:text . ' :', 'nothing'], fname)
  let modeline = &modeline
  set modeline
  filetype plugin on
  syntax enable
  call assert_fails('split ' . fname, a:error)
  call assert_equal("", &filetype)
  call assert_equal("", &syntax)

  bwipe!
  call delete(fname)
  let &modeline = modeline
  filetype plugin off
  syntax off
endfunc

func Test_modeline_filetype_fails()
  call s:modeline_fails('filetype', 'ft=evil$CMD', 'E474:')
endfunc

func Test_modeline_syntax_fails()
  call s:modeline_fails('syntax', 'syn=evil$CMD', 'E474:')
endfunc

func Test_modeline_keymap_fails()
  call s:modeline_fails('keymap', 'keymap=evil$CMD', 'E474:')
endfunc

func Test_modeline_fails_always()
  call s:modeline_fails('backupdir', 'backupdir=Something()', 'E520:')
  call s:modeline_fails('cdpath', 'cdpath=Something()', 'E520:')
  call s:modeline_fails('charconvert', 'charconvert=Something()', 'E520:')
  call s:modeline_fails('completefunc', 'completefunc=Something()', 'E520:')
  call s:modeline_fails('cscopeprg', 'cscopeprg=Something()', 'E520:')
  call s:modeline_fails('diffexpr', 'diffexpr=Something()', 'E520:')
  call s:modeline_fails('directory', 'directory=Something()', 'E520:')
  call s:modeline_fails('equalprg', 'equalprg=Something()', 'E520:')
  call s:modeline_fails('errorfile', 'errorfile=Something()', 'E520:')
  call s:modeline_fails('exrc', 'exrc=Something()', 'E520:')
  call s:modeline_fails('formatprg', 'formatprg=Something()', 'E520:')
  call s:modeline_fails('fsync', 'fsync=Something()', 'E520:')
  call s:modeline_fails('grepprg', 'grepprg=Something()', 'E520:')
  call s:modeline_fails('helpfile', 'helpfile=Something()', 'E520:')
  call s:modeline_fails('imactivatefunc', 'imactivatefunc=Something()', 'E520:')
  call s:modeline_fails('imstatusfunc', 'imstatusfunc=Something()', 'E520:')
  call s:modeline_fails('imstyle', 'imstyle=Something()', 'E520:')
  call s:modeline_fails('keywordprg', 'keywordprg=Something()', 'E520:')
  call s:modeline_fails('langmap', 'langmap=Something()', 'E520:')
  call s:modeline_fails('luadll', 'luadll=Something()', 'E520:')
  call s:modeline_fails('makeef', 'makeef=Something()', 'E520:')
  call s:modeline_fails('makeprg', 'makeprg=Something()', 'E520:')
  call s:modeline_fails('mkspellmem', 'mkspellmem=Something()', 'E520:')
  call s:modeline_fails('mzschemedll', 'mzschemedll=Something()', 'E520:')
  call s:modeline_fails('mzschemegcdll', 'mzschemegcdll=Something()', 'E520:')
  call s:modeline_fails('modelineexpr', 'modelineexpr=Something()', 'E520:')
  call s:modeline_fails('omnifunc', 'omnifunc=Something()', 'E520:')
  call s:modeline_fails('operatorfunc', 'operatorfunc=Something()', 'E520:')
  call s:modeline_fails('perldll', 'perldll=Something()', 'E520:')
  call s:modeline_fails('printdevice', 'printdevice=Something()', 'E520:')
  call s:modeline_fails('patchexpr', 'patchexpr=Something()', 'E520:')
  call s:modeline_fails('printexpr', 'printexpr=Something()', 'E520:')
  call s:modeline_fails('pythondll', 'pythondll=Something()', 'E520:')
  call s:modeline_fails('pythonhome', 'pythonhome=Something()', 'E520:')
  call s:modeline_fails('pythonthreedll', 'pythonthreedll=Something()', 'E520:')
  call s:modeline_fails('pythonthreehome', 'pythonthreehome=Something()', 'E520:')
  call s:modeline_fails('pyxversion', 'pyxversion=Something()', 'E520:')
  call s:modeline_fails('rubydll', 'rubydll=Something()', 'E520:')
  call s:modeline_fails('runtimepath', 'runtimepath=Something()', 'E520:')
  call s:modeline_fails('secure', 'secure=Something()', 'E520:')
  call s:modeline_fails('shell', 'shell=Something()', 'E520:')
  call s:modeline_fails('shellcmdflag', 'shellcmdflag=Something()', 'E520:')
  call s:modeline_fails('shellpipe', 'shellpipe=Something()', 'E520:')
  call s:modeline_fails('shellquote', 'shellquote=Something()', 'E520:')
  call s:modeline_fails('shellredir', 'shellredir=Something()', 'E520:')
  call s:modeline_fails('shellxquote', 'shellxquote=Something()', 'E520:')
  call s:modeline_fails('spellfile', 'spellfile=Something()', 'E520:')
  call s:modeline_fails('spellsuggest', 'spellsuggest=Something()', 'E520:')
  call s:modeline_fails('tcldll', 'tcldll=Something()', 'E520:')
  call s:modeline_fails('titleold', 'titleold=Something()', 'E520:')
  call s:modeline_fails('viewdir', 'viewdir=Something()', 'E520:')
  call s:modeline_fails('viminfo', 'viminfo=Something()', 'E520:')
  call s:modeline_fails('viminfofile', 'viminfofile=Something()', 'E520:')
  call s:modeline_fails('winptydll', 'winptydll=Something()', 'E520:')
  call s:modeline_fails('undodir', 'undodir=Something()', 'E520:')
  " only check a few terminal options
  " Skip these since nvim doesn't support termcodes as options
  "call s:modeline_fails('t_AB', 't_AB=Something()', 'E520:')
  "call s:modeline_fails('t_ce', 't_ce=Something()', 'E520:')
  "call s:modeline_fails('t_sr', 't_sr=Something()', 'E520:')
  "call s:modeline_fails('t_8b', 't_8b=Something()', 'E520:')
endfunc

func Test_modeline_fails_modelineexpr()
  call s:modeline_fails('balloonexpr', 'balloonexpr=Something()', 'E992:')
  call s:modeline_fails('foldexpr', 'foldexpr=Something()', 'E992:')
  call s:modeline_fails('foldtext', 'foldtext=Something()', 'E992:')
  call s:modeline_fails('formatexpr', 'formatexpr=Something()', 'E992:')
  call s:modeline_fails('guitablabel', 'guitablabel=Something()', 'E992:')
  call s:modeline_fails('iconstring', 'iconstring=Something()', 'E992:')
  call s:modeline_fails('includeexpr', 'includeexpr=Something()', 'E992:')
  call s:modeline_fails('indentexpr', 'indentexpr=Something()', 'E992:')
  call s:modeline_fails('rulerformat', 'rulerformat=Something()', 'E992:')
  call s:modeline_fails('statusline', 'statusline=Something()', 'E992:')
  call s:modeline_fails('tabline', 'tabline=Something()', 'E992:')
  call s:modeline_fails('titlestring', 'titlestring=Something()', 'E992:')
endfunc
