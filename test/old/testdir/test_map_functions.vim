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
	\ 'rhs': 'is<F4>foo', 'buffer': 0, 'abbr': 0, 'mode_bits': 0x47},
	\ maparg('foo<C-V>', '', 0, 1))
  call assert_equal({'silent': 1, 'noremap': 1, 'script': 1, 'lhs': 'bar',
        \ 'lhsraw': 'bar', 'mode': 'v',
        \ 'nowait': 0, 'expr': 1, 'sid': sid, 'scriptversion': 1,
        \ 'lnum': lnum + 2,
	\ 'rhs': 'isbar', 'buffer': 1, 'abbr': 0, 'mode_bits': 0x42},
        \ 'bar'->maparg('', 0, 1))
  let lnum = expand('<sflnum>')
  map <buffer> <nowait> foo bar
  call assert_equal({'silent': 0, 'noremap': 0, 'script': 0, 'lhs': 'foo',
        \ 'lhsraw': 'foo', 'mode': ' ',
        \ 'nowait': 1, 'expr': 0, 'sid': sid, 'scriptversion': 1,
        \ 'lnum': lnum + 1, 'rhs': 'bar',
	\ 'buffer': 1, 'abbr': 0, 'mode_bits': 0x47},
        \ maparg('foo', '', 0, 1))
  let lnum = expand('<sflnum>')
  tmap baz foo
  call assert_equal({'silent': 0, 'noremap': 0, 'script': 0, 'lhs': 'baz',
        \ 'lhsraw': 'baz', 'mode': 't',
        \ 'nowait': 0, 'expr': 0, 'sid': sid, 'scriptversion': 1,
        \ 'lnum': lnum + 1, 'rhs': 'foo',
        \ 'buffer': 0, 'abbr': 0, 'mode_bits': 0x80},
        \ maparg('baz', 't', 0, 1))
  let lnum = expand('<sflnum>')
  iab A B
  call assert_equal({'silent': 0, 'noremap': 0, 'script': 0, 'lhs': 'A',
        \ 'lhsraw': 'A', 'mode': 'i',
        \ 'nowait': 0, 'expr': 0, 'sid': sid, 'scriptversion': 1,
        \ 'lnum': lnum + 1, 'rhs': 'B',
	\ 'buffer': 0, 'abbr': 1, 'mode_bits': 0x0010},
        \ maparg('A', 'i', 1, 1))
  iuna A

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

