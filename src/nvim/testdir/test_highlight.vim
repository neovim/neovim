" Tests for ":highlight" and highlighting.

source view_util.vim
source screendump.vim
source check.vim
source script_util.vim

func Test_highlight()
  " basic test if ":highlight" doesn't crash
  highlight
  hi Search

  " test setting colors.
  " test clearing one color and all doesn't generate error or warning
  silent! hi NewGroup term=bold cterm=italic ctermfg=DarkBlue ctermbg=Grey gui= guifg=#00ff00 guibg=Cyan
  silent! hi Group2 term= cterm=
  hi Group3 term=underline cterm=bold

  let res = split(execute("hi NewGroup"), "\n")[0]
  " filter ctermfg and ctermbg, the numbers depend on the terminal
  let res = substitute(res, 'ctermfg=\d*', 'ctermfg=2', '')
  let res = substitute(res, 'ctermbg=\d*', 'ctermbg=3', '')
  call assert_equal("NewGroup       xxx cterm=italic ctermfg=2 ctermbg=3",
				\ res)
  call assert_equal("Group2         xxx cleared",
				\ split(execute("hi Group2"), "\n")[0])
  call assert_equal("Group3         xxx cterm=bold",
				\ split(execute("hi Group3"), "\n")[0])

  hi clear NewGroup
  call assert_equal("NewGroup       xxx cleared",
				\ split(execute("hi NewGroup"), "\n")[0])
  call assert_equal("Group2         xxx cleared",
				\ split(execute("hi Group2"), "\n")[0])
  hi Group2 NONE
  call assert_equal("Group2         xxx cleared",
				\ split(execute("hi Group2"), "\n")[0])
  hi clear
  call assert_equal("Group3         xxx cleared",
				\ split(execute("hi Group3"), "\n")[0])
  call assert_fails("hi Crash term='asdf", "E475:")
endfunc

func HighlightArgs(name)
  return 'hi ' . substitute(split(execute('hi ' . a:name), '\n')[0], '\<xxx\>', '', '')
endfunc

func IsColorable()
  return has('gui_running') || str2nr(&t_Co) >= 8
endfunc

func HiCursorLine()
  let hiCursorLine = HighlightArgs('CursorLine')
  if has('gui_running')
    let guibg = matchstr(hiCursorLine, 'guibg=\w\+')
    let hi_ul = 'hi CursorLine gui=underline guibg=NONE'
    let hi_bg = 'hi CursorLine gui=NONE ' . guibg
  else
    let hi_ul = 'hi CursorLine cterm=underline ctermbg=NONE'
    let hi_bg = 'hi CursorLine cterm=NONE ctermbg=Gray'
  endif
  return [hiCursorLine, hi_ul, hi_bg]
endfunc

func Check_lcs_eol_attrs(attrs, row, col)
  let save_lcs = &lcs
  set list

  call assert_equal(a:attrs, ScreenAttrs(a:row, a:col)[0])

  set nolist
  let &lcs = save_lcs
endfunc

