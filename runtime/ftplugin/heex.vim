" Elixir filetype plugin
" Language: HEEx
" Maintainer:	Mitchell Hanberg <vimNOSPAM@mitchellhanberg.com>
" Last Change: 2022 Sep 21
" 2025 Apr 16 by Vim Project (set 'cpoptions' for line continuation, #17121)
" 2026 Jun 27 by Vim Project (add recommended style guard)

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

if get(g:, 'heex_recommended_style',
      \ get(g:, 'filetype_recommended_style', 1))
  setlocal shiftwidth=2 softtabstop=2 expandtab
endif

setlocal comments=:<%!--
setlocal commentstring=<%!--\ %s\ --%>

let b:undo_ftplugin = 'set sw< sts< et< com< cms<'

" HTML: thanks to Johannes Zellner and Benji Fisher.
if exists("loaded_matchit") && !exists("b:match_words")
  let b:match_ignorecase = 1
  let b:match_words = '<%\{-}!--:--%\{-}>,' ..
	\	      '<:>,' ..
	\	      '<\@<=[ou]l\>[^>]*\%(>\|$\):<\@<=li\>:<\@<=/[ou]l>,' ..
	\	      '<\@<=dl\>[^>]*\%(>\|$\):<\@<=d[td]\>:<\@<=/dl>,' ..
	\	      '<\@<=\([^/!][^ \t>]*\)[^>]*\%(>\|$\):<\@<=/\1>'
  let b:undo_ftplugin ..= " | unlet! b:match_ignorecase b:match_words"
endif

let &cpo = s:cpo_save
unlet s:cpo_save
