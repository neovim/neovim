" Test spell checking

source check.vim
CheckFeature spell

" Test spellbadword() with argument, specifically to move to "rare" words
" in normal mode.
func Test_spellrareword()
  set spell

  " Create a small word list to test that spellbadword('...')
  " can return ['...', 'rare'].
  let lines =<< trim END
     foo
     foobar/?
     foobara/?
END
   call writefile(lines, 'Xwords', 'D')

   mkspell! Xwords.spl Xwords
   set spelllang=Xwords.spl
   call assert_equal(['foobar', 'rare'], spellbadword('foo foobar'))

  new
  call setline(1, ['foo', '', 'foo bar foo bar foobara foo foo foo foobar', '', 'End'])
  set spell wrapscan
  normal ]s
  call assert_equal('foo', expand('<cword>'))
  normal ]s
  call assert_equal('bar', expand('<cword>'))

  normal ]r
  call assert_equal('foobara', expand('<cword>'))
  normal ]r
  call assert_equal('foobar', expand('<cword>'))
  normal ]r
  call assert_equal('foobara', expand('<cword>'))
  normal 2]r
  call assert_equal('foobara', expand('<cword>'))
 
  normal [r
  call assert_equal('foobar', expand('<cword>'))
  normal [r
  call assert_equal('foobara', expand('<cword>'))
  normal [r
  call assert_equal('foobar', expand('<cword>'))
  normal 2[r
  call assert_equal('foobar', expand('<cword>'))

  bwipe!
  set nospell

  call delete('Xwords.spl')
  set spelllang&
  set spell&

  " set 'encoding' to clear the word list
  set encoding=utf-8
endfunc

" vim: shiftwidth=2 sts=2 expandtab
