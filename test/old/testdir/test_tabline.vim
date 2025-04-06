" Test for tabline

source shared.vim
source view_util.vim
source check.vim
source screendump.vim

func TablineWithCaughtError()
  let s:func_in_tabline_called = 1
  try
    call eval('unknown expression')
  catch
  endtry
  return ''
endfunc

func TablineWithError()
  let s:func_in_tabline_called = 1
  call eval('unknown expression')
  return ''
endfunc

func Test_caught_error_in_tabline()
  if has('gui')
    set guioptions-=e
  endif
  let showtabline_save = &showtabline
  set showtabline=2
  let s:func_in_tabline_called = 0
  let tabline = '%{TablineWithCaughtError()}'
  let &tabline = tabline
  redraw!
  call assert_true(s:func_in_tabline_called)
  call assert_equal(tabline, &tabline)
  set tabline=
  let &showtabline = showtabline_save
endfunc

func Test_tabline_will_be_disabled_with_error()
  if has('gui')
    set guioptions-=e
  endif
  let showtabline_save = &showtabline
  set showtabline=2
  let s:func_in_tabline_called = 0
  let tabline = '%{TablineWithError()}'
  try
    let &tabline = tabline
    redraw!
  catch
  endtry
  call assert_true(s:func_in_tabline_called)
  call assert_equal('', &tabline)
  set tabline=
  let &showtabline = showtabline_save
endfunc

func Test_redrawtabline()
  if has('gui')
    set guioptions-=e
  endif
  let showtabline_save = &showtabline
  set showtabline=2
  set tabline=%{bufnr('$')}
  edit Xtabline1
  edit Xtabline2
  redraw
  call assert_match(bufnr('$') . '', Screenline(1))
  au BufAdd * redrawtabline
  badd Xtabline3
  call assert_match(bufnr('$') . '', Screenline(1))

  set tabline=
  let &showtabline = showtabline_save
  au! Bufadd
endfunc

" Test for the "%T" and "%X" flags in the 'tabline' option
func MyTabLine()
  let s = ''
  for i in range(tabpagenr('$'))
    " set the tab page number (for mouse clicks)
    let s .= '%' . (i + 1) . 'T'

    " the label is made by MyTabLabel()
    let s .= ' %{MyTabLabel(' . (i + 1) . ')} '
  endfor

  " after the last tab fill with TabLineFill and reset tab page nr
  let s .= '%T'

  " right-align the label to close the current tab page
  if tabpagenr('$') > 1
    let s .= '%=%Xclose'
  endif

  return s
endfunc

func MyTabLabel(n)
  let buflist = tabpagebuflist(a:n)
  let winnr = tabpagewinnr(a:n)
  return bufname(buflist[winnr - 1])
endfunc

func Test_tabline_flags()
  if has('gui')
    set guioptions-=e
  endif
  set tabline=%!MyTabLine()
  edit Xtabline1
  tabnew Xtabline2
  redrawtabline
  call assert_match('^ Xtabline1  Xtabline2\s\+close$', Screenline(1))
  set tabline=
  %bw!
endfunc

function EmptyTabname()
  return ""
endfunction

function MakeTabLine() abort
  let titles = map(range(1, tabpagenr('$')), '"%( %" . v:val . "T%{EmptyTabname()}%T %)"')
  let sep = 'あ'
  let tabpages = join(titles, sep)
  return tabpages .. sep .. '%=%999X X'
endfunction

func Test_tabline_empty_group()
  " this was reading invalid memory
  set tabline=%!MakeTabLine()
  tabnew
  redraw!

  bw!
  set tabline=
endfunc

" When there are exactly 20 tabline format items (the exact size of the
" initial tabline items array), test that we don't write beyond the size
" of the array.
func Test_tabline_20_format_items_no_overrun()
  set showtabline=2

  let tabline = repeat('%#StatColorHi2#', 20)
  let &tabline = tabline
  redrawtabline

  set showtabline& tabline&
endfunc

func Test_mouse_click_in_tab()
  " This used to crash because TabPageIdxs[] was not initialized
  let lines =<< trim END
      tabnew
      set mouse=a
      exe "norm \<LeftMouse>"
  END
  call writefile(lines, 'Xclickscript')
  call RunVim([], [], "-e -s -S Xclickscript -c qa")

  call delete('Xclickscript')
endfunc

func Test_tabline_showcmd()
  CheckScreendump

  let lines =<< trim END
    func MyTabLine()
      return '%S'
    endfunc

    set showtabline=2
    set tabline=%!MyTabLine()
    set showcmdloc=tabline
    call setline(1, ['a', 'b', 'c'])
    set foldopen+=jump
    1,2fold
    3
  END
  call writefile(lines, 'XTest_tabline', 'D')

  let buf = RunVimInTerminal('-S XTest_tabline', {'rows': 6})

  call term_sendkeys(buf, "g")
  call VerifyScreenDump(buf, 'Test_tabline_showcmd_1', {})

  " typing "gg" should open the fold
  call term_sendkeys(buf, "g")
  call VerifyScreenDump(buf, 'Test_tabline_showcmd_2', {})

  call term_sendkeys(buf, "\<C-V>Gl")
  call VerifyScreenDump(buf, 'Test_tabline_showcmd_3', {})

  call term_sendkeys(buf, "\<Esc>1234")
  call VerifyScreenDump(buf, 'Test_tabline_showcmd_4', {})

  call term_sendkeys(buf, "\<Esc>:set tabline=\<CR>")
  call term_sendkeys(buf, ":\<CR>")
  call term_sendkeys(buf, "1234")
  call VerifyScreenDump(buf, 'Test_tabline_showcmd_5', {})

  call StopVimInTerminal(buf)
endfunc

func TruncTabLine()
  return '%1T口口%2Ta' .. repeat('b', &columns - 4) .. '%999X%#TabLine#c'
endfunc

" Test 'tabline' with truncated double-width label at the start.
func Test_tabline_truncated_double_width()
  let save_TabLine = nvim_get_hl(0, #{name: 'TabLine'})
  " Nvim: avoid combining TabLine with TabLineFill in custom tabline
  hi TabLine cterm=underline,nocombine gui=underline,nocombine
  tabnew
  redraw
  call assert_match('X$', Screenline(1))
  let attr_TabLineFill = screenattr(1, &columns - 1)
  let attr_TabLine = screenattr(1, &columns)
  call assert_notequal(attr_TabLine, attr_TabLineFill)

  set tabline=%!TruncTabLine()
  redraw
  call assert_equal('<a' .. repeat('b', &columns - 4) .. 'c', Screenline(1))
  call assert_equal(attr_TabLineFill, screenattr(1, &columns - 2))
  call assert_equal(attr_TabLine, screenattr(1, &columns - 1))
  call assert_equal(attr_TabLine, screenattr(1, &columns))

  bw!
  set tabline=
  call nvim_set_hl(0, 'TabLine', save_TabLine)
endfunc

" vim: shiftwidth=2 sts=2 expandtab
