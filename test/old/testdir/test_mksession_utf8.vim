" Test for :mksession, :mkview and :loadview in utf-8 encoding

set encoding=utf-8
scriptencoding utf-8

source check.vim
CheckFeature mksession

func Test_mksession_utf8()
  tabnew
  let wrap_save = &wrap
  set sessionoptions=buffers splitbelow fileencoding=utf-8
  call setline(1, [
    \   'start:',
    \   'no multibyte chAracter',
    \   '	one leaDing tab',
    \   '    four leadinG spaces',
    \   'two		consecutive tabs',
    \   'two	tabs	in one line',
    \   'one … multibyteCharacter',
    \   'a “b” two multiByte characters',
    \   '“c”1€ three mulTibyte characters'
    \ ])
  let tmpfile = tempname()
  exec 'w! ' . tmpfile
  /^start:
  set wrap
  vsplit
  norm! j16|
  split
  norm! j16|
  split
  norm! j16|
  split
  norm! j8|
  split
  norm! j8|
  split
  norm! j16|
  split
  norm! j16|
  split
  norm! j16|
  wincmd l

  set nowrap
  /^start:
  norm! j16|3zl
  split
  norm! j016|3zl
  split
  norm! j016|3zl
  split
  norm! j08|3zl
  split
  norm! j08|3zl
  split
  norm! j016|3zl
  split
  norm! j016|3zl
  split
  norm! j016|3zl
  split
  call wincol()
  mksession! test_mks.out
  let li = filter(readfile('test_mks.out'), 'v:val =~# "\\(^ *normal! 0\\|^ *exe ''normal!\\)"')
  let expected =<< trim [DATA]
    normal! 016|
    normal! 016|
    normal! 016|
    normal! 08|
    normal! 08|
    normal! 016|
    normal! 016|
    normal! 016|
      exe 'normal! ' . s:c . '|zs' . 16 . '|'
      normal! 016|
      exe 'normal! ' . s:c . '|zs' . 16 . '|'
      normal! 016|
      exe 'normal! ' . s:c . '|zs' . 16 . '|'
      normal! 016|
      exe 'normal! ' . s:c . '|zs' . 8 . '|'
      normal! 08|
      exe 'normal! ' . s:c . '|zs' . 8 . '|'
      normal! 08|
      exe 'normal! ' . s:c . '|zs' . 16 . '|'
      normal! 016|
      exe 'normal! ' . s:c . '|zs' . 16 . '|'
      normal! 016|
      exe 'normal! ' . s:c . '|zs' . 16 . '|'
      normal! 016|
      exe 'normal! ' . s:c . '|zs' . 16 . '|'
      normal! 016|
  [DATA]

  call assert_equal(expected, li)
  tabclose!

  call delete('test_mks.out')
  call delete(tmpfile)
  let &wrap = wrap_save
  set sessionoptions& splitbelow& fileencoding&
endfunc

func Test_session_multibyte_mappings()
  " some characters readily available on european keyboards,
  " as well as characters containing 0x80 or 0x9b bytes
  let entries = [
        \ ['n', 'ç', 'ç'],
        \ ['n', 'º', 'º'],
        \ ['n', '¡', '¡'],
        \ ['n', '<M-ç>', '<M-ç>'],
        \ ['n', '<M-º>', '<M-º>'],
        \ ['n', '<M-¡>', '<M-¡>'],
        \ ['n', '…', 'ě'],
        \ ['n', 'ě', '…'],
        \ ['n', '<M-…>', '<M-ě>'],
        \ ['n', '<M-ě>', '<M-…>'],
        \ ]
  for entry in entries
    exe entry[0] .. 'map ' .. entry[1] .. ' ' .. entry[2]
  endfor

  mkvimrc Xtestvimrc

  nmapclear

  for entry in entries
    call assert_equal('', maparg(entry[1], entry[0]))
  endfor

  source Xtestvimrc

  for entry in entries
    call assert_equal(entry[2], maparg(entry[1], entry[0]))
  endfor

  nmapclear

  call delete('Xtestvimrc')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
