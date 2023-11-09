" Tests for maparg(), mapcheck(), mapset(), maplist()
" Also test utf8 map with a 0x80 byte.

source shared.vim

func s:SID()
  return str2nr(matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$'))
endfunc

func Test_maparg()
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
        \ 'lhsraw': "foo\x80\xfc\x04V", 'lhsrawalt': "foo\x16",
        \ 'mode': ' ', 'nowait': 0, 'expr': 0, 'sid': sid, 'scriptversion': 1,
        \ 'lnum': lnum + 1, 
	\ 'rhs': 'is<F4>foo', 'buffer': 0},
	\ maparg('foo<C-V>', '', 0, 1))
  call assert_equal({'silent': 1, 'noremap': 1, 'script': 1, 'lhs': 'bar',
        \ 'lhsraw': 'bar', 'mode': 'v',
        \ 'nowait': 0, 'expr': 1, 'sid': sid, 'scriptversion': 1,
        \ 'lnum': lnum + 2,
	\ 'rhs': 'isbar', 'buffer': 1},
        \ 'bar'->maparg('', 0, 1))
  let lnum = expand('<sflnum>')
  map <buffer> <nowait> foo bar
  call assert_equal({'silent': 0, 'noremap': 0, 'script': 0, 'lhs': 'foo',
        \ 'lhsraw': 'foo', 'mode': ' ',
        \ 'nowait': 1, 'expr': 0, 'sid': sid, 'scriptversion': 1,
        \ 'lnum': lnum + 1, 'rhs': 'bar',
	\ 'buffer': 1},
        \ maparg('foo', '', 0, 1))
  let lnum = expand('<sflnum>')
  tmap baz foo
  call assert_equal({'silent': 0, 'noremap': 0, 'script': 0, 'lhs': 'baz',
        \ 'lhsraw': 'baz', 'mode': 't',
        \ 'nowait': 0, 'expr': 0, 'sid': sid, 'scriptversion': 1,
        \ 'lnum': lnum + 1, 'rhs': 'foo',
	\ 'buffer': 0},
        \ maparg('baz', 't', 0, 1))

  map abc x<char-114>x
  call assert_equal("xrx", maparg('abc'))
  map abc y<S-char-114>y
  call assert_equal("yRy", maparg('abc'))

  " character with K_SPECIAL byte
  nmap abc …
  call assert_equal('…', maparg('abc'))

  " modified character with K_SPECIAL byte
  nmap abc <M-…>
  call assert_equal('<M-…>', maparg('abc'))

  " illegal bytes
  let str = ":\x7f:\x80:\x90:\xd0:"
  exe 'nmap abc ' .. str
  call assert_equal(str, maparg('abc'))
  unlet str

  omap { w
  let d = maparg('{', 'o', 0, 1)
  call assert_equal(['{', 'w', 'o'], [d.lhs, d.rhs, d.mode])
  ounmap {

  lmap { w
  let d = maparg('{', 'l', 0, 1)
  call assert_equal(['{', 'w', 'l'], [d.lhs, d.rhs, d.mode])
  lunmap {

  nmap { w
  let d = maparg('{', 'n', 0, 1)
  call assert_equal(['{', 'w', 'n'], [d.lhs, d.rhs, d.mode])
  nunmap {

  xmap { w
  let d = maparg('{', 'x', 0, 1)
  call assert_equal(['{', 'w', 'x'], [d.lhs, d.rhs, d.mode])
  xunmap {

  smap { w
  let d = maparg('{', 's', 0, 1)
  call assert_equal(['{', 'w', 's'], [d.lhs, d.rhs, d.mode])
  sunmap {

  map <C-I> foo
  unmap <Tab>
  " This used to cause a segfault
  call maparg('<C-I>', '', 0, 1)
  unmap <C-I>

  map abc <Nop>
  call assert_equal("<Nop>", maparg('abc'))
  unmap abc

  call feedkeys(":abbr esc \<C-V>\<C-V>\<C-V>\<C-V>\<C-V>\<Esc>\<CR>", "xt")
  let d = maparg('esc', 'i', 1, 1)
  call assert_equal(['esc', "\<C-V>\<C-V>\<Esc>", '!'], [d.lhs, d.rhs, d.mode])
  abclear
  unlet d
endfunc

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

func Test_range_map()
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
endfunc

func One_mapset_test(keys, rhs)
  exe 'nnoremap ' .. a:keys .. ' ' .. a:rhs
  let orig = maparg(a:keys, 'n', 0, 1)
  call assert_equal(a:keys, orig.lhs)
  call assert_equal(a:rhs, orig.rhs)
  call assert_equal('n', orig.mode)

  exe 'nunmap ' .. a:keys
  let d = maparg(a:keys, 'n', 0, 1)
  call assert_equal({}, d)

  call mapset('n', 0, orig)
  let d = maparg(a:keys, 'n', 0, 1)
  call assert_equal(a:keys, d.lhs)
  call assert_equal(a:rhs, d.rhs)
  call assert_equal('n', d.mode)

  exe 'nunmap ' .. a:keys
endfunc

func Test_mapset()
  call One_mapset_test('K', 'original<CR>')
  call One_mapset_test('<F3>', 'original<CR>')
  call One_mapset_test('<F3>', '<lt>Nop>')

  " Check <> key conversion
  new
  inoremap K one<Left>x
  call feedkeys("iK\<Esc>", 'xt')
  call assert_equal('onxe', getline(1))

  let orig = maparg('K', 'i', 0, 1)
  call assert_equal('K', orig.lhs)
  call assert_equal('one<Left>x', orig.rhs)
  call assert_equal('i', orig.mode)

  iunmap K
  let d = maparg('K', 'i', 0, 1)
  call assert_equal({}, d)

  call mapset('i', 0, orig)
  call feedkeys("SK\<Esc>", 'xt')
  call assert_equal('onxe', getline(1))

  iunmap K

  " Test that <Nop> is restored properly
  inoremap K <Nop>
  call feedkeys("SK\<Esc>", 'xt')
  call assert_equal('', getline(1))

  let orig = maparg('K', 'i', 0, 1)
  call assert_equal('K', orig.lhs)
  call assert_equal('<Nop>', orig.rhs)
  call assert_equal('i', orig.mode)

  inoremap K foo
  call feedkeys("SK\<Esc>", 'xt')
  call assert_equal('foo', getline(1))

  call mapset('i', 0, orig)
  call feedkeys("SK\<Esc>", 'xt')
  call assert_equal('', getline(1))

  iunmap K

  " Test literal <CR> using a backslash
  let cpo_save = &cpo
  set cpo-=B
  inoremap K one\<CR>two
  call feedkeys("SK\<Esc>", 'xt')
  call assert_equal('one<CR>two', getline(1))

  let orig = maparg('K', 'i', 0, 1)
  call assert_equal('K', orig.lhs)
  call assert_equal('one\<CR>two', orig.rhs)
  call assert_equal('i', orig.mode)

  iunmap K
  let d = maparg('K', 'i', 0, 1)
  call assert_equal({}, d)

  call mapset('i', 0, orig)
  call feedkeys("SK\<Esc>", 'xt')
  call assert_equal('one<CR>two', getline(1))

  iunmap K

  " Test literal <CR> using CTRL-V
  inoremap K one<CR>two
  call feedkeys("SK\<Esc>", 'xt')
  call assert_equal('one<CR>two', getline(1))

  let orig = maparg('K', 'i', 0, 1)
  call assert_equal('K', orig.lhs)
  call assert_equal("one\x16<CR>two", orig.rhs)
  call assert_equal('i', orig.mode)

  iunmap K
  let d = maparg('K', 'i', 0, 1)
  call assert_equal({}, d)

  call mapset('i', 0, orig)
  call feedkeys("SK\<Esc>", 'xt')
  call assert_equal('one<CR>two', getline(1))

  iunmap K
  let &cpo = cpo_save
  bwipe!

  call assert_fails('call mapset([], v:false, {})', 'E730:')
  call assert_fails('call mapset("i", 0, "")', 'E1206:')
  call assert_fails('call mapset("i", 0, {})', 'E460:')
endfunc

func Check_ctrlb_map(d, check_alt)
  call assert_equal('<C-B>', a:d.lhs)
  if a:check_alt
    call assert_equal("\x80\xfc\x04B", a:d.lhsraw)
    call assert_equal("\x02", a:d.lhsrawalt)
  else
    call assert_equal("\x02", a:d.lhsraw)
  endif
endfunc

func Test_map_local()
  nmap a global
  nmap <buffer>a local

  let prev_map_list = split(execute('nmap a'), "\n")
  call assert_match('n\s*a\s*@local', prev_map_list[0])
  call assert_match('n\s*a\s*global', prev_map_list[1])

  let mapping = maparg('a', 'n', 0, 1)
  call assert_equal(1, mapping.buffer)
  let mapping.rhs = 'new_local'
  call mapset('n', 0, mapping)

  " Check that the global mapping is left untouched.
  let map_list = split(execute('nmap a'), "\n")
  call assert_match('n\s*a\s*@new_local', map_list[0])
  call assert_match('n\s*a\s*global', map_list[1])

  nunmap a
endfunc

func Test_map_restore()
  " Test restoring map with alternate keycode
  nmap <C-B> back
  let d = maparg('<C-B>', 'n', 0, 1)
  call Check_ctrlb_map(d, 1)
  let dsimp = maparg("\x02", 'n', 0, 1)
  call Check_ctrlb_map(dsimp, 0)
  nunmap <C-B>
  call mapset('n', 0, d)
  let d = maparg('<C-B>', 'n', 0, 1)
  call Check_ctrlb_map(d, 1)
  let dsimp = maparg("\x02", 'n', 0, 1)
  call Check_ctrlb_map(dsimp, 0)

  nunmap <C-B>
endfunc

" Test restoring an <SID> mapping
func Test_map_restore_sid()
  func RestoreMap()
    const d = maparg('<CR>', 'i', v:false, v:true)
    iunmap <buffer> <CR>
    call mapset('i', v:false, d)
  endfunc

  let mapscript =<< trim [CODE]
    inoremap <silent><buffer> <SID>Return <C-R>=42<CR>
    inoremap <script><buffer> <CR> <CR><SID>Return
  [CODE]
  call writefile(mapscript, 'Xmapscript', 'D')

  new
  source Xmapscript
  inoremap <buffer> <C-B> <Cmd>call RestoreMap()<CR>
  call feedkeys("i\<CR>\<*C-B>\<CR>", 'xt')
  call assert_equal(['', '42', '42'], getline(1, '$'))

  bwipe!
  delfunc RestoreMap
endfunc

" Test restoring a mapping with a negative script ID
func Test_map_restore_negative_sid()
  let after =<< trim [CODE]
    call assert_equal("\tLast set from --cmd argument",
          \ execute('verbose nmap ,n')->trim()->split("\n")[-1])
    let d = maparg(',n', 'n', 0, 1)
    nunmap ,n
    call assert_equal('No mapping found',
          \ execute('verbose nmap ,n')->trim()->split("\n")[-1])
    call mapset('n', 0, d)
    call assert_equal("\tLast set from --cmd argument",
          \ execute('verbose nmap ,n')->trim()->split("\n")[-1])
    call writefile(v:errors, 'Xresult')
    qall!
  [CODE]

  if RunVim([], after, '--clean --cmd "nmap ,n <Nop>"')
    call assert_equal([], readfile('Xresult'))
  endif
  call delete('Xresult')
endfunc

func Test_maplist()
  new
  func s:ClearMappingsAbbreviations()
    mapclear | nmapclear | vmapclear | xmapclear | smapclear | omapclear
    mapclear!  | imapclear | lmapclear | cmapclear | tmapclear
    mapclear <buffer> | nmapclear <buffer> | vmapclear <buffer>
    xmapclear <buffer> | smapclear <buffer> | omapclear <buffer>
    mapclear! <buffer> | imapclear <buffer> | lmapclear <buffer>
    cmapclear <buffer> | tmapclear <buffer>
    abclear | abclear <buffer>
  endfunc

  func s:AddMaps(new, accum)
    if len(a:new) > 0 && a:new[0] != "No mapping found"
      eval a:accum->extend(a:new)
    endif
  endfunc

  call s:ClearMappingsAbbreviations()
  call assert_equal(0, len(maplist()))
  call assert_equal(0, len(maplist(v:true)))

  " Set up some mappings.
  map dup bar
  map <buffer> dup bufbar
  map foo<C-V> is<F4>foo
  vnoremap <script> <buffer> <expr> <silent> bar isbar
  tmap baz foo
  omap h w
  lmap i w
  nmap j w
  xmap k w
  smap l w
  map abc <Nop>
  nmap <M-j> x
  nmap <M-Space> y
  " And abbreviations
  abbreviate xy he
  abbreviate xx she
  abbreviate <buffer> x they

  " Get a list of the mappings with the ':map' commands.
  " Check maplist() return a list of the same size.
  call assert_equal(13, len(maplist()))
  call assert_equal(3, len(maplist(v:true)))
  call assert_equal(13, len(maplist(v:false)))

  " collect all the current maps using :map commands
  let maps_command = []
  call s:AddMaps(split(execute('map'), '\n'), maps_command)
  call s:AddMaps(split(execute('map!'), '\n'), maps_command)
  call s:AddMaps(split(execute('tmap'), '\n'), maps_command)
  call s:AddMaps(split(execute('lmap'), '\n'), maps_command)

  " Use maplist to get all the maps
  let maps_maplist = maplist()
  call assert_equal(len(maps_command), len(maps_maplist))

  " make sure all the mode-lhs are unique, no duplicates
  let map_set = {}
  for d in maps_maplist
    let map_set[d.mode .. "-" .. d.lhs .. "-" .. d.buffer] = 0
  endfor
  call assert_equal(len(maps_maplist), len(map_set))

  " For everything returned by maplist, should be the same as from maparg.
  " Except for "map dup", bacause maparg returns the <buffer> version
  for d in maps_maplist
    if d.lhs == 'dup' && d.buffer == 0
      continue
    endif
    let d_maparg = maparg(d.lhs, d.mode, v:false, v:true)
    call assert_equal(d_maparg, d)
  endfor

  " Check abbr matches maparg
  for d in maplist(v:true)
    " Note, d.mode is '!', but can't use that with maparg
    let d_maparg = maparg(d.lhs, 'i', v:true, v:true)
    call assert_equal(d_maparg, d)
  endfor

  call s:ClearMappingsAbbreviations()
  call assert_equal(0, len(maplist()))
  call assert_equal(0, len(maplist(v:true)))
endfunc


" vim: shiftwidth=2 sts=2 expandtab