func Test_highlight_eol_with_cursorline()
  let [hiCursorLine, hi_ul, hi_bg] = HiCursorLine()

  call NewWindow('topleft 5', 20)
  call setline(1, 'abcd')
  call matchadd('Search', '\n')

  " expected:
  " 'abcd      '
  "  ^^^^ ^^^^^   no highlight
  "      ^        'Search' highlight
  let attrs0 = ScreenAttrs(1, 10)[0]
  call assert_equal(repeat([attrs0[0]], 4), attrs0[0:3])
  call assert_equal(repeat([attrs0[0]], 5), attrs0[5:9])
  call assert_notequal(attrs0[0], attrs0[4])

  setlocal cursorline

  " underline
  exe hi_ul

  " expected:
  " 'abcd      '
  "  ^^^^         underline
  "      ^        'Search' highlight with underline
  "       ^^^^^   underline
  let attrs = ScreenAttrs(1, 10)[0]
  call assert_equal(repeat([attrs[0]], 4), attrs[0:3])
  call assert_equal([attrs[4]] + repeat([attrs[5]], 5), attrs[4:9])
  call assert_notequal(attrs[0], attrs[4])
  call assert_notequal(attrs[4], attrs[5])
  call assert_notequal(attrs0[0], attrs[0])
  call assert_notequal(attrs0[4], attrs[4])
  call Check_lcs_eol_attrs(attrs, 1, 10)

  if IsColorable()
    " bg-color
    exe hi_bg

    " expected:
    " 'abcd      '
    "  ^^^^         bg-color of 'CursorLine'
    "      ^        'Search' highlight
    "       ^^^^^   bg-color of 'CursorLine'
    let attrs = ScreenAttrs(1, 10)[0]
    call assert_equal(repeat([attrs[0]], 4), attrs[0:3])
    call assert_equal(repeat([attrs[5]], 5), attrs[5:9])
    call assert_equal(attrs0[4], attrs[4])
    call assert_notequal(attrs[0], attrs[4])
    call assert_notequal(attrs[4], attrs[5])
    call assert_notequal(attrs0[0], attrs[0])
    call assert_notequal(attrs0[5], attrs[5])
    call Check_lcs_eol_attrs(attrs, 1, 10)
  endif

  call CloseWindow()
  exe hiCursorLine
endfunc

func Test_highlight_eol_with_cursorline_vertsplit()
  let [hiCursorLine, hi_ul, hi_bg] = HiCursorLine()

  call NewWindow('topleft 5', 5)
  call setline(1, 'abcd')
  call matchadd('Search', '\n')

  let expected = "abcd |abcd     "
  let actual = ScreenLines(1, 15)[0]
  call assert_equal(expected, actual)

  " expected:
  " 'abcd |abcd     '
  "  ^^^^  ^^^^^^^^^   no highlight
  "      ^             'Search' highlight
  "       ^            'VertSplit' highlight
  let attrs0 = ScreenAttrs(1, 15)[0]
  call assert_equal(repeat([attrs0[0]], 4), attrs0[0:3])
  call assert_equal(repeat([attrs0[0]], 9), attrs0[6:14])
  call assert_notequal(attrs0[0], attrs0[4])
  call assert_notequal(attrs0[0], attrs0[5])
  call assert_notequal(attrs0[4], attrs0[5])

  setlocal cursorline

  " expected:
  " 'abcd |abcd     '
  "  ^^^^              underline
  "      ^             'Search' highlight with underline
  "       ^            'VertSplit' highlight
  "        ^^^^^^^^^   no highlight

  " underline
  exe hi_ul

  let actual = ScreenLines(1, 15)[0]
  call assert_equal(expected, actual)

  let attrs = ScreenAttrs(1, 15)[0]
  call assert_equal(repeat([attrs[0]], 4), attrs[0:3])
  call assert_equal(repeat([attrs[6]], 9), attrs[6:14])
  call assert_equal(attrs0[5:14], attrs[5:14])
  call assert_notequal(attrs[0], attrs[4])
  call assert_notequal(attrs[0], attrs[5])
  call assert_notequal(attrs[0], attrs[6])
  call assert_notequal(attrs[4], attrs[5])
  call assert_notequal(attrs[5], attrs[6])
  call assert_notequal(attrs0[0], attrs[0])
  call assert_notequal(attrs0[4], attrs[4])
  call Check_lcs_eol_attrs(attrs, 1, 15)

  if IsColorable()
    " bg-color
    exe hi_bg

    let actual = ScreenLines(1, 15)[0]
    call assert_equal(expected, actual)

    let attrs = ScreenAttrs(1, 15)[0]
    call assert_equal(repeat([attrs[0]], 4), attrs[0:3])
    call assert_equal(repeat([attrs[6]], 9), attrs[6:14])
    call assert_equal(attrs0[5:14], attrs[5:14])
    call assert_notequal(attrs[0], attrs[4])
    call assert_notequal(attrs[0], attrs[5])
    call assert_notequal(attrs[0], attrs[6])
    call assert_notequal(attrs[4], attrs[5])
    call assert_notequal(attrs[5], attrs[6])
    call assert_notequal(attrs0[0], attrs[0])
    call assert_equal(attrs0[4], attrs[4])
    call Check_lcs_eol_attrs(attrs, 1, 15)
  endif

  call CloseWindow()
  exe hiCursorLine
