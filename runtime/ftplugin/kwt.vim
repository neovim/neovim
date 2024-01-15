" Vim filetype plugin file
" Language:	Kimwitu++
" Maintainer:	Michael Piefel <entwurf@piefel.de>
" Last Change:	10 March 2012
"		2024 Jan 14 by Vim Project (browsefilter)

" Behaves almost like C++
runtime! ftplugin/cpp.vim ftplugin/cpp_*.vim ftplugin/cpp/*.vim

let s:cpo_save = &cpo
set cpo&vim

" Limit the browser to related files
if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
    let b:browsefilter = "Kimwitu/Kimwitu++ Files (*.k)\t*.k\n" .
		\ "Lex/Flex Files (*.l)\t*.l\n" .
		\ "Yacc/Bison Files (*.y)\t*.y\n"
    if has("win32")
	let b:browsefilter ..= "All Files (*.*)\t*\n"
    else
	let b:browsefilter ..= "All Files (*)\t*\n"
    endif
endif

" Set the errorformat for the Kimwitu++ compiler
set efm+=kc%.%#:\ error\ at\ %f:%l:\ %m

if exists("b:undo_ftplugin")
    let b:undo_ftplugin = b:undo_ftplugin . " | setlocal efm<"
	\ . "| unlet! b:browsefilter"
else
    let b:undo_ftplugin = "setlocal efm<"
	\ . "| unlet! b:browsefilter"
endif

let &cpo = s:cpo_save
unlet s:cpo_save
