" Vim filetype plugin file
" Language:		csh
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Dan Sharp
" Contributor:		Johannes Zellner <johannes@zellner.org>
" 			Riley Bruins <ribru17@gmail.com>
" Last Change:		2026 Jan 16

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:save_cpo = &cpo
set cpo-=C

setlocal comments=:#
setlocal commentstring=#\ %s
setlocal formatoptions-=t
setlocal formatoptions+=crql

let b:undo_ftplugin = "setlocal com< cms< fo<"

if exists("loaded_matchit") && !exists("b:match_words")
  let b:match_ignorecase = 0
  let b:match_words = "CshMatchWords()"
  let b:match_skip = "CshMatchSkip()"
  let b:undo_ftplugin ..= " | unlet! b:match_ignorecase b:match_skip b:match_words"
endif

" skip single line 'if' commands
function CshMatchSkip()
  return getline(".") =~# '^\s*if\>' && !s:CshIsIfThenCommand()
endfunction

function CshMatchWords()
  let line_start = '\%(^\s*\)\@<='
  let match_words =
	\ line_start .. '\%(foreach\s\+\h\w*\s*(\|while\>\):' ..
	\   '\<break\>:\<continue\>:' ..
	\   line_start .. 'end\>,' ..
	\ line_start .. 'switch\s*(:' ..
	\   line_start .. 'case\s\+:' .. line_start .. 'default\>:\<breaksw\>:' ..
	\   line_start .. 'endsw\>'

  if expand("<cword>") =~# '\<if\>' && !s:CshIsIfThenCommand()
    return match_words
  else
    return match_words .. "," ..
	\ line_start .. 'if\>:' ..
	\   line_start .. 'else\s\+if\>:' .. line_start .. 'else\>:' ..
	\   line_start .. 'endif\>'
  endif
endfunction

function s:CshIsIfThenCommand()
  let lnum = line(".")
  let line = getline(lnum)

  " join continued lines
  while lnum < line("$") && line =~ '^\%([^\\]\|\\\\\)*\\$'
    let lnum += 1
    let line = substitute(line, '\\$', '', '') .. getline(lnum)
  endwhile

  " TODO: confirm with syntax checks when the highlighting is more accurate
  return line =~# '^\s*if\>.*\<then\s*\%(#.*\)\=$'
endfunction

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "csh Scripts (*.csh)\t*.csh\n"
  if has("win32")
    let b:browsefilter ..= "All Files (*.*)\t*\n"
  else
    let b:browsefilter ..= "All Files (*)\t*\n"
  endif
  let b:csh_set_browsefilter = 1
  let b:undo_ftplugin ..= " | unlet! b:browsefilter b:csh_set_browsefilter"
endif

let &cpo = s:save_cpo
unlet s:save_cpo
