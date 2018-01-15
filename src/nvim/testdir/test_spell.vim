" Test spell checking
" TODO: move test58 tests here

if !has('spell')
  finish
endif

func Test_wrap_search()
  new
  call setline(1, ['The', '', 'A plong line with two zpelling mistakes', '', 'End'])
  set spell wrapscan
  normal ]s
  call assert_equal('plong', expand('<cword>'))
  normal ]s
  call assert_equal('zpelling', expand('<cword>'))
  normal ]s
  call assert_equal('plong', expand('<cword>'))
  bwipe!
  set nospell
endfunc

func Test_z_equal_on_invalid_utf8_word()
  split
  set spell
  call setline(1, "\xff")
  norm z=
  set nospell
  bwipe!
endfunc

func Test_spellreall()
  new
  set spell
  call assert_fails('spellrepall', 'E752:')
  call setline(1, ['A speling mistake. The same speling mistake.',
  \                'Another speling mistake.'])
  call feedkeys(']s1z=', 'tx')
  call assert_equal('A spelling mistake. The same speling mistake.', getline(1))
  call assert_equal('Another speling mistake.', getline(2))
  spellrepall
  call assert_equal('A spelling mistake. The same spelling mistake.', getline(1))
  call assert_equal('Another spelling mistake.', getline(2))
  call assert_fails('spellrepall', 'E753:')
  set spell&
  bwipe!
endfunc
