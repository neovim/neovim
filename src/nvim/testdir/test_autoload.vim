" Tests for autoload

set runtimepath=./sautest

func Test_autoload_dict_func()
  let g:loaded_foo_vim = 0
  let g:called_foo_bar_echo = 0
  call g:foo#bar.echo()
  call assert_equal(1, g:loaded_foo_vim)
  call assert_equal(1, g:called_foo_bar_echo)
endfunc

func Test_source_autoload()
  let g:loaded_sourced_vim = 0
  source sautest/autoload/sourced.vim
  call assert_equal(1, g:loaded_sourced_vim)
endfunc