endfunc

func Test_highlight_eol_with_cursorline_rightleft()
  if !has('rightleft')
    return
  endif

  let [hiCursorLine, hi_ul, hi_bg] = HiCursorLine()

  call NewWindow('topleft 5', 10)
  setlocal rightleft
  call setline(1, 'abcd')
  call matchadd('Search', '\n')
  let attrs0 = ScreenAttrs(1, 10)[0]

  setlocal cursorline

  " underline
  exe hi_ul

  " expected:
  " '      dcba'
  "        ^^^^   underline
  "       ^       'Search' highlight with underline
  "  ^^^^^        underline
  let attrs = ScreenAttrs(1, 10)[0]
  call assert_equal(repeat([attrs[9]], 4), attrs[6:9])
  call assert_equal(repeat([attrs[4]], 5) + [attrs[5]], attrs[0:5])
  call assert_notequal(attrs[9], attrs[5])
  call assert_notequal(attrs[4], attrs[5])
  call assert_notequal(attrs0[9], attrs[9])
  call assert_notequal(attrs0[5], attrs[5])
  call Check_lcs_eol_attrs(attrs, 1, 10)

  if IsColorable()
    " bg-color
    exe hi_bg

    " expected:
    " '      dcba'
    "        ^^^^   bg-color of 'CursorLine'
    "       ^       'Search' highlight
    "  ^^^^^        bg-color of 'CursorLine'
    let attrs = ScreenAttrs(1, 10)[0]
    call assert_equal(repeat([attrs[9]], 4), attrs[6:9])
    call assert_equal(repeat([attrs[4]], 5), attrs[0:4])
    call assert_equal(attrs0[5], attrs[5])
    call assert_notequal(attrs[9], attrs[5])
    call assert_notequal(attrs[5], attrs[4])
    call assert_notequal(attrs0[9], attrs[9])
    call assert_notequal(attrs0[4], attrs[4])
    call Check_lcs_eol_attrs(attrs, 1, 10)
  endif

  call CloseWindow()
  exe hiCursorLine
endfunc

