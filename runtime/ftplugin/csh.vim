" Vim filetype plugin file
" Language:		csh
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Dan Sharp <dwsharp at users dot sourceforge dot net>
" Contributor:		Johannes Zellner <johannes@zellner.org>
" Last Change:		2021 Oct 15

if exists("b:did_ftplugin") | finish | endif
let b:did_ftplugin = 1

let s:save_cpo = &cpo
set cpo-=C

setlocal comments=:#
setlocal commentstring=#%s
setlocal formatoptions-=t
setlocal formatoptions+=crql

let b:undo_ftplugin = "setlocal com< cms< fo<"

" Csh:  thanks to Johannes Zellner
" - Both foreach and end must appear alone on separate lines.
" - The words else and endif must appear at the beginning of input lines;
"   the if must appear alone on its input line or after an else.
" - Each case label and the default label must appear at the start of a
"   line.
" - while and end must appear alone on their input lines.
if exists("loaded_matchit") && !exists("b:match_words")
  let s:line_start = '\%(^\s*\)\@<='
  let b:match_words =
	\ s:line_start .. 'if\s*(.*)\s*then\>:' ..
	\   s:line_start .. 'else\s\+if\s*(.*)\s*then\>:' .. s:line_start .. 'else\>:' ..
	\   s:line_start .. 'endif\>,' ..
	\ s:line_start .. '\%(\<foreach\s\+\h\w*\|while\)\s*(:' ..
	\   '\<break\>:\<continue\>:' ..
	\   s:line_start .. 'end\>,' ..
	\ s:line_start .. 'switch\s*(:' ..
	\   s:line_start .. 'case\s\+:' .. s:line_start .. 'default\>:\<breaksw\>:' ..
	\   s:line_start .. 'endsw\>'
  unlet s:line_start
  let b:undo_ftplugin ..= " | unlet b:match_words"
endif

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let  b:browsefilter="csh Scripts (*.csh)\t*.csh\n" ..
	\	      "All Files (*.*)\t*.*\n"
  let b:undo_ftplugin ..= " | unlet b:browsefilter"
endif

let &cpo = s:save_cpo
unlet s:save_cpo
