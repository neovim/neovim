" Test for the new-tutor plugin

source screendump.vim
source check.vim
source script_util.vim

func SetUp()
  set nocompatible
  runtime plugin/tutor.vim
endfunc

func Test_auto_enable_interactive()
  Tutor
  call assert_equal('nofile', &buftype)
  call assert_match('tutor#EnableInteractive', b:undo_ftplugin)

  edit Xtutor/Xtest.tutor
  call assert_true(empty(&buftype))
  call assert_match('tutor#EnableInteractive', b:undo_ftplugin)
endfunc

func Test_tutor_link()
  let tutor_files = globpath($VIMRUNTIME, 'tutor/**/*.tutor', 0, 1)
  let pattern = '\[.\{-}@tutor:\zs[^)\]]*\ze[)\]]'

  for tutor_file in tutor_files
    let lang = fnamemodify(tutor_file, ':h:t')
    if lang == 'tutor'
      let lang = 'en'
    endif

    let text = readfile(tutor_file)
    let links = matchstrlist(text, pattern)->map({_, v -> v.text})
    for link in links
      call assert_true(tutor#GlobTutorials(link, lang)->len() > 0)
    endfor
  endfor
endfunc

func Test_mark()
  CheckScreendump
  call writefile([
  \ 'set nocompatible',
  \ 'runtime plugin/tutor.vim',
  \ 'Tutor tutor',
  \ 'set statusline=',
  \ ], 'Xtest_plugin_tutor_mark', 'D')
  let buf = RunVimInTerminal('-S Xtest_plugin_tutor_mark', {'rows': 20, 'cols': 78})
  call term_sendkeys(buf, ":240\<CR>")
  call WaitForAssert({-> assert_match('Bot$', term_getline(buf, 20))})
  call VerifyScreenDump(buf, 'Test_plugin_tutor_mark_1', {})

  " clean up
  call StopVimInTerminal(buf)
endfunc
