" Vim plugin for showing matching parens
" Maintainer:  Bram Moolenaar <Bram@vim.org>
" Last Change: 2017 Sep 30

" Exit quickly when:
" - this plugin was already loaded (or disabled)
" - when 'compatible' is set
" - the "CursorMoved" autocmd event is not available.
if exists("g:loaded_matchparen") || &cp || !exists("##CursorMoved")
  finish
endif
let g:loaded_matchparen = 1

if !exists("g:matchparen_timeout")
  let g:matchparen_timeout = 300
endif
if !exists("g:matchparen_insert_timeout")
  let g:matchparen_insert_timeout = 60
endif

augroup matchparen
  " Replace all matchparen autocommands
  autocmd! CursorMoved,CursorMovedI,WinEnter * call s:Highlight_Matching_Pair()
  if exists('##TextChanged')
    autocmd! TextChanged,TextChangedI * call s:Highlight_Matching_Pair()
  endif
augroup END

" Skip the rest if it was already done.
if exists("*s:Highlight_Matching_Pair")
  finish
endif

let s:cpo_save = &cpo
set cpo-=C

" The function that is invoked (very often) to define a ":match" highlighting
" for any matching paren.
function! s:Highlight_Matching_Pair()
  " Remove any previous match.
  if exists('w:paren_hl_on') && w:paren_hl_on
    silent! call matchdelete(3)
    let w:paren_hl_on = 0
  endif

  " Avoid that we remove the popup menu.
  " Return when there are no colors (looks like the cursor jumps).
  if pumvisible() || (&t_Co < 8 && !has("gui_running"))
    return
  endif

  " Get the character under the cursor and check if it's in 'matchpairs'.
  let c_lnum = line('.')
  let c_col = col('.')
  let before = 0

  let text = getline(c_lnum)
  let matches = matchlist(text, '\(.\)\=\%'.c_col.'c\(.\=\)')
  if empty(matches)
    let [c_before, c] = ['', '']
  else
    let [c_before, c] = matches[1:2]
  endif
  let plist = split(&matchpairs, '.\zs[:,]')
  let i = index(plist, c)
  if i < 0
    " not found, in Insert mode try character before the cursor
    if c_col > 1 && (mode() == 'i' || mode() == 'R')
      let before = strlen(c_before)
      let c = c_before
      let i = index(plist, c)
    endif
    if i < 0
      " not found, nothing to do
      return
    endif
  endif

  " Figure out the arguments for searchpairpos().
  if i % 2 == 0
    let s_flags = 'nW'
    let c2 = plist[i + 1]
  else
    let s_flags = 'nbW'
    let c2 = c
    let c = plist[i - 1]
  endif
  if c == '['
    let c = '\['
    let c2 = '\]'
  endif

  " Find the match.  When it was just before the cursor move it there for a
  " moment.
  if before > 0
    let has_getcurpos = exists("*getcurpos")
    if has_getcurpos
      " getcurpos() is more efficient but doesn't exist before 7.4.313.
      let save_cursor = getcurpos()
    else
      let save_cursor = winsaveview()
    endif
    call cursor(c_lnum, c_col - before)
  endif

  " Build an expression that detects whether the current cursor position is in
  " certain syntax types (string, comment, etc.), for use as searchpairpos()'s
  " skip argument.
  " We match "escape" for special items, such as lispEscapeSpecial.
  let s_skip = '!empty(filter(map(synstack(line("."), col(".")), ''synIDattr(v:val, "name")''), ' .
	\ '''v:val =~? "string\\|character\\|singlequote\\|escape\\|comment"''))'
  " If executing the expression determines that the cursor is currently in
  " one of the syntax types, then we want searchpairpos() to find the pair
  " within those syntax types (i.e., not skip).  Otherwise, the cursor is
  " outside of the syntax types and s_skip should keep its value so we skip any
  " matching pair inside the syntax types.
  execute 'if' s_skip '| let s_skip = 0 | endif'

  " Limit the search to lines visible in the window.
  let stoplinebottom = line('w$')
  let stoplinetop = line('w0')
  if i % 2 == 0
    let stopline = stoplinebottom
  else
    let stopline = stoplinetop
  endif

  " Limit the search time to 300 msec to avoid a hang on very long lines.
  " This fails when a timeout is not supported.
  if mode() == 'i' || mode() == 'R'
    let timeout = exists("b:matchparen_insert_timeout") ? b:matchparen_insert_timeout : g:matchparen_insert_timeout
  else
    let timeout = exists("b:matchparen_timeout") ? b:matchparen_timeout : g:matchparen_timeout
  endif
  try
    let [m_lnum, m_col] = searchpairpos(c, '', c2, s_flags, s_skip, stopline, timeout)
  catch /E118/
    " Can't use the timeout, restrict the stopline a bit more to avoid taking
    " a long time on closed folds and long lines.
    " The "viewable" variables give a range in which we can scroll while
    " keeping the cursor at the same position.
    " adjustedScrolloff accounts for very large numbers of scrolloff.
    let adjustedScrolloff = min([&scrolloff, (line('w$') - line('w0')) / 2])
    let bottom_viewable = min([line('$'), c_lnum + &lines - adjustedScrolloff - 2])
    let top_viewable = max([1, c_lnum-&lines+adjustedScrolloff + 2])
    " one of these stoplines will be adjusted below, but the current values are
    " minimal boundaries within the current window
    if i % 2 == 0
      if has("byte_offset") && has("syntax_items") && &smc > 0
	let stopbyte = min([line2byte("$"), line2byte(".") + col(".") + &smc * 2])
	let stopline = min([bottom_viewable, byte2line(stopbyte)])
      else
	let stopline = min([bottom_viewable, c_lnum + 100])
      endif
      let stoplinebottom = stopline
    else
      if has("byte_offset") && has("syntax_items") && &smc > 0
	let stopbyte = max([1, line2byte(".") + col(".") - &smc * 2])
	let stopline = max([top_viewable, byte2line(stopbyte)])
      else
	let stopline = max([top_viewable, c_lnum - 100])
      endif
      let stoplinetop = stopline
    endif
    let [m_lnum, m_col] = searchpairpos(c, '', c2, s_flags, s_skip, stopline)
  endtry

  if before > 0
    if has_getcurpos
      call setpos('.', save_cursor)
    else
      call winrestview(save_cursor)
    endif
  endif

  " If a match is found setup match highlighting.
  if m_lnum > 0 && m_lnum >= stoplinetop && m_lnum <= stoplinebottom 
    if exists('*matchaddpos')
      call matchaddpos('MatchParen', [[c_lnum, c_col - before], [m_lnum, m_col]], 10, 3)
    else
      exe '3match MatchParen /\(\%' . c_lnum . 'l\%' . (c_col - before) .
	    \ 'c\)\|\(\%' . m_lnum . 'l\%' . m_col . 'c\)/'
    endif
    let w:paren_hl_on = 1
  endif
endfunction

" Define commands that will disable and enable the plugin.
command! DoMatchParen call s:DoMatchParen()
command! NoMatchParen call s:NoMatchParen()

func! s:NoMatchParen()
  let w = winnr()
  noau windo silent! call matchdelete(3)
  unlet! g:loaded_matchparen
  exe "noau ". w . "wincmd w"
  au! matchparen
endfunc

func! s:DoMatchParen()
  runtime plugin/matchparen.vim
  let w = winnr()
  silent windo doau CursorMoved
  exe "noau ". w . "wincmd w"
endfunc

let &cpo = s:cpo_save
unlet s:cpo_save
