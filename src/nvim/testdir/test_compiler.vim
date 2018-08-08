" Test the :compiler command

func Test_compiler()
  if !executable('perl')
    return
  endif

  e Xfoo.pl
  compiler perl
  call assert_equal('perl', b:current_compiler)
  call assert_fails('let g:current_compiler', 'E121:')

  call setline(1, ['#!/usr/bin/perl -w', 'use strict;', 'my $foo=1'])
  w!
  call feedkeys(":make\<CR>\<CR>", 'tx')
  call assert_fails('clist', 'E42:')

  call setline(1, ['#!/usr/bin/perl -w', 'use strict;', '$foo=1'])
  w!
  call feedkeys(":make\<CR>\<CR>", 'tx')
  let a=execute('clist')
  call assert_match("\n 1 Xfoo.pl:3: Global symbol \"\$foo\" "
  \ .               "requires explicit package name", a)

  call delete('Xfoo.pl')
  bw!
endfunc

func Test_compiler_without_arg()
  let a=split(execute('compiler'))
  call assert_match(expand('^.*runtime/compiler/ant.vim$'), a[0])
  call assert_match(expand('^.*runtime/compiler/bcc.vim$'), a[1])
  call assert_match(expand('^.*runtime/compiler/xmlwf.vim$'), a[-1])
endfunc

func Test_compiler_completion()
  call feedkeys(":compiler \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_match('^"compiler ant bcc .* xmlwf$', @:)

  call feedkeys(":compiler p\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"compiler pbx perl php pylint pyunit', @:)

  call feedkeys(":compiler! p\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_equal('"compiler! pbx perl php pylint pyunit', @:)
endfunc

func Test_compiler_error()
  call assert_fails('compiler doesnotexist', 'E666:')
endfunc