func Test_highlight_eol_with_cursorline_linewrap()
  let [hiCursorLine, hi_ul, hi_bg] = HiCursorLine()

  call NewWindow('topleft 5', 10)
  call setline(1, [repeat('a', 51) . 'bcd', ''])
  call matchadd('Search', '\n')

  setlocal wrap
  normal! gg$
  let attrs0 = ScreenAttrs(5, 10)[0]
  setlocal cursorline

  " underline
  exe hi_ul

  " expected:
  " 'abcd      '
  "  ^^^^         underline
  "      ^        'Search' highlight with underline
  "       ^^^^^   underline
  let attrs = ScreenAttrs(5, 10)[0]
  call assert_equal(repeat([attrs[0]], 4), attrs[0:3])
  call assert_equal([attrs[4]] + repeat([attrs[5]], 5), attrs[4:9])
  call assert_notequal(attrs[0], attrs[4])
  call assert_notequal(attrs[4], attrs[5])
  call assert_notequal(attrs0[0], attrs[0])
  call assert_notequal(attrs0[4], attrs[4])
  call Check_lcs_eol_attrs(attrs, 5, 10)

  if IsColorable()
    " bg-color
    exe hi_bg

    " expected:
    " 'abcd      '
    "  ^^^^         bg-color of 'CursorLine'
    "      ^        'Search' highlight
    "       ^^^^^   bg-color of 'CursorLine'
    let attrs = ScreenAttrs(5, 10)[0]
    call assert_equal(repeat([attrs[0]], 4), attrs[0:3])
    call assert_equal(repeat([attrs[5]], 5), attrs[5:9])
    call assert_equal(attrs0[4], attrs[4])
    call assert_notequal(attrs[0], attrs[4])
    call assert_notequal(attrs[4], attrs[5])
    call assert_notequal(attrs0[0], attrs[0])
    call assert_notequal(attrs0[5], attrs[5])
    call Check_lcs_eol_attrs(attrs, 5, 10)
  endif

  setlocal nocursorline nowrap
  normal! gg$
  let attrs0 = ScreenAttrs(1, 10)[0]
  setlocal cursorline

  " underline
  exe hi_ul

  " expected:
  " 'aaabcd    '
  "  ^^^^^^       underline
  "        ^      'Search' highlight with underline
  "         ^^^   underline
  let attrs = ScreenAttrs(1, 10)[0]
  call assert_equal(repeat([attrs[0]], 6), attrs[0:5])
  call assert_equal([attrs[6]] + repeat([attrs[7]], 3), attrs[6:9])
  call assert_notequal(attrs[0], attrs[6])
  call assert_notequal(attrs[6], attrs[7])
  call assert_notequal(attrs0[0], attrs[0])
  call assert_notequal(attrs0[6], attrs[6])
  call Check_lcs_eol_attrs(attrs, 1, 10)

  if IsColorable()
    " bg-color
    exe hi_bg

    " expected:
    " 'aaabcd    '
    "  ^^^^^^       bg-color of 'CursorLine'
    "        ^      'Search' highlight
    "         ^^^   bg-color of 'CursorLine'
    let attrs = ScreenAttrs(1, 10)[0]
    call assert_equal(repeat([attrs[0]], 6), attrs[0:5])
    call assert_equal(repeat([attrs[7]], 3), attrs[7:9])
    call assert_equal(attrs0[6], attrs[6])
    call assert_notequal(attrs[0], attrs[6])
    call assert_notequal(attrs[6], attrs[7])
    call assert_notequal(attrs0[0], attrs[0])
    call assert_notequal(attrs0[7], attrs[7])
    call Check_lcs_eol_attrs(attrs, 1, 10)
  endif

  call CloseWindow()
  exe hiCursorLine
endfunc

func Test_highlight_eol_with_cursorline_sign()
  if !has('signs')
    return
  endif

  let [hiCursorLine, hi_ul, hi_bg] = HiCursorLine()

  call NewWindow('topleft 5', 10)
  call setline(1, 'abcd')
  call matchadd('Search', '\n')

  sign define Sign text=>>
  exe 'sign place 1 line=1 name=Sign buffer=' . bufnr('')
  let attrs0 = ScreenAttrs(1, 10)[0]
  setlocal cursorline

  " underline
  exe hi_ul

  " expected:
  " '>>abcd    '
  "  ^^           sign
  "    ^^^^       underline
  "        ^      'Search' highlight with underline
  "         ^^^   underline
  let attrs = ScreenAttrs(1, 10)[0]
  call assert_equal(repeat([attrs[2]], 4), attrs[2:5])
  call assert_equal([attrs[6]] + repeat([attrs[7]], 3), attrs[6:9])
  call assert_notequal(attrs[2], attrs[6])
  call assert_notequal(attrs[6], attrs[7])
  call assert_notequal(attrs0[2], attrs[2])
  call assert_notequal(attrs0[6], attrs[6])
  call Check_lcs_eol_attrs(attrs, 1, 10)

  if IsColorable()
    " bg-color
    exe hi_bg

    " expected:
    " '>>abcd    '
    "  ^^           sign
    "    ^^^^       bg-color of 'CursorLine'
    "        ^      'Search' highlight
    "         ^^^   bg-color of 'CursorLine'
    let attrs = ScreenAttrs(1, 10)[0]
    call assert_equal(repeat([attrs[2]], 4), attrs[2:5])
    call assert_equal(repeat([attrs[7]], 3), attrs[7:9])
    call assert_equal(attrs0[6], attrs[6])
    call assert_notequal(attrs[2], attrs[6])
    call assert_notequal(attrs[6], attrs[7])
    call assert_notequal(attrs0[2], attrs[2])
    call assert_notequal(attrs0[7], attrs[7])
    call Check_lcs_eol_attrs(attrs, 1, 10)
  endif

  sign unplace 1
  call CloseWindow()
  exe hiCursorLine
