" Vim filetype plugin file
" Language:		sh
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Dan Sharp
" Contributor:		Enno Nagel <ennonagel+vim@gmail.com>
" Last Change:		2023 Aug 29

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:save_cpo = &cpo
set cpo-=C

setlocal comments=:#
setlocal commentstring=#\ %s
setlocal formatoptions-=t formatoptions+=croql

let b:undo_ftplugin = "setl com< cms< fo<"

" Shell:  thanks to Johannes Zellner
if exists("loaded_matchit") && !exists("b:match_words")
  let b:match_ignorecase = 0
  let s:sol = '\%(;\s*\|^\s*\)\@<='  " start of line
  let b:match_words =
	\  s:sol .. 'if\>:' .. s:sol.'elif\>:' .. s:sol.'else\>:' .. s:sol .. 'fi\>,' ..
	\  s:sol .. '\%(for\|while\)\>:' .. s:sol .. 'done\>,' ..
	\  s:sol .. 'case\>:' .. s:sol .. 'esac\>'
  unlet s:sol
  let b:undo_ftplugin ..= " | unlet! b:match_ignorecase b:match_words"
endif

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "Bourne Shell Scripts (*.sh)\t*.sh\n" ..
	\	       "Korn Shell Scripts (*.ksh)\t*.ksh\n" ..
	\	       "Bash Shell Scripts (*.bash)\t*.bash\n" ..
	\	       "All Files (*.*)\t*.*\n"
  let b:undo_ftplugin ..= " | unlet! b:browsefilter"
endif

if (exists("b:is_bash") && (b:is_bash == 1)) ||
      \ (exists("b:is_sh") && (b:is_sh == 1))
  if !has("gui_running") && executable("less")
    command! -buffer -nargs=1 Help silent exe '!bash -c "{ help "<args>" 2>/dev/null || man "<args>"; } | LESS= less"' | redraw!
  elseif has('terminal')
    command! -buffer -nargs=1 Help silent exe ':term bash -c "help "<args>" 2>/dev/null || man "<args>""'
  else
    command! -buffer -nargs=1 Help echo system('bash -c "help <args>" 2>/dev/null || man "<args>"')
  endif
  setlocal keywordprg=:Help
  let b:undo_ftplugin ..= " | setl kp< | sil! delc -buffer Help"
endif

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: nowrap sw=2 sts=2 ts=8 noet:
