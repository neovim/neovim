" Vim filetype plugin file
" Language:	csh
" Maintainer:	Dan Sharp <dwsharp at users dot sourceforge dot net>
" Last Changed: 20 Jan 2009
" URL:		http://dwsharp.users.sourceforge.net/vim/ftplugin

if exists("b:did_ftplugin") | finish | endif
let b:did_ftplugin = 1

" Make sure the continuation lines below do not cause problems in
" compatibility mode.
let s:save_cpo = &cpo
set cpo-=C

setlocal commentstring=#%s
setlocal formatoptions-=t
setlocal formatoptions+=crql

" Csh:  thanks to Johannes Zellner
" - Both foreach and end must appear alone on separate lines.
" - The words else and endif must appear at the beginning of input lines;
"   the if must appear alone on its input line or after an else.
" - Each case label and the default label must appear at the start of a
"   line.
" - while and end must appear alone on their input lines.
if exists("loaded_matchit")
    let b:match_words =
      \ '^\s*\<if\>.*(.*).*\<then\>:'.
      \   '^\s*\<else\>\s\+\<if\>.*(.*).*\<then\>:^\s*\<else\>:'.
      \   '^\s*\<endif\>,'.
      \ '\%(^\s*\<foreach\>\s\+\S\+\|^s*\<while\>\).*(.*):'.
      \   '\<break\>:\<continue\>:^\s*\<end\>,'.
      \ '^\s*\<switch\>.*(.*):^\s*\<case\>\s\+:^\s*\<default\>:^\s*\<endsw\>'
endif

" Change the :browse e filter to primarily show csh-related files.
if has("gui_win32")
    let  b:browsefilter="csh Scripts (*.csh)\t*.csh\n" .
		\	"All Files (*.*)\t*.*\n"
endif

" Undo the stuff we changed.
let b:undo_ftplugin = "setlocal commentstring< formatoptions<" .
		\     " | unlet! b:match_words b:browsefilter"

" Restore the saved compatibility options.
let &cpo = s:save_cpo
unlet s:save_cpo
