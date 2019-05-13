func Test_modeline_invalid()
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

func s:modeline_fails(what, text)
  let fname = "Xmodeline_fails_" . a:what
  call writefile(['vim: set ' . a:text . ' :', 'nothing'], fname)
  let modeline = &modeline
  set modeline
  filetype plugin on
  syntax enable
  call assert_fails('split ' . fname, 'E474:')
  call assert_equal("", &filetype)
  call assert_equal("", &syntax)

  bwipe!
  call delete(fname)
  let &modeline = modeline
  filetype plugin off
  syntax off
endfunc

func Test_modeline_filetype_fails()
  call s:modeline_fails('filetype', 'ft=evil$CMD')
endfunc

func Test_modeline_syntax_fails()
  call s:modeline_fails('syntax', 'syn=evil$CMD')
endfunc

func Test_modeline_keymap_fails()
  call s:modeline_fails('keymap', 'keymap=evil$CMD')
endfunc
