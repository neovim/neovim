" Test the :compiler command

source check.vim
source shared.vim

func Test_compiler()
  CheckExecutable perl
  CheckFeature quickfix

  " $LANG changes the output of Perl.
  if $LANG != ''
    unlet $LANG
  endif

  " %:S does not work properly with 'shellslash' set
  let save_shellslash = &shellslash
  set noshellslash

  e Xfoo.pl
  compiler perl
  call assert_equal('perl', b:current_compiler)
  call assert_fails('let g:current_compiler', 'E121:')

  let verbose_efm = execute('verbose set efm')
  call assert_match('Last set from .*[/\\]compiler[/\\]perl.vim ', verbose_efm)

  call setline(1, ['#!/usr/bin/perl -w', 'use strict;', 'my $foo=1'])
  w!
  call feedkeys(":make\<CR>\<CR>", 'tx')
  call assert_fails('clist', 'E42:')

  call setline(1, ['#!/usr/bin/perl -w', 'use strict;', '$foo=1'])
  w!
  call feedkeys(":make\<CR>\<CR>", 'tx')
  let a=execute('clist')
  call assert_match('\n \d\+ Xfoo.pl:3: Global symbol "$foo" '
  \ .               'requires explicit package name', a)


  let &shellslash = save_shellslash
  call delete('Xfoo.pl')
  bw!
endfunc

func GetCompilerNames()
  return glob('$VIMRUNTIME/compiler/*.vim', 0, 1)
       \ ->map({i, v -> substitute(v, '.*[\\/]\([a-zA-Z0-9_\-]*\).vim', '\1', '')})
       \ ->sort()
endfunc

func Test_compiler_without_arg()
  let runtime = substitute($VIMRUNTIME, '\\', '/', 'g')
  let a = split(execute('compiler'))
  let exp = GetCompilerNames()
  call assert_match(runtime .. '/compiler/' .. exp[0] .. '.vim$',  a[0])
  call assert_match(runtime .. '/compiler/' .. exp[1] .. '.vim$',  a[1])
  call assert_match(runtime .. '/compiler/' .. exp[-1] .. '.vim$', a[-1])
endfunc

func Test_compiler_completion()
  let clist = GetCompilerNames()->join(' ')
  call feedkeys(":compiler \<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_match('^"compiler ' .. clist .. '$', @:)

  call feedkeys(":compiler p\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_match('"compiler pbx perl\( p[a-z]\+\)\+ pylint pyunit', @:)

  call feedkeys(":compiler! p\<C-A>\<C-B>\"\<CR>", 'tx')
  call assert_match('"compiler! pbx perl\( p[a-z]\+\)\+ pylint pyunit', @:)
endfunc

func Test_compiler_error()
  let g:current_compiler = 'abc'
  call assert_fails('compiler doesnotexist', 'E666:')
  call assert_equal('abc', g:current_compiler)
  call assert_fails('compiler! doesnotexist', 'E666:')
  unlet! g:current_compiler
endfunc
