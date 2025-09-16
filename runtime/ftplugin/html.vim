" Vim filetype plugin file
" Language:		HTML
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Dan Sharp
" Last Change:		2025 Sep 12

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:save_cpo = &cpo
set cpo-=C

setlocal matchpairs+=<:>
setlocal commentstring=<!--\ %s\ -->
setlocal comments=s:<!--,m:\ \ \ \ ,e:-->

if exists('b:undo_ftplugin')
  " no whitespace before |, handle possible :unmap at end of current value
  let b:undo_ftplugin ..= "| setlocal comments< commentstring< matchpairs<"
else
  let b:undo_ftplugin = "setlocal comments< commentstring< matchpairs<"
endif

if get(g:, "ft_html_autocomment", 0)
  setlocal formatoptions-=t formatoptions+=croql
  let b:undo_ftplugin ..= " | setlocal formatoptions<"
endif

if exists('&omnifunc')
  setlocal omnifunc=htmlcomplete#CompleteTags
  call htmlcomplete#DetectOmniFlavor()
  let b:undo_ftplugin ..= " | setlocal omnifunc<"
endif

" HTML: thanks to Johannes Zellner and Benji Fisher.
if exists("loaded_matchit") && !exists("b:match_words")
  let b:match_ignorecase = 1
  let b:match_words = '<!--:-->,' ..
	\	      '<:>,' ..
	\	      '<\@<=[ou]l\>[^>]*\%(>\|$\):<\@<=li\>:<\@<=/[ou]l>,' ..
	\	      '<\@<=dl\>[^>]*\%(>\|$\):<\@<=d[td]\>:<\@<=/dl>,' ..
	\	      '<\@<=\([^/!][^ \t>]*\)[^>]*\%(>\|$\):<\@<=/\1>'
  let b:html_set_match_words = 1
  let b:undo_ftplugin ..= " | unlet! b:match_ignorecase b:match_words b:html_set_match_words"
endif

" Change the :browse e filter to primarily show HTML-related files.
if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let  b:browsefilter = "HTML Files (*.html, *.htm)\t*.html;*.htm\n" ..
	\		"JavaScript Files (*.js)\t*.js\n" ..
	\		"Cascading StyleSheets (*.css)\t*.css\n"
  if has("win32")
    let b:browsefilter ..= "All Files (*.*)\t*\n"
  else
    let b:browsefilter ..= "All Files (*)\t*\n"
  endif
  let b:html_set_browsefilter = 1
  let b:undo_ftplugin ..= " | unlet! b:browsefilter b:html_set_browsefilter"
endif

if has("folding") && get(g:, "html_expr_folding", 0)
  function! HTMLTagFold() abort
    if empty(get(b:, "foldsmap", {}))
      if empty(get(b:, "current_syntax", ''))
	return '0'
      else
	let b:foldsmap = htmlfold#MapBalancedTags()
      endif
    endif

    return get(b:foldsmap, v:lnum, '=')
  endfunction

  setlocal foldexpr=HTMLTagFold()
  setlocal foldmethod=expr
  let b:undo_ftplugin ..= " | setlocal foldexpr< foldmethod<"

  if !get(g:, "html_expr_folding_without_recomputation", 0)
    augroup htmltagfold
      autocmd! htmltagfold
      autocmd TextChanged,InsertLeave <buffer> let b:foldsmap = {}
    augroup END

    " XXX: Keep ":autocmd" last in "b:undo_ftplugin" (see ":help :bar").
    let b:undo_ftplugin ..= " | silent! autocmd! htmltagfold * <buffer>"
  endif
endif

let &cpo = s:save_cpo
unlet s:save_cpo

" See ":help vim9-mix".
if !has("vim9script")
  finish
endif

if exists("*g:HTMLTagFold")
  def! g:HTMLTagFold(): string
    if empty(get(b:, "foldsmap", {}))
      if empty(get(b:, "current_syntax", ''))
	return '0'
      else
	b:foldsmap = g:htmlfold#MapBalancedTags()
      endif
    endif

    return get(b:foldsmap, v:lnum, '=')
  enddef
endif