endfunc

func Test_highlight_eol_with_cursorline_breakindent()
  if !has('linebreak')
    return
  endif

  let [hiCursorLine, hi_ul, hi_bg] = HiCursorLine()

  call NewWindow('topleft 5', 10)
  setlocal breakindent breakindentopt=min:0,shift:1 showbreak=>
  call setline(1, ' ' . repeat('a', 9) . 'bcd')
  call matchadd('Search', '\n')
  let attrs0 = ScreenAttrs(2, 10)[0]
  setlocal cursorline

  " underline
  exe hi_ul

  " expected:
  " '  >bcd    '
  "  ^^^          breakindent and showbreak
  "     ^^^       underline
  "        ^      'Search' highlight with underline
  "         ^^^   underline
  let attrs = ScreenAttrs(2, 10)[0]
  call assert_equal(repeat([attrs[0]], 2), attrs[0:1])
  call assert_equal(repeat([attrs[3]], 3), attrs[3:5])
  call assert_equal([attrs[6]] + repeat([attrs[7]], 3), attrs[6:9])
  call assert_equal(attrs0[0], attrs[0])
  call assert_notequal(attrs[0], attrs[2])
  call assert_notequal(attrs[2], attrs[3])
  call assert_notequal(attrs[3], attrs[6])
  call assert_notequal(attrs[6], attrs[7])
  call assert_notequal(attrs0[2], attrs[2])
  call assert_notequal(attrs0[3], attrs[3])
  call assert_notequal(attrs0[6], attrs[6])
  call Check_lcs_eol_attrs(attrs, 2, 10)

  if IsColorable()
    " bg-color
    exe hi_bg

    " expected:
    " '  >bcd    '
    "  ^^^          breakindent and showbreak
    "     ^^^       bg-color of 'CursorLine'
    "        ^      'Search' highlight
    "         ^^^   bg-color of 'CursorLine'
    let attrs = ScreenAttrs(2, 10)[0]
    call assert_equal(repeat([attrs[0]], 2), attrs[0:1])
    call assert_equal(repeat([attrs[3]], 3), attrs[3:5])
    call assert_equal(repeat([attrs[7]], 3), attrs[7:9])
    call assert_equal(attrs0[0], attrs[0])
    call assert_equal(attrs0[6], attrs[6])
    call assert_notequal(attrs[0], attrs[2])
    call assert_notequal(attrs[2], attrs[3])
    call assert_notequal(attrs[3], attrs[6])
    call assert_notequal(attrs[6], attrs[7])
    call assert_notequal(attrs0[2], attrs[2])
    call assert_notequal(attrs0[3], attrs[3])
    call assert_notequal(attrs0[7], attrs[7])
    call Check_lcs_eol_attrs(attrs, 2, 10)
  endif

  call CloseWindow()
  set showbreak=
  exe hiCursorLine
endfunc

func Test_highlight_eol_on_diff()
  call setline(1, ['abcd', ''])
  call matchadd('Search', '\n')
  let attrs0 = ScreenAttrs(1, 10)[0]

  diffthis
  botright new
  diffthis

  " expected:
  " '  abcd    '
  "  ^^           sign
  "    ^^^^ ^^^   'DiffAdd' highlight
  "        ^      'Search' highlight
  let attrs = ScreenAttrs(1, 10)[0]
  call assert_equal(repeat([attrs[0]], 2), attrs[0:1])
  call assert_equal(repeat([attrs[2]], 4), attrs[2:5])
  call assert_equal(repeat([attrs[2]], 3), attrs[7:9])
  call assert_equal(attrs0[4], attrs[6])
  call assert_notequal(attrs[0], attrs[2])
  call assert_notequal(attrs[0], attrs[6])
  call assert_notequal(attrs[2], attrs[6])
  call Check_lcs_eol_attrs(attrs, 1, 10)

  bwipe!
  diffoff
