" Tests for maparg().
" Also test utf8 map with a 0x80 byte.

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
  call assert_equal({'silent': 0, 'noremap': 0, 'lhs': 'foo<C-V>',
        \ 'mode': ' ', 'nowait': 0, 'expr': 0, 'sid': sid, 'lnum': lnum + 1,
        \ 'rhs': 'is<F4>foo', 'buffer': 0},
        \ maparg('foo<C-V>', '', 0, 1))
  call assert_equal({'silent': 1, 'noremap': 1, 'lhs': 'bar', 'mode': 'v',
        \ 'nowait': 0, 'expr': 1, 'sid': sid, 'lnum': lnum + 2,
        \ 'rhs': 'isbar', 'buffer': 1},
        \ maparg('bar', '', 0, 1))
  let lnum = expand('<sflnum>')
  map <buffer> <nowait> foo bar
  call assert_equal({'silent': 0, 'noremap': 0, 'lhs': 'foo', 'mode': ' ',
        \ 'nowait': 1, 'expr': 0, 'sid': sid, 'lnum': lnum + 1, 'rhs': 'bar',
        \ 'buffer': 1},
        \ maparg('foo', '', 0, 1))
  let lnum = expand('<sflnum>')
  tmap baz foo
  call assert_equal({'silent': 0, 'noremap': 0, 'lhs': 'baz', 'mode': 't',
        \ 'nowait': 0, 'expr': 0, 'sid': sid, 'lnum': lnum + 1, 'rhs': 'foo',
        \ 'buffer': 0},
        \ maparg('baz', 't', 0, 1))

  map abc x<char-114>x
  call assert_equal("xrx", maparg('abc'))
  map abc y<S-char-114>y
  call assert_equal("yRy", maparg('abc'))

  map abc <Nop>
  call assert_equal("<Nop>", maparg('abc'))
  unmap abc
endfunction

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