func Test_mapset_arg1_dir()
  " This test is mostly about get_map_mode_string.
  " Once the code gets past that, it's common with the 3 arg mapset.

  " GetModes() return list of modes for 'XZ' lhs using maplist.
  " There is one list item per mapping
  func s:GetModes(abbr = v:false)
    return maplist(a:abbr)->filter({_, m -> m.lhs == 'XZ'})
              \ ->mapnew({_, m -> m.mode})
  endfunc

  func s:UnmapAll(lhs)
    const unmap_cmds = [ 'unmap', 'unmap!', 'tunmap', 'lunmap' ]
    for cmd in unmap_cmds
      try | call execute(cmd .. ' ' .. a:lhs) | catch /E31/ | endtry
    endfor
  endfunc

  let tmap = {}

  " some mapset(mode, abbr, dict) tests using get_map_mode_str
  map XZ x
  let tmap = maplist()->filter({_, m -> m.lhs == 'XZ'})[0]->copy()
  " this splits the mapping into 2 mappings
  call mapset('ox', v:false, tmap)
  call assert_equal(2, len(s:GetModes()))
  call mapset('o', v:false, tmap)
  call assert_equal(3, len(s:GetModes()))
  " test that '' acts like ' ', and that the 3 mappings become 1
  call mapset('', v:false, tmap)
  call assert_equal([' '], s:GetModes())
  " dict's mode/abbr are ignored
  call s:UnmapAll('XZ')
  let tmap.mode = '!'
  let tmap.abbr = v:true
  call mapset('o', v:false, tmap)
  call assert_equal(['o'], s:GetModes())

  " test the 3 arg version handles bad mode string, dict not used
  call assert_fails("call mapset('vi', v:false, {})", 'E1276:')


  " get the abbreviations out of the way
  abbreviate XZ ZX
  let tmap = maplist(v:true)->filter({_, m -> m.lhs == 'XZ'})[0]->copy()

  abclear
  " 'ic' is the default ab command, shows up as '!'
  let tmap.mode = 'ic'
  call mapset(tmap)
  call assert_equal(['!'], s:GetModes(v:true))

  abclear
  let tmap.mode = 'i'
  call mapset(tmap)
  call assert_equal(['i'], s:GetModes(v:true))

  abclear
  let tmap.mode = 'c'
  call mapset(tmap)
  call assert_equal(['c'], s:GetModes(v:true))

  abclear
  let tmap.mode = '!'
  call mapset(tmap)
  call assert_equal(['!'], s:GetModes(v:true))

  call assert_fails("call mapset(#{mode: ' !', abbr: 1})", 'E1276:')
  call assert_fails("call mapset(#{mode: 'cl', abbr: 1})", 'E1276:')
  call assert_fails("call mapset(#{mode: 'in', abbr: 1})", 'E1276:')

  " the map commands
  map XZ x
  let tmap = maplist()->filter({_, m -> m.lhs == 'XZ'})[0]->copy()

  " try the combos
  call s:UnmapAll('XZ')
  " 'nxso' is ' ', the unadorned :map
  let tmap.mode = 'nxso'
  call mapset(tmap)
  call assert_equal([' '], s:GetModes())

  cal s:UnmapAll('XZ')
  " 'ic' is '!'
  let tmap.mode = 'ic'
  call mapset(tmap)
  call assert_equal(['!'], s:GetModes())

  call s:UnmapAll('XZ')
  " 'xs' is really 'v'
  let tmap.mode = 'xs'
  call mapset(tmap)
  call assert_equal(['v'], s:GetModes())

  " try the individual modes
  call s:UnmapAll('XZ')
  let tmap.mode = 'n'
  call mapset(tmap)
  call assert_equal(['n'], s:GetModes())

  call s:UnmapAll('XZ')
  let tmap.mode = 'x'
  call mapset(tmap)
  call assert_equal(['x'], s:GetModes())

  call s:UnmapAll('XZ')
  let tmap.mode = 's'
  call mapset(tmap)
  call assert_equal(['s'], s:GetModes())

  call s:UnmapAll('XZ')
  let tmap.mode = 'o'
  call mapset(tmap)
  call assert_equal(['o'], s:GetModes())

  call s:UnmapAll('XZ')
  let tmap.mode = 'i'
  call mapset(tmap)
  call assert_equal(['i'], s:GetModes())

  call s:UnmapAll('XZ')
  let tmap.mode = 'c'
  call mapset(tmap)
  call assert_equal(['c'], s:GetModes())

  call s:UnmapAll('XZ')
  let tmap.mode = 't'
  call mapset(tmap)
  call assert_equal(['t'], s:GetModes())

  call s:UnmapAll('XZ')
  let tmap.mode = 'l'
  call mapset(tmap)
  call assert_equal(['l'], s:GetModes())

  call s:UnmapAll('XZ')

  " get errors for modes that can't be in one mapping
  call assert_fails("call mapset(#{mode: 'nxsoi', abbr: 0})", 'E1276:')
  call assert_fails("call mapset(#{mode: ' !', abbr: 0})", 'E1276:')
  call assert_fails("call mapset(#{mode: 'ix', abbr: 0})", 'E1276:')
  call assert_fails("call mapset(#{mode: 'tl', abbr: 0})", 'E1276:')
  call assert_fails("call mapset(#{mode: ' l', abbr: 0})", 'E1276:')
  call assert_fails("call mapset(#{mode: ' t', abbr: 0})", 'E1276:')
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
  " Except for "map dup", because maparg returns the <buffer> version
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
