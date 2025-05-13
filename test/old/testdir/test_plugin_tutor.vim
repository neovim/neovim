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
