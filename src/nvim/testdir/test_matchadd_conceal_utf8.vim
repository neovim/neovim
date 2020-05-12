" Test for matchadd() and conceal feature using utf-8.
if !has('conceal')
  finish
endif

function! s:screenline(lnum) abort
  let line = []
  for c in range(1, winwidth(0))
    call add(line, nr2char(screenchar(a:lnum, c)))
  endfor
  return s:trim(join(line, ''))
endfunction

function! s:trim(str) abort
  return matchstr(a:str,'^\s*\zs.\{-}\ze\s*$')
endfunction

function! Test_match_using_multibyte_conceal_char()
  new
  setlocal concealcursor=n conceallevel=1

  1put='# This is a Test'
  "             1234567890123456
  let expect = '#ˑThisˑisˑaˑTest'

  call cursor(1, 1)
  call matchadd('Conceal', '\%2l ', 20, -1, {'conceal': "\u02d1"})
  redraw!

  let lnum = 2
  call assert_equal(expect, s:screenline(lnum))
  call assert_notequal(screenattr(lnum, 1), screenattr(lnum, 2))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 7))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 10))
  call assert_equal(screenattr(lnum, 2), screenattr(lnum, 12))
  call assert_equal(screenattr(lnum, 1), screenattr(lnum, 16))

  quit!
endfunction
