" Test for the new-tutor plugin

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
