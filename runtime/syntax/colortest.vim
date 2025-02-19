" Vim script for testing colors
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Contributors:	Rafael Garcia-Suarez, Charles Campbell
" Last Change:	2023 Aug 10
" Former Maintainer:	Bram Moolenaar <Bram@vim.org>

" edit this file, then do ":source %", and check if the colors match

" black		black_on_white				white_on_black
"				black_on_black		black_on_black
" darkred	darkred_on_white			white_on_darkred
"				darkred_on_black	black_on_darkred
" darkgreen	darkgreen_on_white			white_on_darkgreen
"				darkgreen_on_black	black_on_darkgreen
" brown		brown_on_white				white_on_brown
"				brown_on_black		black_on_brown
" darkblue	darkblue_on_white			white_on_darkblue
"				darkblue_on_black	black_on_darkblue
" darkmagenta	darkmagenta_on_white			white_on_darkmagenta
"				darkmagenta_on_black	black_on_darkmagenta
" darkcyan	darkcyan_on_white			white_on_darkcyan
"				darkcyan_on_black	black_on_darkcyan
" lightgray	lightgray_on_white			white_on_lightgray
"				lightgray_on_black	black_on_lightgray
" darkgray	darkgray_on_white			white_on_darkgray
"				darkgray_on_black	black_on_darkgray
" red		red_on_white				white_on_red
"				red_on_black		black_on_red
" green		green_on_white				white_on_green
"				green_on_black		black_on_green
" yellow	yellow_on_white				white_on_yellow
"				yellow_on_black		black_on_yellow
" blue		blue_on_white				white_on_blue
"				blue_on_black		black_on_blue
" magenta	magenta_on_white			white_on_magenta
"				magenta_on_black	black_on_magenta
" cyan		cyan_on_white				white_on_cyan
"				cyan_on_black		black_on_cyan
" white		white_on_white				white_on_white
"				white_on_black		black_on_white
" grey		grey_on_white				white_on_grey
"				grey_on_black		black_on_grey
" lightred	lightred_on_white			white_on_lightred
"				lightred_on_black	black_on_lightred
" lightgreen	lightgreen_on_white			white_on_lightgreen
"				lightgreen_on_black	black_on_lightgreen
" lightyellow	lightyellow_on_white			white_on_lightyellow
"				lightyellow_on_black	black_on_lightyellow
" lightblue	lightblue_on_white			white_on_lightblue
"				lightblue_on_black	black_on_lightblue
" lightmagenta	lightmagenta_on_white			white_on_lightmagenta
"				lightmagenta_on_black	black_on_lightmagenta
" lightcyan	lightcyan_on_white			white_on_lightcyan
"				lightcyan_on_black	black_on_lightcyan

" Open this file in a window if it isn't edited yet.
" Use the current window if it's empty.
if expand('%:p') != expand('<sfile>:p')
  let s:fname = expand('<sfile>')
  if exists('*fnameescape')
    let s:fname = fnameescape(s:fname)
  else
    let s:fname = escape(s:fname, ' \|')
  endif
  if &mod || line('$') != 1 || getline(1) != ''
    exe "new " . s:fname
  else
    exe "edit " . s:fname
  endif
  unlet s:fname
endif

syn clear
8
while search("_on_", "W") < 55
  let col1 = substitute(expand("<cword>"), '\(\a\+\)_on_\a\+', '\1', "")
  let col2 = substitute(expand("<cword>"), '\a\+_on_\(\a\+\)', '\1', "")
  exec 'hi col_'.col1.'_'.col2.' ctermfg='.col1.' guifg='.col1.' ctermbg='.col2.' guibg='.col2
  exec 'syn keyword col_'.col1.'_'.col2.' '.col1.'_on_'.col2
endwhile
8,54g/^" \a/exec 'hi col_'.expand("<cword>").' ctermfg='.expand("<cword>").' guifg='.expand("<cword>")| exec 'syn keyword col_'.expand("<cword>")." ".expand("<cword>")
nohlsearch
