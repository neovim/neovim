" Tests for maparg().
" Also test utf8 map with a 0x80 byte.
" Also test mapcheck()

function s:SID()     
  return str2nr(matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$'))
endfun

function Test_maparg()
  new
  set cpo-=<
  set encoding=utf8
  " Test maparg() with a string result
  let sid = s:SID()
  let lnum = expand('<sflnum>')
  map foo<C-V> is<F4>foo
  vnoremap <script> <buffer> <expr> <silent> bar isbar
  call assert_equal("is<F4>foo", maparg('foo<C-V>'))
  call assert_equal({'silent': 0, 'noremap': 0, 'script': 0, 'lhs': 'foo<C-V>',
        \ 'mode': ' ', 'nowait': 0, 'expr': 0, 'sid': sid, 'lnum': lnum + 1,
        \ 'rhs': 'is<F4>foo', 'buffer': 0},
        \ maparg('foo<C-V>', '', 0, 1))
  call assert_equal({'silent': 1, 'noremap': 1, 'script': 1, 'lhs': 'bar', 'mode': 'v',
        \ 'nowait': 0, 'expr': 1, 'sid': sid, 'lnum': lnum + 2,
        \ 'rhs': 'isbar', 'buffer': 1},
        \ 'bar'->maparg('', 0, 1))
  let lnum = expand('<sflnum>')
  map <buffer> <nowait> foo bar
  call assert_equal({'silent': 0, 'noremap': 0, 'script': 0, 'lhs': 'foo', 'mode': ' ',
        \ 'nowait': 1, 'expr': 0, 'sid': sid, 'lnum': lnum + 1, 'rhs': 'bar',
        \ 'buffer': 1},
        \ maparg('foo', '', 0, 1))
  let lnum = expand('<sflnum>')
  tmap baz foo
  call assert_equal({'silent': 0, 'noremap': 0, 'script': 0, 'lhs': 'baz', 'mode': 't',
        \ 'nowait': 0, 'expr': 0, 'sid': sid, 'lnum': lnum + 1, 'rhs': 'foo',
        \ 'buffer': 0},
        \ maparg('baz', 't', 0, 1))

  map abc x<char-114>x
  call assert_equal("xrx", maparg('abc'))
  map abc y<S-char-114>y
  call assert_equal("yRy", maparg('abc'))

  omap { w
  let d = maparg('{', 'o', 0, 1)
  call assert_equal(['{', 'w', 'o'], [d.lhs, d.rhs, d.mode])
  ounmap {

  map abc <Nop>
  call assert_equal("<Nop>", maparg('abc'))
  unmap abc
endfunction

func Test_mapcheck()
  call assert_equal('', mapcheck('a'))
  call assert_equal('', mapcheck('abc'))
  call assert_equal('', mapcheck('ax'))
  call assert_equal('', mapcheck('b'))

  map a something
  call assert_equal('something', mapcheck('a'))
  call assert_equal('something', mapcheck('a', 'n'))
  call assert_equal('', mapcheck('a', 'c'))
  call assert_equal('', mapcheck('a', 'i'))
  call assert_equal('something', 'abc'->mapcheck())
  call assert_equal('something', 'ax'->mapcheck())
  call assert_equal('', mapcheck('b'))
  unmap a

  map ab foobar
  call assert_equal('foobar', mapcheck('a'))
  call assert_equal('foobar', mapcheck('abc'))
  call assert_equal('', mapcheck('ax'))
  call assert_equal('', mapcheck('b'))
  unmap ab

  map abc barfoo
  call assert_equal('barfoo', mapcheck('a'))
  call assert_equal('barfoo', mapcheck('a', 'n', 0))
  call assert_equal('', mapcheck('a', 'n', 1))
  call assert_equal('barfoo', mapcheck('abc'))
  call assert_equal('', mapcheck('ax'))
  call assert_equal('', mapcheck('b'))
  unmap abc

  abbr ab abbrev
  call assert_equal('abbrev', mapcheck('a', 'i', 1))
  call assert_equal('', mapcheck('a', 'n', 1))
  call assert_equal('', mapcheck('a', 'i', 0))
  unabbr ab
endfunc

function Test_range_map()
  new
  " Outside of the range, minimum
  inoremap <Char-0x1040> a
  execute "normal a\u1040\<Esc>"
  " Inside of the range, minimum
  inoremap <Char-0x103f> b
  execute "normal a\u103f\<Esc>"
  " Inside of the range, maximum
  inoremap <Char-0xf03f> c
  execute "normal a\uf03f\<Esc>"
  " Outside of the range, maximum
  inoremap <Char-0xf040> d
  execute "normal a\uf040\<Esc>"
  call assert_equal("abcd", getline(1))
endfunction

" vim: shiftwidth=2 sts=2 expandtab