endfunc

func Test_termguicolors()
  if !exists('+termguicolors')
    return
  endif
  if has('vtp') && !has('vcon') && !has('gui_running')
    " Win32: 'guicolors' doesn't work without virtual console.
    call assert_fails('set termguicolors', 'E954:')
    return
  endif

  " Basic test that setting 'termguicolors' works with one color.
  set termguicolors
  redraw
  set t_Co=1
  redraw
  set t_Co=0
  redraw
endfunc

func Test_cursorline_after_yank()
  if !CanRunVimInTerminal()
    throw 'Skipped: cannot make screendumps'
  endif

  call writefile([
	\ 'set cul rnu',
	\ 'call setline(1, ["","1","2","3",""])',
	\ ], 'Xtest_cursorline_yank')
  let buf = RunVimInTerminal('-S Xtest_cursorline_yank', {'rows': 8})
  call term_wait(buf)
  call term_sendkeys(buf, "Gy3k")
  call term_wait(buf)
  call term_sendkeys(buf, "jj")

  call VerifyScreenDump(buf, 'Test_cursorline_yank_01', {})

  " clean up
  call StopVimInTerminal(buf)
  call delete('Xtest_cursorline_yank')
endfunc

" test for issue https://github.com/vim/vim/issues/4862
func Test_put_before_cursorline()
  new
  only!
  call setline(1, 'A')
  redraw
  let std_attr = screenattr(1, 1)
  set cursorline
  redraw
  let cul_attr = screenattr(1, 1)
  normal yyP
  redraw
  " Line 1 has cursor so it should be highlighted with CursorLine.
  call assert_equal(cul_attr, screenattr(1, 1))
  " And CursorLine highlighting from the second line should be gone.
  call assert_equal(std_attr, screenattr(2, 1))
  set nocursorline
  bwipe!
endfunc

func Test_cursorline_with_visualmode()
  if !CanRunVimInTerminal()
    throw 'Skipped: cannot make screendumps'
  endif

  call writefile([
	\ 'set cul',
	\ 'call setline(1, repeat(["abc"], 50))',
	\ ], 'Xtest_cursorline_with_visualmode')
  let buf = RunVimInTerminal('-S Xtest_cursorline_with_visualmode', {'rows': 12})
  call term_wait(buf)
  call term_sendkeys(buf, "V\<C-f>kkkjk")

  call VerifyScreenDump(buf, 'Test_cursorline_with_visualmode_01', {})

  " clean up
  call StopVimInTerminal(buf)
  call delete('Xtest_cursorline_with_visualmode')
endfunc

" This test must come before the Test_cursorline test, as it appears this
" defines the Normal highlighting group anyway.
func Test_1_highlight_Normalgroup_exists()
  let hlNormal = HighlightArgs('Normal')
  if !has('gui_running')
    call assert_match('hi Normal\s*clear', hlNormal)
  elseif has('gui_gtk2') || has('gui_gnome') || has('gui_gtk3')
    " expect is DEFAULT_FONT of gui_gtk_x11.c
    call assert_match('hi Normal\s*font=Monospace 10', hlNormal)
  elseif has('gui_motif') || has('gui_athena')
    " expect is DEFAULT_FONT of gui_x11.c
    call assert_match('hi Normal\s*font=7x13', hlNormal)
  elseif has('win32')
    " expect any font
    call assert_match('hi Normal\s*font=.*', hlNormal)
  endif
endfunc

" Test for using RGB color values in a highlight group
func Test_xxlast_highlight_RGB_color()
  CheckCanRunGui
  gui -f
  hi MySearch guifg=#110000 guibg=#001100 guisp=#000011
  call assert_equal('#110000', synIDattr(synIDtrans(hlID('MySearch')), 'fg#'))
  call assert_equal('#001100', synIDattr(synIDtrans(hlID('MySearch')), 'bg#'))
  call assert_equal('#000011', synIDattr(synIDtrans(hlID('MySearch')), 'sp#'))
  hi clear
endfunc

func Test_highlight_clear_restores_links()
  let aaa_id = hlID('aaa')
  call assert_equal(aaa_id, 0)

  " create default link aaa --> bbb
  hi def link aaa bbb
  let id_aaa = hlID('aaa')
  let hl_aaa_bbb = HighlightArgs('aaa')

  " try to redefine default link aaa --> ccc; check aaa --> bbb
  hi def link aaa ccc
  call assert_equal(HighlightArgs('aaa'), hl_aaa_bbb)

  " clear aaa; check aaa --> bbb
  hi clear aaa
  call assert_equal(HighlightArgs('aaa'), hl_aaa_bbb)

  " link aaa --> ccc; clear aaa; check aaa --> bbb
  hi link aaa ccc
  let id_ccc = hlID('ccc')
  call assert_equal(synIDtrans(id_aaa), id_ccc)
  hi clear aaa
  call assert_equal(HighlightArgs('aaa'), hl_aaa_bbb)

  " forcibly set default link aaa --> ddd
  hi! def link aaa ddd
  let id_ddd = hlID('ddd')
  let hl_aaa_ddd = HighlightArgs('aaa')
  call assert_equal(synIDtrans(id_aaa), id_ddd)

  " link aaa --> eee; clear aaa; check aaa --> ddd
  hi link aaa eee
  let eee_id = hlID('eee')
  call assert_equal(synIDtrans(id_aaa), eee_id)
  hi clear aaa
  call assert_equal(HighlightArgs('aaa'), hl_aaa_ddd)
endfunc

func Test_highlight_clear_restores_context()
  func FuncContextDefault()
    hi def link Context ContextDefault
  endfun

  func FuncContextRelink()
    " Dummy line
    hi link Context ContextRelink
  endfunc

  let scriptContextDefault = MakeScript("FuncContextDefault")
  let scriptContextRelink = MakeScript("FuncContextRelink")
  let patContextDefault = fnamemodify(scriptContextDefault, ':t') .. ' line 1'
  let patContextRelink = fnamemodify(scriptContextRelink, ':t') .. ' line 2'

  exec "source" scriptContextDefault
  let hlContextDefault = execute("verbose hi Context")
  call assert_match(patContextDefault, hlContextDefault)

  exec "source" scriptContextRelink
  let hlContextRelink = execute("verbose hi Context")
  call assert_match(patContextRelink, hlContextRelink)

  hi clear
  let hlContextAfterClear = execute("verbose hi Context")
  call assert_match(patContextDefault, hlContextAfterClear)

  delfunc FuncContextDefault
  delfunc FuncContextRelink
  call delete(scriptContextDefault)
  call delete(scriptContextRelink)
endfunc

func Test_highlight_default_colorscheme_restores_links()
  hi link TestLink Identifier
  hi TestHi ctermbg=red

  let hlTestLinkPre = HighlightArgs('TestLink')
  let hlTestHiPre = HighlightArgs('TestHi')

  " Test colorscheme
  hi clear
  if exists('syntax_on')
    syntax reset
  endif
  let g:colors_name = 'test'
  hi link TestLink ErrorMsg
  hi TestHi ctermbg=green

  " Restore default highlighting
  colorscheme default
  " 'default' should work no matter if highlight group was cleared
  hi def link TestLink Identifier
  hi def TestHi ctermbg=red
  let hlTestLinkPost = HighlightArgs('TestLink')
  let hlTestHiPost = HighlightArgs('TestHi')
  call assert_equal(hlTestLinkPre, hlTestLinkPost)
  call assert_equal(hlTestHiPre, hlTestHiPost)
  hi clear
endfunc

" vim: shiftwidth=2 sts=2 expandtab
